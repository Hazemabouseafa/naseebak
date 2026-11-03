import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStorage {
  static const String _sanctumTokenKey = 'naseebak_sanctum_token';

  final FlutterSecureStorage _storage;

  const SecureSessionStorage([
    FlutterSecureStorage? storage,
  ]) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveToken(String token) async {
    await _storage.write(key: _sanctumTokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _sanctumTokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _sanctumTokenKey);
  }
}
