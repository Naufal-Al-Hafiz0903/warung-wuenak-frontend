import '../../models/review_model.dart';
import '../../services/user_http.dart';

class ReviewService {
  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['reviews'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<ReviewModel>> fetchByProduct(int productId) async {
    final res = await UserHttp.getJson('reviews/product?product_id=$productId');
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<bool> create({
    required int productId,
    required int rating,
    required String komentar,
  }) async {
    final res = await UserHttp.postForm('reviews/create', {
      'product_id': productId.toString(),
      'rating': rating.toString(),
      'komentar': komentar,
    });
    return res['ok'] == true;
  }
}
