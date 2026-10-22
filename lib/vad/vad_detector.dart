import 'dart:typed_data';

abstract interface class VadDetector {
  bool isSpeech(Float32List frame);
}
