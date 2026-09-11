import 'dart:convert';

import 'package:flutter/services.dart';

class NbaTradeContract {
  const NbaTradeContract({
    required this.id,
    required this.player,
    required this.team,
    required this.salaries,
    required this.guaranteed,
    required this.sourceStatus,
    required this.sourceLabel,
  });

  final String id;
  final String player;
  final String team;
  final Map<String, double> salaries;
  final double? guaranteed;
  final String sourceStatus;
  final String sourceLabel;

  double salaryFor(String season) => salaries[season] ?? 0;

  factory NbaTradeContract.fromJson(Map<String, dynamic> json) {
    final raw = (json['salaries'] as Map?)?.cast<String, dynamic>() ?? const {};
    return NbaTradeContract(
      id: '${json['id'] ?? ''}',
      player: '${json['player'] ?? ''}',
      team: '${json['team'] ?? ''}'.toUpperCase(),
      salaries: {
        for (final entry in raw.entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      },
      guaranteed: json['guaranteed'] is num
          ? (json['guaranteed'] as num).toDouble()
          : null,
      sourceStatus: '${json['sourceStatus'] ?? 'uploaded'}',
      sourceLabel: '${json['sourceLabel'] ?? ''}',
    );
  }
}

class NbaTradeContractSnapshot {
  const NbaTradeContractSnapshot({
    required this.records,
    required this.asOf,
    required this.sourceNote,
  });

  final List<NbaTradeContract> records;
  final String asOf;
  final String sourceNote;

  List<String> get teams {
    final values = records.map((item) => item.team).where((item) => item.isNotEmpty).toSet().toList()..sort();
    return values;
  }

  List<NbaTradeContract> forTeam(String team, String season) {
    final rows = records
        .where((item) => item.team == team && item.salaryFor(season) > 0)
        .toList()
      ..sort((a, b) => b.salaryFor(season).compareTo(a.salaryFor(season)));
    return rows;
  }

  double payroll(String team, String season) =>
      forTeam(team, season).fold(0, (sum, item) => sum + item.salaryFor(season));
}

class NbaTradeContractRepository {
  const NbaTradeContractRepository({
    this.path = 'assets/data/nba/finance/contracts_2026_27.json',
  });

  final String path;

  Future<NbaTradeContractSnapshot> load() async {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid NBA trade contract dataset.');
    }
    final rows = (decoded['records'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => NbaTradeContract.fromJson(item.cast<String, dynamic>()))
        .toList();
    return NbaTradeContractSnapshot(
      records: rows,
      asOf: '${decoded['asOf'] ?? ''}',
      sourceNote: '${decoded['deduplication'] ?? ''}',
    );
  }
}
