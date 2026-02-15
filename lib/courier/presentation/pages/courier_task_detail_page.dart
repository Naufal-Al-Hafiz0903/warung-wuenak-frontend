import 'package:flutter/material.dart';
import '../../data/courier_shipments_service.dart';
import '../../data/courier_tasks_store.dart';
import 'courier_maps_page.dart';

class CourierTaskDetailPage extends StatefulWidget {
  final int orderId;
  const CourierTaskDetailPage({super.key, required this.orderId});

  @override
  State<CourierTaskDetailPage> createState() => _CourierTaskDetailPageState();
}

class _CourierTaskDetailPageState extends State<CourierTaskDetailPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;

  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _events = const [];

  final store = CourierTasksStore.I;

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
          _error = 'Data shipment tidak ditemukan untuk order ini.';
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

  String _status() =>
      (_data?['status'] ?? 'diproses').toString().toLowerCase().trim();

  bool _shouldRemove(String st) => st == 'selesai' || st == 'dibatalkan';

  bool _canUpdateTo(String next) {
    final st = _status();
    if (st == 'dibatalkan' || st == 'selesai') return false;

    if (next == 'dalam_perjalanan')
      return st == 'dikirim' || st == 'dikemas' || st == 'diproses';
    if (next == 'sampai') return st == 'dalam_perjalanan';
    if (next == 'selesai') return st == 'sampai';
    return true;
  }

  Future<void> _updateStatus(String next) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final res = await CourierShipmentsService.updateStatus(
        orderId: widget.orderId,
        status: next,
      );

      if (res['ok'] == true) {
        // ✅ kalau backend kirim data terbaru, pakai itu (hemat request)
        final data = res['data'];
        if (data is Map) {
          setState(() {
            _data = Map<String, dynamic>.from(data as Map);
            final ev = _data?['events'];
            if (ev is List) {
              _events = ev
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            }
          });
        } else {
          // fallback: update minimal local
          setState(() {
            _data ??= {};
            _data!['status'] = next;
          });
        }

        // ✅ update list di Home secara instan
        if (_shouldRemove(next)) {
          store.removeByOrderId(widget.orderId);
          _snack('Tugas selesai. Menghapus dari daftar...');
          if (!mounted) return;
          Navigator.pop(context);
          return;
        } else {
          store.updateStatus(
            widget.orderId,
            next,
            updatedAt: DateTime.now().toIso8601String(),
          );
        }

        _snack('Status diperbarui: $next');
      } else {
        _snack((res['message'] ?? 'Gagal update status').toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic>? _buyerMap() {
    final b = _data?['buyer'];
    if (b is Map) return Map<String, dynamic>.from(b as Map);
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

    // ✅ Pickup (Toko) — optional; jika ada, rute dimulai dari toko
    final tokoMap = (d['toko'] is Map)
        ? Map<String, dynamic>.from(d['toko'] as Map)
        : null;
    final pickupLat = _pickDouble(d, [
          'pickup_lat',
          'toko_lat',
          'store_lat',
          'origin_lat',
          'seller_lat',
          'shop_lat',
        ]) ??
        (tokoMap == null
            ? null
            : _pickDouble(tokoMap, ['lat', 'toko_lat', 'pickup_lat', 'store_lat']));

    final pickupLng = _pickDouble(d, [
          'pickup_lng',
          'toko_lng',
          'store_lng',
          'origin_lng',
          'seller_lng',
          'shop_lng',
        ]) ??
        (tokoMap == null
            ? null
            : _pickDouble(tokoMap, ['lng', 'toko_lng', 'pickup_lng', 'store_lng']));

    final pickupName = _pickString(d, [
          'pickup_name',
          'toko_name',
          'nama_toko',
          'store_name',
          'shop_name',
        ]) ??
        (tokoMap == null
            ? null
            : _pickString(tokoMap, ['name', 'nama', 'toko_name', 'nama_toko']));

    final pickupAddress = _pickString(d, [
          'pickup_address',
          'toko_address',
          'alamat_toko',
          'store_address',
          'shop_address',
        ]) ??
        (tokoMap == null
            ? null
            : _pickString(tokoMap, ['address', 'alamat', 'alamat_toko', 'toko_address']));

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
          buyerName: _pickString(buyer, ['name', 'nama']) ?? 'Pembeli',
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

    final shipmentId = (d['shipment_id'] ?? d['shipmentId'] ?? '-').toString();
    final status = (d['status'] ?? 'diproses').toString();
    final courier = (d['kurir'] ?? d['courier'] ?? '-').toString();
    final resi = (d['nomor_resi'] ?? d['tracking_number'] ?? '-').toString();

    final buyerName = _pickString(buyer, ['name', 'nama']) ?? '-';
    final buyerAddr =
        _pickString(d, [
          'alamat_pengiriman',
          'alamat',
          'alamat_user',
          'alamatUser',
        ]) ??
        _pickString(buyer, ['alamat_user', 'alamatUser', 'alamat']) ??
        '';

    // ✅ Pickup (Toko) — titik awal rute (sesuai requirement)
    final toko = (d['toko'] is Map)
        ? Map<String, dynamic>.from(d['toko'] as Map)
        : const <String, dynamic>{};

    final pickupName = _pickString(d, [
          'pickup_name',
          'pickupName',
          'toko_name',
          'tokoName',
        ]) ??
        _pickString(toko, [
          'name',
          'nama_toko',
          'nama',
          'toko_name',
          'tokoName',
        ]);

    final pickupAddr = _pickString(d, [
          'pickup_address',
          'pickupAddress',
          'alamat_toko',
          'alamatToko',
        ]) ??
        _pickString(toko, [
          'alamat',
          'alamat_toko',
          'alamatToko',
          'address',
        ]) ??
        '';

    final pickupLat = _pickDouble(d, [
          'pickup_lat',
          'pickupLat',
          'toko_lat',
          'tokoLat',
        ]) ??
        _pickDouble(toko, ['lat', 'latitude']);

    final pickupLng = _pickDouble(d, [
          'pickup_lng',
          'pickupLng',
          'toko_lng',
          'tokoLng',
        ]) ??
        _pickDouble(toko, ['lng', 'longitude']);

    final hasPickup =
        (pickupLat != null && pickupLng != null) ||
        (pickupAddr.trim().isNotEmpty) ||
        ((pickupName ?? '').trim().isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Detail Tugas'),
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
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
                        'Shipment #$shipmentId • Order #${widget.orderId}',
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
                          _Pill(text: 'Status: $status'),
                          _Pill(text: 'Kurir: $courier'),
                          if (resi.trim().isNotEmpty && resi != '-')
                            _Pill(text: 'Resi: $resi'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (hasPickup) ...[
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9).withOpacity(.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Pickup (Toko)',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _RowInfo(
                          label: 'Toko',
                          value: (pickupName == null || pickupName.trim().isEmpty)
                              ? 'Toko'
                              : pickupName,
                        ),
                        const SizedBox(height: 6),
                        _RowInfo(
                          label: 'Alamat',
                          value: pickupAddr.trim().isEmpty
                              ? 'Belum tersedia'
                              : pickupAddr,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D28D9).withOpacity(.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Tujuan (Pembeli)',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
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
                          onPressed: _busy ? null : _openMap,
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
                        'Aksi Cepat',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  (!_busy && _canUpdateTo('dalam_perjalanan'))
                                  ? () => _updateStatus('dalam_perjalanan')
                                  : null,
                              child: const Text(
                                'Mulai Antar',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (!_busy && _canUpdateTo('sampai'))
                                  ? () => _updateStatus('sampai')
                                  : null,
                              child: const Text(
                                'Sampai',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (!_busy && _canUpdateTo('selesai'))
                              ? () => _updateStatus('selesai')
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D28D9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Selesaikan',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ],
                  ),
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
