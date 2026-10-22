import 'dart:async';
import 'dart:convert';

import 'llm_stream_exception.dart';

/// Turns the raw bytes of an OpenAI-compatible streaming chat completion
/// (Groq, Gemini) into the sequence of `delta.content` strings.
class SseParser extends StreamTransformerBase<List<int>, String> {
  const SseParser();

  static final _otherField = RegExp(r'^(event|id|retry):');

  @override
  Stream<String> bind(Stream<List<int>> stream) async* {
    final rawBody = StringBuffer();
    var sawData = false;

    final lines = stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty || line.startsWith(':') || _otherField.hasMatch(line)) {
        continue;
      }
      if (!line.startsWith('data:')) {
        // Non-SSE body, e.g. a JSON error returned with a non-200 status.
        rawBody.writeln(line);
        continue;
      }
      sawData = true;
      var payload = line.substring(5);
      if (payload.startsWith(' ')) payload = payload.substring(1);
      if (payload.trim() == '[DONE]') return;

      // These APIs send one JSON object per data line, so each line is
      // dispatched immediately instead of waiting for the blank separator;
      // this saves a chunk round-trip on the first token.
      final content = _contentOf(_decode(payload));
      if (content != null && content.isNotEmpty) yield content;
    }

    if (!sawData && rawBody.isNotEmpty) {
      final body = rawBody.toString().trim();
      Object? json;
      try {
        json = jsonDecode(body);
      } on FormatException {
        throw LlmStreamException(_truncate(body));
      }
      _throwIfError(json);
      throw LlmStreamException(_truncate(body));
    }
  }

  static Object? _decode(String payload) {
    try {
      return jsonDecode(payload);
    } on FormatException {
      throw LlmStreamException('Malformed stream data: ${_truncate(payload)}');
    }
  }

  static String? _contentOf(Object? json) {
    _throwIfError(json);
    if (json is! Map) return null;
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final delta = first['delta'];
    if (delta is! Map) return null;
    final content = delta['content'];
    return content is String ? content : null;
  }

  static void _throwIfError(Object? json) {
    if (json is List && json.isNotEmpty) {
      _throwIfError(json.first);
      return;
    }
    if (json is! Map || !json.containsKey('error')) return;
    final error = json['error'];
    if (error is Map) {
      final message = error['message']?.toString() ?? 'Unknown error';
      final code = (error['code'] ?? error['status'] ?? error['type'])
          ?.toString();
      throw LlmStreamException(message, code: code);
    }
    throw LlmStreamException(error?.toString() ?? 'Unknown error');
  }

  static String _truncate(String s) =>
      s.length <= 200 ? s : '${s.substring(0, 200)}…';
}
