import 'user_http.dart';

class PaymentService {
  // Catatan:
  // Endpoint disesuaikan dengan backend kamu.
  // Yang penting file ini menyediakan method & signature yang dipakai PaymentPage.

  static Future<Map<String, dynamic>> createQrisXendit({
    required int orderId,
    required int amount,
  }) async {
    final res = await UserHttp.postJson('/payments/qris', {
      'order_id': orderId,
      'amount': amount,
    });

    return res;
  }

  static Future<Map<String, dynamic>> createVaBcaXendit({
    required int orderId,
    required String name,
    required int expectedAmount,
  }) async {
    final res = await UserHttp.postJson('/payments/va-bca', {
      'order_id': orderId,
      'name': name,
      'expected_amount': expectedAmount,
    });

    return res;
  }
}
