import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'vad_detector.dart';

/// Silero v5 via sherpa-onnx, used only as a per-window speech/non-speech
/// flag: sherpa's own silence timing is set near zero so [Segmenter] owns
/// pause and end-of-turn timing.
class SileroVadDetector implements VadDetector {
  SileroVadDetector(String modelPath)
    : _vad = so.VoiceActivityDetector(
        config: so.VadModelConfig(
          sileroVad: so.SileroVadModelConfig(
            model: modelPath,
            threshold: 0.5,
            minSilenceDuration: 0.05,
            minSpeechDuration: 0.05,
            windowSize: windowSize,
          ),
          numThreads: 1,
          debug: false,
        ),
        bufferSizeInSeconds: 30,
      );

  static const windowSize = 512;

  final so.VoiceActivityDetector _vad;

  @override
  bool isSpeech(Float32List frame) {
    _vad.acceptWaveform(frame);
    final speech = _vad.isDetected();
    while (!_vad.isEmpty()) {
      _vad.pop();
    }
    return speech;
  }

  void reset() => _vad.reset();

  void dispose() => _vad.free();
}
