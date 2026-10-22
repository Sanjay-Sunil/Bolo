/// Events emitted by the segmenter. [lastVoiceSample] is the 16 kHz sample
/// index just after the last voiced frame of the current turn.
sealed class VadEvent {
  const VadEvent(this.lastVoiceSample);

  final int lastVoiceSample;
}

final class SpeechStart extends VadEvent {
  const SpeechStart(super.lastVoiceSample);
}

final class ShortPause extends VadEvent {
  const ShortPause(super.lastVoiceSample, this.pauseMs);

  final int pauseMs;
}

final class EndOfTurn extends VadEvent {
  const EndOfTurn(super.lastVoiceSample);
}
