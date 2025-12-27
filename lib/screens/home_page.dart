import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final String role;
  late final String name;
  late final String email;

  bool loading = true;
  String q = '';
  int? selectedCategoryId;

  List<CategoryModel> categories = [];
  List<ProductModel> products = [];

  @override
  void initState() {
    super.initState();
    role = widget.user["level"] ?? "user";
    name = widget.user["name"] ?? "-";
    email = widget.user["email"] ?? "-";

    // dashboard user: load data
    _load();
  }

  Future<void> _load() async {
    if (role != 'user') return;

    setState(() => loading = true);

    final c = await CategoryService.fetchCategories(); // categories/list.php
    final p = await ProductService.fetchProducts(); // products/list.php (auth)

    setState(() {
      categories = c;
      products = p;
      loading = false;
    });
  }

  List<ProductModel> get _filteredProducts {
    Iterable<ProductModel> list = products;

    // hanya produk aktif
    list = list.where((p) => (p.status.toLowerCase() == 'aktif'));

    // filter kategori
    if (selectedCategoryId != null && selectedCategoryId != 0) {
      list = list.where((p) => p.categoryId == selectedCategoryId);
    }

    // search
    final s = q.trim().toLowerCase();
    if (s.isNotEmpty) {
      list = list.where((p) {
        final n = p.namaProduk.toLowerCase();
        final c = (p.categoryName ?? '').toLowerCase();
        return n.contains(s) || c.contains(s);
      });
    }

    return list.toList();
  }

  String _money(double v) {
    // simpel dulu (tanpa package intl)
    final s = v.toStringAsFixed(0);
    return "Rp $s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'user' ? "Warung Wuenak" : "Dashboard"),
        backgroundColor: _roleColor(role),
        actions: [
          if (role == 'user')
            IconButton(
              tooltip: "Pesanan Saya",
              icon: const Icon(Icons.receipt_long),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserOrdersPage()),
                );
              },
            ),
        ],
      ),
      body: role == 'user' ? _userDashboard() : _roleWidget(role),
    );
  }

  // ===============================
  // DASHBOARD USER (BARU)
  // ===============================
  Widget _userDashboard() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = _filteredProducts;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Halo, $name",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),

          // SEARCH
          TextField(
            decoration: InputDecoration(
              hintText: "Cari produk / kategori...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => q = v),
          ),
          const SizedBox(height: 12),

          // FILTER KATEGORI
          Row(
            children: [
              const Text("Kategori: "),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedCategoryId ?? 0,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int>(value: 0, child: Text("Semua")),
                    ...categories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.categoryId,
                        child: Text(c.categoryName),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() {
                    selectedCategoryId = (v == 0) ? null : v;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // INFO JUMLAH
          Text(
            "Produk ditemukan: ${list.length}",
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),

          // LIST PRODUK
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text("Tidak ada produk.")),
            )
          else
            ...list.map(_productCard).toList(),
        ],
      ),
    );
  }

  Widget _productCard(ProductModel p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // thumbnail sederhana (placeholder)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_bag),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.namaProduk,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.categoryName ?? "Kategori #${p.categoryId}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(_money(p.harga), style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 6),
                  Text("Stok: ${p.stok}"),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: p.stok <= 0
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Template: ${p.namaProduk} ditambahkan (fitur cart belum dibuat)",
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text("Tambah"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================
  // WIDGET BERDASARKAN ROLE (TETAP ADA)
  // ===============================
  Widget _roleWidget(String role) {
    switch (role) {
      case "admin":
        return _adminView();
      case "penjual":
        return _penjualView();
      default:
        return _userView(); // tidak dipakai lagi kalau role user karena sudah dashboard
    }
  }

  Widget _adminView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: Colors.red.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "🔴 LOGIN SEBAGAI ADMIN\n\n"
            "• Kelola semua user\n"
            "• Kelola toko\n"
            "• Kelola produk\n"
            "• Monitoring transaksi",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _penjualView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "🟠 LOGIN SEBAGAI PENJUAL\n\n"
            "• Kelola produk sendiri\n"
            "• Lihat pesanan\n"
            "• Proses pengiriman",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _userView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: Colors.green.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "🟢 LOGIN SEBAGAI USER\n\n"
            "• Lihat produk\n"
            "• Belanja\n"
            "• Lihat status pesanan",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case "admin":
        return Colors.red;
      case "penjual":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}

// =====================================================
// HALAMAN PESANAN SAYA (TEMPLATE, cepat jalan)
// =====================================================
class UserOrdersPage extends StatefulWidget {
  const UserOrdersPage({super.key});

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  bool loading = true;
  List<OrderModel> orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await OrderService.fetchMyOrders();
    setState(() {
      orders = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pesanan Saya")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, i) {
                  final o = orders[i];
                  return Card(
                    child: ListTile(
                      title: Text("Order #${o.orderId}"),
                      subtitle: Text(
                        "Status: ${o.status} • Metode: ${o.metodePembayaran}",
                      ),
                      trailing: Text("Rp ${o.totalAmount.toStringAsFixed(0)}"),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
