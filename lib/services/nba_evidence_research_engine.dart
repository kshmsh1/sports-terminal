import 'nba_stats_workstation_engine.dart';

/// Deterministic, read-only question planner. No LLM output is permitted to
/// invent a statistic: every numeric answer comes from NbaStatsRow values.
/// Advanced tracking, betting, live data and cross-season questions abstain.
enum NbaResearchIntent { leaderboard, unsupported }

class NbaResearchPlan {
  const NbaResearchPlan({
    required this.question,
    required this.season,
    required this.seasonType,
    required this.basis,
    required this.metric,
    required this.limit,
    required this.minGames,
    required this.descending,
    required this.intent,
    required this.explanation,
    this.minimumMetric,
  });

  final String question;
  final String season;
  final NbaStatsSeasonType seasonType;
  final NbaStatsBasis basis;
  final String metric;
  final int limit;
  final int minGames;
  final bool descending;
  final NbaResearchIntent intent;
  final String explanation;
  final double? minimumMetric;
  bool get supported => intent == NbaResearchIntent.leaderboard;

  String get sourcePath => 'seasons/$season/'
      '${seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular'}.json';
}

class NbaResearchFinding {
  const NbaResearchFinding({required this.row, required this.metricValue});
  final NbaStatsRow row;
  final double metricValue;
}

class NbaResearchAnswer {
  const NbaResearchAnswer({
    required this.plan,
    required this.findings,
    required this.evaluatedCount,
    required this.qualifiedCount,
  });

  final NbaResearchPlan plan;
  final List<NbaResearchFinding> findings;
  final int evaluatedCount;
  final int qualifiedCount;
  bool get hasResults => findings.isNotEmpty;
}

/// Whitelisted season-leaderboard questions with explicit coverage boundaries.
/// More complex query families can be added as separate, tested planners.
class NbaEvidenceResearchEngine {
  const NbaEvidenceResearchEngine();

  static const _metrics = <String, List<String>>{
    'three_pct': ['three-point percentage', '3-point percentage',
      'three point percentage', '3p%', '3pt%', '3pt percentage'],
    'fg_pct': ['field goal percentage', 'fg%', 'shooting percentage'],
    'ft_pct': ['free throw percentage', 'ft%'],
    'pts': ['points per game', 'points', 'ppg', 'pts', 'scoring'],
    'ast': ['assists per game', 'assists', 'apg', 'ast'],
    'reb': ['rebounds per game', 'rebounds', 'rpg', 'reb'],
    'stl': ['steals per game', 'steals', 'spg', 'stl'],
    'blk': ['blocks per game', 'blocks', 'bpg', 'blk'],
    'tov': ['turnovers per game', 'turnovers', 'tov'],
  };

  static const _unsupportedHints = <String, String>{
    'betting': 'Betting markets and historical odds are not present in the verified NBA season-statistics corpus.',
    'odds': 'Live or historical betting odds are not part of this source-backed query.',
    'prop': 'Player props require a separate verified market-data feed.',
    'tracking': 'Defender matchup and player-tracking data are not present in this season-level dataset.',
    'defender': 'Defender-specific matchup data requires tracking observations, not season averages.',
    'gravity': 'Basketball gravity requires a defined tracking model and source data.',
    'shot chart': 'Shot-location queries require event or tracking observations.',
    'lineup': 'Lineup and on/off questions require source-backed stint or play-by-play records.',
    'on/off': 'On/off questions require verified lineup stints rather than season averages.',
    'with and without': 'With/without questions require verified player-pair observations.',
    'clutch': 'Clutch splits require game/event timestamps and score context.',
    'play-by-play': 'Play-by-play analysis must run on possession-level source data.',
    'live': 'This research surface is historical and does not claim live feed availability.',
    'tonight': 'Tonight\'s games require current and verified live data.',
    'today': 'Current game data is not available in the historical snapshot.',
    'yesterday': 'Recent games require a current-season data layer.',
    'career': 'Career-wide research needs multi-season aggregation; this first query family is single-season.',
    'since ': 'Multi-season time windows are not yet implemented in this query family.',
    'video': 'Video and highlight licensing have not been integrated.',
    'clip': 'Video and highlight licensing have not been integrated.',
    'simulate': 'Forecasting and counterfactuals require validated simulation models.',
    'predict': 'Forecasting requires evaluated out-of-sample prediction models.',
  };

  NbaResearchPlan parse(String question, {required String defaultSeason}) {
    final normalized = question.toLowerCase()
      .replaceAll('–', '-').replaceAll('—', '-')
      .replaceAll(RegExp(r'\s+'), ' ').trim();
    final seasonMatch =
        RegExp(r'\b(?:19|20)\d{2}-\d{2}\b').firstMatch(normalized);
    final season = seasonMatch?.group(0) ?? defaultSeason;
    final playoffs = RegExp(r'\b(playoffs?|postseason)\b')
        .hasMatch(normalized);
    final seasonType = playoffs
        ? NbaStatsSeasonType.playoffs : NbaStatsSeasonType.regular;
    final basis = normalized.contains('per 100') ? NbaStatsBasis.per100
        : normalized.contains('per 75') ? NbaStatsBasis.per75
        : normalized.contains('per 48') ? NbaStatsBasis.per48
        : normalized.contains('per 36') ? NbaStatsBasis.per36
        : normalized.contains('total') ? NbaStatsBasis.totals
        : NbaStatsBasis.perGame;
    NbaResearchPlan unsupported(String why) => NbaResearchPlan(
      question: question, season: season, seasonType: seasonType,
      basis: basis, metric: '', limit: 0, minGames: 0, descending: true,
      intent: NbaResearchIntent.unsupported, explanation: why,
    );

    if (normalized.isEmpty) return unsupported('Enter a sports research question.');
    if (normalized.contains('regular season and playoffs') ||
        normalized.contains('both regular and playoffs')) {
      return unsupported('Regular season and playoffs must be queried separately.');
    }
    if (normalized.contains(' vs ') || normalized.contains('versus')) {
      return unsupported('Head-to-head comparisons are not part of this single-season leaderboard query.');
    }
    for (final hint in _unsupportedHints.entries) {
      if (normalized.contains(hint.key)) return unsupported(hint.value);
    }

    final metricCandidates = <({String key, int offset, int length})>[];
    for (final entry in _metrics.entries) {
      for (final alias in entry.value) {
        final match = RegExp('(?<![a-z])${RegExp.escape(alias)}(?![a-z])')
            .firstMatch(normalized);
        if (match != null) {
          metricCandidates.add((key: entry.key, offset: match.start,
              length: alias.length));
        }
      }
    }
    metricCandidates.sort((a, b) {
      final start = a.offset.compareTo(b.offset);
      return start != 0 ? start : b.length.compareTo(a.length);
    });
    if (metricCandidates.isEmpty) {
      return unsupported('This question does not identify a supported season statistic. '
        'Try points, assists, rebounds, blocks, steals, or a shooting percentage.');
    }
    if (!RegExp(r'\b(top|leaders?|leading|led|most|highest|lowest|fewest|best|rank|ranking)\b')
        .hasMatch(normalized)) {
      return unsupported('For now, ask a ranking question such as "Top 10 players in assists in 2025-26".');
    }

    final metric = metricCandidates.first.key;
    // Never silently discard a numeric filter against another statistic.
    // Unsupported comparisons must abstain instead of overstating the cohort.
    for (final match in RegExp(
      r'\b(?:at least|minimum of|over|under|less than|more than)\s+\d+(?:\.\d+)?\s+([a-z0-9%\-]+)',
    ).allMatches(normalized)) {
      final word = match.group(1)!;
      final leading = match.group(0)!.split(RegExp(r'\s+')).first;
      if (leading == 'over' || leading == 'under' ||
          leading == 'less' || leading == 'more') {
        return unsupported('Strict numeric inequalities are not implemented for this query family.');
      }
      final gamesToken = word == 'games' || word == 'game' || word == 'gp';
      final metricToken = _metrics[metric]!.any(
        (alias) => alias.startsWith(word) || alias == word,
      );
      if (!gamesToken && !metricToken) {
        return unsupported('Additional statistic thresholds require a multi-metric query planner. '
            'This query would otherwise silently omit a filter.');
      }
    }
    final limitMatch = RegExp(r'\btop\s+(\d+)\b')
        .firstMatch(normalized);
    final limit = (int.tryParse(limitMatch?.group(1) ?? '') ?? 10)
        .clamp(1, 50);
    final gamesMatch = RegExp(r'\b(?:at least|minimum|with)\s+(\d+)\s+(?:games|gp)\b')
        .firstMatch(normalized);
    final minGames = (int.tryParse(gamesMatch?.group(1) ?? '') ??
        (playoffs ? 4 : 10)).clamp(1, 100);
    final descending = !RegExp(r'\b(lowest|fewest|least)\b')
        .hasMatch(normalized);

    double? minimumMetric;
    final aliasPattern = _metrics[metric]!
      .map(RegExp.escape).join('|');
    final thresholdMatch = RegExp(
      '(?:at least|minimum of|over)\\s+(\\d+(?:\\.\\d+)?)\\s+(?:$aliasPattern)(?![a-z])',
    ).firstMatch(normalized);
    if (thresholdMatch != null) {
      minimumMetric = double.tryParse(thresholdMatch.group(1)!);
    }

    return NbaResearchPlan(
      question: question, season: season, seasonType: seasonType,
      basis: basis, metric: metric, limit: limit,
      minGames: minGames, descending: descending,
      minimumMetric: minimumMetric,
      intent: NbaResearchIntent.leaderboard,
      explanation: 'Single-season player leaderboard, based on available '
        'source-backed player-season rows. Ties are broken by games played.',
    );
  }

  NbaResearchAnswer execute(
    NbaResearchPlan plan,
    List<NbaStatsRow> rows,
  ) {
    if (!plan.supported) {
      return NbaResearchAnswer(
        plan: plan, findings: const [], evaluatedCount: 0, qualifiedCount: 0,
      );
    }
    final unique = <String, NbaStatsRow>{};
    for (final row in rows) {
      if (row.playerId.isEmpty) continue;
      final previous = unique[row.playerId];
      if (previous == null ||
          _combinedTeam(row.team) && !_combinedTeam(previous.team) ||
          _combinedTeam(row.team) == _combinedTeam(previous.team) &&
          (row.value('gp') ?? 0) > (previous.value('gp') ?? 0)) {
        unique[row.playerId] = row;
      }
    }
    final qualifies = <NbaResearchFinding>[];
    for (final row in unique.values) {
      final games = row.value('gp');
      final value = row.value(plan.metric);
      if (games == null || !games.isFinite || games < plan.minGames ||
          value == null || !value.isFinite ||
          (plan.minimumMetric != null && value < plan.minimumMetric!)) continue;
      qualifies.add(NbaResearchFinding(row: row, metricValue: value));
    }
    qualifies.sort((a, b) {
      final result = a.metricValue.compareTo(b.metricValue);
      if (result != 0) return plan.descending ? -result : result;
      final games = (b.row.value('gp') ?? 0).compareTo(a.row.value('gp') ?? 0);
      return games != 0 ? games : a.row.player.compareTo(b.row.player);
    });
    return NbaResearchAnswer(
      plan: plan, evaluatedCount: unique.length,
      qualifiedCount: qualifies.length,
      findings: qualifies.take(plan.limit).toList(growable: false),
    );
  }

  static bool _combinedTeam(String team) =>
      team.contains('TOT') || RegExp(r'\b\d+TM\b').hasMatch(team);
}
