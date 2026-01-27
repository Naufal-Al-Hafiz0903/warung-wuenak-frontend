import 'dart:io';
import '/core/config/app_config.dart';
import 'package:flutter/material.dart';
import '/models/product_model.dart';
import '/models/toko_model.dart';
import '/services/category_service.dart';
import '../../data/product_admin_service.dart';
import '/services/admin_http.dart';
import '/core/utils/debouncer.dart';
import '../widgets/admin_add_dialog.dart';
import '../widgets/admin_db_table.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  late Future<List<ProductModel>> _future;

  final TextEditingController _searchC = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 250),
  );

  String _statusFilter = 'semua';
  static const statuses = ['aktif', 'nonaktif'];

  @override
  void initState() {
    super.initState();
    _future = ProductAdminService.fetchProducts();

    _searchC.addListener(() {
      _searchDebouncer.run(() {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _future = ProductAdminService.fetchProducts();
    });

    // optional: biar caller yang await _refresh() nunggu selesai
    await _future;
  }

  int _leadingInt(String s) {
    final m = RegExp(r'^\s*(\d+)').firstMatch(s);
    if (m == null) return 0;
    return int.tryParse(m.group(1) ?? '') ?? 0;
  }

  Future<List<String>> _fetchTokoDropdownOptions() async {
    final res = await AdminHttp.getJson('toko/list?status=aktif');

    if (res['ok'] == true && res['data'] is List) {
      final raw = res['data'] as List;

      final tokos =
          raw
              .whereType<Map>()
              .map((e) => TokoModel.fromJson(Map<String, dynamic>.from(e)))
              .where((t) => t.tokoId > 0)
              .toList()
            ..sort((a, b) => a.tokoId.compareTo(b.tokoId));

      return tokos.map((t) {
        final name = t.namaToko.trim().isNotEmpty
            ? t.namaToko.trim()
            : 'Toko ${t.tokoId}';
        final st = t.status.trim().isNotEmpty
            ? t.status.trim().toLowerCase()
            : 'nonaktif';
        return '${t.tokoId} - $name ($st)';
      }).toList();
    }

    return [];
  }

  Future<List<String>> _fetchCategoryDropdownOptions() async {
    // admin fetch + forceRefresh supaya tidak nyangkut kosong
    var cats = await CategoryService.fetchCategoriesAdmin(forceRefresh: true);
    if (cats.isEmpty) {
      cats = await CategoryService.fetchCategories(forceRefresh: true);
    }

    final clean = cats.where((c) => c.categoryId > 0).toList()
      ..sort((a, b) => a.categoryId.compareTo(b.categoryId));

    return clean.map((c) {
      final name = c.categoryName.trim().isNotEmpty
          ? c.categoryName.trim()
          : 'Kategori ${c.categoryId}';
      return '${c.categoryId} - $name';
    }).toList();
  }

  Future<({List<String> tokoOptions, List<String> categoryOptions})>
  _loadAddOptionsWithLoading() async {
    if (!mounted) return (tokoOptions: <String>[], categoryOptions: <String>[]);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<String> tokoOpts = [];
    List<String> catOpts = [];

    try {
      final results = await Future.wait([
        _fetchTokoDropdownOptions(),
        _fetchCategoryDropdownOptions(),
      ]);
      tokoOpts = results[0];
      catOpts = results[1];
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    return (tokoOptions: tokoOpts, categoryOptions: catOpts);
  }

  List<ProductModel> _applyFilter(List<ProductModel> items) {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<ProductModel> list = items;

    if (_statusFilter != 'semua') {
      list = list.where((p) => p.status.toLowerCase() == _statusFilter);
    }

    if (q.isNotEmpty) {
      list = list.where((p) {
        return p.productId.toString().contains(q) ||
            p.namaProduk.toLowerCase().contains(q);
      });
    }

    return list.toList();
  }

  void _openStatusMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Semua'),
                trailing: _statusFilter == 'semua'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'semua'),
              ),
              ListTile(
                title: const Text('Aktif'),
                trailing: _statusFilter == 'aktif'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'aktif'),
              ),
              ListTile(
                title: const Text('Nonaktif'),
                trailing: _statusFilter == 'nonaktif'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'nonaktif'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) setState(() => _statusFilter = selected);
  }

  Future<void> _openAddDialog() async {
    final opts = await _loadAddOptionsWithLoading();
    if (!mounted) return;

    final tokoOptions = opts.tokoOptions;
    final categoryOptions = opts.categoryOptions;

    if (tokoOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data toko aktif kosong / endpoint belum tersedia.'),
        ),
      );
      return;
    }

    if (categoryOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori kosong. Cek endpoint /categories.'),
        ),
      );
      return;
    }

    final res = await showDialog<AdminDialogResult>(
      context: context,
      builder: (_) => AdminEntityAddDialog(
        schema: AdminDialogSchema(
          title: 'Tambah Produk',
          submitLabel: 'Tambah',
          fields: [
            // ✅ NEW: image picker
            AdminFieldSpec.image(
              'image_file',
              label: 'Gambar Produk',
              required: false,
              hint: 'Tap untuk pilih gambar',
              maxBytes: 2 * 1024 * 1024,
            ),

            AdminFieldSpec.dropdown(
              'toko_id',
              label: 'Toko',
              options: tokoOptions,
              required: true,
              initialValue: tokoOptions.first,
            ),
            AdminFieldSpec.dropdown(
              'category_id',
              label: 'Kategori',
              options: categoryOptions,
              required: true,
              initialValue: categoryOptions.first,
            ),
            AdminFieldSpec.text(
              'nama_produk',
              label: 'Nama Produk',
              required: true,
            ),
            AdminFieldSpec.multiline(
              'deskripsi',
              label: 'Deskripsi',
              required: true,
              maxLines: 3,
            ),
            AdminFieldSpec.doubleField('harga', label: 'Harga', required: true),
            AdminFieldSpec.intField('stok', label: 'Stok', required: true),
            AdminFieldSpec.dropdown(
              'status',
              label: 'Status',
              options: statuses,
              required: true,
              initialValue: 'aktif',
            ),
          ],
          onSubmit: (values, _) async {
            final tokoId = _leadingInt(values['toko_id']?.toString() ?? '');
            final categoryId = _leadingInt(
              values['category_id']?.toString() ?? '',
            );

            if (tokoId <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'toko_id tidak valid',
              );
            }
            if (categoryId <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'category_id tidak valid',
              );
            }

            final nama = values['nama_produk'] as String;
            final desc = values['deskripsi'] as String;
            final harga = values['harga'] as double;
            final stok = values['stok'] as int;
            final status = values['status'] as String;

            final File? img = values['image_file'] as File?;

            final ok = await ProductAdminService.createProductWithImage(
              tokoId: tokoId,
              categoryId: categoryId,
              namaProduk: nama,
              deskripsi: desc,
              harga: harga,
              stok: stok,
              status: status,
              image: img,
            );

            return AdminDialogResult(
              ok: ok,
              message: ok
                  ? (img != null
                        ? 'Produk + gambar berhasil ditambahkan'
                        : 'Produk berhasil ditambahkan')
                  : 'Gagal menambahkan produk',
            );
          },
        ),
      ),
    );

    if (!mounted) return;

    if (res?.ok == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res!.message)));
      _refresh();
    }
  }

  Widget _table(List<ProductModel> list) {
    const double wImg = 86;
    const double wId = 110;
    const double wNama = 260;
    const double wHarga = 140;
    const double wStok = 110;
    const double wStatus = 160;
    const double wAksi = 110;

    String _resolveImgUrl(String? raw) {
      final s = (raw ?? '').trim();
      if (s.isEmpty) return '';
      if (s.startsWith('http://') || s.startsWith('https://')) return s;

      // dukung "uploads/..." atau "/uploads/..."
      if (s.startsWith('/')) return '${AppConfig.baseUrl}$s';
      return '${AppConfig.baseUrl}/$s';
    }

    Widget _thumb(ProductModel p) {
      final url = _resolveImgUrl(p.imageUrl);

      return SizedBox(
        width: 64,
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: const Color(0xFFF2F2F6),
            child: url.isEmpty
                ? const Icon(
                    Icons.image_not_supported_rounded,
                    color: Colors.black26,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.black26,
                    ),
                    loadingBuilder: (ctx, child, prog) {
                      if (prog == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
          ),
        ),
      );
    }

    return AdminDbTable<ProductModel>(
      tableName: 'products',
      columns: const [
        AdminDbColumn(
          title: 'Gambar',
          columnName: 'image_url',
          width: wImg,
          headerAlign: Alignment.center,
          cellAlign: Alignment.center,
        ),
        AdminDbColumn(title: 'Id', columnName: 'product_id', width: wId),
        AdminDbColumn(title: 'Nama', columnName: 'nama_produk', width: wNama),
        AdminDbColumn(
          title: 'Harga',
          columnName: 'harga',
          width: wHarga,
          cellAlign: Alignment.centerLeft,
        ),
        AdminDbColumn(
          title: 'Stok',
          columnName: 'stok',
          width: wStok,
          cellAlign: Alignment.centerLeft,
        ),
        AdminDbColumn(title: 'Status', columnName: 'status', width: wStatus),
        AdminDbColumn(
          title: 'Aksi',
          columnName: 'aksi',
          width: wAksi,
          headerAlign: Alignment.center,
          cellAlign: Alignment.center,
        ),
      ],
      items: list,
      rowsHeight: 360,
      emptyMessage: 'Tidak ada produk yang cocok dengan filter/search.',
      cellsBuilder: (context, p) {
        final statusVal = statuses.contains(p.status.toLowerCase())
            ? p.status.toLowerCase()
            : 'aktif';

        return [
          _thumb(p),

          Text(
            p.productId.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(p.namaProduk, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            p.harga.toStringAsFixed(0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(p.stok.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),

          SizedBox(
            height: 40,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: statusVal,
                isExpanded: true,
                items: statuses
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;

                  bool ok = await ProductAdminService.updateStatus(
                    productId: p.productId,
                    status: v,
                  );

                  if (!ok) {
                    ok = await ProductAdminService.updateProduct(
                      productId: p.productId,
                      namaProduk: p.namaProduk,
                      deskripsi: p.deskripsi ?? '',
                      harga: p.harga,
                      stok: p.stok,
                      status: v,
                      categoryId: p.categoryId,
                    );
                  }

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Status produk diubah' : 'Gagal ubah status',
                      ),
                    ),
                  );

                  if (ok) _refresh();
                },
              ),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await ProductAdminService.deleteProduct(p.productId);
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Produk dihapus' : 'Gagal hapus produk'),
                ),
              );

              if (ok) _refresh();
            },
          ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final items = snap.data ?? [];
        final filtered = _applyFilter(items);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchC,
                        decoration: InputDecoration(
                          hintText: "Search",
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _openAddDialog,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _openStatusMenu(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_statusFilter == 'semua')
                            ? Colors.redAccent
                            : Colors.red,
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Filter: ${_statusFilter.toUpperCase()} • Data: ${filtered.length}",
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              _table(filtered),
            ],
          ),
        );
      },
    );
  }
}
