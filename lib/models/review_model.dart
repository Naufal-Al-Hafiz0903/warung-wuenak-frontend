class ReviewModel {
  final int reviewId;
  final int productId;
  final int userId;

  final int rating;
  final String? komentar;
  final String? createdAt;

  // optional join
  final String? userName;

  ReviewModel({
    required this.reviewId,
    required this.productId,
    required this.userId,
    required this.rating,
    required this.komentar,
    required this.createdAt,
    required this.userName,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static String? _pick(dynamic a, dynamic b) {
    final v = a ?? b;
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory ReviewModel.fromJson(Map<String, dynamic> j) {
    return ReviewModel(
      reviewId: _toInt(j['review_id'] ?? j['reviewId'] ?? j['id']),
      productId: _toInt(j['product_id'] ?? j['productId']),
      userId: _toInt(j['user_id'] ?? j['userId']),
      rating: _toInt(j['rating']),
      komentar: _pick(j['komentar'], j['comment']),
      createdAt: _pick(j['created_at'], j['createdAt']),
      userName: _pick(j['user_name'], j['userName']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'review_id': reviewId,
      'product_id': productId,
      'user_id': userId,
      'rating': rating,
      'komentar': komentar,
      'created_at': createdAt,
      'user_name': userName,
    };
  }
}
