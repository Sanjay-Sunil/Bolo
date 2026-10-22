import 'dart:typed_data';

/// One synthesized phrase, ready to play.
class TtsResult {
  const TtsResult({
    required this.pcm16,
    required this.sampleRate,
    required this.levels,
    required this.levelWindow,
    required this.synthMs,
  });

  /// Little-endian 16-bit mono PCM.
  final Uint8List pcm16;
  final int sampleRate;

  /// Visualizer levels, one row of bands per [levelWindow] samples.
  final Float32List levels;
  final int levelWindow;

  /// Time spent normalizing and synthesizing inside the TTS isolate.
  final int synthMs;

  int get frames => pcm16.length ~/ 2;

  Duration get duration =>
      Duration(microseconds: frames * 1000000 ~/ sampleRate);
}
