import '../../services/user_http.dart';
import '../../models/shipment_tracking_model.dart';

class TrackingService {
  static const List<String> _myCandidates = [
    'shipments/my',
    'shipments/user/my',
    'shipments/customer/my',
  ];

  static List<String> byOrderCandidates(int orderId) => [
    // ✅ sesuai backend kamu
    'shipments/order/$orderId',
    // fallback lama (kalau ada)
    'shipments/by-order/$orderId',
    'shipments/order/${orderId.toString()}',
  ];

  static List<Map<String, dynamic>> _extractList(Map<String, dynamic> res) {
    final cands = [res['data'], res['items'], res['shipments']];
    for (final c in cands) {
      if (c is List) {
        return c.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (c is Map) {
        final inner = c['data'] ?? c['items'] ?? c['shipments'];
        if (inner is List) {
          return inner.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic>? _extractMap(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is Map) return Map<String, dynamic>.from(d as Map);
    return null;
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> j) {
    final out = Map<String, dynamic>.from(j);

    // id
    out['shipment_id'] ??= out['shipmentId'] ?? out['id'];
    out['order_id'] ??= out['orderId'];

    // courier + resi (backend kamu pakai: kurir, nomor_resi)
    out['courier'] ??= out['kurir'] ?? out['courier_name'];
    out['tracking_number'] ??=
        out['nomor_resi'] ?? out['resi'] ?? out['trackingNumber'];

    // events
    final ev = out['events'] ?? out['history'] ?? out['timeline'];
    if (ev is List) {
      out['events'] = ev
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    // updated_at
    out['updated_at'] ??= out['updatedAt'];

    return out;
  }

  static Future<List<ShipmentTrackingModel>> fetchMy() async {
    for (final p in _myCandidates) {
      final res = await UserHttp.getJson(p);
      if (res['ok'] == true) {
        final list = _extractList(res);
        return list
            .map((e) => ShipmentTrackingModel.fromJson(_normalize(e)))
            .toList();
      }

      final st = (res['status'] ?? res['statusCode'] ?? 0);
      final code = int.tryParse('$st') ?? 0;
      if (code == 404 || code == 405) continue;
    }
    return <ShipmentTrackingModel>[];
  }

  static Future<ShipmentTrackingModel?> fetchByOrder(int orderId) async {
    Map<String, dynamic>? lastOk;

    for (final p in byOrderCandidates(orderId)) {
      final res = await UserHttp.getJson(p);
      if (res['ok'] == true) {
        final m = _extractMap(res);
        if (m == null) {
          // kalau server mengembalikan data langsung
          if (res is Map<String, dynamic>) {
            lastOk = Map<String, dynamic>.from(res);
          }
        } else {
          lastOk = m;
        }

        if (lastOk != null) {
          return ShipmentTrackingModel.fromJson(_normalize(lastOk!));
        }
        return null;
      }

      final st = (res['status'] ?? res['statusCode'] ?? 0);
      final code = int.tryParse('$st') ?? 0;
      if (code == 404 || code == 405) continue;
    }

    return null;
  }
}
