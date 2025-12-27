import '../models/order_model.dart';
import 'user_http.dart';

class OrderService {
  static const String _listUser = 'orders/list_user.php';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['orders'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<OrderModel>> fetchMyOrders() async {
    final res = await UserHttp.getJson(_listUser);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
