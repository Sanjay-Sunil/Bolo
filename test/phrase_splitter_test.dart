import 'dart:async';

import 'package:bolo/tts/phrase_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [tokens] through the splitter as if streamed from the LLM.
Future<List<String>> splitTokens(List<String> tokens, [PhraseSplitter? s]) =>
    (s ?? PhraseSplitter()).split(Stream.fromIterable(tokens)).toList();

/// Breaks [text] into small deltas the way a streaming API does: a leading
/// space attached to each word, and long words broken in two.
List<String> tokenize(String text) {
  final out = <String>[];
  for (final m in RegExp(r'\s*\S+').allMatches(text)) {
    final t = m.group(0)!;
    if (t.length > 6) {
      out
        ..add(t.substring(0, t.length ~/ 2))
        ..add(t.substring(t.length ~/ 2));
    } else {
      out.add(t);
    }
  }
  return out;
}

Future<List<String>> splitText(String text) => splitTokens(tokenize(text));

void main() {
  group('opener and first phrase', () {
    test('an English opener becomes its own phrase', () async {
      final phrases = await splitText(
        'Sure, I will remind you about your meeting at five PM today.',
      );
      expect(phrases.first, 'Sure,');
    });

    test('a Devanagari opener becomes its own phrase', () async {
      final phrases = await splitText('ठीक है, मैं आपको याद दिला दूँगा।');
      expect(phrases, ['ठीक है,', 'मैं आपको याद दिला दूँगा।']);
    });

    test('a first phrase without punctuation is cut after five words', () async {
      final phrases = await splitText(
        'I cannot check live weather but tomorrow in Bangalore looks pleasant',
      );
      expect(phrases.first, 'I cannot check live weather');
    });
  });

  group('later phrases', () {
    test('cut at sentence punctuation', () async {
      final phrases = await splitText('Okay. It will be sunny. Carry water!');
      expect(phrases, ['Okay.', 'It will be sunny.', 'Carry water!']);
    });

    test('cut at the danda', () async {
      final phrases = await splitText(
        'हाँ, कल धूप रहेगी। छाता ज़रूरी नहीं है।',
      );
      expect(phrases, ['हाँ,', 'कल धूप रहेगी।', 'छाता ज़रूरी नहीं है।']);
    });

    test('cut after eight words when there is no punctuation', () async {
      final phrases = await splitText(
        'Okay, you have a long day with many meetings planned and a '
        'review in the evening',
      );
      expect(phrases[1], 'you have a long day with many meetings');
      expect(phrases[2], 'planned and a review in the evening');
    });
  });

  group('number and time expressions stay together', () {
    test('Devanagari time is not split', () async {
      final phrases = await splitText(
        'ठीक है, आपकी मीटिंग आज शाम पाँच बजे है।',
      );
      expect(phrases, ['ठीक है,', 'आपकी मीटिंग आज शाम पाँच बजे है।']);
    });

    test('a time at the word limit pulls in its unit', () async {
      final phrases = await splitText(
        'Your meeting is at 5:30 PM in the main office today.',
      );
      expect(phrases.first, 'Your meeting is at 5:30 PM');
    });

    test('digits with a Hinglish unit stay together', () async {
      final phrases = await splitText(
        'Theek hai main kal subah 7 baje ka alarm yaad rakhunga',
      );
      expect(phrases.first, 'Theek hai main kal subah 7 baje');
    });

    test('Hindi number words at the limit stay together', () async {
      final phrases = await splitText(
        'हाँ आपका अलार्म कल सुबह साढ़े सात बजे का है',
      );
      expect(phrases.first, 'हाँ आपका अलार्म कल सुबह साढ़े सात बजे');
    });

    test('a long run of numbers is still cut eventually', () async {
      final phrases = await splitTokens(
        tokenize('one two three four five six seven eight nine ten eleven'),
      );
      expect(phrases.first.split(' '), hasLength(9));
    });
  });

  group('streaming behaviour', () {
    test('a word split across deltas is not cut in half', () async {
      final phrases = await splitTokens([
        'Sure',
        ',',
        ' remind',
        'er set for to',
        'morrow at nine.',
      ]);
      expect(phrases, ['Sure,', 'reminder set for tomorrow at nine.']);
    });

    test('the first phrase is emitted before the stream ends', () async {
      final splitter = PhraseSplitter();
      final controller = StreamController<String>();
      final got = <String>[];
      final done = splitter.split(controller.stream).forEach(got.add);
      controller
        ..add('Okay,')
        ..add(' let');
      await pumpEventQueue();
      expect(got, ['Okay,']);
      controller.add(' me check.');
      await controller.close();
      await done;
      expect(got, ['Okay,', 'let me check.']);
    });

    test('the remainder is flushed at the end of the stream', () async {
      final phrases = await splitText('Okay, see you then');
      expect(phrases, ['Okay,', 'see you then']);
    });

    test('whitespace is trimmed and empty phrases are dropped', () async {
      final phrases = await splitTokens(['  ', 'Hi', ' , ', '\n', ' there ']);
      expect(phrases, ['Hi ,', 'there']);
    });

    test('an empty stream gives no phrases', () async {
      expect(await splitTokens([]), isEmpty);
      expect(await splitTokens(['   ', '\n']), isEmpty);
    });

    test('a decimal number is not treated as a sentence end', () async {
      final phrases = await splitText('It is 2.5 kilometres away.');
      expect(phrases, ['It is 2.5 kilometres away.']);
    });
  });

  group('likely replies to the four test sentences', () {
    test('weather in English', () async {
      final phrases = await splitText(
        "Sure, I can't check live forecasts, but Bangalore tomorrow will "
        'likely be pleasant with a high of twenty eight degrees.',
      );
      expect(phrases, [
        'Sure,',
        "I can't check live forecasts,",
        'but Bangalore tomorrow will likely be pleasant with',
        'a high of twenty eight degrees.',
      ]);
    });

    test('reminder in English', () async {
      final phrases = await splitText(
        "Okay, I can't set reminders, but I'd remind you at five PM.",
      );
      expect(phrases, [
        'Okay,',
        "I can't set reminders,",
        "but I'd remind you at five PM.",
      ]);
    });

    test('alarm in Hinglish', () async {
      final phrases = await splitText(
        'ठीक है, मैं अलार्म सेट नहीं कर सकता, लेकिन आप कल सुबह सात बजे का '
        'अलार्म लगा लीजिए।',
      );
      expect(phrases, [
        'ठीक है,',
        'मैं अलार्म सेट नहीं कर सकता,',
        'लेकिन आप कल सुबह सात बजे का अलार्म',
        'लगा लीजिए।',
      ]);
    });

    test('schedule in Hinglish', () async {
      final phrases = await splitText(
        'हाँ, मैं आपका शेड्यूल नहीं देख सकता, पर अपनी अगली मीटिंग '
        'कैलेंडर में चेक कर लीजिए।',
      );
      expect(phrases.first, 'हाँ,');
      expect(phrases.join(' '), contains('मीटिंग'));
      expect(phrases.last.endsWith('।'), isTrue);
    });
  });
}
