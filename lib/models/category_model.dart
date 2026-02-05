class CategoryModel {
  final int categoryId;
  final String categoryName;
  final String? description;

  CategoryModel({
    required this.categoryId,
    required this.categoryName,
    required this.description,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> j) {
    int parseInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    return CategoryModel(
      categoryId: parseInt(j['category_id'] ?? j['id']),
      categoryName: (j['category_name'] ?? j['name'] ?? '').toString(),
      description: j['description']?.toString(),
    );
  }
}
