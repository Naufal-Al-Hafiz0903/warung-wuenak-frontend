import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../services/admin_http.dart';

export '../../services/admin_http.dart' show AdminHttp;

// ======================================================================
// LEGACY: HTTP PHP (/backend/) - tidak dihapus (tidak terkait tugas endpoint Spring)
// ======================================================================
class PhpAdminHttp {
  static const String baseUrl = 'http://10.0.2.2/backend/';
  static const _tokenKey = 'token';

  static Future<String?> _getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKey);
  }

  static Map<String, String> _mergeHeaders(
    String? token, [
    Map<String, String>? extra,
  ]) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  static Map<String, dynamic> _safeJsonDecode(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) {
        return {'ok': true, 'data': decoded, 'status': statusCode};
      }
      return {
        'ok': false,
        'message': 'Response JSON tidak valid',
        'raw': body,
        'status': statusCode,
      };
    } catch (e) {
      return {
        'ok': false,
        'message': 'Gagal parse JSON: $e',
        'raw': body,
        'status': statusCode,
      };
    }
  }

  static Future<Map<String, dynamic>> getJson(String path) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl$path');

    try {
      final res = await http.get(uri, headers: _mergeHeaders(token));
      if (kDebugMode) {
        debugPrint('[LEGACY GET] $uri -> ${res.statusCode}');
        debugPrint(res.body);
      }
      final data = _safeJsonDecode(res.body, res.statusCode);
      if (res.statusCode >= 400 && data['ok'] == null) {
        return {'ok': false, 'message': 'HTTP ${res.statusCode}', 'data': data};
      }
      return data;
    } catch (e) {
      return {'ok': false, 'message': 'GET error: $e'};
    }
  }

  static Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, String> body,
  ) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl$path');

    try {
      final res = await http.post(
        uri,
        headers: _mergeHeaders(token, {
          'Content-Type': 'application/x-www-form-urlencoded',
        }),
        body: body,
      );
      if (kDebugMode) {
        debugPrint('[LEGACY POST] $uri -> ${res.statusCode}');
        debugPrint('BODY: $body');
        debugPrint(res.body);
      }
      final data = _safeJsonDecode(res.body, res.statusCode);
      if (res.statusCode >= 400 && data['ok'] == null) {
        return {'ok': false, 'message': 'HTTP ${res.statusCode}', 'data': data};
      }
      return data;
    } catch (e) {
      return {'ok': false, 'message': 'POST error: $e'};
    }
  }
}

// ===f==================================================
// USER SERVICE — Spring Boot :8080 (endpoint disesuaikan dengan UserController.java)
// =====================================================
class UserService {
  static const String listEndpoint = 'users/list';
  static const String createEndpoint = 'users/create';
  static const String updateStatusEndpoint = 'users/update-status';
  static const String changeLevelEndpoint = 'users/change-level';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['users'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<UserModel>> fetchUsers() async {
    final res = await AdminHttp.getJson(listEndpoint);

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<bool> changeLevel({
    required int userId,
    required String level,
  }) async {
    final res = await AdminHttp.postForm(changeLevelEndpoint, {
      'user_id': userId.toString(),
      'level': level,
    });
    return res['ok'] == true;
  }

  static Future<bool> updateStatus({
    required int userId,
    required String status,
  }) async {
    final res = await AdminHttp.postForm(updateStatusEndpoint, {
      'user_id': userId.toString(),
      'status': status,
    });
    return res['ok'] == true;
  }

  static Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String level,
    required String status,
    String nomorUser = '',
    String alamatUser = '',
  }) async {
    // ✅ kirim snake_case + camelCase agar backend aman
    final res = await AdminHttp.postForm(createEndpoint, {
      'name': name,
      'email': email,
      'password': password,
      'level': level,
      'status': status,

      'nomor_user': nomorUser,
      'alamat_user': alamatUser,

      'nomorUser': nomorUser,
      'alamatUser': alamatUser,
    });
    return res;
  }
}
