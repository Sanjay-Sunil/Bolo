import 'dart:math' as math;
import 'dart:typed_data';

/// Loudness of a few voice frequency bands for one audio window, each 0..1.
/// Used to drive the visualizer bars; cheap enough for every 32 ms window.
class BandLevels {
  BandLevels({
    required this.sampleRate,
    this.size = 512,
    this.bands = 7,
    this.minHz = 90,
    this.maxHz = 5000,
    this.floorDb = -70,
    this.ceilDb = -15,
  }) : assert(size & (size - 1) == 0, 'size must be a power of two') {
    for (var i = 0; i < size; i++) {
      _window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
    }
    final binHz = sampleRate / size;
    final lo = math.log(minHz), hi = math.log(maxHz);
    for (var b = 0; b <= bands; b++) {
      final hz = math.exp(lo + (hi - lo) * b / bands);
      _edges.add((hz / binHz).round().clamp(1, size ~/ 2));
    }
  }

  final int sampleRate;
  final int size;
  final int bands;
  final double minHz;
  final double maxHz;
  final double floorDb;
  final double ceilDb;

  late final _window = Float64List(size);
  final _edges = <int>[];
  late final _re = Float64List(size);
  late final _im = Float64List(size);

  /// Levels for the first [size] samples of [samples] (zero-padded if short).
  Float32List of(Float32List samples, [int offset = 0]) {
    for (var i = 0; i < size; i++) {
      final j = offset + i;
      _re[i] = j < samples.length ? samples[j] * _window[i] : 0;
      _im[i] = 0;
    }
    _fft();
    final out = Float32List(bands);
    for (var b = 0; b < bands; b++) {
      final from = _edges[b], to = math.max(_edges[b + 1], from + 1);
      var power = 0.0;
      for (var k = from; k < to; k++) {
        power += _re[k] * _re[k] + _im[k] * _im[k];
      }
      power /= (to - from);
      final db = 10 * math.log(power / (size * size) + 1e-12) / math.ln10;
      out[b] = ((db - floorDb) / (ceilDb - floorDb)).clamp(0.0, 1.0);
    }
    return out;
  }

  /// Levels for consecutive [size]-sample windows of a whole clip, flattened
  /// (window-major), so playback can look up the bars for any moment.
  Float32List track(Float32List samples) {
    final windows = (samples.length / size).ceil();
    final out = Float32List(windows * bands);
    for (var w = 0; w < windows; w++) {
      out.setAll(w * bands, of(samples, w * size));
    }
    return out;
  }

  void _fft() {
    final n = size;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = _re[i], ti = _im[i];
        _re[i] = _re[j];
        _im[i] = _im[j];
        _re[j] = tr;
        _im[j] = ti;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang), wi = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var cr = 1.0, ci = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final ar = _re[i + k], ai = _im[i + k];
          final br = _re[i + k + len ~/ 2], bi = _im[i + k + len ~/ 2];
          final tr = br * cr - bi * ci, ti = br * ci + bi * cr;
          _re[i + k] = ar + tr;
          _im[i + k] = ai + ti;
          _re[i + k + len ~/ 2] = ar - tr;
          _im[i + k + len ~/ 2] = ai - ti;
          final ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = ncr;
        }
      }
    }
  }
}
