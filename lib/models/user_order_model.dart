class UserOrderModel {
  final int orderId;
  final num totalAmount;
  final String status;
  final String metodePembayaran;
  final String alamatPengiriman;
  final num ongkir;
  final String? kurir;
  final String createdAt;

  final double? buyerLat;
  final double? buyerLng;

  final String? namaToko;
  final double? sellerLat;
  final double? sellerLng;

  UserOrderModel({
    required this.orderId,
    required this.totalAmount,
    required this.status,
    required this.metodePembayaran,
    required this.alamatPengiriman,
    required this.ongkir,
    required this.kurir,
    required this.createdAt,
    required this.buyerLat,
    required this.buyerLng,
    required this.namaToko,
    required this.sellerLat,
    required this.sellerLng,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static num _toNum(dynamic v) => num.tryParse(v?.toString() ?? '') ?? 0;
  static double? _toDoubleN(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  static String _toStr(dynamic v, String def) {
    final s = (v ?? def).toString();
    return s.isEmpty ? def : s;
  }

  static String? _toStrN(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory UserOrderModel.fromJson(Map<String, dynamic> j) {
    return UserOrderModel(
      orderId: _toInt(j['order_id'] ?? j['orderId']),
      totalAmount: _toNum(j['total_amount'] ?? j['totalAmount']),
      status: _toStr(j['status'], 'menunggu'),
      metodePembayaran: _toStr(
        j['metode_pembayaran'] ?? j['metodePembayaran'],
        'cash',
      ),
      alamatPengiriman: _toStr(
        j['alamat_pengiriman'] ?? j['alamatPengiriman'],
        '',
      ),
      ongkir: _toNum(j['ongkir']),
      kurir: _toStrN(j['kurir']),
      createdAt: _toStr(j['created_at'] ?? j['createdAt'], ''),

      buyerLat: _toDoubleN(j['buyer_lat'] ?? j['buyerLat']),
      buyerLng: _toDoubleN(j['buyer_lng'] ?? j['buyerLng']),

      namaToko: _toStrN(j['nama_toko'] ?? j['namaToko']),
      sellerLat: _toDoubleN(j['seller_lat'] ?? j['sellerLat']),
      sellerLng: _toDoubleN(j['seller_lng'] ?? j['sellerLng']),
    );
  }
}
