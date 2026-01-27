import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/seller_orders_service.dart';
import '../layout/seller_layout.dart';
import 'seller_order_detail_page.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  bool _loading = true;
  bool _polling = false;
  String? _error;

  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic> _counts = {
    'menunggu': 0,
    'membayar': 0,
    'dikirim': 0,
    'selesai': 0,
  };

  String _filter = 'all'; // all|menunggu|membayar|dikirim|selesai
  int _maxOrderId = 0;

  int _lastSeenOrderId = 0;

  Timer? _t;
  int _intervalSec = 8;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadLastSeen();
    await _reloadAll(force: true);
    _startPolling();
  }

  Future<void> _loadLastSeen() async {
    final sp = await SharedPreferences.getInstance();
    _lastSeenOrderId = sp.getInt('seller_last_seen_order_id') ?? 0;
  }

  Future<void> _saveLastSeen(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('seller_last_seen_order_id', v);
    _lastSeenOrderId = v;
  }

  void _startPolling() {
    _t?.cancel();
    _t = Timer.periodic(Duration(seconds: _intervalSec), (_) => _poll());
  }

  void _adjustInterval({required bool changed, required bool error}) {
    // adaptif: kalau sering berubah -> cepat, kalau stabil -> pelan
    if (error) {
      _intervalSec = 20;
    } else if (changed) {
      _intervalSec = 8;
    } else {
      _intervalSec = 14;
    }
    _startPolling();
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;

    try {
      final sum = await SellerOrdersService.fetchSummary(days: 30);
      if (sum['ok'] == true && sum['data'] is Map) {
        final data = Map<String, dynamic>.from(sum['data'] as Map);
        final counts = (data['counts'] is Map)
            ? Map<String, dynamic>.from(data['counts'] as Map)
            : <String, dynamic>{};
        final maxId = int.tryParse('${data['max_order_id'] ?? 0}') ?? 0;

        setState(() {
          _counts = {
            'menunggu': int.tryParse('${counts['menunggu'] ?? 0}') ?? 0,
            'membayar': int.tryParse('${counts['membayar'] ?? 0}') ?? 0,
            'dikirim': int.tryParse('${counts['dikirim'] ?? 0}') ?? 0,
            'selesai': int.tryParse('${counts['selesai'] ?? 0}') ?? 0,
          };
        });

        final changed = maxId != _maxOrderId;
        if (changed) {
          _maxOrderId = maxId;
          // ambil list baru (hemat: after_id untuk nambah saja)
          await _reloadList();
        }

        _adjustInterval(changed: changed, error: false);
      } else {
        _adjustInterval(changed: false, error: true);
      }
    } catch (_) {
      _adjustInterval(changed: false, error: true);
    } finally {
      _polling = false;
    }
  }

  Future<void> _reloadAll({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sum = await SellerOrdersService.fetchSummary(days: 30);
      if (sum['ok'] == true && sum['data'] is Map) {
        final data = Map<String, dynamic>.from(sum['data'] as Map);
        final counts = (data['counts'] is Map)
            ? Map<String, dynamic>.from(data['counts'] as Map)
            : <String, dynamic>{};
        _maxOrderId = int.tryParse('${data['max_order_id'] ?? 0}') ?? 0;

        _counts = {
          'menunggu': int.tryParse('${counts['menunggu'] ?? 0}') ?? 0,
          'membayar': int.tryParse('${counts['membayar'] ?? 0}') ?? 0,
          'dikirim': int.tryParse('${counts['dikirim'] ?? 0}') ?? 0,
          'selesai': int.tryParse('${counts['selesai'] ?? 0}') ?? 0,
        };
      }

      await _reloadList();
    } catch (e) {
      setState(() => _error = 'Gagal memuat: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadList() async {
    final status = (_filter == 'all') ? null : _filter;

    final res = await SellerOrdersService.fetchOrders(
      status: status,
      days: 30,
      limit: 60,
    );

    if (res['ok'] == true && res['data'] is List) {
      final list = (res['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        _orders = list;
        _error = null;
      });

      // kalau list paling atas lebih besar dari last seen -> tampil “baru”
      if (_orders.isNotEmpty) {
        final topId = int.tryParse('${_orders.first['order_id'] ?? 0}') ?? 0;
        if (topId > _lastSeenOrderId) {
          // jangan auto mark read, biar user lihat dulu
        }
      }
      return;
    }

    setState(() => _error = (res['message'] ?? 'Gagal memuat').toString());
  }

  void _onFilter(String f) {
    setState(() => _filter = f);
    _reloadList();
  }

  Color _pillBg(String st) {
    st = st.toLowerCase().trim();
    if (st == 'menunggu') return const Color(0xFFFFF7ED);
    if (st == 'membayar') return const Color(0xFFF0F9FF);
    if (st == 'dikirim') return const Color(0xFFF5F3FF);
    if (st == 'selesai') return const Color(0xFFF0FDF4);
    return const Color(0xFFF8FAFC);
  }

  Color _pillFg(String st) {
    st = st.toLowerCase().trim();
    if (st == 'menunggu') return const Color(0xFF9A3412);
    if (st == 'membayar') return const Color(0xFF0369A1);
    if (st == 'dikirim') return const Color(0xFF6D28D9);
    if (st == 'selesai') return const Color(0xFF166534);
    return const Color(0xFF0F172A);
  }

  String _rupiah(num v) {
    final n = v.round();
    final s = n.toString();
    final sb = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        sb.write('.');
        c = 0;
      }
    }
    return 'Rp ${sb.toString().split('').reversed.join()}';
  }

  bool _isNew(int orderId) => orderId > _lastSeenOrderId;

  Future<void> _openDetail(Map<String, dynamic> o) async {
    final orderId = int.tryParse('${o['order_id'] ?? 0}') ?? 0;
    if (orderId <= 0) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailPage(orderId: orderId),
      ),
    );

    // setelah balik, anggap user sudah melihat order paling baru
    if (_orders.isNotEmpty) {
      final topId = int.tryParse('${_orders.first['order_id'] ?? 0}') ?? 0;
      if (topId > _lastSeenOrderId) {
        await _saveLastSeen(topId);
        setState(() {});
      }
    }
  }

  Widget _summary() {
    Widget card(String label, int value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDE9FE)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 14,
                offset: Offset(0, 8),
                color: Color(0x12000000),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF6D28D9)),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card('Menunggu', _counts['menunggu'] ?? 0, Icons.schedule_rounded),
        const SizedBox(width: 10),
        card('Membayar', _counts['membayar'] ?? 0, Icons.payments_outlined),
        const SizedBox(width: 10),
        card('Dikirim', _counts['dikirim'] ?? 0, Icons.local_shipping_outlined),
        const SizedBox(width: 10),
        card('Selesai', _counts['selesai'] ?? 0, Icons.verified_rounded),
      ],
    );
  }

  Widget _filters() {
    Widget chip(String key, String text) {
      final sel = _filter == key;
      return InkWell(
        onTap: () => _onFilter(key),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFF5F3FF) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: sel ? const Color(0xFFD8B4FE) : const Color(0xFFEDE9FE),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: sel ? const Color(0xFF6D28D9) : const Color(0xFF0F172A),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('all', 'Semua'),
          const SizedBox(width: 8),
          chip('menunggu', 'Menunggu'),
          const SizedBox(width: 8),
          chip('membayar', 'Membayar'),
          const SizedBox(width: 8),
          chip('dikirim', 'Dikirim'),
          const SizedBox(width: 8),
          chip('selesai', 'Selesai'),
        ],
      ),
    );
  }

  Widget _list() {
    if (_orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDE9FE)),
        ),
        child: Column(
          children: const [
            Icon(Icons.inbox_outlined, size: 46, color: Colors.black38),
            SizedBox(height: 10),
            Text(
              'Belum ada pesanan',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Jika ada order masuk, akan muncul di sini.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _orders.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = _orders[i];
        final id = int.tryParse('${o['order_id'] ?? 0}') ?? 0;
        final pembeli = (o['pembeli'] ?? '-').toString();
        final st = (o['status'] ?? 'menunggu').toString().toLowerCase().trim();
        final metode = (o['metode_pembayaran'] ?? '').toString();
        final created = (o['created_at'] ?? '').toString();
        final total = double.tryParse('${o['total_amount'] ?? 0}') ?? 0;

        return InkWell(
          onTap: () => _openDetail(o),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Order #$id',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    if (_isNew(id))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'BARU',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _pillBg(st),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFEDE9FE)),
                      ),
                      child: Text(
                        st,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _pillFg(st),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  pembeli,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _rupiah(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6D28D9),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: 'Metode: ${metode.isEmpty ? '-' : metode}'),
                    if (created.isNotEmpty) _Pill(text: created),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SellerLayout(
      title: 'Pesanan',
      child: RefreshIndicator(
        onRefresh: () => _reloadAll(force: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summary(),
            const SizedBox(height: 12),
            _filters(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEDE9FE)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _reloadAll(force: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else
              _list(),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}
