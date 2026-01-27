import 'package:flutter/material.dart';
import '../../data/courier_tasks_store.dart';
import 'courier_task_detail_page.dart';

class CourierHomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const CourierHomePage({super.key, required this.user});

  @override
  State<CourierHomePage> createState() => _CourierHomePageState();
}

class _CourierHomePageState extends State<CourierHomePage>
    with WidgetsBindingObserver {
  final store = CourierTasksStore.I;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.load(); // throttle internal => aman
    }
  }

  String _name() => (widget.user['name'] ?? '-').toString();

  String _statusLabel(String s) {
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

  Future<void> _openDetail(int orderId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierTaskDetailPage(orderId: orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        final items = store.items;
        final loading = store.loading;
        final error = store.error;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F3FF),
          appBar: AppBar(
            title: const Text('Kurir'),
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6D28D9),
                    Color(0xFF9333EA),
                    Color(0xFFA855F7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => store.load(force: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: (loading && items.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : (error != null && items.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 44),
                        const SizedBox(height: 10),
                        Text(
                          'Gagal memuat tugas kurir\n$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => store.load(force: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => store.load(force: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Card(
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              child: Icon(Icons.local_shipping_rounded),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Halo, ${_name()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Ini daftar tugas pengiriman kamu.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tugas aktif: ${items.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        const _EmptyState()
                      else
                        ...items.map((s) {
                          return _Card(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Shipment #${s.shipmentId} • Order #${s.orderId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _Pill(text: _statusLabel(s.status)),
                                    _Pill(text: 'Kurir: ${s.courier ?? '-'}'),
                                    if ((s.trackingNumber ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      _Pill(text: 'Resi: ${s.trackingNumber}'),
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _openDetail(s.orderId),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          'Belum ada tugas pengiriman.',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
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
