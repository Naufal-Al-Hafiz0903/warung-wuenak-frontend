import '../models/product_model.dart';
import 'admin_http.dart';

class ProductAdminService {
  static const String listEndpoint = 'products/list.php';
  static const String updateEndpoint = 'products/update.php';
  static const String deleteEndpoint = 'products/delete.php';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['products'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<ProductModel>> fetchProducts() async {
    final res = await AdminHttp.getJson(listEndpoint);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<bool> updateProduct({
    required int productId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status, // aktif|nonaktif
    required int categoryId,
  }) async {
    final res = await AdminHttp.postForm(updateEndpoint, {
      'product_id': productId.toString(),
      'nama_produk': namaProduk,
      'deskripsi': deskripsi,
      'harga': harga.toString(),
      'stok': stok.toString(),
      'status': status,
      'category_id': categoryId.toString(),
    });
    return res['ok'] == true;
  }

  static Future<bool> deleteProduct(int productId) async {
    final res = await AdminHttp.postForm(deleteEndpoint, {
      'product_id': productId.toString(),
    });
    return res['ok'] == true;
  }
}
