import '../models/payment_model.dart';
import 'admin_http.dart';

class PaymentService {
  static const String listEndpoint = 'payments/list.php';
  static const String confirmEndpoint = 'payments/confirm.php';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['payments'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<PaymentModel>> fetchPayments() async {
    final res = await AdminHttp.getJson(listEndpoint);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Confirm = set status jadi "dibayar" (sesuai ENUM payments.status)
  static Future<bool> confirmPayment(int paymentId) async {
    final res = await AdminHttp.postForm(confirmEndpoint, {
      'payment_id': paymentId.toString(),
      'status': 'dibayar',
    });
    return res['ok'] == true;
  }
}
