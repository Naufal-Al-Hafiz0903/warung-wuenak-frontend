import '../../models/order_model.dart';
import '../../services/admin_http.dart';

class OrderServiceAdmin {
  static const String listAdmin = 'orders/admin';

  // ✅ Pakai endpoint baru dulu, fallback ke legacy
  static const String updateStatusEndpoint = 'orders/update-status';
  static const String updateStatusEndpointLegacy = 'orders/updateStatus';

  // ✅ create order admin
  static const String createEndpoint = 'orders/admin/create';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['orders'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<OrderModel>> fetchOrders() async {
    final res = await AdminHttp.getJson(listAdmin);

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return [];
  }

  // =========================================================
  // ✅ UPDATE STATUS (ADMIN)
  // FIX: sebelumnya postForm -> menyebabkan 500 Content-Type not supported
  // sekarang: postJson (sesuai backend consumes JSON)
  // =========================================================
  static Future<bool> updateStatus({
    required int orderId,
    required String status, // menunggu|dibayar|dikirim|selesai
  }) async {
    final payload = <String, dynamic>{'order_id': orderId, 'status': status};

    // 1) coba endpoint baru
    var res = await AdminHttp.postJson(updateStatusEndpoint, payload);
    if (res['ok'] == true) return true;

    // 2) fallback endpoint legacy
    res = await AdminHttp.postJson(updateStatusEndpointLegacy, payload);
    if (res['ok'] == true) return true;

    return false;
  }

  // =========================================================
  // ✅ CREATE ORDER (ADMIN)
  // =========================================================
  static Future<bool> createOrder({
    required int userId,
    required String metodePembayaran, // transfer|ewallet|cod|cash|qris
    String status = 'menunggu',
    required List<Map<String, dynamic>>
    items, // [{product_id, quantity, toko_id?}]
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'metode_pembayaran': metodePembayaran,
      'status': status,
      'items': items,
    };

    final res = await AdminHttp.postJson(createEndpoint, payload);
    return res['ok'] == true;
  }
}
