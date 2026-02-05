import 'package:flutter/material.dart';

import '../../../core/location/device_location_service.dart';
import '../../../core/utils/geo_haversine.dart';
import '../../../services/user_http.dart';

import '../../data/product_detail_service.dart';
import '../../data/toko_location_service.dart';

import 'user_cart_page.dart';
import 'user_checkout_page.dart';

class UserProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? product; // boleh langsung di-pass dari list
  final int? productId; // atau ambil detail via API

  const UserProductDetailPage({
    super.key,
    required this.user,
    this.product,
    this.productId,
  });

  @override
  State<UserProductDetailPage> createState() => _UserProductDetailPageState();
}

class _UserProductDetailPageState extends State<UserProductDetailPage> {
  bool _loading = false;
  bool _loadingDetail = false;

  Map<String, dynamic>? _p;
  int _qty = 1;

  // ===== TUGAS: toko + jarak =====
  bool _loadingToko = false;
  String? _tokoError;

  String? _tokoName;
  String? _tokoAlamat;
  String? _tokoStatus;

  double? _distanceKm;
  int? _distanceM;

  @override
  void initState() {
    super.initState();
    _p = widget.product;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_p == null && widget.productId != null) {
        await _fetchDetail(widget.productId!);
      } else {
        _afterProductLoaded();
      }
    });
  }

  void _afterProductLoaded() {
    _guardIfInactive();
    _loadTokoAndDistance();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), behavior: SnackBarBehavior.floating),
    );
  }

  // ======================
  // Helpers parse data
  // ======================
  int _toInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? def;
  }

  double _toDouble(dynamic v, [double def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? def;
  }

  String _pickStr(dynamic a, dynamic b, [String def = '']) {
    final v = a ?? b;
    if (v == null) return def;
    final s = v.toString().trim();
    return s.isEmpty ? def : s;
  }

  String _resolveImageUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = UserHttp.baseUrl; // ".../"
    final cleaned = s.startsWith('/') ? s.substring(1) : s;
    return '$base$cleaned';
  }

  bool _isActiveFromMap(Map<String, dynamic>? p) {
    if (p == null) return true;
    final s =
        (p['status'] ??
                p['product_status'] ??
                p['productStatus'] ??
                p['status_produk'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    if (s.isEmpty) return true;
    return s == 'aktif';
  }

  int _stok() {
    final v = _p?['stok'] ?? _p?['stock'];
    return _toInt(v, 0);
  }

  num _harga() {
    final v = _p?['harga'] ?? _p?['price'];
    if (v is num) return v;
    return num.tryParse('${v ?? 0}') ?? 0;
  }

  String _imgRaw() {
    final v = _p?['image_url'] ?? _p?['imageUrl'] ?? _p?['gambar'];
    return (v == null) ? '' : '$v';
  }

  int _productId() {
    final v = _p?['product_id'] ?? _p?['productId'] ?? _p?['id'];
    return _toInt(v, 0);
  }

  int _tokoId() {
    final v =
        _p?['toko_id'] ?? _p?['tokoId'] ?? _p?['shop_id'] ?? _p?['shopId'];
    return _toInt(v, 0);
  }

  void _guardIfInactive() {
    final inactive = !_isActiveFromMap(_p);
    if (!inactive) return;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Produk tidak tersedia'),
        content: const Text(
          'Produk ini berstatus NONAKTIF sehingga tidak bisa dibuka/dibeli.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }

  // ======================
  // Fetch detail via service (UserHttp)
  // ======================
  Future<void> _fetchDetail(int id) async {
    setState(() => _loadingDetail = true);
    try {
      final res = await ProductDetailService.fetchDetailRaw(id);
      if (res['ok'] == true) {
        // coba ambil map produk dari beberapa kemungkinan field
        dynamic prod = res['product'] ?? res['data'] ?? res['item'];

        if (prod is Map) {
          setState(() => _p = Map<String, dynamic>.from(prod));
        } else if (res is Map && res['data'] is Map) {
          setState(() => _p = Map<String, dynamic>.from(res['data']));
        }
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }

    _afterProductLoaded();
  }

  // ======================
  // Add to cart via UserHttp
  // ======================
  Future<void> _addToCart({required int qty}) async {
    final pid = _productId();
    if (pid <= 0) {
      _snack('Produk tidak valid');
      return;
    }
    if (qty <= 0) qty = 1;

    if (!_isActiveFromMap(_p)) {
      _snack('Produk NONAKTIF (tidak bisa ditambahkan)');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await UserHttp.postJson('cart/add', {
        'product_id': pid,
        'quantity': qty,
      });

      if (res['ok'] == true) {
        _snack('Produk masuk keranjang');
        return;
      }

      final msg = (res['detail'] ?? res['message'] ?? 'Gagal menambahkan')
          .toString();
      _snack(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ======================
  // TUGAS: toko + jarak user ↔ toko
  // ======================
  Future<void> _loadTokoAndDistance() async {
    if (_loadingToko) return;

    final pid = _productId();
    if (pid <= 0) return;

    final tokoId = _tokoId();
    if (tokoId <= 0) return;

    setState(() {
      _loadingToko = true;
      _tokoError = null;
    });

    try {
      // ambil info toko dari payload produk (kalau ada)
      final tokoMap = (_p?['toko'] is Map)
          ? Map<String, dynamic>.from(_p!['toko'])
          : <String, dynamic>{};

      final tokoName = _pickStr(
        _p?['nama_toko'] ?? _p?['namaToko'] ?? tokoMap['nama_toko'],
        _p?['toko_name'] ?? tokoMap['toko_name'],
        '',
      );

      final tokoAlamat = _pickStr(
        _p?['alamat_toko'] ?? _p?['alamatToko'] ?? tokoMap['alamat_toko'],
        tokoMap['alamatToko'],
        '',
      );

      final tokoStatus = _pickStr(
        _p?['toko_status'] ?? tokoMap['status'],
        _p?['status_toko'] ?? tokoMap['toko_status'],
        '',
      );

      // ambil GPS user
      final pos = await DeviceLocationService.getCurrentHighAccuracy();

      // ambil lokasi toko dari endpoint
      final loc = await TokoLocationService.fetchTokoLocation(tokoId);

      if (loc == null) {
        setState(() {
          _tokoName = tokoName.isEmpty ? null : tokoName;
          _tokoAlamat = tokoAlamat.isEmpty ? null : tokoAlamat;
          _tokoStatus = tokoStatus.isEmpty ? null : tokoStatus;
          _tokoError = 'Lokasi toko tidak ditemukan';
        });
        return;
      }

      final lat = _toDouble(loc['lat'] ?? loc['latitude'], 0);
      final lng = _toDouble(loc['lng'] ?? loc['longitude'], 0);

      if (lat == 0 || lng == 0) {
        setState(() {
          _tokoName = tokoName.isEmpty ? null : tokoName;
          _tokoAlamat = tokoAlamat.isEmpty ? null : tokoAlamat;
          _tokoStatus = tokoStatus.isEmpty ? null : tokoStatus;
          _tokoError = 'Koordinat toko tidak valid';
        });
        return;
      }

      final meters = haversineMeters(pos.latitude, pos.longitude, lat, lng);
      final km = meters / 1000.0;

      setState(() {
        _tokoName = tokoName.isEmpty ? null : tokoName;
        _tokoAlamat = tokoAlamat.isEmpty ? null : tokoAlamat;
        _tokoStatus = tokoStatus.isEmpty ? null : tokoStatus;
        _distanceM = meters.round();
        _distanceKm = km;
      });
    } catch (e) {
      setState(() => _tokoError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingToko = false);
    }
  }

  String _rupiah(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      c++;
      if (c % 3 == 0 && i != 0) buf.write('.');
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final stok = _stok();
    final harga = _harga();
    final img = _resolveImageUrl(_imgRaw());

    final active = _isActiveFromMap(p);

    final distanceText = (_distanceM == null)
        ? '-'
        : fmtDistance((_distanceM ?? 0).toDouble());

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Detail Produk'),
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF9333EA), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserCartPage(user: widget.user),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _StickyTokoBar(
        loading: _loadingToko,
        tokoName: _tokoName,
        tokoAlamat: _tokoAlamat,
        tokoStatus: _tokoStatus,
        distanceText: distanceText,
        error: _tokoError,
        onRefresh: _loadTokoAndDistance,
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : (p == null)
          ? const Center(child: Text('Produk tidak ditemukan'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!active) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFB45309),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Produk NONAKTIF (tidak bisa dibeli)',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _HeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: img.isEmpty
                              ? Container(
                                  color: const Color(0xFFEDE9FE),
                                  child: const Center(
                                    child: Icon(Icons.image_outlined, size: 48),
                                  ),
                                )
                              : Image.network(
                                  img,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFEDE9FE),
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            icon: Icons.inventory_2_outlined,
                            label: stok > 0 ? 'Stok: $stok' : 'Stok habis',
                            tone: stok > 0 ? _Tone.good : _Tone.bad,
                          ),
                          _Pill(
                            icon: Icons.sell_outlined,
                            label: _rupiah(harga),
                            tone: _Tone.info,
                          ),
                          if ((p['category_name'] ?? p['categoryName']) != null)
                            _Pill(
                              icon: Icons.category_outlined,
                              label:
                                  '${p['category_name'] ?? p['categoryName']}',
                              tone: _Tone.neutral,
                            ),
                          _Pill(
                            icon: active
                                ? Icons.check_circle_outline
                                : Icons.block,
                            label: active ? 'AKTIF' : 'NONAKTIF',
                            tone: active ? _Tone.good : _Tone.bad,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${p['nama_produk'] ?? p['namaProduk'] ?? 'Produk'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${p['deskripsi'] ?? p['deskripsi_produk'] ?? p['deskripsiProduk'] ?? ''}',
                        style: const TextStyle(
                          height: 1.35,
                          color: Color(0xFF3F3F46),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jumlah',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _IconSquareButton(
                            onTap: _loading || _qty <= 1
                                ? null
                                : () => setState(() => _qty--),
                            icon: Icons.remove,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE9D5FF),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$_qty',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _IconSquareButton(
                            onTap: _loading || (_qty >= stok && stok > 0)
                                ? null
                                : () => setState(() => _qty++),
                            icon: Icons.add,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_loading || stok <= 0 || !active)
                                  ? null
                                  : () async {
                                      await _addToCart(qty: _qty);
                                      if (!mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              UserCartPage(user: widget.user),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D28D9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_shopping_cart),
                              label: const Text(
                                'Tambah Keranjang',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_loading || stok <= 0 || !active)
                                  ? null
                                  : () async {
                                      await _addToCart(qty: _qty);
                                      if (!mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserCheckoutPage(
                                            user: widget.user,
                                            prefillKurir: 'kurirku',
                                          ),
                                        ),
                                      );
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6D28D9),
                                side: const BorderSide(
                                  color: Color(0xFF6D28D9),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.flash_on_outlined),
                              label: const Text(
                                'Beli Sekarang',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!active) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Produk NONAKTIF, tombol pembelian dinonaktifkan.',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 72), // ruang untuk sticky bar
              ],
            ),
    );
  }
}

class _StickyTokoBar extends StatelessWidget {
  final bool loading;
  final String? tokoName;
  final String? tokoAlamat;
  final String? tokoStatus;
  final String distanceText;
  final String? error;
  final VoidCallback onRefresh;

  const _StickyTokoBar({
    required this.loading,
    required this.tokoName,
    required this.tokoAlamat,
    required this.tokoStatus,
    required this.distanceText,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final name = (tokoName ?? '').trim();
    final alamat = (tokoAlamat ?? '').trim();
    final status = (tokoStatus ?? '').trim();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: const Color(0xFFEDE9FE))),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, -10),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Informasi toko' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (error != null && error!.trim().isNotEmpty)
                        ? error!
                        : '${alamat.isEmpty ? '-' : alamat} • Jarak: $distanceText'
                              '${status.isNotEmpty ? " • $status" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: (error != null) ? Colors.red : Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 6),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh jarak',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh, color: Color(0xFF6D28D9)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Widget child;
  const _HeroCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

enum _Tone { good, bad, info, neutral }

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final _Tone tone;

  const _Pill({required this.icon, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color bd;

    switch (tone) {
      case _Tone.good:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        bd = const Color(0xFFA7F3D0);
        break;
      case _Tone.bad:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        bd = const Color(0xFFFECACA);
        break;
      case _Tone.info:
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF6D28D9);
        bd = const Color(0xFFE9D5FF);
        break;
      case _Tone.neutral:
        bg = const Color(0xFFF8FAFC);
        fg = const Color(0xFF0F172A);
        bd = const Color(0xFFE2E8F0);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;

  const _IconSquareButton({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF1F5F9) : const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled ? const Color(0xFFE2E8F0) : const Color(0xFFE9D5FF),
          ),
        ),
        child: Icon(
          icon,
          color: disabled ? const Color(0xFF94A3B8) : const Color(0xFF6D28D9),
        ),
      ),
    );
  }
}
