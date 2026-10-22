enum Voice { hindi, english }

final _devanagari = RegExp(r'[ऀ-ॿ]');

Voice voiceFor(String phrase) =>
    _devanagari.hasMatch(phrase) ? Voice.hindi : Voice.english;
