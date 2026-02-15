import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/config/app_config.dart';

class EmailVerificationService {
  EmailVerificationService({String? baseUrl})
    : _baseUrl = (baseUrl == null || baseUrl.trim().isEmpty)
          ? AppConfig.baseUrl
          : baseUrl.trim();

  final String _baseUrl;

  Future<Map<String, dynamic>> sendCode({required String email}) async {
    final uri = Uri.parse('$_baseUrl/auth/email/send-verification');
    final payload = {'email': email};

    return _postJson(uri, payload);
  }

  Future<Map<String, dynamic>> verifyCode({
    required String email,
    required String code,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/email/verify');
    final payload = {'email': email, 'code': code};

    return _postJson(uri, payload);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final req = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 12));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(jsonEncode(body)));

      final res = await req.close().timeout(const Duration(seconds: 12));
      final resBody = await res.transform(utf8.decoder).join();

      Map<String, dynamic> decoded = {};
      if (resBody.isNotEmpty) {
        final v = jsonDecode(resBody);
        if (v is Map<String, dynamic>) decoded = v;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = (decoded['message'] ?? decoded['error'] ?? 'Request gagal')
            .toString();
        throw EmailVerificationException(msg, res.statusCode);
      }

      final okVal = decoded['ok'];
      if (okVal is bool && okVal == false) {
        final msg = (decoded['message'] ?? 'Request gagal').toString();
        throw EmailVerificationException(msg, res.statusCode);
      }

      return decoded;
    } on TimeoutException {
      throw const EmailVerificationException('Koneksi timeout', 408);
    } on SocketException {
      throw const EmailVerificationException(
        'Tidak dapat terhubung ke server',
        503,
      );
    } finally {
      client.close(force: true);
    }
  }
}

class EmailVerificationException implements Exception {
  final String message;
  final int statusCode;

  const EmailVerificationException(this.message, this.statusCode);

  @override
  String toString() => 'EmailVerificationException($statusCode): $message';
}
