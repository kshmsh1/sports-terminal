import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/game_record.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/playoff_series_record.dart';
import '../models/roster_entry.dart';
import '../models/season.dart';
import '../models/standings_record.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../models/transaction_record.dart';

class NbaAssetRepository {
  const NbaAssetRepository();

  Future<List<Team>> loadTeams() async {
    final decoded = await _loadObject('assets/data/nba/teams/teams.json');
    final records = decoded['teams'] as List<dynamic>;
    return records.map((record) => Team.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<Season>> loadSeasons() async {
    final decoded = await _loadObject('assets/data/nba/seasons/seasons.json');
    final records = decoded['seasons'] as List<dynamic>;
    return records.map((record) => Season.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<PlayerProfile>> loadPlayerProfiles() async {
    final decoded = await _loadObject('assets/data/nba/players/player_profiles.json');
    final records = decoded['players'] as List<dynamic>;
    return records.map((record) => PlayerProfile.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<PlayerSeasonStat>> loadPlayerSeasonStats() async {
    final decoded = await _loadObject('assets/data/nba/stats/player_traditional_by_season.json');
    final records = decoded['playerSeasonStats'] as List<dynamic>;
    return records.map((record) => PlayerSeasonStat.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<TeamSeasonStat>> loadTeamSeasonStats() async {
    final decoded = await _loadObject('assets/data/nba/stats/team_by_season.json');
    final records = decoded['teamSeasonStats'] as List<dynamic>;
    return records.map((record) => TeamSeasonStat.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<GameRecord>> loadGames() async {
    final decoded = await _loadObject('assets/data/nba/games/game_records.json');
    final records = decoded['games'] as List<dynamic>;
    return records.map((record) => GameRecord.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<RosterEntry>> loadRosters() async {
    final decoded = await _loadObject('assets/data/nba/rosters/roster_entries.json');
    final records = decoded['rosters'] as List<dynamic>;
    return records.map((record) => RosterEntry.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<AwardRecord>> loadAwards() async {
    final decoded = await _loadObject('assets/data/nba/awards/award_records.json');
    final records = decoded['awards'] as List<dynamic>;
    return records.map((record) => AwardRecord.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<DraftPick>> loadDraftPicks() async {
    final decoded = await _loadObject('assets/data/nba/draft/draft_picks.json');
    final records = decoded['draftPicks'] as List<dynamic>;
    return records.map((record) => DraftPick.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<TransactionRecord>> loadTransactions() async {
    final decoded = await _loadObject('assets/data/nba/transactions/transaction_records.json');
    final records = decoded['transactions'] as List<dynamic>;
    return records.map((record) => TransactionRecord.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<StandingsRecord>> loadStandings() async {
    final decoded = await _loadObject('assets/data/nba/standings/standings_records.json');
    final records = decoded['standings'] as List<dynamic>;
    return records.map((record) => StandingsRecord.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<PlayoffSeriesRecord>> loadPlayoffSeries() async {
    final decoded = await _loadObject('assets/data/nba/playoffs/playoff_series_records.json');
    final records = decoded['playoffSeries'] as List<dynamic>;
    return records.map((record) => PlayoffSeriesRecord.fromJson(record as Map<String, dynamic>)).toList(growable: false);
  }

  Future<Map<String, dynamic>> loadDatasetManifest() async {
    return _loadObject('assets/data/nba/metadata/dataset_manifest.json');
  }

  Future<Map<String, dynamic>> _loadObject(String path) async {
    final rawJson = await rootBundle.loadString(path);
    return jsonDecode(rawJson) as Map<String, dynamic>;
  }
}
