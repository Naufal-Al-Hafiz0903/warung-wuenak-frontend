import '../../../models/user_order_model.dart';
import '../../../services/user_http.dart';

class UserOrdersService {
  static const List<String> _candidates = [
    'orders/my',
    'order/my',
    'orders/user',
    'pesanan/my',
    'orders',
  ];

  static List<Map<String, dynamic>> _extractList(Map<String, dynamic> res) {
    final cands = [res['data'], res['items'], res['orders']];
    for (final c in cands) {
      if (c is List) {
        return c.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (c is Map) {
        final inner = c['data'] ?? c['items'] ?? c['orders'];
        if (inner is List) {
          return inner.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  static String _pickMessage(Map<String, dynamic> res) {
    return (res['message'] ??
            res['error'] ??
            res['raw'] ??
            'Gagal memuat pesanan')
        .toString();
  }

  static Future<List<UserOrderModel>> fetchMyOrders() async {
    Map<String, dynamic>? last;

    for (final p in _candidates) {
      final res = await UserHttp.getJson(p);
      last = res;

      if (res['ok'] == true) {
        final list = _extractList(res);
        return list.map((e) => UserOrderModel.fromJson(e)).toList();
      }

      final st = (res['status'] ?? res['statusCode'] ?? 0);
      final code = int.tryParse('$st') ?? 0;
      if (code == 404 || code == 405) continue;
    }

    throw Exception(
      _pickMessage(last ?? {'message': 'Endpoint orders tidak tersedia'}),
    );
  }
}
