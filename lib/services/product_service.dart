import '../models/product_model.dart';
import 'user_http.dart';

class ProductService {
  static const String _delete = 'products/deleteProducts';
  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['products'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Map<String, dynamic>? _extractMap(Map<String, dynamic> res) {
    final candidates = [res['data'], res['product'], res['item']];
    for (final c in candidates) {
      if (c is Map) return Map<String, dynamic>.from(c);
    }
    return null;
  }

  /// ✅ MATCH BACKEND:
  /// GET /products/listProduct?q=...&status=all|aktif|nonaktif&categoryId=...
  static Future<List<ProductModel>> fetchProducts({
    String? query,
    int? categoryId,
  }) async {
    // build params (utama)
    final qs = <String, String>{
      'status': 'all', // ✅ penting: backend kamu pakai status
    };

    if (query != null && query.trim().isNotEmpty) {
      qs['q'] = query.trim();
    }

    // backend support categoryId atau category_id (aku coba dua cara)
    List<Map<String, String>> variants = [];
    if (categoryId != null && categoryId > 0) {
      variants.add({...qs, 'categoryId': categoryId.toString()});
      variants.add({...qs, 'category_id': categoryId.toString()});
    } else {
      variants.add(qs);
    }

    // kandidat endpoint sesuai backend kamu
    final basePaths = <String>['products/listProduct', 'products/listProducts'];

    for (final params in variants) {
      for (final path in basePaths) {
        final uri = Uri(path: path, queryParameters: params);
        final full = '${uri.path}?${uri.query}';

        final res = await UserHttp.getJson(full);

        if (res['ok'] == true) {
          final list = _extractList(res);
          return list
              .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    }

    // fallback lama (kalau backend lain)
    final fallback = <String>['products', 'products/list', 'products/all'];
    for (final p in fallback) {
      final res = await UserHttp.getJson(p);
      if (res['ok'] == true) {
        final list = _extractList(res);
        return list
            .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    return <ProductModel>[];
  }

  static Future<bool> deleteProduct(int productId) async {
    final res = await UserHttp.postJson(_delete, {'product_id': productId});
    return res['ok'] == true;
  }

  /// Detail produk (kompat backend kamu: /products/detailProducts?id=...)
  static Future<ProductModel?> fetchDetail(int productId) async {
    final tryPaths = <String>[
      'products/detailProducts?id=$productId', // ✅ backend kamu
      'products/$productId',
      'products/detail?product_id=$productId',
    ];

    for (final p in tryPaths) {
      final res = await UserHttp.getJson(p);
      if (res['ok'] == true) {
        final m = _extractMap(res);
        if (m != null) return ProductModel.fromJson(m);
      }
    }
    return null;
  }
}
