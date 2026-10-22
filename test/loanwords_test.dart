import 'package:bolo/tts/loanwords.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direct lookup is case-insensitive', () {
    expect(loanword('Schedule'), 'शेड्यूल');
    expect(loanword('NEXT'), 'नेक्स्ट');
  });

  test('plural of a consonant-final word adds ्स', () {
    expect(loanword('meetings'), 'मीटिंग्स');
    expect(loanword('calls'), 'कॉल्स');
  });

  test('plural of a vowel-final word adds ज़', () {
    expect(loanword('movies'), 'मूवीज़');
    expect(loanword('batteries'), isNull);
  });

  test('-es plural', () {
    expect(loanword('classes'), 'क्लासेज़');
  });

  test('unknown words return null', () {
    expect(loanword('whatsapp'), isNull);
    expect(loanword('s'), isNull);
  });

  test('every value is pure Devanagari', () {
    final devanagari = RegExp(r'^[ऀ-ॿ]+$');
    for (final e in loanwords.entries) {
      expect(devanagari.hasMatch(e.value), isTrue, reason: e.key);
      expect(e.key, e.key.toLowerCase());
    }
  });
}
