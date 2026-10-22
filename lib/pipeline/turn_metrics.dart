enum TurnEvent {
  speechStart,
  lastVoice,
  endOfTurn,
  sttFinal,
  llmRequest,
  llmFirstToken,
  firstPhraseReady,
  firstAudio,
  lastAudio,
}

/// Timestamps of one turn as offsets on a monotonic clock owned by the caller.
class TurnMetrics {
  const TurnMetrics({this._marks = const {}, this.speculative = false});

  final Map<TurnEvent, Duration> _marks;

  /// True when the reply came from a speculative LLM request sent before the
  /// end of the turn.
  final bool speculative;

  Duration? operator [](TurnEvent e) => _marks[e];

  TurnMetrics mark(TurnEvent e, Duration at) =>
      TurnMetrics(marks: {..._marks, e: at}, speculative: speculative);

  TurnMetrics withSpeculative(bool value) =>
      TurnMetrics(marks: _marks, speculative: value);

  Duration? _between(TurnEvent from, TurnEvent to) {
    final a = _marks[from], b = _marks[to];
    return a == null || b == null ? null : b - a;
  }

  Duration? get eot => _between(TurnEvent.lastVoice, TurnEvent.endOfTurn);
  Duration? get stt => _between(TurnEvent.endOfTurn, TurnEvent.sttFinal);
  Duration? get llm => _between(TurnEvent.llmRequest, TurnEvent.llmFirstToken);
  Duration? get tts => _between(TurnEvent.llmFirstToken, TurnEvent.firstAudio);

  /// Last voiced frame to first audio. Typed turns have no voice, so they
  /// are measured from the LLM request.
  Duration? get total => _marks.containsKey(TurnEvent.lastVoice)
      ? _between(TurnEvent.lastVoice, TurnEvent.firstAudio)
      : _between(TurnEvent.llmRequest, TurnEvent.firstAudio);

  /// One-line breakdown shown under each reply, e.g.
  /// `EoT 400 · STT 120 · LLM 310 · TTS 90 · total 920 ms`.
  String summary() {
    String ms(Duration d) => '${d.inMilliseconds}';
    final parts = <String>[
      if (eot != null) 'EoT ${ms(eot!)}',
      if (stt != null) 'STT ${ms(stt!)}',
      if (llm != null) 'LLM ${ms(llm!)}${speculative ? ' (spec)' : ''}',
      if (tts != null) 'TTS ${ms(tts!)}',
      if (total != null) 'total ${ms(total!)}',
    ];
    return parts.isEmpty ? '' : '${parts.join(' · ')} ms';
  }

  Map<String, Object> toJson() => {
    for (final e in _marks.entries) e.key.name: e.value.inMicroseconds,
    if (speculative) 'speculative': true,
  };

  factory TurnMetrics.fromJson(Map<String, Object?> json) {
    final marks = <TurnEvent, Duration>{};
    for (final e in TurnEvent.values) {
      final v = json[e.name];
      if (v is num) marks[e] = Duration(microseconds: v.toInt());
    }
    return TurnMetrics(marks: marks, speculative: json['speculative'] == true);
  }
}
