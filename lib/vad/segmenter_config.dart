class SegmenterConfig {
  const SegmenterConfig({
    this.sampleRate = 16000,
    this.shortPauseMs = 200,
    this.minSpeechMs = 250,
    this.endOfTurnMs = 400,
    this.tentativeIntervalMs = 700,
    this.maxPieceMs = 10000,
    this.preRollMs = 100,
  });

  final int sampleRate;
  final int shortPauseMs;
  final int minSpeechMs;
  final int endOfTurnMs;
  final int tentativeIntervalMs;
  final int maxPieceMs;
  final int preRollMs;

  int samples(int ms) => ms * sampleRate ~/ 1000;
}
