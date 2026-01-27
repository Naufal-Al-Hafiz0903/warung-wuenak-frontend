import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';

class UserHomeRepository {
  Future<List<CategoryModel>> fetchCategories() async {
    return CategoryService.fetchCategories();
  }

  Future<List<ProductModel>> fetchProducts({
    String? query,
    int? categoryId,
  }) async {
    return ProductService.fetchProducts(query: query, categoryId: categoryId);
  }
}
