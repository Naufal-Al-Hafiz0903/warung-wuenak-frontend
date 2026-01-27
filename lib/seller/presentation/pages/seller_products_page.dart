// lib/seller/presentation/pages/seller_products_page.dart
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/debouncer.dart';
import '../../../models/product_model.dart';
import '../../data/product_service.dart';
import '../layout/seller_layout.dart';
import 'seller_product_add_page.dart';
import 'seller_product_form.dart';
import 'seller_product_images.dart';

class SellerProductsPage extends StatefulWidget {
  const SellerProductsPage({super.key});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  late Future<List<ProductModel>> _future;

  final _searchC = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 450));

  String _q = '';
  String _status = 'all'; // all|aktif|nonaktif

  bool get _filterActive => _status != 'all';

  @override
  void initState() {
    super.initState();
    _future = ProductService.fetchSellerProducts(q: '', status: 'all');
  }

  @override
  void dispose() {
    _searchC.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  String? _resolveImg(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    final base = AppConfig.baseUrl; // contoh: http://10.0.2.2:8081
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }

  Future<void> _reload() async {
    setState(() {
      _future = ProductService.fetchSellerProducts(q: _q, status: _status);
    });
  }

  void _onSearchChanged(String v) {
    _q = v;

    _debouncer.run(() {
      if (!mounted) return;
      setState(() {
        _future = ProductService.fetchSellerProducts(q: _q, status: _status);
      });
    });
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SellerProductAddPage()),
    );
    if (changed == true) _reload();
  }

  Future<void> _openEdit(ProductModel initial) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProductFormPage(initial: initial),
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _openImages(ProductModel p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProductImagesPage(
          productId: p.productId,
          productName: p.namaProduk,
        ),
      ),
    );
    // setelah balik, reload biar gambar utama/list ke-update jika ada perubahan
    _reload();
  }

  Future<void> _openFilterSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Filter Status',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              RadioListTile<String>(
                value: 'all',
                groupValue: _status,
                title: const Text('Semua'),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
              RadioListTile<String>(
                value: 'aktif',
                groupValue: _status,
                title: const Text('Aktif'),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
              RadioListTile<String>(
                value: 'nonaktif',
                groupValue: _status,
                title: const Text('Nonaktif'),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _status = picked;
      _future = ProductService.fetchSellerProducts(q: _q, status: _status);
    });
  }

  Future<void> _delete(ProductModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Yakin hapus "${p.namaProduk}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final success = await ProductService.deleteProduct(p.productId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Produk dihapus' : 'Gagal hapus produk'),
      ),
    );

    if (success) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget actionButton({
      required IconData icon,
      required VoidCallback onTap,
      required String tooltip,
      bool active = false,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: active
              ? cs.primary.withOpacity(.14)
              : Colors.white.withOpacity(.78),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: active ? cs.primary : Colors.black87),
            ),
          ),
        ),
      );
    }

    return SellerLayout(
      title: "Produk",
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      hintText: 'Cari produk / kategori...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(.78),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 10),
                actionButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Tambah Produk',
                  onTap: _openAdd,
                ),
                const SizedBox(width: 10),
                actionButton(
                  icon: _filterActive
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
                  tooltip: _filterActive ? 'Filter aktif' : 'Filter nonaktif',
                  active: _filterActive,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ProductModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? <ProductModel>[];

                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(child: Text('Belum ada produk.')),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = items[i];
                      final img = _resolveImg(p.imageUrl);

                      return Card(
                        elevation: 1.2,
                        child: ListTile(
                          // ✅ FIX: tampilkan gambar utama
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 54,
                              height: 54,
                              color: Colors.black12,
                              child: img == null
                                  ? const Icon(Icons.image_rounded)
                                  : Image.network(
                                      img,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_rounded,
                                      ),
                                    ),
                            ),
                          ),

                          title: Text(
                            p.namaProduk,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rp ${p.harga.toStringAsFixed(0)} • Stok: ${p.stok}',
                                ),
                                if ((p.categoryName ?? '').trim().isNotEmpty)
                                  Text('Kategori: ${p.categoryName}'),
                                Text('Status: ${p.status}'),
                              ],
                            ),
                          ),

                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _openEdit(p);
                              if (v == 'images') _openImages(p);
                              if (v == 'delete') _delete(p);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'images',
                                child: Text('Foto Produk'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus'),
                              ),
                            ],
                          ),

                          onTap: () => _openEdit(p),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
