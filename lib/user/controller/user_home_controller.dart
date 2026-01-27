import 'package:flutter/foundation.dart';

import '../../core/utils/debouncer.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../data/user_home_repository.dart';

class UserHomeController extends ChangeNotifier {
  final UserHomeRepository repo;
  UserHomeController({required this.repo});

  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: 350),
  );

  bool loading = true;
  String? error;

  List<ProductModel> products = [];
  List<CategoryModel> categories = [];

  int? selectedCategoryId;
  String query = '';

  // header
  String name = '-';
  String email = '-';
  double saldo = 0.0; // ✅ FIX: harus double

  void setUser(Map<String, dynamic> user) {
    name = (user['name'] ?? '-').toString();
    email = (user['email'] ?? '-').toString();

    final raw = user['saldo'] ?? user['saldo_user'] ?? 0;
    if (raw is num) {
      saldo = raw.toDouble();
    } else {
      saldo = double.tryParse(raw.toString()) ?? 0.0;
    }
  }

  Future<void> init() async => _loadAll();
  Future<void> refresh() async => _loadProducts();

  Future<void> _loadAll() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repo.fetchCategories(),
        repo.fetchProducts(query: query, categoryId: selectedCategoryId),
      ]);

      categories = results[0] as List<CategoryModel>;
      products = results[1] as List<ProductModel>;
    } catch (e) {
      error = 'Gagal memuat data: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      products = await repo.fetchProducts(
        query: query,
        categoryId: selectedCategoryId,
      );
    } catch (e) {
      error = 'Gagal memuat produk: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void onQueryChanged(String v) {
    query = v.trim();
    _debouncer.run(() async {
      await _loadProducts();
    });
  }

  /// id <= 0 dianggap "Semua"
  void onSelectCategory(int id) {
    if (id <= 0) {
      selectedCategoryId = null;
    } else if (selectedCategoryId == id) {
      selectedCategoryId = null;
    } else {
      selectedCategoryId = id;
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}
