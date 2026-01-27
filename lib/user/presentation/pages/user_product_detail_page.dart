// pages/user_product_detail_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
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
  // UBAH baseUrl sesuai backend kamu
  static const String _baseUrl = AppConfig.baseUrl;

  bool _loading = false;
  bool _loadingDetail = false;
  Map<String, dynamic>? _p;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _p = widget.product;
    if (_p == null && widget.productId != null) {
      _fetchDetail(widget.productId!);
    }
  }

  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('jwt_token') ?? sp.getString('token');
  }

  Map<String, String> _gradHeaders({String? token}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
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

  Future<void> _fetchDetail(int id) async {
    setState(() => _loadingDetail = true);
    try {
      // asumsi endpoint: GET /products/{id}
      final r = await http.get(Uri.parse('$_baseUrl/products/$id'));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final j = jsonDecode(r.body);
        final data = (j is Map && j['data'] != null) ? j['data'] : j;
        if (data is Map) {
          setState(() => _p = Map<String, dynamic>.from(data as Map));
        }
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  int _stok() {
    final v = _p?['stok'];
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? 0}') ?? 0;
  }

  num _harga() {
    final v = _p?['harga'];
    if (v is num) return v;
    return num.tryParse('${v ?? 0}') ?? 0;
  }

  String _img() {
    final v = _p?['image_url'] ?? _p?['imageUrl'] ?? _p?['gambar'];
    return (v == null) ? '' : '$v';
  }

  int _productId() {
    final v = _p?['product_id'] ?? _p?['productId'];
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? 0}') ?? 0;
  }

  Future<void> _addToCart({required int qty}) async {
    final pid = _productId();
    if (pid <= 0) {
      _snack('Produk tidak valid');
      return;
    }
    if (qty <= 0) qty = 1;

    final tok = await _token();
    if (tok == null || tok.isEmpty) {
      _snack('Token tidak ditemukan, silakan login ulang');
      return;
    }

    setState(() => _loading = true);
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/cart/add'),
        headers: _gradHeaders(token: tok),
        body: jsonEncode({'product_id': pid, 'quantity': qty}),
      );

      final ok = r.statusCode >= 200 && r.statusCode < 300;
      if (!ok) {
        String msg = 'Gagal menambahkan ke keranjang';
        try {
          final j = jsonDecode(r.body);
          if (j is Map && j['message'] != null) msg = '${j['message']}';
        } catch (_) {}
        _snack(msg);
        return;
      }
      _snack('Produk masuk keranjang');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final stok = _stok();
    final harga = _harga();
    final img = _img();

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
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : (p == null)
          ? const Center(child: Text('Produk tidak ditemukan'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                              onPressed: (_loading || stok <= 0)
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
                              onPressed: (_loading || stok <= 0)
                                  ? null
                                  : () async {
                                      await _addToCart(qty: _qty);
                                      if (!mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserCheckoutPage(
                                            user: widget.user,
                                            // checkout dari cart (backend akan baca cart user)
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
                    ],
                  ),
                ),
              ],
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
