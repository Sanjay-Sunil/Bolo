/// One finished exchange, for the history below the main stage.
class ChatEntry {
  const ChatEntry({
    required this.user,
    required this.reply,
    this.metrics = '',
    this.confidence,
    this.accuracy = '',
    this.typed = false,
  });

  final String user;

  /// Display form of the reply (Roman Hinglish or English).
  final String reply;

  /// One-line latency breakdown.
  final String metrics;

  /// STT confidence 0..1 for spoken turns.
  final double? confidence;

  /// WER/CER against a matching test sentence, empty otherwise.
  final String accuracy;
  final bool typed;
}
