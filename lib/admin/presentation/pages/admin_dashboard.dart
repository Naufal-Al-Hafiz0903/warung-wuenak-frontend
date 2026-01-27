import 'package:flutter/material.dart';

import '../../data/grafiadmin_dasboard_service.dart';
import '../../../models/toko_model.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;

  List<TokoModel> _tokos = [];
  int? _selectedTokoId;

  String _mode = 'daily'; // daily|weekly
  int _days = 30;

  List<AdminSalesPoint> _series = [];
  List<AdminTopProductSold> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tokos = await GrafiAdminDasboardService.fetchTokos(status: 'aktif');
      int? selected;

      if (tokos.isNotEmpty) {
        selected = tokos.first.tokoId;
      }

      setState(() {
        _tokos = tokos;
        _selectedTokoId = selected;
      });

      if (selected != null) {
        await _loadForToko(selected);
      } else {
        setState(() {
          _series = [];
          _topProducts = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadForToko(int tokoId) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        GrafiAdminDasboardService.fetchSalesSeries(
          tokoId: tokoId,
          mode: _mode,
          days: _days,
        ),
        GrafiAdminDasboardService.fetchTopProductsSold(
          tokoId: tokoId,
          days: _days,
          limit: 10,
        ),
      ]);

      setState(() {
        _series = futures[0] as List<AdminSalesPoint>;
        _topProducts = futures[1] as List<AdminTopProductSold>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final tid = _selectedTokoId;
    if (tid == null) {
      await _init();
      return;
    }
    await _loadForToko(tid);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dashboard Admin',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(
                icon: Icons.query_stats_rounded,
                text: _mode == 'weekly' ? 'Mingguan' : 'Harian',
              ),
              const SizedBox(width: 8),
              _Pill(icon: Icons.calendar_month_rounded, text: '$_days hari'),
            ],
          ),
          const SizedBox(height: 12),

          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<int>(
                  value: _selectedTokoId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih penjual (toko)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _tokos
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t.tokoId,
                          child: Text('${t.namaToko} (toko_id=${t.tokoId})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedTokoId = v);
                    await _loadForToko(v);
                  },
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Harian'),
                      selected: _mode == 'daily',
                      onSelected: (yes) async {
                        if (!yes) return;
                        setState(() => _mode = 'daily');
                        final tid = _selectedTokoId;
                        if (tid != null) await _loadForToko(tid);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Mingguan'),
                      selected: _mode == 'weekly',
                      onSelected: (yes) async {
                        if (!yes) return;
                        setState(() => _mode = 'weekly');
                        final tid = _selectedTokoId;
                        if (tid != null) await _loadForToko(tid);
                      },
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _days,
                      underline: const SizedBox(),
                      items: const [7, 14, 30, 31]
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d hari'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _days = v);
                        final tid = _selectedTokoId;
                        if (tid != null) await _loadForToko(tid);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (_loading) ...[
            const SizedBox(height: 60),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
          ] else if (_error != null) ...[
            _ErrorBox(error: _error!, onRetry: _refresh),
          ] else if (_selectedTokoId == null) ...[
            const _EmptyBox(
              title: 'Belum ada penjual/toko aktif',
              subtitle:
                  'Pastikan ada toko dengan status "aktif" supaya admin bisa memilih penjual.',
              icon: Icons.store_mall_directory_outlined,
            ),
          ] else ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grafik Penjualan',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sumber: /seller/dashboard/sales (filter status: dibayar/dikirim/selesai).',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: _series.isEmpty
                        ? const _EmptyChart()
                        : _LineChart(points: _series, axisColor: cs.primary),
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
                    'Produk Paling Banyak Terjual',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sumber: /seller/dashboard/products (berdasarkan toko terpilih).',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (_topProducts.isEmpty)
                    const _EmptyBox(
                      title: 'Belum ada data penjualan',
                      subtitle:
                          'Coba ubah range hari atau pastikan sudah ada order dibayar/dikirim/selesai.',
                      icon: Icons.shopping_bag_outlined,
                    )
                  else
                    Column(
                      children: _topProducts
                          .asMap()
                          .entries
                          .map((e) => _ProductRow(rank: e.key + 1, p: e.value))
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ],
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
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.primary,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gagal memuat dashboard',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyBox({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  const _EmptyBox._({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Data grafik kosong',
        style: TextStyle(
          color: Colors.black.withOpacity(.55),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final AdminTopProductSold p;

  const _ProductRow({required this.rank, required this.p});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 44,
              height: 44,
              child: (p.imageUrl == null || p.imageUrl!.trim().isEmpty)
                  ? Container(
                      color: Colors.black.withOpacity(.06),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.black45,
                      ),
                    )
                  : Image.network(
                      p.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black.withOpacity(.06),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.black45,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.namaProduk.isEmpty ? '(Tanpa nama)' : p.namaProduk,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Terjual: ${p.jumlahTerjual} • Harga: ${p.harga}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// Simple Line Chart (CustomPainter)
// =======================

class _LineChart extends StatelessWidget {
  final List<AdminSalesPoint> points;
  final Color axisColor;

  const _LineChart({required this.points, required this.axisColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(points: points, axisColor: axisColor),
      child: Container(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<AdminSalesPoint> points;
  final Color axisColor;

  _LineChartPainter({required this.points, required this.axisColor});

  @override
  void paint(Canvas canvas, Size size) {
    final padL = 34.0;
    final padR = 10.0;
    final padT = 12.0;
    final padB = 26.0;

    final w = size.width;
    final h = size.height;

    final chartW = (w - padL - padR).clamp(1, w);
    final chartH = (h - padT - padB).clamp(1, h);

    final maxV = points
        .map((e) => e.total)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final safeMax = (maxV <= 0) ? 1.0 : maxV;

    final axisPaint = Paint()
      ..color = axisColor.withOpacity(.30)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(padL, padT + chartH),
      Offset(padL + chartW, padT + chartH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + chartH), axisPaint);

    final gridPaint = Paint()
      ..color = axisColor.withOpacity(.12)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = padT + chartH * (i / 4.0);
      canvas.drawLine(Offset(padL, y), Offset(padL + chartW, y), gridPaint);
    }

    if (points.length <= 1) return;

    Offset toPoint(int i) {
      final x = padL + chartW * (i / (points.length - 1));
      final y = padT + chartH * (1 - (points[i].total / safeMax));
      return Offset(x, y);
    }

    final linePaint = Paint()
      ..color = axisColor.withOpacity(.85)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(toPoint(0).dx, toPoint(0).dy);
    for (int i = 1; i < points.length; i++) {
      final p = toPoint(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = axisColor.withOpacity(.95);
    for (int i = 0; i < points.length; i++) {
      final p = toPoint(i);
      canvas.drawCircle(p, 3.2, dotPaint);
    }

    final labelCount = points.length;
    final step = (labelCount / 6).ceil().clamp(1, labelCount);

    for (int i = 0; i < labelCount; i += step) {
      final p = toPoint(i);
      final text = points[i].label;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.black.withOpacity(.65),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 48);

      tp.paint(canvas, Offset(p.dx - tp.width / 2, padT + chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.axisColor != axisColor;
  }
}
