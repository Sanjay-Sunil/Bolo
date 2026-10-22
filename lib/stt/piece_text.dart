import '../vad/piece.dart';

class PieceText {
  const PieceText({
    required this.seq,
    required this.text,
    required this.confidence,
    required this.kind,
  });

  final int seq;
  final String text;
  final double confidence;
  final PieceKind kind;
}
