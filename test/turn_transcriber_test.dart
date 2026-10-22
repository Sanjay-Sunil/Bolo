import 'dart:async';
import 'dart:typed_data';

import 'package:bolo/stt/stt_result.dart';
import 'package:bolo/stt/turn_transcriber.dart';
import 'package:bolo/vad/piece.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List audio(int n) => Float32List(n);

/// Decoder whose calls stay pending until released; text is `len:N`.
class FakeDecoder {
  final calls = <int>[];
  final _pending = <Completer<SttResult>>[];

  Future<SttResult> call(Float32List a) {
    calls.add(a.length);
    final c = Completer<SttResult>();
    _pending.add(c);
    return c.future;
  }

  Future<void> releaseNext() async {
    final c = _pending.removeAt(0);
    c.complete(
      SttResult(
        text: 'len:${calls[calls.length - 1 - _pending.length]}',
        avgLogProb: -0.1,
      ),
    );
    await pumpEventQueue();
  }
}

Piece committed(int seq, int n, {bool last = false}) =>
    Piece(seq: seq, audio: audio(n), kind: PieceKind.committed, isLast: last);

Piece tentative(int seq, int n) =>
    Piece(seq: seq, audio: audio(n), kind: PieceKind.tentative);

void main() {
  test(
    'early final at a pause is reused when the turn ends silently',
    () async {
      final d = FakeDecoder();
      final t = TurnTranscriber(d.call);
      t.add(committed(0, 100));
      t.add(committed(1, 0, last: true));
      await d.releaseNext();
      final r = await t.finalResult;
      expect(r.text, 'len:100');
      expect(d.calls, [100]);
    },
  );

  test(
    'more speech after the pause means one more whole-turn decode',
    () async {
      final d = FakeDecoder();
      final t = TurnTranscriber(d.call);
      t.add(committed(0, 100));
      t.add(committed(1, 50, last: true));
      await d.releaseNext();
      await d.releaseNext();
      expect((await t.finalResult).text, 'len:150');
      expect(d.calls, [100, 150]);
    },
  );

  test(
    'live requests keep only the newest and include committed audio',
    () async {
      final d = FakeDecoder();
      final t = TurnTranscriber(d.call);
      final live = <String>[];
      t.live.listen(live.add);
      t.add(tentative(0, 10));
      t.add(tentative(0, 20));
      t.add(tentative(0, 30));
      await d.releaseNext();
      await d.releaseNext();
      expect(d.calls, [10, 30]);
      expect(live, ['len:10', 'len:30']);
    },
  );

  test('final jumps ahead of a queued live request', () async {
    final d = FakeDecoder();
    final t = TurnTranscriber(d.call);
    t.add(tentative(0, 10));
    t.add(tentative(0, 40));
    t.add(committed(0, 60, last: true));
    await d.releaseNext();
    await d.releaseNext();
    expect(d.calls, [10, 60]);
    expect((await t.finalResult).text, 'len:60');
  });

  test('a turn with no speech completes empty without decoding', () async {
    final d = FakeDecoder();
    final t = TurnTranscriber(d.call);
    t.add(committed(0, 0, last: true));
    expect((await t.finalResult).text, '');
    expect(d.calls, isEmpty);
  });

  test('reset discards in-flight results', () async {
    final d = FakeDecoder();
    final t = TurnTranscriber(d.call);
    final live = <String>[];
    t.live.listen(live.add);
    t.add(tentative(0, 10));
    t.reset();
    await d.releaseNext();
    expect(live, isEmpty);
  });

  test('older results never replace newer live text', () async {
    final d = FakeDecoder();
    final t = TurnTranscriber(d.call);
    final live = <String>[];
    t.live.listen(live.add);
    t.add(committed(0, 100));
    t.add(tentative(1, 20));
    await d.releaseNext();
    await d.releaseNext();
    expect(live, ['len:100', 'len:120']);
  });
}
