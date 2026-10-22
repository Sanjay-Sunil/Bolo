import '../tts/piper_voice_files.dart';

/// Where the downloaded models live on the phone.
class ModelPaths {
  const ModelPaths(this.root);

  final String root;

  String get silero => '$root/silero_vad_v5.onnx';
  String get whisper => '$root/ggml-swift-q8_0.bin';

  PiperVoiceFiles get hindiVoice => _piper(
    'vits-piper-hi_IN-priyamvada-medium-int8',
    'hi_IN-priyamvada-medium.onnx',
  );

  PiperVoiceFiles get englishVoice =>
      _piper('vits-piper-en_US-lessac-medium-int8', 'en_US-lessac-medium.onnx');

  PiperVoiceFiles _piper(String dir, String model) => PiperVoiceFiles(
    model: '$root/$dir/$model',
    tokens: '$root/$dir/tokens.txt',
    espeakData: '$root/$dir/espeak-ng-data',
  );
}
