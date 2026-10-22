import 'dart:typed_data';

/// A reply phrase as it is played: text to reveal, when, and its levels.
class SpokenPhrase {
  const SpokenPhrase({
    required this.text,
    required this.start,
    required this.duration,
    required this.levels,
    required this.levelWindow,
    required this.sampleRate,
  });

  /// Display text (Roman Hinglish or English).
  final String text;

  /// Start and length on the app clock.
  final Duration start;
  final Duration duration;

  final Float32List levels;
  final int levelWindow;
  final int sampleRate;

  Duration get end => start + duration;

  /// 0..1 progress through this phrase at [t].
  double progressAt(Duration t) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start).inMicroseconds / duration.inMicroseconds;
  }

  /// Visualizer levels being played at [t], or null outside the phrase.
  Float32List? levelsAt(Duration t, int bands) {
    if (t < start || t >= end) return null;
    final sample = (t - start).inMicroseconds * sampleRate ~/ 1000000;
    final row = sample ~/ levelWindow;
    final offset = row * bands;
    if (offset + bands > levels.length) return null;
    return Float32List.sublistView(levels, offset, offset + bands);
  }
}
