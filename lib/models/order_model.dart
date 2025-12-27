class OrderModel {
  final int orderId;
  final int userId;

  /// total order (dari orders.total_amount)
  final double totalAmount;

  /// Alias agar kompatibel dengan code lama yang pakai o.totalPrice
  /// (TIDAK menghilangkan fungsi apa pun)
  double get totalPrice => totalAmount;

  final String status; // menunggu|dibayar|dikirim|selesai
  final String metodePembayaran; // transfer|ewallet|cod
  final String? createdAt;

  // dari JOIN
  final String? pembeli;

  OrderModel({
    required this.orderId,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.metodePembayaran,
    required this.createdAt,
    required this.pembeli,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory OrderModel.fromJson(Map<String, dynamic> j) {
    return OrderModel(
      orderId: _toInt(j['order_id']),
      userId: _toInt(j['user_id']),
      totalAmount: _toDouble(j['total_amount']),
      status: (j['status'] ?? 'menunggu').toString(),
      metodePembayaran: (j['metode_pembayaran'] ?? 'transfer').toString(),
      createdAt: j['created_at']?.toString(),
      pembeli: j['pembeli']?.toString(),
    );
  }
}
