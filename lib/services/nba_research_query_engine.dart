import 'nba_stats_workstation_engine.dart';
import 'website_nba_api_service.dart';

/// A deliberately narrow, deterministic query layer over Arcside static data.
///
/// It is not ChatGPT, does not call any AI service and cannot answer questions
/// beyond the published NBA player-season corpus.
class ArcsideResearchHit {
  const ArcsideResearchHit({
    required this.name,
    required this.team,
    required this.value,
    required this.detail,
  });

  final String name;
  final String team;
  final String value;
  final String detail;
}

class ArcsideResearchAnswer {
  const ArcsideResearchAnswer({
    required this.title,
    required this.message,
    required this.source,
    this.hits = const [],
    this.supported = true,
  });

  final String title;
  final String message;
  final String source;
  final List<ArcsideResearchHit> hits;
  final bool supported;
}

class ArcsideResearchQueryEngine {
  const ArcsideResearchQueryEngine({WebsiteNbaApiService api = const WebsiteNbaApiService()})
      : _api = api;

  final WebsiteNbaApiService _api;
  static const _stats = NbaStatsWorkstationEngine();

  /// Keeps all data retrieval same-origin and confined to one historical shard.
  Future<ArcsideResearchAnswer> ask(
    String question, {
    required String defaultSeason,
    required bool defaultPlayoffs,
  }) async {
    final prompt = question.trim();
    if (prompt.isEmpty || prompt.length > 180) {
      return const ArcsideResearchAnswer(
        title: 'Query needs adjusting',
        message: 'Enter one NBA statistics question of at most 180 characters.',
        source: 'Arcside query rules',
        supported: false,
      );
    }
    final explicitSeason = RegExp(r'\b(?:19|20)\d\d-\d\d\b').firstMatch(prompt);
    final season = explicitSeason?.group(0) ?? defaultSeason;
    final lower = prompt.toLowerCase();
    final playoffs = lower.contains('playoff') || lower.contains('postseason')
        ? true
        : (lower.contains('regular season') ? false : defaultPlayoffs);
    final source = '$season · ${playoffs ? 'Playoffs' : 'Regular Season'} · Arcside historical NBA corpus';
    try {
      final seasons = await _api.seasons();
      if (!seasons.any((item) => item.id == season)) {
        return ArcsideResearchAnswer(
          title: 'Season unavailable',
          message: 'The $season season is not in the published historical NBA index.',
          source: source,
          supported: false,
        );
      }
      final snapshot = await _api.seasonSnapshot(
        season, seasonType: playoffs ? 'playoffs' : 'regular');
      final rows = _stats.buildRows(
        snapshot,
        seasonType: playoffs
            ? NbaStatsSeasonType.playoffs
            : NbaStatsSeasonType.regular,
      );
      return answerFromRows(
        prompt, rows, season: season, playoffs: playoffs);
    } catch (_) {
      return ArcsideResearchAnswer(
        title: 'Source data unavailable',
        message: 'This historical season has not been published or cannot be read. No answer has been invented.',
        source: source,
        supported: false,
      );
    }
  }

  /// Pure, source-backed resolution: also exercised with test season fixtures.
  static ArcsideResearchAnswer answerFromRows(
    String question,
    List<NbaStatsRow> rows, {
    required String season,
    required bool playoffs,
  }) {
    final query = question.toLowerCase().trim();
    final source = '$season · ${playoffs ? 'Playoffs' : 'Regular Season'} · Arcside historical NBA corpus';
    if (query.isEmpty || query.length > 180) {
      return ArcsideResearchAnswer(
        title: 'Query too long',
        message: 'Use one question with no more than 180 characters.',
        source: source,
        supported: false,
      );
    }
    if (rows.isEmpty) {
      return ArcsideResearchAnswer(
        title: 'No source records',
        message: 'No player-season rows are available for this season and segment.',
        source: source,
        supported: false,
      );
    }
    final metric = _metricFor(query);
    final wantsTotals = RegExp(r'\b(total|totals|combined total)\b').hasMatch(query);
    final basis = wantsTotals ? NbaStatsBasis.totals : NbaStatsBasis.perGame;
    final leaderboard = RegExp(
      r'\b(top|leaders?|leading|highest|most|best|rankings?|ranked|who led|who leads)\b',
    ).hasMatch(query);
    final minGames = playoffs ? 4.0 : 50.0;

    if (leaderboard) {
      if (metric == null) return _unsupported(source);
      final requested = RegExp(r'\btop\s+(\d{1,2})\b').firstMatch(query);
      final count = requested == null
          ? (query.contains('who ') ? 1 : 5)
          : (int.tryParse(requested.group(1)!) ?? 5).clamp(1, 10).toInt();
      final eligible = rows.where((row) {
        final gp = row.value('gp') ?? 0;
        final value = _value(row, metric);
        return gp >= minGames && value != null && value.isFinite;
      }).toList()
        ..sort((left, right) {
          final leftValue = _value(left, metric)!;
          final rightValue = _value(right, metric)!;
          final comparison = rightValue.compareTo(leftValue);
          return comparison != 0 ? comparison : left.player.compareTo(right.player);
        });
      if (eligible.isEmpty) {
        return ArcsideResearchAnswer(
          title: 'No qualifying player rows',
          message: 'No players with at least ${minGames.toInt()} games have this statistic in the available records.',
          source: source,
          supported: false,
        );
      }
      final titleMetric = _metricName(metric, totals: wantsTotals);
      final selected = eligible.take(count).toList();
      return ArcsideResearchAnswer(
        title: 'Top ${selected.length} · $titleMetric',
        message: 'Ranked within $season ${playoffs ? 'playoffs' : 'regular season'}. Minimum ${minGames.toInt()} games. ${wantsTotals ? 'Season totals' : 'Per-game figures or source percentages'} shown.',
        source: source,
        hits: [
          for (final row in selected)
            ArcsideResearchHit(
              name: row.player,
              team: row.team,
              value: _display(metric, _value(row, metric)),
              detail: '${(row.value('gp') ?? 0).round()} GP',
            ),
        ],
      );
    }

    // Require an unambiguous full player name. Surname-only prompts often
    // collide across eras (e.g. Curry), so never guess which player was meant.
    final matches = rows.where((row) {
      final name = row.player.toLowerCase().trim();
      if (name.isEmpty || name == '—') return false;
      final escaped = RegExp.escape(name);
      return RegExp('(^|[^a-z])$escaped([^a-z]|$)').hasMatch(query);
    }).toList();
    if (matches.length != 1) {
      return ArcsideResearchAnswer(
        title: matches.isEmpty ? 'Specify a player or leaderboard' : 'Ambiguous player',
        message: matches.isEmpty
            ? 'Try a full player name and season (e.g. Stephen Curry 2015-16 stats) or ask for the top five in points, assists, rebounds or TS%.'
            : 'Several records match this name. Be more specific.',
        source: source,
        supported: false,
      );
    }
    final player = matches.single;
    if (metric != null) {
      final value = _value(player, metric, basis: basis);
      if (value == null || !value.isFinite) {
        return ArcsideResearchAnswer(
          title: '${player.player} · Unavailable metric',
          message: '${_metricName(metric, totals: wantsTotals)} is not available from the published season data.',
          source: source,
          supported: false,
        );
      }
      return ArcsideResearchAnswer(
        title: '${player.player} · ${_metricName(metric, totals: wantsTotals)}',
        message: '${player.player} (${player.team}) recorded ${_display(metric, value)} ${_metricName(metric, totals: wantsTotals).toLowerCase()} in $season ${playoffs ? 'playoffs' : 'regular season'}.',
        source: source,
        hits: [
          ArcsideResearchHit(
            name: player.player,
            team: player.team,
            value: _display(metric, value),
            detail: '${(player.value('gp') ?? 0).round()} GP',
          ),
        ],
      );
    }

    const profileMetrics = <(String, String)>[
      ('GP', 'gp'), ('PPG', 'pts'), ('RPG', 'reb'),
      ('APG', 'ast'), ('SPG', 'stl'), ('BPG', 'blk'),
      ('TS%', 'ts_pct'), ('3P%', 'three_pct'),
    ];
    return ArcsideResearchAnswer(
      title: '${player.player} · Season snapshot',
      message: '${player.team} · $season ${playoffs ? 'playoffs' : 'regular season'} · Per-game statistics unless stated otherwise.',
      source: source,
      hits: [
        for (final item in profileMetrics)
          if (_value(player, item.$2) case final double value when value.isFinite)
            ArcsideResearchHit(
              name: item.$1,
              team: '',
              value: _display(item.$2, value),
              detail: '',
            ),
      ],
    );
  }

  static double? _value(
    NbaStatsRow row, String key, {
    NbaStatsBasis basis = NbaStatsBasis.perGame,
  }) {
    if (basis == NbaStatsBasis.totals &&
        const {'pts', 'reb', 'ast', 'stl', 'blk', 'tov'}.contains(key)) {
      final games = row.value('gp');
      final perGame = row.value(key);
      if (games == null || perGame == null) return null;
      return games * perGame;
    }
    return row.value(key);
  }

  static String _display(String key, double? value) =>
      _stats.formatValue(key, value);

  static String? _metricFor(String prompt) {
    const patterns = <(String, String)>[
      ('true shooting', 'ts_pct'),
      ('ts%', 'ts_pct'),
      ('effective field goal', 'efg_pct'),
      ('efg%', 'efg_pct'),
      ('three-point percentage', 'three_pct'),
      ('three point percentage', 'three_pct'),
      ('3p%', 'three_pct'),
      ('3pt%', 'three_pct'),
      ('free throw percentage', 'ft_pct'),
      ('ft%', 'ft_pct'),
      ('field goal percentage', 'fg_pct'),
      ('fg%', 'fg_pct'),
      ('box plus minus', 'bpm'),
      ('bpm', 'bpm'),
      ('turnover', 'tov'),
      ('tpg', 'tov'),
      ('offensive rebound', 'oreb'),
      ('defensive rebound', 'dreb'),
      ('rebound', 'reb'),
      ('rpg', 'reb'),
      ('assist', 'ast'),
      ('apg', 'ast'),
      ('steal', 'stl'),
      ('spg', 'stl'),
      ('block', 'blk'),
      ('bpg', 'blk'),
      ('point', 'pts'),
      ('scor', 'pts'),
      ('ppg', 'pts'),
    ];
    for (final entry in patterns) {
      if (prompt.contains(entry.$1)) return entry.$2;
    }
    return null;
  }

  static String _metricName(String key, {required bool totals}) {
    if (totals && const {'pts', 'reb', 'ast', 'stl', 'blk', 'tov'}.contains(key)) {
      return const {
        'pts': 'Total points', 'reb': 'Total rebounds', 'ast': 'Total assists',
        'stl': 'Total steals', 'blk': 'Total blocks', 'tov': 'Total turnovers',
      }[key]!;
    }
    return const {
      'pts': 'Points per game', 'reb': 'Rebounds per game',
      'ast': 'Assists per game', 'stl': 'Steals per game',
      'blk': 'Blocks per game', 'tov': 'Turnovers per game',
      'oreb': 'Offensive rebounds per game',
      'dreb': 'Defensive rebounds per game',
      'ts_pct': 'TS%', 'efg_pct': 'eFG%', 'three_pct': '3P%',
      'ft_pct': 'FT%', 'fg_pct': 'FG%', 'bpm': 'BPM', 'gp': 'GP',
    }[key] ?? key;
  }

  static ArcsideResearchAnswer _unsupported(String source) =>
      ArcsideResearchAnswer(
        title: 'Unsupported research question',
        message: 'Ask for a specific NBA statistic: points, rebounds, assists, TS%, FG%, 3P%, FT%, BPM, steals, blocks or turnovers.',
        source: source,
        supported: false,
      );
}
