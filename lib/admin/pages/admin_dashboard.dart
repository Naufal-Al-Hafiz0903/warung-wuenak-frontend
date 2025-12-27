import 'package:flutter/material.dart';
import '../../services/admin_dashboard_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminDashboardService.fetchStats();
  }

  Future<void> _refresh() async {
    setState(() => _future = AdminDashboardService.fetchStats());
  }

  Widget _card(String title, dynamic value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(value.toString(), style: const TextStyle(fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 120),
                Text('Error: ${snap.error}'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Coba lagi'),
                ),
              ],
            );
          }

          final stats = snap.data ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card('Users', stats['users'] ?? 0, Icons.people),
              _card('Products', stats['products'] ?? 0, Icons.inventory_2),
              _card('Orders', stats['orders'] ?? 0, Icons.receipt_long),
              _card('Payments', stats['payments'] ?? 0, Icons.payments),
              const SizedBox(height: 10),
              const Text(
                'Catatan: angka dihitung dari endpoint list (users/products/orders/payments).',
              ),
            ],
          );
        },
      ),
    );
  }
}
