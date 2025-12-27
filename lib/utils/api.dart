import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class Api {
  // =====================================================
  // BASE URL
  // =====================================================
  static const String baseUrl = "http://10.0.2.2/backend";

  // =====================================================
  // HEADER DEFAULT
  // =====================================================
  static const Map<String, String> _headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  // =====================================================
  // REGISTER
  // =====================================================
  static Future<Map<String, dynamic>> register({
    required String name,
    required String nomorUser,
    required String alamatUser,
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/auth/register.php");

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              "name": name,
              "nomor_user": nomorUser,
              "alamat_user": alamatUser,
              "email": email,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
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

  // =====================================================
  // LOGIN
  // =====================================================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/auth/login.php");

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
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

  // =====================================================
  // CHECK TOKEN (JWT)
  // =====================================================
  static Future<Map<String, dynamic>> checkToken(String token) async {
    try {
      final uri = Uri.parse("$baseUrl/auth/check_token.php");

      final response = await http
          .get(uri, headers: {..._headers, "Authorization": "Bearer $token"})
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on SocketException {
      return {"ok": false, "message": "Server tidak dapat dijangkau"};
    } on HttpException {
      return {"ok": false, "message": "Kesalahan HTTP"};
    } catch (e) {
      return {"ok": false, "message": "Gagal cek token: $e"};
    }
  }

  // =====================================================
  // RESPONSE HANDLER (GLOBAL)
  // =====================================================
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body;

    // Jika server balas HTML (biasanya <br /> warning PHP), jangan paksa jsonDecode
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('<')) {
      return {
        "ok": false,
        "message":
            "Server mengirim HTML (bukan JSON). Cek error PHP di backend.",
        "statusCode": response.statusCode,
        "rawPreview": trimmed.substring(
          0,
          trimmed.length > 200 ? 200 : trimmed.length,
        ),
      };
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        return {"ok": false, "message": "Format response tidak dikenali"};
      }
    } catch (e) {
      return {"ok": false, "message": "Gagal parsing JSON: $e"};
    }
  }
}
