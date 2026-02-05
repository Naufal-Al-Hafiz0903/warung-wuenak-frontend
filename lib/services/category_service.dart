import '../models/category_model.dart';
import 'admin_http.dart';
import 'user_http.dart';

class CategoryService {
  static const String _base = 'categories';

  static const Duration _ttl = Duration(seconds: 30);

  static List<CategoryModel>? _cacheUser;
  static DateTime? _cacheUserAt;

  static List<CategoryModel>? _cacheAdmin;
  static DateTime? _cacheAdminAt;

  static bool _fresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _ttl;

  static void invalidateCache() {
    _cacheUser = null;
    _cacheUserAt = null;
    _cacheAdmin = null;
    _cacheAdminAt = null;
  }

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['categories'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<CategoryModel>> fetchCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cacheUser != null && _fresh(_cacheUserAt)) {
      return _cacheUser!;
    }

    final res = await UserHttp.getJson(_base);

    if (res['ok'] == true) {
      final list = _extractList(res)
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _cacheUser = list;
      _cacheUserAt = DateTime.now();
      return list;
    }

    return _cacheUser ?? <CategoryModel>[];
  }

  static Future<List<CategoryModel>> fetchCategoriesAdmin({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cacheAdmin != null && _fresh(_cacheAdminAt)) {
      return _cacheAdmin!;
    }

    final resAdmin = await AdminHttp.getJson(_base);

    if (resAdmin['ok'] == true) {
      final list = _extractList(resAdmin)
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _cacheAdmin = list;
      _cacheAdminAt = DateTime.now();
      return list;
    }

    final resUser = await UserHttp.getJson(_base);
    if (resUser['ok'] == true) {
      final list = _extractList(resUser)
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _cacheAdmin = list;
      _cacheAdminAt = DateTime.now();
      return list;
    }

    return _cacheAdmin ?? <CategoryModel>[];
  }

  static Future<Map<String, dynamic>> createResult({
    required String name,
    required String description,
  }) async {
    final body = <String, dynamic>{
      'category_name': name.trim(),
      'description': description.trim(),
    };

    final res = await AdminHttp.postJson('$_base/create', body);

    if (res['ok'] == true) invalidateCache();
    return res;
  }

  static Future<bool> create({
    required String name,
    required String description,
  }) async {
    final res = await createResult(name: name, description: description);
    return res['ok'] == true;
  }

  static Future<bool> delete(int categoryId) async {
    final res = await AdminHttp.postJson('$_base/delete', {
      'category_id': categoryId,
    });
    final ok = res['ok'] == true;

    if (ok) invalidateCache();
    return ok;
  }
}
