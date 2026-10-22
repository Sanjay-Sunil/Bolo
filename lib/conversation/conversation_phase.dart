enum ConversationPhase {
  /// Models are loading.
  loading,

  /// Ready; no conversation running.
  idle,

  /// Mic open, waiting for or hearing the user.
  listening,

  /// Turn ended; final transcript or LLM reply on its way.
  thinking,

  /// Reply audio playing.
  speaking,

  /// Something failed to load; see the error text.
  failed,
}
