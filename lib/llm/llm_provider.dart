/// OpenAI-compatible chat endpoints. Default keys come from `.env` at build
/// time (`--dart-define-from-file=.env`); a key saved in Settings overrides them.
enum LlmProvider {
  groq(
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'openai/gpt-oss-120b',
    buildKey: String.fromEnvironment('GROQ_API_KEY'),
  ),
  gemini(
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    defaultModel: 'gemini-2.5-flash',
    buildKey: String.fromEnvironment('GEMINI_API_KEY'),
  );

  const LlmProvider({
    required this.baseUrl,
    required this.defaultModel,
    required this.buildKey,
  });

  final String baseUrl;
  final String defaultModel;
  final String buildKey;
}
