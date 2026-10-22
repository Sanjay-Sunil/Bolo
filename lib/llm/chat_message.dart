enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage(this.role, this.text);

  const ChatMessage.user(this.text) : role = ChatRole.user;
  const ChatMessage.assistant(this.text) : role = ChatRole.assistant;

  final ChatRole role;
  final String text;

  Map<String, String> toApi() => {'role': role.name, 'content': text};
}
