import '../tts/loanwords.dart';

/// Writes Devanagari Hinglish the way people type it in Latin letters
/// ("ठीक है, आपकी मीटिंग 5 बजे है।" -> "Theek hai, aapki meeting 5 baje hai.").
/// Replies are spoken from Devanagari but shown in this form.
///
/// Pass [capitalize] false for a phrase that continues a sentence.
String romanHinglish(String text, {bool capitalize = true}) {
  text = text.replaceAll(_markdown, '');
  final out = StringBuffer();
  var sentenceStart = capitalize;
  for (final m in _token.allMatches(text)) {
    final t = m[0]!;
    if (_devanagariWord.hasMatch(t)) {
      var word = _romanWord(t);
      if (sentenceStart && word.isNotEmpty) {
        word = word[0].toUpperCase() + word.substring(1);
      }
      out.write(word);
      sentenceStart = false;
    } else {
      final plain = t
          .replaceAll('।', '.')
          .replaceAll('॥', '.')
          .replaceAllMapped(
            _devanagariDigit,
            (d) => '${d[0]!.codeUnitAt(0) - 0x966}',
          );
      out.write(plain);
      if (_sentenceEnd.hasMatch(plain)) {
        sentenceStart = true;
      } else if (_letter.hasMatch(plain)) {
        sentenceStart = false;
      }
    }
  }
  return out.toString();
}

/// Emphasis and code markers the LLM sometimes adds (`**word**`, `_word_`).
final _markdown = RegExp(r'\*\*|__|`|(?<=\s|^)[*_#]+|[*_]+(?=\s|$|[.,!?।])');
final _token = RegExp('[ऀ-ॣॱ-ॿ]+|[^ऀ-ॣॱ-ॿ]+');
final _devanagariWord = RegExp('^[ऀ-ॣॱ-ॿ]+\$');
final _devanagariDigit = RegExp('[०-९]');
final _sentenceEnd = RegExp(r'[.?!]\s*$');
final _letter = RegExp('[A-Za-z0-9]');

String _romanWord(String word) {
  final known =
      _common[word] ?? _englishFor[word] ?? _englishFor[_precomposed(word)];
  if (known != null) return known;
  if (word.endsWith('्स')) {
    final stem = _englishFor[word.substring(0, word.length - 2)];
    if (stem != null) return '${stem}s';
  }
  if (word.endsWith('ज़')) {
    final stem = _englishFor[word.substring(0, word.length - 2)];
    if (stem != null) return '${stem}s';
  }
  return _transliterate(word);
}

/// Splits precomposed nukta letters (ज़ U+095B) into base + nukta, matching
/// how the loanword table is written.
String _precomposed(String word) {
  const split = {
    '\u0958': 'क\u093c',
    '\u0959': 'ख\u093c',
    '\u095a': 'ग\u093c',
    '\u095b': 'ज\u093c',
    '\u095c': 'ड\u093c',
    '\u095d': 'ढ\u093c',
    '\u095e': 'फ\u093c',
    '\u095f': 'य\u093c',
  };
  var out = word;
  split.forEach((a, b) => out = out.replaceAll(a, b));
  return out;
}

final Map<String, String> _englishFor = () {
  final m = <String, String>{};
  for (final e in loanwords.entries) {
    m.putIfAbsent(e.value, () => e.key);
    // The LLM often drops the nukta (ऑफिस for ऑफ़िस).
    m.putIfAbsent(e.value.replaceAll('़', ''), () => e.key);
  }
  m['ओके'] = 'okay';
  return m;
}();

const _common = {
  'है': 'hai',
  'हैं': 'hain',
  'हूँ': 'hoon',
  'हूं': 'hoon',
  'हो': 'ho',
  'था': 'tha',
  'थी': 'thi',
  'थे': 'the',
  'मैं': 'main',
  'में': 'mein',
  'नहीं': 'nahin',
  'नही': 'nahi',
  'हाँ': 'haan',
  'हां': 'haan',
  'जी': 'ji',
  'क्या': 'kya',
  'क्यों': 'kyon',
  'कैसे': 'kaise',
  'कब': 'kab',
  'कहाँ': 'kahan',
  'और': 'aur',
  'या': 'ya',
  'तो': 'to',
  'भी': 'bhi',
  'ही': 'hi',
  'ये': 'ye',
  'यह': 'yeh',
  'वह': 'woh',
  'वो': 'wo',
  'का': 'ka',
  'की': 'ki',
  'के': 'ke',
  'को': 'ko',
  'से': 'se',
  'पर': 'par',
  'ने': 'ne',
  'एक': 'ek',
  'दो': 'do',
  'आप': 'aap',
  'आपका': 'aapka',
  'आपकी': 'aapki',
  'आपके': 'aapke',
  'आपको': 'aapko',
  'मुझे': 'mujhe',
  'मेरा': 'mera',
  'मेरी': 'meri',
  'मेरे': 'mere',
  'हम': 'hum',
  'तुम': 'tum',
  'ठीक': 'theek',
  'अभी': 'abhi',
  'कल': 'kal',
  'आज': 'aaj',
  'सुबह': 'subah',
  'शाम': 'shaam',
  'रात': 'raat',
  'बजे': 'baje',
  'लिए': 'liye',
  'चलिए': 'chaliye',
  'बहुत': 'bahut',
  'थोड़ा': 'thoda',
  'थोड़ी': 'thodi',
  'अच्छा': 'achha',
  'अच्छी': 'achhi',
  'ज़्यादा': 'zyada',
  'ज्यादा': 'zyada',
  'कुछ': 'kuch',
  'सब': 'sab',
  'अपने': 'apne',
  'अपना': 'apna',
  'अपनी': 'apni',
  'लेकिन': 'lekin',
  'इसलिए': 'isliye',
  'कृपया': 'kripya',
  'धन्यवाद': 'dhanyavaad',
};

const _consonants = {
  'क': 'k',
  'ख': 'kh',
  'ग': 'g',
  'घ': 'gh',
  'ङ': 'n',
  'च': 'ch',
  'छ': 'chh',
  'ज': 'j',
  'झ': 'jh',
  'ञ': 'n',
  'ट': 't',
  'ठ': 'th',
  'ड': 'd',
  'ढ': 'dh',
  'ण': 'n',
  'त': 't',
  'थ': 'th',
  'द': 'd',
  'ध': 'dh',
  'न': 'n',
  'प': 'p',
  'फ': 'ph',
  'ब': 'b',
  'भ': 'bh',
  'म': 'm',
  'य': 'y',
  'र': 'r',
  'ल': 'l',
  'व': 'v',
  'श': 'sh',
  'ष': 'sh',
  'स': 's',
  'ह': 'h',
  'क़': 'q',
  'ख़': 'kh',
  'ग़': 'g',
  'ज़': 'z',
  'ड़': 'r',
  'ढ़': 'rh',
  'फ़': 'f',
  'य़': 'y',
};

const _nuktaBase = {
  'क': 'क़',
  'ख': 'ख़',
  'ग': 'ग़',
  'ज': 'ज़',
  'ड': 'ड़',
  'ढ': 'ढ़',
  'फ': 'फ़',
  'य': 'य़',
};

const _vowels = {
  'अ': 'a',
  'आ': 'aa',
  'इ': 'i',
  'ई': 'ee',
  'उ': 'u',
  'ऊ': 'oo',
  'ए': 'e',
  'ऐ': 'ai',
  'ओ': 'o',
  'औ': 'au',
  'ऋ': 'ri',
  'ऑ': 'o',
  'ऍ': 'e',
};

const _matras = {
  'ा': 'aa',
  'ि': 'i',
  'ी': 'ee',
  'ु': 'u',
  'ू': 'oo',
  'े': 'e',
  'ै': 'ai',
  'ो': 'o',
  'ौ': 'au',
  'ृ': 'ri',
  'ॉ': 'o',
  'ॅ': 'e',
};

const _labials = {'p', 'ph', 'b', 'bh', 'm'};

/// One unit of the word: a consonant (with its vowel, which is the inherent
/// schwa unless a matra or virama follows) or an independent vowel.
class _Unit {
  _Unit(this.consonant, this.vowel);

  final String? consonant;
  String vowel;
  bool schwa = false;
  String nasal = '';
}

String _transliterate(String word) {
  final chars = word.split('');
  final units = <_Unit>[];
  for (var i = 0; i < chars.length; i++) {
    var c = chars[i];
    if (i + 1 < chars.length && chars[i + 1] == '़' && _nuktaBase[c] != null) {
      c = _nuktaBase[c]!;
      i++;
    }
    if (c == '़') continue;
    final cons = _consonants[c];
    if (cons != null) {
      units.add(_Unit(cons, 'a')..schwa = true);
      continue;
    }
    final vowel = _vowels[c];
    if (vowel != null) {
      units.add(_Unit(null, vowel));
      continue;
    }
    final matra = _matras[c];
    if (matra != null && units.isNotEmpty) {
      units.last
        ..vowel = matra
        ..schwa = false;
      continue;
    }
    if (c == '्' && units.isNotEmpty) {
      units.last
        ..vowel = ''
        ..schwa = false;
      continue;
    }
    if ((c == 'ं' || c == 'ँ') && units.isNotEmpty) {
      units.last.nasal = 'n';
      continue;
    }
    if (c == 'ः' && units.isNotEmpty) {
      units.last.nasal = 'h';
    }
  }
  if (units.isEmpty) return '';

  // Schwa deletion: the last one, then right to left in V C ə C V contexts.
  if (units.length > 1 && units.last.schwa && units.last.nasal.isEmpty) {
    units.last.vowel = '';
  }
  bool hasVowel(_Unit u) => u.vowel.isNotEmpty;
  for (var i = units.length - 2; i >= 1; i--) {
    final u = units[i];
    if (!u.schwa || u.nasal.isNotEmpty) continue;
    final prev = units[i - 1], next = units[i + 1];
    if (hasVowel(prev) && next.consonant != null && hasVowel(next)) {
      u.vowel = '';
    }
  }

  final out = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    final last = i == units.length - 1;
    var vowel = u.vowel;
    // Casual Hinglish spelling: long vowels shortened at the end of a word.
    if (last && u.nasal.isEmpty) {
      vowel = switch (vowel) {
        'aa' => 'a',
        'ee' => 'i',
        'oo' => 'u',
        _ => vowel,
      };
    }
    out
      ..write(u.consonant ?? '')
      ..write(vowel);
    if (u.nasal == 'n') {
      final next = i + 1 < units.length ? units[i + 1].consonant : null;
      out.write(next != null && _labials.contains(next) ? 'm' : 'n');
    } else {
      out.write(u.nasal);
    }
  }
  return out.toString();
}
