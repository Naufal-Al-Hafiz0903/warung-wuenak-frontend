import 'package:flutter/foundation.dart';

import '../../core/utils/debouncer.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../data/user_home_repository.dart';

// ✅ TUGAS: sebelum ambil produk, pastikan lokasi user sudah terkirim ke backend
import '../../services/me_location_service.dart';

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
  double saldo = 0.0;

  // ==========================================================
  // ✅ TUGAS: throttle kirim lokasi agar tidak dipanggil tiap search
  // - lokasi akan dikirim saat init
  // - lalu maksimal 1x per 2 menit saat user mengetik / refresh
  // ==========================================================
  DateTime? _lastLocationSentAt;
  static const Duration _locationRefreshInterval = Duration(minutes: 2);

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

  // ==========================================================
  // ✅ TUGAS: memastikan lokasi sudah tersimpan di user_locations
  // Supaya backend bisa memfilter produk <= 1.2 km
  // ==========================================================
  Future<void> _ensureUserLocationUpToDate() async {
    final now = DateTime.now();

    // kalau masih baru (<= 2 menit), tidak perlu kirim lagi
    if (_lastLocationSentAt != null) {
      final age = now.difference(_lastLocationSentAt!);
      if (age < _locationRefreshInterval) return;
    }

    final res = await MeLocationService.captureAndSend();
    if (res.ok != true) {
      // kalau gagal kirim lokasi, lempar error agar UI menampilkan pesan
      throw Exception(res.message);
    }

    _lastLocationSentAt = now;
  }

  Future<void> _loadAll() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      // ✅ TUGAS: pastikan lokasi user dikirim dulu sebelum fetch produk
      await _ensureUserLocationUpToDate();

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
      // ✅ TUGAS: pastikan lokasi user ada / cukup baru
      await _ensureUserLocationUpToDate();

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
