import 'package:flutter/material.dart';

import '../../data/courier_shipments_service.dart';
import 'courier_maps_page.dart';

class CourierTrackingDetailPage extends StatefulWidget {
  final int orderId;
  const CourierTrackingDetailPage({super.key, required this.orderId});

  @override
  State<CourierTrackingDetailPage> createState() =>
      _CourierTrackingDetailPageState();
}

class _CourierTrackingDetailPageState extends State<CourierTrackingDetailPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final d = await CourierShipmentsService.fetchTaskDetailRawByOrder(
        widget.orderId,
      );
      if (d == null) {
        setState(() {
          _data = null;
          _events = const [];
          _error = 'Detail shipment tidak ditemukan untuk order ini.';
        });
        return;
      }

      final ev = d['events'] ?? d['history'] ?? d['timeline'];
      final list = (ev is List)
          ? ev.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _data = d;
        _events = list;
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat detail: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _buyerMap() {
    final b = _data?['buyer'];
    if (b is Map) return Map<String, dynamic>.from(b); // ✅ no cast
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v); // ✅ no cast
    return null;
  }

  String? _pickString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  double? _pickDouble(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final d = double.tryParse('$v');
      if (d != null) return d;
    }
    return null;
  }

  void _openMap() {
    final d = _data;
    if (d == null) return;

    final buyer = _buyerMap() ?? {};

    // ✅ FIX: buyerName harus dihitung DI SINI (bukan ambil dari build())
    final buyerNameValue =
        _pickString(buyer, ['name', 'nama', 'nama_lengkap']) ?? '-';

    final address =
        _pickString(d, [
          'alamat_pengiriman',
          'alamat',
          'alamat_user',
          'alamatUser',
        ]) ??
        _pickString(buyer, ['alamat_user', 'alamatUser', 'alamat']) ??
        '';

    final lat = _pickDouble(d, [
      'buyer_lat',
      'dest_lat',
      'destination_lat',
      'latitude',
    ]);
    final lng = _pickDouble(d, [
      'buyer_lng',
      'dest_lng',
      'destination_lng',
      'longitude',
    ]);

    // ✅ Pickup (Toko)
    final tokoMap = _asMap(d['toko']);
    final pickupLat =
        _pickDouble(d, [
          'pickup_lat',
          'toko_lat',
          'store_lat',
          'origin_lat',
          'seller_lat',
          'shop_lat',
        ]) ??
        (tokoMap != null
            ? _pickDouble(tokoMap, [
                'lat',
                'toko_lat',
                'store_lat',
                'origin_lat',
              ])
            : null);

    final pickupLng =
        _pickDouble(d, [
          'pickup_lng',
          'toko_lng',
          'store_lng',
          'origin_lng',
          'seller_lng',
          'shop_lng',
        ]) ??
        (tokoMap != null
            ? _pickDouble(tokoMap, [
                'lng',
                'toko_lng',
                'store_lng',
                'origin_lng',
              ])
            : null);

    final pickupName =
        _pickString(d, [
          'pickup_name',
          'toko_name',
          'nama_toko',
          'store_name',
          'shop_name',
        ]) ??
        (tokoMap != null
            ? _pickString(tokoMap, [
                'name',
                'nama',
                'toko_name',
                'nama_toko',
                'store_name',
              ])
            : null);

    final pickupAddress =
        _pickString(d, [
          'pickup_address',
          'toko_address',
          'alamat_toko',
          'store_address',
          'shop_address',
          'origin_address',
        ]) ??
        (tokoMap != null
            ? _pickString(tokoMap, [
                'address',
                'alamat',
                'alamat_toko',
                'toko_address',
              ])
            : null);

    if (address.trim().isEmpty && (lat == null || lng == null)) {
      _snack('Alamat/koordinat tujuan belum tersedia dari server.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierMapsPage(
          title: 'Rute Pengantaran',
          orderId: widget.orderId,
          buyerName: buyerNameValue, // ✅ FIXED
          buyerAddress: address.trim().isEmpty ? null : address,
          buyerLat: lat,
          buyerLng: lng,
          pickupName: pickupName,
          pickupAddress: pickupAddress,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? {};
    final buyer = _buyerMap() ?? {};

    final status = (d['status'] ?? 'diproses').toString().toLowerCase().trim();
    final courier = (d['kurir'] ?? d['courier'] ?? '-').toString();
    final resi = (d['nomor_resi'] ?? d['tracking_number'] ?? '-').toString();

    final buyerName =
        _pickString(buyer, ['name', 'nama', 'nama_lengkap']) ?? '-';
    final buyerAddr =
        _pickString(d, [
          'alamat_pengiriman',
          'alamat',
          'alamat_user',
          'alamatUser',
        ]) ??
        _pickString(buyer, ['alamat_user', 'alamatUser', 'alamat']) ??
        '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text('Tracking Order #${widget.orderId}'),
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
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: $status',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(text: 'Kurir: $courier'),
                          if (resi.trim().isNotEmpty && resi != '-')
                            _Pill(text: 'Resi: $resi'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tujuan',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      _RowInfo(label: 'Pembeli', value: buyerName),
                      const SizedBox(height: 6),
                      _RowInfo(
                        label: 'Alamat',
                        value: buyerAddr.trim().isEmpty
                            ? 'Belum tersedia'
                            : buyerAddr,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openMap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D28D9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.map_rounded),
                          label: const Text(
                            'Buka Peta',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riwayat',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      if (_events.isEmpty)
                        const Text(
                          'Belum ada event.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        ..._events.map((e) {
                          final st = (e['status'] ?? '').toString();
                          final desc = (e['description'] ?? e['desc'] ?? '')
                              .toString();
                          final loc = (e['location'] ?? '').toString();
                          final at = (e['created_at'] ?? e['createdAt'] ?? '')
                              .toString();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE9D5FF),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    st,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (desc.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  if (loc.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Lokasi: $loc',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                  if (at.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      at,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, {'refresh': true}),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Kembali'),
                ),
              ],
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

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  const _RowInfo({required this.label, required this.value});
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
