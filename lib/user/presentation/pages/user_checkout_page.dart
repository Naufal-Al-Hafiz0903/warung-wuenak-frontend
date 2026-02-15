import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/device_location_service.dart';
import '../../../services/user_http.dart';
import '../../data/checkout_service.dart';
import '../../../features/presentation/payment_page.dart';

class UserCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> user;

  final String? prefillKurir;

  const UserCheckoutPage({super.key, required this.user, this.prefillKurir});

  @override
  State<UserCheckoutPage> createState() => _UserCheckoutPageState();
}

class _UserCheckoutPageState extends State<UserCheckoutPage> {
  bool _busy = false;
  bool _quoteLoading = false;

  String? _error;
  String? _quoteError;

  double? _distanceKm;
  int? _distanceM;
  int? _ongkir;
  double? _maxDistanceKm;
  bool _withinRange = true;

  String? _areaLabel;
  String? _areaType;

  Position? _pos;

  static const List<_CourierOption> _couriers = [
    _CourierOption(
      key: 'kurirku',
      title: 'KurirKu',
      subtitle: 'Kurir internal / toko',
      badge: 'K',
    ),
    _CourierOption(
      key: 'gosend',
      title: 'GoSend',
      subtitle: 'Pengiriman cepat',
      badge: 'G',
    ),
    _CourierOption(
      key: 'grabexpress',
      title: 'GrabExpress',
      subtitle: 'Kurir instan',
      badge: 'GR',
    ),
  ];

  late String _selectedKurir;

  final _alamatCtrl = TextEditingController(text: '');
  final _ongkirCtrl = TextEditingController(text: '0');

  String _metode = 'cash'; // cash|transfer|qris

  @override
  void initState() {
    super.initState();
    final pre = (widget.prefillKurir ?? '').trim().toLowerCase();
    final exists = _couriers.any((c) => c.key == pre);
    _selectedKurir = exists ? pre : _couriers.first.key;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshQuote(forceGps: true),
    );
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

  int _toInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? def;
  }

  double _toDouble(dynamic v, [double def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? def;
  }

  Future<void> _refreshQuote({bool forceGps = false}) async {
    if (_quoteLoading) return;

    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });

    try {
      if (_pos == null || forceGps) {
        final Position p = await DeviceLocationService.getCurrentHighAccuracy();
        _pos = p;

        final locRes = await UserHttp.postJson('me/location', {
          'lat': p.latitude,
          'lng': p.longitude,
          'accuracy_m': p.accuracy.round(),
        });

        if (locRes['ok'] != true) {
          _snack(
            'Lokasi gagal dikirim (tetap lanjut): ${locRes['message'] ?? ''}',
          );
        }
      }

      final p = _pos!;
      final res = await CheckoutService.quoteOngkir(
        kurir: _selectedKurir,
        buyerLat: p.latitude,
        buyerLng: p.longitude,
        accuracyM: p.accuracy.round(),
      );

      if (res['ok'] != true) {
        setState(() {
          _quoteError = (res['message'] ?? 'Gagal ambil quote').toString();
        });
        return;
      }

      final data = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'])
          : <String, dynamic>{};

      final geo = (data['geo_limit'] is Map)
          ? Map<String, dynamic>.from(data['geo_limit'])
          : <String, dynamic>{};

      final distKm = _toDouble(data['distance_km'], 0);
      final distM = _toInt(data['distance_m'], 0);
      final ongkir = _toInt(data['ongkir'], 0);
      final maxKm = _toDouble(geo['max_distance_km'], 0);
      final within = (data['within_range'] == true);

      setState(() {
        _distanceKm = distKm;
        _distanceM = distM;
        _ongkir = ongkir;
        _maxDistanceKm = (maxKm > 0) ? maxKm : null;
        _withinRange = within;

        _areaLabel = (geo['area_label'] ?? '').toString().trim().isEmpty
            ? null
            : geo['area_label'].toString();
        _areaType = (geo['area_type'] ?? '').toString().trim().isEmpty
            ? null
            : geo['area_type'].toString();

        _ongkirCtrl.text = '$ongkir';
      });
    } catch (e) {
      setState(() => _quoteError = e.toString());
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
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

      if (_pos == null) {
        await _refreshQuote(forceGps: true);
      }

      if (_quoteError != null) {
        setState(() => _error = 'Quote ongkir gagal: $_quoteError');
        return;
      }

      if (_withinRange == false) {
        final mx = (_maxDistanceKm ?? 0);
        setState(() => _error =
            'Lokasi kamu di luar jangkauan pengiriman. Maksimal ${mx.toStringAsFixed(2)} km.');
        return;
      }

      final p = _pos!;
      final ongkirFinal = _ongkir ?? 0;

      final orderRes = await CheckoutService.checkoutFromCart(
        metodePembayaran: _metode,
        kurir: _selectedKurir,
        ongkir: ongkirFinal,
        alamatPengiriman: alamat,
        buyerLat: p.latitude,
        buyerLng: p.longitude,
        accuracyM: p.accuracy.round(),
      );

      if (orderRes['ok'] == true) {
        if (!mounted) return;

        final data = (orderRes['data'] is Map)
            ? Map<String, dynamic>.from(orderRes['data'])
            : <String, dynamic>{};

        final orderId = _toInt(data['order_id'], 0);
        final totalAmount = _toInt(data['total_amount'], 0);

        _snack('Checkout berhasil');

        if (_metode == 'cash') {
          Navigator.pop(context, {
            'checkout_ok': true,
            'kurir': _selectedKurir,
            'lat': p.latitude,
            'lng': p.longitude,
          });
          return;
        }

        final initialPay = (_metode == 'transfer') ? 'va_bca' : 'qris';

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPage(
              orderId: orderId,
              totalAmount: totalAmount,
              initialMethod: initialPay,
            ),
          ),
        );

        Navigator.pop(context, {
          'checkout_ok': true,
          'kurir': _selectedKurir,
          'lat': p.latitude,
          'lng': p.longitude,
        });
        return;
      }

      setState(() => _error = (orderRes['message'] ?? 'Checkout gagal').toString());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _couriers.firstWhere((c) => c.key == _selectedKurir);

    final distanceText = (_distanceKm == null)
        ? '-'
        : '${_distanceKm!.toStringAsFixed(2)} km (${_distanceM ?? 0} m)';

    final maxText = (_maxDistanceKm == null) ? '-' : '${_maxDistanceKm!.toStringAsFixed(2)} km';

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
        actions: [
          TextButton(
            onPressed: (_busy || _quoteLoading) ? null : () => _refreshQuote(forceGps: true),
            child: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
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
                  'Ongkir dihitung otomatis dari koordinat TOKO → koordinat KAMU (haversine). Batas jarak mengikuti wilayah kamu (maksimum seluas kota).',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'INFO',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jarak: $distanceText',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Batas maks: $maxText${_areaLabel != null ? " • ${_areaLabel!}" : ""}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                            if (_areaType != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Tipe area: $_areaType',
                                style: const TextStyle(color: Colors.black54, fontSize: 12),
                              ),
                            ],
                            if (_quoteLoading) ...[
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(minHeight: 4),
                            ],
                            if (_quoteError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _quoteError!,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                              ),
                            ],
                            if (_withinRange == false) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Lokasi kamu di luar jangkauan.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${(_ongkir ?? 0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                const Text('Alamat Pengiriman', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(
                  controller: _alamatCtrl,
                  enabled: !_busy,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Jalan Ahmad No 10, RT 02/RW 01',
                  ),
                ),

                const SizedBox(height: 12),

                const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChipChoice(
                      selected: _metode == 'cash',
                      text: 'CASH',
                      onTap: _busy ? null : () => setState(() => _metode = 'cash'),
                    ),
                    _ChipChoice(
                      selected: _metode == 'transfer',
                      text: 'TRANSFER (VA BCA)',
                      onTap: _busy ? null : () => setState(() => _metode = 'transfer'),
                    ),
                    _ChipChoice(
                      selected: _metode == 'qris',
                      text: 'QRIS (XENDIT)',
                      onTap: _busy ? null : () => setState(() => _metode = 'qris'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const Text('Ongkir (otomatis)', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(
                  controller: _ongkirCtrl,
                  enabled: false,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Otomatis dari sistem',
                  ),
                ),

                const SizedBox(height: 14),

                const Text('Pilih Kurir', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                ..._couriers.map((c) {
                  final isSel = c.key == _selectedKurir;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: (_busy || _quoteLoading)
                          ? null
                          : () async {
                              setState(() => _selectedKurir = c.key);
                              await _refreshQuote(forceGps: false);
                            },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFF5F3FF) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSel ? const Color(0xFFD8B4FE) : const Color(0xFFEDE9FE),
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
                              alignment: Alignment.center,
                              child: Text(
                                c.badge,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 2),
                                  Text(c.subtitle, style: const TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF6D28D9) : const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isSel ? 'Dipilih' : 'Pilih',
                                style: TextStyle(
                                  color: isSel ? Colors.white : const Color(0xFF6D28D9),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                  ),
                ],

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_busy || _quoteLoading || _withinRange == false) ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Buat Pesanan',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),

                const SizedBox(height: 10),
                _MiniSummary(
                  kurir: selected.title,
                  metode: _metode.toUpperCase(),
                  ongkir: (_ongkir ?? 0).toString(),
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
  final String key;
  final String title;
  final String subtitle;
  final String badge;

  const _CourierOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.badge,
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
      child: Text(
        'Kurir: $kurir • Metode: $metode • Ongkir: Rp $ongkir',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF6D28D9),
        ),
      ),
    );
  }
}
