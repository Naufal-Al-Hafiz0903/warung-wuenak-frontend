import 'package:flutter/foundation.dart';
import 'user_http.dart';

class CategoryRepository {
  static List<Map<String, dynamic>> _cache = [];
  static int _lastFetchMs = 0;

  static const int _ttlMs = 20 * 1000;

  static List<Map<String, dynamic>> getCached() =>
      List<Map<String, dynamic>>.from(_cache);

  static void invalidate() {
    _cache = [];
    _lastFetchMs = 0;
  }

  static int _toInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? def;
  }

  static Future<List<Map<String, dynamic>>> list({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fresh = _cache.isNotEmpty && (now - _lastFetchMs) < _ttlMs;

    if (!force && fresh) return getCached();

    final res = await UserHttp.getJson('categories');

    if (res['ok'] == true && res['data'] is List) {
      final list = (res['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      list.sort(
        (a, b) => _toInt(a['category_id']).compareTo(_toInt(b['category_id'])),
      );

      _cache = list;
      _lastFetchMs = now;
      return getCached();
    }

    if (_cache.isNotEmpty) return getCached();

    if (kDebugMode) {
      debugPrint('[CategoryRepository] list error: ${res['message']}');
    }
    return [];
  }

  static Future<Map<String, dynamic>> create({
    required String categoryName,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'category_name': categoryName.trim(),
      'description': (description ?? '').trim(),
    };

    final res = await UserHttp.postJson('categories/create', body);

    if (res['ok'] == true) invalidate();
    return res;
  }
}
