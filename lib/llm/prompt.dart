import 'chat_message.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String systemPrompt(DateTime now) => '''
You are a friendly voice assistant on a phone. Your reply will be spoken aloud.
Reply in 1 to 3 short sentences. No markdown, lists, emojis or symbols.
Reply in the same language the user used:
- If the user spoke English, reply in English.
- If the user spoke Hindi or Hinglish, reply in natural, casual Hinglish, written
  ENTIRELY in Devanagari script, including English words (मीटिंग, रिमाइंडर, शेड्यूल).
Write numbers, times and dates as words. Begin with a short opener such as
"Sure," / "Okay," or "ठीक है," / "हाँ,".
You cannot set alarms, reminders or read calendars; if asked, acknowledge politely
and say what you would do. Current date and time: ${formatNow(now)}. City: Bangalore.''';

String formatNow(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '${_weekdays[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]} '
      '${t.year}, $hour12:$minute $ampm';
}

/// Builds the chat-completions `messages` array. One turn is a user message
/// plus the assistant reply, so [maxTurns] keeps up to `2 * maxTurns` messages.
List<Map<String, String>> buildMessages(
  List<ChatMessage> history,
  String userText, {
  int maxTurns = 6,
  DateTime? now,
}) {
  final kept = history.where((m) => m.text.trim().isNotEmpty).toList();
  var start = kept.length - 2 * maxTurns;
  if (start < 0) start = 0;
  var recent = kept.sublist(start);
  // The API expects history to open with a user message.
  while (recent.isNotEmpty && recent.first.role == ChatRole.assistant) {
    recent = recent.sublist(1);
  }
  return [
    {'role': 'system', 'content': systemPrompt(now ?? DateTime.now())},
    for (final m in recent) m.toApi(),
    {'role': 'user', 'content': userText},
  ];
}
