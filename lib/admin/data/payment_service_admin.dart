import '../../models/payment_model.dart';
import '../../services/admin_http.dart';

class PaymentServiceAdmin {
  // LIST
  static const String listEndpoint = 'payments'; // bisa juga 'payments/list'

  // CREATE / UPDATE / CONFIRM
  static const String createEndpoint = 'payments/create';
  static const String updateStatusEndpoint = 'payments/update_status';
  static const String confirmEndpoint = 'payments/confirm';

  // OPTIONS
  static const String orderOptionsEndpoint = 'payments/order-options';

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
          .whereType<Map>()
          .map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return <PaymentModel>[];
  }

  static Future<List<String>> fetchOrderIdOptions() async {
    final res = await AdminHttp.getJson(orderOptionsEndpoint);
    if (res['ok'] == true && res['data'] is List) {
      final raw = res['data'] as List;
      final ids = <String>[];

      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = (m['order_id'] ?? m['orderId'] ?? m['id'])?.toString();
        if (id != null && id.trim().isNotEmpty) ids.add(id.trim());
      }
      return ids;
    }
    return <String>[];
  }

  static Future<bool> createPayment({
    required int orderId,
    required String metode,
    required String status,
    String? provider,
    String? referenceCode,
    String? paidAt,
  }) async {
    final payload = <String, String>{
      'order_id': orderId.toString(),
      'metode': metode.trim(),
      'status': status.trim(),
      'provider': (provider ?? '').trim(),
      'reference_code': (referenceCode ?? '').trim(),
      'paid_at': (paidAt ?? '').trim(),
    };

    final res = await AdminHttp.postForm(createEndpoint, payload);
    return res['ok'] == true;
  }

  static Future<bool> updateStatus({
    required int paymentId,
    required String status,
  }) async {
    final payload = <String, String>{
      'payment_id': paymentId.toString(),
      'status': status.trim(),
    };

    final res = await AdminHttp.postForm(updateStatusEndpoint, payload);
    return res['ok'] == true;
  }

  static Future<bool> confirmPayment(int paymentId) async {
    final payload = <String, String>{
      'payment_id': paymentId.toString(),
      'status': 'dibayar',
    };

    final res = await AdminHttp.postForm(confirmEndpoint, payload);
    return res['ok'] == true;
  }
}
