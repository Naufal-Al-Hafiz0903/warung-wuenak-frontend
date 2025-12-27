class CategoryModel {
  final int categoryId;
  final int? parentId;
  final String categoryName;
  final String? description;

  CategoryModel({
    required this.categoryId,
    required this.parentId,
    required this.categoryName,
    required this.description,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> j) {
    int parseInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    int? parseIntNullable(dynamic v) {
      if (v == null) return null;
      final n = int.tryParse(v.toString());
      return n;
    }

    return CategoryModel(
      categoryId: parseInt(j['category_id'] ?? j['id']),
      parentId: parseIntNullable(j['parent_id']),
      categoryName: (j['category_name'] ?? j['name'] ?? '').toString(),
      description: j['description']?.toString(),
    );
  }
}
