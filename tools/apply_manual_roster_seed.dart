import 'dart:convert';
import 'dart:io';

const _sourceId = 'manual-roster-screenshots-2026-06-06';
const _asOf = '2026-06-06';
const _seasonId = '2025-26';

const _paths = <String>[
  'assets/data/nba/manual_sources/rosters/boston_celtics_2026_06_06.psv',
  'assets/data/nba/manual_sources/rosters/atlanta_hawks_2026_06_06_part1.psv',
  'assets/data/nba/manual_sources/rosters/atlanta_hawks_2026_06_06_part2.psv',
  'assets/data/nba/manual_sources/rosters/brooklyn_nets_2026_06_06_part1.psv',
  'assets/data/nba/manual_sources/rosters/brooklyn_nets_2026_06_06_part2a.psv',
  'assets/data/nba/manual_sources/rosters/brooklyn_nets_2026_06_06_part2b.psv',
  'assets/data/nba/manual_sources/rosters/charlotte_hornets_2026_06_06_part1.psv',
  'assets/data/nba/manual_sources/rosters/charlotte_hornets_2026_06_06_part2.psv',
  'assets/data/nba/manual_sources/rosters/chicago_bulls_2026_06_06.psv.b64',
];

void main() {
  final players = <Map<String, dynamic>>[];
  final rosters = <Map<String, dynamic>>[];
  final teams = <String, Map<String, dynamic>>{};
  final seenPlayers = <String>{};

  for (final path in _paths) {
    final text = _readSeed(path);
    for (final line in text.trim().split('\n').skip(1)) {
      if (line.trim().isEmpty) continue;
      final cells = line.split('|');
      if (cells.length != 12) throw StateError('Bad manual roster row in $path: $line');
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
      final college = _nullable(cells[10]);
      final salary = _nullableInt(cells[11]);
      final playerId = 'manual-2026-${_slug(name)}';
      final parts = _splitName(name);

      if (!seenPlayers.add(playerId)) throw StateError('Duplicate manual playerId: $playerId');
      teams[teamId] = {'teamId': teamId, 'teamAbbreviation': teamAbbr, 'teamName': teamName, 'headCoach': headCoach};
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
        'college': college,
        'draftYear': null,
        'draftRound': null,
        'draftPick': null,
        'nbaDebutYear': null,
        'isActive': true,
        'primaryTeamAbbreviation': teamAbbr,
        'sourceId': _sourceId,
        'asOf': _asOf,
      });
      rosters.add({
        'playerId': playerId,
        'teamId': teamId,
        'seasonId': _seasonId,
        'jerseyNumber': jersey,
        'position': position,
        'rosterStatus': 'Active',
        'contractType': null,
        'startDate': null,
        'endDate': null,
        'sourceId': _sourceId,
        'asOf': _asOf,
        'age': age,
        'height': height,
        'weightPounds': weight,
        'college': college,
        'salaryUsd': salary,
        'salaryDisplay': salary == null ? '--' : '\$${_formatMoney(salary)}',
      });
    }
  }

  _writeJson('assets/data/nba/players/player_profiles.json', {
    'source': {'id': _sourceId, 'asOf': _asOf, 'type': 'manual-source-backed', 'usage': 'Manual player identity seed transcribed from user-provided roster screenshots for the first five NBA teams'},
    'players': players,
  });
  _writeJson('assets/data/nba/rosters/roster_entries.json', {
    'source': {'id': _sourceId, 'asOf': _asOf, 'type': 'manual-source-backed', 'usage': 'Manual roster seed transcribed from user-provided roster screenshots for the first five NBA teams'},
    'teams': teams.values.toList(),
    'rosters': rosters,
  });
  _writeJson('raw/manual_roster_seed_report.json', {
    'sourceId': _sourceId,
    'asOf': _asOf,
    'seasonId': _seasonId,
    'teamCount': teams.length,
    'playerRows': players.length,
    'rosterRows': rosters.length,
    'teams': teams.values.toList(),
  });

  print('Manual roster seed applied: ${players.length} players, ${rosters.length} roster entries, ${teams.length} teams.');
  print('Report written to raw/manual_roster_seed_report.json');
}

String _readSeed(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Manual seed file missing: $path');
  final raw = file.readAsStringSync().trim();
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

String _slug(String value) => value.toLowerCase().replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-\$'), '');

String _formatMoney(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i += 1) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

void _writeJson(String path, Map<String, dynamic> value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');
}
