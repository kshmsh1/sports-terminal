import 'nba_stats_metric_catalog.dart';
import 'nba_stats_workstation_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Normalizes historical player dossier rows through exactly the same stats
/// engine and metric catalog used by the league Stats and Advanced Stats pages.
/// No independently maintained player-profile stat formulas.
class ArcsidePlayerSeasonStat {
  const ArcsidePlayerSeasonStat(this.season, this.row);
  final String season;
  final NbaStatsRow row;
}

class ArcsidePlayerProfileStats {
  const ArcsidePlayerProfileStats();

  static const engine = NbaStatsWorkstationEngine();
  static const resolver = NbaTerminalMetricResolver();

  List<ArcsidePlayerSeasonStat> rows(
    Map<String, dynamic> dossier, {
    required String segment,
    NbaStatsBasis basis = NbaStatsBasis.perGame,
  }) {
    final profile = _map(dossier['profile']);
    final sources = _maps(segment == 'playoffs'
        ? dossier['playoff_seasons'] : dossier['regular_seasons']);
    if (sources.isEmpty) return const [];

    final id = (profile['nba_id'] ?? profile['player_key'] ??
            profile['bref_id'] ?? profile['canonical_name'] ?? '')
        .toString();
    final name = (profile['canonical_name'] ?? '').toString();
    final normalized = [
      for (final source in sources)
        <String, dynamic>{
          ...source,
          'player_id': source['player_id'] ?? source['nba_id'] ??
              source['player_key'] ?? id,
          'player_label': source['player_label'] ?? name,
          'team_ids': source['team_ids'] ??
              source['team_abbreviation'] ?? source['team_id'] ?? '—',
          'season_type': segment,
        },
    ];
    final ids = normalized
        .map((record) => record['player_id'].toString()).toSet();
    final snapshot = NbaTerminalSeedSnapshot.fromMap({
      'players': [
        for (final playerId in ids) <String, dynamic>{
          ...profile,
          'player_id': playerId,
        },
      ],
      'player_season_totals': normalized,
    });
    final converted = engine.buildRows(snapshot,
      basis: basis,
      seasonType: segment == 'playoffs'
          ? NbaStatsSeasonType.playoffs : NbaStatsSeasonType.regular);

    return [
      for (var i = 0; i < converted.length && i < sources.length; i++)
        ArcsidePlayerSeasonStat(
          (sources[i]['season_id'] ?? '').toString(),
          converted[i],
        ),
    ]..sort((a,b) {
      final year = b.season.compareTo(a.season);
      return year != 0 ? year : a.row.team.compareTo(b.row.team);
    });
  }

  /// Avoid treating the engine's zero-filled missing counting-stat inputs as
  /// published zeros. This is especially important for older NBA seasons.
  double? value(NbaStatsRow row, String key) {
    final metric = nbaTerminalMetricByKey[key];
    final raw = row.raw;
    // Only guard counting metrics against the stats engine's missing-input
    // defaults. Ratios/derived metrics may legitimately be calculated from
    // published component fields even without an explicit source ratio.
    const guardedCounts = {
      'gp','mpg','ppg','rpg','apg','spg','bpg','tpg','pf',
      'oreb','dreb','fgm','fga','three_pm','three_pa','ftm','fta',
      'bpm','obpm','dbpm',
    };
    if (guardedCounts.contains(key) &&
        metric != null && metric.rawAliases.isEmpty &&
        !_hasSource(raw, key)) {
      return null;
    }
    final number = metric == null
        ? row.value(key) : resolver.value(row, key);
    return number != null && number.isFinite ? number : null;
  }

  String format(NbaStatsRow row, String key) {
    final resolved = value(row, key);
    if (resolved == null) return '—';
    if (nbaTerminalMetricByKey.containsKey(key)) {
      return resolver.format(row, key);
    }
    return engine.formatValue(key, resolved);
  }

  bool _hasSource(Map<String, dynamic> raw, String key) {
    const aliases = <String, List<String>>{
      'gp': ['games', 'gp', 'g'],
      'mpg': ['minutes','mp','minutes_per_game','mpg'],
      'ppg': ['points','pts','points_per_game','ppg'],
      'rpg': ['rebounds','trb','reb','rebounds_per_game','rpg'],
      'apg': ['assists','ast','assists_per_game','apg'],
      'spg': ['steals','stl','steals_per_game','spg'],
      'bpg': ['blocks','blk','blocks_per_game','bpg'],
      'tpg': ['turnovers','tov','turnovers_per_game','tpg'],
      'pf': ['personal_fouls','pf','pf_per_game'],
      'fgm': ['field_goals_made','fgm','fg'],
      'fga': ['field_goal_attempts','fga'],
      'three_pm': ['three_pointers_made','fg3','three_pm'],
      'three_pa': ['three_point_attempts','fg3a','three_pa'],
      'ftm': ['free_throws_made','ftm','ft'],
      'fta': ['free_throw_attempts','fta'],
      'oreb': ['offensive_rebounds','orb','oreb'],
      'dreb': ['defensive_rebounds','drb','dreb'],
      'bpm': ['bpm','avg_bpm','box_plus_minus'],
    };
    final candidates = aliases[key] ?? aliases[switch (key) {
      'min' => 'mpg',
      'pts' => 'ppg',
      'reb' => 'rpg',
      'ast' => 'apg',
      'stl' => 'spg',
      'blk' => 'bpg',
      'tov' => 'tpg',
      _ => key,
    }] ?? [key];
    return candidates.any((candidate) {
      final object = raw[candidate];
      return object != null && object.toString().isNotEmpty;
    });
  }
}

Map<String, dynamic> _map(Object? input) {
  if (input is! Map) return {};
  return input.map((k,v)=>MapEntry(k.toString(),v));
}

List<Map<String, dynamic>> _maps(Object? input) {
  if (input is! List) return const [];
  return [for (final v in input) if (v is Map) _map(v)];
}
