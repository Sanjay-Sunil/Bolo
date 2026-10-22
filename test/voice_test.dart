import 'package:bolo/tts/voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Devanagari text uses the Hindi voice', () {
    expect(voiceFor('ठीक है, आपकी मीटिंग शाम पाँच बजे है।'), Voice.hindi);
  });

  test('Latin text uses the English voice', () {
    expect(voiceFor('Sure, your meeting is at five PM.'), Voice.english);
  });

  test('a single Devanagari character is enough for the Hindi voice', () {
    expect(voiceFor('OK, ठीक'), Voice.hindi);
    expect(voiceFor('।'), Voice.hindi);
  });

  test('empty and symbol-only text default to the English voice', () {
    expect(voiceFor(''), Voice.english);
    expect(voiceFor('123 !?'), Voice.english);
  });
}
