import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class Api {
  static const String baseUrl = AppConfig.baseUrl;
  static final http.Client _client = http.Client();

  static const Map<String, String> _headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  static const Duration _timeout15 = Duration(seconds: 15);
  static const Duration _timeout10 = Duration(seconds: 10);

  static Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse("$baseUrl$p");
  }

  static String _normalizeRole(String raw) {
    final r = (raw).trim().toLowerCase();
    if (r.isEmpty) return 'user';
    if (r == 'pembeli') return 'user';
    if (r == 'seller') return 'penjual';
    if (r == 'penjual') return 'penjual';
    return 'user';
  }

  // REGISTER
  static Future<Map<String, dynamic>> register({
    required String name,
    required String nomorUser,
    required String alamatUser,
    required String email,
    required String password,
    String level = 'user',
  }) async {
    try {
      final uri = _uri("/auth/register");

      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              "name": name,
              "nomor_user": nomorUser,
              "alamat_user": alamatUser,
              "email": email,
              "password": password,
              "level": _normalizeRole(level),
            }),
          )
          .timeout(_timeout15);

      return _handleResponse(response, uri);
    } on SocketException {
      return {"ok": false, "message": "Server tidak dapat dijangkau"};
    } on HttpException {
      return {"ok": false, "message": "Kesalahan HTTP"};
    } on FormatException {
      return {"ok": false, "message": "Response server tidak valid"};
    } catch (e) {
      return {"ok": false, "message": "Register error: $e"};
    }
  }

  // LOGIN
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = _uri("/auth/login");

      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(_timeout15);

      return _handleResponse(response, uri);
    } on SocketException {
      return {"ok": false, "message": "Server tidak dapat dijangkau"};
    } on HttpException {
      return {"ok": false, "message": "Kesalahan HTTP"};
    } on FormatException {
      return {"ok": false, "message": "Response server tidak valid"};
    } catch (e) {
      return {"ok": false, "message": "Login error: $e"};
    }
  }

  // CHANGE PASSWORD ✅
  static Future<Map<String, dynamic>> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final uri = _uri("/auth/change-password");

      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              "email": email,
              "old_password": oldPassword,
              "new_password": newPassword,
            }),
          )
          .timeout(_timeout15);

      return _handleResponse(response, uri);
    } on SocketException {
      return {"ok": false, "message": "Server tidak dapat dijangkau"};
    } on HttpException {
      return {"ok": false, "message": "Kesalahan HTTP"};
    } on FormatException {
      return {"ok": false, "message": "Response server tidak valid"};
    } catch (e) {
      return {"ok": false, "message": "Change password error: $e"};
    }
  }

  // CHECK TOKEN
  static Future<Map<String, dynamic>> checkToken(String token) async {
    final candidates = <String>[
      "/auth/check",
      "/auth/check-token",
      "/auth/check_token",
    ];

    Map<String, dynamic>? lastResult;

    for (final path in candidates) {
      try {
        final uri = _uri(path);

        final response = await _client
            .get(uri, headers: {..._headers, "Authorization": "Bearer $token"})
            .timeout(_timeout10);

        final data = _handleResponse(response, uri);
        lastResult = data;

        final sc = (data["statusCode"] is int)
            ? data["statusCode"] as int
            : response.statusCode;

        if (sc == 404 || sc == 405) continue;

        if (data["message"] == "Server mengirim HTML (bukan JSON)." &&
            (sc == 404 || sc == 405)) {
          continue;
        }

        return data;
      } on SocketException {
        return {"ok": false, "message": "Server tidak dapat dijangkau"};
      } on HttpException {
        return {"ok": false, "message": "Kesalahan HTTP"};
      } catch (e) {
        lastResult = {"ok": false, "message": "Gagal cek token: $e"};
      }
    }

    return lastResult ??
        {
          "ok": false,
          "message": "Endpoint check token tidak ditemukan di server",
          "statusCode": 404,
        };
  }

  // RESPONSE HANDLER
  static Map<String, dynamic> _handleResponse(http.Response response, Uri uri) {
    final body = response.body;
    final contentType = response.headers['content-type'] ?? "";

    if (body.trim().isEmpty) {
      return {
        "ok": response.statusCode < 400,
        "message": "Response kosong dari server",
        "statusCode": response.statusCode,
        "url": uri.toString(),
      };
    }

    final trimmed = body.trimLeft();
    final isHtmlByHeader = contentType.toLowerCase().contains("text/html");
    final isHtmlByBody = trimmed.startsWith('<');

    if (isHtmlByHeader || isHtmlByBody) {
      return {
        "ok": false,
        "message": "Server mengirim HTML (bukan JSON).",
        "statusCode": response.statusCode,
        "url": uri.toString(),
        "contentType": contentType,
        "rawPreview": trimmed.substring(
          0,
          trimmed.length > 250 ? 250 : trimmed.length,
        ),
      };
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        decoded["ok"] ??= response.statusCode < 400;
        decoded["statusCode"] ??= response.statusCode;
        decoded["url"] ??= uri.toString();
        return decoded;
      }

      if (decoded is List) {
        return {
          "ok": response.statusCode < 400,
          "message": "OK",
          "data": decoded,
          "statusCode": response.statusCode,
          "url": uri.toString(),
        };
      }

      return {
        "ok": false,
        "message": "Format response tidak dikenali",
        "statusCode": response.statusCode,
        "url": uri.toString(),
      };
    } catch (e) {
      return {
        "ok": false,
        "message": "Gagal parsing JSON: $e",
        "statusCode": response.statusCode,
        "url": uri.toString(),
        "rawPreview": body.substring(0, body.length > 250 ? 250 : body.length),
      };
    }
  }
}
