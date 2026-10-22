/// Model files for one Piper voice (a sherpa-onnx VITS pack).
class PiperVoiceFiles {
  const PiperVoiceFiles({
    required this.model,
    required this.tokens,
    required this.espeakData,
  });

  final String model;
  final String tokens;
  final String espeakData;
}
