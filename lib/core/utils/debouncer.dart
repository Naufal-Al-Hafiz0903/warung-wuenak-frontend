import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _t;

  Debouncer({this.delay = const Duration(milliseconds: 450)});

  void run(void Function() action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() {
    _t?.cancel();
  }
}
