import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chat_message.dart';
import 'llm_provider.dart';
import 'llm_stream_exception.dart';
import 'prompt.dart';
import 'sse_parser.dart';

/// Streams a chat reply from an OpenAI-compatible endpoint.
class LlmClient {
  LlmClient({
    required this.provider,
    required this.apiKey,
    String? model,
    http.Client? client,
  }) : model = model ?? provider.defaultModel,
       _client = client ?? http.Client();

  static const maxTokens = 100;
  static const temperature = 0.6;

  final LlmProvider provider;
  final String apiKey;
  final String model;
  final http.Client _client;

  Stream<String> streamReply(
    List<ChatMessage> history,
    String userText, {
    DateTime? now,
  }) async* {
    final request =
        http.Request('POST', Uri.parse('${provider.baseUrl}/chat/completions'))
          ..headers.addAll({
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'model': model,
            'messages': buildMessages(history, userText, now: now),
            'stream': true,
            'max_tokens': maxTokens,
            'temperature': temperature,
          });
    final response = await _client.send(request);
    yield* response.stream.transform(const SseParser());
    if (response.statusCode != 200) {
      throw LlmStreamException(
        'HTTP ${response.statusCode}',
        code: '${response.statusCode}',
      );
    }
  }

  void close() => _client.close();
}
