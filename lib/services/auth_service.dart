import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api.dart';

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  // =========================
  // LOGIN
  // =========================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await Api.login(email: email, password: password);

    if (res['ok'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, res['token']);
      await prefs.setString(_userKey, jsonEncode(res['data']));
    }

    return res;
  }

  // =========================
  // GET TOKEN
  // =========================
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // =========================
  // GET USER DATA
  // =========================
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  // =========================
  // GET ROLE
  // =========================
  static Future<String?> getRole() async {
    final user = await getUser();
    return user?['level'];
  }

  // =========================
  // LOGOUT
  // =========================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
