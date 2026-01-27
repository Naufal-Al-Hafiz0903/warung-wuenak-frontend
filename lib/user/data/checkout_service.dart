import '../../services/user_http.dart';

class CheckoutService {
  /// ✅ Quote ongkir per-km dari server:
  /// GET /orders/ongkir/quote?kurir=...&buyer_lat=...&buyer_lng=...
  static Future<Map<String, dynamic>> quoteOngkir({
    required String kurir,
    double? buyerLat,
    double? buyerLng,
    int? accuracyM,
  }) async {
    final qs = <String>[
      'kurir=${Uri.encodeQueryComponent(kurir)}',
      if (buyerLat != null) 'buyer_lat=$buyerLat',
      if (buyerLng != null) 'buyer_lng=$buyerLng',
      if (accuracyM != null) 'accuracy_m=$accuracyM',
    ].join('&');

    return UserHttp.getJson('orders/ongkir/quote?$qs');
  }

  /// ✅ Checkout:
  /// POST /orders/checkout
  ///
  /// Body:
  /// - metode_pembayaran: cash|transfer|qris
  /// - kurir: kurirku|gosend|grabexpress
  /// - alamat_pengiriman
  /// Optional:
  /// - buyer_lat, buyer_lng, accuracy_m
  /// - ongkir (optional, untuk kompat lama; idealnya server hitung sendiri)
  static Future<Map<String, dynamic>> checkoutFromCart({
    required String metodePembayaran,
    required String kurir,
    int? ongkir,
    required String alamatPengiriman,
    double? buyerLat,
    double? buyerLng,
    int? accuracyM,
  }) async {
    final body = <String, dynamic>{
      'metode_pembayaran': metodePembayaran,
      'kurir': kurir,
      'alamat_pengiriman': alamatPengiriman,
      if (ongkir != null) 'ongkir': ongkir,
      if (buyerLat != null) 'buyer_lat': buyerLat,
      if (buyerLng != null) 'buyer_lng': buyerLng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    };

    return UserHttp.postJson('orders/checkout', body);
  }
}
