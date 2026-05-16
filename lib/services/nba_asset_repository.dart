import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/player_profile.dart';
import '../models/season.dart';
import '../models/team.dart';

class NbaAssetRepository {
  const NbaAssetRepository();

  Future<List<Team>> loadTeams() async {
    final rawJson = await rootBundle.loadString('assets/data/nba/teams/teams.json');
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final records = decoded['teams'] as List<dynamic>;

    return records
        .map((record) => Team.fromJson(record as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Season>> loadSeasons() async {
    final rawJson = await rootBundle.loadString('assets/data/nba/seasons/seasons.json');
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final records = decoded['seasons'] as List<dynamic>;

    return records
        .map((record) => Season.fromJson(record as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PlayerProfile>> loadPlayerProfiles() async {
    final rawJson = await rootBundle.loadString('assets/data/nba/players/player_profiles.json');
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final records = decoded['players'] as List<dynamic>;

    return records
        .map((record) => PlayerProfile.fromJson(record as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> loadDatasetManifest() async {
    final rawJson = await rootBundle.loadString('assets/data/nba/metadata/dataset_manifest.json');
    return jsonDecode(rawJson) as Map<String, dynamic>;
  }
}
