import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/network/api.dart';
import '../../../models/sales_point_model.dart';
import '../../../models/seller_product_sales_model.dart';
import '../../data/seller_dashboard_service.dart';
import '../layout/seller_layout.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  String _mode = 'daily'; // daily | weekly
  late Future<List<SalesPointModel>> _salesFuture;
  late Future<List<SellerProductSalesModel>> _productsSoldFuture;

  @override
  void initState() {
    super.initState();
    _salesFuture = SellerDashboardService.fetchMonthlySales(
      mode: _mode,
      days: 30,
    );
    _productsSoldFuture = SellerDashboardService.fetchProductsSold(
      days: 30,
      limit: 20,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _salesFuture = SellerDashboardService.fetchMonthlySales(
        mode: _mode,
        days: 30,
      );
      _productsSoldFuture = SellerDashboardService.fetchProductsSold(
        days: 30,
        limit: 20,
      );
    });
  }

  void _setMode(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _salesFuture = SellerDashboardService.fetchMonthlySales(
        mode: _mode,
        days: 30,
      );
    });
  }

  // =========================
  // Helpers UI
  // =========================
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

  String _resolveImageUrl(String? raw) {
    final r = (raw ?? '').trim();
    if (r.isEmpty) return '';
    if (r.startsWith('http://') || r.startsWith('https://')) return r;
    if (r.startsWith('/')) return '${Api.baseUrl}$r';
    return '${Api.baseUrl}/$r';
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipMode({
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active ? const Color(0xFF7C4DFF) : Colors.white,
          border: Border.all(
            color: active ? const Color(0xFF7C4DFF) : Colors.black12,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox({double? w, double? h, BorderRadius? r}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.black12.withOpacity(0.08),
        borderRadius: r ?? BorderRadius.circular(12),
      ),
    );
  }

  // =========================
  // Chart Widget (Grafik)
  // =========================
  Widget _salesChartCard() {
    return FutureBuilder<List<SalesPointModel>>(
      future: _salesFuture,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final data = snap.data ?? <SalesPointModel>[];

        // kerangka tetap tampil walau data kosong
        final points = (loading || data.isEmpty)
            ? List.generate(
                _mode == 'daily' ? 12 : 6,
                (_) => SalesPointModel(label: '', total: 0),
              )
            : data;

        final maxTotal = points.fold<double>(0, (m, e) => math.max(m, e.total));
        final totalMonth = data.fold<double>(0, (s, e) => s + e.total);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Rekap Penjualan (1 Bulan)",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _chipMode(
                    text: "Harian",
                    active: _mode == 'daily',
                    onTap: () => _setMode('daily'),
                  ),
                  const SizedBox(width: 8),
                  _chipMode(
                    text: "Mingguan",
                    active: _mode == 'weekly',
                    onTap: () => _setMode('weekly'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loading
                          ? "Memuat rekap..."
                          : (data.isEmpty
                                ? "Belum ada transaksi pada periode ini."
                                : "Total: ${_formatRupiah(totalMonth)}"),
                      style: TextStyle(
                        color: data.isEmpty ? Colors.black54 : Colors.black87,
                        fontWeight: data.isEmpty
                            ? FontWeight.w600
                            : FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chart area (scroll horizontal)
              SizedBox(
                height: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: Colors.black12.withOpacity(0.04),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(points.length, (i) {
                            final p = points[i];
                            final safeMax = (maxTotal <= 0) ? 1.0 : maxTotal;
                            final barH = (p.total <= 0)
                                ? 6.0
                                : (120.0 * (p.total / safeMax)).clamp(
                                    6.0,
                                    120.0,
                                  );

                            final showLabel = (!loading && data.isNotEmpty);

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: SizedBox(
                                width: _mode == 'daily' ? 18 : 28,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      width: double.infinity,
                                      height: barH,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        color: showLabel
                                            ? const Color(0xFF7C4DFF)
                                            : Colors.black12.withOpacity(0.18),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      showLabel ? p.label : "",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // Produk terjual (scroll horizontal)
  // =========================
  Widget _productSoldSection() {
    return FutureBuilder<List<SellerProductSalesModel>>(
      future: _productsSoldFuture,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final items = snap.data ?? <SellerProductSalesModel>[];

        // kerangka tetap tampil walau data kosong
        final showSkeleton = loading || items.isEmpty;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                "Produk & Jumlah Terjual",
                subtitle:
                    "Scroll ke samping untuk melihat produk (range 1 bulan).",
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 235,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: showSkeleton ? 6 : items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    if (showSkeleton) {
                      return Container(
                        width: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.black12.withOpacity(0.04),
                          border: Border.all(
                            color: Colors.black12.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _skeletonBox(
                              w: double.infinity,
                              h: 105,
                              r: BorderRadius.circular(14),
                            ),
                            const SizedBox(height: 10),
                            _skeletonBox(w: 120, h: 14),
                            const SizedBox(height: 8),
                            _skeletonBox(w: 90, h: 12),
                            const SizedBox(height: 8),
                            _skeletonBox(w: 80, h: 12),
                          ],
                        ),
                      );
                    }

                    final p = items[i];
                    final img = _resolveImageUrl(p.imageUrl);

                    return Container(
                      width: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.black12.withOpacity(0.10),
                        ),
                        boxShadow: const [
                          BoxShadow(blurRadius: 10, color: Colors.black12),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 105,
                              width: double.infinity,
                              color: Colors.black12.withOpacity(0.06),
                              child: img.isEmpty
                                  ? const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.black38,
                                      ),
                                    )
                                  : Image.network(
                                      img,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              color: Colors.black38,
                                            ),
                                          ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p.namaProduk,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
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
                            "Terjual: ${p.jumlahTerjual}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
      title: "Dashboard Penjual",
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // HANYA 2 BAGIAN INI (grafik + produk)
            _salesChartCard(),
            const SizedBox(height: 14),
            _productSoldSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
