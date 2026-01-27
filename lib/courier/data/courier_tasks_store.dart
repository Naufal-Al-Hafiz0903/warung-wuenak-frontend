import 'package:flutter/foundation.dart';
import '../../models/shipment_tracking_model.dart';
import 'courier_shipments_service.dart';

class CourierTasksStore extends ChangeNotifier {
  CourierTasksStore._();
  static final CourierTasksStore I = CourierTasksStore._();

  List<ShipmentTrackingModel> _items = const [];
  bool _loading = false;
  String? _error;

  DateTime? _lastFetch;
  Future<void>? _inflight;

  List<ShipmentTrackingModel> get items => _items;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({bool force = false}) {
    if (_inflight != null) return _inflight!;

    final now = DateTime.now();
    if (!force &&
        _lastFetch != null &&
        now.difference(_lastFetch!).inSeconds < 8 &&
        _items.isNotEmpty) {
      return Future.value();
    }

    _loading = true;
    _error = null;
    notifyListeners();

    final f = CourierShipmentsService.fetchMyTasks()
        .then((list) {
          _items = list;
          _lastFetch = DateTime.now();
        })
        .catchError((e) {
          _error = e.toString();
        })
        .whenComplete(() {
          _loading = false;
          _inflight = null;
          notifyListeners();
        });

    _inflight = f;
    return f;
  }

  void removeByOrderId(int orderId) {
    final next = _items.where((e) => e.orderId != orderId).toList();
    if (next.length == _items.length) return;
    _items = next;
    notifyListeners();
  }

  void updateStatus(int orderId, String status, {String? updatedAt}) {
    bool changed = false;
    final next = _items.map((e) {
      if (e.orderId != orderId) return e;
      changed = true;
      return ShipmentTrackingModel(
        shipmentId: e.shipmentId,
        orderId: e.orderId,
        status: status,
        courier: e.courier,
        trackingNumber: e.trackingNumber,
        updatedAt: updatedAt ?? e.updatedAt,
        events: e.events,
      );
    }).toList();

    if (!changed) return;
    _items = next;
    notifyListeners();
  }
}
