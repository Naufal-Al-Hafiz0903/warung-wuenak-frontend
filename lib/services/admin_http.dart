import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

class AdminHttp {
  static const String baseUrl = '${AppConfig.baseUrl}/';

  static const _tokenKeyLegacy = 'token';
  static const _tokenKeyNew = 'jwt_token';

  static Future<String?> _getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKeyNew) ?? sp.getString(_tokenKeyLegacy);
  }

  static Uri _uri(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl$p');
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
    final uri = _uri(path);

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
    final uri = _uri(path);

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

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();
    final uri = _uri(path);

    try {
      final res = await http.post(
        uri,
        headers: _mergeHeaders(token, {'Content-Type': 'application/json'}),
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('[POST-JSON] $uri -> ${res.statusCode}');
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

  // ============================================================
  // ✅ NEW: multipart upload (file)
  // ============================================================
  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required File file,
    String fileField = 'file',
    Map<String, String> fields = const {},
  }) async {
    final token = await _getToken();
    final uri = _uri(path);

    try {
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(_mergeHeaders(token)); // no content-type manual
      req.fields.addAll(fields);

      req.files.add(await http.MultipartFile.fromPath(fileField, file.path));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (kDebugMode) {
        debugPrint('[POST-MULTIPART] $uri -> ${streamed.statusCode}');
        debugPrint('FIELDS: $fields');
        debugPrint(body);
      }

      final data = _safeJsonDecode(body, streamed.statusCode);

      if (streamed.statusCode >= 400 && data['ok'] == null) {
        return {
          'ok': false,
          'message': 'HTTP ${streamed.statusCode}',
          'data': data,
        };
      }

      return data;
    } catch (e) {
      return {'ok': false, 'message': 'POST multipart error: $e'};
    }
  }
}
