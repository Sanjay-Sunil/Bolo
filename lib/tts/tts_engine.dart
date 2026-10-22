import 'tts_audio.dart';
import 'voice.dart';

abstract interface class TtsEngine {
  /// Blocking; call only inside the TTS isolate.
  TtsAudio synthesize(String text, Voice voice);

  void dispose();
}
