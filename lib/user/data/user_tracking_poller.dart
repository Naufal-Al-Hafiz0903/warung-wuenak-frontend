import 'dart:async';
import '../../services/user_http.dart';

class UserTrackingPoller {
  final int orderId;

  Timer? _t;
  bool _running = false;

  int _intervalSec = 6; // start medium
  int _tickN = 0;

  // status check dibuat lebih jarang daripada live-location
  int _statusEvery = 3;

  final void Function(Map<String, dynamic>? liveLocation)? onLocation;
  final void Function(String status, Map<String, dynamic>? shipment)? onStatus;
  final void Function(String message)? onError;

  UserTrackingPoller({
    required this.orderId,
    this.onLocation,
    this.onStatus,
    this.onError,
  });

  void start() {
    if (_running) return;
    _running = true;
    _schedule(0);
  }

  void stop() {
    _running = false;
    _t?.cancel();
    _t = null;
  }

  void _schedule(int seconds) {
    if (!_running) return;
    _t?.cancel();
    _t = Timer(Duration(seconds: seconds), _tick);
  }

  Future<void> _tick() async {
    if (!_running) return;
    _tickN++;

    try {
      // ✅ 1) live location (paling sering)
      final locRes = await UserHttp.getJson(
        'shipments/live-location/order/$orderId',
      );
      if (locRes['ok'] == true) {
        final d = locRes['data'];
        if (d is Map) onLocation?.call(Map<String, dynamic>.from(d as Map));
      }

      // ✅ 2) status shipment (lebih jarang)
      if (_tickN % _statusEvery == 0) {
        final detRes = await UserHttp.getJson('shipments/order/$orderId');
        if (detRes['ok'] == true) {
          final data = detRes['data'];
          if (data is Map) {
            final m = Map<String, dynamic>.from(data as Map);
            final st = (m['status'] ?? '').toString().toLowerCase().trim();
            onStatus?.call(st, m);

            if (st == 'selesai' || st == 'dibatalkan') {
              stop();
              return;
            }
          }
        }
      }

      // adaptive interval: kalau sering update, 5-6 detik; kalau stabil, 12-20 detik
      if (_intervalSec < 20) {
        _intervalSec = (_tickN < 6) ? 6 : 12;
      }
      _statusEvery = (_intervalSec <= 6) ? 3 : 4;
    } catch (e) {
      onError?.call(e.toString());
      _intervalSec = 20; // kalau error, pelankan -> anti overload
      _statusEvery = 4;
    } finally {
      _schedule(_intervalSec);
    }
  }
}
