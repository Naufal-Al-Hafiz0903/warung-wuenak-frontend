import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../services/user_http.dart';
import 'user_checkout_page.dart';

class UserCartPage extends StatefulWidget {
  final Map<String, dynamic> user;

  // optional: dipanggil ketika checkout sukses
  final VoidCallback? onCheckoutSuccess;

  const UserCartPage({super.key, required this.user, this.onCheckoutSuccess});

  @override
  UserCartPageState createState() => UserCartPageState();
}

class UserCartPageState extends State<UserCartPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload(silent: false));
  }

  // dipanggil dari UserShellPage via GlobalKey
  Future<void> reload({bool silent = true}) async {
    await _loadCart(silent: silent);
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

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

  String _str(dynamic v) => (v == null) ? '' : '$v';

  double get _totalProduk {
    double sum = 0;
    for (final it in _items) {
      final harga = _toDouble(it['harga'], 0);
      final qty = _toInt(it['quantity'], 0);
      sum += harga * qty;
    }
    return sum;
  }

  Future<void> _loadCart({bool silent = false}) async {
    if (_busy) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await UserHttp.getJson('cart/my');

      // ignore: avoid_print
      print('[CART/MY] $res');

      if (res['ok'] == true) {
        final data = res['data'];

        List<Map<String, dynamic>> items = [];

        if (data is List) {
          items = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (data is Map && data['data'] is List) {
          final l = data['data'] as List;
          items = l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          items = [];
        }

        if (!mounted) return;
        setState(() {
          _items = items;
          _loading = false;
          _error = null;
        });
        return;
      }

      final msg = (res['message'] ?? res['raw'] ?? 'Gagal memuat cart')
          .toString();
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateQty(int productId, int newQty, int stok) async {
    if (_busy) return;

    newQty = math.max(0, newQty);
    if (stok > 0) newQty = math.min(newQty, stok);

    setState(() => _busy = true);
    try {
      final res = await UserHttp.postJson('cart/update-qty', {
        'product_id': productId,
        'quantity': newQty,
      });

      if (res['ok'] == true) {
        await _loadCart(silent: true);
        return;
      }

      _snack((res['message'] ?? 'Gagal update qty').toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearCart() async {
    if (_busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        content: const Text('Semua item akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final res = await UserHttp.postJson('cart/clear', {});
      if (res['ok'] == true) {
        await _loadCart(silent: true);
        return;
      }
      _snack((res['message'] ?? 'Gagal clear cart').toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goCheckout() async {
    if (_busy || _items.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserCheckoutPage(user: widget.user)),
    );

    await _loadCart(silent: true);

    if (result is Map && result['checkout_ok'] == true) {
      widget.onCheckoutSuccess?.call();
      _snack('Checkout berhasil');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Keranjang'),
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
            tooltip: 'Refresh',
            onPressed: _busy ? null : () => _loadCart(silent: false),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: (_busy || _items.isEmpty) ? null : _clearCart,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCart(silent: false),
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : (_error != null)
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gagal memuat keranjang',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _loadCart(silent: false),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba lagi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : (_items.isEmpty)
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: Text('Keranjang kosong')),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._items.map(
                    (it) => _CartItemCard(
                      item: it,
                      busy: _busy,
                      onMinus: () {
                        final pid = _toInt(it['product_id']);
                        final qty = _toInt(it['quantity']);
                        final stok = _toInt(it['stok']);
                        _updateQty(pid, qty - 1, stok);
                      },
                      onPlus: () {
                        final pid = _toInt(it['product_id']);
                        final qty = _toInt(it['quantity']);
                        final stok = _toInt(it['stok']);
                        _updateQty(pid, qty + 1, stok);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Rp ${_totalProduk.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_busy || _items.isEmpty) ? null : _goCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text(
                        'Checkout',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CartItemCard({
    required this.item,
    required this.busy,
    required this.onMinus,
    required this.onPlus,
  });

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

  String _str(dynamic v) => (v == null) ? '' : '$v';

  // ✅ FIX UTAMA: ubah path relatif "/uploads/..." jadi URL lengkap
  String _resolveImageUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    // UserHttp.baseUrl sudah punya trailing slash ".../"
    final base = UserHttp.baseUrl;
    final cleaned = s.startsWith('/') ? s.substring(1) : s;
    return '$base$cleaned';
  }

  @override
  Widget build(BuildContext context) {
    final nama = _str(item['nama_produk']);
    final harga = _toDouble(item['harga'], 0);
    final qty = _toInt(item['quantity'], 0);
    final stok = _toInt(item['stok'], 0);

    final imageUrlRaw = _str(item['image_url']);
    final imageUrl = _resolveImageUrl(imageUrlRaw);

    final subtotal = harga * qty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 62,
                height: 62,
                color: const Color(0xFFF5F3FF),
                child: (imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_outlined),
                      )
                    : const Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${harga.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stok: $stok • Subtotal: Rp ${subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  onPressed: busy || qty <= 0 ? null : onMinus,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$qty',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: busy || (stok > 0 && qty >= stok) ? null : onPlus,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE9FE)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: child,
    );
  }
}
