import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../data/seller_orders_service.dart';
import '../layout/seller_layout.dart';
import 'seller_live_tracking_page.dart';

class SellerOrderDetailPage extends StatefulWidget {
  final int orderId;
  const SellerOrderDetailPage({super.key, required this.orderId});

  @override
  State<SellerOrderDetailPage> createState() => _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends State<SellerOrderDetailPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await SellerOrdersService.fetchDetail(widget.orderId);
      if (res['ok'] == true && res['data'] is Map) {
        setState(() {
          _data = Map<String, dynamic>.from(res['data'] as Map);
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = (res['message'] ?? 'Gagal memuat detail').toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat detail: $e';
        _loading = false;
      });
    }
  }

  String _rupiah(num v) {
    final n = v.round();
    final s = n.toString();
    final sb = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        sb.write('.');
        c = 0;
      }
    }
    return 'Rp ${sb.toString().split('').reversed.join()}';
  }

  Color _pillBg(String st) {
    st = st.toLowerCase().trim();
    if (st == 'menunggu') return const Color(0xFFFFF7ED);
    if (st == 'membayar') return const Color(0xFFF0F9FF);
    if (st == 'dikirim') return const Color(0xFFF5F3FF);
    if (st == 'selesai') return const Color(0xFFF0FDF4);
    return const Color(0xFFF8FAFC);
  }

  Color _pillFg(String st) {
    st = st.toLowerCase().trim();
    if (st == 'menunggu') return const Color(0xFF9A3412);
    if (st == 'membayar') return const Color(0xFF0369A1);
    if (st == 'dikirim') return const Color(0xFF6D28D9);
    if (st == 'selesai') return const Color(0xFF166534);
    return const Color(0xFF0F172A);
  }

  String _fmtDistance(dynamic km, dynamic m) {
    final kmD = (km is num) ? km.toDouble() : double.tryParse('$km');
    if (kmD != null && kmD > 0) {
      if (kmD < 1) {
        final mm = (m is num) ? m.toInt() : int.tryParse('$m');
        if (mm != null) return '${mm} m';
      }
      return '${kmD.toStringAsFixed(2)} km';
    }
    return '-';
  }

  String _resolveImageUrl(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '${AppConfig.baseUrl}$s';
    return '${AppConfig.baseUrl}/$s';
  }

  Widget _card({required Widget child}) {
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

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SellerLayout(
      title: 'Detail Order #${widget.orderId}',
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _card(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else
              ..._buildContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final data = _data ?? {};
    final order = (data['order'] is Map)
        ? Map<String, dynamic>.from(data['order'])
        : <String, dynamic>{};
    final toko = (data['toko'] is Map)
        ? Map<String, dynamic>.from(data['toko'])
        : <String, dynamic>{};
    final payment = (data['payment'] is Map)
        ? Map<String, dynamic>.from(data['payment'])
        : <String, dynamic>{};
    final shipment = (data['shipment'] is Map)
        ? Map<String, dynamic>.from(data['shipment'])
        : <String, dynamic>{};
    final items = (data['items'] is List)
        ? (data['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final status = (order['status'] ?? '').toString().toLowerCase().trim();
    final createdAt = (order['created_at'] ?? '').toString();
    final buyer = (order['pembeli'] ?? '-').toString();
    final alamat = (order['alamat_pengiriman'] ?? '-').toString();
    final metode = (order['metode_pembayaran'] ?? '-').toString();
    final total = double.tryParse('${order['total_amount'] ?? 0}') ?? 0;

    final sellerTotal = double.tryParse('${data['seller_total'] ?? 0}') ?? 0;

    final distText = _fmtDistance(data['distance_km'], data['distance_m']);

    final tokoNama = (toko['nama_toko'] ?? '-').toString();
    final tokoAlamat = (toko['alamat_toko'] ?? '-').toString();
    final tokoUpdated = (toko['location_updated_at'] ?? '').toString();

    final payStatus = (payment['status'] ?? '-').toString();
    final payMetode = (payment['metode'] ?? metode).toString();
    final paidAt = (payment['paid_at'] ?? '').toString();

    final shipStatus = (shipment['shipment_status'] ?? '-').toString();
    final shippedAt = (shipment['shipped_at'] ?? '').toString();
    final deliveredAt = (shipment['delivered_at'] ?? '').toString();

    final courierUserId = int.tryParse('${shipment['courier_user_id'] ?? ''}');
    final canTrack = courierUserId != null && courierUserId > 0;

    return [
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order #${order['order_id'] ?? widget.orderId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _pillBg(status),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFEDE9FE)),
                  ),
                  child: Text(
                    status.isEmpty ? '-' : status,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _pillFg(status),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              buyer,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              _rupiah(total),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF6D28D9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Metode: $metode'),
                if (createdAt.isNotEmpty) _pill('Tanggal: $createdAt'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Alamat: $alamat',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toko (Acuan Jarak)',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              tokoNama,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              tokoAlamat,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Jarak ke buyer: $distText'),
                if (tokoUpdated.isNotEmpty) _pill('Lokasi toko: $tokoUpdated'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan: jarak dihitung dari koordinat TOKO (toko.lat/lng) ke buyer_lat/buyer_lng.',
              style: TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pembayaran',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Status: $payStatus'),
                _pill('Metode: $payMetode'),
                if (paidAt.isNotEmpty) _pill('Paid at: $paidAt'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengiriman',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Status: $shipStatus'),
                if (shippedAt.isNotEmpty) _pill('Shipped: $shippedAt'),
                if (deliveredAt.isNotEmpty) _pill('Delivered: $deliveredAt'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (canTrack)
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Tracking Kurir',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lihat posisi kurir secara live pada peta. Lokasi akan muncul jika aplikasi kurir mengirim live location.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SellerLiveTrackingPage(orderId: widget.orderId),
                      ),
                    );
                  },
                  child: const Text('Buka Live Tracking'),
                ),
              ),
            ],
          ),
        )
      else
        _card(
          child: const Text(
            'Live tracking belum tersedia karena kurir belum ditugaskan pada shipment ini.',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      const SizedBox(height: 12),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Pesanan',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text(
                'Tidak ada item',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...items.map((it) {
                final nama = (it['nama_produk'] ?? '-').toString();
                final qty = int.tryParse('${it['quantity'] ?? 0}') ?? 0;
                final sub = double.tryParse('${it['subtotal'] ?? 0}') ?? 0;
                final img = _resolveImageUrl(it['image_url']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEDE9FE)),
                  ),
                  child: Row(
                    children: [
                      if (img.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            img,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 54,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFEDE9FE),
                                ),
                              ),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEDE9FE)),
                          ),
                          child: const Icon(Icons.photo_outlined),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nama,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Qty: $qty',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _rupiah(sub),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            const Divider(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal (toko ini)',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  _rupiah(sellerTotal),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
    ];
  }
}
