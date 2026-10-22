import 'package:bolo/llm/chat_message.dart';
import 'package:bolo/llm/prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 17, 5);

  test('formats the current time for the prompt', () {
    expect(formatNow(now), 'Thursday, 22 October 2026, 5:05 PM');
    expect(
      formatNow(DateTime(2026, 1, 5, 0, 30)),
      'Monday, 5 January 2026, 12:30 AM',
    );
    expect(
      formatNow(DateTime(2026, 1, 5, 12, 0)),
      'Monday, 5 January 2026, 12:00 PM',
    );
  });

  test('system prompt injects time and keeps the Devanagari rule', () {
    final p = systemPrompt(now);
    expect(
      p,
      contains('Current date and time: Thursday, 22 October 2026, 5:05 PM.'),
    );
    expect(p, contains('ENTIRELY in Devanagari script'));
    expect(p, isNot(contains('{now}')));
  });

  test('builds system, history and user messages in order', () {
    final msgs = buildMessages(
      const [ChatMessage.user('Hi'), ChatMessage.assistant('Hello!')],
      'What time is it?',
      now: now,
    );
    expect(msgs.map((m) => m['role']), ['system', 'user', 'assistant', 'user']);
    expect(msgs.last['content'], 'What time is it?');
    expect(msgs[1]['content'], 'Hi');
  });

  test('keeps only the last maxTurns turns', () {
    final history = [
      for (var i = 0; i < 10; i++) ...[
        ChatMessage.user('u$i'),
        ChatMessage.assistant('a$i'),
      ],
    ];
    final msgs = buildMessages(history, 'new', maxTurns: 2, now: now);
    expect(msgs.skip(1).map((m) => m['content']), [
      'u8',
      'a8',
      'u9',
      'a9',
      'new',
    ]);
  });

  test('drops a leading assistant message and empty messages', () {
    final msgs = buildMessages(
      const [
        ChatMessage.user('u0'),
        ChatMessage.assistant('a0'),
        ChatMessage.user('u1'),
        ChatMessage.assistant(' '),
        ChatMessage.assistant('a1'),
      ],
      'new',
      maxTurns: 1,
      now: now,
    );
    expect(msgs.skip(1).map((m) => m['content']), ['u1', 'a1', 'new']);
  });

  test('works with empty history', () {
    final msgs = buildMessages(const [], 'Namaste', now: now);
    expect(msgs.length, 2);
    expect(msgs.last, {'role': 'user', 'content': 'Namaste'});
  });
}
