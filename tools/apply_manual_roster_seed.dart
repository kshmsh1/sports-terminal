import 'dart:convert';
import 'dart:io';

const _sourceId = 'manual-roster-screenshots-2026-06-06';
const _asOf = '2026-06-06';
const _seasonId = '2025-26';
const _snapshotLabel = '2025-26 final roster snapshot';
const _sourceDirs = <String>[
  'assets/data/nba/manual_sources/rosters',
  'docs/manual_roster_sources',
];

void main() {
  final seedPaths = _seedPaths();
  if (seedPaths.isEmpty) {
    throw StateError('No manual roster seed files found.');
  }

  final players = <Map<String, dynamic>>[];
  final rosters = <Map<String, dynamic>>[];
  final teams = <String, Map<String, dynamic>>{};
  final seenPlayerIds = <String>{};
  final seenRosterKeys = <String>{};
  final skippedDuplicatePlayers = <Map<String, String>>[];
  final skippedDuplicateRosters = <Map<String, String>>[];

  for (final path in seedPaths) {
    final text = _readSeed(path);
    for (final line in text.trim().split('\n').skip(1)) {
      if (line.trim().isEmpty) continue;
      final cells = line.split('|');
      if (cells.length != 12) {
        throw StateError('Bad manual roster row in $path: $line');
      }
      final teamAbbr = cells[0];
      final teamId = cells[1];
      final teamName = cells[2];
      final headCoach = _nullable(cells[3]);
      final name = cells[4];
      final jersey = _nullable(cells[5]);
      final position = cells[6];
      final age = int.parse(cells[7]);
      final height = cells[8];
      final weight = int.parse(cells[9]);
      final from = _nullable(cells[10]);
      final salary = _nullableInt(cells[11]);
      final playerId = 'manual-2026-${_slug(name)}';
      final rosterKey = '$playerId|$teamId|$_seasonId';
      final parts = _splitName(name);

      teams[teamId] = {
        'teamId': teamId,
        'teamAbbreviation': teamAbbr,
        'teamName': teamName,
        'headCoach': headCoach,
      };

      if (seenPlayerIds.add(playerId)) {
        players.add({
          'id': playerId,
          'displayName': name,
          'firstName': parts.first,
          'lastName': parts.last,
          'position': position,
          'height': height,
          'weightPounds': weight,
          'birthDate': null,
          'birthCountry': null,
          'college': from,
          'draftYear': null,
          'draftRound': null,
          'draftPick': null,
          'nbaDebutYear': null,
          'isActive': true,
          'primaryTeamAbbreviation': teamAbbr,
          'sourceId': _sourceId,
          'asOf': _asOf,
        });
      } else {
        skippedDuplicatePlayers.add({'playerId': playerId, 'displayName': name, 'sourceFile': path});
      }

      if (!seenRosterKeys.add(rosterKey)) {
        skippedDuplicateRosters.add({'rosterKey': rosterKey, 'displayName': name, 'sourceFile': path});
        continue;
      }

      rosters.add({
        'playerId': playerId,
        'teamId': teamId,
        'seasonId': _seasonId,
        'jerseyNumber': jersey,
        'position': position,
        'rosterStatus': 'Final roster',
        'contractType': null,
        'startDate': null,
        'endDate': null,
        'sourceId': _sourceId,
        'asOf': _asOf,
        'snapshotLabel': _snapshotLabel,
        'age': age,
        'height': height,
        'weightPounds': weight,
        'college': from,
        'from': from,
        'salaryUsd': salary,
        'salaryDisplay': salary == null ? '--' : '\$${_formatMoney(salary)}',
      });
    }
  }

  _writeJson('assets/data/nba/players/player_profiles.json', {
    'source': {
      'id': _sourceId,
      'asOf': _asOf,
      'type': 'manual-source-backed',
      'usage': 'Manual player identity seed transcribed from user-provided final 2025-26 roster screenshots',
      'seasonId': _seasonId,
      'snapshotLabel': _snapshotLabel,
    },
    'players': players,
  });
  _writeJson('assets/data/nba/rosters/roster_entries.json', {
    'source': {
      'id': _sourceId,
      'asOf': _asOf,
      'type': 'manual-source-backed',
      'usage': 'Manual roster seed transcribed from user-provided final 2025-26 roster screenshots',
      'seasonId': _seasonId,
      'snapshotLabel': _snapshotLabel,
    },
    'teams': teams.values.toList(),
    'rosters': rosters,
  });
  _writeJson('raw/manual_roster_seed_report.json', {
    'sourceId': _sourceId,
    'asOf': _asOf,
    'seasonId': _seasonId,
    'snapshotLabel': _snapshotLabel,
    'seedFiles': seedPaths,
    'teamCount': teams.length,
    'playerRows': players.length,
    'rosterRows': rosters.length,
    'skippedDuplicatePlayerRows': skippedDuplicatePlayers,
    'skippedDuplicateRosterRows': skippedDuplicateRosters,
    'teams': teams.values.toList(),
  });

  print('Manual roster seed applied: ${players.length} players, ${rosters.length} roster entries, ${teams.length} teams.');
  print('Seed files: ${seedPaths.length}.');
  print('Skipped duplicate player rows: ${skippedDuplicatePlayers.length}.');
  print('Skipped duplicate roster rows: ${skippedDuplicateRosters.length}.');
  print('Report written to raw/manual_roster_seed_report.json');
}

List<String> _seedPaths() {
  final paths = <String>[];
  for (final dirPath in _sourceDirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.endsWith('.psv') || path.endsWith('.psv.b64')) {
        paths.add(path);
      }
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

String? _nullable(String value) => value == '--' ? null : value;
int? _nullableInt(String value) => value == '--' ? null : int.parse(value);

({String first, String last}) _splitName(String name) {
  final parts = name.split(' ');
  if (parts.length == 1) return (first: name, last: '');
  return (first: parts.first, last: parts.skip(1).join(' '));
}

String _slug(String value) => value.toLowerCase().replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+\$'), '');
String _formatMoney(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

void _writeJson(String path, Map<String, dynamic> value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');
}
