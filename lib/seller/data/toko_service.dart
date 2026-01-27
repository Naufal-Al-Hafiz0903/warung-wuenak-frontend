import 'package:flutter/foundation.dart';
import '../../services/admin_http.dart';

class TokoService {
  static const String statusMapEndpoint = 'toko/status-map';
  static const String createEndpoint = 'toko/create';
  static const String updateStatusEndpoint = 'toko/update-status';

  /// GET /toko/status-map?user_ids=1,2,3&fill_missing=1
  /// Backend bisa balikin: aktif | nonaktif | belum
  static Future<Map<int, String>> fetchTokoStatusMap({
    required List<int> userIds,
    bool fillMissing = true,
  }) async {
    if (userIds.isEmpty) return {};

    final csv = userIds.join(',');
    final ep =
        '$statusMapEndpoint?user_ids=$csv&fill_missing=${fillMissing ? 1 : 0}';

    final res = await AdminHttp.getJson(ep);

    if (kDebugMode) {
      debugPrint('[TokoService.fetchTokoStatusMap] $ep');
      debugPrint('[TokoService.fetchTokoStatusMap] res=$res');
    }

    if (res['ok'] == true && res['data'] is List) {
      final map = <int, String>{};

      for (final item in (res['data'] as List)) {
        if (item is Map) {
          final uidRaw = item['user_id'] ?? item['userId'];
          final stRaw = item['status'];

          final uid = int.tryParse(uidRaw?.toString() ?? '');
          final st = (stRaw ?? 'belum').toString().trim().toLowerCase();

          if (uid != null) map[uid] = st;
        }
      }

      return map;
    }

    return {};
  }

  /// POST /toko/create (x-www-form-urlencoded)
  /// - jika toko belum ada => wajib nama_toko (create)
  static Future<Map<String, dynamic>> createToko({
    required int userId,
    required String namaToko,
    String deskripsiToko = '',
    String alamatToko = '',
  }) async {
    final res = await AdminHttp.postForm(createEndpoint, {
      'user_id': userId.toString(),
      'nama_toko': namaToko,
      'deskripsi_toko': deskripsiToko,
      'alamat_toko': alamatToko,

      // kompatibilitas camelCase
      'userId': userId.toString(),
      'namaToko': namaToko,
      'deskripsiToko': deskripsiToko,
      'alamatToko': alamatToko,
    });

    if (kDebugMode) {
      debugPrint('[TokoService.createToko] res=$res');
    }

    return res;
  }

  /// POST /toko/create (tanpa nama) untuk re-activate toko yang SUDAH PERNAH ADA (nonaktif)
  static Future<Map<String, dynamic>> reactivateToko({
    required int userId,
  }) async {
    final res = await AdminHttp.postForm(createEndpoint, {
      'user_id': userId.toString(),
      'userId': userId.toString(),
    });

    if (kDebugMode) {
      debugPrint('[TokoService.reactivateToko] res=$res');
    }

    return res;
  }

  /// POST /toko/update-status (x-www-form-urlencoded)
  static Future<bool> updateStatusByUserId({
    required int userId,
    required String status,
  }) async {
    final st = status.trim().toLowerCase();

    final res = await AdminHttp.postForm(updateStatusEndpoint, {
      'user_id': userId.toString(),
      'status': st,
      'userId': userId.toString(),
    });

    if (kDebugMode) {
      debugPrint('[TokoService.updateStatusByUserId] res=$res');
    }

    return res['ok'] == true;
  }
}
