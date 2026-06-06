import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/player_alias.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/services/player_identity_validator.dart';

void main(List<String> args) {
  final parsed = _Args.parse(args);
  if (parsed == null) {
    _printUsage();
    exit(64);
  }

  final profilesFile = File(parsed.profilesPath);
  final aliasesFile = File(parsed.aliasesPath);
  if (!profilesFile.existsSync()) {
    stderr.writeln('Player profiles file not found: ${parsed.profilesPath}');
    exit(66);
  }
  if (!aliasesFile.existsSync()) {
    stderr.writeln('Player aliases file not found: ${parsed.aliasesPath}');
    exit(66);
  }

  final profileJson = jsonDecode(profilesFile.readAsStringSync()) as Map<String, dynamic>;
  final aliasJson = jsonDecode(aliasesFile.readAsStringSync()) as Map<String, dynamic>;
  final players = (profileJson['players'] as List<dynamic>).map((row) => PlayerProfile.fromJson(row as Map<String, dynamic>)).toList(growable: false);
  final aliases = (aliasJson['aliases'] as List<dynamic>).map((row) => PlayerAlias.fromJson(row as Map<String, dynamic>)).toList(growable: false);
  final summary = const PlayerIdentityValidator().validate(players: players, aliases: aliases);

  stdout.writeln('Player identity validation summary');
  stdout.writeln('Players: ${players.length}');
  stdout.writeln('Aliases: ${aliases.length}');
  stdout.writeln('Blockers: ${summary.blockers}');
  stdout.writeln('Warnings: ${summary.warnings}');

  if (summary.issues.isNotEmpty) {
    stdout.writeln('Issues:');
    for (final issue in summary.issues) {
      stdout.writeln('- ${issue.severity} ${issue.code} ${issue.playerId ?? 'global'}: ${issue.message}');
    }
  }

  if (!summary.canConnect) {
    stderr.writeln('Player identity assets are blocked and should not be connected.');
    exit(1);
  }

  stdout.writeln('Player identity assets are connectable.');
}

void _printUsage() {
  stdout.writeln('Usage: dart run tools/validate_player_identity.dart [--profiles assets/data/nba/players/player_profiles.json] [--aliases assets/data/nba/players/player_aliases.json]');
}

class _Args {
  const _Args({required this.profilesPath, required this.aliasesPath});
  final String profilesPath;
  final String aliasesPath;

  static _Args? parse(List<String> args) {
    final map = <String, String>{};
    for (var i = 0; i < args.length; i += 1) {
      final key = args[i];
      if (!key.startsWith('--')) return null;
      if (i + 1 >= args.length) return null;
      map[key.substring(2)] = args[i + 1];
      i += 1;
    }
    return _Args(
      profilesPath: map['profiles'] ?? 'assets/data/nba/players/player_profiles.json',
      aliasesPath: map['aliases'] ?? 'assets/data/nba/players/player_aliases.json',
    );
  }
}
