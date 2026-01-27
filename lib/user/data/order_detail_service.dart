import '../../services/user_http.dart';

class OrderDetailService {
  static Future<Map<String, dynamic>> fetchDetail(int orderId) async {
    return UserHttp.getJson('orders/detail?order_id=$orderId');
  }
}
