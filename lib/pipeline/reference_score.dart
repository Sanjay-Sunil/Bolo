import 'test_sentences.dart';
import 'wer.dart';

/// Accuracy of one transcript against the test sentence it matches.
class ReferenceScore {
  const ReferenceScore({
    required this.index,
    required this.wer,
    required this.cer,
  });

  /// 0-based index into [testSentences].
  final int index;
  final double wer;
  final double cer;

  /// The closest test sentence, if the transcript is close enough to one
  /// (CER at most [maxCer]) to be an attempt at saying it.
  static ReferenceScore? match(String transcript, {double maxCer = 0.5}) {
    const calc = WerCalculator();
    ReferenceScore? best;
    for (var i = 0; i < testSentences.length; i++) {
      final cer = calc.cer(testSentences[i], transcript).rate;
      if (cer <= maxCer && (best == null || cer < best.cer)) {
        best = ReferenceScore(
          index: i,
          wer: calc.wer(testSentences[i], transcript).rate,
          cer: cer,
        );
      }
    }
    return best;
  }

  String summary() =>
      'WER ${(wer * 100).round()}% · CER ${(cer * 100).round()}% '
      'vs test ${index + 1}';
}
