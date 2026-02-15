import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../services/user_http.dart';
import '../../data/upload_service.dart';

class SellerProductImagesPage extends StatefulWidget {
  final int productId;
  final String productName;

  const SellerProductImagesPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<SellerProductImagesPage> createState() =>
      _SellerProductImagesPageState();
}

class _SellerProductImagesPageState extends State<SellerProductImagesPage> {
  bool _loading = true;
  String? _err;

  final _picker = ImagePicker();
  List<_Img> _items = [];

  static const int _maxBytes = 2 * 1024 * 1024;

  String? _resolveImg(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = AppConfig.baseUrl;
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    final res = await UserHttp.getJson(
      'products/detailProducts?id=${widget.productId}',
    );

    if (!mounted) return;

    if (res['ok'] == true) {
      final images = (res['images'] is List)
          ? List.from(res['images'])
          : <dynamic>[];
      final parsed = images
          .whereType<Map>()
          .map((e) => _Img.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // sort primary dulu
      parsed.sort((a, b) {
        if (a.isPrimary == b.isPrimary) return a.imageId.compareTo(b.imageId);
        return (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0);
      });

      setState(() {
        _items = parsed;
        _loading = false;
      });
      return;
    }

    setState(() {
      _err = (res['message'] ?? 'Gagal memuat foto').toString();
      _loading = false;
    });
  }

  Future<void> _pickAndUpload(ImageSource src) async {
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

      final resUpload = await UploadService.uploadProductImageFile(
        productId: widget.productId,
        file: f,
        fieldName: 'file',
      );

      if (!mounted) return;

      if (resUpload['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Foto berhasil diupload')),
        );
        _load();
        return;
      }

      final msg = (resUpload['message'] ?? 'Gagal upload foto').toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ $msg')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih/upload foto.')),
      );
    }
  }

  Future<void> _openPickSheet() async {
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
                  'Tambah Foto',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Dari Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setPrimary(_Img img) async {
    final res = await UserHttp.postJson('products/images/setPrimary', {
      'product_id': widget.productId,
      'image_id': img.imageId,
    });

    if (!mounted) return;

    if (res['ok'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Foto utama diubah')));
      _load();
      return;
    }

    final msg = (res['message'] ?? 'Gagal set primary').toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('❌ $msg')));
  }

  Future<void> _delete(_Img img) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Foto'),
        content: const Text('Yakin hapus foto ini?'),
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

    final res = await UserHttp.postJson('products/images/delete', {
      'product_id': widget.productId,
      'image_id': img.imageId,
    });

    if (!mounted) return;

    if (res['ok'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Foto dihapus')));
      _load();
      return;
    }

    final msg = (res['message'] ?? 'Gagal hapus foto').toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('❌ $msg')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Foto Produk'),
        actions: [
          IconButton(
            tooltip: 'Tambah Foto',
            icon: const Icon(Icons.add_a_photo_rounded),
            onPressed: _openPickSheet,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_err!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, i) {
                  final it = _items[i];
                  final url = _resolveImg(it.imageUrl);

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            color: Colors.black12,
                            child: url == null
                                ? const Icon(Icons.image_rounded, size: 40)
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_rounded,
                                      size: 40,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              it.isPrimary ? 'UTAMA' : 'FOTO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'primary') _setPrimary(it);
                              if (v == 'delete') _delete(it);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'primary',
                                child: Text('Jadikan Utama'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _Img {
  final int imageId;
  final String imageUrl;
  final bool isPrimary;

  const _Img({
    required this.imageId,
    required this.imageUrl,
    required this.isPrimary,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  factory _Img.fromJson(Map<String, dynamic> j) {
    final isP = j['is_primary'];
    final bool primary = (isP is bool) ? isP : (_toInt(isP) == 1);

    return _Img(
      imageId: _toInt(j['image_id'] ?? j['id']),
      imageUrl: (j['image_url'] ?? j['url'] ?? '').toString(),
      isPrimary: primary,
    );
  }
}
