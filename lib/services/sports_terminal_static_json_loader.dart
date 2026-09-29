import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import 'sports_terminal_static_config.dart';

/// Loads the same logical static JSON documents from either loose local files
/// or compressed GitHub Pages bundles.
class SportsTerminalStaticJsonLoader {
  SportsTerminalStaticJsonLoader(this.client);

  final http.Client client;
  final Map<int, Map<String, dynamic>> _bundleCache = {};
  final List<int> _bundleLru = [];
  static const int _maxCachedBundles = 8;

  Future<Object?> load(String basePath, String relative) async {
    final logicalRelative = _logicalRelative(basePath, relative);

    if (!sportsTerminalNbaStaticBundled) {
      final uri = Uri.base.resolve('${_normalize(basePath)}/$relative');
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StaticJsonLoadException(response.statusCode, relative);
      }
      return jsonDecode(response.body);
    }

    final bucket = sportsTerminalStaticBundleBucket(logicalRelative);
    var payload = _bundleCache[bucket];
    if (payload == null) {
      final bundleName = 'bundle_${bucket.toString().padLeft(3, '0')}.json.gz';
      final uri = Uri.base.resolve(
        '${_normalize(sportsTerminalNbaBundleBase)}/$bundleName',
      );
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StaticJsonLoadException(response.statusCode, relative);
      }
      final decodedBytes = GZipDecoder().decodeBytes(response.bodyBytes);
      final decoded = jsonDecode(utf8.decode(decodedBytes));
      if (decoded is! Map) {
        throw FormatException('Invalid Sports Terminal bundle: $bundleName');
      }
      payload = decoded.map((key, value) => MapEntry(key.toString(), value));
      _remember(bucket, payload);
    } else {
      _touch(bucket);
    }

    if (!payload.containsKey(logicalRelative)) {
      throw FormatException(
        'Sports Terminal bundle is missing $logicalRelative (bucket $bucket)',
      );
    }
    return payload[logicalRelative];
  }

  void _remember(int bucket, Map<String, dynamic> payload) {
    _bundleCache[bucket] = payload;
    _touch(bucket);
    while (_bundleLru.length > _maxCachedBundles) {
      final evicted = _bundleLru.removeAt(0);
      _bundleCache.remove(evicted);
    }
  }

  void _touch(int bucket) {
    _bundleLru.remove(bucket);
    _bundleLru.add(bucket);
  }

  String _normalize(String value) => value.replaceAll(RegExp(r'^/+|/+

class StaticJsonLoadException implements Exception {
  const StaticJsonLoadException(this.statusCode, this.relative);
  final int statusCode;
  final String relative;
}
), '');

  String _logicalRelative(String basePath, String relative) {
    final normalizedBase = _normalize(basePath);
    final normalizedStaticBase = _normalize(sportsTerminalNbaStaticBase);
    final normalizedRelative = relative.replaceAll(RegExp(r'^/+'), '');

    if (normalizedBase == normalizedStaticBase) {
      return normalizedRelative;
    }
    if (normalizedBase.startsWith('$normalizedStaticBase/')) {
      final prefix = normalizedBase.substring(normalizedStaticBase.length + 1);
      return '$prefix/$normalizedRelative';
    }
    return normalizedRelative;
  }
}

class StaticJsonLoadException implements Exception {
  const StaticJsonLoadException(this.statusCode, this.relative);
  final int statusCode;
  final String relative;
}
