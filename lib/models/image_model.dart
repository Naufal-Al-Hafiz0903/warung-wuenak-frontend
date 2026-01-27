class ImageModel {
  final int imageId;
  final int productId;
  final String url;
  final String? label;
  final String? createdAt;

  ImageModel({
    required this.imageId,
    required this.productId,
    required this.url,
    required this.label,
    required this.createdAt,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static String _toStr(dynamic v, String def) {
    final s = (v ?? def).toString().trim();
    return s.isEmpty ? def : s;
  }

  static String? _pick(dynamic a, dynamic b) {
    final v = a ?? b;
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory ImageModel.fromJson(Map<String, dynamic> j) {
    return ImageModel(
      imageId: _toInt(j['image_id'] ?? j['id']),
      productId: _toInt(j['product_id'] ?? j['productId']),
      url: _toStr(j['image_url'] ?? j['url'] ?? j['path'], ''),
      label: _pick(j['label'], j['type']),
      createdAt: _pick(j['created_at'], j['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image_id': imageId,
      'product_id': productId,
      'image_url': url,
      'label': label,
      'created_at': createdAt,
    };
  }
}
