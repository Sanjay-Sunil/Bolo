import 'dart:async';
import 'dart:typed_data';

import '../vad/piece.dart';
import 'stt_result.dart';

typedef Decode = Future<SttResult> Function(Float32List audio);

/// Transcribes one turn by decoding the whole turn audio so far.
///
/// With Swift's 500-frame window floor (G4) a decode of up to 10 s costs the
/// same as a short piece, so whole-turn decodes are as fast as piece decodes
/// and more accurate. Three kinds of request share one decoder:
/// - final (end of turn): highest priority;
/// - early final (at each short pause): if the turn then ends with no more
///   speech, it already is the final transcript;
/// - live (while speaking): only the newest is kept.
class TurnTranscriber {
  TurnTranscriber(this._decode);

  final Decode _decode;
  final _live = StreamController<String>.broadcast();
  final _committed = <Float32List>[];
  int _committedLength = 0;

  final _byLength = <int, Future<SttResult>>{};
  final _queue = <_Request>[];
  _Request? _latestLive;
  bool _busy = false;
  int _generation = 0;
  int _shownLength = -1;
  Completer<SttResult> _final = Completer<SttResult>();

  /// Best transcript of the turn so far, for display while speaking.
  Stream<String> get live => _live.stream;

  /// Completes once per turn, after the last piece.
  Future<SttResult> get finalResult => _final.future;

  void add(Piece piece) {
    if (piece.kind == PieceKind.tentative) {
      final audio = _join(piece.audio);
      _latestLive = _Request(audio, live: true, generation: _generation);
      _pump();
      return;
    }
    if (piece.audio.isNotEmpty) {
      _committed.add(piece.audio);
      _committedLength += piece.audio.length;
    }
    if (piece.isLast) {
      _finish();
    } else if (piece.audio.isNotEmpty) {
      _request(_committedLength, _join());
    }
  }

  /// Starts a new turn; pending and in-flight results are discarded.
  void reset() {
    _generation++;
    _committed.clear();
    _committedLength = 0;
    _byLength.clear();
    _queue.clear();
    _latestLive = null;
    _shownLength = -1;
    if (!_final.isCompleted) {
      _final.complete(const SttResult(text: '', avgLogProb: 0));
    }
    _final = Completer<SttResult>();
  }

  /// All committed audio of the current turn.
  Float32List get turnAudio => _join();

  Future<void> close() => _live.close();

  void _finish() {
    final done = _final;
    if (_committedLength == 0) {
      done.complete(const SttResult(text: '', avgLogProb: 0));
      return;
    }
    _latestLive = null;
    final result = _request(_committedLength, _join(), front: true);
    final generation = _generation;
    result.then(
      (r) {
        if (generation == _generation && !done.isCompleted) done.complete(r);
      },
      onError: (Object e, StackTrace st) {
        if (generation == _generation && !done.isCompleted) {
          done.completeError(e, st);
        }
      },
    );
  }

  Future<SttResult> _request(
    int length,
    Float32List audio, {
    bool front = false,
  }) {
    final existing = _byLength[length];
    if (existing != null) {
      if (front) {
        final i = _queue.indexWhere((r) => r.audio.length == length);
        if (i > 0) _queue.insert(0, _queue.removeAt(i));
      }
      return existing;
    }
    final request = _Request(audio, live: false, generation: _generation);
    _byLength[length] = request.done.future;
    if (front) {
      _queue.insert(0, request);
    } else {
      _queue.add(request);
    }
    _pump();
    return request.done.future;
  }

  void _pump() {
    if (_busy) return;
    final _Request request;
    if (_queue.isNotEmpty) {
      request = _queue.removeAt(0);
    } else if (_latestLive != null) {
      request = _latestLive!;
      _latestLive = null;
    } else {
      return;
    }
    _busy = true;
    unawaited(_run(request));
  }

  Future<void> _run(_Request request) async {
    try {
      final result = await _decode(request.audio);
      if (request.generation == _generation &&
          request.audio.length > _shownLength &&
          result.text.isNotEmpty) {
        _shownLength = request.audio.length;
        _live.add(result.text);
      }
      request.done.complete(result);
    } catch (e, st) {
      // Errors only matter for the final transcript, which listens itself.
      request.done.future.ignore();
      request.done.completeError(e, st);
    } finally {
      _busy = false;
      _pump();
    }
  }

  Float32List _join([Float32List? tail]) {
    final out = Float32List(_committedLength + (tail?.length ?? 0));
    var offset = 0;
    for (final c in _committed) {
      out.setAll(offset, c);
      offset += c.length;
    }
    if (tail != null) out.setAll(offset, tail);
    return out;
  }
}

class _Request {
  _Request(this.audio, {required this.live, required this.generation});

  final Float32List audio;
  final bool live;
  final int generation;
  final done = Completer<SttResult>();
}
