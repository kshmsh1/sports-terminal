import 'dart:convert';

import 'package:flutter/services.dart';

class NbaTradeDraftAsset {
  const NbaTradeDraftAsset({
    required this.id,
    required this.team,
    required this.teamName,
    required this.year,
    required this.round,
    required this.description,
    required this.frozen,
    required this.conditional,
    required this.source,
    required this.sourceAsOf,
  });

  final String id;
  final String team;
  final String teamName;
  final int year;
  final int round;
  final String description;
  final bool frozen;
  final bool conditional;
  final String source;
  final String sourceAsOf;

  String get shortLabel => '$year R$round';
}

class NbaTradeDraftSnapshot {
  const NbaTradeDraftSnapshot({
    required this.records,
    required this.sourceNote,
  });

  final List<NbaTradeDraftAsset> records;
  final String sourceNote;

  List<NbaTradeDraftAsset> forTeam(String team) => records
      .where((asset) => asset.team == team)
      .toList()
    ..sort((a, b) {
      final byYear = a.year.compareTo(b.year);
      return byYear != 0 ? byYear : a.round.compareTo(b.round);
    });
}

class NbaTradeDraftRepository {
  const NbaTradeDraftRepository();

  static const assetPath =
      'assets/data/nba/draft/future_draft_assets_2026_27.json';

  Future<NbaTradeDraftSnapshot> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final records = ((decoded['records'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) {
      final data = Map<String, dynamic>.from(row);
      return NbaTradeDraftAsset(
        id: '${data['id'] ?? ''}',
        team: '${data['team_id'] ?? ''}',
        teamName: '${data['team_name'] ?? ''}',
        year: (data['draft_year'] as num?)?.toInt() ?? 0,
        round: (data['round'] as num?)?.toInt() ?? 0,
        description: '${data['description'] ?? ''}',
        frozen: data['frozen'] == true,
        conditional: data['conditional'] == true,
        source: '${data['source'] ?? ''}',
        sourceAsOf: '${data['source_as_of'] ?? ''}',
      );
    }).where((asset) =>
            asset.id.isNotEmpty &&
            asset.team.isNotEmpty &&
            asset.year > 0 &&
            (asset.round == 1 || asset.round == 2))
        .toList();

    return NbaTradeDraftSnapshot(
      records: records,
      sourceNote: '${decoded['source_note'] ?? ''}',
    );
  }
}
