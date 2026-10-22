import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The user's own Groq key, kept in Android's encrypted storage.
class ApiKeyStore {
  static const _name = 'groq_api_key';
  final _storage = const FlutterSecureStorage();

  Future<String?> read() async {
    try {
      final key = await _storage.read(key: _name);
      return key == null || key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key) => _storage.write(key: _name, value: key);
}
