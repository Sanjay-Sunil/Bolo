import 'dart:typed_data';

enum PieceKind { committed, tentative }

/// A slice of one utterance. Committed pieces are cut at pauses and decoded
/// once; tentative pieces are snapshots of the piece still being spoken.
class Piece {
  const Piece({
    required this.seq,
    required this.audio,
    required this.kind,
    this.isLast = false,
  });

  final int seq;
  final Float32List audio;
  final PieceKind kind;
  final bool isLast;
}
