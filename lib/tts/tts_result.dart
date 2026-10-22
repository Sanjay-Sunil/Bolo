import 'tts_audio.dart';

/// Synthesized phrase plus how long normalize + synth took inside the isolate.
class TtsResult {
  const TtsResult(this.audio, this.synthMs);

  final TtsAudio audio;
  final int synthMs;
}
