import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/award_record.dart';
import 'package:sports_terminal/models/draft_pick.dart';
import 'package:sports_terminal/models/game_record.dart';
import 'package:sports_terminal/models/player_alias.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/player_season_stat.dart';
import 'package:sports_terminal/models/playoff_series_record.dart';
import 'package:sports_terminal/models/roster_entry.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/standings_record.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/models/team_season_stat.dart';
import 'package:sports_terminal/models/transaction_record.dart';
import 'package:sports_terminal/services/award_record_validator.dart';
import 'package:sports_terminal/services/draft_pick_validator.dart';
import 'package:sports_terminal/services/game_record_validator.dart';
import 'package:sports_terminal/services/player_identity_validator.dart';
import 'package:sports_terminal/services/player_season_stat_validator.dart';
import 'package:sports_terminal/services/playoff_series_validator.dart';
import 'package:sports_terminal/services/roster_entry_validator.dart';
import 'package:sports_terminal/services/standings_record_validator.dart';
import 'package:sports_terminal/services/team_season_stat_validator.dart';
import 'package:sports_terminal/services/transaction_record_validator.dart';

void main() {
  final teams = _load('assets/data/nba/teams/teams.json', 'teams', Team.fromJson);
  final seasons = _load('assets/data/nba/seasons/seasons.json', 'seasons', Season.fromJson);
  final players = _load('assets/data/nba/players/player_profiles.json', 'players', PlayerProfile.fromJson);
  final aliases = _load('assets/data/nba/players/player_aliases.json', 'aliases', PlayerAlias.fromJson);
  final playerStats = _load('assets/data/nba/stats/player_traditional_by_season.json', 'playerSeasonStats', PlayerSeasonStat.fromJson);
  final teamStats = _load('assets/data/nba/stats/team_by_season.json', 'teamSeasonStats', TeamSeasonStat.fromJson);
  final standings = _load('assets/data/nba/standings/standings_records.json', 'standings', StandingsRecord.fromJson);
  final playoffSeries = _load('assets/data/nba/playoffs/playoff_series_records.json', 'playoffSeries', PlayoffSeriesRecord.fromJson);
  final awards = _load('assets/data/nba/awards/award_records.json', 'awards', AwardRecord.fromJson);
  final games = _load('assets/data/nba/games/game_records.json', 'games', GameRecord.fromJson);
  final rosters = _load('assets/data/nba/rosters/roster_entries.json', 'rosters', RosterEntry.fromJson);
  final draft = _load('assets/data/nba/draft/draft_picks.json', 'draftPicks', DraftPick.fromJson);
  final transactions = _load('assets/data/nba/transactions/transaction_records.json', 'transactions', TransactionRecord.fromJson);

  final rows = <_ValidationRow>[
    _ValidationRow('Player Identity', players.length + aliases.length, const PlayerIdentityValidator().validate(players: players, aliases: aliases).blockers, const PlayerIdentityValidator().validate(players: players, aliases: aliases).warnings),
    _fromSummary('Player Season Stats', playerStats.length, const PlayerSeasonStatValidator().validate(stats: playerStats, players: players, seasons: seasons, teams: teams).blockers, const PlayerSeasonStatValidator().validate(stats: playerStats, players: players, seasons: seasons, teams: teams).warnings),
    _fromSummary('Team Season Stats', teamStats.length, const TeamSeasonStatValidator().validate(stats: teamStats, teams: teams, seasons: seasons).blockers, const TeamSeasonStatValidator().validate(stats: teamStats, teams: teams, seasons: seasons).warnings),
    _fromSummary('Standings', standings.length, const StandingsRecordValidator().validate(standings: standings, teams: teams, seasons: seasons).blockers, const StandingsRecordValidator().validate(standings: standings, teams: teams, seasons: seasons).warnings),
    _fromSummary('Playoff Series', playoffSeries.length, const PlayoffSeriesValidator().validate(series: playoffSeries, teams: teams, seasons: seasons).blockers, const PlayoffSeriesValidator().validate(series: playoffSeries, teams: teams, seasons: seasons).warnings),
    _fromSummary('Awards', awards.length, const AwardRecordValidator().validate(awards: awards, players: players, teams: teams, seasons: seasons).blockers, const AwardRecordValidator().validate(awards: awards, players: players, teams: teams, seasons: seasons).warnings),
    _fromSummary('Games', games.length, const GameRecordValidator().validate(games: games, teams: teams, seasons: seasons).blockers, const GameRecordValidator().validate(games: games, teams: teams, seasons: seasons).warnings),
    _fromSummary('Rosters', rosters.length, const RosterEntryValidator().validate(rosters: rosters, players: players, teams: teams, seasons: seasons).blockers, const RosterEntryValidator().validate(rosters: rosters, players: players, teams: teams, seasons: seasons).warnings),
    _fromSummary('Draft Picks', draft.length, const DraftPickValidator().validate(picks: draft, players: players, teams: teams).blockers, const DraftPickValidator().validate(picks: draft, players: players, teams: teams).warnings),
    _fromSummary('Transactions', transactions.length, const TransactionRecordValidator().validate(transactions: transactions, players: players, teams: teams).blockers, const TransactionRecordValidator().validate(transactions: transactions, players: players, teams: teams).warnings),
  ];

  print('NBA asset validation summary');
  var blockers = 0;
  var warnings = 0;
  for (final row in rows) {
    blockers += row.blockers;
    warnings += row.warnings;
    print('${row.dataset}: rows=${row.rows}, blockers=${row.blockers}, warnings=${row.warnings}');
  }
  print('Total blockers: $blockers');
  print('Total warnings: $warnings');

  if (blockers > 0) {
    stderr.writeln('NBA asset validation failed. Do not connect blocked datasets.');
    exit(1);
  }

  print('All NBA asset validators passed.');
}

List<T> _load<T>(String path, String key, T Function(Map<String, dynamic>) fromJson) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (decoded[key] as List<dynamic>).map((row) => fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

_ValidationRow _fromSummary(String dataset, int rows, int blockers, int warnings) => _ValidationRow(dataset, rows, blockers, warnings);

class _ValidationRow {
  const _ValidationRow(this.dataset, this.rows, this.blockers, this.warnings);

  final String dataset;
  final int rows;
  final int blockers;
  final int warnings;
}
