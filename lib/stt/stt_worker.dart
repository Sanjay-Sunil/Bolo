import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import '../vad/piece.dart';
import 'piece_text.dart';
import 'stt_engine.dart';
import 'stt_result.dart';

/// Decodes pieces one at a time. Committed pieces run in seq order and take
/// priority; only the newest tentative piece is kept.
class SttWorker {
  SttWorker(this._engine);

  final SttEngine _engine;
  final _results = StreamController<PieceText>.broadcast();

  final _committedQueue = SplayTreeMap<int, Piece>();
  Piece? _tentative;
  bool _busy = false;
  int _generation = 0;
  final Set<int> _seenCommitted = {};
  int _nextSeq = 0;

  final List<String> _texts = [];
  double _weightedLogProb = 0;
  int _weightedSamples = 0;
  Completer<String> _final = Completer<String>();

  Stream<PieceText> get results => _results.stream;

  String get committed => _texts.join(' ');

  /// exp of the length-weighted mean log-prob over committed pieces.
  double? get confidence => _weightedSamples == 0
      ? null
      : math.exp(_weightedLogProb / _weightedSamples);

  /// Completes with the joined transcript once the last piece is decoded.
  Future<String> finalTranscript() => _final.future;

  void submit(Piece piece) {
    if (piece.kind == PieceKind.committed) {
      if (!_seenCommitted.add(piece.seq)) return;
      _committedQueue[piece.seq] = piece;
      if (_tentative != null && _isStale(_tentative!)) _tentative = null;
    } else {
      if (_isStale(piece)) return;
      _tentative = piece;
    }
    _pump();
  }

  /// Starts a new turn; results of in-flight decodes are discarded.
  void reset() {
    _generation++;
    if (!_final.isCompleted) _final.complete(committed);
    _final = Completer<String>();
    _committedQueue.clear();
    _tentative = null;
    _seenCommitted.clear();
    _nextSeq = 0;
    _texts.clear();
    _weightedLogProb = 0;
    _weightedSamples = 0;
  }

  Future<void> close() => _results.close();

  void _pump() {
    if (_busy) return;
    final Piece piece;
    if (_committedQueue.isNotEmpty && _committedQueue.firstKey() == _nextSeq) {
      piece = _committedQueue.remove(_nextSeq)!;
      _nextSeq++;
    } else if (_tentative != null && !_isStale(_tentative!)) {
      piece = _tentative!;
      _tentative = null;
    } else {
      return;
    }
    _busy = true;
    unawaited(_run(piece, _generation));
  }

  Future<void> _run(Piece piece, int generation) async {
    try {
      if (piece.kind == PieceKind.committed) {
        await _decodeCommitted(piece, generation);
      } else {
        await _decodeTentative(piece, generation);
      }
    } finally {
      _busy = false;
      _pump();
    }
  }

  Future<void> _decodeCommitted(Piece piece, int generation) async {
    SttResult? result;
    if (piece.audio.isNotEmpty) {
      try {
        result = await _engine.decode(piece.audio, prompt: _prompt());
      } catch (e, st) {
        if (generation == _generation) _results.addError(e, st);
      }
    }
    if (generation != _generation) return;

    final text = result?.text.trim() ?? '';
    if (result != null && text.isNotEmpty) {
      _texts.add(text);
      _weightedLogProb += result.avgLogProb * piece.audio.length;
      _weightedSamples += piece.audio.length;
    }
    if (result != null) {
      _results.add(
        PieceText(
          seq: piece.seq,
          text: text,
          confidence: math.exp(result.avgLogProb),
          kind: PieceKind.committed,
        ),
      );
    }
    if (piece.isLast && !_final.isCompleted) _final.complete(committed);
  }

  Future<void> _decodeTentative(Piece piece, int generation) async {
    final SttResult result;
    try {
      result = await _engine.decode(piece.audio, prompt: _prompt());
    } catch (e, st) {
      if (generation == _generation) _results.addError(e, st);
      return;
    }
    if (generation != _generation || _isStale(piece)) return;
    _results.add(
      PieceText(
        seq: piece.seq,
        text: result.text.trim(),
        confidence: math.exp(result.avgLogProb),
        kind: PieceKind.tentative,
      ),
    );
  }

  /// A tentative piece is stale once its seq (or a later one) is committed.
  bool _isStale(Piece tentative) =>
      _seenCommitted.any((seq) => seq >= tentative.seq);

  String? _prompt() => _texts.isEmpty ? null : committed;
}
