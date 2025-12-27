import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api.dart';
import 'auth_service.dart';
import '../models/product_model.dart';
import 'user_http.dart';

class ProductService {
  // ================================
  // (TETAP) UNTUK SELLER (code lama)
  // ================================
  static Future<List> getSellerProducts() async {
    final token = await AuthService.getToken();

    final res = await http.get(
      Uri.parse("${Api.baseUrl}/products/list.php"),
      headers: {"Authorization": "Bearer $token"},
    );

    final data = json.decode(res.body);
    return data['data'] ?? [];
  }

  // ================================
  // (BARU) UNTUK USER DASHBOARD
  // ================================
  static const String _list = 'products/list.php';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['products'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<ProductModel>> fetchProducts() async {
    final res = await UserHttp.getJson(_list);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
