class ShipmentModel {
  final int shipmentId;
  final int orderId;

  final String? kurir;
  final String? nomorResi;
  final double ongkir;

  final String status; // diproses|dikirim|diterima

  ShipmentModel({
    required this.shipmentId,
    required this.orderId,
    required this.kurir,
    required this.nomorResi,
    required this.ongkir,
    required this.status,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  static String? _pick(dynamic a, dynamic b) {
    final v = a ?? b;
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _lower(dynamic v, String def) {
    final s = (v ?? def).toString().trim();
    return s.isEmpty ? def : s.toLowerCase();
  }

  factory ShipmentModel.fromJson(Map<String, dynamic> j) {
    return ShipmentModel(
      shipmentId: _toInt(j['shipment_id'] ?? j['shipmentId'] ?? j['id']),
      orderId: _toInt(j['order_id'] ?? j['orderId']),
      kurir: _pick(j['kurir'], j['courier']),
      nomorResi:
          _pick(j['nomor_resi'], j['nomorResi']) ??
          _pick(j['resi'], j['tracking']),
      ongkir: _toDouble(j['ongkir'] ?? j['shipping_fee'] ?? j['shippingFee']),
      status: _lower(j['status'], 'diproses'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_id': shipmentId,
      'order_id': orderId,
      'kurir': kurir,
      'nomor_resi': nomorResi,
      'ongkir': ongkir,
      'status': status,
    };
  }
}
