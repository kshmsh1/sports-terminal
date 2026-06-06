import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/player_alias.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/services/player_identity_validator.dart';

void main(List<String> args) {
  final asOf = args.isEmpty ? DateTime.now().toIso8601String().split('T').first : args.first;
  final players = _load('assets/data/nba/players/player_profiles.json', 'players', PlayerProfile.fromJson);
  final aliases = _load('assets/data/nba/players/player_aliases.json', 'aliases', PlayerAlias.fromJson);
  final heldRows = _loadHeldRows('raw/player_identity_held_rows.json');
  final validation = const PlayerIdentityValidator().validate(players: players, aliases: aliases);
  final sourceIds = players.map((player) => player.sourceId).whereType<String>().where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  final asOfValues = players.map((player) => player.asOf).whereType<String>().where((value) => value.trim().isNotEmpty).toSet().toList()..sort();

  final report = {
    'generatedAt': DateTime.now().toIso8601String(),
    'candidateAsOf': asOf,
    'playerRows': players.length,
    'aliasRows': aliases.length,
    'heldRows': heldRows.length,
    'validatorBlockers': validation.blockers,
    'validatorWarnings': validation.warnings,
    'sourceIds': sourceIds,
    'asOfValues': asOfValues,
    'canConnect': validation.canConnect && players.isNotEmpty,
    'issues': validation.issues.map((issue) => {
      'severity': issue.severity,
      'code': issue.code,
      'playerId': issue.playerId,
      'message': issue.message,
    }).toList(),
  };

  final output = File('raw/player_identity_import_report.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');

  print('Player identity import report written to raw/player_identity_import_report.json');
  print('Players: ${players.length}; aliases: ${aliases.length}; held: ${heldRows.length}; blockers: ${validation.blockers}; warnings: ${validation.warnings}');

  if (!validation.canConnect || players.isEmpty) {
    stderr.writeln('Player identity import report is not connectable.');
    exit(1);
  }
}

List<T> _load<T>(String path, String key, T Function(Map<String, dynamic>) fromJson) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (decoded[key] as List<dynamic>).map((row) => fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<dynamic> _loadHeldRows(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded['heldRows'] as List<dynamic>? ?? const [];
}
