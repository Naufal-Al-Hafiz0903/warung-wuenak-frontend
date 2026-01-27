import '../models/cart_item_model.dart';
import 'user_http.dart';

class CartService {
  static const String _my = 'cart/my';
  static const String _add = 'cart/add';
  static const String _updateQty = 'cart/update-qty';
  static const String _clear = 'cart/clear';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['items'], res['cart']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<CartItemModel>> fetchMyCart() async {
    final res = await UserHttp.getJson(_my);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => CartItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <CartItemModel>[];
  }

  // ✅ FIX: kirim JSON (bukan form-urlencoded)
  static Future<bool> addToCart({
    required int productId,
    int quantity = 1,
  }) async {
    final res = await UserHttp.postJson(_add, {
      'product_id': productId,
      'quantity': quantity,
    });
    return res['ok'] == true;
  }

  // ✅ FIX: kirim JSON
  static Future<bool> updateQty({
    required int productId,
    required int quantity,
  }) async {
    final res = await UserHttp.postJson(_updateQty, {
      'product_id': productId,
      'quantity': quantity,
    });
    return res['ok'] == true;
  }

  // ✅ FIX: tetap kirim JSON kosong agar content-type aman
  static Future<bool> clear() async {
    final res = await UserHttp.postJson(_clear, {});
    return res['ok'] == true;
  }
}
