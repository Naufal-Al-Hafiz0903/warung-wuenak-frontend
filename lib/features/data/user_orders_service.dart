import '../../../services/user_http.dart';
import '../../../models/user_order_model.dart';

class UserOrdersService {
  static Future<List<UserOrderModel>> fetchMyOrders() async {
    final res = await UserHttp.getJson('orders/my');

    if (res['ok'] == true && res['data'] is List) {
      return (res['data'] as List)
          .whereType<Map>()
          .map((e) => UserOrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return <UserOrderModel>[];
  }
}
