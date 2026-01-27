class OrderModel {
  final int orderId;
  final int userId;

  final double totalAmount;

  double get totalPrice => totalAmount;

  final String status;
  final String metodePembayaran;
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
      orderId: _toInt(j['order_id'] ?? j['orderId'] ?? j['id']),
      userId: _toInt(j['user_id'] ?? j['userId']),
      totalAmount: _toDouble(j['total_amount'] ?? j['totalAmount']),
      status: (j['status'] ?? 'menunggu').toString(),
      metodePembayaran:
          (j['metode_pembayaran'] ?? j['metodePembayaran'] ?? 'transfer')
              .toString(),
      createdAt: j['created_at']?.toString() ?? j['createdAt']?.toString(),
      pembeli: j['pembeli']?.toString(),
    );
  }
}
