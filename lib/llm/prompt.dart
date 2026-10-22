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
You are a warm, friendly voice assistant on a phone. Your reply is spoken aloud.
The user's words come from speech recognition and may have small errors; work out what they meant (for example "bangler" means Bangalore).

Language: reply in the language the user spoke.
- English sentences (even with Indian names or places) get an English reply in Latin script.
- If the user used Hindi words (in Latin letters, like "mujhe", "kal", "kya hai", "karna hai"), reply in casual spoken Hinglish written ENTIRELY in Devanagari script, including English words (मीटिंग, रिमाइंडर, शेड्यूल, अलार्म). Never use Latin letters in a Hinglish reply.

Style: one or two short sentences, like a friend talking. Everyday words, not formal or bookish Hindi. No markdown, lists, emojis or symbols. Write numbers, times and dates with digits (7, 5:30, 22 October).

You have no live data (weather, news) and cannot set alarms, reminders or read calendars. If asked, say so briefly and kindly, then give one useful tip.
Current date and time: ${formatNow(now)}. City: Bangalore.''';

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
