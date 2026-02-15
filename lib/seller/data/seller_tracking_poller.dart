import 'dart:async';
import 'package:flutter/foundation.dart';
import './seller_orders_service.dart';

class SellerTrackingPoller {
  final int orderId;

  final void Function(Map<String, dynamic>? liveLocation)? onLocation;
  final void Function(String status, Map<String, dynamic>? payload)? onStatus;
  final void Function(String message)? onError;

  Timer? _timer;
  bool _running = false;
  bool _inFlight = false;

  int _intervalSec = 3;
  int _stableTicks = 0;

  String? _lastStatus;
  String? _lastLiveUpdatedAt;

  SellerTrackingPoller({
    required this.orderId,
    this.onLocation,
    this.onStatus,
    this.onError,
  });

  void start() {
    if (_running) return;
    _running = true;

    _intervalSec = 3;
    _stableTicks = 0;
    _lastStatus = null;
    _lastLiveUpdatedAt = null;

    _schedule(0);
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule(int seconds) {
    if (!_running) return;
    _timer?.cancel();
    _timer = Timer(Duration(seconds: seconds), _tick);
  }

  Future<void> _tick() async {
    if (!_running) return;
    if (_inFlight) {
      _schedule(_intervalSec);
      return;
    }

    _inFlight = true;

    try {
      final res = await SellerOrdersService.fetchTracking(orderId);

      if (res['ok'] != true) {
        onError?.call((res['message'] ?? 'Gagal memuat tracking').toString());
        _intervalSec = 20;
        _stableTicks++;
        return;
      }

      final data = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'] as Map)
          : <String, dynamic>{};

      final status = (data['shipment_status'] ?? '-').toString();
      final st = status.toLowerCase().trim();

      final live = (data['live_location'] is Map)
          ? Map<String, dynamic>.from(data['live_location'] as Map)
          : null;

      final liveUpd = (live == null)
          ? null
          : (live['updated_at'] ?? '').toString().trim();

      final bool changed =
          (status != (_lastStatus ?? '')) ||
          ((liveUpd ?? '') != (_lastLiveUpdatedAt ?? ''));

      if (changed) {
        _stableTicks = 0;
        _intervalSec = 3;
        _lastStatus = status;
        _lastLiveUpdatedAt = liveUpd;
      } else {
        _stableTicks++;
        if (_stableTicks >= 6) {
          _intervalSec = 20;
        } else if (_stableTicks >= 3) {
          _intervalSec = 12;
        } else {
          _intervalSec = 6;
        }
      }

      onLocation?.call(live);
      onStatus?.call(status, data);

      if (st == 'selesai' || st == 'dibatalkan') {
        stop();
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SellerTrackingPoller error: $e');
      }
      onError?.call('Tracking error: $e');
      _intervalSec = 20;
      _stableTicks++;
    } finally {
      _inFlight = false;
      if (_running) _schedule(_intervalSec);
    }
  }
}
