import '../models/order_model.dart';
import 'admin_http.dart';

class OrderServiceAdmin {
  static const String listAdmin = 'orders/list_admin.php';
  static const String updateStatusEndpoint = 'orders/update_status.php';

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

    // kalau backend balas 401/403, tetap aman
    return [];
  }

  static Future<bool> updateStatus({
    required int orderId,
    required String status, // menunggu|dibayar|dikirim|selesai
  }) async {
    final res = await AdminHttp.postForm(updateStatusEndpoint, {
      'order_id': orderId.toString(),
      'status': status,
    });

    return res['ok'] == true;
  }
}
