import '../../services/admin_http.dart';

class AdminDashboardService {
  static Future<int> _countListFrom(String endpoint) async {
    final res = await AdminHttp.getJson(endpoint);

    if (res['ok'] == true) {
      final data = res['data'];

      // backend return {"ok":true,"data":[...]}
      if (data is List) return data.length;

      // fallback kalau backend return {"data":{"items":[...]}}
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).length;
      }

      // fallback kalau backend return {"orders":[...]} atau {"items":[...]}
      for (final key in ['orders', 'items', 'products', 'users', 'payments']) {
        if (res[key] is List) return (res[key] as List).length;
      }
    }

    return 0;
  }

  static Future<Map<String, dynamic>> fetchStats() async {
    final users = await _countListFrom('users'); // nanti backend: GET /users
    final products = await _countListFrom('products/listProduct');
    final orders = await _countListFrom(
      'orders/admin',
    ); // nanti backend: GET /orders/admin
    final payments = await _countListFrom(
      'payments',
    ); // nanti backend: GET /payments

    return {
      'users': users,
      'products': products,
      'orders': orders,
      'payments': payments,
    };
  }
}
