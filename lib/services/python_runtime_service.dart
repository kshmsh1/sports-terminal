import '../models/route_payload.dart';
import 'launch_backend_transport.dart';

class PythonRuntimeResult {
  const PythonRuntimeResult({
    required this.completed,
    required this.available,
    required this.stdout,
    required this.result,
    required this.durationMs,
    required this.rowCount,
    required this.columnCount,
    required this.warnings,
    required this.error,
    required this.statusCode,
  });

  final bool completed;
  final bool available;
  final String stdout;
  final Object? result;
  final int durationMs;
  final int rowCount;
  final int columnCount;
  final List<String> warnings;
  final String error;
  final int statusCode;
}

class PythonRuntimeService {
  const PythonRuntimeService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
  }) : _transport = transport;

  final LaunchBackendTransport _transport;

  Future<Map<String, dynamic>?> capabilities() async {
    final response = await _transport.getJson(
      '/v2/runtime/python/capabilities',
    );
    if (!response.succeeded || response.data is! Map) return null;
    return (response.data as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  Future<PythonRuntimeResult> execute({
    required String code,
    required RoutePayload? payload,
  }) async {
    final response = await _transport.postJson(
      '/v2/runtime/python/execute',
      {
        'code': code,
        'rows': payload?.rows ?? const [],
        'columns': [
          for (final column in payload?.columns ?? const <RoutePayloadColumn>[])
            column.toJson(),
        ],
        'timeout_seconds': 3,
      },
      timeout: const Duration(seconds: 7),
    );
    if (!response.succeeded || response.data is! Map) {
      return PythonRuntimeResult(
        completed: false,
        available: response.available,
        stdout: '',
        result: null,
        durationMs: 0,
        rowCount: payload?.rowCount ?? 0,
        columnCount: payload?.columnCount ?? 0,
        warnings: const [],
        error: response.error.isEmpty
            ? 'The isolated runtime is unavailable.'
            : response.error,
        statusCode: response.statusCode,
      );
    }
    final data = (response.data as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return PythonRuntimeResult(
      completed: data['status'] == 'completed',
      available: true,
      stdout: data['stdout']?.toString() ?? '',
      result: data['result'],
      durationMs: (data['duration_ms'] as num?)?.toInt() ?? 0,
      rowCount: (data['row_count'] as num?)?.toInt() ?? 0,
      columnCount: (data['column_count'] as num?)?.toInt() ?? 0,
      warnings: data['warnings'] is List
          ? [for (final value in data['warnings'] as List) value.toString()]
          : const [],
      error: '',
      statusCode: response.statusCode,
    );
  }
}
