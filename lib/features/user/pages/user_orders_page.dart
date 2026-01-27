import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../models/user_order_model.dart';
import '../../data/user_orders_service.dart';

class UserOrdersPage extends StatefulWidget {
  const UserOrdersPage({super.key});

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  bool _loading = true;
  String? _error;
  List<UserOrderModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await UserOrdersService.fetchMyOrders();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  // ✅ Haversine (meter)
  double? _haversineMeters(UserOrderModel o) {
    final aLat = o.buyerLat;
    final aLng = o.buyerLng;
    final bLat = o.sellerLat;
    final bLng = o.sellerLng;

    if (aLat == null || aLng == null || bLat == null || bLng == null) {
      return null;
    }

    const R = 6371000.0;
    final dLat = _deg2rad(bLat - aLat);
    final dLon = _deg2rad(bLng - aLng);

    final x =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(aLat)) *
            math.cos(_deg2rad(bLat)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return R * c;
  }

  double _deg2rad(double d) => d * (math.pi / 180);

  String _fmtDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  Color _statusColor(String s) {
    final st = s.toLowerCase().trim();
    if (st == 'selesai') return Colors.green;
    if (st == 'dikirim') return Colors.blue;
    if (st == 'membayar') return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
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
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 140),
                        Center(
                          child: Text(
                            'Belum ada pesanan.',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final o = _items[i];
                        final dist = _haversineMeters(o);
                        final stColor = _statusColor(o.status);

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Order #${o.orderId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: stColor.withOpacity(0.12),
                                    ),
                                    child: Text(
                                      o.status.toLowerCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: stColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (o.namaToko ?? '').trim().isEmpty
                                    ? 'Toko: -'
                                    : 'Toko: ${o.namaToko}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Total: ${_formatRupiah(o.totalAmount)} • Ongkir: ${_formatRupiah(o.ongkir)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Kurir: ${(o.kurir ?? '-')} • Metode: ${o.metodePembayaran}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                o.alamatPengiriman.trim().isEmpty
                                    ? 'Alamat: (belum ada)'
                                    : 'Alamat: ${o.alamatPengiriman}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                (o.buyerLat != null && o.buyerLng != null)
                                    ? 'Koordinat Buyer: ${o.buyerLat}, ${o.buyerLng}'
                                    : 'Koordinat Buyer: (tidak ada)',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dist == null
                                    ? 'Jarak ke Penjual: (lokasi penjual/buyer belum tersedia)'
                                    : 'Jarak ke Penjual: ${_fmtDistance(dist)} (Haversine)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF6D28D9),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (o.createdAt.trim().isNotEmpty)
                                Text(
                                  'Dibuat: ${o.createdAt}',
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w700,
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
