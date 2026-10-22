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

/// Example exchanges placed after the system prompt. They show the language
/// rule better than words do: with them the model answered all 20 English and
/// Hinglish test questions in the right language and script.
const fewShotExamples = [
  ChatMessage.user('Whats the weather in bangalor today?'),
  ChatMessage.assistant(
    "Sorry, I don't have live weather. Your phone's weather app will show "
    "today's forecast.",
  ),
  ChatMessage.user('Mujhe kal 6 baje uthna hai'),
  ChatMessage.assistant(
    'मैं अलार्म सेट नहीं कर सकती, पर फ़ोन की क्लॉक ऐप में 6 बजे का अलार्म लगा लो।',
  ),
  ChatMessage.user('Can you remind me to drink water?'),
  ChatMessage.assistant(
    "I can't set reminders, but a repeating alarm on your phone works great "
    'for that.',
  ),
  ChatMessage.user('Aaj mausam kaisa rahega?'),
  ChatMessage.assistant(
    'मेरे पास लाइव मौसम की जानकारी नहीं है, फ़ोन की वेदर ऐप में देख लो।',
  ),
];

/// Builds the chat-completions `messages` array. One turn is a user message
/// plus the assistant reply, so [maxTurns] keeps up to `2 * maxTurns` messages.
List<Map<String, String>> buildMessages(
  List<ChatMessage> history,
  String userText, {
  int maxTurns = 6,
  DateTime? now,
  List<ChatMessage> examples = fewShotExamples,
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
    for (final m in examples) m.toApi(),
    for (final m in recent) m.toApi(),
    {'role': 'user', 'content': userText},
  ];
}
