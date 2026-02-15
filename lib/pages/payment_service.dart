import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  // NOTE: Sesuai permintaan kamu, key ditaruh langsung di client.
  // Untuk production seharusnya key disimpan di backend (lebih aman).
  static const String _xenditSecretKey =
      'xnd_development_O5IZF2PKd3TEco9EldwV5feeXINQJD6OzwJsQPa0JGMsRv4FrdhmHC2vk4b0KIx';

  static const String _baseUrl = 'https://api.xendit.co';
  static const Duration _timeout = Duration(seconds: 25);

  static String _basicAuthHeader() {
    final token = base64Encode(utf8.encode('$_xenditSecretKey:'));
    return 'Basic $token';
  }

  static Map<String, String> _headers() {
    return {
      'Authorization': _basicAuthHeader(),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static String _safeString(dynamic v) => (v ?? '').toString();

  static int _safeInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? def;
  }

  static Future<Map<String, dynamic>> createQrisXendit({
    required int orderId,
    required int amount,
    String callbackUrl = 'https://example.com/xendit/qris-callback',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/qr_codes');

      final body = <String, dynamic>{
        'external_id': 'order-$orderId',
        'type': 'DYNAMIC',
        'amount': amount,
        'callback_url': callbackUrl,
      };

      final resp = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);

      final raw = resp.body;
      final decoded = (raw.isNotEmpty) ? jsonDecode(raw) : null;

      if (resp.statusCode >= 200 && resp.statusCode < 300 && decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);

        return {
          'ok': true,
          'message': 'QRIS berhasil dibuat',
          'data': {
            'id': _safeString(data['id']),
            'external_id': _safeString(data['external_id']),
            'qr_string': _safeString(data['qr_string']),
            'amount': _safeInt(data['amount'], amount),
            'status': _safeString(data['status']),
            'expires_at': _safeString(data['expires_at']),
          },
        };
      }

      String msg = 'Gagal membuat QRIS';
      if (decoded is Map && decoded['message'] != null) {
        msg = decoded['message'].toString();
      } else {
        msg = '$msg (HTTP ${resp.statusCode})';
      }

      return {'ok': false, 'message': msg, 'data': null};
    } catch (e) {
      return {'ok': false, 'message': 'Error QRIS: $e', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> createVaBcaXendit({
    required int orderId,
    required String name,
    required int expectedAmount,
    int expiryHours = 24,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/callback_virtual_accounts');

      final expUtc = DateTime.now()
          .toUtc()
          .add(Duration(hours: expiryHours))
          .toIso8601String();

      final nm = name.trim().isEmpty ? 'WARUNGWUENAK' : name.trim();

      final body = <String, dynamic>{
        'external_id': 'order-$orderId',
        'bank_code': 'BCA',
        'name': nm,
        'is_closed': true,
        'expected_amount': expectedAmount,
        'expiration_date': expUtc,
      };

      final resp = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);

      final raw = resp.body;
      final decoded = (raw.isNotEmpty) ? jsonDecode(raw) : null;

      if (resp.statusCode >= 200 && resp.statusCode < 300 && decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);

        return {
          'ok': true,
          'message': 'VA BCA berhasil dibuat',
          'data': {
            'id': _safeString(data['id']),
            'external_id': _safeString(data['external_id']),
            'bank_code': _safeString(data['bank_code']),
            'name': _safeString(data['name']),
            'account_number': _safeString(data['account_number']),
            'expiration_date': _safeString(data['expiration_date']),
            'status': _safeString(data['status']),
            'expected_amount': _safeInt(
              data['expected_amount'],
              expectedAmount,
            ),
          },
        };
      }

      String msg = 'Gagal membuat VA BCA';
      if (decoded is Map && decoded['message'] != null) {
        msg = decoded['message'].toString();
      } else {
        msg = '$msg (HTTP ${resp.statusCode})';
      }

      return {'ok': false, 'message': msg, 'data': null};
    } catch (e) {
      return {'ok': false, 'message': 'Error VA: $e', 'data': null};
    }
  }
}
