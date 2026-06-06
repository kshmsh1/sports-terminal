import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/player_alias.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/services/player_identity_validator.dart';

void main() {
  final players = _load('assets/data/nba/players/player_profiles.json', 'players', PlayerProfile.fromJson);
  final aliases = _load('assets/data/nba/players/player_aliases.json', 'aliases', PlayerAlias.fromJson);
  final summary = const PlayerIdentityValidator().validate(players: players, aliases: aliases);

  print('Connected player identity validation summary');
  print('Players: ${players.length}');
  print('Aliases: ${aliases.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.playerId ?? 'global'}: ${issue.message}');
  }

  var blockers = summary.blockers;
  if (players.isEmpty) {
    stderr.writeln('Player identity is not connected: player_profiles.json has zero rows.');
    blockers += 1;
  }
  if (players.any((player) => player.sourceId == null || player.sourceId!.trim().isEmpty || player.asOf == null || player.asOf!.trim().isEmpty)) {
    stderr.writeln('Player identity is not connected: one or more player rows are missing sourceId/asOf.');
    blockers += 1;
  }
  if (aliases.isEmpty) {
    stderr.writeln('Warning: player_aliases.json has zero rows. This is allowed only if intentionally documented for the chosen source.');
  }

  if (blockers > 0) {
    stderr.writeln('Connected player identity validation failed. Do not move to player stats yet.');
    exit(1);
  }

  print('Connected player identity is valid.');
}

List<T> _load<T>(String path, String key, T Function(Map<String, dynamic>) fromJson) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Required file not found: $path');
    exit(66);
  }
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (decoded[key] as List<dynamic>).map((row) => fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
