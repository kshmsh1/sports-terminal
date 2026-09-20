import 'product_local_store.dart';

class LaunchBackendResponse {
  const LaunchBackendResponse({
    required this.available,
    this.data,
    this.statusCode = 0,
    this.error = '',
    this.requestCompleted = false,
  });

  final bool available;
  final Object? data;
  final int statusCode;
  final String error;
  final bool requestCompleted;

  bool get succeeded => statusCode >= 200 && statusCode < 300;
  bool get rejected => requestCompleted && !succeeded;
}

/// Compatibility transport retained for callers that still understand the
/// former backend-sync contract.
///
/// Runtime network synchronization is intentionally disabled. Sports Terminal
/// now operates from static snapshots and local persistence only.
class LaunchBackendTransport {
  const LaunchBackendTransport({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  // Retained so existing constructor call sites remain source-compatible.
  final ProductLocalStore _store;

  Future<LaunchBackendResponse> getJson(
    String path, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) async => _disabled();

  Future<LaunchBackendResponse> putJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) async => _disabled();

  Future<LaunchBackendResponse> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) async => _disabled();

  Future<LaunchBackendResponse> deleteJson(
    String path, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) async => _disabled();

  LaunchBackendResponse _disabled() {
    // Touch the retained field so static analysis does not flag it as dead.
    _store.hashCode;
    return const LaunchBackendResponse(
      available: false,
      error:
          'Runtime backend/network synchronization is disabled. Sports Terminal uses static snapshots and local persistence.',
    );
  }
}
