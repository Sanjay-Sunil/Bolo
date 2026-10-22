import 'package:bolo/text/roman_hinglish.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typical reply', () {
    expect(
      romanHinglish('ठीक है, आपकी मीटिंग शाम पाँच बजे है।'),
      'Theek hai, aapki meeting shaam paanch baje hai.',
    );
  });

  test('alarm reply with digits kept', () {
    expect(
      romanHinglish('कल सुबह 7 बजे का अलार्म सेट कर दिया है।'),
      'Kal subah 7 baje ka alarm set kar diya hai.',
    );
  });

  test('schwa deletion inside and at the end of words', () {
    expect(romanHinglish('करना'), 'Karna');
    expect(romanHinglish('समझना'), 'Samajhna');
    expect(romanHinglish('बदलना'), 'Badalna');
    expect(romanHinglish('घर'), 'Ghar');
  });

  test('loanwords and their plurals come back in English spelling', () {
    expect(romanHinglish('दो कॉल्स और तीन मूवीज़'), 'Do calls aur teen movies');
    expect(romanHinglish('ओके'), 'Okay');
  });

  test('loanwords match with or without the nukta', () {
    expect(romanHinglish('ऑफिस'), 'Office');
    expect(romanHinglish('ऑफ़िस'), 'Office');
    expect(romanHinglish('ऑ\u095eिस'), 'Office');
  });

  test('nukta letters', () {
    expect(romanHinglish('ज़रूर'), 'Zaroor');
    expect(romanHinglish('पढ़ना'), 'Parhna');
  });

  test('anusvara before a labial becomes m', () {
    expect(romanHinglish('कंप्यूटर'), 'Computer');
    expect(romanHinglish('संभव'), 'Sambhav');
  });

  test('sentence capitalisation and Devanagari digits', () {
    expect(romanHinglish('हाँ। ठीक है? ५ बजे'), 'Haan. Theek hai? 5 baje');
  });

  test('a phrase that continues a sentence is not capitalised', () {
    expect(
      romanHinglish('लेकिन फ़ोन के क्लॉक ऐप में', capitalize: false),
      'lekin phone ke clock app mein',
    );
  });

  test('markdown emphasis is removed', () {
    expect(
      romanHinglish("Here's the word: **developer**."),
      "Here's the word: developer.",
    );
    expect(romanHinglish('*ज़रूर*'), 'Zaroor');
  });

  test('Latin text passes through', () {
    expect(
      romanHinglish('Sure, your meeting is at 5 PM.'),
      'Sure, your meeting is at 5 PM.',
    );
  });
}
