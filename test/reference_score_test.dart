import 'package:bolo/pipeline/reference_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an exact test sentence scores zero', () {
    final s = ReferenceScore.match(
      'Mujhe kal subah 7 baje ka alarm set karna hai.',
    )!;
    expect(s.index, 2);
    expect(s.wer, 0);
    expect(s.cer, 0);
  });

  test('a misheard attempt matches the right sentence', () {
    final s = ReferenceScore.match(
      'Is the weather forecast for bangaar tomorrow?',
    )!;
    expect(s.index, 0);
    expect(s.wer, closeTo(2 / 8, 1e-9));
  });

  test('unrelated speech is not scored', () {
    expect(ReferenceScore.match('Tell me a joke about cats'), isNull);
  });

  test('summary', () {
    const s = ReferenceScore(index: 3, wer: 0.0909, cer: 0.019);
    expect(s.summary(), 'WER 9% · CER 2% vs test 4');
  });
}
