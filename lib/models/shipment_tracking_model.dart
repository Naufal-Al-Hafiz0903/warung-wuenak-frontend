import 'shipment_event_model.dart';

class ShipmentTrackingModel {
  final int shipmentId;
  final int orderId;
  final String status;
  final String? courier;
  final String? trackingNumber;
  final String? updatedAt;
  final List<ShipmentEventModel> events;

  ShipmentTrackingModel({
    required this.shipmentId,
    required this.orderId,
    required this.status,
    required this.courier,
    required this.trackingNumber,
    required this.updatedAt,
    required this.events,
  });

  static int _toInt(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  static String? _pickStr(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  factory ShipmentTrackingModel.fromJson(Map<String, dynamic> j) {
    final ev = j['events'] ?? j['history'] ?? j['timeline'];
    final list = (ev is List)
        ? ev
              .map(
                (e) =>
                    ShipmentEventModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <ShipmentEventModel>[];

    return ShipmentTrackingModel(
      shipmentId: _toInt(j['shipment_id'] ?? j['shipmentId'] ?? j['id']),
      orderId: _toInt(j['order_id'] ?? j['orderId']),
      status: (j['status'] ?? 'diproses').toString(),
      // ✅ support backend: kurir
      courier: _pickStr(j, ['courier', 'kurir', 'courier_name']),
      // ✅ support backend: nomor_resi
      trackingNumber: _pickStr(j, [
        'tracking_number',
        'nomor_resi',
        'resi',
        'trackingNumber',
      ]),
      updatedAt: (j['updated_at'] ?? j['updatedAt'])?.toString(),
      events: list,
    );
  }
}
