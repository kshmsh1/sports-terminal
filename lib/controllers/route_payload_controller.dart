import 'package:flutter/material.dart';

import '../models/route_payload.dart';

class RoutePayloadController extends ChangeNotifier {
  RoutePayload? _activePayload;
  String _lastOrigin = 'None';
  final List<RoutePayload> _history = [];

  RoutePayload? get activePayload => _activePayload;
  String get lastOrigin => _lastOrigin;
  List<RoutePayload> get history => List.unmodifiable(_history);
  bool get hasActivePayload => _activePayload != null;

  void setActivePayload(RoutePayload payload, {String origin = 'Unknown origin'}) {
    _activePayload = payload;
    _lastOrigin = origin;
    _history.removeWhere((item) => item.routeKey == payload.routeKey);
    _history.insert(0, payload);
    if (_history.length > 12) {
      _history.removeRange(12, _history.length);
    }
    notifyListeners();
  }

  void retargetActivePayload(String targetRoute, {String origin = 'Retargeted'}) {
    final current = _activePayload;
    if (current == null) return;
    setActivePayload(current.copyWith(targetRoute: targetRoute), origin: origin);
  }

  void clear() {
    _activePayload = null;
    _lastOrigin = 'Cleared';
    notifyListeners();
  }
}

class RoutePayloadScope extends InheritedNotifier<RoutePayloadController> {
  const RoutePayloadScope({
    super.key,
    required RoutePayloadController controller,
    required super.child,
  }) : super(notifier: controller);

  static RoutePayloadController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RoutePayloadScope>()?.notifier;
  }

  static RoutePayloadController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'RoutePayloadScope was not found above this context.');
    return controller!;
  }
}
