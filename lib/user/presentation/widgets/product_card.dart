import 'package:flutter/material.dart';
import '../../../services/user_http.dart';
import '../../../models/product_model.dart';

class ProductCard extends StatefulWidget {
  final ProductModel p;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.p, this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _busy = false;

  bool get _isActive {
    final s = (widget.p.status ?? '').toString().trim().toLowerCase();
    // default: kalau status kosong, anggap aktif (biar tidak mematikan semua UI)
    if (s.isEmpty) return true;
    return s == 'aktif';
  }

  String _resolveImageUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = UserHttp.baseUrl; // sudah punya trailing slash
    final cleaned = s.startsWith('/') ? s.substring(1) : s;
    return '$base$cleaned';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _rupiah(num v) {
    final int n = v.round();
    final s = n.toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        buf.write('.');
        c = 0;
      }
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  Future<void> _addToCart() async {
    if (_busy) return;

    if (!_isActive) {
      _snack('Produk nonaktif (tidak bisa ditambahkan)');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await UserHttp.postJson('cart/add', {
        'product_id': widget.p.productId,
        'quantity': 1,
      });

      final ok = res['ok'] == true;
      if (ok) {
        _snack('Berhasil ditambahkan ke keranjang');
        return;
      }

      // ✅ ambil error paling jelas
      final msg =
          (res['detail'] ?? res['message'] ?? 'Gagal menambah ke keranjang')
              .toString();
      _snack(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final img = _resolveImageUrl((p.imageUrl ?? '').toString());

    final statusText = _isActive ? 'AKTIF' : 'NONAKTIF';
    final statusBg = _isActive
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFFBEB);
    final statusFg = _isActive
        ? const Color(0xFF047857)
        : const Color(0xFFB45309);
    final statusBd = _isActive
        ? const Color(0xFFA7F3D0)
        : const Color(0xFFFDE68A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
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
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 72,
                  height: 72,
                  color: const Color(0xFFF5F3FF),
                  child: img.isEmpty
                      ? const Icon(Icons.image_outlined)
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.namaProduk ?? 'Produk',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _rupiah(p.harga ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: statusBd),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusFg,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE9D5FF)),
                          ),
                          child: Text(
                            'Stok: ${p.stok ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFF6D28D9),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: (_busy || !_isActive) ? null : _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.black12,
                    disabledForegroundColor: Colors.black45,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Tambah',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
