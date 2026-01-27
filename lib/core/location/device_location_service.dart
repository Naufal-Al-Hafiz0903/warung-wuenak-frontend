import 'package:geolocator/geolocator.dart';

class DeviceLocationService {
  static Future<Position> getCurrentHighAccuracy() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('GPS tidak aktif. Aktifkan Location/GPS.');
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen. Aktifkan dari Settings.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }
}
