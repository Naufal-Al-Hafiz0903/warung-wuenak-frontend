import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api.dart';

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _tokenKeyLegacy = 'token';
  static const _userKey = 'user_data';
  static const _emailVerifiedKey = 'email_verified';

  static final Future<SharedPreferences> _prefs =
      SharedPreferences.getInstance();

  static bool _toBool(dynamic v, {bool defaultValue = false}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    return defaultValue;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final emailNorm = email.trim().toLowerCase();

    final res = await Api.login(email: emailNorm, password: password);

    if (res['ok'] == true && res['token'] != null) {
      final prefs = await _prefs;

      final token = res['token'].toString();
      final data = (res['data'] is Map<String, dynamic>)
          ? (res['data'] as Map<String, dynamic>)
          : <String, dynamic>{};

      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(data));
      await prefs.setString(_tokenKeyLegacy, token);

      await prefs.setString("level", (data["level"] ?? "user").toString());
      await prefs.setString("email", (data["email"] ?? emailNorm).toString());
      await prefs.setString("name", (data["name"] ?? "").toString());

      final emailVerified = _toBool(
        data["email_verified"] ?? data["emailVerified"],
        defaultValue: false,
      );
      await prefs.setBool(_emailVerifiedKey, emailVerified);

      final uidRaw = data["user_id"] ?? data["userId"];
      final uid = (uidRaw is num)
          ? uidRaw.toInt()
          : int.tryParse(uidRaw?.toString() ?? '');
      if (uid != null) {
        await prefs.setInt("user_id", uid);
      }
    }

    return res;
  }

  static Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey) ?? prefs.getString(_tokenKeyLegacy);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getRole() async {
    final user = await getUser();
    return user?['level']?.toString();
  }

  static Future<bool?> getEmailVerified() async {
    final prefs = await _prefs;
    return prefs.getBool(_emailVerifiedKey);
  }

  static Future<void> setEmailVerified(bool v) async {
    final prefs = await _prefs;
    await prefs.setBool(_emailVerifiedKey, v);

    final user = await getUser();
    if (user != null) {
      user["email_verified"] = v;
      await prefs.setString(_userKey, jsonEncode(user));
    }
  }

  static Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String nomorUser,
    required String alamatUser,
    required String email,
    required String password,
    String level = 'user',
  }) async {
    return Api.register(
      name: name,
      nomorUser: nomorUser,
      alamatUser: alamatUser,
      email: email,
      password: password,
      level: level,
    );
  }

  static Future<Map<String, dynamic>> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    return Api.changePassword(
      email: email,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }
}
