import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/route_payload.dart';
import '../services/product_local_store.dart';

class RoutePayloadController extends ChangeNotifier {
  RoutePayloadController({ProductLocalStore store = const ProductLocalStore()})
      : _store = store;

  final ProductLocalStore _store;
  RoutePayload? _activePayload;
  String _lastOrigin = 'None';
  final List<RoutePayload> _history = [];
  bool _hydrated = false;

  RoutePayload? get activePayload => _activePayload;
  String get lastOrigin => _lastOrigin;
  List<RoutePayload> get history => List.unmodifiable(_history);
  bool get hasActivePayload => _activePayload != null;
  bool get hydrated => _hydrated;

  Future<void> hydrate() async {
    if (_hydrated) return;
    try {
      final activeRaw = await _store.loadString(ProductLocalStore.routePayloadActiveKey);
      final historyRaw = await _store.loadString(ProductLocalStore.routePayloadHistoryKey);
      _activePayload = RoutePayload.tryDecode(activeRaw);
      if (historyRaw.isNotEmpty) {
        final decoded = jsonDecode(historyRaw);
        if (decoded is List) {
          _history
            ..clear()
            ..addAll([
              for (final item in decoded)
                if (item is Map)
                  RoutePayload.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
            ]);
        }
      }
    } catch (_) {
      _activePayload = null;
      _history.clear();
    }
    _hydrated = true;
    notifyListeners();
  }

  void setActivePayload(
    RoutePayload payload, {
    String origin = 'Unknown origin',
  }) {
    final stamped = payload.createdAtIso.isEmpty
        ? payload.copyWith(createdAtIso: DateTime.now().toUtc().toIso8601String())
        : payload;
    _activePayload = stamped;
    _lastOrigin = origin;
    _history.removeWhere((item) => item.routeKey == stamped.routeKey);
    _history.insert(0, stamped);
    if (_history.length > 25) {
      _history.removeRange(25, _history.length);
    }
    notifyListeners();
    unawaited(_persist());
  }

  void retargetActivePayload(
    String targetRoute, {
    String origin = 'Retargeted',
  }) {
    final current = _activePayload;
    if (current == null) return;
    setActivePayload(
      current.copyWith(targetRoute: targetRoute),
      origin: origin,
    );
  }

  void activateHistoryItem(RoutePayload payload) {
    setActivePayload(payload, origin: 'Route history');
  }

  void removeHistoryItem(RoutePayload payload) {
    _history.removeWhere(
      (item) =>
          item.routeKey == payload.routeKey &&
          item.createdAtIso == payload.createdAtIso,
    );
    if (_activePayload?.routeKey == payload.routeKey &&
        _activePayload?.createdAtIso == payload.createdAtIso) {
      _activePayload = null;
      _lastOrigin = 'Removed from history';
    }
    notifyListeners();
    unawaited(_persist());
  }

  void clearHistory() {
    _history.clear();
    _activePayload = null;
    _lastOrigin = 'History cleared';
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    _activePayload = null;
    _lastOrigin = 'Cleared';
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      if (_activePayload == null) {
        await _store.remove(ProductLocalStore.routePayloadActiveKey);
      } else {
        await _store.saveString(
          ProductLocalStore.routePayloadActiveKey,
          _activePayload!.encode(),
        );
      }
      await _store.saveString(
        ProductLocalStore.routePayloadHistoryKey,
        jsonEncode([for (final item in _history) item.toJson()]),
      );
    } catch (_) {
      // Local persistence must never interrupt the active product workflow.
    }
  }
}

class RoutePayloadScope extends InheritedNotifier<RoutePayloadController> {
  const RoutePayloadScope({
    super.key,
    required RoutePayloadController controller,
    required super.child,
  }) : super(notifier: controller);

  static RoutePayloadController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RoutePayloadScope>()
        ?.notifier;
  }

  static RoutePayloadController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'RoutePayloadScope was not found above this context.');
    return controller!;
  }
}
