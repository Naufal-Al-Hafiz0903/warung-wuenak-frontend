// lib/seller/presentation/pages/seller_product_form.dart
import 'package:flutter/material.dart';
import 'package:warung_wuenak/services/category_repository.dart';

import 'package:warung_wuenak/models/product_model.dart';
import 'package:warung_wuenak/services/user_http.dart';

class SellerProductFormPage extends StatefulWidget {
  final ProductModel? initial;

  const SellerProductFormPage({super.key, this.initial});

  @override
  State<SellerProductFormPage> createState() => _SellerProductFormPageState();
}

class _SellerProductFormPageState extends State<SellerProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _namaC = TextEditingController();
  final _descC = TextEditingController();
  final _hargaC = TextEditingController();
  final _stokC = TextEditingController();

  bool _saving = false;

  List<String> _categoryOptions = [];
  String? _selectedCategory;

  // ✅ Seller: status disembunyikan.
  // - Create: default "aktif"
  // - Edit: pertahankan status lama (admin yang atur)
  static const _allowedStatuses = ['aktif', 'nonaktif'];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();

    final p = widget.initial;
    if (p != null) {
      _namaC.text = p.namaProduk;
      _descC.text = p.deskripsi ?? '';
      _hargaC.text = p.harga.toString();
      _stokC.text = p.stok.toString();
    }

    _loadCategories();
  }

  @override
  void dispose() {
    _namaC.dispose();
    _descC.dispose();
    _hargaC.dispose();
    _stokC.dispose();
    super.dispose();
  }

  int _leadingInt(String s) {
    final m = RegExp(r'^\s*(\d+)').firstMatch(s);
    if (m == null) return 0;
    return int.tryParse(m.group(1) ?? '') ?? 0;
  }

  Future<void> _loadCategories({
    bool force = false,
    int? preferCategoryId,
  }) async {
    // 1) pakai cache dulu biar cepat tampil
    final cached = CategoryRepository.getCached();
    if (cached.isNotEmpty && mounted) {
      _setCategoryOptionsFromList(cached, preferCategoryId: preferCategoryId);
    }

    // 2) ambil dari server
    final list = await CategoryRepository.list(force: force);
    if (!mounted) return;
    _setCategoryOptionsFromList(list, preferCategoryId: preferCategoryId);
  }

  void _setCategoryOptionsFromList(
    List<Map<String, dynamic>> list, {
    int? preferCategoryId,
  }) {
    final clean =
        list.where((c) {
          final id = int.tryParse('${c['category_id'] ?? 0}') ?? 0;
          return id > 0;
        }).toList()..sort((a, b) {
          final ia = int.tryParse('${a['category_id'] ?? 0}') ?? 0;
          final ib = int.tryParse('${b['category_id'] ?? 0}') ?? 0;
          return ia.compareTo(ib);
        });

    final opts = clean.map((c) {
      final id = int.tryParse('${c['category_id'] ?? 0}') ?? 0;
      final name = (c['category_name'] ?? '').toString().trim();
      final label = name.isNotEmpty ? name : 'Kategori $id';
      return '$id - $label';
    }).toList();

    String? selected;

    // kalau baru create kategori -> prioritaskan itu
    if (preferCategoryId != null && preferCategoryId > 0) {
      selected = opts.firstWhere(
        (x) => _leadingInt(x) == preferCategoryId,
        orElse: () => '',
      );
      if (selected.isEmpty) selected = null;
    }

    // kalau edit -> pilih sesuai product.categoryId
    if (selected == null && _isEdit) {
      final need = widget.initial!.categoryId;
      selected = opts.firstWhere(
        (x) => _leadingInt(x) == need,
        orElse: () => opts.isNotEmpty ? opts.first : '',
      );
      if (selected.isEmpty) selected = null;
    }

    // kalau create -> default first
    selected ??= (opts.isNotEmpty ? opts.first : null);

    setState(() {
      _categoryOptions = opts;
      _selectedCategory = selected;
    });
  }

  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    return null;
  }

  String? _reqDouble(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    if (double.tryParse(v.trim()) == null) return 'Harus angka';
    return null;
  }

  String? _reqIntNonNeg(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Harus angka';
    if (n < 0) return 'Tidak boleh minus';
    return null;
  }

  String _statusForSubmit() {
    if (!_isEdit) return 'aktif';
    final s = (widget.initial!.status).toString().trim().toLowerCase();
    return _allowedStatuses.contains(s) ? s : 'aktif';
  }

  Future<void> _openAddCategoryDialog() async {
    final nameC = TextEditingController();
    final descC = TextEditingController();

    bool saving = false;

    bool isDuplicateRes(Map<String, dynamic> res) {
      final detail = (res['detail'] ?? '').toString();
      final status = (res['status'] ?? res['statusCode'] ?? 0);
      return detail == 'CATEGORY_EXISTS' || status == 409;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> submit() async {
              if (saving) return;

              final name = nameC.text.trim();
              if (name.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama kategori wajib diisi')),
                  );
                }
                return;
              }

              setStateDialog(() => saving = true);

              try {
                // ✅ parent_id sudah dihapus -> JANGAN kirim parentId lagi
                final res = await CategoryRepository.create(
                  categoryName: name,
                  description: descC.text.trim(),
                );

                if (!mounted) return;

                final ok = res['ok'] == true;

                // ✅ sukses -> pilih kategori baru
                if (ok) {
                  final newId = int.tryParse('${res['category_id'] ?? 0}') ?? 0;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kategori ditambahkan')),
                  );

                  Navigator.pop(ctx);

                  // reload + auto select kategori baru
                  await _loadCategories(force: true, preferCategoryId: newId);
                  return;
                }

                // ✅ duplicate (makanan/Makanan/MAKANAN)
                if (isDuplicateRes(res)) {
                  final existingId =
                      int.tryParse('${res['existing_category_id'] ?? 0}') ?? 0;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Kategori sudah ada. Huruf besar/kecil dianggap sama.',
                      ),
                    ),
                  );

                  // jika server memberi existing id, auto pilih kategori yang sudah ada
                  if (existingId > 0) {
                    Navigator.pop(ctx);
                    await _loadCategories(
                      force: true,
                      preferCategoryId: existingId,
                    );
                  }
                  return;
                }

                // error lain
                final msg =
                    (res['message']?.toString().trim().isNotEmpty == true)
                    ? res['message'].toString()
                    : 'Gagal menambah kategori';

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal tambah kategori: $e')),
                );
              } finally {
                if (ctx.mounted) setStateDialog(() => saving = false);
              }
            }

            return AlertDialog(
              title: const Text('Tambah Kategori'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kategori',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descC,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi (opsional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    // ✅ parent field dihapus total
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: Text(saving ? 'Menyimpan...' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_saving) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori belum dipilih / data kategori kosong'),
        ),
      );
      return;
    }

    final categoryId = _leadingInt(_selectedCategory!);
    if (categoryId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('category_id tidak valid')));
      return;
    }

    final nama = _namaC.text.trim();
    final desc = _descC.text.trim();
    final harga = _hargaC.text.trim();
    final stok = _stokC.text.trim();

    setState(() => _saving = true);

    final body = <String, dynamic>{
      'category_id': categoryId,
      'nama_produk': nama,
      'deskripsi': desc,
      'harga': harga,
      'stok': stok,
      'status': _statusForSubmit(),
    };

    Map<String, dynamic> res;
    if (_isEdit) {
      body['product_id'] = widget.initial!.productId;
      res = await UserHttp.postJson('products/updateProducts', body);
    } else {
      res = await UserHttp.postJson('products/createProducts', body);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    final ok = res['ok'] == true;
    final msg = (res['message']?.toString().trim().isNotEmpty == true)
        ? res['message'].toString()
        : (ok ? 'Berhasil disimpan' : 'Gagal');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Produk' : 'Tambah Produk';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            items: _categoryOptions
                                .map(
                                  (x) => DropdownMenuItem(
                                    value: x,
                                    child: Text(x),
                                  ),
                                )
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _selectedCategory = v),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tambah kategori',
                        onPressed: _saving ? null : _openAddCategoryDialog,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                      IconButton(
                        tooltip: 'Refresh kategori',
                        onPressed: _saving
                            ? null
                            : () => _loadCategories(force: true),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                if (_categoryOptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tidak ada kategori / endpoint /categories belum bisa diakses.',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _namaC,
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descC,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hargaC,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Harga',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _reqDouble,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stokC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _reqIntNonNeg,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
