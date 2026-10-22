import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bolo/audio/band_levels.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List tone(double hz, {int n = 512, int sr = 16000, double amp = 0.5}) =>
    Float32List.fromList([
      for (var i = 0; i < n; i++) amp * math.sin(2 * math.pi * hz * i / sr),
    ]);

void main() {
  final bands = BandLevels(sampleRate: 16000);

  test('silence is all zero', () {
    expect(bands.of(Float32List(512)).every((v) => v == 0), isTrue);
  });

  test('a low tone lights the low band, a high tone the high band', () {
    final low = bands.of(tone(150));
    final high = bands.of(tone(3500));
    expect(low.first, greaterThan(low.last));
    expect(high.last, greaterThan(high.first));
  });

  test('levels stay within 0..1', () {
    for (final v in bands.of(tone(1000, amp: 1))) {
      expect(v, inInclusiveRange(0, 1));
    }
  });

  test('track gives one row of bands per window', () {
    final t = bands.track(tone(500, n: 1300));
    expect(t.length, 3 * bands.bands);
  });
}
