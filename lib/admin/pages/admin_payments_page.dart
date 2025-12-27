import 'package:flutter/material.dart';
import '../../models/payment_model.dart';
import '../../services/payment_service.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  late Future<List<PaymentModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = PaymentService.fetchPayments();
  }

  Future<void> _refresh() async {
    setState(() => _future = PaymentService.fetchPayments());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snap.data!;

        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: const [
                SizedBox(height: 140),
                Center(child: Text('Payment kosong / endpoint belum sesuai')),
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
              final p = items[i];
              final canConfirm = p.status.toLowerCase() == 'menunggu';

              return Card(
                child: ListTile(
                  title: Text('Payment #${p.paymentId} - ${p.status}'),
                  subtitle: Text(
                    'Order: ${p.orderId} | Metode: ${p.metode} | Paid: ${p.paidAt ?? "-"}',
                  ),
                  trailing: canConfirm
                      ? ElevatedButton(
                          onPressed: () async {
                            final ok = await PaymentService.confirmPayment(
                              p.paymentId,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Payment dikonfirmasi (dibayar)'
                                      : 'Gagal konfirmasi',
                                ),
                              ),
                            );
                            if (ok) _refresh();
                          },
                          child: const Text('Confirm'),
                        )
                      : const Icon(Icons.check_circle),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
