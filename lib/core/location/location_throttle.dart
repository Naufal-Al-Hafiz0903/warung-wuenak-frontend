import 'dart:math' as math;

class LocationThrottle {
  static bool shouldSend({
    required double lastLat,
    required double lastLng,
    required DateTime lastSentAt,
    required double newLat,
    required double newLng,
    required DateTime now,
    int minSeconds = 15,
    double minDistanceM = 20,
  }) {
    final dt = now.difference(lastSentAt).inSeconds;
    if (dt >= minSeconds) return true;

    final d = _haversineM(lastLat, lastLng, newLat, newLng);
    return d >= minDistanceM;
  }

  static double _haversineM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double d) => d * math.pi / 180.0;
}
