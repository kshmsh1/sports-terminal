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

  final identity = const PlayerIdentityValidator().validate(players: players, aliases: aliases);
  final playerStat = const PlayerSeasonStatValidator().validate(stats: playerStats, players: players, seasons: seasons, teams: teams);
  final teamStat = const TeamSeasonStatValidator().validate(stats: teamStats, teams: teams, seasons: seasons);
  final standing = const StandingsRecordValidator().validate(standings: standings, teams: teams, seasons: seasons);
  final playoffs = const PlayoffSeriesValidator().validate(series: playoffSeries, teams: teams, seasons: seasons);
  final award = const AwardRecordValidator().validate(awards: awards, players: players, teams: teams, seasons: seasons);
  final game = const GameRecordValidator().validate(games: games, teams: teams, seasons: seasons);
  final roster = const RosterEntryValidator().validate(rosters: rosters, players: players, teams: teams, seasons: seasons);
  final draftValidation = const DraftPickValidator().validate(picks: draft, players: players, teams: teams);
  final transaction = const TransactionRecordValidator().validate(transactions: transactions, players: players, teams: teams);

  final rows = <_ValidationRow>[
    _ValidationRow('Player Identity', players.length + aliases.length, identity.blockers, identity.warnings),
    _ValidationRow('Player Season Stats', playerStats.length, playerStat.blockers, playerStat.warnings),
    _ValidationRow('Team Season Stats', teamStats.length, teamStat.blockers, teamStat.warnings),
    _ValidationRow('Standings', standings.length, standing.blockers, standing.warnings),
    _ValidationRow('Playoff Series', playoffSeries.length, playoffs.blockers, playoffs.warnings),
    _ValidationRow('Awards', awards.length, award.blockers, award.warnings),
    _ValidationRow('Games', games.length, game.blockers, game.warnings),
    _ValidationRow('Rosters', rosters.length, roster.blockers, roster.warnings),
    _ValidationRow('Draft Picks', draft.length, draftValidation.blockers, draftValidation.warnings),
    _ValidationRow('Transactions', transactions.length, transaction.blockers, transaction.warnings),
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

class _ValidationRow {
  const _ValidationRow(this.dataset, this.rows, this.blockers, this.warnings);

  final String dataset;
  final int rows;
  final int blockers;
  final int warnings;
}
