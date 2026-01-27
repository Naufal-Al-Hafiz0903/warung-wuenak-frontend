import '/models/user_model.dart';
import '../../services/admin_http.dart';

class UserServiceAdmin {
  static const String eligibleEndpoint = 'users/eligible-order-users';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['users'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<UserModel>> fetchEligibleOrderUsers() async {
    final res = await AdminHttp.getJson(eligibleEndpoint);

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return [];
  }
}
