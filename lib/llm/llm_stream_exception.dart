class LlmStreamException implements Exception {
  const LlmStreamException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null
      ? 'LlmStreamException: $message'
      : 'LlmStreamException($code): $message';
}
