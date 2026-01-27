import '../../models/payment_model.dart';
import '../../services/admin_http.dart';

class PaymentService {
  // endpoint baru (java style)
  static const String _listNew = 'payments/list';
  static const String _confirmNew = 'payments/confirm';

  // fallback legacy (kalau backend lama masih kepakai)
  static const String _listLegacy = 'payments/list.php';
  static const String _confirmLegacy = 'payments/confirm.php';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['payments'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<PaymentModel>> fetchPayments() async {
    // coba yang baru dulu
    Map<String, dynamic> res = await AdminHttp.getJson(_listNew);

    // kalau endpoint baru belum ada / error, fallback ke .php
    if (res['ok'] != true) {
      res = await AdminHttp.getJson(_listLegacy);
    }

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
    Map<String, dynamic> res = await AdminHttp.postForm(_confirmNew, {
      'payment_id': paymentId.toString(),
      'status': 'dibayar',
    });

    // fallback legacy
    if (res['ok'] != true) {
      res = await AdminHttp.postForm(_confirmLegacy, {
        'payment_id': paymentId.toString(),
        'status': 'dibayar',
      });
    }

    return res['ok'] == true;
  }
}
