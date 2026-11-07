import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStorage {
  static const String _sanctumTokenKey = 'naseebak_sanctum_token';
  static const String _cachedUserJsonKey = 'naseebak_cached_user_json';

  final FlutterSecureStorage _storage;

  const SecureSessionStorage([
    FlutterSecureStorage? storage,
  ]) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _sanctumTokenKey, value: token);
    } catch (_) {}
  }

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _sanctumTokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserJson(Map<String, dynamic> userJson) async {
    try {
      await _storage.write(
        key: _cachedUserJsonKey,
        value: jsonEncode(userJson),
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> readUserJson() async {
    try {
      final raw = await _storage.read(key: _cachedUserJsonKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _sanctumTokenKey);
      await _storage.delete(key: _cachedUserJsonKey);
    } catch (_) {}
  }
}
