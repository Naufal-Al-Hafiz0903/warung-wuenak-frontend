import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

class UserHttp {
  static const String baseUrl = '${AppConfig.baseUrl}/';

  static const _tokenKeyLegacy = 'token';
  static const _tokenKeyNew = 'jwt_token';

  static const Duration _timeout = Duration(seconds: 15);
  static String _base() {
    final raw = AppConfig.baseUrl.trim();
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  static Future<String?> _getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKeyNew) ?? sp.getString(_tokenKeyLegacy);
  }

  static Uri _uri(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('${_base()}/$p');
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
    final raw = body.trim();
    if (raw.isEmpty) {
      return {
        'ok': statusCode < 400,
        'message': 'Response kosong dari server',
        'status': statusCode,
      };
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        // kalau server tidak kirim ok, kita fallback dari status code
        decoded.putIfAbsent('ok', () => statusCode < 400);
        decoded.putIfAbsent('status', () => statusCode);
        return decoded;
      }

      if (decoded is List) {
        return {'ok': statusCode < 400, 'data': decoded, 'status': statusCode};
      }

      return {
        'ok': false,
        'message': 'Response JSON tidak valid',
        'raw': raw,
        'status': statusCode,
      };
    } catch (e) {
      return {
        'ok': false,
        'message': 'Gagal parse JSON: $e',
        'raw': raw,
        'status': statusCode,
      };
    }
  }

  static Future<String?> getTokenForMultipart() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKeyNew) ?? sp.getString(_tokenKeyLegacy);
  }

  static Map<String, dynamic> safeJsonDecode(String body, int statusCode) {
    return _safeJsonDecode(body, statusCode);
  }

  static Future<Map<String, dynamic>> getJson(String path) async {
    final token = await _getToken();
    final uri = _uri(path);

    try {
      final res = await http
          .get(uri, headers: _mergeHeaders(token))
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[GET] $uri -> ${res.statusCode}');
        debugPrint(res.body);
      }

      return _safeJsonDecode(res.body, res.statusCode);
    } catch (e) {
      return {'ok': false, 'message': 'GET error: $e'};
    }
  }

  static Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, String> body,
  ) async {
    final token = await _getToken();
    final uri = _uri(path);

    try {
      final res = await http
          .post(
            uri,
            headers: _mergeHeaders(token, {
              'Content-Type': 'application/x-www-form-urlencoded',
            }),
            body: body,
          )
          .timeout(_timeout);

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

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();
    final uri = _uri(path);

    try {
      final res = await http
          .post(
            uri,
            headers: _mergeHeaders(token, {'Content-Type': 'application/json'}),
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[POST-JSON] $uri -> ${res.statusCode}');
        debugPrint('BODY: $body');
        debugPrint(res.body);
      }

      return _safeJsonDecode(res.body, res.statusCode);
    } catch (e) {
      return {'ok': false, 'message': 'POST error: $e'};
    }
  }
}
