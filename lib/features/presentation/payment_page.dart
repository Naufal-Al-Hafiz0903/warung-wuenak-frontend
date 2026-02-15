import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:warung_wuenak/services/payment_service.dart';

class PaymentPage extends StatefulWidget {
  final int orderId;
  final int totalAmount;
  final String initialMethod;

  const PaymentPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
    this.initialMethod = 'qris',
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late String _selected;
  bool _loading = false;

  String _info = '';

  String _qrString = '';
  String _qrExp = '';

  String _vaNumber = '';
  String _vaExp = '';

  final TextEditingController _nameCtl = TextEditingController(
    text: 'WARUNGWUENAK',
  );

  @override
  void initState() {
    super.initState();
    final init = widget.initialMethod.trim().toLowerCase();
    _selected = (init == 'va_bca') ? 'va_bca' : 'qris';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tersalin ke clipboard')));
  }

  Future<void> _createPayment() async {
    setState(() {
      _loading = true;
      _info = '';
      _qrString = '';
      _qrExp = '';
      _vaNumber = '';
      _vaExp = '';
    });

    try {
      Map<String, dynamic> res;

      if (_selected == 'qris') {
        res = await PaymentService.createQrisXendit(
          orderId: widget.orderId,
          amount: widget.totalAmount,
        );

        if (res['ok'] == true && res['data'] is Map) {
          final data = Map<String, dynamic>.from(res['data']);
          _qrString = (data['qr_string'] ?? '').toString();
          _qrExp = (data['expires_at'] ?? '').toString();
          _info = (res['message'] ?? 'QRIS dibuat').toString();
        } else {
          _info = (res['message'] ?? 'Gagal membuat QRIS').toString();
        }
      } else {
        res = await PaymentService.createVaBcaXendit(
          orderId: widget.orderId,
          name: _nameCtl.text,
          expectedAmount: widget.totalAmount,
        );

        if (res['ok'] == true && res['data'] is Map) {
          final data = Map<String, dynamic>.from(res['data']);
          _vaNumber = (data['account_number'] ?? '').toString();
          _vaExp = (data['expiration_date'] ?? '').toString();
          _info = (res['message'] ?? 'VA BCA dibuat').toString();
        } else {
          _info = (res['message'] ?? 'Gagal membuat VA BCA').toString();
        }
      }
    } catch (e) {
      _info = 'Error: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _radio(String value, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _selected == value ? Colors.black : Colors.black12,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selected = value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? value),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultBox() {
    final lines = <Widget>[];

    if (_info.trim().isNotEmpty) {
      lines.add(
        Text(_info, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
      lines.add(const SizedBox(height: 10));
    }

    if (_selected == 'qris') {
      if (_qrString.trim().isNotEmpty) {
        lines.add(const Text('QRIS (Xendit):'));
        lines.add(const SizedBox(height: 10));

        lines.add(
          Center(child: QrImageView(data: _qrString, size: 220, gapless: true)),
        );

        lines.add(const SizedBox(height: 10));
        lines.add(const Text('QR String:'));
        lines.add(const SizedBox(height: 6));
        lines.add(SelectableText(_qrString));
        lines.add(const SizedBox(height: 8));
        lines.add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _copy(_qrString),
              child: const Text('Salin QR String'),
            ),
          ),
        );

        if (_qrExp.trim().isNotEmpty) {
          lines.add(const SizedBox(height: 6));
          lines.add(
            Text(
              'Berlaku sampai: $_qrExp',
              style: const TextStyle(color: Colors.black54),
            ),
          );
        }
      }
    } else {
      if (_vaNumber.trim().isNotEmpty) {
        lines.add(const Text('Virtual Account BCA (Xendit):'));
        lines.add(const SizedBox(height: 6));
        lines.add(
          SelectableText(
            _vaNumber,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        );
        lines.add(const SizedBox(height: 8));
        lines.add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _copy(_vaNumber),
              child: const Text('Salin VA'),
            ),
          ),
        );
      }
      if (_vaExp.trim().isNotEmpty) {
        lines.add(const SizedBox(height: 6));
        lines.add(
          Text(
            'Berlaku sampai: $_vaExp',
            style: const TextStyle(color: Colors.black54),
          ),
        );
      }
    }

    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withOpacity(0.03),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ID: ${widget.orderId}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: Rp ${widget.totalAmount}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),

            _radio(
              'qris',
              'QRIS (Xendit)',
              'Buat QRIS dinamis dari Xendit lalu tampilkan QR di halaman ini.',
            ),
            _radio(
              'va_bca',
              'Virtual Account BCA (Xendit)',
              'Buat nomor VA BCA untuk transfer. Nomor VA akan muncul di halaman ini.',
            ),

            if (_selected == 'va_bca') ...[
              const SizedBox(height: 6),
              const Text('Nama pemilik VA (opsional):'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Masukkan nama',
                ),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _createPayment,
                child: Text(_loading ? 'Memproses...' : 'Buat Pembayaran'),
              ),
            ),

            _resultBox(),
          ],
        ),
      ),
    );
  }
}
