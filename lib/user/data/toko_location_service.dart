import '../../../services/user_http.dart';

class TokoLocationService {
  static Future<Map<String, dynamic>?> fetchTokoLocation(int tokoId) async {
    final res = await UserHttp.getJson('toko/location/$tokoId');
    if (res['ok'] == true) {
      final d = res['data'];
      if (d is Map) return Map<String, dynamic>.from(d);
    }
    return null;
  }
}
