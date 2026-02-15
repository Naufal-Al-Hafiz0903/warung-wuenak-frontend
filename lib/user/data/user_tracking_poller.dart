import 'dart:async';
import '../../services/user_http.dart';

class UserTrackingPoller {
  final int orderId;

  Timer? _t;
  bool _running = false;

  int _intervalSec = 6;
  int _tickN = 0;

  int _statusEvery = 3;

  String? _lastLocUpdatedAt;
  int _stableLocTicks = 0;

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

    bool hadError = false;

    try {
      // 1) live location (paling sering)
      final locRes = await UserHttp.getJson(
        'shipments/live-location/order/$orderId',
      );

      if (locRes['ok'] == true) {
        final d = locRes['data'];
        if (d is Map) {
          final m = Map<String, dynamic>.from(d as Map);
          onLocation?.call(m);

          final upd = (m['updated_at'] ?? '').toString().trim();
          if (upd.isNotEmpty && upd == (_lastLocUpdatedAt ?? '')) {
            _stableLocTicks++;
          } else {
            _stableLocTicks = 0;
            _lastLocUpdatedAt = upd.isEmpty ? _lastLocUpdatedAt : upd;
          }
        }
      }

      // 2) status shipment (lebih jarang)
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

      // adaptive interval: stabil -> pelankan agar server tidak overload
      if (_stableLocTicks >= 6) {
        _intervalSec = 20;
      } else if (_stableLocTicks >= 3) {
        _intervalSec = 12;
      } else {
        _intervalSec = 6;
      }

      _statusEvery = (_intervalSec <= 6) ? 3 : 4;
    } catch (e) {
      hadError = true;
      onError?.call(e.toString());
      _intervalSec = 20;
      _statusEvery = 4;
    } finally {
      if (!hadError && !_running) return;
      _schedule(_intervalSec);
    }
  }
}
