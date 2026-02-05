import 'dart:io';

import 'package:flutter/material.dart';

import '/core/config/app_config.dart';
import '/models/category_model.dart';
import '/models/product_model.dart';
import '/services/category_service.dart';

import '../../data/product_admin_service.dart';
import '../widgets/admin_add_dialog.dart';
import '../widgets/admin_db_table.dart';
import '../widgets/admin_ui.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  late Future<List<ProductModel>> _future;

  final TextEditingController _searchC = TextEditingController();

  /// filter status produk: semua|aktif|nonaktif
  String _statusFilter = 'semua';

  /// supaya dropdown status tidak bisa diubah berulang saat request sedang jalan
  final Set<int> _busyStatus = <int>{};

  static const List<String> _statusOptions = ['aktif', 'nonaktif'];

  @override
  void initState() {
    super.initState();
    _future = ProductAdminService.fetchProducts();
    _searchC.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = ProductAdminService.fetchProducts());
  }

  String _norm(String s) => s.trim().toLowerCase();

  String _fullImageUrl(String? u) {
    if (u == null) return '';
    final s = u.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '${AppConfig.baseUrl}$s';
    return '${AppConfig.baseUrl}/$s';
  }

  List<ProductModel> _applyFilter(List<ProductModel> items) {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<ProductModel> list = items;

    // filter status
    if (_statusFilter != 'semua') {
      list = list.where((p) => _norm(p.status) == _statusFilter);
    }

    // search
    if (q.isNotEmpty) {
      list = list.where((p) {
        final id = p.productId.toString();
        final toko = p.tokoId.toString();
        final cat = p.categoryId.toString();
        final name = p.namaProduk.toLowerCase();
        final catName = (p.categoryName ?? '').toLowerCase();
        final st = (p.status).toLowerCase();
        return id.contains(q) ||
            toko.contains(q) ||
            cat.contains(q) ||
            name.contains(q) ||
            catName.contains(q) ||
            st.contains(q);
      });
    }

    return list.toList();
  }

  Future<void> _openStatusMenu(BuildContext context) async {
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

  Future<void> _changeStatus(ProductModel p, String next) async {
    final pid = p.productId;
    if (pid <= 0) return;

    if (_busyStatus.contains(pid)) return;

    final cur = _norm(p.status);
    if (cur == _norm(next)) return;

    setState(() => _busyStatus.add(pid));

    final ok = await ProductAdminService.updateStatus(
      productId: pid,
      status: next,
    );

    if (!mounted) return;
    setState(() => _busyStatus.remove(pid));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Status produk diubah' : 'Gagal ubah status produk'),
      ),
    );

    if (ok) _refresh();
  }

  // =========================================================
  // ✅ ADMIN ADD DIALOG HELPERS (category)
  // =========================================================
  String _catLabel(CategoryModel c) {
    final name = c.categoryName.trim().isEmpty
        ? '(Tanpa Nama)'
        : c.categoryName.trim();
    return '${c.categoryId} - $name';
  }

  int? _parseCategoryId(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final firstNum = s
        .split(RegExp(r'[^0-9]'))
        .firstWhere((x) => x.trim().isNotEmpty, orElse: () => '');
    return int.tryParse(firstNum);
  }

  // =========================================================
  // ✅ CREATE PRODUCT (pakai AdminEntityAddDialog)
  // =========================================================
  Future<void> _openCreateDialog() async {
    List<CategoryModel> cats = [];
    try {
      cats = await CategoryService.fetchCategoriesAdmin(forceRefresh: false);
    } catch (_) {}

    if (!mounted) return;

    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kategori kosong. Buat kategori dulu sebelum membuat produk.',
          ),
        ),
      );
      return;
    }

    final catOptions = cats.map(_catLabel).toList();
    final initialCat = catOptions.first;

    final res = await showDialog<AdminDialogResult>(
      context: context,
      builder: (_) => AdminEntityAddDialog(
        schema: AdminDialogSchema(
          title: 'Tambah Produk',
          submitLabel: 'Tambah',
          fields: [
            // ADMIN wajib toko_id (sesuai backend createProducts)
            AdminFieldSpec.intField(
              'toko_id',
              label: 'toko_id (wajib untuk admin)',
              required: true,
            ),

            // ✅ wajib category (frontend) + backend juga validasi
            AdminFieldSpec.dropdown(
              'category',
              label: 'Kategori (wajib)',
              options: catOptions,
              required: true,
              initialValue: initialCat,
            ),

            AdminFieldSpec.text(
              'nama_produk',
              label: 'nama_produk',
              required: true,
            ),

            AdminFieldSpec.multiline(
              'deskripsi',
              label: 'deskripsi (opsional)',
              required: false,
              maxLines: 3,
            ),

            AdminFieldSpec.doubleField('harga', label: 'harga', required: true),

            AdminFieldSpec.intField(
              'stok',
              label: 'stok',
              required: true,
              initialValue: '0',
            ),

            AdminFieldSpec.dropdown(
              'status',
              label: 'status',
              options: _statusOptions,
              required: true,
              initialValue: 'aktif',
            ),

            // gambar optional
            AdminFieldSpec.image(
              'image',
              label: 'Gambar Produk (opsional)',
              required: false,
            ),
          ],
          onSubmit: (values, _) async {
            final tokoId = (values['toko_id'] is int)
                ? values['toko_id'] as int
                : int.tryParse('${values['toko_id'] ?? ''}') ?? 0;

            final catRaw = (values['category'] ?? '').toString();
            final categoryId = _parseCategoryId(catRaw) ?? 0;

            final nama = (values['nama_produk'] ?? '').toString().trim();
            final deskripsi = (values['deskripsi'] ?? '').toString().trim();

            final harga = (values['harga'] is double)
                ? values['harga'] as double
                : double.tryParse('${values['harga'] ?? ''}') ?? 0;

            final stok = (values['stok'] is int)
                ? values['stok'] as int
                : int.tryParse('${values['stok'] ?? ''}') ?? -1;

            final status = (values['status'] ?? 'aktif')
                .toString()
                .toLowerCase();

            final File? image = values['image'] as File?;

            // guard minimal (backend tetap jadi sumber aturan utama)
            if (tokoId <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'toko_id wajib diisi',
              );
            }
            if (categoryId <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'Kategori wajib dipilih',
              );
            }
            if (nama.isEmpty) {
              return const AdminDialogResult(
                ok: false,
                message: 'nama_produk wajib diisi',
              );
            }
            if (harga <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'harga tidak valid',
              );
            }
            if (stok < 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'stok tidak valid',
              );
            }

            // ✅ ambil message dari backend
            final apiRes =
                await ProductAdminService.createProductWithImageResult(
                  tokoId: tokoId,
                  categoryId: categoryId,
                  namaProduk: nama,
                  deskripsi: deskripsi,
                  harga: harga,
                  stok: stok,
                  status: status,
                  image: image,
                );

            final ok = apiRes['ok'] == true;
            final msg =
                (apiRes['message'] ??
                        (ok
                            ? 'Produk berhasil dibuat'
                            : 'Gagal membuat produk'))
                    .toString();

            return AdminDialogResult(ok: ok, message: msg);
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

  // =========================================================
  // ✅ EDIT PRODUCT (pakai AdminEntityAddDialog)
  // =========================================================
  Future<void> _openEditDialog(ProductModel p) async {
    List<CategoryModel> cats = [];
    try {
      cats = await CategoryService.fetchCategoriesAdmin(forceRefresh: false);
    } catch (_) {}

    // category input:
    // - jika kategori berhasil diambil -> dropdown
    // - jika gagal/kosong -> fallback intField category_id
    final catOptions = cats.map(_catLabel).toList();

    String? initialCatLabel;
    if (catOptions.isNotEmpty) {
      initialCatLabel = catOptions.firstWhere(
        (x) => _parseCategoryId(x) == p.categoryId,
        orElse: () => catOptions.first,
      );
    }

    final initialStatus = _statusOptions.contains(_norm(p.status))
        ? _norm(p.status)
        : 'aktif';

    if (!mounted) return;

    final res = await showDialog<AdminDialogResult>(
      context: context,
      builder: (_) => AdminEntityAddDialog(
        schema: AdminDialogSchema(
          title: 'Edit Produk • ID ${p.productId}',
          submitLabel: 'Simpan',
          fields: [
            if (catOptions.isNotEmpty)
              AdminFieldSpec.dropdown(
                'category',
                label: 'Kategori (wajib)',
                options: catOptions,
                required: true,
                initialValue: initialCatLabel,
              )
            else
              AdminFieldSpec.intField(
                'category_id',
                label: 'category_id (wajib)',
                required: true,
                initialValue: '${p.categoryId}',
              ),

            AdminFieldSpec.text(
              'nama_produk',
              label: 'nama_produk',
              required: true,
              initialValue: p.namaProduk,
            ),

            AdminFieldSpec.multiline(
              'deskripsi',
              label: 'deskripsi (opsional)',
              required: false,
              maxLines: 3,
              initialValue: (p.deskripsi ?? ''),
            ),

            AdminFieldSpec.doubleField(
              'harga',
              label: 'harga',
              required: true,
              initialValue: p.harga.toStringAsFixed(0),
            ),

            AdminFieldSpec.intField(
              'stok',
              label: 'stok',
              required: true,
              initialValue: '${p.stok}',
            ),

            AdminFieldSpec.dropdown(
              'status',
              label: 'status',
              options: _statusOptions,
              required: true,
              initialValue: initialStatus,
            ),

            AdminFieldSpec.image(
              'image',
              label: 'Gambar Baru (opsional)',
              required: false,
            ),
          ],
          onSubmit: (values, _) async {
            int categoryId = 0;
            if (catOptions.isNotEmpty) {
              categoryId = _parseCategoryId('${values['category'] ?? ''}') ?? 0;
            } else {
              categoryId = (values['category_id'] is int)
                  ? values['category_id'] as int
                  : int.tryParse('${values['category_id'] ?? ''}') ?? 0;
            }

            final nama = (values['nama_produk'] ?? '').toString().trim();
            final deskripsi = (values['deskripsi'] ?? '').toString().trim();

            final harga = (values['harga'] is double)
                ? values['harga'] as double
                : double.tryParse('${values['harga'] ?? ''}') ?? 0;

            final stok = (values['stok'] is int)
                ? values['stok'] as int
                : int.tryParse('${values['stok'] ?? ''}') ?? -1;

            final status = (values['status'] ?? 'aktif')
                .toString()
                .toLowerCase();

            final File? image = values['image'] as File?;

            if (categoryId <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'Kategori tidak valid',
              );
            }
            if (nama.isEmpty) {
              return const AdminDialogResult(
                ok: false,
                message: 'nama_produk wajib diisi',
              );
            }
            if (harga <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'harga tidak valid',
              );
            }
            if (stok < 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'stok tidak valid',
              );
            }

            // ✅ ambil message dari backend (edit)
            final apiRes =
                await ProductAdminService.updateProductWithImageResult(
                  productId: p.productId,
                  namaProduk: nama,
                  deskripsi: deskripsi,
                  harga: harga,
                  stok: stok,
                  status: status,
                  categoryId: categoryId,
                  image: image,
                );

            final ok = apiRes['ok'] == true;
            final msg =
                (apiRes['message'] ??
                        (ok ? 'Produk diupdate' : 'Gagal update produk'))
                    .toString();

            return AdminDialogResult(ok: ok, message: msg);
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

  Widget _table(List<ProductModel> list, int allCount) {
    const double wId = 110;
    const double wToko = 110;
    const double wCat = 220;
    const double wNama = 240;
    const double wHarga = 120;
    const double wStok = 100;
    const double wImg = 120;
    const double wStatus = 160;
    const double wAksi = 110;

    final hasActiveFilter =
        _statusFilter != 'semua' || _searchC.text.trim().isNotEmpty;

    return AdminDbTable<ProductModel>(
      tableName: 'products',
      columns: const [
        AdminDbColumn(title: 'product_id', width: wId),
        AdminDbColumn(title: 'toko_id', width: wToko),
        AdminDbColumn(title: 'category', width: wCat),
        AdminDbColumn(title: 'nama_produk', width: wNama),
        AdminDbColumn(
          title: 'harga',
          width: wHarga,
          headerAlign: Alignment.centerRight,
          cellAlign: Alignment.centerRight,
        ),
        AdminDbColumn(
          title: 'stok',
          width: wStok,
          headerAlign: Alignment.centerRight,
          cellAlign: Alignment.centerRight,
        ),
        AdminDbColumn(title: 'image', width: wImg),
        AdminDbColumn(title: 'status', width: wStatus),
        AdminDbColumn(
          title: 'aksi',
          width: wAksi,
          headerAlign: Alignment.center,
          cellAlign: Alignment.center,
        ),
      ],
      items: list,
      rowsHeight: 360,
      emptyWidget: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            allCount == 0
                ? 'Belum ada data produk.'
                : (hasActiveFilter
                      ? 'Tidak ada produk yang cocok dengan filter/search.'
                      : 'Tidak ada produk.'),
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ),
      cellsBuilder: (context, p) {
        final pid = p.productId;

        final catText =
            (p.categoryName != null && p.categoryName!.trim().isNotEmpty)
            ? '${p.categoryId} - ${p.categoryName}'
            : 'category_id=${p.categoryId}';

        final st = _statusOptions.contains(_norm(p.status))
            ? _norm(p.status)
            : 'aktif';

        final busy = _busyStatus.contains(pid);

        final imgUrl = _fullImageUrl(p.imageUrl);
        final hasImg = imgUrl.isNotEmpty;

        return [
          Text('$pid', maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${p.tokoId}', maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(catText, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(p.namaProduk, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            p.harga.toStringAsFixed(0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
          Text(
            '${p.stok}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
          SizedBox(
            height: 46,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 46,
                  height: 46,
                  color: const Color(0xFFEFEFF6),
                  child: hasImg
                      ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported_rounded),
                        )
                      : const Icon(Icons.image_rounded),
                ),
              ),
            ),
          ),

          // STATUS (aktif/nonaktif) -> endpoint admin-only /products/updateStatus
          SizedBox(
            height: 40,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: st,
                isExpanded: true,
                items: _statusOptions
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: busy
                    ? null
                    : (v) async {
                        if (v == null) return;
                        await _changeStatus(p, v);
                      },
              ),
            ),
          ),

          // AKSI: edit
          busy
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: 'Edit Produk',
                  onPressed: () => _openEditDialog(p),
                  icon: const Icon(Icons.edit_rounded),
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
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: ListTile(
                  title: const Text('Gagal memuat data products'),
                  subtitle: Text('${snap.error}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
                ),
              ),
            ),
          );
        }

        final items = snap.data ?? <ProductModel>[];
        final filtered = _applyFilter(items);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AdminTopBar(
                controller: _searchC,
                hintText: 'Cari produk / id / toko / kategori / status',

                // ✅ tombol tambah (pakai AdminEntityAddDialog)
                onAdd: _openCreateDialog,
                addTooltip: 'Tambah Produk',
                addIcon: Icons.add_rounded,
                addColor: Colors.green,

                onFilter: () => _openStatusMenu(context),
                filterTooltip: 'Filter Status Produk',
                filterActive: _statusFilter != 'semua',
              ),
              const SizedBox(height: 10),
              Text(
                'Filter: ${_statusFilter.toUpperCase()} • Data: ${filtered.length}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              _table(filtered, items.length),
            ],
          ),
        );
      },
    );
  }
}
