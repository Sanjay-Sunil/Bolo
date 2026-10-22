import 'dart:typed_data';

import 'package:bolo/vad/piece.dart';
import 'package:bolo/vad/segmenter.dart';
import 'package:bolo/vad/vad_detector.dart';
import 'package:bolo/vad/vad_event.dart';
import 'package:flutter_test/flutter_test.dart';

const frameLen = 512; // 32 ms at 16 kHz

class ValueDetector implements VadDetector {
  @override
  bool isSpeech(Float32List frame) => frame[0] > 0.5;
}

class Harness {
  Harness({int Function()? endOfTurnMs})
    : seg = Segmenter(ValueDetector(), endOfTurnMs: endOfTurnMs) {
    seg.events.listen(events.add);
    seg.pieces.listen(pieces.add);
  }

  final Segmenter seg;
  final events = <VadEvent>[];
  final pieces = <Piece>[];
  int framesFed = 0;

  void speech(int frames) => _feed(frames, 1.0);
  void silence(int frames) => _feed(frames, 0.0);

  void _feed(int frames, double v) {
    for (var i = 0; i < frames; i++) {
      seg.addFrame(Float32List(frameLen)..fillRange(0, frameLen, v));
      framesFed++;
    }
  }

  List<Piece> get committed =>
      pieces.where((p) => p.kind == PieceKind.committed).toList();
  List<Piece> get tentative =>
      pieces.where((p) => p.kind == PieceKind.tentative).toList();
}

int speechSamples(Float32List a) => a.where((v) => v > 0.5).length;

void main() {
  test('silence only produces nothing', () {
    final h = Harness()..silence(100);
    expect(h.events, isEmpty);
    expect(h.pieces, isEmpty);
  });

  test('blip shorter than min speech is ignored', () {
    final h = Harness()
      ..speech(5)
      ..silence(20);
    expect(h.events, isEmpty);
    expect(h.pieces, isEmpty);
  });

  test(
    'one utterance: start, pause cut, end of turn with empty last piece',
    () {
      final h = Harness()
        ..silence(10)
        ..speech(30)
        ..silence(20);

      expect(h.events.map((e) => e.runtimeType).toList(), [
        SpeechStart,
        ShortPause,
        EndOfTurn,
      ]);
      final pause = h.events[1] as ShortPause;
      expect(pause.pauseMs, 7 * frameLen * 1000 ~/ 16000);
      expect(h.events.last.lastVoiceSample, 40 * frameLen);

      final c = h.committed;
      expect(c.map((p) => p.seq), [0, 1]);
      expect(c[0].isLast, isFalse);
      expect(speechSamples(c[0].audio), 30 * frameLen);
      // ~100 ms of pre-roll silence before the first voiced sample.
      final firstVoice = c[0].audio.indexWhere((v) => v > 0.5);
      expect(firstVoice, greaterThanOrEqualTo(1600));
      expect(firstVoice, lessThan(1600 + frameLen));
      expect(c[1].isLast, isTrue);
      expect(c[1].audio, isEmpty);
    },
  );

  test('pause between phrases cuts two pieces in order', () {
    final h = Harness()
      ..speech(20)
      ..silence(8)
      ..speech(20)
      ..silence(20);

    final c = h.committed;
    expect(c.map((p) => p.seq), [0, 1, 2]);
    expect(speechSamples(c[0].audio), 20 * frameLen);
    expect(speechSamples(c[1].audio), 20 * frameLen);
    expect(c[2].isLast, isTrue);
    expect(h.events.whereType<EndOfTurn>(), hasLength(1));
  });

  test('a gap shorter than the short pause does not cut', () {
    final h = Harness()
      ..speech(20)
      ..silence(4)
      ..speech(20)
      ..silence(20);
    expect(speechSamples(h.committed.first.audio), 40 * frameLen);
  });

  test('long speech without pause is force-cut at ~10 s', () {
    final h = Harness()..speech(400);
    final c = h.committed;
    expect(c, hasLength(1));
    expect(c[0].isLast, isFalse);
    expect(c[0].audio.length, greaterThanOrEqualTo(160000));
    expect(h.events.whereType<EndOfTurn>(), isEmpty);
  });

  test('tentative snapshots every ~0.7 s of the in-progress piece', () {
    final h = Harness()..speech(60);
    final t = h.tentative;
    expect(t, hasLength(2));
    expect(t.every((p) => p.seq == 0), isTrue);
    expect(t[1].audio.length, greaterThan(t[0].audio.length));
    expect(h.committed, isEmpty);
  });

  test('end-of-turn delay comes from the getter (adaptive)', () {
    var eot = 250;
    final h = Harness(endOfTurnMs: () => eot)..speech(20);
    var silent = 0;
    while (h.events.whereType<EndOfTurn>().isEmpty) {
      h.silence(1);
      silent++;
    }
    expect(silent, 8); // 250 ms = 7.8 frames

    eot = 500;
    h.speech(20);
    silent = 0;
    while (h.events.whereType<EndOfTurn>().length < 2) {
      h.silence(1);
      silent++;
    }
    expect(silent, 16); // 500 ms = 15.6 frames
  });

  test('forceEndOfTurn emits the in-progress audio as the last piece', () {
    final h = Harness()..speech(20);
    h.seg.forceEndOfTurn();
    expect(h.events.last, isA<EndOfTurn>());
    final last = h.committed.single;
    expect(last.isLast, isTrue);
    expect(speechSamples(last.audio), 20 * frameLen);
    expect(h.seg.inTurn, isFalse);
  });

  test('a blip inside the turn after a cut is dropped', () {
    final h = Harness()
      ..speech(20)
      ..silence(8)
      ..speech(3)
      ..silence(20);
    final c = h.committed;
    expect(c.map((p) => p.seq), [0, 1]);
    expect(c[1].isLast, isTrue);
    expect(c[1].audio, isEmpty);
  });

  test('a new turn restarts seq at 0', () {
    final h = Harness()
      ..speech(20)
      ..silence(20);
    h.pieces.clear();
    h
      ..speech(20)
      ..silence(20);
    expect(h.committed.first.seq, 0);
    expect(h.events.whereType<SpeechStart>(), hasLength(2));
  });
}
