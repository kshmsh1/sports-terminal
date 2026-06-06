import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/services/player_identity_normalizer.dart';

const _sourceId = 'nba-api-common-all-players';

void main(List<String> args) {
  final parsed = _Args.parse(args);
  if (parsed == null) {
    _printUsage();
    exit(64);
  }

  final inputFile = File(parsed.inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: ${parsed.inputPath}');
    exit(66);
  }

  final source = jsonDecode(inputFile.readAsStringSync()) as Map<String, dynamic>;
  final rows = _extractRows(source);
  final batch = const PlayerIdentityNormalizer().normalizeCommonAllPlayers(rows: rows, sourceId: _sourceId, asOf: parsed.asOf);

  _writeJson(parsed.profilesPath, {'source': _sourceHeader(parsed.asOf), 'players': batch.players.map((item) => item.toJson()).toList()});
  _writeJson(parsed.aliasesPath, {'source': _sourceHeader(parsed.asOf), 'aliases': batch.aliases.map((item) => item.toJson()).toList()});
  _writeJson(parsed.heldPath, {'source': _sourceHeader(parsed.asOf), 'heldRows': batch.heldRows});

  stdout.writeln('Normalized ${batch.players.length} players, ${batch.aliases.length} aliases, ${batch.heldRows.length} held rows.');
}

Map<String, dynamic> _sourceHeader(String asOf) => {'id': _sourceId, 'asOf': asOf, 'type': 'source-backed', 'usage': 'CommonAllPlayers normalized local import'};

List<Map<String, dynamic>> _extractRows(Map<String, dynamic> source) {
  final rows = source['rows'];
  if (rows is List) return rows.cast<Map>().map((row) => Map<String, dynamic>.from(row)).toList();

  final resultSets = source['resultSets'];
  if (resultSets is List) {
    for (final resultSet in resultSets.cast<Map>()) {
      final name = resultSet['name']?.toString().toLowerCase();
      if (name == 'commonallplayers' || name == 'common_all_players') {
        final headers = (resultSet['headers'] as List).map((item) => item.toString()).toList();
        final rowSet = resultSet['rowSet'] as List;
        return [for (final row in rowSet.cast<List>()) Map<String, dynamic>.fromIterables(headers, row)];
      }
    }
  }

  final dataSets = source['data_sets'];
  final rowSet = source['rowSet'];
  if (dataSets is Map && dataSets['CommonAllPlayers'] is List && rowSet is List) {
    final headers = (dataSets['CommonAllPlayers'] as List).map((item) => item.toString()).toList();
    return [for (final row in rowSet.cast<List>()) Map<String, dynamic>.fromIterables(headers, row)];
  }

  throw StateError('Could not find CommonAllPlayers rows in input JSON.');
}

void _writeJson(String path, Map<String, dynamic> payload) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(payload)}\n');
}

void _printUsage() {
  stdout.writeln('Usage: dart run tools/normalize_common_all_players.dart --input raw/common_all_players.json --as-of 2026-06-05 [--profiles path] [--aliases path] [--held path]');
}

class _Args {
  const _Args({required this.inputPath, required this.asOf, required this.profilesPath, required this.aliasesPath, required this.heldPath});
  final String inputPath;
  final String asOf;
  final String profilesPath;
  final String aliasesPath;
  final String heldPath;

  static _Args? parse(List<String> args) {
    final map = <String, String>{};
    for (var i = 0; i < args.length; i += 1) {
      final key = args[i];
      if (!key.startsWith('--') || i + 1 >= args.length) return null;
      map[key.substring(2)] = args[i + 1];
      i += 1;
    }
    final input = map['input'];
    final asOf = map['as-of'];
    if (input == null || asOf == null) return null;
    return _Args(
      inputPath: input,
      asOf: asOf,
      profilesPath: map['profiles'] ?? 'assets/data/nba/players/player_profiles.json',
      aliasesPath: map['aliases'] ?? 'assets/data/nba/players/player_aliases.json',
      heldPath: map['held'] ?? 'raw/player_identity_held_rows.json',
    );
  }
}
