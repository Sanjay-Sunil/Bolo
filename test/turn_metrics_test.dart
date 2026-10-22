import 'package:bolo/pipeline/turn_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int v) => Duration(milliseconds: v);

TurnMetrics voiceTurn() => const TurnMetrics()
    .mark(TurnEvent.speechStart, ms(0))
    .mark(TurnEvent.lastVoice, ms(3000))
    .mark(TurnEvent.endOfTurn, ms(3400))
    .mark(TurnEvent.sttFinal, ms(3520))
    .mark(TurnEvent.llmRequest, ms(3530))
    .mark(TurnEvent.llmFirstToken, ms(3840))
    .mark(TurnEvent.firstPhraseReady, ms(3860))
    .mark(TurnEvent.firstAudio, ms(3930))
    .mark(TurnEvent.lastAudio, ms(6500));

void main() {
  test('computes stage durations from lastVoice', () {
    final m = voiceTurn();
    expect(m.eot, ms(400));
    expect(m.stt, ms(120));
    expect(m.llm, ms(310));
    expect(m.tts, ms(90));
    expect(m.total, ms(930));
  });

  test('summary matches the metrics bar format', () {
    expect(
      voiceTurn().summary(),
      'EoT 400 · STT 120 · LLM 310 · TTS 90 · total 930 ms',
    );
  });

  test('speculative replies are labelled', () {
    expect(
      voiceTurn().withSpeculative(true).summary(),
      contains('LLM 310 (spec)'),
    );
  });

  test(
    'typed turn measures total from the LLM request and omits voice stages',
    () {
      final m = const TurnMetrics()
          .mark(TurnEvent.llmRequest, ms(100))
          .mark(TurnEvent.llmFirstToken, ms(400))
          .mark(TurnEvent.firstAudio, ms(480));
      expect(m.eot, isNull);
      expect(m.stt, isNull);
      expect(m.total, ms(380));
      expect(m.summary(), 'LLM 300 · TTS 80 · total 380 ms');
    },
  );

  test('incomplete turn has partial summary and empty when unmarked', () {
    expect(const TurnMetrics().summary(), '');
    final m = const TurnMetrics()
        .mark(TurnEvent.lastVoice, ms(1000))
        .mark(TurnEvent.endOfTurn, ms(1250));
    expect(m.summary(), 'EoT 250 ms');
    expect(m.total, isNull);
  });

  test('mark does not mutate the original', () {
    const a = TurnMetrics();
    final b = a.mark(TurnEvent.speechStart, ms(5));
    expect(a[TurnEvent.speechStart], isNull);
    expect(b[TurnEvent.speechStart], ms(5));
  });

  test('round-trips through JSON', () {
    final m = voiceTurn().withSpeculative(true);
    final back = TurnMetrics.fromJson(m.toJson());
    for (final e in TurnEvent.values) {
      expect(back[e], m[e], reason: e.name);
    }
    expect(back.speculative, isTrue);
    expect(back.summary(), m.summary());
  });

  test('fromJson tolerates missing and unknown keys', () {
    final m = TurnMetrics.fromJson({
      'lastVoice': 1000000,
      'firstAudio': 1900000,
      'other': 'x',
    });
    expect(m.total, ms(900));
    expect(m.speculative, isFalse);
  });
}
