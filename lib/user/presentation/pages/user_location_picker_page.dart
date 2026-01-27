import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/me_service.dart';

class UserLocationPickerPage extends StatefulWidget {
  final LatLng? initial;

  const UserLocationPickerPage({super.key, this.initial});

  @override
  State<UserLocationPickerPage> createState() => _UserLocationPickerPageState();
}

class _UserLocationPickerPageState extends State<UserLocationPickerPage> {
  final MapController _map = MapController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  LatLng? _picked;
  LatLng? _gps;
  double? _accuracy;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _snack(String s, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _ensureLocationReady();

      // 1) coba ambil lokasi tersimpan dari server
      final loc = await MeService.fetchMyLocation();
      LatLng? serverLoc;
      if (loc != null && loc['lat'] != null && loc['lng'] != null) {
        serverLoc = LatLng(
          double.tryParse('${loc['lat']}') ?? 0,
          double.tryParse('${loc['lng']}') ?? 0,
        );
      }

      // 2) GPS current
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _gps = LatLng(p.latitude, p.longitude);
      _accuracy = p.accuracy;

      // 3) initial pin
      _picked = widget.initial ?? serverLoc ?? _gps;

      if (_picked != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _map.move(_picked!, 16);
        });
      }
    } catch (e) {
      _error = 'Gagal memuat lokasi: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final p = _picked;
    if (p == null) {
      _snack('Pilih titik lokasi dulu');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await MeService.updateMyLocation(
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: _accuracy?.round(),
      );

      if (!mounted) return;

      if (res == null) {
        _snack('Gagal menyimpan lokasi', bg: Colors.red);
        return;
      }

      final ok = res['ok'] == true;
      final throttled = res['throttled'] == true;
      final msg = (res['message'] ?? (ok ? 'Lokasi tersimpan' : 'Gagal'))
          .toString();

      _snack(
        throttled ? '$msg (dibatasi server)' : msg,
        bg: ok ? Colors.green : Colors.red,
      );

      if (ok) {
        Navigator.pop(context, {
          'lat': p.latitude,
          'lng': p.longitude,
          'updated_at': res['updated_at'],
          'throttled': throttled,
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = _picked;
    final gps = _gps;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Atur Lokasi'),
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
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: pin ?? const LatLng(-6.2, 106.816666),
                    initialZoom: 15,
                    onTap: (_, latlng) => setState(() => _picked = latlng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.warung_wuenak',
                    ),
                    MarkerLayer(
                      markers: [
                        if (gps != null)
                          Marker(
                            point: gps,
                            width: 44,
                            height: 44,
                            child: const _Pin(
                              color: Color(0xFF0EA5E9),
                              icon: Icons.my_location_rounded,
                              label: 'GPS',
                            ),
                          ),
                        if (pin != null)
                          Marker(
                            point: pin,
                            width: 56,
                            height: 56,
                            child: const _Pin(
                              color: Color(0xFF6D28D9),
                              icon: Icons.location_on_rounded,
                              label: 'LOKASI',
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
                          'Pilih titik lokasi pengiriman',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pin == null
                              ? 'Tap pada peta untuk memilih titik.'
                              : 'Lat: ${pin.latitude.toStringAsFixed(6)}\nLng: ${pin.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: (gps == null || _saving)
                                    ? null
                                    : () {
                                        setState(() => _picked = gps);
                                        _map.move(gps, 16);
                                      },
                                icon: const Icon(Icons.my_location_rounded),
                                label: const Text('Pakai GPS'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_circle_outline_rounded,
                                      ),
                                label: const Text(
                                  'Simpan',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
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
  final Color color;
  final IconData icon;
  final String label;

  const _Pin({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                blurRadius: 14,
                offset: Offset(0, 8),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
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
