import 'package:bolo/pipeline/wer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = WerCalculator();

  group('normalize', () {
    test('lowercases and strips punctuation', () {
      expect(
        WerCalculator.normalize(
          'What is the weather forecast for Bangalore tomorrow?',
        ),
        'what is the weather forecast for bangalore tomorrow',
      );
      expect(
        WerCalculator.normalize(
          'Aaj ka schedule kya hai, aur meri next meeting kab hai?',
        ),
        'aaj ka schedule kya hai aur meri next meeting kab hai',
      );
    });

    test('drops apostrophes and splits on other punctuation', () {
      expect(
        WerCalculator.normalize("What's  the follow-up?"),
        'whats the follow up',
      );
    });

    test('keeps Devanagari matras and removes danda', () {
      expect(WerCalculator.normalize('ठीक है, मीटिंग है।'), 'ठीक है मीटिंग है');
    });
  });

  group('wer', () {
    test('identical after normalization is zero', () {
      final r = calc.wer(
        'Can you set a reminder for my meeting at 5 PM?',
        'can you set a reminder for my meeting at 5 pm',
      );
      expect(r.rate, 0);
      expect(r.referenceLength, 11);
    });

    test('counts substitutions, insertions and deletions', () {
      final r = calc.wer(
        'mujhe kal subah 7 baje ka alarm set karna hai',
        'mujhe kal subha 7 baje alarm set karna hai na',
      );
      expect(r.substitutions, 1);
      expect(r.deletions, 1);
      expect(r.insertions, 1);
      expect(r.rate, closeTo(3 / 10, 1e-9));
    });

    test('empty hypothesis is all deletions', () {
      final r = calc.wer('aaj ka schedule', '');
      expect(r.deletions, 3);
      expect(r.rate, 1);
    });

    test('empty reference', () {
      expect(calc.wer('', '').rate, 0);
      final r = calc.wer('', 'hello there');
      expect(r.insertions, 2);
      expect(r.rate, 1);
    });

    test('can exceed 100% with many insertions', () {
      expect(calc.wer('hi', 'hi there my friend').rate, closeTo(3.0, 1e-9));
    });
  });

  group('cer', () {
    test('counts character edits including spaces', () {
      final r = calc.cer('kal subah', 'kal subha');
      expect(r.referenceLength, 9);
      expect(r.errors, 2);
    });

    test('works on code points for Devanagari', () {
      final r = calc.cer('है', 'हैं');
      expect(r.referenceLength, 2);
      expect(r.insertions, 1);
      expect(r.errors, 1);
    });
  });
}
