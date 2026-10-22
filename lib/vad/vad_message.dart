import 'dart:typed_data';

import 'piece.dart';

/// What the VAD isolate reports to the main isolate.
sealed class VadMessage {
  const VadMessage();
}

/// Visualizer levels for the latest mic window.
final class MicLevels extends VadMessage {
  const MicLevels(this.levels);

  final Float32List levels;
}

enum TurnEventKind { speechStart, shortPause, endOfTurn }

/// [lastVoiceSample] counts samples from the start of the current listening
/// session, so the main isolate can map it to a time.
final class TurnEventMessage extends VadMessage {
  const TurnEventMessage(this.kind, this.lastVoiceSample);

  final TurnEventKind kind;
  final int lastVoiceSample;
}

final class PieceMessage extends VadMessage {
  const PieceMessage(this.piece);

  final Piece piece;
}
