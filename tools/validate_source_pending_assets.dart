import 'dart:convert';
import 'dart:io';

void main() {
  final checks = <_SourcePendingCheck>[
    _SourcePendingCheck('Teams', 'assets/data/nba/teams/teams.json', 'teams', expectedMinimumRows: 30),
    _SourcePendingCheck('Seasons', 'assets/data/nba/seasons/seasons.json', 'seasons', expectedMinimumRows: 1),
    _SourcePendingCheck('Player Profiles', 'assets/data/nba/players/player_profiles.json', 'players'),
    _SourcePendingCheck('Player Aliases', 'assets/data/nba/players/player_aliases.json', 'aliases'),
    _SourcePendingCheck('Player Season Stats', 'assets/data/nba/stats/player_traditional_by_season.json', 'playerSeasonStats'),
    _SourcePendingCheck('Team Season Stats', 'assets/data/nba/stats/team_by_season.json', 'teamSeasonStats'),
    _SourcePendingCheck('Standings', 'assets/data/nba/standings/standings_records.json', 'standings'),
    _SourcePendingCheck('Playoff Series', 'assets/data/nba/playoffs/playoff_series_records.json', 'playoffSeries'),
    _SourcePendingCheck('Awards', 'assets/data/nba/awards/award_records.json', 'awards'),
    _SourcePendingCheck('Games', 'assets/data/nba/games/game_records.json', 'games'),
    _SourcePendingCheck('Rosters', 'assets/data/nba/rosters/roster_entries.json', 'rosters'),
    _SourcePendingCheck('Draft Picks', 'assets/data/nba/draft/draft_picks.json', 'draftPicks'),
    _SourcePendingCheck('Transactions', 'assets/data/nba/transactions/transaction_records.json', 'transactions'),
  ];

  var blockers = 0;
  print('Source-pending asset gate');
  for (final check in checks) {
    final count = _rowCount(check.path, check.key);
    final expectedMinimum = check.expectedMinimumRows;
    final passes = expectedMinimum == null ? count == 0 : count >= expectedMinimum;
    if (!passes) blockers += 1;
    final expectation = expectedMinimum == null ? 'expected=0' : 'expected>=$expectedMinimum';
    print('${check.label}: rows=$count, $expectation, status=${passes ? 'pass' : 'block'}');
  }

  if (blockers > 0) {
    stderr.writeln('Source-pending gate failed. Restore placeholders or move to the post-import candidate gate.');
    exit(1);
  }

  print('Source-pending asset gate passed.');
}

int _rowCount(String path, String key) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (decoded[key] as List<dynamic>).length;
}

class _SourcePendingCheck {
  const _SourcePendingCheck(this.label, this.path, this.key, {this.expectedMinimumRows});

  final String label;
  final String path;
  final String key;
  final int? expectedMinimumRows;
}
