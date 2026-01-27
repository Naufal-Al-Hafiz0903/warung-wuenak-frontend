import '../../models/product_model.dart';
import '../../services/user_http.dart';

class ProductService {
  static const String _list = 'products/listProduct';
  static const String _delete = 'products/deleteProducts';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['products'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static String _withQuery(String path, Map<String, String> qp) {
    if (qp.isEmpty) return path;
    final q = qp.entries
        .where((e) => e.value.trim().isNotEmpty)
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    if (q.isEmpty) return path;
    return '$path?$q';
  }

  // ======================================================
  // ✅ LIST + SEARCH SERVER-SIDE + FILTER STATUS
  // status: all|aktif|nonaktif
  // ======================================================
  static Future<List<ProductModel>> fetchSellerProducts({
    String q = '',
    String status = 'all',
  }) async {
    final qp = <String, String>{
      'q': q.trim(),
      'status': status.trim().isEmpty ? 'all' : status.trim(),
    };

    final path = _withQuery(_list, qp);

    final res = await UserHttp.getJson(path);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <ProductModel>[];
  }

  // ======================================================
  // ✅ untuk HomePage (user dashboard) - kalau masih dipakai
  // ======================================================
  static Future<List<ProductModel>> fetchProducts({
    String q = '',
    String status = 'all',
  }) async {
    return fetchSellerProducts(q: q, status: status);
  }

  // ======================================================
  // ✅ kompat lama
  // ======================================================
  static Future<List> getSellerProducts() async {
    final res = await UserHttp.getJson(_list);
    if (res['ok'] == true) return _extractList(res);
    return [];
  }

  // ======================================================
  // ✅ delete produk
  // ======================================================
  static Future<bool> deleteProduct(int productId) async {
    final res = await UserHttp.postForm(_delete, {
      'product_id': productId.toString(),
    });
    return res['ok'] == true;
  }
}
