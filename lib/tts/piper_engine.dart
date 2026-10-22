import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'piper_voice_files.dart';
import 'tts_audio.dart';
import 'tts_engine.dart';
import 'voice.dart';

/// Piper via sherpa-onnx: one model for Devanagari, one for English (G3).
class PiperEngine implements TtsEngine {
  PiperEngine({
    required PiperVoiceFiles hindi,
    required PiperVoiceFiles english,
    required int threads,
  }) : _hindi = _load(hindi, threads),
       _english = _load(english, threads);

  final so.OfflineTts _hindi;
  final so.OfflineTts _english;

  static so.OfflineTts _load(PiperVoiceFiles f, int threads) => so.OfflineTts(
    so.OfflineTtsConfig(
      model: so.OfflineTtsModelConfig(
        vits: so.OfflineTtsVitsModelConfig(
          model: f.model,
          tokens: f.tokens,
          dataDir: f.espeakData,
        ),
        numThreads: threads,
        debug: false,
      ),
    ),
  );

  @override
  TtsAudio synthesize(String text, Voice voice) {
    final audio = (voice == Voice.hindi ? _hindi : _english).generate(
      text: text,
    );
    return TtsAudio(audio.samples, audio.sampleRate);
  }

  @override
  void dispose() {
    _hindi.free();
    _english.free();
  }
}
