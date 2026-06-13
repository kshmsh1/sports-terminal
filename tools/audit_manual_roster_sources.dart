import 'dart:convert';
import 'dart:io';

const _sourceDirs = <String>[
  'assets/data/nba/manual_sources/rosters',
  'docs/manual_roster_sources',
];

void main() {
  final canonicalTeams = _loadCanonicalTeamIds();
  final paths = _seedPaths();
  if (paths.isEmpty) throw StateError('No manual roster source files found.');

  final sourceRowCountsByTeam = <String, int>{};
  final uniqueRowCountsByTeam = <String, int>{};
  final fileCountsByTeam = <String, int>{};
  final duplicateNaturalKeys = <String, List<String>>{};
  final seenNaturalKeys = <String, String>{};
  var totalRows = 0;

  for (final path in paths) {
    final text = _readSeed(path);
    final lines = text.trim().split('\n');
    if (lines.isEmpty || lines.first != 'teamAbbr|teamId|teamName|headCoach|displayName|jerseyNumber|position|age|height|weightPounds|college|salaryUsd') {
      throw StateError('Bad manual roster source header in $path');
    }

    final teamsInFile = <String>{};
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final cells = line.split('|');
      if (cells.length != 12) throw StateError('Bad manual roster row in $path: $line');
      final teamId = cells[1];
      final playerName = cells[4];
      final naturalKey = '${_slug(playerName)}|$teamId|2025-26';
      totalRows += 1;
      sourceRowCountsByTeam[teamId] = (sourceRowCountsByTeam[teamId] ?? 0) + 1;
      teamsInFile.add(teamId);
      final firstPath = seenNaturalKeys[naturalKey];
      if (firstPath == null) {
        seenNaturalKeys[naturalKey] = path;
        uniqueRowCountsByTeam[teamId] = (uniqueRowCountsByTeam[teamId] ?? 0) + 1;
      } else {
        duplicateNaturalKeys.putIfAbsent(naturalKey, () => [firstPath]).add(path);
      }
    }
    for (final teamId in teamsInFile) {
      fileCountsByTeam[teamId] = (fileCountsByTeam[teamId] ?? 0) + 1;
    }
  }

  final coveredTeams = uniqueRowCountsByTeam.keys.toSet();
  final missingTeams = canonicalTeams.difference(coveredTeams).toList()..sort();
  final unknownTeams = coveredTeams.difference(canonicalTeams).toList()..sort();
  final duplicateSourceRows = totalRows - seenNaturalKeys.length;

  print('Manual roster source audit');
  print('Seed files: ${paths.length}');
  print('Source rows scanned: $totalRows');
  print('Unique player-team-season rows: ${seenNaturalKeys.length}');
  print('Duplicate source rows ignored: $duplicateSourceRows');
  print('Covered teams: ${coveredTeams.length} / ${canonicalTeams.length}');
  if (missingTeams.isNotEmpty) print('Missing teams: ${missingTeams.join(', ')}');
  if (unknownTeams.isNotEmpty) print('Unknown teams: ${unknownTeams.join(', ')}');
  print('Unique rows by team:');
  final teamIds = uniqueRowCountsByTeam.keys.toList()..sort();
  for (final teamId in teamIds) {
    final uniqueRows = uniqueRowCountsByTeam[teamId] ?? 0;
    final sourceRows = sourceRowCountsByTeam[teamId] ?? 0;
    final duplicates = sourceRows - uniqueRows;
    print('- $teamId: $uniqueRows unique rows, $duplicates duplicate rows, ${fileCountsByTeam[teamId]} source files');
  }

  if (duplicateNaturalKeys.isNotEmpty) {
    print('Duplicate source keys are tolerated because generation deterministically keeps the first player-team-season row. Consolidation remains a source-cleanup task.');
  }

  if (missingTeams.isNotEmpty || unknownTeams.isNotEmpty) {
    throw StateError('Manual roster source audit failed coverage checks.');
  }
}

Set<String> _loadCanonicalTeamIds() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => (row as Map<String, dynamic>)['id'] as String).toSet();
}

List<String> _seedPaths() {
  final paths = <String>[];
  for (final dirPath in _sourceDirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.endsWith('.psv') || path.endsWith('.psv.b64')) paths.add(path);
    }
  }
  paths.sort();
  return paths;
}

String _readSeed(String path) {
  final raw = File(path).readAsStringSync().trim();
  if (path.endsWith('.b64')) return utf8.decode(base64Decode(raw));
  return raw;
}

String _slug(String value) => value.toLowerCase().replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+\$'), '');
