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

  // Pickup (Toko) agar titik pertama/rute dimulai dari toko
  final String? pickupName;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;

  const CourierMapsPage({
    super.key,
    required this.title,
    required this.orderId,
    required this.buyerName,
    this.buyerAddress,
    this.buyerLat,
    this.buyerLng,
    this.pickupName,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
  });

  @override
  State<CourierMapsPage> createState() => _CourierMapsPageState();
}

class _CourierMapsPageState extends State<CourierMapsPage> {
  final MapController _mapController = MapController();

  bool _loading = true;
  String? _error;

  LatLng? _courierPos;
  LatLng? _courierDisplayPos;
  LatLng? _buyerPos;
  LatLng? _pickupPos;

  StreamSubscription<Position>? _posSub;
  DateTime? _lastPushAt;
  LatLng? _lastPushPos;

  // Panel info bisa dibuka/tutup
  bool _infoOpen = true;

  // Tracking center/zoom agar tombol zoom kompatibel lintas versi flutter_map
  LatLng _mapCenter = const LatLng(-6.2, 106.816666);
  double _mapZoom = 13;

  static const double _minZoom = 3;
  static const double _maxZoom = 19;

  // Jejak tracking kurir (polyline)
  final List<LatLng> _trail = <LatLng>[];

  // Timer animasi perpindahan marker kurir
  Timer? _animTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _animTimer?.cancel();
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
      final pickup = await _resolvePickupLocation();

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
        _courierDisplayPos = courier;
        _buyerPos = buyer;
        _pickupPos = pickup;

        _mapCenter = courier;
        _mapZoom = 13;

        _trail
          ..clear()
          ..add(courier);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final points = <LatLng>[courier, buyer, if (pickup != null) pickup];

        double minLat = points.first.latitude;
        double maxLat = points.first.latitude;
        double minLng = points.first.longitude;
        double maxLng = points.first.longitude;

        for (final p in points) {
          minLat = math.min(minLat, p.latitude);
          maxLat = math.max(maxLat, p.latitude);
          minLng = math.min(minLng, p.longitude);
          maxLng = math.max(maxLng, p.longitude);
        }

        final dLat = (maxLat - minLat).abs();
        final dLng = (maxLng - minLng).abs();

        // Jika bounds terlalu kecil (titik sama), jangan fitCamera karena bisa menghasilkan zoom Infinity/NaN
        if (dLat < 1e-7 && dLng < 1e-7) {
          try {
            _mapController.move(points.first, 16);
          } catch (_) {}
          return;
        }

        final sw = LatLng(minLat, minLng);
        final ne = LatLng(maxLat, maxLng);
        final b = LatLngBounds(sw, ne);

        try {
          _mapController.fitCamera(
            CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(40)),
          );
        } catch (_) {
          try {
            _mapController.move(courier, 15);
          } catch (_) {}
        }
      });

      // Mulai live update (hemat: distanceFilter + throttle)
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
    if (widget.buyerLat != null && widget.buyerLng != null) {
      return LatLng(widget.buyerLat!, widget.buyerLng!);
    }

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

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    if (lat.abs() > 90) return false;
    if (lng.abs() > 180) return false;
    return true;
  }

  Future<LatLng?> _resolvePickupLocation() async {
    if (_isValidLatLng(widget.pickupLat, widget.pickupLng)) {
      return LatLng(widget.pickupLat!, widget.pickupLng!);
    }

    final addr = (widget.pickupAddress ?? '').trim();
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

  double _distM(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  void _addTrailPoint(LatLng p) {
    if (_trail.isEmpty) {
      _trail.add(p);
      return;
    }
    final last = _trail.last;
    if (_distM(last, p) >= 6) {
      _trail.add(p);
      if (_trail.length > 2000) {
        _trail.removeRange(0, _trail.length - 1500);
      }
    }
  }

  double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  void _animateCourierTo(LatLng target) {
    _animTimer?.cancel();

    final start = _courierDisplayPos ?? target;

    if (_distM(start, target) < 2) {
      _courierDisplayPos = target;
      if (mounted) setState(() {});
      return;
    }

    const total = Duration(milliseconds: 420);
    final startedAt = DateTime.now();

    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (tm) {
      final elapsed = DateTime.now().difference(startedAt);
      final tRaw = elapsed.inMilliseconds / total.inMilliseconds;
      final t = tRaw.clamp(0.0, 1.0);
      final e = _easeOutCubic(t);

      final lat = start.latitude + (target.latitude - start.latitude) * e;
      final lng = start.longitude + (target.longitude - start.longitude) * e;

      _courierDisplayPos = LatLng(lat, lng);

      if (mounted) setState(() {});
      if (t >= 1.0) {
        tm.cancel();
      }
    });
  }

  void _startLiveUpdates() {
    _posSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen((
      pos,
    ) async {
      final newPos = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;

      _courierPos = newPos;
      _animateCourierTo(newPos);
      _addTrailPoint(newPos);

      final now = DateTime.now();
      final lastAt = _lastPushAt;
      final lastPos = _lastPushPos;

      final dt = (lastAt == null) ? 9999 : now.difference(lastAt).inSeconds;
      final dist = (lastPos == null) ? 999999.0 : _distM(lastPos, newPos);

      if (dt < 5 && dist < 30) return;

      _lastPushAt = now;
      _lastPushPos = newPos;

      final res = await CourierShipmentsService.pushLiveLocation(
        orderId: widget.orderId,
        lat: newPos.latitude,
        lng: newPos.longitude,
        accuracyM: pos.accuracy.round(),
      );

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

  double? _distancePickupToBuyerMeters() {
    final a = _pickupPos;
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

  void _zoomBy(double delta) {
    final next = (_mapZoom + delta).clamp(_minZoom, _maxZoom).toDouble();
    _mapZoom = next;
    try {
      _mapController.move(_mapCenter, _mapZoom);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: const Color(0x22000000),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: const Color(0xFF6D28D9)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courierShown = _courierDisplayPos ?? _courierPos;
    final courierRaw = _courierPos;
    final buyer = _buyerPos;
    final pickup = _pickupPos;

    final distCourierToBuyer = _distanceMeters();
    final distPickupToBuyer = _distancePickupToBuyerMeters();

    final routePoints = (pickup != null && buyer != null)
        ? <LatLng>[pickup, buyer]
        : (courierRaw != null && buyer != null)
        ? <LatLng>[courierRaw, buyer]
        : const <LatLng>[];

    final infoChips = <Widget>[
      if (distCourierToBuyer != null)
        _Pill(
          label: 'Kurir → Pembeli',
          value: _fmtDistance(distCourierToBuyer),
        ),
      if (distPickupToBuyer != null)
        _Pill(label: 'Toko → Pembeli', value: _fmtDistance(distPickupToBuyer)),
    ];

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
                    initialCenter:
                        courierShown ?? const LatLng(-6.2, 106.816666),
                    initialZoom: 13,
                    onPositionChanged: (pos, _) {
                      final c = pos.center;
                      final z = pos.zoom;
                      if (c != null) _mapCenter = c;
                      if (z != null && z.isFinite) _mapZoom = z;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.warungwuenak',
                    ),
                    if (_trail.length >= 2)
                      PolylineLayer(
                        polylines: [Polyline(points: _trail, strokeWidth: 3)],
                      ),
                    if (routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(points: routePoints, strokeWidth: 5),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (pickup != null)
                          Marker(
                            point: pickup,
                            width: 78,
                            height: 92,
                            child: const _Pin(
                              label: 'PICKUP',
                              icon: Icons.storefront_rounded,
                            ),
                          ),
                        if (courierShown != null)
                          Marker(
                            point: courierShown,
                            width: 86,
                            height: 98,
                            child: const _CourierPin(
                              label: 'KURIR',
                              icon: Icons.delivery_dining_rounded,
                            ),
                          ),
                        if (buyer != null)
                          Marker(
                            point: buyer,
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
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      _mapButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom in',
                        onTap: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 10),
                      _mapButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom out',
                        onTap: () => _zoomBy(-1),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    firstCurve: Curves.easeOut,
                    secondCurve: Curves.easeIn,
                    sizeCurve: Curves.easeInOut,
                    crossFadeState: _infoOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: GestureDetector(
                      onTap: () => setState(() => _infoOpen = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
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
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9).withOpacity(.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.route_rounded,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Order #${widget.orderId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tracking aktif • Tap untuk buka detail',
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(.55),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Buka',
                              onPressed: () => setState(() => _infoOpen = true),
                              icon: const Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    secondChild: Container(
                      width: double.infinity,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${widget.orderId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Tutup',
                                onPressed: () =>
                                    setState(() => _infoOpen = false),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF6D28D9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tujuan: ${widget.buyerName}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if ((widget.buyerAddress ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.buyerAddress!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                          if (pickup != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Pickup (Toko): ${widget.pickupName ?? 'Toko'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if ((widget.pickupAddress ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.pickupAddress!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ],
                          if (infoChips.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: infoChips,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            'Jejak tracking: ${_trail.length} titik',
                            style: TextStyle(
                              color: Colors.black.withOpacity(.55),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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

class _CourierPin extends StatefulWidget {
  final String label;
  final IconData icon;
  const _CourierPin({required this.label, required this.icon});

  @override
  State<_CourierPin> createState() => _CourierPinState();
}

class _CourierPinState extends State<_CourierPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  final scale = 0.9 + (t * 0.9);
                  final opacity = (1 - t).clamp(0.0, 1.0);

                  return Opacity(
                    opacity: 0.35 * opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
                child: Icon(widget.icon, color: Colors.white),
              ),
            ],
          ),
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
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;

  const _Pill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFEDE9FE)),
            ),
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
