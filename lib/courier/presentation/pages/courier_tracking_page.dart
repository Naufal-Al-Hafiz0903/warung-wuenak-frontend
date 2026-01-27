import 'package:flutter/material.dart';

import '../../data/courier_shipments_service.dart';
import '../../../models/shipment_tracking_model.dart';
import 'courier_tracking_detail_page.dart';

class CourierTrackingPage extends StatefulWidget {
  const CourierTrackingPage({super.key});

  @override
  State<CourierTrackingPage> createState() => _CourierTrackingPageState();
}

class _CourierTrackingPageState extends State<CourierTrackingPage> {
  bool _loading = true;
  String? _error;
  List<ShipmentTrackingModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await CourierShipmentsService.fetchMyTasks();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat tracking: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String st) {
    st = st.toLowerCase().trim();
    if (st == 'selesai') return Colors.green;
    if (st == 'dibatalkan') return Colors.red;
    if (st == 'dalam_perjalanan') return Colors.orange;
    if (st == 'dikirim') return Colors.indigo;
    return const Color(0xFF6D28D9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Tracking Kurir'),
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : (_error != null)
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
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
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : (_items.isEmpty)
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  _Card(
                    child: Text(
                      'Belum ada shipment aktif untuk kurir ini.',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final it = _items[i];
                  final st = it.status.toLowerCase().trim();
                  final col = _statusColor(st);

                  return InkWell(
                    onTap: () async {
                      final r = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CourierTrackingDetailPage(orderId: it.orderId),
                        ),
                      );
                      // optional: refresh kalau detail melakukan update status
                      if (r is Map && r['refresh'] == true) {
                        _snack('Memperbarui daftar...');
                        _load();
                      }
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: _Card(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: col.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: col.withOpacity(0.25)),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              color: col,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #${it.orderId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _Pill(text: 'Status: $st'),
                                    if ((it.courier ?? '').trim().isNotEmpty)
                                      _Pill(text: 'Kurir: ${it.courier}'),
                                    if ((it.trackingNumber ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      _Pill(text: 'Resi: ${it.trackingNumber}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  );
                },
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

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6D28D9),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
