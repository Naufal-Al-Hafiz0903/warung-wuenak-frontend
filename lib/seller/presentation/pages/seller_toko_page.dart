import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/location/device_location_service.dart';

import '../../../models/toko_model.dart';
import '../../../models/toko_product_item_model.dart';
import '../../data/seller_toko_service.dart';
import '../../data/seller_toko_location_service.dart';
import '../layout/seller_layout.dart';

class SellerTokoPage extends StatefulWidget {
  const SellerTokoPage({super.key});

  @override
  State<SellerTokoPage> createState() => _SellerTokoPageState();
}

class _SellerTokoPageState extends State<SellerTokoPage> {
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 450));

  TokoModel? _toko;
  bool _loadingToko = true;

  List<TokoProductItemModel> _products = [];
  bool _loadingProducts = true;

  String _status = 'all'; // all|aktif|nonaktif
  String _sort = 'sold_desc'; // sold_desc|sold_asc

  // ✅ banner max size
  static const int kMaxBannerBytes = 300 * 1024;

  // ==========================
  // ✅ NEW: lokasi toko
  // ==========================
  bool _loadingLoc = false;
  String? _locError;
  Map<String, dynamic>? _loc;
  // contoh: {toko_id,user_id,lat,lng,accuracy_m,location_updated_at,location_set}

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _reloadAll() async {
    setState(() {
      _loadingToko = true;
      _loadingProducts = true;

      // lokasi
      _loadingLoc = false;
      _locError = null;
      _loc = null;
    });

    // ✅ 1) ambil toko dulu
    final toko = await SellerTokoService.fetchMyToko();
    if (!mounted) return;

    // ✅ 2) kalau toko null -> jangan panggil products & lokasi
    if (toko == null) {
      setState(() {
        _toko = null;
        _products = <TokoProductItemModel>[];
        _loadingToko = false;
        _loadingProducts = false;

        _loadingLoc = false;
        _loc = null;
        _locError = null;
      });
      return;
    }

    // ✅ set toko
    setState(() {
      _toko = toko;
      _loadingToko = false;
    });

    // ✅ 2b) load lokasi toko (tidak block products)
    _loadMyTokoLocation(silent: true);

    // ✅ 3) toko ada -> baru ambil products
    setState(() => _loadingProducts = true);
    final products = await SellerTokoService.fetchMyProducts(
      status: _status,
      sort: _sort,
    );

    if (!mounted) return;
    setState(() {
      _products = products;
      _loadingProducts = false;
    });
  }

  Future<void> _loadMyTokoLocation({bool silent = false}) async {
    if (_toko == null) return;

    if (!silent) {
      setState(() {
        _loadingLoc = true;
        _locError = null;
      });
    } else {
      _loadingLoc = true;
      _locError = null;
    }

    try {
      final loc = await SellerTokoLocationService.fetchMyTokoLocation();
      if (!mounted) return;

      setState(() {
        _loc = loc; // bisa null kalau 404 / ok false
        _loadingLoc = false;
        _locError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLoc = false;
        _locError = e.toString();
      });
    }
  }

  Future<void> _setLocationFromGps() async {
    if (_toko == null) {
      _snack('Buat toko dulu sebelum mengatur lokasi.');
      return;
    }
    if (_loadingLoc) return;

    setState(() {
      _loadingLoc = true;
      _locError = null;
    });

    try {
      final Position pos = await DeviceLocationService.getCurrentHighAccuracy();

      final res = await SellerTokoLocationService.updateMyTokoLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy.round(),
      );

      if (!mounted) return;

      if (res['ok'] == true) {
        _snack('Lokasi toko tersimpan');
        await _loadMyTokoLocation(silent: true);
        if (!mounted) return;
        setState(() => _loadingLoc = false);
      } else {
        setState(() {
          _loadingLoc = false;
          _locError = (res['message'] ?? 'Gagal menyimpan lokasi').toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLoc = false;
        _locError = e.toString();
      });
    }
  }

  void _onFilterChanged({String? status, String? sort}) {
    if (status != null) _status = status;
    if (sort != null) _sort = sort;

    // ✅ kalau toko belum ada, jangan hit server
    if (_toko == null) {
      setState(() {
        _products = <TokoProductItemModel>[];
        _loadingProducts = false;
      });
      return;
    }

    setState(() => _loadingProducts = true);

    _debouncer.run(() async {
      final products = await SellerTokoService.fetchMyProducts(
        status: _status,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    });
  }

  String _resolveUrl(String? raw) {
    final r = (raw ?? '').trim();
    if (r.isEmpty) return '';
    if (r.startsWith('http://') || r.startsWith('https://')) return r;
    if (r.startsWith('/')) return '${Api.baseUrl}$r';
    return '${Api.baseUrl}/$r';
  }

  String _formatRupiah(num value) {
    final int v = value.round();
    final s = v.toString();
    final sb = StringBuffer();
    int counter = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      counter++;
      if (counter == 3 && i != 0) {
        sb.write('.');
        counter = 0;
      }
    }
    final reversed = sb.toString().split('').reversed.join();
    return 'Rp $reversed';
  }

  double? _toDoubleObj(dynamic v) {
    try {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return double.parse(s);
    } catch (_) {
      return null;
    }
  }

  bool _isNonZero(double? v) => v != null && v.abs() > 0.000001;

  bool _locationIsSet() {
    if (_loc == null) return false;
    if (_loc!['location_set'] == true) return true;

    final lat = _toDoubleObj(_loc!['lat']);
    final lng = _toDoubleObj(_loc!['lng']);
    return _isNonZero(lat) && _isNonZero(lng);
  }

  String _fmtCoord(double? v) {
    if (v == null) return '-';
    return v.toStringAsFixed(6);
  }

  Future<File?> _compressBannerToLimit(File input) async {
    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/toko_banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

    int quality = 90;
    File? outFile;

    while (quality >= 45) {
      final result = await FlutterImageCompress.compressAndGetFile(
        input.absolute.path,
        outPath,
        quality: quality,
        format: CompressFormat.jpeg,
        minWidth: 2560,
        minHeight: 1440,
      );

      if (result == null) break;

      final f = File(result.path);
      final size = await f.length();
      outFile = f;

      if (size <= kMaxBannerBytes) return outFile;
      quality -= 10;
    }

    return outFile;
  }

  Future<void> _pickAndUploadBanner() async {
    if (_loadingToko) return;

    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;

    final original = File(x.path);
    final compressed = await _compressBannerToLimit(original);

    if (compressed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal memproses gambar')));
      return;
    }

    final size = await compressed.length();
    if (!mounted) return;

    if (size > kMaxBannerBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gambar masih > ${kMaxBannerBytes ~/ 1024}KB. Coba gambar lain.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mengupload banner...')));

    final updated = await SellerTokoService.uploadBanner(compressed);
    if (!mounted) return;

    if (updated == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal upload banner')));
      return;
    }

    setState(() => _toko = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Banner berhasil diupdate')));
  }

  Future<void> _createTokoDialog() async {
    final namaC = TextEditingController();
    final deskC = TextEditingController();
    final alamatC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buat Toko'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: namaC,
                decoration: const InputDecoration(labelText: 'Nama Toko'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deskC,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: alamatC,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final nama = namaC.text.trim();
    if (nama.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nama toko wajib diisi')));
      return;
    }

    final success = await SellerTokoService.updateMyToko(
      namaToko: nama,
      deskripsi: deskC.text.trim(),
      alamat: alamatC.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Toko dibuat' : 'Gagal membuat toko')),
    );

    if (success) {
      await _reloadAll();
    }
  }

  Widget _bannerSection() {
    final bannerUrl = _resolveUrl(_toko?.bannerUrl);

    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black12.withOpacity(0.05),
              child: bannerUrl.isEmpty
                  ? Container(
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image,
                        size: 46,
                        color: Colors.black38,
                      ),
                    )
                  : Image.network(
                      bannerUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image,
                          size: 42,
                          color: Colors.black38,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                    Colors.black.withOpacity(0.25),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: ElevatedButton.icon(
              onPressed: (_toko == null)
                  ? _createTokoDialog
                  : _pickAndUploadBanner,
              icon: const Icon(Icons.photo_camera_back),
              label: Text(_toko == null ? 'Buat Toko' : 'Ganti Banner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================
  // ✅ NEW UI: kartu lokasi toko
  // ==========================
  Widget _locationCard() {
    if (_toko == null) return const SizedBox.shrink();

    final setLoc = _locationIsSet();
    final lat = _loc == null ? null : _toDoubleObj(_loc!['lat']);
    final lng = _loc == null ? null : _toDoubleObj(_loc!['lng']);
    final updatedAt = _loc == null
        ? null
        : (_loc!['location_updated_at']?.toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12.withOpacity(0.08)),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, color: Color(0xFF7C4DFF)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Lokasi Toko',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: setLoc
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.14),
                  ),
                  child: Text(
                    setLoc ? 'SUDAH' : 'BELUM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: setLoc
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_loadingLoc)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(
                'Lat: ${_fmtCoord(lat)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Lng: ${_fmtCoord(lng)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Update: ${updatedAt ?? '-'}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            if (_locError != null) ...[
              const SizedBox(height: 10),
              Text(
                _locError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadingLoc ? null : _setLocationFromGps,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text(
                      'Ambil GPS & Simpan',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _loadingLoc ? null : () => _loadMyTokoLocation(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),

            if (!setLoc) ...[
              const SizedBox(height: 10),
              Text(
                'Catatan: checkout user akan gagal jika lokasi toko belum diatur.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pinnedHeader() {
    final nama = (_toko?.namaToko ?? 'Toko Saya').trim();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nama.isEmpty ? 'Toko Saya' : nama,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          // ✅ FIX OVERFLOW: jadikan horizontal scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _status == 'all',
                  onSelected: (_) => _onFilterChanged(status: 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Aktif'),
                  selected: _status == 'aktif',
                  onSelected: (_) => _onFilterChanged(status: 'aktif'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Nonaktif'),
                  selected: _status == 'nonaktif',
                  onSelected: (_) => _onFilterChanged(status: 'nonaktif'),
                ),
                const SizedBox(width: 10),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(
                        value: 'sold_desc',
                        child: Text('Terbanyak dibeli'),
                      ),
                      DropdownMenuItem(
                        value: 'sold_asc',
                        child: Text('Tersedikit dibeli'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      _onFilterChanged(sort: v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productList() {
    if (_toko == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toko belum dibuat',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Buat toko dulu untuk menampilkan banner dan daftar produk.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createTokoDialog,
                    child: const Text('Buat Toko'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loadingProducts) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Tidak ada produk untuk filter ini.',
              style: TextStyle(color: Colors.black.withOpacity(0.65)),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = _products[i];
        final img = _resolveUrl(p.imageUrl);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12.withOpacity(0.08)),
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 70,
                  height: 70,
                  color: Colors.black12.withOpacity(0.06),
                  child: img.isEmpty
                      ? const Icon(
                          Icons.image_not_supported,
                          color: Colors.black38,
                        )
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.black38,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.namaProduk,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatRupiah(p.harga),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C4DFF),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Terjual: ${p.soldQty} • Stok: ${p.stok}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: p.status.toLowerCase() == 'aktif'
                      ? Colors.green.withOpacity(0.12)
                      : Colors.red.withOpacity(0.10),
                ),
                child: Text(
                  p.status.toLowerCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: p.status.toLowerCase() == 'aktif'
                        ? Colors.green.shade800
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SellerLayout(
      title: "Toko Saya",
      child: RefreshIndicator(
        onRefresh: _reloadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _loadingToko
                  ? const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _bannerSection(),
            ),

            // ✅ NEW: kartu lokasi toko
            SliverToBoxAdapter(child: _locationCard()),

            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeaderDelegate(
                minHeight: 118,
                maxHeight: 118,
                child: _pinnedHeader(),
              ),
            ),

            SliverToBoxAdapter(child: _productList()),
          ],
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _PinnedHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(elevation: overlapsContent ? 2 : 0, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.child != child;
  }
}
