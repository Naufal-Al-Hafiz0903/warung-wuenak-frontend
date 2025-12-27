import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/order_service_admin.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  late Future<List<OrderModel>> _future;

  static const orderStatuses = ['menunggu', 'dibayar', 'dikirim', 'selesai'];

  @override
  void initState() {
    super.initState();
    _future = OrderServiceAdmin.fetchOrders();
  }

  Future<void> _refresh() async {
    setState(() => _future = OrderServiceAdmin.fetchOrders());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrderModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? [];
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: const [
                SizedBox(height: 140),
                Center(child: Text('Order kosong / endpoint belum sesuai')),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final o = items[i];

              final total = o.totalAmount;

              return Card(
                child: ListTile(
                  title: Text('Order #${o.orderId} - ${o.status}'),
                  subtitle: Text(
                    'User: ${o.userId} | Total: $total | Metode: ${o.metodePembayaran}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      final ok = await OrderServiceAdmin.updateStatus(
                        orderId: o.orderId,
                        status: v,
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'Status order diubah' : 'Gagal ubah status',
                          ),
                        ),
                      );

                      if (ok) {
                        await _refresh();
                      }
                    },
                    itemBuilder: (_) => orderStatuses
                        .map((s) => PopupMenuItem(value: s, child: Text(s)))
                        .toList(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
