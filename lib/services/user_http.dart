import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserHttp {
  /// Android emulator: http://10.0.2.2/backend/
  /// HP fisik: http://IP_LAPTOP/backend/
  static const String baseUrl = 'http://10.0.2.2/backend/';

  static const _tokenKey = 'token'; // samakan dengan key token kamu saat login

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
        debugPrint('[GET] $uri -> ${res.statusCode}');
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
        debugPrint('[POST] $uri -> ${res.statusCode}');
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
