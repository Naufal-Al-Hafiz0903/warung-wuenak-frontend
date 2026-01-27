import 'package:flutter/material.dart';
import '../../../models/shipment_tracking_model.dart';
import '../../data/tracking_service.dart';

class UserTrackingDetailPage extends StatefulWidget {
  final int orderId;
  const UserTrackingDetailPage({super.key, required this.orderId});

  @override
  State<UserTrackingDetailPage> createState() => _UserTrackingDetailPageState();
}

class _UserTrackingDetailPageState extends State<UserTrackingDetailPage> {
  bool _loading = true;
  String? _error;
  ShipmentTrackingModel? _data;

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
      final d = await TrackingService.fetchByOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _labelStatus(String s) {
    final x = s.toLowerCase().trim();
    switch (x) {
      case 'diproses':
        return 'Diproses';
      case 'dikemas':
        return 'Dikemas';
      case 'dikirim':
        return 'Dikirim';
      case 'dalam_perjalanan':
        return 'Dalam Perjalanan';
      case 'sampai':
        return 'Sampai';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Tracking Pesanan'),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 10),
                    Text(
                      'Gagal memuat tracking\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
            )
          : (d == null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 48),
                    const SizedBox(height: 10),
                    const Text('Data tracking belum tersedia'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Muat ulang'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${d.orderId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: ${_labelStatus(d.status)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        if ((d.courier ?? '').trim().isNotEmpty)
                          Text('Kurir: ${d.courier}'),
                        if ((d.trackingNumber ?? '').trim().isNotEmpty)
                          Text('Resi: ${d.trackingNumber}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Timeline',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (d.events.isEmpty)
                    const _Card(child: Text('Belum ada event tracking.'))
                  else
                    ...d.events.map(
                      (e) => _Card(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.fiber_manual_record,
                              size: 14,
                              color: Color(0xFF6D28D9),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _labelStatus(e.status),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if ((e.description ?? '').isNotEmpty)
                                    Text('${e.description}'),
                                  if ((e.location ?? '').isNotEmpty)
                                    Text('Lokasi: ${e.location}'),
                                  const SizedBox(height: 6),
                                  Text(
                                    e.createdAt,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
