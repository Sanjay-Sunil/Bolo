import 'package:flutter/foundation.dart';

import 'loanwords.dart';
import 'number_words.dart';
import 'voice.dart';

/// Prepares one phrase for synthesis: removes symbols the voice can't read
/// and spells out numbers, times and acronyms in the phrase's language.
///
/// Latin words inside a Devanagari phrase can't be pronounced by the Hindi
/// voice. Common ones are respelled from [loanwords]; the rest are kept and
/// passed to [onUnknownLatin].
String normalize(
  String phrase,
  Voice voice, {
  void Function(List<String> words) onUnknownLatin = _logUnknownLatin,
}) {
  final hindi = voice == Voice.hindi;
  var s = phrase;
  s = s.replaceAllMapped(
    _devanagariDigit,
    (m) => '${m[0]!.codeUnitAt(0) - 0x966}',
  );
  s = s.replaceAllMapped(_markdownLink, (m) => m[1]!);
  s = s.replaceAll(_emojiModifiers, '');
  s = s.replaceAll(_thousandsComma, '');
  s = s.replaceAllMapped(_amPmAfterNumber, (m) => ' ${m[1]!.toUpperCase()}M');
  s = s.replaceAllMapped(_dottedAmPm, (m) => '${m[1]!.toUpperCase()}M');
  s = s.replaceAllMapped(_time, (m) => ' ${_timeWords(m, hindi)} ');
  s = s.replaceAllMapped(
    _rupees,
    (m) => ' ${m[1]} ${hindi ? 'रुपये' : 'rupees'} ',
  );
  s = s.replaceAllMapped(
    _degrees,
    (m) => ' ${m[1]} ${_degreeWords(m[2], hindi)} ',
  );
  s = s.replaceAllMapped(
    _percent,
    (m) => ' ${m[1]} ${hindi ? 'प्रतिशत' : 'percent'} ',
  );
  if (!hindi) {
    s = s.replaceAllMapped(
      _ordinal,
      (m) => ' ${englishOrdinal(int.parse(m[1]!))} ',
    );
  }
  s = s.replaceAllMapped(_number, (m) => ' ${_numberWords(m[0]!, hindi)} ');
  if (hindi) {
    s = s.replaceAllMapped(_latinWord, (m) {
      final w = m[0]!;
      final shouted = w.length > 1 && w == w.toUpperCase();
      if (shouted && w.toLowerCase() != 'ok') return w;
      return loanword(w) ?? w;
    });
    s = s.replaceAllMapped(
      _acronym,
      (m) => ' ${m[0]!.split('').map((c) => _letterNames[c]).join(' ')} ',
    );
  } else {
    s = s.replaceAllMapped(_amPmWord, (m) => '${m[1]} M');
  }
  s = _stripSymbols(s);
  s = _tidy(s);
  if (hindi) {
    final latin = _latinWord.allMatches(s).map((m) => m[0]!).toList();
    if (latin.isNotEmpty) onUnknownLatin(latin);
  }
  return s;
}

void _logUnknownLatin(List<String> words) =>
    debugPrint('TextNormalizer: Latin words in Devanagari phrase: $words');

final _devanagariDigit = RegExp('[०-९]');
final _markdownLink = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final _emojiModifiers = RegExp('[︎️⃣]');
final _thousandsComma = RegExp(r'(?<=\d),(?=\d{3}(?!\d))');
final _amPmAfterNumber = RegExp(
  r'(?<=\d)\s*([ap])(?:\.m\.|m)(?![a-z])',
  caseSensitive: false,
);
final _dottedAmPm = RegExp(r'\b([ap])\.m\.', caseSensitive: false);
final _time = RegExp(
  r'(?<!\d)(\d{1,2})([:.])(\d{2})(?!\d)(\s*[AP]M\b)?(\s*(?:बजे|baje\b))?',
);
final _rupees = RegExp(r'(?:₹|\bRs\.?)\s*(\d+(?:\.\d+)?)');
final _degrees = RegExp(r'(\d+(?:\.\d+)?)\s*°\s*([CF](?![A-Za-z]))?');
final _percent = RegExp(r'(\d+(?:\.\d+)?)\s*%');
final _ordinal = RegExp(r'\b(\d+)(?:st|nd|rd|th)\b', caseSensitive: false);
final _number = RegExp(r'\d+(?:\.\d+)?');
final _acronym = RegExp(r'\b[A-Z]{1,5}\b');
final _amPmWord = RegExp(r'\b([AP])M\b');
final _latinWord = RegExp(r"[A-Za-z]+(?:['-][A-Za-z]+)*");

const _letterNames = {
  'A': 'ए', 'B': 'बी', 'C': 'सी', 'D': 'डी', 'E': 'ई', 'F': 'एफ़', 'G': 'जी', //
  'H': 'एच', 'I': 'आई', 'J': 'जे', 'K': 'के', 'L': 'एल', 'M': 'एम', 'N': 'एन',
  'O': 'ओ', 'P': 'पी', 'Q': 'क्यू', 'R': 'आर', 'S': 'एस', 'T': 'टी', 'U': 'यू',
  'V': 'वी', 'W': 'डब्ल्यू', 'X': 'एक्स', 'Y': 'वाई', 'Z': 'ज़ेड',
};

String _timeWords(Match m, bool hindi) {
  final h = int.parse(m[1]!);
  final min = int.parse(m[3]!);
  final amPm = m[4]?.trim();
  final baje = m[5] != null;
  final dotted = m[2] == '.';
  if (h > 23 || min > 59 || (dotted && amPm == null && !baje)) return m[0]!;

  final h12 = h % 12 == 0 ? 12 : h % 12;
  if (hindi) {
    final hourWord = hindiNumber(h12);
    final String spoken;
    switch (min) {
      case 0:
        spoken = '$hourWord बजे';
      case 15:
        spoken = 'सवा $hourWord${baje ? ' बजे' : ''}';
      case 30:
        final base = switch (h12) {
          1 => 'डेढ़',
          2 => 'ढाई',
          _ => 'साढ़े $hourWord',
        };
        spoken = '$base${baje ? ' बजे' : ''}';
      case 45:
        spoken = 'पौने ${hindiNumber(h12 % 12 + 1)}${baje ? ' बजे' : ''}';
      default:
        spoken = '$hourWord बजकर ${hindiNumber(min)} मिनट';
    }
    return amPm == null ? spoken : '$spoken ${amPm == 'AM' ? 'ए एम' : 'पी एम'}';
  }

  final period = amPm ?? (h > 12 ? 'PM' : (h == 0 ? 'AM' : null));
  final hourWord = englishNumber(h12);
  final String spoken;
  if (min == 0) {
    spoken = period == null ? "$hourWord o'clock" : hourWord;
  } else if (min < 10) {
    spoken = '$hourWord oh ${englishNumber(min)}';
  } else {
    spoken = '$hourWord ${englishNumber(min)}';
  }
  final suffix = [
    if (period != null) '${period[0]} M',
    if (baje) 'baje',
  ].join(' ');
  return suffix.isEmpty ? spoken : '$spoken $suffix';
}

String _degreeWords(String? scale, bool hindi) => [
  hindi ? 'डिग्री' : 'degrees',
  if (scale == 'C') hindi ? 'सेल्सियस' : 'Celsius',
  if (scale == 'F') hindi ? 'फ़ारेनहाइट' : 'Fahrenheit',
].join(' ');

String _numberWords(String number, bool hindi) {
  final parts = number.split('.');
  final whole = parts[0];
  final wholeWords = whole.length > 9 || (whole.length > 1 && whole[0] == '0')
      ? digitByDigit(whole, hindi: hindi)
      : (hindi ? hindiNumber : englishNumber)(int.parse(whole));
  if (parts.length == 1) return wholeWords;
  final point = hindi ? 'दशमलव' : 'point';
  return '$wholeWords $point ${digitByDigit(parts[1], hindi: hindi)}';
}

final _dash = RegExp(r'[–—]|(?<=\s|^)-(?=\s|$)');
final _clauseBreak = RegExp('[:;]');
final _curlyApostrophe = RegExp('[‘’]');
final _disallowed = RegExp(r"[^\p{L}\p{M}\p{N}\s.,?!।॥'\-‌‍]", unicode: true);
final _strayJoiner = RegExp(r'(?<![ऀ-ॿ])[‌‍]');

String _stripSymbols(String s) => s
    .replaceAll(_dash, ',')
    .replaceAll(_clauseBreak, ',')
    .replaceAll(_curlyApostrophe, "'")
    .replaceAll(_disallowed, ' ')
    .replaceAll(_strayJoiner, '');

final _spaces = RegExp(r'\s+');
final _spaceBeforePunct = RegExp(r'\s+([,.?!।॥])');
final _commasAfterPunct = RegExp(r'([,.?!।॥])(?:\s*,)+');
final _commaBeforeEnd = RegExp(r',\s*([.?!।॥])');
final _leadingPunct = RegExp(r'^[\s,.?!।॥]+');

String _tidy(String s) => s
    .replaceAll(_spaces, ' ')
    .replaceAllMapped(_spaceBeforePunct, (m) => m[1]!)
    .replaceAllMapped(_commasAfterPunct, (m) => m[1]!)
    .replaceAllMapped(_commaBeforeEnd, (m) => m[1]!)
    .replaceAll(_leadingPunct, '')
    .trim();
