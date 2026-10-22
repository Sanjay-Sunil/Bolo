import 'dart:async';
import 'dart:typed_data';

import 'piece.dart';
import 'segmenter_config.dart';
import 'vad_detector.dart';
import 'vad_event.dart';

/// Turns a stream of 16 kHz frames into turn events and pieces cut at pauses.
class Segmenter {
  Segmenter(
    this._detector, {
    this.config = const SegmenterConfig(),
    int Function()? endOfTurnMs,
  }) : _endOfTurnMs = endOfTurnMs ?? (() => config.endOfTurnMs) {
    _preRoll = _AudioBuffer();
    _piece = _AudioBuffer();
  }

  final VadDetector _detector;
  final SegmenterConfig config;
  final int Function() _endOfTurnMs;

  final _events = StreamController<VadEvent>.broadcast(sync: true);
  final _pieces = StreamController<Piece>.broadcast(sync: true);

  late _AudioBuffer _preRoll;
  late _AudioBuffer _piece;

  int _cursor = 0;
  int _lastVoiceSample = 0;
  bool _active = false;

  // Pre-turn candidate (blip filtering before SpeechStart).
  bool _candidate = false;
  int _candidateVoiced = 0;

  // In-turn state.
  int _seq = 0;
  int _pieceVoiced = 0;
  int _silenceRun = 0;
  bool _pauseFired = false;
  int _lastTentativeLen = 0;

  Stream<VadEvent> get events => _events.stream;
  Stream<Piece> get pieces => _pieces.stream;
  bool get inTurn => _active;

  void addFrame(Float32List frame) {
    final speech = _detector.isSpeech(frame);
    _cursor += frame.length;
    if (speech) _lastVoiceSample = _cursor;

    if (_active) {
      _onActiveFrame(frame, speech);
    } else {
      _onIdleFrame(frame, speech);
    }
  }

  /// Ends the current turn immediately (e.g. the user tapped the mic).
  void forceEndOfTurn() {
    if (_active) _endTurn();
  }

  void reset() {
    _active = false;
    _candidate = false;
    _candidateVoiced = 0;
    _preRoll.clear();
    _resetTurn();
  }

  Future<void> close() async {
    await _events.close();
    await _pieces.close();
  }

  void _onIdleFrame(Float32List frame, bool speech) {
    if (!_candidate) {
      if (!speech) {
        _preRoll.add(frame);
        _preRoll.keepLast(config.samples(config.preRollMs));
        return;
      }
      _candidate = true;
      _candidateVoiced = 0;
      _silenceRun = 0;
      _piece
        ..clear()
        ..addAll(_preRoll);
      _preRoll.clear();
    }

    _piece.add(frame);
    if (speech) {
      _candidateVoiced += frame.length;
      _silenceRun = 0;
    } else {
      _silenceRun += frame.length;
    }

    if (_candidateVoiced >= config.samples(config.minSpeechMs)) {
      _candidate = false;
      _active = true;
      _pieceVoiced = _candidateVoiced;
      _pauseFired = false;
      _lastTentativeLen = 0;
      _events.add(SpeechStart(_lastVoiceSample));
    } else if (_silenceRun >= config.samples(config.shortPauseMs)) {
      // A blip: too little speech before a pause. Keep its tail as pre-roll.
      _candidate = false;
      _preRoll.addAll(_piece);
      _preRoll.keepLast(config.samples(config.preRollMs));
      _piece.clear();
      _silenceRun = 0;
    }
  }

  void _onActiveFrame(Float32List frame, bool speech) {
    _piece.add(frame);
    if (speech) {
      _pieceVoiced += frame.length;
      _silenceRun = 0;
      _pauseFired = false;
      if (_hasEnoughVoice &&
          _piece.length >= config.samples(config.maxPieceMs)) {
        _emitCommitted(isLast: false);
        return;
      }
      if (_hasEnoughVoice &&
          _piece.length - _lastTentativeLen >=
              config.samples(config.tentativeIntervalMs)) {
        _lastTentativeLen = _piece.length;
        _pieces.add(
          Piece(
            seq: _seq,
            audio: _piece.toFloat32(),
            kind: PieceKind.tentative,
          ),
        );
      }
    } else {
      _silenceRun += frame.length;
      if (!_hasEnoughVoice && _pieceVoiced == 0) {
        _piece.keepLast(config.samples(config.preRollMs));
      }
      _onSilence();
    }
  }

  void _onSilence() {
    if (!_pauseFired && _silenceRun >= config.samples(config.shortPauseMs)) {
      _pauseFired = true;
      _events.add(
        ShortPause(_lastVoiceSample, _silenceRun * 1000 ~/ config.sampleRate),
      );
      if (_hasEnoughVoice) {
        _emitCommitted(isLast: false);
      } else {
        _dropPieceVoice();
      }
    }
    if (_silenceRun >= config.samples(_endOfTurnMs())) _endTurn();
  }

  bool get _hasEnoughVoice =>
      _pieceVoiced >= config.samples(config.minSpeechMs);

  void _emitCommitted({required bool isLast}) {
    _pieces.add(
      Piece(
        seq: _seq,
        audio: _piece.toFloat32(),
        kind: PieceKind.committed,
        isLast: isLast,
      ),
    );
    _seq++;
    _piece.clear();
    _pieceVoiced = 0;
    _lastTentativeLen = 0;
  }

  void _dropPieceVoice() {
    _pieceVoiced = 0;
    _lastTentativeLen = 0;
    _piece.keepLast(config.samples(config.preRollMs));
  }

  void _endTurn() {
    _events.add(EndOfTurn(_lastVoiceSample));
    if (_hasEnoughVoice) {
      _emitCommitted(isLast: true);
    } else {
      _pieces.add(
        Piece(
          seq: _seq,
          audio: Float32List(0),
          kind: PieceKind.committed,
          isLast: true,
        ),
      );
    }
    _active = false;
    _preRoll.clear();
    _resetTurn();
  }

  void _resetTurn() {
    _seq = 0;
    _piece.clear();
    _pieceVoiced = 0;
    _silenceRun = 0;
    _pauseFired = false;
    _lastTentativeLen = 0;
  }
}

class _AudioBuffer {
  final List<Float32List> _chunks = [];
  int _length = 0;

  int get length => _length;

  void add(Float32List chunk) {
    _chunks.add(chunk);
    _length += chunk.length;
  }

  void addAll(_AudioBuffer other) {
    for (final c in other._chunks) {
      add(c);
    }
  }

  void keepLast(int samples) {
    while (_chunks.isNotEmpty && _length - _chunks.first.length >= samples) {
      _length -= _chunks.removeAt(0).length;
    }
  }

  void clear() {
    _chunks.clear();
    _length = 0;
  }

  Float32List toFloat32() {
    final out = Float32List(_length);
    var offset = 0;
    for (final c in _chunks) {
      out.setAll(offset, c);
      offset += c.length;
    }
    return out;
  }
}
