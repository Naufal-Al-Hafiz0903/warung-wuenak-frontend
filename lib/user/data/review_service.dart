import '../../models/review_model.dart';
import '../../services/user_http.dart';

class ReviewService {
  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['reviews'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    // kadang: {data: {data: []}}
    final d = res['data'];
    if (d is Map && d['data'] is List) return d['data'] as List;
    return [];
  }

  static Map<String, dynamic>? _extractMap(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    // kadang: {data: {data: {...}}}
    if (d is Map && d['data'] is Map)
      return Map<String, dynamic>.from(d['data']);
    return null;
  }

  /// GET review list by product (support 2 bentuk endpoint)
  static Future<List<ReviewModel>> fetchByProduct(int productId) async {
    Map<String, dynamic> res = await UserHttp.getJson(
      'reviews/product?product_id=$productId',
    );

    if (res['ok'] != true) {
      // fallback: /reviews/product/{id}
      res = await UserHttp.getJson('reviews/product/$productId');
    }

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// GET my review for product
  static Future<Map<String, dynamic>?> fetchMyRaw(int productId) async {
    Map<String, dynamic> res = await UserHttp.getJson(
      'reviews/my?product_id=$productId',
    );

    if (res['ok'] != true) {
      // fallback: /reviews/my/{id} (kalau backend kamu pakai ini)
      res = await UserHttp.getJson('reviews/my/$productId');
    }

    if (res['ok'] == true) {
      return _extractMap(res);
    }
    return null;
  }

  /// Upsert review (coba JSON dulu, fallback form)
  static Future<Map<String, dynamic>> upsert({
    required int productId,
    required int rating,
    required String komentar,
  }) async {
    // 1) JSON
    var res = await UserHttp.postJson('reviews/create', {
      'product_id': productId,
      'rating': rating,
      'komentar': komentar,
    });

    if (res['ok'] == true) return res;

    // 2) fallback: form
    res = await UserHttp.postForm('reviews/create', {
      'product_id': productId.toString(),
      'rating': rating.toString(),
      'komentar': komentar,
    });

    return res;
  }

  static Future<bool> create({
    required int productId,
    required int rating,
    required String komentar,
  }) async {
    final res = await upsert(
      productId: productId,
      rating: rating,
      komentar: komentar,
    );
    return res['ok'] == true;
  }
}
