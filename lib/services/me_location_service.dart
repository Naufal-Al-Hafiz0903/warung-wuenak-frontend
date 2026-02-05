import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// sesuaikan path jika lokasi MeService berbeda di proyekmu
import '../user/data/me_service.dart';

class MeLocationResult {
  final bool ok;
  final String message;

  final double? lat;
  final double? lng;
  final int? accuracyM;

  /// ✅ tambahan agar login_page.dart tidak error
  final String? city;
  final double? areaKm2;
  final double? radiusMMax;

  final bool throttled;

  const MeLocationResult({
    required this.ok,
    required this.message,
    this.lat,
    this.lng,
    this.accuracyM,
    this.city,
    this.areaKm2,
    this.radiusMMax,
    this.throttled = false,
  });
}

class MeLocationService {
  static DateTime? _lastSentAt;
  static MeLocationResult? _lastGood;

  /// Interval throttle global (dipakai semua page/controller)
  static const Duration refreshInterval = Duration(minutes: 2);

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static String? _pickCityFrom(Map<String, dynamic> res) {
    // cek top-level
    final candidates = [
      res['city'],
      res['kota'],
      res['kabupaten'],
      res['kab_kota'],
      res['city_name'],
    ];

    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }

    // cek di res['data']
    final d = res['data'];
    if (d is Map) {
      final innerCandidates = [
        d['city'],
        d['kota'],
        d['kabupaten'],
        d['kab_kota'],
        d['city_name'],
      ];
      for (final c in innerCandidates) {
        final s = (c ?? '').toString().trim();
        if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
      }
    }
    return null;
  }

  static double? _pickAreaKm2From(Map<String, dynamic> res) {
    final candidates = [
      res['areaKm2'],
      res['area_km2'],
      res['area_km_2'],
      res['city_area_km2'],
    ];
    for (final c in candidates) {
      final v = _toDouble(c);
      if (v != null) return v;
    }
    final d = res['data'];
    if (d is Map) {
      final inner = [
        d['areaKm2'],
        d['area_km2'],
        d['area_km_2'],
        d['city_area_km2'],
      ];
      for (final c in inner) {
        final v = _toDouble(c);
        if (v != null) return v;
      }
    }
    return null;
  }

  static double? _pickRadiusMMaxFrom(Map<String, dynamic> res) {
    final candidates = [
      res['radiusMMax'],
      res['radius_m_max'],
      res['max_radius_m'],
      res['radius_max_m'],
    ];
    for (final c in candidates) {
      final v = _toDouble(c);
      if (v != null) return v;
    }
    final d = res['data'];
    if (d is Map) {
      final inner = [
        d['radiusMMax'],
        d['radius_m_max'],
        d['max_radius_m'],
        d['radius_max_m'],
      ];
      for (final c in inner) {
        final v = _toDouble(c);
        if (v != null) return v;
      }
    }
    return null;
  }

  /// Ambil GPS + kirim ke backend (/me/location via MeService.updateMyLocation)
  /// - force=true: abaikan throttle client
  static Future<MeLocationResult> captureAndSend({bool force = false}) async {
    final now = DateTime.now();

    // throttle client: kalau masih baru, kembalikan hasil terakhir (biar city/area/radius tetap ada)
    if (!force && _lastSentAt != null) {
      final age = now.difference(_lastSentAt!);
      if (age < refreshInterval) {
        final last = _lastGood;
        if (last != null) {
          return MeLocationResult(
            ok: true,
            message: 'Lokasi masih baru (throttled di client)',
            lat: last.lat,
            lng: last.lng,
            accuracyM: last.accuracyM,
            city: last.city,
            areaKm2: last.areaKm2,
            radiusMMax: last.radiusMMax,
            throttled: true,
          );
        }
        return const MeLocationResult(
          ok: true,
          message: 'Lokasi masih baru (throttled di client)',
          throttled: true,
        );
      }
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return const MeLocationResult(
          ok: false,
          message: 'GPS tidak aktif. Aktifkan Location lalu coba lagi.',
        );
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        return const MeLocationResult(
          ok: false,
          message:
              'Izin lokasi ditolak permanen. Buka Settings → Location Permission untuk mengaktifkan.',
        );
      }

      if (perm == LocationPermission.denied) {
        return const MeLocationResult(
          ok: false,
          message: 'Izin lokasi ditolak. Tidak bisa mengambil lokasi.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      final lat = pos.latitude;
      final lng = pos.longitude;
      final acc = pos.accuracy.round();

      final res = await MeService.updateMyLocation(
        lat: lat,
        lng: lng,
        accuracyM: acc,
      );

      final ok = res['ok'] == true;
      final throttled = res['throttled'] == true;
      final msg =
          (res['message'] ??
                  (ok ? 'Lokasi tersimpan' : 'Gagal mengirim lokasi'))
              .toString();

      final city = _pickCityFrom(res);
      final areaKm2 = _pickAreaKm2From(res);
      final radiusMMax = _pickRadiusMMaxFrom(res);

      if (kDebugMode) {
        debugPrint('[ME_LOCATION] ok=$ok throttled=$throttled msg=$msg');
        debugPrint('[ME_LOCATION] lat=$lat lng=$lng acc=$acc');
        debugPrint(
          '[ME_LOCATION] city=$city areaKm2=$areaKm2 radiusMMax=$radiusMMax',
        );
      }

      if (ok) _lastSentAt = now;

      final result = MeLocationResult(
        ok: ok,
        message: msg,
        lat: lat,
        lng: lng,
        accuracyM: acc,
        city: city,
        areaKm2: areaKm2,
        radiusMMax: radiusMMax,
        throttled: throttled,
      );

      if (ok) _lastGood = result;

      return result;
    } catch (e) {
      return MeLocationResult(ok: false, message: 'Gagal ambil lokasi: $e');
    }
  }

  static void resetThrottle() {
    _lastSentAt = null;
    _lastGood = null;
  }
}
