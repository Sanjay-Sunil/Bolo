import 'dart:io';

/// Threads for one on-device inference job; safe on mid-tier phones.
int inferenceThreads() => (Platform.numberOfProcessors ~/ 2).clamp(2, 4);
