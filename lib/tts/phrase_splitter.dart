import 'number_words.dart';

/// Turns a stream of LLM token deltas into short phrases for TTS.
///
/// The first phrase is kept short so speech can start early; later phrases
/// end at punctuation or after [maxWords]. A cut is never made inside a
/// number or time expression ("शाम पाँच बजे", "5:30 PM").
class PhraseSplitter {
  PhraseSplitter({
    this.firstWords = 5,
    this.maxWords = 8,
    this.maxExtraWords = 4,
  });

  final int firstWords;
  final int maxWords;

  /// How far past the word limit a number expression may extend a phrase.
  final int maxExtraWords;

  static final _word = RegExp(r'\S+');
  static final _endsWithPunct = RegExp('[,.?!।॥]["\'”’)]*\$');
  static final _endsWithSpace = RegExp(r'\s$');
  static final _hasDigit = RegExp(r'[0-9०-९]');
  static final _edgePunct = RegExp('^["\'“‘(]+|[,.?!।॥:;"\'”’)]+\$');

  Stream<String> split(Stream<String> tokens) async* {
    var buffer = '';
    var emitted = 0;

    Iterable<String> drain({required bool flush}) sync* {
      while (true) {
        final end = _nextCut(buffer, first: emitted == 0, flush: flush);
        if (end == null) return;
        final phrase = buffer.substring(0, end).trim();
        buffer = buffer.substring(end);
        if (phrase.isEmpty) continue;
        emitted++;
        yield phrase;
      }
    }

    await for (final token in tokens) {
      buffer += token;
      for (final phrase in drain(flush: false).toList()) {
        yield phrase;
      }
    }
    for (final phrase in drain(flush: true).toList()) {
      yield phrase;
    }
  }

  /// End offset of the next phrase in [buffer], or null if more text is
  /// needed. With [flush], whatever remains forms the last phrase.
  int? _nextCut(String buffer, {required bool first, required bool flush}) {
    if (buffer.trim().isEmpty) return null;
    final words = _word.allMatches(buffer).toList();
    // Until whitespace follows it, the last word may still be growing.
    if (!flush && !_endsWithSpace.hasMatch(buffer)) words.removeLast();
    final limit = first ? firstWords : maxWords;

    for (var i = 0; i < words.length; i++) {
      final word = words[i].group(0)!;
      if (_endsWithPunct.hasMatch(word)) return words[i].end;
      final count = i + 1;
      if (count < limit) continue;
      if (i + 1 == words.length) break;
      final next = words[i + 1].group(0)!;
      final insideNumber = _isNumeric(word) || _isNumeric(next);
      if (!insideNumber || count >= limit + maxExtraWords) return words[i].end;
    }
    return flush ? buffer.length : null;
  }

  bool _isNumeric(String word) {
    if (_hasDigit.hasMatch(word)) return true;
    final bare = word.replaceAll(_edgePunct, '').toLowerCase();
    return hindiUpTo100.contains(bare) ||
        hindiNumberExtras.contains(bare) ||
        englishNumberWords.contains(bare);
  }
}
