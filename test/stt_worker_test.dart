import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bolo/stt/piece_text.dart';
import 'package:bolo/stt/stt_engine.dart';
import 'package:bolo/stt/stt_result.dart';
import 'package:bolo/stt/stt_worker.dart';
import 'package:bolo/vad/piece.dart';
import 'package:flutter_test/flutter_test.dart';

class Call {
  Call(this.audio, this.prompt);
  final Float32List audio;
  final String? prompt;
  final completer = Completer<SttResult>();

  void reply(String text, [double logProb = -0.1]) =>
      completer.complete(SttResult(text: text, avgLogProb: logProb));
}

class FakeEngine implements SttEngine {
  final calls = <Call>[];

  @override
  Future<SttResult> decode(Float32List audio, {String? prompt}) {
    final c = Call(audio, prompt);
    calls.add(c);
    return c.completer.future;
  }
}

Piece committed(int seq, int len, {bool last = false}) => Piece(
  seq: seq,
  audio: Float32List(len),
  kind: PieceKind.committed,
  isLast: last,
);

Piece tentative(int seq, int len) =>
    Piece(seq: seq, audio: Float32List(len), kind: PieceKind.tentative);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeEngine engine;
  late SttWorker worker;
  late List<PieceText> results;
  late List<Object> errors;

  setUp(() {
    engine = FakeEngine();
    worker = SttWorker(engine);
    results = [];
    errors = [];
    worker.results.listen(results.add, onError: errors.add);
  });

  test(
    'decodes one at a time in seq order with committed text as prompt',
    () async {
      worker
        ..submit(committed(0, 100))
        ..submit(committed(1, 200));
      expect(engine.calls, hasLength(1));
      expect(engine.calls[0].prompt, isNull);

      engine.calls[0].reply(' Mujhe kal ');
      await flush();
      expect(engine.calls, hasLength(2));
      expect(engine.calls[1].prompt, 'Mujhe kal');
      engine.calls[1].reply('subah alarm');
      await flush();
      expect(worker.committed, 'Mujhe kal subah alarm');
      expect(results.map((r) => r.seq), [0, 1]);
    },
  );

  test('waits for a missing seq instead of decoding out of order', () async {
    worker.submit(committed(1, 200));
    expect(engine.calls, isEmpty);
    worker.submit(committed(0, 100));
    expect(engine.calls.single.audio.length, 100);
  });

  test(
    'committed pieces take priority over tentative; stale results dropped',
    () async {
      worker.submit(tentative(0, 50));
      expect(engine.calls, hasLength(1));
      worker
        ..submit(committed(0, 100))
        ..submit(tentative(1, 70));

      engine.calls[0].reply('stale');
      await flush();
      expect(results, isEmpty); // seq 0 tentative is stale after commit
      expect(engine.calls[1].audio.length, 100);

      engine.calls[1].reply('hello');
      await flush();
      expect(engine.calls[2].audio.length, 70);
      engine.calls[2].reply('wor');
      await flush();
      expect(results.last.kind, PieceKind.tentative);
      expect(results.last.text, 'wor');
    },
  );

  test('only the newest tentative is kept', () async {
    worker.submit(committed(0, 100));
    worker
      ..submit(tentative(1, 10))
      ..submit(tentative(1, 20))
      ..submit(tentative(1, 30));
    engine.calls[0].reply('a');
    await flush();
    expect(engine.calls, hasLength(2));
    expect(engine.calls[1].audio.length, 30);
    engine.calls[1].reply('b');
    await flush();
    expect(engine.calls, hasLength(2));
  });

  test(
    'final transcript joins pieces and completes on the last piece',
    () async {
      final done = worker.finalTranscript();
      worker
        ..submit(committed(0, 100))
        ..submit(committed(1, 100))
        ..submit(committed(2, 0, last: true));
      engine.calls[0].reply('  what is ');
      await flush();
      engine.calls[1].reply('the weather ');
      await flush();
      expect(engine.calls, hasLength(2)); // empty last piece is not decoded
      expect(await done, 'what is the weather');
    },
  );

  test('confidence is exp of the length-weighted mean log-prob', () async {
    worker
      ..submit(committed(0, 100))
      ..submit(committed(1, 300, last: true));
    engine.calls[0].reply('a', -0.1);
    await flush();
    engine.calls[1].reply('b', -0.5);
    await flush();
    expect(worker.confidence, closeTo(math.exp(-0.4), 1e-9));
    expect(results[1].confidence, closeTo(math.exp(-0.5), 1e-9));
  });

  test('reset discards in-flight results and starts fresh', () async {
    worker.submit(committed(0, 100));
    worker.reset();
    engine.calls[0].reply('old turn');
    await flush();
    expect(results, isEmpty);
    expect(worker.committed, isEmpty);

    worker.submit(committed(0, 40, last: true));
    await flush();
    engine.calls[1].reply('new turn');
    expect(await worker.finalTranscript(), 'new turn');
  });

  test(
    'engine errors surface on the stream and do not stall the turn',
    () async {
      final done = worker.finalTranscript();
      worker
        ..submit(committed(0, 100))
        ..submit(committed(1, 100, last: true));
      engine.calls[0].completer.completeError(StateError('boom'));
      await flush();
      expect(errors, hasLength(1));
      engine.calls[1].reply('still here');
      expect(await done, 'still here');
    },
  );
}
