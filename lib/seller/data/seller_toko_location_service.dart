import '../../../services/user_http.dart';

class SellerTokoLocationService {
  /// GET /toko/my/location
  static Future<Map<String, dynamic>?> fetchMyTokoLocation() async {
    final res = await UserHttp.getJson('toko/my/location');

    if (res['ok'] == true && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data']);
    }

    return null;
  }

  /// POST /toko/my/location
  /// body: {lat,lng,accuracy_m}
  static Future<Map<String, dynamic>> updateMyTokoLocation({
    required double lat,
    required double lng,
    int? accuracyM,
  }) async {
    final body = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    };

    return UserHttp.postJson('toko/my/location', body);
  }
}
