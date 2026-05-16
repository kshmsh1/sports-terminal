import 'dart:convert';
import 'dart:io';

typedef JsonObject = Map<String, dynamic>;

const assetChecks = <AssetCheck>[
  AssetCheck(path: 'assets/data/nba/teams/teams.json', rootKey: 'teams', requiredFields: ['id', 'name', 'city', 'abbreviation', 'conference', 'division']),
  AssetCheck(path: 'assets/data/nba/seasons/seasons.json', rootKey: 'seasons', requiredFields: ['id', 'label', 'startYear', 'endYear', 'league']),
  AssetCheck(path: 'assets/data/nba/players/player_profiles.json', rootKey: 'players', requiredFields: ['id', 'displayName']),
  AssetCheck(path: 'assets/data/nba/stats/player_traditional_by_season.json', rootKey: 'playerSeasonStats', requiredFields: ['id', 'playerId', 'seasonId']),
  AssetCheck(path: 'assets/data/nba/stats/team_by_season.json', rootKey: 'teamSeasonStats', requiredFields: ['id', 'teamId', 'seasonId']),
  AssetCheck(path: 'assets/data/nba/games/game_records.json', rootKey: 'games', requiredFields: ['id', 'seasonId']),
  AssetCheck(path: 'assets/data/nba/rosters/roster_entries.json', rootKey: 'rosters', requiredFields: ['id', 'playerId', 'teamId', 'seasonId']),
  AssetCheck(path: 'assets/data/nba/awards/award_records.json', rootKey: 'awards', requiredFields: ['id', 'seasonId', 'awardName']),
  AssetCheck(path: 'assets/data/nba/draft/draft_picks.json', rootKey: 'draftPicks', requiredFields: ['id', 'draftYear', 'pickNumber']),
  AssetCheck(path: 'assets/data/nba/transactions/transaction_records.json', rootKey: 'transactions', requiredFields: ['id', 'transactionDate', 'transactionType']),
  AssetCheck(path: 'assets/data/nba/standings/standings_records.json', rootKey: 'standings', requiredFields: ['id', 'teamId', 'seasonId']),
  AssetCheck(path: 'assets/data/nba/playoffs/playoff_series_records.json', rootKey: 'playoffSeries', requiredFields: ['id', 'seasonId']),
];

void main() {
  final issues = <String>[];
  final rowCounts = <String, int>{};
  final idsByAsset = <String, Set<String>>{};
  final teams = <String>{};
  final seasons = <String>{};
  final players = <String>{};

  for (final check in assetChecks) {
    final file = File(check.path);
    if (!file.existsSync()) {
      issues.add('Missing asset: ${check.path}');
      continue;
    }

    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! JsonObject) {
      issues.add('${check.path}: root JSON must be an object.');
      continue;
    }

    final rows = decoded[check.rootKey];
    if (rows is! List) {
      issues.add('${check.path}: missing list root key `${check.rootKey}`.');
      continue;
    }

    rowCounts[check.rootKey] = rows.length;
    final ids = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! JsonObject) {
        issues.add('${check.path}[$i]: row must be an object.');
        continue;
      }
      for (final field in check.requiredFields) {
        if (!row.containsKey(field) || row[field] == null || row[field].toString().isEmpty) {
          issues.add('${check.path}[$i]: missing required field `$field`.');
        }
      }
      final id = row['id']?.toString();
      if (id != null && id.isNotEmpty) {
        if (!ids.add(id)) issues.add('${check.path}: duplicate id `$id`.');
      }
      if (check.rootKey == 'teams' && id != null) teams.add(id);
      if (check.rootKey == 'seasons' && id != null) seasons.add(id);
      if (check.rootKey == 'players' && id != null) players.add(id);
    }
    idsByAsset[check.rootKey] = ids;
  }

  _validateJoins(issues, teams: teams, seasons: seasons, players: players);

  stdout.writeln('NBA asset validation summary');
  stdout.writeln('----------------------------');
  for (final entry in rowCounts.entries) {
    stdout.writeln('${entry.key}: ${entry.value} rows');
  }
  stdout.writeln('Known teams: ${teams.length}');
  stdout.writeln('Known seasons: ${seasons.length}');
  stdout.writeln('Known players: ${players.length}');
  stdout.writeln('');

  if (issues.isEmpty) {
    stdout.writeln('PASS: assets are structurally valid for the current MVP checks.');
    return;
  }

  stdout.writeln('FAIL: ${issues.length} issue(s) found.');
  for (final issue in issues.take(80)) {
    stdout.writeln('- $issue');
  }
  if (issues.length > 80) stdout.writeln('- ... ${issues.length - 80} additional issues omitted');
  exitCode = 1;
}

void _validateJoins(List<String> issues, {required Set<String> teams, required Set<String> seasons, required Set<String> players}) {
  final joinFiles = [
    const JoinCheck(path: 'assets/data/nba/stats/player_traditional_by_season.json', rootKey: 'playerSeasonStats', playerField: 'playerId', teamField: 'teamId', seasonField: 'seasonId'),
    const JoinCheck(path: 'assets/data/nba/stats/team_by_season.json', rootKey: 'teamSeasonStats', teamField: 'teamId', seasonField: 'seasonId'),
    const JoinCheck(path: 'assets/data/nba/standings/standings_records.json', rootKey: 'standings', teamField: 'teamId', seasonField: 'seasonId'),
    const JoinCheck(path: 'assets/data/nba/rosters/roster_entries.json', rootKey: 'rosters', playerField: 'playerId', teamField: 'teamId', seasonField: 'seasonId'),
    const JoinCheck(path: 'assets/data/nba/awards/award_records.json', rootKey: 'awards', playerField: 'playerId', teamField: 'teamId', seasonField: 'seasonId'),
    const JoinCheck(path: 'assets/data/nba/transactions/transaction_records.json', rootKey: 'transactions', playerField: 'playerId', teamField: 'teamId'),
  ];

  for (final check in joinFiles) {
    final file = File(check.path);
    if (!file.existsSync()) continue;
    final decoded = jsonDecode(file.readAsStringSync()) as JsonObject;
    final rows = decoded[check.rootKey];
    if (rows is! List) continue;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! JsonObject) continue;
      final playerId = check.playerField == null ? null : row[check.playerField]?.toString();
      final teamId = check.teamField == null ? null : row[check.teamField]?.toString();
      final seasonId = check.seasonField == null ? null : row[check.seasonField]?.toString();
      if (playerId != null && playerId.isNotEmpty && !players.contains(playerId)) issues.add('${check.path}[$i]: unknown playerId `$playerId`.');
      if (teamId != null && teamId.isNotEmpty && !teams.contains(teamId)) issues.add('${check.path}[$i]: unknown teamId `$teamId`.');
      if (seasonId != null && seasonId.isNotEmpty && !seasons.contains(seasonId)) issues.add('${check.path}[$i]: unknown seasonId `$seasonId`.');
    }
  }
}

class AssetCheck {
  const AssetCheck({required this.path, required this.rootKey, required this.requiredFields});
  final String path;
  final String rootKey;
  final List<String> requiredFields;
}

class JoinCheck {
  const JoinCheck({required this.path, required this.rootKey, this.playerField, this.teamField, this.seasonField});
  final String path;
  final String rootKey;
  final String? playerField;
  final String? teamField;
  final String? seasonField;
}
