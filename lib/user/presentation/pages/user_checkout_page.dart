import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/device_location_service.dart';
import '../../../services/user_http.dart';

class UserCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> user;

  /// prefill dari halaman produk (opsional)
  final String? prefillKurir;

  const UserCheckoutPage({super.key, required this.user, this.prefillKurir});

  @override
  State<UserCheckoutPage> createState() => _UserCheckoutPageState();
}

class _UserCheckoutPageState extends State<UserCheckoutPage> {
  bool _busy = false;
  String? _error;

  // ✅ HANYA 3 kurir
  static const List<_CourierOption> _couriers = [
    _CourierOption(
      key: 'kurirku',
      title: 'KurirKu',
      subtitle: 'Kurir internal / toko',
      icon: Icons.storefront_outlined,
    ),
    _CourierOption(
      key: 'gosend',
      title: 'GoSend',
      subtitle: 'Pengiriman cepat',
      icon: Icons.local_shipping_outlined,
    ),
    _CourierOption(
      key: 'grabexpress',
      title: 'GrabExpress',
      subtitle: 'Kurir instan',
      icon: Icons.flash_on_outlined,
    ),
  ];

  late String _selectedKurir;

  // input user
  final _alamatCtrl = TextEditingController(text: '');
  final _ongkirCtrl = TextEditingController(text: '16000');

  String _metode = 'cash'; // cash|transfer|qris (sesuaikan)

  @override
  void initState() {
    super.initState();
    final pre = (widget.prefillKurir ?? '').trim().toLowerCase();
    final exists = _couriers.any((c) => c.key == pre);
    _selectedKurir = exists ? pre : _couriers.first.key;
  }

  @override
  void dispose() {
    _alamatCtrl.dispose();
    _ongkirCtrl.dispose();
    super.dispose();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  int _toInt(String s, [int def = 0]) {
    final x = s.trim();
    return int.tryParse(x) ?? def;
  }

  Future<void> _checkout() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final alamat = _alamatCtrl.text.trim();
      if (alamat.isEmpty) {
        setState(() => _error = 'Alamat pengiriman wajib diisi');
        return;
      }

      final ongkir = _toInt(_ongkirCtrl.text, 0);
      if (ongkir < 0) {
        setState(() => _error = 'Ongkir tidak valid');
        return;
      }

      // 1) ambil lokasi real-time device (GPS)
      final Position pos = await DeviceLocationService.getCurrentHighAccuracy();

      // 2) update lokasi user -> /me/location
      final locRes = await UserHttp.postJson('me/location', {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy_m': pos.accuracy.round(),
      });

      // kalau throttled / ok false, tetap lanjut (biar user tidak stuck)
      if (locRes['ok'] != true) {
        _snack(
          'Lokasi gagal dikirim (tetap lanjut): ${locRes['message'] ?? ''}',
        );
      }

      // 3) checkout order -> /orders/checkout
      // 3) checkout order -> /orders/checkout-from-cart
      final orderRes = await UserHttp.postJson('orders/checkout-from-cart', {
        'metode_pembayaran': _metode,
        'kurir': _selectedKurir,
        'ongkir': ongkir,
        'alamat_pengiriman': alamat,
        'buyer_lat': pos.latitude,
        'buyer_lng': pos.longitude,
        'accuracy_m': pos.accuracy.round(),
      });

      if (orderRes['ok'] == true) {
        _snack('Checkout berhasil');
        if (!mounted) return;

        Navigator.pop(context, {
          'checkout_ok': true,
          'kurir': _selectedKurir,
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
        return;
      }

      setState(
        () => _error = (orderRes['message'] ?? 'Checkout gagal').toString(),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _couriers.firstWhere((c) => c.key == _selectedKurir);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Checkout'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Konfirmasi Checkout',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aplikasi akan mengambil lokasi GPS terbaru dan mengirimkannya ke server sebelum membuat order.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),

                // Alamat
                const Text(
                  'Alamat Pengiriman',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _alamatCtrl,
                  enabled: !_busy,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'Contoh: Jalan Ahmad No 10, RT 02/RW 01',
                  ),
                ),

                const SizedBox(height: 12),

                // Metode pembayaran (sederhana)
                const Text(
                  'Metode Pembayaran',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChipChoice(
                      selected: _metode == 'cash',
                      text: 'CASH',
                      onTap: _busy
                          ? null
                          : () => setState(() => _metode = 'cash'),
                    ),
                    _ChipChoice(
                      selected: _metode == 'transfer',
                      text: 'TRANSFER',
                      onTap: _busy
                          ? null
                          : () => setState(() => _metode = 'transfer'),
                    ),
                    _ChipChoice(
                      selected: _metode == 'qris',
                      text: 'QRIS',
                      onTap: _busy
                          ? null
                          : () => setState(() => _metode = 'qris'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Ongkir
                const Text(
                  'Ongkir',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ongkirCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.payments_outlined),
                    hintText: 'contoh: 16000',
                  ),
                ),

                const SizedBox(height: 14),

                // Pilih Kurir (hanya 3)
                const Text(
                  'Pilih Kurir',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ..._couriers.map((c) {
                  final isSel = c.key == _selectedKurir;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () => setState(() => _selectedKurir = c.key),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFF5F3FF) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFFD8B4FE)
                                : const Color(0xFFEDE9FE),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(c.icon, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.subtitle,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSel
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: const Color(0xFF6D28D9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _busy ? 'Memproses...' : 'Buat Pesanan',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                _MiniSummary(
                  kurir: selected.title,
                  metode: _metode.toUpperCase(),
                  ongkir: _ongkirCtrl.text.trim().isEmpty
                      ? '0'
                      : _ongkirCtrl.text.trim(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierOption {
  final String key; // yang dikirim ke server
  final String title;
  final String subtitle;
  final IconData icon;

  const _CourierOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
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

class _ChipChoice extends StatelessWidget {
  final bool selected;
  final String text;
  final VoidCallback? onTap;

  const _ChipChoice({
    required this.selected,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFE9D5FF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? const Color(0xFF6D28D9) : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

class _MiniSummary extends StatelessWidget {
  final String kurir;
  final String metode;
  final String ongkir;

  const _MiniSummary({
    required this.kurir,
    required this.metode,
    required this.ongkir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: Color(0xFF6D28D9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kurir: $kurir • Metode: $metode • Ongkir: Rp $ongkir',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF6D28D9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
