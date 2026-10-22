import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import '../app/app_clock.dart';

/// Gapless PCM16 playback. Phrases are queued back to back; [enqueue] returns
/// when each one is expected to start, so text and visuals can follow it.
class AudioPlayer {
  /// Rough Android output latency, added before the first sample is heard.
  static const outputLatency = Duration(milliseconds: 80);

  int? _sampleRate;
  Duration _endsAt = Duration.zero;

  /// When the queued audio finishes.
  Duration get endsAt => _endsAt;

  bool get playing => now < _endsAt;

  /// Queues [pcm16] and returns its expected start time on [appClock].
  Future<Duration> enqueue(
    Uint8List pcm16,
    int sampleRate,
    Duration duration,
  ) async {
    if (_sampleRate != sampleRate) {
      await FlutterPcmSound.release();
      await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
      _sampleRate = sampleRate;
      _endsAt = Duration.zero;
    }
    final t = now;
    final start = _endsAt > t ? _endsAt : t + outputLatency;
    _endsAt = start + duration;
    await FlutterPcmSound.feed(
      PcmArrayInt16(bytes: ByteData.sublistView(pcm16)),
    );
    return start;
  }

  /// Stops playback and drops anything queued.
  Future<void> stop() async {
    _endsAt = Duration.zero;
    _sampleRate = null;
    await FlutterPcmSound.release();
  }
}
