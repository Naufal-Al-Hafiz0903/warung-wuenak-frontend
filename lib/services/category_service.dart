import '../models/category_model.dart';
import 'admin_http.dart';

class CategoryService {
  // UBAH sesuai endpoint backend kamu
  static const String _list = 'categories/list.php';
  static const String _create = 'categories/create.php';
  static const String _update = 'categories/update.php';
  static const String _delete = 'categories/delete.php';

  static Future<List<CategoryModel>> fetchCategories() async {
    final res = await AdminHttp.getJson(_list);
    if (res['ok'] == true) {
      final data = (res['data'] ?? res['categories'] ?? []) as List;
      return data
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<bool> create({
    required String name,
    String? description,
    int? parentId,
  }) async {
    final res = await AdminHttp.postForm(_create, {
      'category_name': name,
      'description': description ?? '',
      'parent_id': parentId?.toString() ?? '',
    });
    return res['ok'] == true;
  }

  static Future<bool> update({
    required int categoryId,
    required String name,
    String? description,
    int? parentId,
  }) async {
    final res = await AdminHttp.postForm(_update, {
      'category_id': categoryId.toString(),
      'category_name': name,
      'description': description ?? '',
      'parent_id': parentId?.toString() ?? '',
    });
    return res['ok'] == true;
  }

  static Future<bool> delete(int categoryId) async {
    final res = await AdminHttp.postForm(_delete, {
      'category_id': categoryId.toString(),
    });
    return res['ok'] == true;
  }
}
