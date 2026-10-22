import 'dart:typed_data';

class TtsAudio {
  const TtsAudio(this.samples, this.sampleRate);

  final Float32List samples;
  final int sampleRate;
}
