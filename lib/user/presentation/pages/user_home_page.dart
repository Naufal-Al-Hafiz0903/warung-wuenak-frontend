import 'package:flutter/material.dart';

import '../../controller/user_home_controller.dart';
import '../../data/user_home_repository.dart';

import '../widgets/product_card.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/user_profile_header.dart';
import '../widgets/empty_state.dart';

import 'user_cart_page.dart';
import 'user_product_detail_page.dart';

import '../../../features/data/auth_service.dart';

class UserHomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserHomePage({super.key, required this.user});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  late final UserHomeController c;

  @override
  void initState() {
    super.initState();
    c = UserHomeController(repo: UserHomeRepository());
    c.setUser(widget.user);
    c.init();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _goCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserCartPage(user: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Warung Wuenak"),
            actions: [
              IconButton(
                tooltip: "Keranjang",
                icon: const Icon(Icons.shopping_cart_rounded),
                onPressed: _goCart,
              ),
              IconButton(
                tooltip: "Logout",
                icon: const Icon(Icons.logout_rounded),
                onPressed: _logout,
              ),
            ],
          ),
          body: c.loading
              ? const Center(child: CircularProgressIndicator())
              : c.error != null
              ? _ErrorState(message: c.error!, onRetry: c.init)
              : RefreshIndicator(
                  onRefresh: c.refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      UserProfileHeader(
                        name: c.name,
                        email: c.email,
                        saldo: c.saldo,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: "Cari produk / kategori...",
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: c.onQueryChanged,
                      ),
                      const SizedBox(height: 12),
                      CategoryFilterChips(
                        categories: c.categories,
                        // ✅ FIX terkait tugas UI filter
                        selectedId: c.selectedCategoryId ?? 0,
                        onSelected: (id) => c.onSelectCategory(id),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Produk ditemukan: ${c.products.length}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (c.products.isEmpty)
                        const EmptyState()
                      else
                        ...c.products.map(
                          (p) => ProductCard(
                            p: p,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProductDetailPage(
                                    user: widget.user,
                                    productId: p.productId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Coba lagi"),
            ),
          ],
        ),
      ),
    );
  }
}
