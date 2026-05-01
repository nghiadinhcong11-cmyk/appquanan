import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _sessionKey = 'session_user_v3';
  static const _tokenKey = 'session_token_v1';
  static const _refreshKey = 'session_refresh_v1';

  Future<String?> loadSessionUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  Future<void> saveSessionUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, username);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> loadRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshKey, token);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }
}
