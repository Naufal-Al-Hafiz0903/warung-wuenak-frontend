import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/seller_tracking_poller.dart';

class SellerLiveTrackingPage extends StatefulWidget {
  final int orderId;

  const SellerLiveTrackingPage({super.key, required this.orderId});

  @override
  State<SellerLiveTrackingPage> createState() => _SellerLiveTrackingPageState();
}

class _SellerLiveTrackingPageState extends State<SellerLiveTrackingPage> {
  final MapController _map = MapController();

  SellerTrackingPoller? _poller;

  String _status = '-';
  String _courierName = '-';
  String _lastUpdate = '-';

  LatLng? _courier;
  LatLng? _buyer;

  String? _error;
  bool _fitOnce = false;

  bool _isValidLatLng(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat.abs() > 90) return false;
    if (lng.abs() > 180) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();

    _poller = SellerTrackingPoller(
      orderId: widget.orderId,
      onLocation: (loc) {
        if (!mounted) return;
        if (loc == null) return;

        final lat = double.tryParse('${loc['lat']}');
        final lng = double.tryParse('${loc['lng']}');
        if (lat == null || lng == null) return;
        if (!_isValidLatLng(lat, lng)) return;

        setState(() {
          _courier = LatLng(lat, lng);
          _lastUpdate = (loc['updated_at'] ?? '-').toString();
        });

        _tryFitOrMoveSafe();
      },
      onStatus: (st, payload) {
        if (!mounted) return;

        setState(() {
          _status = st.isEmpty ? '-' : st;
          _error = null;
        });

        if (payload != null) {
          final courierName = (payload['courier_name'] ?? '-').toString();
          final blat = double.tryParse('${payload['buyer_lat']}');
          final blng = double.tryParse('${payload['buyer_lng']}');

          setState(() {
            _courierName = courierName.isEmpty ? '-' : courierName;
            if (blat != null && blng != null && _isValidLatLng(blat, blng)) {
              _buyer = LatLng(blat, blng);
            }
          });

          _tryFitOrMoveSafe();
        }
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() => _error = msg);
      },
    );

    _poller!.start();
  }

  @override
  void dispose() {
    _poller?.stop();
    super.dispose();
  }

  void _tryFitOrMoveSafe() {
    if (_fitOnce) return;

    final a = _courier;
    final b = _buyer;
    if (a == null || b == null) return;

    _fitOnce = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final distM = const Distance().as(LengthUnit.Meter, a, b);

      // Jika kurir dan tujuan sama/terlalu dekat, jangan fitCamera karena bisa menghasilkan zoom Infinity/NaN
      if (distM < 5) {
        try {
          _map.move(a, 16);
        } catch (_) {}
        return;
      }

      final sw = LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      );
      final ne = LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      );

      try {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(sw, ne),
            padding: const EdgeInsets.all(44),
          ),
        );
      } catch (_) {
        // Fallback aman jika fitCamera gagal
        try {
          _map.move(a, 15);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _courier ?? _buyer ?? const LatLng(-6.2, 106.816666);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text('Live Tracking Order #${widget.orderId}'),
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.warungwuenak',
              ),
              if (_courier != null && _buyer != null)
                PolylineLayer(
                  polylines: [
                    Polyline(points: [_courier!, _buyer!], strokeWidth: 5),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_courier != null)
                    Marker(
                      point: _courier!,
                      width: 78,
                      height: 92,
                      child: const _Pin(
                        label: 'KURIR',
                        icon: Icons.delivery_dining_rounded,
                      ),
                    ),
                  if (_buyer != null)
                    Marker(
                      point: _buyer!,
                      width: 78,
                      height: 92,
                      child: const _Pin(
                        label: 'TUJUAN',
                        icon: Icons.location_on_rounded,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Pengiriman',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _status,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6D28D9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kurir: $_courierName',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Update terakhir: $_lastUpdate',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (_courier == null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Lokasi kurir belum tersedia. Pastikan aplikasi kurir mengirim live location.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Pin({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF6D28D9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, 8),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFEDE9FE)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
