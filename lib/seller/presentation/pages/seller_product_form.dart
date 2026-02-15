import 'package:flutter/material.dart';

import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../services/category_service.dart';
import '../../../services/user_http.dart';

class SellerProductFormPage extends StatefulWidget {
  final ProductModel initial;

  const SellerProductFormPage({super.key, required this.initial});

  @override
  State<SellerProductFormPage> createState() => _SellerProductFormPageState();
}

class _SellerProductFormPageState extends State<SellerProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _namaC;
  late final TextEditingController _descC;
  late final TextEditingController _hargaC;
  late final TextEditingController _stokC;

  bool _saving = false;

  List<CategoryModel> _cats = [];
  CategoryModel? _selected;

  String _status = 'aktif'; // aktif|nonaktif

  @override
  void initState() {
    super.initState();

    _namaC = TextEditingController(text: widget.initial.namaProduk);
    _descC = TextEditingController(text: widget.initial.deskripsi ?? '');
    _hargaC = TextEditingController(text: widget.initial.harga.toStringAsFixed(0));
    _stokC = TextEditingController(text: widget.initial.stok.toString());
    _status = (widget.initial.status).toLowerCase().trim().isEmpty
        ? 'aktif'
        : widget.initial.status.toLowerCase().trim();

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

  Future<void> _loadCategories() async {
    final cats = await CategoryService.fetchCategoriesAdmin();
    if (!mounted) return;

    final clean = cats.where((c) => c.categoryId > 0).toList()
      ..sort((a, b) => a.categoryId.compareTo(b.categoryId));

    CategoryModel? sel;
    for (final c in clean) {
      if (c.categoryId == widget.initial.categoryId) {
        sel = c;
        break;
      }
    }
    sel ??= clean.isNotEmpty ? clean.first : null;

    setState(() {
      _cats = clean;
      _selected = sel;
    });
  }

  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    return null;
  }

  String? _reqDouble(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    final n = double.tryParse(v.trim());
    if (n == null) return 'Harus angka';
    if (n <= 0) return 'Harus > 0';
    return null;
  }

  String? _reqIntNonNeg(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Harus angka';
    if (n < 0) return 'Tidak boleh minus';
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori kosong / belum bisa diambil')),
      );
      return;
    }

    setState(() => _saving = true);

    final body = <String, dynamic>{
      'product_id': widget.initial.productId,
      'category_id': _selected!.categoryId,
      'nama_produk': _namaC.text.trim(),
      'deskripsi': _descC.text.trim(),
      'harga': _hargaC.text.trim(),
      'stok': _stokC.text.trim(),
      'status': _status, // aktif|nonaktif
    };

    final res = await UserHttp.postJson('products/updateProducts', body);

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Produk berhasil diupdate')),
      );
      Navigator.pop(context, true);
      return;
    }

    final msg = (res['message'] ?? 'Gagal update produk').toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Produk')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Product ID: ${widget.initial.productId}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Kategori
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CategoryModel>(
                      value: _selected,
                      isExpanded: true,
                      items: _cats
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c.categoryId} - ${c.categoryName}'),
                            ),
                          )
                          .toList(),
                      onChanged: _saving ? null : (v) => setState(() => _selected = v),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                const SizedBox(height: 12),

                // Status
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _status,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                        DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _status = v ?? 'aktif'),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_saving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (_saving) const SizedBox(width: 10),
                        Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
                      ],
                    ),
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
