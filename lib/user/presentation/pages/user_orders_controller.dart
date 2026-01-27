import 'package:flutter/material.dart';
import '../../../../models/order_model.dart';
import '../../../../seller/data/order_service.dart';

class UserOrdersPage extends StatefulWidget {
  const UserOrdersPage({super.key});

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  bool loading = true;
  List<OrderModel> orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await OrderService.fetchMyOrders();
    if (!mounted) return;
    setState(() {
      orders = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pesanan Saya")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, i) {
                  final o = orders[i];
                  return Card(
                    child: ListTile(
                      title: Text("Order #${o.orderId}"),
                      subtitle: Text(
                        "Status: ${o.status} • Metode: ${o.metodePembayaran}",
                      ),
                      trailing: Text("Rp ${o.totalAmount.toStringAsFixed(0)}"),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
