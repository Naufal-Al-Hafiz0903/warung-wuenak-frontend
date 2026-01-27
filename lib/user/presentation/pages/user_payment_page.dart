import 'package:flutter/material.dart';

enum PaymentMethod { cash, transfer, qris }

class UserPaymentPage extends StatelessWidget {
  final int orderId;
  final PaymentMethod method;
  final double total;

  const UserPaymentPage({
    super.key,
    required this.orderId,
    required this.method,
    required this.total,
  });

  String _rupiah(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      c++;
      if (c % 3 == 0 && i != 0) buf.write('.');
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  String _title() {
    switch (method) {
      case PaymentMethod.cash:
        return 'Bayar Tunai';
      case PaymentMethod.transfer:
        return 'Transfer Bank';
      case PaymentMethod.qris:
        return 'QRIS';
    }
  }

  IconData _icon() {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.transfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.qris:
        return Icons.qr_code_2_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text(_title()),
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Icon(_icon(), color: const Color(0xFF6D28D9)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$orderId',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${_rupiah(total)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (method == PaymentMethod.cash) ...[
            _Card(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instruksi',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Bayar saat pesanan diterima.\nPastikan uang pas agar proses lebih cepat.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ] else if (method == PaymentMethod.transfer) ...[
            _Card(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rekening Tujuan',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 10),
                  _Row(label: 'Bank', value: 'BCA'),
                  SizedBox(height: 6),
                  _Row(label: 'No Rek', value: '1234567890'),
                  SizedBox(height: 6),
                  _Row(label: 'Nama', value: 'WARUNG WUENAK'),
                  SizedBox(height: 12),
                  Text(
                    'Setelah transfer, simpan bukti pembayaran.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ] else ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan QRIS',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 72,
                            color: Color(0xFF6D28D9),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'QR Placeholder',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Integrasi QR asli bisa menyusul',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gunakan aplikasi e-wallet / m-banking untuk scan.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, {'payment_done': true}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Selesai',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
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
