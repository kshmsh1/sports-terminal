import 'dart:math' as math;

import 'nba_terminal_seed_repository.dart';

enum NbaStatsBasis {
  perGame('Per Game'),
  per36('Per 36'),
  per48('Per 48'),
  per75('Per 75 Poss'),
  per100('Per 100 Poss'),
  totals('Totals');

  const NbaStatsBasis(this.label);
  final String label;
}

enum NbaStatsSeasonType {
  regular('Regular'),
  playoffs('Playoffs'),
  combined('Combined');

  const NbaStatsSeasonType(this.label);
  final String label;
}

enum NbaMetricFormat { decimal, integer, percent, signed, text }

class NbaStatMetric {
  const NbaStatMetric({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.group,
    this.format = NbaMetricFormat.decimal,
    this.decimals = 1,
    this.higherIsBetter = true,
    this.description = '',
    this.sourceNote = '',
  });

  final String key;
  final String label;
  final String shortLabel;
  final String group;
  final NbaMetricFormat format;
  final int decimals;
  final bool higherIsBetter;
  final String description;
  final String sourceNote;
}

const nbaStatMetrics = <NbaStatMetric>[
  NbaStatMetric(key: 'gp', label: 'Games Played', shortLabel: 'GP', group: 'Profile', format: NbaMetricFormat.integer, description: 'Games played in the selected season segment.'),
  NbaStatMetric(key: 'min', label: 'Minutes', shortLabel: 'MIN', group: 'Profile', description: 'Minutes under the selected rate basis.'),
  NbaStatMetric(key: 'age', label: 'Age', shortLabel: 'AGE', group: 'Profile', description: 'Player age in the source season.'),
  NbaStatMetric(key: 'pts', label: 'Points', shortLabel: 'PTS', group: 'Counting', description: 'Points scored under the selected rate basis.'),
  NbaStatMetric(key: 'ast', label: 'Assists', shortLabel: 'AST', group: 'Counting', description: 'Assists under the selected rate basis.'),
  NbaStatMetric(key: 'reb', label: 'Rebounds', shortLabel: 'REB', group: 'Counting', description: 'Total rebounds under the selected rate basis.'),
  NbaStatMetric(key: 'oreb', label: 'Offensive Rebounds', shortLabel: 'OREB', group: 'Counting', description: 'Offensive rebounds under the selected rate basis.'),
  NbaStatMetric(key: 'dreb', label: 'Defensive Rebounds', shortLabel: 'DREB', group: 'Counting', description: 'Defensive rebounds under the selected rate basis.'),
  NbaStatMetric(key: 'stl', label: 'Steals', shortLabel: 'STL', group: 'Counting', description: 'Steals under the selected rate basis.'),
  NbaStatMetric(key: 'blk', label: 'Blocks', shortLabel: 'BLK', group: 'Counting', description: 'Blocks under the selected rate basis.'),
  NbaStatMetric(key: 'tov', label: 'Turnovers', shortLabel: 'TOV', group: 'Counting', higherIsBetter: false, description: 'Turnovers under the selected rate basis.'),
  NbaStatMetric(key: 'pf', label: 'Personal Fouls', shortLabel: 'PF', group: 'Counting', higherIsBetter: false, description: 'Personal fouls under the selected rate basis.'),
  NbaStatMetric(key: 'fgm', label: 'Field Goals Made', shortLabel: 'FGM', group: 'Shooting'),
  NbaStatMetric(key: 'fga', label: 'Field Goal Attempts', shortLabel: 'FGA', group: 'Shooting'),
  NbaStatMetric(key: 'fg_pct', label: 'Field Goal Percentage', shortLabel: 'FG%', group: 'Shooting', format: NbaMetricFormat.percent, description: 'Field goals made divided by field goal attempts.'),
  NbaStatMetric(key: 'two_pm', label: 'Two-Point Field Goals Made', shortLabel: '2PM', group: 'Shooting'),
  NbaStatMetric(key: 'two_pa', label: 'Two-Point Field Goal Attempts', shortLabel: '2PA', group: 'Shooting'),
  NbaStatMetric(key: 'two_pct', label: 'Two-Point Percentage', shortLabel: '2P%', group: 'Shooting', format: NbaMetricFormat.percent),
  NbaStatMetric(key: 'three_pm', label: 'Three-Pointers Made', shortLabel: '3PM', group: 'Shooting'),
  NbaStatMetric(key: 'three_pa', label: 'Three-Point Attempts', shortLabel: '3PA', group: 'Shooting'),
  NbaStatMetric(key: 'three_pct', label: 'Three-Point Percentage', shortLabel: '3P%', group: 'Shooting', format: NbaMetricFormat.percent),
  NbaStatMetric(key: 'ftm', label: 'Free Throws Made', shortLabel: 'FTM', group: 'Shooting'),
  NbaStatMetric(key: 'fta', label: 'Free Throw Attempts', shortLabel: 'FTA', group: 'Shooting'),
  NbaStatMetric(key: 'ft_pct', label: 'Free Throw Percentage', shortLabel: 'FT%', group: 'Shooting', format: NbaMetricFormat.percent),
  NbaStatMetric(key: 'ts_pct', label: 'True Shooting Percentage', shortLabel: 'TS%', group: 'Efficiency', format: NbaMetricFormat.percent, description: 'PTS / (2 × (FGA + 0.44 × FTA)).', sourceNote: 'Derived from source box-score totals.'),
  NbaStatMetric(key: 'efg_pct', label: 'Effective Field Goal Percentage', shortLabel: 'eFG%', group: 'Efficiency', format: NbaMetricFormat.percent, description: '(FGM + 0.5 × 3PM) / FGA.', sourceNote: 'Derived from source box-score totals.'),
  NbaStatMetric(key: 'points_per_shot', label: 'Points per Shooting Attempt', shortLabel: 'PTS/SA', group: 'Efficiency', decimals: 2, description: 'Points divided by FGA + 0.44 × FTA.', sourceNote: 'Derived efficiency measure.'),
  NbaStatMetric(key: 'ast_tov', label: 'Assist-to-Turnover Ratio', shortLabel: 'AST/TOV', group: 'Efficiency', decimals: 2, description: 'Assists divided by turnovers.'),
  NbaStatMetric(key: 'three_rate', label: 'Three-Point Attempt Rate', shortLabel: '3PA RATE', group: 'Efficiency', format: NbaMetricFormat.percent, description: 'Three-point attempts divided by field goal attempts.'),
  NbaStatMetric(key: 'ft_rate', label: 'Free Throw Attempt Rate', shortLabel: 'FTA RATE', group: 'Efficiency', format: NbaMetricFormat.percent, description: 'Free throw attempts divided by field goal attempts.'),
  NbaStatMetric(key: 'plus_minus', label: 'Plus/Minus', shortLabel: '+/-', group: 'Impact', format: NbaMetricFormat.signed),
  NbaStatMetric(key: 'bpm', label: 'Box Plus/Minus', shortLabel: 'BPM', group: 'Impact', format: NbaMetricFormat.signed, description: 'Source-provided box plus/minus when available.'),
  NbaStatMetric(key: 'game_score_proxy', label: 'Production Index', shortLabel: 'PROD', group: 'Impact', description: 'Transparent box-production index for comparison, not an official NBA metric.', sourceNote: 'PTS + .7 REB + .7 AST + STL + BLK − .7 TOV.'),
  NbaStatMetric(key: 'stocks', label: 'Steals + Blocks', shortLabel: 'STOCKS', group: 'Defense', description: 'Steals plus blocks under the selected rate basis.'),
  NbaStatMetric(key: 'defense_events', label: 'Defensive Event Index', shortLabel: 'DEF EVT', group: 'Defense', description: 'Steals + blocks + 0.35 × defensive rebounds.', sourceNote: 'Transparent box-score proxy; not tracking-based defense.'),
  NbaStatMetric(key: 'possessions_proxy', label: 'Estimated Individual Possessions', shortLabel: 'POSS*', group: 'Advanced', description: 'FGA + 0.44 × FTA − OREB + TOV when source possessions are absent.', sourceNote: 'Asterisk denotes an estimate when no direct possession field exists.'),
  NbaStatMetric(key: 'scoring_load', label: 'Scoring Load Proxy', shortLabel: 'LOAD*', group: 'Advanced', format: NbaMetricFormat.percent, description: 'Estimated shooting possessions divided by estimated individual possessions.', sourceNote: 'Transparent usage proxy, not official usage percentage.'),
];

const nbaDefaultViews = <String, List<String>>{
  'Overview': ['gp', 'min', 'age', 'pts', 'ast', 'reb', 'tov', 'ts_pct', 'plus_minus', 'bpm'],
  'Counting': ['gp', 'min', 'pts', 'ast', 'reb', 'oreb', 'dreb', 'stl', 'blk', 'tov', 'pf'],
  'Shooting': ['gp', 'min', 'fgm', 'fga', 'fg_pct', 'two_pm', 'two_pa', 'two_pct', 'three_pm', 'three_pa', 'three_pct', 'ftm', 'fta', 'ft_pct'],
  'Efficiency': ['gp', 'min', 'pts', 'ts_pct', 'efg_pct', 'points_per_shot', 'ast_tov', 'three_rate', 'ft_rate'],
  'Impact': ['gp', 'min', 'pts', 'ast', 'reb', 'plus_minus', 'bpm', 'game_score_proxy'],
  'Defense': ['gp', 'min', 'dreb', 'stl', 'blk', 'stocks', 'defense_events', 'pf'],
  'Advanced': ['gp', 'min', 'possessions_proxy', 'scoring_load', 'ts_pct', 'efg_pct', 'ast_tov', 'bpm', 'game_score_proxy'],
};

class NbaStatsFilters {
  const NbaStatsFilters({
    this.search = '',
    this.team = 'All',
    this.position = 'All',
    this.minGames = 0,
    this.minMinutes = 0,
    this.minAge,
    this.maxAge,
    this.favoriteOnly = false,
    this.metricKey,
    this.metricMinimum,
    this.metricMaximum,
  });

  final String search;
  final String team;
  final String position;
  final double minGames;
  final double minMinutes;
  final double? minAge;
  final double? maxAge;
  final bool favoriteOnly;
  final String? metricKey;
  final double? metricMinimum;
  final double? metricMaximum;

  NbaStatsFilters copyWith({
    String? search,
    String? team,
    String? position,
    double? minGames,
    double? minMinutes,
    double? minAge,
    double? maxAge,
    bool? favoriteOnly,
    String? metricKey,
    double? metricMinimum,
    double? metricMaximum,
    bool clearMinAge = false,
    bool clearMaxAge = false,
    bool clearMetric = false,
  }) {
    return NbaStatsFilters(
      search: search ?? this.search,
      team: team ?? this.team,
      position: position ?? this.position,
      minGames: minGames ?? this.minGames,
      minMinutes: minMinutes ?? this.minMinutes,
      minAge: clearMinAge ? null : minAge ?? this.minAge,
      maxAge: clearMaxAge ? null : maxAge ?? this.maxAge,
      favoriteOnly: favoriteOnly ?? this.favoriteOnly,
      metricKey: clearMetric ? null : metricKey ?? this.metricKey,
      metricMinimum: clearMetric ? null : metricMinimum ?? this.metricMinimum,
      metricMaximum: clearMetric ? null : metricMaximum ?? this.metricMaximum,
    );
  }
}

class NbaStatsRow {
  const NbaStatsRow({
    required this.playerId,
    required this.player,
    required this.team,
    required this.position,
    required this.values,
    required this.percentiles,
    required this.raw,
    required this.possessionsEstimated,
  });

  final String playerId;
  final String player;
  final String team;
  final String position;
  final Map<String, double?> values;
  final Map<String, double> percentiles;
  final Map<String, dynamic> raw;
  final bool possessionsEstimated;

  double? value(String key) => values[key];

  NbaStatsRow withPercentiles(Map<String, double> next) => NbaStatsRow(
        playerId: playerId,
        player: player,
        team: team,
        position: position,
        values: values,
        percentiles: next,
        raw: raw,
        possessionsEstimated: possessionsEstimated,
      );
}

class NbaStatsWorkstationEngine {
  const NbaStatsWorkstationEngine();

  List<NbaStatsRow> buildRows(
    NbaTerminalSeedSnapshot snapshot, {
    NbaStatsBasis basis = NbaStatsBasis.perGame,
    NbaStatsSeasonType seasonType = NbaStatsSeasonType.regular,
  }) {
    final profiles = <String, Map<String, dynamic>>{
      for (final profile in snapshot.players) _text(_first(profile, const ['player_id', 'id'])): profile,
    };
    final rows = <NbaStatsRow>[];
    for (final raw in snapshot.playerSeasonTotals) {
      final rawType = _text(_first(raw, const ['season_type', 'seasonType', 'segment'])).toLowerCase();
      final isPlayoff = rawType.contains('playoff') || rawType.contains('postseason');
      if (seasonType == NbaStatsSeasonType.regular && isPlayoff) continue;
      if (seasonType == NbaStatsSeasonType.playoffs && !isPlayoff) continue;
      final playerId = _text(_first(raw, const ['player_id', 'id', 'slug']));
      final profile = profiles[playerId] ?? const <String, dynamic>{};
      rows.add(_normalize(raw, profile, basis));
    }
    return _attachPercentiles(rows);
  }

  List<NbaStatsRow> filterRows(
    List<NbaStatsRow> rows,
    NbaStatsFilters filters, {
    Set<String> favorites = const {},
  }) {
    final query = filters.search.trim().toLowerCase();
    return rows.where((row) {
      if (query.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) return false;
      if (filters.team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(filters.team)) return false;
      if (filters.position != 'All' && row.position != filters.position) return false;
      if ((row.value('gp') ?? 0) < filters.minGames) return false;
      final minutes = row.value('min') ?? 0;
      if (minutes < filters.minMinutes) return false;
      final age = row.value('age');
      if (filters.minAge != null && (age == null || age < filters.minAge!)) return false;
      if (filters.maxAge != null && (age == null || age > filters.maxAge!)) return false;
      if (filters.favoriteOnly && !favorites.contains(row.playerId)) return false;
      if (filters.metricKey != null) {
        final value = row.value(filters.metricKey!);
        if (value == null) return false;
        if (filters.metricMinimum != null && value < filters.metricMinimum!) return false;
        if (filters.metricMaximum != null && value > filters.metricMaximum!) return false;
      }
      return true;
    }).toList();
  }

  void sortRows(List<NbaStatsRow> rows, String metricKey, {bool descending = true}) {
    rows.sort((left, right) {
      final l = left.value(metricKey);
      final r = right.value(metricKey);
      if (l == null && r == null) return left.player.compareTo(right.player);
      if (l == null) return 1;
      if (r == null) return -1;
      final compared = l.compareTo(r);
      return descending ? -compared : compared;
    });
  }

  Map<String, List<NbaStatsRow>> groupByTeam(List<NbaStatsRow> rows) {
    final output = <String, List<NbaStatsRow>>{};
    for (final row in rows) {
      final teams = row.team.split(RegExp(r'[,/ ]+')).where((team) => team.isNotEmpty && team != '—');
      for (final team in teams) {
        output.putIfAbsent(team, () => []).add(row);
      }
    }
    return output;
  }

  NbaStatMetric metric(String key) => nbaStatMetrics.firstWhere(
        (metric) => metric.key == key,
        orElse: () => NbaStatMetric(key: key, label: key, shortLabel: key.toUpperCase(), group: 'Custom'),
      );

  String formatValue(String key, double? value) {
    if (value == null || value.isNaN || value.isInfinite) return '—';
    final definition = metric(key);
    switch (definition.format) {
      case NbaMetricFormat.integer:
        return value.round().toString();
      case NbaMetricFormat.percent:
        return '${(value * 100).toStringAsFixed(definition.decimals)}%';
      case NbaMetricFormat.signed:
        return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(definition.decimals)}';
      case NbaMetricFormat.text:
        return value.toString();
      case NbaMetricFormat.decimal:
        return value.toStringAsFixed(definition.decimals);
    }
  }

  NbaStatsRow _normalize(Map<String, dynamic> raw, Map<String, dynamic> profile, NbaStatsBasis basis) {
    final games = _number(_first(raw, const ['games', 'gp', 'g'])) ?? 0;
    final minutesTotal = _total(raw, games, const ['minutes', 'mp'], const ['minutes_per_game', 'mpg']);
    final points = _total(raw, games, const ['points', 'pts'], const ['points_per_game', 'ppg']);
    final rebounds = _total(raw, games, const ['rebounds', 'trb', 'reb'], const ['rebounds_per_game', 'rpg']);
    final offensiveRebounds = _total(raw, games, const ['offensive_rebounds', 'orb', 'oreb'], const ['offensive_rebounds_per_game', 'oreb_per_game']);
    final defensiveRebounds = _total(raw, games, const ['defensive_rebounds', 'drb', 'dreb'], const ['defensive_rebounds_per_game', 'dreb_per_game']);
    final assists = _total(raw, games, const ['assists', 'ast'], const ['assists_per_game', 'apg']);
    final steals = _total(raw, games, const ['steals', 'stl'], const ['steals_per_game', 'spg']);
    final blocks = _total(raw, games, const ['blocks', 'blk'], const ['blocks_per_game', 'bpg']);
    final turnovers = _total(raw, games, const ['turnovers', 'tov'], const ['turnovers_per_game', 'tov_per_game']);
    final fouls = _total(raw, games, const ['personal_fouls', 'pf'], const ['personal_fouls_per_game', 'pf_per_game']);
    final plusMinus = _total(raw, games, const ['plus_minus'], const ['plus_minus_per_game']);
    final fgm = _total(raw, games, const ['field_goals_made', 'fg', 'fgm'], const ['field_goals_made_per_game', 'fgm_per_game']);
    final fga = _total(raw, games, const ['field_goal_attempts', 'fga'], const ['field_goal_attempts_per_game', 'fga_per_game']);
    final threePm = _total(raw, games, const ['three_pointers_made', 'fg3', 'fg3m', 'three_pm'], const ['three_pointers_made_per_game', 'fg3m_per_game', 'three_pm_per_game']);
    final threePa = _total(raw, games, const ['three_point_attempts', 'fg3a', 'three_pa'], const ['three_point_attempts_per_game', 'fg3a_per_game', 'three_pa_per_game']);
    final ftm = _total(raw, games, const ['free_throws_made', 'ft', 'ftm'], const ['free_throws_made_per_game', 'ftm_per_game']);
    final fta = _total(raw, games, const ['free_throw_attempts', 'fta'], const ['free_throw_attempts_per_game', 'fta_per_game']);
    final directPossessions = _number(_first(raw, const ['possessions', 'poss', 'estimated_possessions']));
    var possessions = directPossessions ?? math.max(0.0, fga + .44 * fta - offensiveRebounds + turnovers).toDouble();
    var possessionsEstimated = directPossessions == null;
    if (possessions <= 0 && minutesTotal > 0) {
      possessions = minutesTotal * 2.05;
      possessionsEstimated = true;
    }

    final scale = switch (basis) {
      NbaStatsBasis.totals => 1.0,
      NbaStatsBasis.perGame => games > 0 ? 1 / games : 0.0,
      NbaStatsBasis.per36 => minutesTotal > 0 ? 36 / minutesTotal : 0.0,
      NbaStatsBasis.per48 => minutesTotal > 0 ? 48 / minutesTotal : 0.0,
      NbaStatsBasis.per75 => possessions > 0 ? 75 / possessions : 0.0,
      NbaStatsBasis.per100 => possessions > 0 ? 100 / possessions : 0.0,
    };
    final minuteScale = basis == NbaStatsBasis.totals ? 1.0 : scale;
    final twoPm = math.max(0.0, fgm - threePm).toDouble();
    final twoPa = math.max(0.0, fga - threePa).toDouble();
    final shootingPossessions = fga + .44 * fta;
    final fgPct = _ratioOrSource(raw, fgm, fga, const ['fg_pct', 'field_goal_pct', 'avg_fg_pct']);
    final threePct = _ratioOrSource(raw, threePm, threePa, const ['three_point_pct', 'three_pct', 'fg3_pct', 'avg_fg3_pct']);
    final ftPct = _ratioOrSource(raw, ftm, fta, const ['free_throw_pct', 'ft_pct', 'avg_ft_pct']);
    final bpm = _number(_first(raw, const ['avg_bpm', 'bpm', 'box_plus_minus']));

    double scaled(double value) => value * scale;

    return NbaStatsRow(
      playerId: _display(_first(raw, const ['player_id', 'id', 'slug'])),
      player: _display(_first(raw, const ['player_label', 'player', 'name'])),
      team: _display(_first(raw, const ['team_ids', 'team_id', 'team'])),
      position: _position(raw, profile),
      values: {
        'gp': games,
        'min': minutesTotal * minuteScale,
        'age': _number(_first(raw, const ['age'])) ?? _number(_first(profile, const ['age'])),
        'pts': scaled(points),
        'ast': scaled(assists),
        'reb': scaled(rebounds),
        'oreb': scaled(offensiveRebounds),
        'dreb': scaled(defensiveRebounds),
        'stl': scaled(steals),
        'blk': scaled(blocks),
        'tov': scaled(turnovers),
        'pf': scaled(fouls),
        'fgm': scaled(fgm),
        'fga': scaled(fga),
        'fg_pct': fgPct,
        'two_pm': scaled(twoPm),
        'two_pa': scaled(twoPa),
        'two_pct': _ratio(twoPm, twoPa),
        'three_pm': scaled(threePm),
        'three_pa': scaled(threePa),
        'three_pct': threePct,
        'ftm': scaled(ftm),
        'fta': scaled(fta),
        'ft_pct': ftPct,
        'ts_pct': _ratio(points, 2 * shootingPossessions),
        'efg_pct': _ratio(fgm + .5 * threePm, fga),
        'points_per_shot': _ratio(points, shootingPossessions),
        'ast_tov': turnovers > 0 ? assists / turnovers : (assists > 0 ? assists : null),
        'three_rate': _ratio(threePa, fga),
        'ft_rate': _ratio(fta, fga),
        'plus_minus': scaled(plusMinus),
        'bpm': bpm,
        'game_score_proxy': scaled(points + .7 * rebounds + .7 * assists + steals + blocks - .7 * turnovers),
        'stocks': scaled(steals + blocks),
        'defense_events': scaled(steals + blocks + .35 * defensiveRebounds),
        'possessions_proxy': basis == NbaStatsBasis.totals ? possessions : possessions * scale,
        'scoring_load': _ratio(shootingPossessions, possessions),
      },
      percentiles: const {},
      raw: raw,
      possessionsEstimated: possessionsEstimated,
    );
  }

  List<NbaStatsRow> _attachPercentiles(List<NbaStatsRow> rows) {
    if (rows.isEmpty) return rows;
    final byPlayer = <String, Map<String, double>>{for (final row in rows) row.playerId: <String, double>{}};
    for (final metric in nbaStatMetrics) {
      final entries = <MapEntry<String, double>>[];
      for (final row in rows) {
        final value = row.value(metric.key);
        if (value != null && value.isFinite) entries.add(MapEntry(row.playerId, value));
      }
      entries.sort((a, b) => a.value.compareTo(b.value));
      if (entries.isEmpty) continue;
      for (var index = 0; index < entries.length; index++) {
        final base = entries.length == 1 ? 100.0 : index / (entries.length - 1) * 100;
        byPlayer[entries[index].key]![metric.key] = metric.higherIsBetter ? base : 100 - base;
      }
    }
    return [for (final row in rows) row.withPercentiles(byPlayer[row.playerId] ?? const {})];
  }
}

Object? _first(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) return value;
  }
  return null;
}

double _total(Map<String, dynamic> row, double games, List<String> totalKeys, List<String> perGameKeys) {
  final total = _number(_first(row, totalKeys));
  if (total != null) return total;
  final perGame = _number(_first(row, perGameKeys));
  if (perGame != null) return perGame * games;
  return 0;
}

double? _ratioOrSource(Map<String, dynamic> row, double numerator, double denominator, List<String> sourceKeys) {
  final source = _number(_first(row, sourceKeys));
  if (source != null) return source > 1 ? source / 100 : source;
  return _ratio(numerator, denominator);
}

double? _ratio(double numerator, double denominator) {
  if (denominator <= 0) return null;
  return numerator / denominator;
}

double? _number(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '').replaceAll('%', '').trim());
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _display(Object? value) {
  final text = _text(value);
  return text.isEmpty ? '—' : text;
}

String _position(Map<String, dynamic> raw, Map<String, dynamic> profile) {
  final source = _text(_first(raw, const ['positions', 'position', 'pos', 'primary_position'])).isNotEmpty
      ? _text(_first(raw, const ['positions', 'position', 'pos', 'primary_position']))
      : _text(_first(profile, const ['positions', 'position', 'pos', 'primary_position', 'position_abbrev']));
  if (source.isEmpty) return '—';
  final upper = source.toUpperCase()
      .replaceAll('POINT GUARD', 'PG')
      .replaceAll('SHOOTING GUARD', 'SG')
      .replaceAll('SMALL FORWARD', 'SF')
      .replaceAll('POWER FORWARD', 'PF')
      .replaceAll('CENTER', 'C');
  final positions = <String>[];
  for (final candidate in const ['PG', 'SG', 'SF', 'PF', 'C']) {
    if (RegExp('(^|[^A-Z])$candidate([^A-Z]|\$)').hasMatch(upper) && !positions.contains(candidate)) {
      positions.add(candidate);
    }
  }
  if (positions.isNotEmpty) return positions.join(', ');
  return source;
}
