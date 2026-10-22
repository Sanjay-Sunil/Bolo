import 'dart:convert';

import 'package:bolo/llm/chat_message.dart';
import 'package:bolo/llm/llm_client.dart';
import 'package:bolo/llm/llm_provider.dart';
import 'package:bolo/llm/llm_stream_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String sse(List<String> parts) => [
  for (final p in parts)
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': p},
        },
      ],
    })}\n\n',
  'data: [DONE]\n\n',
].join();

void main() {
  test('sends a streaming request and yields content deltas', () async {
    late http.Request sent;
    final client = MockClient.streaming((request, body) async {
      sent = request as http.Request;
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse(['ठीक है,', ' हो गया।']))),
        200,
      );
    });
    final llm = LlmClient(
      provider: LlmProvider.groq,
      apiKey: 'k',
      client: client,
    );

    final out = await llm.streamReply([
      const ChatMessage.user('hi'),
    ], 'kal ka alarm').toList();

    expect(out, ['ठीक है,', ' हो गया।']);
    expect(
      sent.url.toString(),
      'https://api.groq.com/openai/v1/chat/completions',
    );
    expect(sent.headers['Authorization'], 'Bearer k');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['stream'], isTrue);
    expect(body['model'], LlmProvider.groq.defaultModel);
    expect(body['max_tokens'], LlmClient.maxTokens);
    expect(body['reasoning_effort'], 'none');
    final messages = body['messages'] as List;
    expect(messages.first['role'], 'system');
    expect(messages.last, {'role': 'user', 'content': 'kal ka alarm'});
  });

  test('reasoning options per model family', () {
    expect(LlmClient.reasoningOptions('openai/gpt-oss-120b'), {
      'reasoning_effort': 'low',
      'include_reasoning': false,
    });
    expect(LlmClient.reasoningOptions('qwen/qwen3.8-27b'), {
      'reasoning_effort': 'none',
    });
    expect(LlmClient.reasoningOptions('gemini-2.5-flash'), {
      'reasoning_effort': 'none',
    });
    expect(LlmClient.reasoningOptions('gemini-3.5-flash-lite'), isEmpty);
  });

  test('API error body becomes LlmStreamException', () async {
    final client = MockClient.streaming(
      (request, body) async => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'error': {
                'message': 'Invalid API Key',
                'code': 'invalid_api_key',
              },
            }),
          ),
        ),
        401,
      ),
    );
    final llm = LlmClient(
      provider: LlmProvider.groq,
      apiKey: 'bad',
      client: client,
    );

    expect(
      llm.streamReply(const [], 'hi').toList(),
      throwsA(
        isA<LlmStreamException>().having(
          (e) => e.message,
          'message',
          'Invalid API Key',
        ),
      ),
    );
  });

  test('non-200 with an empty body still fails', () async {
    final client = MockClient.streaming(
      (request, body) async => http.StreamedResponse(const Stream.empty(), 503),
    );
    final llm = LlmClient(
      provider: LlmProvider.gemini,
      apiKey: 'k',
      client: client,
    );

    expect(
      llm.streamReply(const [], 'hi').toList(),
      throwsA(isA<LlmStreamException>()),
    );
  });

  group('checkKey', () {
    LlmClient client(int status) => LlmClient(
      provider: LlmProvider.groq,
      apiKey: 'k',
      client: MockClient((r) async => http.Response('{}', status)),
    );

    test('200 means accepted', () async {
      expect(await client(200).checkKey(), isTrue);
    });

    test('401 means rejected', () async {
      expect(await client(401).checkKey(), isFalse);
    });

    test('other failures mean unknown', () async {
      expect(await client(503).checkKey(), isNull);
      final offline = LlmClient(
        provider: LlmProvider.groq,
        apiKey: 'k',
        client: MockClient((r) async => throw http.ClientException('offline')),
      );
      expect(await offline.checkKey(), isNull);
    });
  });
}
