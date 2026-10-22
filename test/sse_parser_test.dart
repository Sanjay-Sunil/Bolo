import 'dart:async';
import 'dart:convert';

import 'package:bolo/llm/llm_stream_exception.dart';
import 'package:bolo/llm/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String chunk(String? content) =>
    'data: ${jsonEncode({
      'id': 'x',
      'choices': [
        {
          'index': 0,
          'delta': {'content': ?content},
        },
      ],
    })}\n\n';

Future<List<String>> parse(List<List<int>> chunks) =>
    Stream<List<int>>.fromIterable(chunks)
        .transform(const SseParser())
        .toList();

Future<List<String>> parseText(String body, {int split = 0}) {
  final bytes = utf8.encode(body);
  if (split <= 0) return parse([bytes]);
  return parse([
    for (var i = 0; i < bytes.length; i += split)
      bytes.sublist(i, i + split > bytes.length ? bytes.length : i + split),
  ]);
}

void main() {
  test('yields content deltas in order and stops at [DONE]', () async {
    final body =
        '${chunk('Sure,')}${chunk(' it is')}${chunk(' sunny.')}data: [DONE]\n\n${chunk('ignored')}';
    expect(await parseText(body), ['Sure,', ' it is', ' sunny.']);
  });

  test(
    'handles every possible byte split, including inside Devanagari',
    () async {
      final body =
          '${chunk('ठीक है,')}${chunk(' मीटिंग पाँच बजे है।')}data: [DONE]\n\n';
      for (var split = 1; split <= 7; split++) {
        expect(
          (await parseText(body, split: split)).join(),
          'ठीक है, मीटिंग पाँच बजे है।',
          reason: 'split=$split',
        );
      }
    },
  );

  test('skips role-only, null, missing and empty content', () async {
    final roleOnly =
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'role': 'assistant'},
            },
          ],
        })}\n\n';
    final nullContent =
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': null},
            },
          ],
        })}\n\n';
    final noChoices =
        'data: ${jsonEncode({
          'choices': <Object>[],
          'x_groq': {'usage': <String, Object>{}},
        })}\n\n';
    final body =
        '$roleOnly$nullContent${chunk('')}$noChoices${chunk('Hi')}data: [DONE]\n\n';
    expect(await parseText(body), ['Hi']);
  });

  test(
    'ignores comments, other fields, CRLF and no space after colon',
    () async {
      final body =
          ': keep-alive\r\nevent: message\r\nid: 1\r\nretry: 100\r\n'
          'data:{"choices":[{"delta":{"content":"A"}}]}\r\n\r\n'
          '${chunk('B')}';
      expect(await parseText(body), ['A', 'B']);
    },
  );

  test('ends cleanly when the stream closes without [DONE]', () async {
    expect(await parseText(chunk('only')), ['only']);
  });

  test('throws on an error object inside the stream', () async {
    final body =
        '${chunk('Partial')}data: {"error":{"message":"Rate limit reached","type":"tokens","code":"rate_limit_exceeded"}}\n\n';
    final out = <String>[];
    Object? err;
    try {
      await for (final s in Stream<List<int>>.value(
        utf8.encode(body),
      ).transform(const SseParser())) {
        out.add(s);
      }
    } catch (e) {
      err = e;
    }
    expect(out, ['Partial']);
    expect(
      err,
      isA<LlmStreamException>()
          .having((e) => e.message, 'message', 'Rate limit reached')
          .having((e) => e.code, 'code', 'rate_limit_exceeded'),
    );
  });

  test('throws on a non-SSE JSON error body (Groq style)', () async {
    const body =
        '{\n  "error": {\n    "message": "Invalid API Key",\n    "type": "invalid_request_error",\n    "code": "invalid_api_key"\n  }\n}\n';
    await expectLater(
      parseText(body),
      throwsA(
        isA<LlmStreamException>()
            .having((e) => e.message, 'message', 'Invalid API Key')
            .having((e) => e.code, 'code', 'invalid_api_key'),
      ),
    );
  });

  test('throws on a list-wrapped error body (Gemini style)', () async {
    const body =
        '[{"error":{"code":400,"message":"API key not valid.","status":"INVALID_ARGUMENT"}}]';
    await expectLater(
      parseText(body),
      throwsA(
        isA<LlmStreamException>()
            .having((e) => e.message, 'message', 'API key not valid.')
            .having((e) => e.code, 'code', '400'),
      ),
    );
  });

  test('throws on a plain-text body', () async {
    await expectLater(
      parseText('Service Unavailable\n'),
      throwsA(
        isA<LlmStreamException>().having(
          (e) => e.message,
          'message',
          'Service Unavailable',
        ),
      ),
    );
  });

  test('throws on malformed JSON in a data line', () async {
    await expectLater(
      parseText('data: {"choices": [\n\n'),
      throwsA(isA<LlmStreamException>()),
    );
  });

  test('yields the first delta before the stream completes', () async {
    final controller = StreamController<List<int>>();
    final first = controller.stream.transform(const SseParser()).first;
    controller.add(utf8.encode(chunk('Fast')));
    expect(await first.timeout(const Duration(seconds: 1)), 'Fast');
    await controller.close();
  });
}
