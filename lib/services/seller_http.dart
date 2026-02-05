// lib/services/seller_http.dart
import 'user_http.dart';

class SellerHttp {
  static Future<Map<String, dynamic>> getJson(String path) {
    return UserHttp.getJson(path);
  }

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return UserHttp.postJson(path, body);
  }

  static Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, String> body,
  ) {
    return UserHttp.postForm(path, body);
  }
}
