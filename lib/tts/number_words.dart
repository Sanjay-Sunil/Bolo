/// Hindi number words 0 to 100. Hindi has no regular pattern below 100.
const hindiUpTo100 = [
  'शून्य', 'एक', 'दो', 'तीन', 'चार', 'पाँच', 'छह', 'सात', 'आठ', 'नौ', //
  'दस', 'ग्यारह', 'बारह', 'तेरह', 'चौदह', 'पंद्रह', 'सोलह', 'सत्रह', 'अठारह',
  'उन्नीस', 'बीस', 'इक्कीस', 'बाईस', 'तेईस', 'चौबीस', 'पच्चीस', 'छब्बीस',
  'सत्ताईस', 'अट्ठाईस', 'उनतीस', 'तीस', 'इकतीस', 'बत्तीस', 'तैंतीस', 'चौंतीस',
  'पैंतीस', 'छत्तीस', 'सैंतीस', 'अड़तीस', 'उनतालीस', 'चालीस', 'इकतालीस',
  'बयालीस', 'तैंतालीस', 'चवालीस', 'पैंतालीस', 'छियालीस', 'सैंतालीस', 'अड़तालीस',
  'उनचास', 'पचास', 'इक्यावन', 'बावन', 'तिरपन', 'चौवन', 'पचपन', 'छप्पन',
  'सत्तावन', 'अट्ठावन', 'उनसठ', 'साठ', 'इकसठ', 'बासठ', 'तिरसठ', 'चौंसठ',
  'पैंसठ', 'छियासठ', 'सड़सठ', 'अड़सठ', 'उनहत्तर', 'सत्तर', 'इकहत्तर', 'बहत्तर',
  'तिहत्तर', 'चौहत्तर', 'पचहत्तर', 'छिहत्तर', 'सतहत्तर', 'अठहत्तर', 'उन्यासी',
  'अस्सी', 'इक्यासी', 'बयासी', 'तिरासी', 'चौरासी', 'पचासी', 'छियासी', 'सत्तासी',
  'अट्ठासी', 'नवासी', 'नब्बे', 'इक्यानवे', 'बानवे', 'तिरानवे', 'चौरानवे',
  'पचानवे', 'छियानवे', 'सत्तानवे', 'अट्ठानवे', 'निन्यानवे', 'सौ',
];

/// Words that are part of a number or time expression in Hindi.
const hindiNumberExtras = {
  'सौ',
  'हज़ार',
  'हजार',
  'लाख',
  'करोड़',
  'साढ़े',
  'सवा',
  'पौने',
  'डेढ़',
  'ढाई',
  'पांच',
  'छः',
  'दशमलव',
};

const _englishOnes = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', //
  'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
  'sixteen', 'seventeen', 'eighteen', 'nineteen',
];

const _englishTens = [
  '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', //
  'eighty', 'ninety',
];

/// Words that are part of a number or time expression in English.
final englishNumberWords = {
  ..._englishOnes,
  ..._englishTens.where((w) => w.isNotEmpty),
  'hundred',
  'thousand',
  'million',
  'billion',
  'half',
  'quarter',
  'point',
};

String hindiNumber(int n) {
  if (n < 0) return 'माइनस ${hindiNumber(-n)}';
  if (n <= 100) return hindiUpTo100[n];
  final parts = <String>[];
  void take(int unit, String word) {
    final count = n ~/ unit;
    if (count > 0) {
      parts.add('${hindiNumber(count)} $word');
      n %= unit;
    }
  }

  take(10000000, 'करोड़');
  take(100000, 'लाख');
  take(1000, 'हज़ार');
  take(100, 'सौ');
  if (n > 0) parts.add(hindiUpTo100[n]);
  return parts.join(' ');
}

String englishNumber(int n) {
  if (n < 0) return 'minus ${englishNumber(-n)}';
  if (n < 20) return _englishOnes[n];
  if (n < 100) {
    final rest = n % 10;
    return rest == 0
        ? _englishTens[n ~/ 10]
        : '${_englishTens[n ~/ 10]} ${_englishOnes[rest]}';
  }
  for (final (unit, word) in const [
    (1000000000, 'billion'),
    (1000000, 'million'),
    (1000, 'thousand'),
    (100, 'hundred'),
  ]) {
    if (n >= unit) {
      final rest = n % unit;
      final head = '${englishNumber(n ~/ unit)} $word';
      return rest == 0 ? head : '$head ${englishNumber(rest)}';
    }
  }
  throw StateError('unreachable');
}

const _ordinalIrregular = {
  'one': 'first',
  'two': 'second',
  'three': 'third',
  'five': 'fifth',
  'eight': 'eighth',
  'nine': 'ninth',
  'twelve': 'twelfth',
};

String englishOrdinal(int n) {
  final words = englishNumber(n).split(' ');
  final last = words.removeLast();
  final String ordinal;
  if (_ordinalIrregular.containsKey(last)) {
    ordinal = _ordinalIrregular[last]!;
  } else if (last.endsWith('y')) {
    ordinal = '${last.substring(0, last.length - 1)}ieth';
  } else {
    ordinal = '${last}th';
  }
  return [...words, ordinal].join(' ');
}

/// Reads each digit separately, for phone numbers and very long numbers.
String digitByDigit(String digits, {required bool hindi}) => digits
    .split('')
    .map((d) => hindi ? hindiUpTo100[int.parse(d)] : _englishOnes[int.parse(d)])
    .join(' ');
