import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/user_tracking_poller.dart';

class UserTrackingPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final int orderId;

  const UserTrackingPage({
    super.key,
    required this.user,
    required this.orderId,
  });

  @override
  State<UserTrackingPage> createState() => _UserTrackingPageState();
}

class _UserTrackingPageState extends State<UserTrackingPage> {
  final MapController _map = MapController();

  UserTrackingPoller? _poller;

  String _status = '-';
  LatLng? _courier;
  LatLng? _buyer;

  String? _error;
  bool _fitOnce = false;

  @override
  void initState() {
    super.initState();

    _poller = UserTrackingPoller(
      orderId: widget.orderId,
      onLocation: (loc) {
        if (!mounted) return;
        if (loc == null) return;

        final lat = double.tryParse('${loc['lat']}');
        final lng = double.tryParse('${loc['lng']}');
        if (lat == null || lng == null) return;

        setState(() => _courier = LatLng(lat, lng));
        _tryFit();
      },
      onStatus: (st, shipment) {
        if (!mounted) return;
        setState(() {
          _status = st.isEmpty ? '-' : st;
          _error = null;
        });

        // buyer_lat/buyer_lng dari backend shipments/order/{id}
        if (shipment != null) {
          final blat = double.tryParse('${shipment['buyer_lat']}');
          final blng = double.tryParse('${shipment['buyer_lng']}');
          if (blat != null && blng != null) {
            setState(() => _buyer = LatLng(blat, blng));
            _tryFit();
          }
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

  void _tryFit() {
    if (_fitOnce) return;
    final a = _courier;
    final b = _buyer;
    if (a == null || b == null) return;

    _fitOnce = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sw = LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      );
      final ne = LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      );
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(sw, ne),
          padding: const EdgeInsets.all(44),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter:
                  _courier ?? _buyer ?? const LatLng(-6.2, 106.816666),
              initialZoom: 13,
            ),
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
                      width: 60,
                      height: 60,
                      child: const _Pin(
                        label: 'KURIR',
                        icon: Icons.delivery_dining_rounded,
                      ),
                    ),
                  if (_buyer != null)
                    Marker(
                      point: _buyer!,
                      width: 60,
                      height: 60,
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
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'Tracking hemat server: live-location dipoll adaptif, status dipoll lebih jarang.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
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
