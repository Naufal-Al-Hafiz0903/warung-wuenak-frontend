import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/product_admin_service.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  late Future<List<ProductModel>> _future;

  static const statuses = ['aktif', 'nonaktif'];

  @override
  void initState() {
    super.initState();
    _future = ProductAdminService.fetchProducts();
  }

  Future<void> _refresh() async {
    setState(() => _future = ProductAdminService.fetchProducts());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final items = snap.data!;
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: const [
                SizedBox(height: 140),
                Center(child: Text('Produk kosong / endpoint belum sesuai')),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Nama')),
                      DataColumn(label: Text('Harga')),
                      DataColumn(label: Text('Stok')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Toko')),
                      DataColumn(label: Text('Kategori')),
                      DataColumn(label: Text('Aksi')),
                    ],
                    rows: items.map((p) {
                      final statusVal = statuses.contains(p.status)
                          ? p.status
                          : 'aktif';

                      return DataRow(
                        cells: [
                          DataCell(Text(p.productId.toString())),
                          DataCell(Text(p.namaProduk)),
                          DataCell(Text(p.harga.toString())),
                          DataCell(Text(p.stok.toString())),
                          DataCell(
                            DropdownButton<String>(
                              value: statusVal,
                              items: statuses
                                  .map(
                                    (x) => DropdownMenuItem(
                                      value: x,
                                      child: Text(x),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null) return;
                                final ok =
                                    await ProductAdminService.updateProduct(
                                      productId: p.productId,
                                      namaProduk: p.namaProduk,
                                      deskripsi: p.deskripsi ?? '',
                                      harga: p.harga,
                                      stok: p.stok,
                                      status: v,
                                      categoryId: p.categoryId,
                                    );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Status produk diubah'
                                          : 'Gagal ubah status',
                                    ),
                                  ),
                                );
                                if (ok) _refresh();
                              },
                            ),
                          ),
                          DataCell(Text(p.tokoId.toString())),
                          DataCell(Text(p.categoryId.toString())),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final ok =
                                    await ProductAdminService.deleteProduct(
                                      p.productId,
                                    );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Produk dihapus'
                                          : 'Gagal hapus produk',
                                    ),
                                  ),
                                );
                                if (ok) _refresh();
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
