import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/nba_cap_environment.dart';

class NbaFinancialRepository {
  const NbaFinancialRepository({
    this.assetPath = 'assets/data/nba/finance/cap_environments.json',
  });

  final String assetPath;

  Future<List<NbaCapEnvironment>> loadCapEnvironments() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['environments'] is! List) {
      throw const FormatException('Invalid NBA cap environment asset.');
    }
    final environments = <NbaCapEnvironment>[
      for (final item in decoded['environments'] as List)
        if (item is Map)
          NbaCapEnvironment.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
    ];
    environments.sort((a, b) => a.season.compareTo(b.season));
    return environments;
  }

  Future<NbaCapEnvironment?> loadSeason(String season) async {
    final environments = await loadCapEnvironments();
    for (final environment in environments) {
      if (environment.season == season) return environment;
    }
    return null;
  }
}
