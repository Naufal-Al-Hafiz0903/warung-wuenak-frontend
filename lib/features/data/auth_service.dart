import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api.dart';

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _tokenKeyLegacy = 'token';
  static const _userKey = 'user_data';

  static final Future<SharedPreferences> _prefs =
      SharedPreferences.getInstance();

  // =========================
  // LOGIN (EXACT via backend)
  // =========================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await Api.login(email: email, password: password);

    if (res['ok'] == true && res['token'] != null) {
      final prefs = await _prefs;

      final token = res['token'].toString();
      final data = (res['data'] is Map<String, dynamic>)
          ? (res['data'] as Map<String, dynamic>)
          : <String, dynamic>{};

      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(data));
      await prefs.setString(_tokenKeyLegacy, token);

      // kompatibilitas tambahan
      await prefs.setString("level", (data["level"] ?? "user").toString());
      await prefs.setString("email", (data["email"] ?? "").toString());
      await prefs.setString("name", (data["name"] ?? "").toString());

      // ✅ simpan user_id (berguna untuk fallback foto/profil saat offline)
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

  // =========================
  // GET TOKEN
  // =========================
  static Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey) ?? prefs.getString(_tokenKeyLegacy);
  }

  // =========================
  // GET USER DATA
  // =========================
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

  // =========================
  // GET ROLE
  // =========================
  static Future<String?> getRole() async {
    final user = await getUser();
    return user?['level']?.toString();
  }

  // =========================
  // LOGOUT
  // =========================
  static Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  // =========================
  // REGISTER (ROLE PICK)
  // =========================
  static Future<Map<String, dynamic>> register({
    required String name,
    required String nomorUser,
    required String alamatUser,
    required String email,
    required String password,
    String level = 'user', // ✅ default pembeli
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
}
