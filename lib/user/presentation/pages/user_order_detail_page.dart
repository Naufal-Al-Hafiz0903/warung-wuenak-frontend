// pages/user_order_detail_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import 'user_tracking_page.dart';
import 'user_review_page.dart';

class UserOrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final int orderId;
  final Map<String, dynamic>? order;

  const UserOrderDetailPage({
    super.key,
    required this.user,
    required this.orderId,
    this.order,
  });

  @override
  State<UserOrderDetailPage> createState() => _UserOrderDetailPageState();
}

class _UserOrderDetailPageState extends State<UserOrderDetailPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  bool _loading = true;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _shipment;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _load();
  }

  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('token');
  }

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
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

  num _num(dynamic v) => (v is num) ? v : (num.tryParse('${v ?? 0}') ?? 0);
  int _int(dynamic v) =>
      (v is num) ? v.toInt() : (int.tryParse('${v ?? 0}') ?? 0);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = await _token();
      if (tok == null || tok.isEmpty) {
        _snack('Token tidak ditemukan, silakan login ulang');
        return;
      }

      // 1) ambil order dari /orders/my lalu filter (paling kompatibel)
      if (_order == null) {
        final r = await http.get(
          Uri.parse('$_baseUrl/orders/my'),
          headers: _headers(tok),
        );
        if (r.statusCode >= 200 && r.statusCode < 300) {
          final j = jsonDecode(r.body);
          final data = (j is Map && j['data'] is List)
              ? (j['data'] as List)
              : <dynamic>[];
          for (final e in data) {
            final m = Map<String, dynamic>.from(e as Map);
            if (_int(m['order_id']) == widget.orderId) {
              _order = m;
              break;
            }
          }
        }
      }

      // 2) items: coba beberapa endpoint (kalau backend kamu berbeda, tinggal sesuaikan URL)
      _items = [];
      final tryUrls = <String>[
        '$_baseUrl/orders/items?order_id=${widget.orderId}',
        '$_baseUrl/order-items/order/${widget.orderId}',
        '$_baseUrl/order_items/order/${widget.orderId}',
      ];

      for (final u in tryUrls) {
        final r = await http.get(Uri.parse(u), headers: _headers(tok));
        if (r.statusCode >= 200 && r.statusCode < 300) {
          final j = jsonDecode(r.body);
          final data = (j is Map && j['data'] is List)
              ? (j['data'] as List)
              : null;
          if (data != null) {
            _items = data
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            break;
          }
        }
      }

      // 3) shipment: GET /shipments/order/{orderId} (file backend aku sudah buat)
      final s = await http.get(
        Uri.parse('$_baseUrl/shipments/order/${widget.orderId}'),
        headers: _headers(tok),
      );
      if (s.statusCode >= 200 && s.statusCode < 300) {
        final j = jsonDecode(s.body);
        final data = (j is Map && j['data'] != null) ? j['data'] : null;
        if (data is Map) _shipment = Map<String, dynamic>.from(data);
      }
    } catch (_) {
      _snack('Gagal memuat detail order');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusOrder() => ((_order?['status']) ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final st = _statusOrder();
    final total = _num(o?['total_amount']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${widget.orderId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            label: 'Status: ${st.isEmpty ? '-' : st}',
                            tone: _tone(st),
                          ),
                          if (o?['created_at'] != null)
                            _Pill(
                              label: 'Dibuat: ${o?['created_at']}',
                              tone: _Tone.neutral,
                            ),
                          if (o?['metode_pembayaran'] != null)
                            _Pill(
                              label: 'Metode: ${o?['metode_pembayaran']}',
                              tone: _Tone.info,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          Text(
                            _rupiah(total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6D28D9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserTrackingPage(
                                      user: widget.user,
                                      orderId: widget.orderId,
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
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: const Text(
                                'Tracking',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _load,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D28D9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text(
                                'Refresh',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_shipment != null)
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengiriman',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Pill(
                              label: 'Kurir: ${_shipment?['kurir'] ?? '-'}',
                              tone: _Tone.neutral,
                            ),
                            _Pill(
                              label: 'Resi: ${_shipment?['nomor_resi'] ?? '-'}',
                              tone: _Tone.neutral,
                            ),
                            _Pill(
                              label: 'Status: ${_shipment?['status'] ?? '-'}',
                              tone: _Tone.info,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Item Pesanan',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      if (_items.isEmpty)
                        const Text(
                          'Item belum tersedia di endpoint kamu (sesuaikan URL di file ini).',
                        )
                      else
                        Column(
                          children: _items.map((it) {
                            final pid = _int(it['product_id']);
                            final nama =
                                (it['nama_produk'] ?? it['name'] ?? 'Produk')
                                    .toString();
                            final qty = _int(it['quantity']);
                            final subtotal = _num(it['subtotal']);
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFEDE9FE)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nama,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Qty: $qty',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _rupiah(subtotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF6D28D9),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (st == 'selesai')
                                        InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => UserReviewPage(
                                                  user: widget.user,
                                                  productId: pid,
                                                  productName: nama,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Beri ulasan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF6D28D9),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  _Tone _tone(String st) {
    switch (st.toLowerCase()) {
      case 'selesai':
        return _Tone.good;
      case 'dikirim':
        return _Tone.info;
      case 'dibayar':
        return _Tone.neutral;
      case 'menunggu':
      default:
        return _Tone.warn;
    }
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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

enum _Tone { good, info, warn, neutral }

class _Pill extends StatelessWidget {
  final String label;
  final _Tone tone;

  const _Pill({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    Color bg, fg, bd;
    switch (tone) {
      case _Tone.good:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        bd = const Color(0xFFA7F3D0);
        break;
      case _Tone.info:
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF6D28D9);
        bd = const Color(0xFFE9D5FF);
        break;
      case _Tone.warn:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        bd = const Color(0xFFFDE68A);
        break;
      case _Tone.neutral:
      default:
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
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900),
      ),
    );
  }
}
