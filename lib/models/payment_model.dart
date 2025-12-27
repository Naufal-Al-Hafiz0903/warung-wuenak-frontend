class PaymentModel {
  final int paymentId;
  final int orderId;
  final String metode; // transfer|ewallet|cod
  final String status; // menunggu|dibayar|gagal
  final String? paidAt;

  // dari JOIN
  final double? totalAmount;
  final String? pembeli;

  PaymentModel({
    required this.paymentId,
    required this.orderId,
    required this.metode,
    required this.status,
    required this.paidAt,
    required this.totalAmount,
    required this.pembeli,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory PaymentModel.fromJson(Map<String, dynamic> j) {
    return PaymentModel(
      paymentId: _toInt(j['payment_id']),
      orderId: _toInt(j['order_id']),
      metode: (j['metode'] ?? 'transfer').toString(),
      status: (j['status'] ?? 'menunggu').toString(),
      paidAt: j['paid_at']?.toString(),
      totalAmount: j.containsKey('total_amount')
          ? _toDouble(j['total_amount'])
          : null,
      pembeli: j['pembeli']?.toString(),
    );
  }
}
