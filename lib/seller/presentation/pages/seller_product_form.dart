// lib/seller/presentation/pages/seller_product_form.dart
import 'package:flutter/material.dart';

import 'package:warung_wuenak/models/product_model.dart';
import 'package:warung_wuenak/services/category_service.dart';
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

  Future<void> _loadCategories() async {
    final cats = await CategoryService.fetchCategoriesAdmin();
    if (!mounted) return;

    final clean = cats.where((c) => c.categoryId > 0).toList()
      ..sort((a, b) => a.categoryId.compareTo(b.categoryId));

    final opts = clean.map((c) {
      final name = c.categoryName.trim().isNotEmpty
          ? c.categoryName.trim()
          : 'Kategori ${c.categoryId}';
      return '${c.categoryId} - $name';
    }).toList();

    String? selected;
    if (_isEdit) {
      final need = widget.initial!.categoryId;
      selected = opts.firstWhere(
        (x) => _leadingInt(x) == need,
        orElse: () => opts.isNotEmpty ? opts.first : '',
      );
      if (selected.isEmpty) selected = null;
    } else {
      selected = opts.isNotEmpty ? opts.first : null;
    }

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
    // ✅ status tetap, admin yang mengatur aktif/nonaktif
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

    // ✅ KIRIM JSON (bukan form) -> FIX error backend
    final body = <String, dynamic>{
      'category_id': categoryId,
      'nama_produk': nama,
      'deskripsi': desc,
      'harga': harga,
      'stok': stok,
      'status': _statusForSubmit(), // ✅ disembunyikan dari UI seller
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
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      items: _categoryOptions
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _selectedCategory = v),
                    ),
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
