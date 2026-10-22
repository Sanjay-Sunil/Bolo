import 'package:bolo/tts/number_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hindi', () {
    test('table covers 0 to 100', () {
      expect(hindiUpTo100, hasLength(101));
      expect(hindiUpTo100.toSet(), hasLength(101));
    });

    test('irregular numbers below 100', () {
      expect(hindiNumber(0), 'शून्य');
      expect(hindiNumber(5), 'पाँच');
      expect(hindiNumber(7), 'सात');
      expect(hindiNumber(19), 'उन्नीस');
      expect(hindiNumber(29), 'उनतीस');
      expect(hindiNumber(45), 'पैंतालीस');
      expect(hindiNumber(79), 'उन्यासी');
      expect(hindiNumber(99), 'निन्यानवे');
      expect(hindiNumber(100), 'सौ');
    });

    test('hundreds, thousands, lakhs and crores', () {
      expect(hindiNumber(105), 'एक सौ पाँच');
      expect(hindiNumber(500), 'पाँच सौ');
      expect(hindiNumber(2026), 'दो हज़ार छब्बीस');
      expect(hindiNumber(150000), 'एक लाख पचास हज़ार');
      expect(hindiNumber(23000000), 'दो करोड़ तीस लाख');
    });
  });

  group('English', () {
    test('cardinals', () {
      expect(englishNumber(0), 'zero');
      expect(englishNumber(13), 'thirteen');
      expect(englishNumber(40), 'forty');
      expect(englishNumber(28), 'twenty eight');
      expect(englishNumber(100), 'one hundred');
      expect(englishNumber(2026), 'two thousand twenty six');
      expect(englishNumber(1500000), 'one million five hundred thousand');
    });

    test('ordinals', () {
      expect(englishOrdinal(1), 'first');
      expect(englishOrdinal(2), 'second');
      expect(englishOrdinal(3), 'third');
      expect(englishOrdinal(12), 'twelfth');
      expect(englishOrdinal(20), 'twentieth');
      expect(englishOrdinal(21), 'twenty first');
      expect(englishOrdinal(24), 'twenty fourth');
    });
  });

  test('digit by digit', () {
    expect(digitByDigit('0912', hindi: false), 'zero nine one two');
    expect(digitByDigit('07', hindi: true), 'शून्य सात');
  });
}
