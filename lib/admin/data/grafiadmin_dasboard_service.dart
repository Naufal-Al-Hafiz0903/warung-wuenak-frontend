import '../../services/admin_http.dart';
import '../../models/toko_model.dart';

class AdminSalesPoint {
  final String label;
  final double total;

  // optional meta
  final String? date;
  final String? weekStart;

  AdminSalesPoint({
    required this.label,
    required this.total,
    this.date,
    this.weekStart,
  });

  factory AdminSalesPoint.fromJson(Map<String, dynamic> j) {
    double toD(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    String pickLabel() {
      final a = j['label']?.toString();
      if (a != null && a.trim().isNotEmpty) return a;
      final b = j['date']?.toString();
      if (b != null && b.trim().isNotEmpty) return b;
      final c = j['week_start']?.toString();
      if (c != null && c.trim().isNotEmpty) return c;
      return '-';
    }

    return AdminSalesPoint(
      label: pickLabel(),
      total: toD(j['total']),
      date: j['date']?.toString(),
      weekStart: j['week_start']?.toString(),
    );
  }
}

class AdminTopProductSold {
  final int productId;
  final String namaProduk;
  final int jumlahTerjual;
  final int harga;
  final String? imageUrl;

  AdminTopProductSold({
    required this.productId,
    required this.namaProduk,
    required this.jumlahTerjual,
    required this.harga,
    this.imageUrl,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  factory AdminTopProductSold.fromJson(Map<String, dynamic> j) {
    return AdminTopProductSold(
      productId: _toInt(j['product_id'] ?? j['productId']),
      namaProduk: (j['nama_produk'] ?? j['namaProduk'] ?? '').toString(),
      jumlahTerjual: _toInt(
        j['jumlah_terjual'] ?? j['jumlahTerjual'] ?? j['qty'],
      ),
      harga: _toInt(j['harga']),
      imageUrl: (j['image_url'] ?? j['imageUrl'])?.toString(),
    );
  }
}

class GrafiAdminDasboardService {
  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['items'], res['list']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  /// ADMIN: ambil list toko (penjual)
  /// GET /toko/list?status=aktif (optional)
  static Future<List<TokoModel>> fetchTokos({String? status}) async {
    final qs = (status == null || status.trim().isEmpty)
        ? ''
        : '?status=${Uri.encodeComponent(status.trim())}';

    final res = await AdminHttp.getJson('toko/list$qs');

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => TokoModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <TokoModel>[];
  }

  /// ADMIN: grafik penjualan per toko_id (mode daily|weekly)
  /// GET /seller/dashboard/sales?mode=...&days=...&toko_id=...
  static Future<List<AdminSalesPoint>> fetchSalesSeries({
    required int tokoId,
    required String mode, // daily|weekly
    int days = 30,
  }) async {
    final m = (mode.trim().toLowerCase() == 'weekly') ? 'weekly' : 'daily';
    final d = (days <= 0) ? 30 : days;
    final ep = 'seller/dashboard/sales?mode=$m&days=$d&toko_id=$tokoId';

    final res = await AdminHttp.getJson(ep);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => AdminSalesPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <AdminSalesPoint>[];
  }

  /// ADMIN: top produk terjual per toko_id
  /// GET /seller/dashboard/products?days=...&limit=...&toko_id=...
  static Future<List<AdminTopProductSold>> fetchTopProductsSold({
    required int tokoId,
    int days = 30,
    int limit = 10,
  }) async {
    final d = (days <= 0) ? 30 : days;
    final lim = (limit <= 0) ? 10 : limit;
    final ep = 'seller/dashboard/products?days=$d&limit=$lim&toko_id=$tokoId';

    final res = await AdminHttp.getJson(ep);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map(
            (e) => AdminTopProductSold.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
    return <AdminTopProductSold>[];
  }
}
