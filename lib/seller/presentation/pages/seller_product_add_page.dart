// lib/seller/presentation/pages/seller_product_add_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/category_model.dart';
import '../../../services/category_service.dart';
import '../../../services/user_http.dart';
import '../../data/upload_service.dart';

class SellerProductAddPage extends StatefulWidget {
  const SellerProductAddPage({super.key});

  @override
  State<SellerProductAddPage> createState() => _SellerProductAddPageState();
}

class _SellerProductAddPageState extends State<SellerProductAddPage> {
  final _formKey = GlobalKey<FormState>();

  final _namaC = TextEditingController();
  final _descC = TextEditingController();
  final _hargaC = TextEditingController();
  final _stokC = TextEditingController();

  bool _saving = false;

  List<CategoryModel> _cats = [];
  CategoryModel? _selected;

  static const String _statusDefault = 'nonaktif';

  // ✅ image picker
  final _picker = ImagePicker();
  File? _pickedImage;

  static const int _maxBytes = 2 * 1024 * 1024; // 2MB (sesuai backend)

  @override
  void initState() {
    super.initState();
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

    setState(() {
      _cats = clean;
      _selected = clean.isNotEmpty ? clean.first : null;
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

  Future<void> _pickFrom(ImageSource src) async {
    if (_saving) return;

    try {
      final x = await _picker.pickImage(source: src, imageQuality: 85);
      if (x == null) return;

      final f = File(x.path);
      final len = await f.length();

      if (len > _maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran foto maksimal 2MB.')),
        );
        return;
      }

      setState(() => _pickedImage = f);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal memilih foto.')));
    }
  }

  Future<void> _openPickSheet() async {
    if (_saving) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Pilih Foto Produk',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFrom(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Dari Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFrom(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  int _extractProductId(Map<String, dynamic> res) {
    final direct = _toInt(res['product_id'] ?? res['productId'] ?? res['id']);
    if (direct > 0) return direct;

    final data = res['data'];
    if (data is Map) {
      return _toInt(data['product_id'] ?? data['productId'] ?? data['id']);
    }
    return 0;
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

    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto produk wajib dipilih.')),
      );
      return;
    }

    final len = await _pickedImage!.length();
    if (len > _maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukuran foto maksimal 2MB.')),
      );
      return;
    }

    setState(() => _saving = true);

    // ✅ KIRIM JSON (bukan x-www-form-urlencoded) -> FIX error backend
    final body = <String, dynamic>{
      'category_id': _selected!.categoryId,
      'nama_produk': _namaC.text.trim(),
      'deskripsi': _descC.text.trim(),
      'harga': _hargaC.text.trim(),
      'stok': _stokC.text.trim(),
      'status': _statusDefault, // ✅ selalu aktif
    };

    final resCreate = await UserHttp.postJson('products/createProducts', body);

    if (!mounted) return;

    final okCreate = resCreate['ok'] == true;
    if (!okCreate) {
      setState(() => _saving = false);
      final msg = (resCreate['message']?.toString().trim().isNotEmpty == true)
          ? resCreate['message'].toString()
          : 'Gagal menambah produk';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final productId = _extractProductId(resCreate);
    if (productId <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Produk berhasil dibuat, tapi product_id tidak ditemukan.',
          ),
        ),
      );
      return;
    }

    // ✅ Upload product_image (insert ke table product_images)
    final resUpload = await UploadService.uploadProductImageFile(
      productId: productId,
      file: _pickedImage!,
      fieldName: 'file',
    );

    if (!mounted) return;

    final okUpload = resUpload['ok'] == true;
    if (!okUpload) {
      // rollback: hapus produk agar tidak ada produk tanpa gambar
      try {
        await UserHttp.postJson('products/deleteProducts', {
          'product_id': productId,
        });
      } catch (_) {}

      setState(() => _saving = false);

      final msg = (resUpload['message']?.toString().trim().isNotEmpty == true)
          ? resUpload['message'].toString()
          : 'Gagal upload foto produk';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ $msg (produk dibatalkan)')));
      return;
    }

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Produk & foto berhasil ditambahkan')),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Produk')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Foto Produk
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto Produk (wajib, max 2MB)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _saving ? null : _openPickSheet,
                  child: Container(
                    width: double.infinity,
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                      color: Colors.white.withOpacity(.85),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _pickedImage == null
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 34,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Ketuk untuk pilih foto',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Image.file(_pickedImage!, fit: BoxFit.cover),
                          ),
                        ),
                        if (_pickedImage != null)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: InkWell(
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _pickedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                              child: Text(
                                '${c.categoryId} - ${c.categoryName}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _selected = v),
                    ),
                  ),
                ),
                if (_cats.isEmpty)
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
                        Text(_saving ? 'Menyimpan...' : 'Simpan'),
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
