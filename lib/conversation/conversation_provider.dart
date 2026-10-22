import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_controller.dart';

final conversationProvider = Provider<ConversationController>((ref) {
  final controller = ConversationController();
  ref.onDispose(controller.dispose);
  controller.init();
  return controller;
});
