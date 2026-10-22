import 'package:bolo/tts/text_normalizer.dart';
import 'package:bolo/tts/voice.dart';
import 'package:flutter_test/flutter_test.dart';

String en(String s) => normalize(s, Voice.english);

String hi(String s, [List<String>? unknown]) =>
    normalize(s, Voice.hindi, onUnknownLatin: (w) => unknown?.addAll(w));

void main() {
  group('symbols and markdown', () {
    test('markdown emphasis, headings and code marks are removed', () {
      expect(en('**Sure**, here is the _plan_.'), 'Sure, here is the plan.');
      expect(en('# Weather `today`'), 'Weather today');
    });

    test('markdown links keep only their text', () {
      expect(
        en('See [the forecast](https://x.y/z) now.'),
        'See the forecast now.',
      );
    });

    test('emojis are removed, including joined sequences', () {
      expect(en('Great 👍🏽 job! ❤️'), 'Great job!');
      expect(en('Family 👨‍👩‍👧 time.'), 'Family time.');
      expect(hi('बहुत बढ़िया 😊।'), 'बहुत बढ़िया।');
    });

    test('dashes and colons become pauses, list bullets disappear', () {
      expect(
        en('- Carry an umbrella — it may rain.'),
        'Carry an umbrella, it may rain.',
      );
      expect(en('Note: bring water'), 'Note, bring water');
    });

    test('danda, hyphenated words and apostrophes survive', () {
      expect(hi('ठीक है, कल धूप रहेगी।'), 'ठीक है, कल धूप रहेगी।');
      expect(en("I can't check-in yet."), "I can't check-in yet.");
      expect(en('I can’t do that.'), "I can't do that.");
    });

    test('Devanagari conjuncts with joiners are kept', () {
      expect(hi('क्‍या'), 'क्‍या');
    });

    test('symbol-only text normalizes to empty', () {
      expect(en('*** 🎉 ***'), '');
    });
  });

  group('English numbers', () {
    test('cardinals, decimals and thousands separators', () {
      expect(en('It will be 28 degrees.'), 'It will be twenty eight degrees.');
      expect(en('About 2.5 km away.'), 'About two point five km away.');
      expect(
        en('That costs 1,500 rupees.'),
        'That costs one thousand five hundred rupees.',
      );
    });

    test('ordinals', () {
      expect(
        en('Your 1st and 22nd meetings.'),
        'Your first and twenty second meetings.',
      );
    });

    test('degrees', () {
      expect(
        en('High of 31°C, low of 20°.'),
        'High of thirty one degrees Celsius, low of twenty degrees.',
      );
      expect(hi('कल 28°C रहेगा।'), 'कल अट्ठाईस डिग्री सेल्सियस रहेगा।');
    });

    test('currency and percent', () {
      expect(en('It is ₹500.'), 'It is five hundred rupees.');
      expect(
        en('There is a 40% chance of rain.'),
        'There is a forty percent chance of rain.',
      );
    });

    test('long and zero-padded numbers are read digit by digit', () {
      expect(
        en('Call 9876543210.'),
        'Call nine eight seven six five four three two one zero.',
      );
      expect(en('Code 007.'), 'Code zero zero seven.');
    });
  });

  group('English times', () {
    test('times with AM and PM', () {
      expect(en('At 5:30 PM.'), 'At five thirty P M.');
      expect(en('At 7:05 am'), 'At seven oh five A M');
      expect(en('At 5 PM.'), 'At five P M.');
      expect(en('At 9 a.m. tomorrow'), 'At nine A M tomorrow');
    });

    test("whole hours without a period say o'clock", () {
      expect(en('The meeting is at 3:00.'), "The meeting is at three o'clock.");
    });

    test('24-hour times become 12-hour with a period', () {
      expect(en('Starts at 17:30.'), 'Starts at five thirty P M.');
    });

    test('a dotted time needs a period to count as a time', () {
      expect(en('At 5.30 pm'), 'At five thirty P M');
      expect(en('Rated 4.50 overall'), 'Rated four point five zero overall');
    });

    test('Latin Hinglish keeps baje', () {
      expect(en('Kal 7 baje'), 'Kal seven baje');
    });
  });

  group('Hindi numbers', () {
    test('digits become Hindi words', () {
      expect(hi('कल सुबह 7 बजे'), 'कल सुबह सात बजे');
      expect(hi('तापमान 28 डिग्री है।'), 'तापमान अट्ठाईस डिग्री है।');
      expect(hi('2026 में'), 'दो हज़ार छब्बीस में');
    });

    test('Devanagari digits are handled too', () {
      expect(hi('शाम ५ बजे'), 'शाम पाँच बजे');
    });

    test('digits glued to Devanagari get separated', () {
      expect(hi('5बजे'), 'पाँच बजे');
    });

    test('currency, percent and decimals', () {
      expect(hi('₹500 लगेंगे।'), 'पाँच सौ रुपये लगेंगे।');
      expect(hi('40% बारिश'), 'चालीस प्रतिशत बारिश');
      expect(hi('2.5 किलोमीटर'), 'दो दशमलव पाँच किलोमीटर');
    });
  });

  group('Hindi times', () {
    test('quarter and half hours use the spoken forms', () {
      expect(hi('मीटिंग 5:00 बजे है।'), 'मीटिंग पाँच बजे है।');
      expect(hi('मीटिंग 5:15 बजे है।'), 'मीटिंग सवा पाँच बजे है।');
      expect(hi('मीटिंग 5:30 बजे है।'), 'मीटिंग साढ़े पाँच बजे है।');
      expect(hi('मीटिंग 5:45 बजे है।'), 'मीटिंग पौने छह बजे है।');
      expect(hi('मीटिंग 5:30 है।'), 'मीटिंग साढ़े पाँच है।');
    });

    test('1:30 and 2:30 are irregular, 12:45 wraps to one', () {
      expect(hi('1:30 बजे'), 'डेढ़ बजे');
      expect(hi('2:30 बजे'), 'ढाई बजे');
      expect(hi('12:45 बजे'), 'पौने एक बजे');
    });

    test('other minutes use bajkar', () {
      expect(hi('5:10 बजे'), 'पाँच बजकर दस मिनट');
      expect(hi('17:20'), 'पाँच बजकर बीस मिनट');
    });

    test('AM and PM are spelled out', () {
      expect(hi('शाम 5 PM'), 'शाम पाँच पी एम');
      expect(hi('सुबह 7 am'), 'सुबह सात ए एम');
      expect(hi('5:30 PM पर'), 'साढ़े पाँच पी एम पर');
    });
  });

  group('Latin text inside Devanagari phrases', () {
    test('short acronyms are spelled with letter names', () {
      expect(hi('मेरा PNR देखिए'), 'मेरा पी एन आर देखिए');
      expect(hi('UPI से पेमेंट करें'), 'यू पी आई से पेमेंट करें');
      expect(hi('मेरा WIFI बंद है'), 'मेरा डब्ल्यू आई एफ़ आई बंद है');
    });

    test('common English words are respelled in Devanagari', () {
      final unknown = <String>[];
      expect(
        hi('आज का schedule थोड़ा busy है, lunch के बाद दो calls हैं।', unknown),
        'आज का शेड्यूल थोड़ा बिज़ी है, लंच के बाद दो कॉल्स हैं।',
      );
      expect(unknown, isEmpty);
    });

    test('loanwords ignore case', () {
      expect(hi('Meeting कब है?'), 'मीटिंग कब है?');
      expect(hi('OK, हो गया।'), 'ओके, हो गया।');
      expect(hi('okay'), 'ओके');
    });

    test('plurals of loanwords', () {
      expect(hi('दो tickets'), 'दो टिकट्स');
      expect(hi('तीन movies'), 'तीन मूवीज़');
      expect(hi('सारी classes'), 'सारी क्लासेज़');
    });

    test('Latin text inside a Devanagari word run is untouched', () {
      expect(hi('मीटिंग'), 'मीटिंग');
    });

    test('other Latin words are kept and reported', () {
      final unknown = <String>[];
      expect(hi('WhatsApp पर मैसेज भेजें', unknown), 'WhatsApp पर मैसेज भेजें');
      expect(unknown, ['WhatsApp']);
    });

    test('acronyms longer than five letters are kept and reported', () {
      final unknown = <String>[];
      hi('BANGALORE में', unknown);
      expect(unknown, ['BANGALORE']);
    });

    test('nothing is reported for a clean Devanagari phrase', () {
      final unknown = <String>[];
      hi('ठीक है, आपकी मीटिंग शाम पाँच बजे है।', unknown);
      expect(unknown, isEmpty);
    });

    test('Latin words in English phrases are never reported', () {
      var reported = false;
      normalize(
        'WhatsApp me',
        Voice.english,
        onUnknownLatin: (_) => reported = true,
      );
      expect(reported, isFalse);
    });
  });

  group('likely replies to the four test sentences', () {
    test('weather in English', () {
      expect(
        en(
          "Sure, I can't check live forecasts, but expect around 28°C tomorrow.",
        ),
        "Sure, I can't check live forecasts, but expect around twenty eight degrees Celsius tomorrow.",
      );
    });

    test('reminder in English', () {
      expect(
        en("Okay, I can't set reminders, but your meeting is at 5 PM."),
        "Okay, I can't set reminders, but your meeting is at five P M.",
      );
    });

    test('alarm in Hinglish', () {
      expect(
        hi('ठीक है, कल सुबह 7 बजे का अलार्म मैं सेट नहीं कर सकता।'),
        'ठीक है, कल सुबह सात बजे का अलार्म मैं सेट नहीं कर सकता।',
      );
    });

    test('schedule in Hinglish', () {
      final unknown = <String>[];
      expect(
        hi('हाँ, आपकी next मीटिंग 3:30 PM पर है।', unknown),
        'हाँ, आपकी नेक्स्ट मीटिंग साढ़े तीन पी एम पर है।',
      );
      expect(unknown, isEmpty);
    });
  });
}
