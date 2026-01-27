// lib/seller/presentation/pages/seller_product_images.dart
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';

import '../../../models/image_model.dart';
import '../../data/upload_service.dart';
import '../layout/seller_layout.dart';

class SellerProductImagesPage extends StatefulWidget {
  final int productId;
  final String? productName;

  const SellerProductImagesPage({
    super.key,
    required this.productId,
    this.productName,
  });

  @override
  State<SellerProductImagesPage> createState() =>
      _SellerProductImagesPageState();
}

class _SellerProductImagesPageState extends State<SellerProductImagesPage> {
  late Future<List<ImageModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = UploadService.fetchProductImages(widget.productId);
  }

  String? _resolveImg(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    final base = AppConfig.baseUrl;
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }

  Future<void> _reload() async {
    setState(() {
      _future = UploadService.fetchProductImages(widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SellerLayout(
      title: "Foto Produk",
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.productName?.trim().isNotEmpty == true
                        ? widget.productName!.trim()
                        : 'Produk #${widget.productId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ImageModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final images = snapshot.data ?? <ImageModel>[];

                if (images.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Belum ada foto produk.')),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                    itemCount: images.length,
                    itemBuilder: (context, i) {
                      final img = images[i];
                      final url = _resolveImg(img.url);

                      return GestureDetector(
                        onTap: () => _showPreview(context, url ?? ''),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (url == null)
                                    ? Container(
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image),
                                      )
                                    : Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.black12,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () async {
                                  final ok = await UploadService.deleteImage(
                                    imageId: img.imageId,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Foto dihapus'
                                            : 'Gagal hapus foto',
                                      ),
                                    ),
                                  );
                                  if (ok) _reload();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  void _showPreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: url.trim().isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Icon(Icons.broken_image, size: 40),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Icon(Icons.broken_image, size: 40),
                      ),
                    ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
