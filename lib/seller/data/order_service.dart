import '../../models/order_model.dart';
import '../../services/user_http.dart';

class OrderService {
  // endpoint existing (ROLE_USER)
  static const String _listMyOrdersEndpoint = 'orders/my';

  // rekomendasi (kalau nanti kamu buat endpoint penjual)
  static const String _sellerOrdersEndpoint = 'orders/seller';

  static List<dynamic> _extractList(Map<String, dynamic> res) {
    final candidates = <dynamic>[res['data'], res['orders'], res['items']];
    for (final c in candidates) {
      if (c is List) return c.cast<dynamic>();
    }
    return <dynamic>[];
  }

  // ======================================================
  // ✅ COMPAT: dipakai HomePage -> UserOrdersPage
  // ======================================================
  static Future<List<OrderModel>> fetchMyOrders() async {
    final res = await UserHttp.getJson(_listMyOrdersEndpoint);

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return <OrderModel>[];
  }

  // ======================================================
  // OPTIONAL: untuk seller (kalau endpoint /orders/seller dibuat)
  // ======================================================
  static Future<Map<String, dynamic>> fetchSellerOrdersRaw() async {
    final resSeller = await UserHttp.getJson(_sellerOrdersEndpoint);
    if (resSeller['ok'] == true) return resSeller;
    return resSeller;
  }

  static Future<List<OrderModel>> fetchSellerOrders() async {
    final res = await fetchSellerOrdersRaw();
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return <OrderModel>[];
  }
}
