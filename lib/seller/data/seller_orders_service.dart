import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../services/user_http.dart';

class SellerOrdersService {
  static const String _baseUrl = AppConfig.baseUrl;

  static Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('token');
  }

  static Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Map<String, dynamic> _fail(String msg, {int? status}) => {
    'ok': false,
    'message': msg,
    if (status != null) 'status': status,
  };

  static Future<Map<String, dynamic>> fetchSellerOrdersRaw() async {
    try {
      final tok = await _token();
      if (tok == null || tok.isEmpty) return _fail('Token tidak ditemukan');

      final r = await http.get(
        Uri.parse('$_baseUrl/orders/seller'),
        headers: _headers(tok),
      );

      final body = r.body.isEmpty ? '{}' : r.body;
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;

      return _fail('Response tidak valid', status: r.statusCode);
    } catch (e) {
      return _fail('Gagal memuat pesanan: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchOrders({
    String? status,
    int days = 30,
    int limit = 50,
    int? afterId,
  }) async {
    final qs = <String>[
      'days=$days',
      'limit=$limit',
      if (status != null && status.trim().isNotEmpty) 'status=${status.trim()}',
      if (afterId != null && afterId > 0) 'after_id=$afterId',
    ].join('&');

    return UserHttp.getJson('orders/seller?$qs');
  }

  static Future<Map<String, dynamic>> fetchSummary({int days = 30}) async {
    return UserHttp.getJson('orders/seller/summary?days=$days');
  }

  static Future<Map<String, dynamic>> fetchDetail(int orderId) async {
    return UserHttp.getJson('orders/seller/detail?order_id=$orderId');
  }

  static Future<Map<String, dynamic>> fetchSellerOrderDetail(
    int orderId,
  ) async {
    try {
      final tok = await _token();
      if (tok == null || tok.isEmpty) return _fail('Token tidak ditemukan');

      final r = await http.get(
        Uri.parse('$_baseUrl/orders/seller/$orderId'),
        headers: _headers(tok),
      );

      final body = r.body.isEmpty ? '{}' : r.body;
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;

      return _fail('Response tidak valid', status: r.statusCode);
    } catch (e) {
      return _fail('Gagal memuat detail: $e');
    }
  }
}
