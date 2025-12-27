import '../models/user_model.dart';
import 'admin_http.dart';

class UserService {
  static const String listEndpoint = 'users/list.php';
  static const String changeLevelEndpoint = 'users/change_level.php';
  static const String updateStatusEndpoint = 'users/update_status.php';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['users'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<UserModel>> fetchUsers() async {
    final res = await AdminHttp.getJson(listEndpoint);
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<bool> changeLevel({
    required int userId,
    required String level, // admin|penjual|user
  }) async {
    final res = await AdminHttp.postForm(changeLevelEndpoint, {
      'user_id': userId.toString(),
      'level': level,
    });
    return res['ok'] == true;
  }

  static Future<bool> updateStatus({
    required int userId,
    required String status, // aktif|nonaktif
  }) async {
    final res = await AdminHttp.postForm(updateStatusEndpoint, {
      'user_id': userId.toString(),
      'status': status,
    });
    return res['ok'] == true;
  }
}
