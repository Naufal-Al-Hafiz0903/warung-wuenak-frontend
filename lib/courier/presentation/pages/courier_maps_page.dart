import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/courier_shipments_service.dart';

class CourierMapsPage extends StatefulWidget {
  final String title;
  final int orderId;

  final String buyerName;
  final String? buyerAddress;

  final double? buyerLat;
  final double? buyerLng;

  const CourierMapsPage({
    super.key,
    required this.title,
    required this.orderId,
    required this.buyerName,
    this.buyerAddress,
    this.buyerLat,
    this.buyerLng,
  });

  @override
  State<CourierMapsPage> createState() => _CourierMapsPageState();
}

class _CourierMapsPageState extends State<CourierMapsPage> {
  final MapController _mapController = MapController();

  bool _loading = true;
  String? _error;

  LatLng? _courierPos;
  LatLng? _buyerPos;

  StreamSubscription<Position>? _posSub;
  DateTime? _lastPushAt;
  LatLng? _lastPushPos;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _ensureLocationReady();

      final courier = await _getCurrentLocation();
      final buyer = await _resolveBuyerLocation();

      if (courier == null) {
        setState(() => _error = 'Lokasi kurir tidak tersedia.');
        return;
      }
      if (buyer == null) {
        setState(
          () => _error =
              'Lokasi tujuan tidak tersedia (alamat/koordinat kosong).',
        );
        return;
      }

      setState(() {
        _courierPos = courier;
        _buyerPos = buyer;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sw = LatLng(
          math.min(courier.latitude, buyer.latitude),
          math.min(courier.longitude, buyer.longitude),
        );
        final ne = LatLng(
          math.max(courier.latitude, buyer.latitude),
          math.max(courier.longitude, buyer.longitude),
        );
        final b = LatLngBounds(sw, ne);

        _mapController.fitCamera(
          CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(40)),
        );
      });

      // ✅ mulai live update (hemat: distanceFilter + interval + throttle)
      _startLiveUpdates();
    } catch (e) {
      setState(() => _error = 'Gagal memuat peta: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureLocationReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _snack('GPS tidak aktif. Silakan aktifkan Location.');
      await Geolocator.openLocationSettings();
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      _snack('Izin lokasi ditolak permanen. Buka settings untuk mengaktifkan.');
      await Geolocator.openAppSettings();
      throw Exception('Permission lokasi deniedForever');
    }

    if (perm == LocationPermission.denied) {
      throw Exception('Permission lokasi ditolak');
    }
  }

  Future<LatLng?> _getCurrentLocation() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _resolveBuyerLocation() async {
    // 1) backend kirim koordinat dari user_locations (paling hemat)
    if (widget.buyerLat != null && widget.buyerLng != null) {
      return LatLng(widget.buyerLat!, widget.buyerLng!);
    }

    // 2) fallback: geocode alamat (lebih berat)
    final addr = (widget.buyerAddress ?? '').trim();
    if (addr.isEmpty) return null;

    try {
      final list = await locationFromAddress(addr);
      if (list.isEmpty) return null;
      final first = list.first;
      return LatLng(first.latitude, first.longitude);
    } catch (_) {
      return null;
    }
  }

  void _startLiveUpdates() {
    _posSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // ✅ hanya update kalau pindah >= 20m
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen((
      pos,
    ) async {
      final newPos = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() => _courierPos = newPos);

      // throttle client: minimal 5 detik, atau jarak besar
      final now = DateTime.now();
      final lastAt = _lastPushAt;
      final lastPos = _lastPushPos;

      final dt = (lastAt == null) ? 9999 : now.difference(lastAt).inSeconds;
      final dist = (lastPos == null)
          ? 999999.0
          : Geolocator.distanceBetween(
              lastPos.latitude,
              lastPos.longitude,
              newPos.latitude,
              newPos.longitude,
            );

      if (dt < 5 && dist < 30) return; // ✅ hemat request

      _lastPushAt = now;
      _lastPushPos = newPos;

      final res = await CourierShipmentsService.pushLiveLocation(
        orderId: widget.orderId,
        lat: newPos.latitude,
        lng: newPos.longitude,
        accuracyM: pos.accuracy.round(),
      );

      // tidak usah spam snackbar kalau throttled
      if (res['ok'] != true) {
        // silent fail
      }
    }, onError: (_) {});
  }

  double? _distanceMeters() {
    final a = _courierPos;
    final b = _buyerPos;
    if (a == null || b == null) return null;

    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  String _fmtDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final courier = _courierPos;
    final buyer = _buyerPos;
    final dist = _distanceMeters();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text(widget.title),
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
            tooltip: 'Refresh lokasi',
            onPressed: _loading ? null : _init,
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
                    const Icon(Icons.location_off_rounded, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _init,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: courier ?? const LatLng(-6.2, 106.816666),
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.warungwuenak',
                    ),
                    if (courier != null && buyer != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(points: [courier, buyer], strokeWidth: 5),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (courier != null)
                          Marker(
                            point: courier,
                            width: 60,
                            height: 60,
                            child: const _Pin(
                              label: 'KURIR',
                              icon: Icons.delivery_dining_rounded,
                            ),
                          ),
                        if (buyer != null)
                          Marker(
                            point: buyer,
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
                        Text(
                          'Order #${widget.orderId}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tujuan: ${widget.buyerName}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if ((widget.buyerAddress ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.buyerAddress!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        if (dist != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                              ),
                            ),
                            child: Text(
                              'Jarak: ${_fmtDistance(dist)}',
                              style: const TextStyle(
                                color: Color(0xFF6D28D9),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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
