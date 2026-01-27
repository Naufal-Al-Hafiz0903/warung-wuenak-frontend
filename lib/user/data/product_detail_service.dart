import '../../models/image_model.dart';
import '../../models/product_model.dart';
import '../../services/user_http.dart';

class ProductDetailService {
  static Future<Map<String, dynamic>> fetchDetailRaw(int productId) async {
    return UserHttp.getJson('products/detailProducts?id=$productId');
  }

  static List _extractList(dynamic res, List<String> keys) {
    if (res is Map<String, dynamic>) {
      for (final k in keys) {
        final v = res[k];
        if (v is List) return v;
      }
    }
    return [];
  }

  static Future<ProductModel?> fetchProduct(int productId) async {
    final res = await fetchDetailRaw(productId);
    if (res['ok'] == true && res['product'] is Map) {
      return ProductModel.fromJson(Map<String, dynamic>.from(res['product']));
    }
    return null;
  }

  static Future<List<ImageModel>> fetchImages(int productId) async {
    final res = await fetchDetailRaw(productId);
    if (res['ok'] == true) {
      final list = _extractList(res, ['images', 'data', 'items']);
      return list
          .map((e) => ImageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
