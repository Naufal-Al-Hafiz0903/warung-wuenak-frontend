import '../../services/user_http.dart';
import '../../models/shipment_tracking_model.dart';

class CourierShipmentsService {
  // =========================
  // Endpoint candidates (fallback)
  // =========================
  static const List<String> _myCandidates = [
    'shipments/my', // target utama (kurir)
    'shipments/kurir/my',
    'shipments/courier/my',
    'shipments/kurir',
    'shipments/courier',
  ];

  static List<String> byOrderCandidates(int orderId) => [
    'shipments/order/$orderId', // sesuai backend kamu
    'shipments/by-order/$orderId',
    'shipments/order/${orderId.toString()}',
  ];

  static const List<String> _updateStatusCandidates = [
    'shipments/update-status',
    'shipments/updateStatus',
    'shipments/kurir/update-status',
    'shipments/courier/update-status',
  ];

  // =========================
  // ✅ LIVE LOCATION (BARU)
  // =========================
  static const String _livePush = 'shipments/live-location';
  static String _liveGetByOrder(int orderId) =>
      'shipments/live-location/order/$orderId';

  /// Kurir push lokasi live (hemat server: backend akan throttle juga)
  static Future<Map<String, dynamic>> pushLiveLocation({
    required int orderId,
    required double lat,
    required double lng,
    int? accuracyM,
  }) async {
    final body = <String, dynamic>{
      'order_id': orderId,
      'lat': lat,
      'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    };
    return await UserHttp.postJson(_livePush, body);
  }

  /// Ambil lokasi live terbaru untuk order (bisa null kalau belum ada/TTL habis)
  static Future<Map<String, dynamic>?> fetchLiveLocationByOrder(
    int orderId,
  ) async {
    final res = await UserHttp.getJson(_liveGetByOrder(orderId));
    if (res['ok'] == true) {
      final d = res['data'];
      if (d == null) return null;
      if (d is Map) return Map<String, dynamic>.from(d as Map);
    }
    return null;
  }

  // =========================
  // Public API
  // =========================

  static Future<List<ShipmentTrackingModel>> fetchMyTasks() async {
    for (final p in _myCandidates) {
      final res = await UserHttp.getJson(p);
      if (res['ok'] == true) {
        final list = _extractList(res);
        return list
            .map(
              (e) => ShipmentTrackingModel.fromJson(_normalizeTrackingJson(e)),
            )
            .toList();
      }

      final st = (res['status'] ?? res['statusCode'] ?? 0);
      final code = int.tryParse('$st') ?? 0;
      if (code == 404 || code == 405) continue;
    }
    return <ShipmentTrackingModel>[];
  }

  static Future<Map<String, dynamic>?> fetchTaskDetailRawByOrder(
    int orderId,
  ) async {
    for (final p in byOrderCandidates(orderId)) {
      final res = await UserHttp.getJson(p);
      if (res['ok'] == true) {
        final data = _extractMap(res);
        if (data != null) return _normalizeDetailJson(data);
        return null;
      }

      final st = (res['status'] ?? res['statusCode'] ?? 0);
      final code = int.tryParse('$st') ?? 0;
      if (code == 404 || code == 405) continue;
    }
    return null;
  }

  static Future<ShipmentTrackingModel?> fetchTaskDetailByOrder(
    int orderId,
  ) async {
    final data = await fetchTaskDetailRawByOrder(orderId);
    if (data == null) return null;
    return ShipmentTrackingModel.fromJson(_normalizeTrackingJson(data));
  }

  static Future<Map<String, dynamic>> updateStatus({
    required int orderId,
    required String status,
    String? description,
    String? location,
  }) async {
    final body = <String, dynamic>{'order_id': orderId, 'status': status};
    if (description != null) body['description'] = description;
    if (location != null) body['location'] = location;

    Map<String, dynamic> last = {
      'ok': false,
      'message': 'Endpoint update status belum tersedia',
    };

    for (final p in _updateStatusCandidates) {
      final res = await UserHttp.postJson(p, body);
      last = res;
      if (res['ok'] == true) return res;

      final st = (res['status'] ?? res['statusCode'] ?? 0);
      final code = int.tryParse('$st') ?? 0;
      if (code == 404 || code == 405) continue;
    }
    return last;
  }

  // =========================
  // Helpers: extract list/map
  // =========================
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

  // =========================
  // Normalization
  // =========================
  static Map<String, dynamic> _normalizeTrackingJson(Map<String, dynamic> j) {
    final out = Map<String, dynamic>.from(j);

    out['shipment_id'] ??= out['shipmentId'] ?? out['id'];
    out['order_id'] ??= out['orderId'];

    out['courier'] ??= out['kurir'] ?? out['courier_name'];
    out['tracking_number'] ??= out['nomor_resi'] ?? out['resi'];

    out['updated_at'] ??= out['updatedAt'];

    final ev = out['events'] ?? out['history'] ?? out['timeline'];
    if (ev is List) {
      out['events'] = ev
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return out;
  }

  static Map<String, dynamic> _normalizeDetailJson(Map<String, dynamic> j) {
    final out = _normalizeTrackingJson(j);

    out['buyer'] ??= out['pembeli'] ?? out['user'] ?? out['customer'];

    out['alamat_pengiriman'] ??=
        out['alamat'] ?? out['alamatUser'] ?? out['alamat_user'];

    // kalau backend nanti kirim koordinat
    out['buyer_lat'] ??= out['dest_lat'] ?? out['destination_lat'];
    out['buyer_lng'] ??= out['dest_lng'] ?? out['destination_lng'];

    return out;
  }
}
