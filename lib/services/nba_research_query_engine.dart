import 'nba_stats_metric_catalog.dart';
import 'nba_stats_workstation_engine.dart';
import 'website_nba_api_service.dart';

/// One display row backed by a value in the published Arcside corpus.
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

/// Runs exclusively in the visitor's browser and uses only Arcside's same-origin
/// static data facade. No AI service, proxy, authentication, remote search,
/// paid API, prompt execution, or arbitrary URL access exists here.
class ArcsideResearchQueryEngine {
  const ArcsideResearchQueryEngine({
    WebsiteNbaApiService api = const WebsiteNbaApiService(),
  }) : _api = api;

  /// A generous input-size safety bound, not a paid-inference token budget.
  static const maxQuestionChars = 4096;

  final WebsiteNbaApiService _api;
  static const _stats = NbaStatsWorkstationEngine();
  static const _catalog = NbaTerminalMetricResolver();

  static String _normal(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9%]+'), ' ').trim();

  static bool _has(String text, String phrase) =>
      (' ${_normal(text)} ').contains(' ${_normal(phrase)} ');

  static String? _seasonIn(String query) =>
      RegExp(r'\b((?:19|20)\d{2}-\d{2})(?!-\d{2})\b')
          .firstMatch(query)?.group(1);

  static String _source(String label) => 'Arcside published NBA corpus · $label';

  static ArcsideResearchAnswer _notFound(String title, String message,
      String source) => ArcsideResearchAnswer(
        title: title, message: message, source: source, supported: false);

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  /// Every branch below reads only a published Arcside static resource. The
  /// input is interpreted as query intent; it is never executable content.
  Future<ArcsideResearchAnswer> ask(
    String question, {
    required String defaultSeason,
    required bool defaultPlayoffs,
  }) async {
    final prompt = question.trim();
    if (prompt.isEmpty || prompt.length > maxQuestionChars) {
      return _notFound('Query needs adjusting',
          'Enter a question with at most $maxQuestionChars characters.',
          _source('Query rules'));
    }
    final q = prompt.toLowerCase();
    final season = _seasonIn(q) ?? defaultSeason;
    final playoffs = _has(q, 'playoffs') || _has(q, 'playoff') ||
            _has(q, 'postseason')
        ? true : (_has(q, 'regular season') ? false : defaultPlayoffs);
    final context = '$season · ${playoffs ? 'Playoffs' : 'Regular Season'}';
    final source = _source(context);

    try {
      // Only supported data domains may be loaded; never pass user-provided
      // resource paths, URLs or endpoint names to the static loader.
      if (_isGameQuery(q)) return await _gamesQuery(q, season);
      if (_isDraftQuery(q)) return await _draftQuery(q);
      if (_isAwardsQuery(q)) return await _awardsQuery(q, season);
      if (_isAllStarQuery(q)) return await _allStarQuery(q, season);
      final seasons = await _api.seasons();
      if (!seasons.any((s) => s.id == season)) {
        return _notFound('Season unavailable',
            'Season $season is not published in Arcside.', source);
      }
      final snapshot = await _api.seasonSnapshot(
          season, seasonType: playoffs ? 'playoffs' : 'regular');
      if (_isTeamQuery(q)) {
        return teamAnswerFromRecords(q, snapshot.teamRecords,
            teams: snapshot.teams, season: season, playoffs: playoffs);
      }
      final basis = _basisFrom(q);
      final rows = _stats.buildRows(snapshot, basis: basis,
          seasonType: playoffs
              ? NbaStatsSeasonType.playoffs
              : NbaStatsSeasonType.regular);
      return answerFromRows(prompt, rows,
          season: season, playoffs: playoffs, basis: basis);
    } catch (_) {
      return _notFound('Source data unavailable',
        'The requested Arcside dataset is not published or could not be read. '
        'No alternative source or generated answer was substituted.',
        source);
    }
  }

  static bool _isGameQuery(String q) =>
      _has(q, 'box scores') || _has(q, 'box score') ||
      _has(q, 'games on') || _has(q, 'game on') ||
      _has(q, 'scores on') || _has(q, 'games played') ||
      _has(q, 'final scores') || _has(q, 'game results');

  static bool _isDraftQuery(String q) =>
      RegExp(r'\bdraft\b|\bdrafted\b|\bdraft picks\b').hasMatch(q);

  static bool _isAwardsQuery(String q) => _has(q, 'mvp') ||
      _has(q, 'most valuable player') || _has(q, 'rookie of the year') ||
      _has(q, 'defensive player of the year') ||
      _has(q, 'sixth man') || _has(q, 'most improved') ||
      _has(q, 'nba awards');

  static bool _isAllStarQuery(String q) =>
      _has(q, 'all star selections') || _has(q, 'all stars') ||
      _has(q, 'all-star selections');

  static bool _isTeamQuery(String q) =>
      _has(q, 'team standings') || _has(q, 'standings') ||
      _has(q, 'team wins') || _has(q, 'team losses') ||
      _has(q, 'team win percentage') || _has(q, 'teams by') ||
      _has(q, 'best teams') || _has(q, 'worst teams') ||
      _has(q, 'team ortg') || _has(q, 'team drtg') ||
      _has(q, 'team srs') || _has(q, 'team pace');

  static NbaStatsBasis _basisFrom(String q) {
    if (_has(q, 'per 36')) return NbaStatsBasis.per36;
    if (_has(q, 'per 48')) return NbaStatsBasis.per48;
    if (_has(q, 'per 75')) return NbaStatsBasis.per75;
    if (_has(q, 'per 100')) return NbaStatsBasis.per100;
    return NbaStatsBasis.perGame;
  }

  Future<ArcsideResearchAnswer> _gamesQuery(String q, String season) async {
    final date = RegExp(r'\b(?:19|20)\d{2}-\d{2}-\d{2}\b')
        .firstMatch(q)?.group(0);
    if (date == null && _seasonIn(q) == null) {
      return _notFound('Specify a game date or season',
        'Use "games on 2023-06-12" or "2022-23 game results".',
        _source('Historical game index'));
    }
    final games = await _api.games(
        season: date == null ? season : null);
    final selected = games.where((row) =>
        date == null ||
        (row['game_date']?.toString().startsWith(date) ?? false)).toList()
      ..sort((a, b) => (a['game_date']?.toString() ?? '')
          .compareTo(b['game_date']?.toString() ?? ''));
    if (selected.isEmpty) return _notFound('No published games',
      'Arcside has no recorded games for ${date ?? season}.',
      _source('Historical game index'));
    return ArcsideResearchAnswer(
      title: '${selected.length} games · ${date ?? season}',
      message: 'Final scores are shown when the static game index records both scores. '
          'Unpublished or incomplete games are not inferred.',
      source: _source('Historical game index · ${date ?? season}'),
      hits: [
        for (final row in selected)
          ArcsideResearchHit(
            name: '${row['away_team_name'] ?? row['away_team_abbreviation'] ?? 'Away'} @ '
                '${row['home_team_name'] ?? row['home_team_abbreviation'] ?? 'Home'}',
            team: row['game_date']?.toString().split(' ').first ?? '',
            value: row['away_score'] == null || row['home_score'] == null
                ? '—'
                : '${row['away_score']} – ${row['home_score']}',
            detail: row['season_type']?.toString() ?? '',
          ),
      ],
    );
  }

  Future<ArcsideResearchAnswer> _draftQuery(String q) async {
    final year = RegExp(r'\b(?:19|20)\d{2}\b').firstMatch(q)?.group(0);
    if (year == null) return _notFound('Specify a draft year',
        'Try "2018 NBA draft picks".', _source('NBA draft index'));
    final all = await _api.draft();
    final results = all.where((row) =>
        row['draft_year']?.toString() == year).toList()
      ..sort((a, b) => (_number(a['pick_number']) ?? 999)
          .compareTo(_number(b['pick_number']) ?? 999));
    if (results.isEmpty) return _notFound('Draft records unavailable',
      'No $year draft picks were published in the Arcside corpus.',
      _source('NBA draft index · $year'));
    return ArcsideResearchAnswer(
      title: '$year NBA draft · ${results.length} picks',
      message: 'Recorded draft picks ordered by overall pick number.',
      source: _source('NBA draft index · $year'),
      hits: [
        for (final row in results)
          ArcsideResearchHit(
            name: row['player_name']?.toString() ?? 'Unknown player',
            team: row['drafting_team_text']?.toString() ?? '',
            value: row['pick_number'] == null
                ? '—' : '#${(_number(row['pick_number']) ?? 0).round()}',
            detail: row['round_text']?.toString() ?? '',
          ),
      ],
    );
  }

  Future<ArcsideResearchAnswer> _awardsQuery(String q, String season) async {
    String needle;
    if (_has(q, 'rookie of the year')) {
      needle = 'rookie';
    } else if (_has(q, 'defensive player of the year')) {
      needle = 'defensive player';
    } else if (_has(q, 'sixth man')) {
      needle = 'sixth man';
    } else if (_has(q, 'most improved')) {
      needle = 'most improved';
    } else if (_has(q, 'mvp') || _has(q, 'most valuable player')) {
      needle = 'mvp';
    } else {
      needle = '';
    }
    final all = await _api.awards();
    final results = all.where((row) {
      if (row['season_id']?.toString() != season) return false;
      final name = (row['award'] ?? '').toString().toLowerCase();
      if (needle.isNotEmpty && !name.contains(needle) &&
          !(needle == 'mvp' && name.contains('most valuable player'))) {
        return false;
      }
      if (needle == 'mvp' && !_has(q, 'finals') &&
          name.contains('finals')) return false;
      final winner = row['winner'];
      return winner == true || winner == 1 ||
          winner?.toString().toLowerCase() == 'true';
    }).toList();
    if (results.isEmpty) return _notFound('Award not available',
      'Arcside has no published winning award record matching this request for $season.',
      _source('NBA awards · $season'));
    return ArcsideResearchAnswer(
      title: '$season · NBA awards',
      message: 'Only recorded award winners are included.',
      source: _source('NBA awards · $season'),
      hits: [
        for (final row in results)
          ArcsideResearchHit(
            name: row['player_name']?.toString() ?? 'Unknown player',
            team: row['award']?.toString() ?? '',
            value: 'Winner',
            detail: '',
          ),
      ],
    );
  }

  Future<ArcsideResearchAnswer> _allStarQuery(
      String q, String season) async {
    final rows = (await _api.allStar())
        .where((row) => row['season_id']?.toString() == season).toList();
    if (rows.isEmpty) return _notFound('All-Star data unavailable',
      'Arcside has no published All-Star records for $season.',
      _source('All-Star history · $season'));
    return ArcsideResearchAnswer(
      title: '$season · All-Star records',
      message: 'Selections recorded in the published historical database.',
      source: _source('All-Star history · $season'),
      hits: [
        for (final row in rows)
          ArcsideResearchHit(
            name: row['player_name']?.toString() ?? 'Unknown player',
            team: row['team']?.toString() ?? '',
            value: row['starter'] == true || row['starter'] == 1
                ? 'Starter' : 'Selected',
            detail: '',
          ),
      ],
    );
  }

  /// Team standings and ranks use source-provided team-season records only.
  static ArcsideResearchAnswer teamAnswerFromRecords(
    String question,
    List<Map<String, dynamic>> records, {
    required List<Map<String, dynamic>> teams,
    required String season,
    required bool playoffs,
  }) {
    final q = question.toLowerCase();
    final source = _source('$season · Team seasons · ${playoffs ? 'Playoffs' : 'Regular Season'}');
    String key = 'wins';
    String label = 'Wins';
    if (_has(q, 'losses')) { key = 'losses'; label = 'Losses'; }
    else if (_has(q, 'win percentage') || _has(q, 'win pct') ||
        _has(q, 'win%')) { key = 'win_pct'; label = 'Win%'; }
    else if (_has(q, 'ortg') || _has(q, 'offensive rating')) {
      key = 'offensive_rating'; label = 'ORTG';
    } else if (_has(q, 'drtg') || _has(q, 'defensive rating')) {
      key = 'defensive_rating'; label = 'DRTG';
    } else if (_has(q, 'srs')) { key = 'srs'; label = 'SRS'; }
    else if (_has(q, 'pace')) { key = 'pace'; label = 'Pace'; }
    final available = <(String, String, double)>[];
    for (final row in records) {
      final rawType = row['season_type']?.toString().toLowerCase() ?? '';
      if (rawType.isNotEmpty &&
          (rawType.contains('play') != playoffs)) continue;
      double? number;
      if (key == 'win_pct') {
        final wins = _number(row['wins']);
        final losses = _number(row['losses']);
        if (wins != null && losses != null && wins + losses > 0) {
          number = wins / (wins + losses);
        }
      } else {
        number = _number(row[key] ??
          (key == 'offensive_rating' ? row['ortg'] :
            key == 'defensive_rating' ? row['drtg'] : null));
      }
      if (number == null || !number.isFinite) continue;
      final teamKey = row['team_key']?.toString() ?? '';
      Map<String, dynamic>? meta;
      for (final team in teams) {
        final recordId = row['team_id']?.toString();
        if ((teamKey.isNotEmpty && team['team_key']?.toString() == teamKey) ||
            (recordId != null && team['team_id']?.toString() == recordId)) {
          meta = team; break;
        }
      }
      final name = meta?['canonical_name']?.toString() ??
          row['team_name']?.toString() ??
          row['team_abbreviation']?.toString() ?? teamKey;
      if (name.isEmpty) continue;
      available.add((name, row['team_abbreviation']?.toString() ?? '', number));
    }
    if (available.isEmpty) return _notFound('Team stat unavailable',
        'No source-backed $label records exist for $season.', source);
    final ascending = _isAscending(q);
    available.sort((a, b) {
      final compare = a.$3.compareTo(b.$3);
      return ascending ? compare : -compare;
    });
    return ArcsideResearchAnswer(
      title: '$season · Team $label',
      message: '${available.length} published teams ranked by $label. '
          'Computed Win% uses only recorded wins and losses.',
      source: source,
      hits: [
        for (final row in available)
          ArcsideResearchHit(name: row.$1, team: row.$2,
              value: key == 'win_pct'
                  ? '${(row.$3 * 100).toStringAsFixed(1)}%'
                  : row.$3.toStringAsFixed(key == 'wins' ||
                      key == 'losses' ? 0 : 1),
              detail: ''),
      ],
    );
  }

  /// Returns the entire matching season set. The UI paginates locally; there
  /// are no daily, per-query or 10-result artificial limits.
  static ArcsideResearchAnswer answerFromRows(
    String question,
    List<NbaStatsRow> rows, {
    required String season,
    required bool playoffs,
    NbaStatsBasis basis = NbaStatsBasis.perGame,
  }) {
    final q = question.trim().toLowerCase();
    final source = _source('$season · ${playoffs ? 'Playoffs' : 'Regular Season'} · Player seasons');
    if (q.isEmpty || q.length > maxQuestionChars) {
      return _notFound('Query needs adjusting',
          'Use a question no longer than $maxQuestionChars characters.',
          source);
    }
    if (rows.isEmpty) return _notFound('No season data',
      'Arcside has no published player records for this season and segment.',
      source);
    final metric = _metricFor(q);
    final totals = _has(q, 'total') || _has(q, 'totals');
    final rank = _has(q, 'top') || _has(q, 'leader') ||
        _has(q, 'leaders') || _has(q, 'leading') ||
        _has(q, 'highest') || _has(q, 'lowest') ||
        _has(q, 'most') || _has(q, 'fewest') ||
        _has(q, 'rankings') || _has(q, 'ranked') ||
        _has(q, 'who led') || _has(q, 'who leads') ||
        _has(q, 'best') || _has(q, 'worst') ||
        _has(q, 'bottom') || _has(q, 'all players');
    final minMatch = RegExp(r'(?:min_gp:\s*|minimum\s+|at\s+least\s+)(\d+)\s*(?:games|gp)?')
        .firstMatch(q);
    final minGp = minMatch == null
        ? (playoffs ? 4 : 50)
        : (int.tryParse(minMatch.group(1)!) ?? 0).clamp(0, 1000).toInt();
    final teamFilter = RegExp(r'\bteam:\s*([a-z]{2,4})\b').firstMatch(q)?.group(1)?.toUpperCase();
    final positionFilter = RegExp(r'\bposition:\s*(PG|SG|SF|PF|C)\b',
        caseSensitive: false).firstMatch(q)?.group(1)?.toUpperCase();
    final descending = !_isAscending(q);
    if (rank) {
      if (metric == null) {
        return _notFound('Specify a statistic',
          'Use any Arcside Advanced Stats metric, such as PPG, APG, TS%, '
          'AST%, BPM, USG%, ORTG, Max Vert or deflections.',
          source);
      }
      final amount = RegExp(r'\b(?:top|bottom)\s+(\d+)\b')
          .firstMatch(q)?.group(1);
      final count = _has(q, 'all players') || _has(q, 'all results')
          ? rows.length
          : (amount == null ? (_has(q, 'who led') || _has(q, 'who leads') ? 1 : 20)
              : int.tryParse(amount) ?? 20);
      final applicable = rows.where((row) {
        if ((row.value('gp') ?? 0) < minGp) return false;
        if (teamFilter != null && !_teamHas(row.team, teamFilter)) return false;
        if (positionFilter != null &&
            !_has(row.position, positionFilter)) return false;
        final val = _value(row, metric, totals: totals);
        return val != null && val.isFinite;
      }).toList()
        ..sort((a, b) {
          final av = _value(a, metric, totals: totals)!;
          final bv = _value(b, metric, totals: totals)!;
          final compare = av.compareTo(bv);
          return compare == 0 ? a.player.compareTo(b.player)
              : (descending ? -compare : compare);
        });
      if (applicable.isEmpty) return _notFound('No qualifying data',
        'No rows meet the $minGp GP minimum and requested source-backed metric.',
        source);
      final selected = applicable.take(count.clamp(1, applicable.length).toInt()).toList();
      final metricLabel = _metricName(metric, totals: totals);
      return ArcsideResearchAnswer(
        title: '${selected.length} player results · $metricLabel',
        message: '$season ${playoffs ? 'playoffs' : 'regular season'} · '
            '$minGp+ GP · ${totals ? 'Recorded totals' : basis.label} · '
            '${descending ? 'Highest first' : 'Lowest first'}'
            '${teamFilter == null ? '' : ' · Team $teamFilter'}.',
        source: source,
        hits: [
          for (final row in selected)
            ArcsideResearchHit(
              name: row.player, team: row.team,
              value: _display(row, metric, totals: totals),
              detail: '${(row.value('gp') ?? 0).round()} GP',
            ),
        ],
      );
    }

    // Names are matched against known players in the loaded season, never
    // generated or resolved via the public internet.
    final normalizedQ = ' ${_normal(q)} ';
    final matches = <NbaStatsRow>[];
    final seen = <String>{};
    for (final row in rows) {
      final name = _normal(row.player);
      if (name.isEmpty || name == '—') continue;
      if (normalizedQ.contains(' $name ') && seen.add(row.playerId)) {
        matches.add(row);
      }
    }
    if (matches.isEmpty) {
      return _notFound('Specify a player or leaderboard',
        'Try a published full player name and season, or a leaderboard '
        'using any available Advanced Stats metric. '
        'Draft, award and game queries are supported too.',
        source);
    }
    final compare = _has(q, 'compare') ||
        RegExp(r'\bvs\.?\b').hasMatch(q) || _has(q, 'versus');
    if (matches.length > 1 && !compare) {
      return _notFound('Multiple player matches',
        'Specify a player, or use "compare Player A vs Player B" '
        'with a single season.', source);
    }
    if (matches.length > 2) {
      return _notFound('Too many player matches',
        'Compare two players at a time within one season.', source);
    }
    if (compare && matches.length != 2) {
      return _notFound('Two players required',
        'Give both players’ full names and one season, '
        'for example "compare Stephen Curry vs James Harden 2015-16".',
        source);
    }
    if (metric != null) {
      final available = [
        for (final row in matches)
          if (_value(row, metric, totals: totals) case final double value
              when value.isFinite)
            ArcsideResearchHit(
              name: row.player, team: row.team,
              value: _display(row, metric, totals: totals),
              detail: '${(row.value('gp') ?? 0).round()} GP',
            ),
      ];
      if (available.length != matches.length) return _notFound(
        'Metric unavailable',
        '${_metricName(metric, totals: totals)} has no published value '
        'for one or more of these player-season records.', source);
      return ArcsideResearchAnswer(
        title: '${matches.map((row) => row.player).join(' vs ')} · '
            '${_metricName(metric, totals: totals)}',
        message: '$season · ${playoffs ? 'Playoffs' : 'Regular Season'} · '
            '${totals ? 'Recorded totals' : basis.label}',
        source: source, hits: available,
      );
    }

    // A player-only query is allowed for a season snapshot. An unrelated
    // question containing a player name is not silently answered as stats.
    if (!_has(q, 'stats') && !_has(q, 'statistics') &&
        !_has(q, 'profile') && !_has(q, 'season') &&
        !_has(q, 'averages') && !_has(q, 'all metrics') &&
        !_has(q, 'all stats') && !_has(q, 'compare') && !compare) {
      return _notFound('Question outside the data query scope',
        'Ask for a season stat line, a specific recorded metric, '
        'or a two-player comparison. General questions are not answered.',
        source);
    }
    final allMetrics = _has(q, 'all metrics') ||
        _has(q, 'all stats') || _has(q, 'everything');
    final keys = allMetrics
        ? nbaTerminalMetrics.map((m) => m.key).toList()
        : [
            'gp','mpg','ppg','rpg','apg','spg','bpg','tpg',
            'fg_pct','three_pct','ft_pct','ts_pct','efg_pct',
            'per','bpm','ast_pct','tov_pct','usage','ortg',
            'drtg','net_rating','trb_pct',
          ];
    final hits = <ArcsideResearchHit>[];
    for (final row in matches) {
      for (final key in keys) {
        final value = _value(row, key);
        if (value == null || !value.isFinite) continue;
        hits.add(ArcsideResearchHit(
          name: matches.length == 1 ? _metricShort(key)
              : '${row.player} · ${_metricShort(key)}',
          team: row.team,
          value: _display(row, key),
          detail: '',
        ));
      }
    }
    if (hits.isEmpty) return _notFound('No published metrics',
        'The selected records contain no available metrics.', source);
    return ArcsideResearchAnswer(
      title: '${matches.map((row) => row.player).join(' vs ')} · Season stats',
      message: '$season · ${playoffs ? 'Playoffs' : 'Regular Season'} · '
          '${basis.label}. ${hits.length} available values; '
          'missing fields are omitted, not filled with zeros.',
      source: source, hits: hits,
    );
  }

  static bool _teamHas(String team, String target) => team.toUpperCase()
      .split(RegExp(r'[,/ ]+')).contains(target);

  static bool _isAscending(String q) => _has(q, 'lowest') ||
      _has(q, 'fewest') || _has(q, 'bottom') ||
      _has(q, 'ascending') || _has(q, 'worst');

  static String _metricShort(String key) =>
      nbaTerminalMetricByKey[key]?.shortLabel ?? key.toUpperCase();

  static String _metricName(String key, {bool totals = false}) {
    if (totals) {
      return const {
        'ppg':'Total points','rpg':'Total rebounds',
        'apg':'Total assists','spg':'Total steals',
        'bpg':'Total blocks','tpg':'Total turnovers',
      }[key] ?? nbaTerminalMetricByKey[key]?.label ?? key;
    }
    return nbaTerminalMetricByKey[key]?.label ?? key;
  }

  static String? _metricFor(String q) {
    final selected = RegExp(r'\b(?:metric|stat):\s*([a-z0-9_]+)\b')
        .firstMatch(q)?.group(1);
    if (selected != null) return nbaTerminalMetricByKey.containsKey(selected)
        ? selected : null;
    const aliases = <(String, String)>[
      ('points per game','ppg'),('scorers','ppg'),('scorer','ppg'),
      ('scoring','ppg'),('points','ppg'),('point','ppg'),('pts','ppg'),('ppg','ppg'),
      ('rebounds per game','rpg'),('rebounds','rpg'),('rebounding','rpg'),
      ('rpg','rpg'),('reb','rpg'),
      ('assists per game','apg'),('assists','apg'),('assist','apg'),('apg','apg'),
      ('steals per game','spg'),('steals','spg'),('spg','spg'),
      ('blocks per game','bpg'),('blocks','bpg'),('bpg','bpg'),
      ('turnovers per game','tpg'),('turnovers','tpg'),('tpg','tpg'),
      ('true shooting','ts_pct'),('ts%','ts_pct'),
      ('deflections','deflections_pg'),
      ('contested shots','contested_shots_pg'),
      ('screen assists','screen_apg'),
      ('loose balls recovered','loose_balls_recovered_pg'),
      ('box outs','box_outs_pg'),
      ('scored','ppg'),('score','ppg'),
      ('usage rate','usage'),('usg%','usage'),
      ('net rating','net_rating'),('nrtg','net_rating'),
      ('assist to turnover','ast_to'),('ast:to','ast_to'),
    ];
    final query = ' ${_normal(q)} ';
    // Longest exact phrase wins. This prevents "rebounds" overriding
    // "offensive rebounds" and supports all catalog metrics by name.
    final candidates = <(String, String)>[
      ...aliases,
      for (final m in nbaTerminalMetrics)
        (m.label, m.key),
      for (final m in nbaTerminalMetrics)
        if (m.shortLabel.length >= 3 || m.shortLabel.contains('%'))
          (m.shortLabel, m.key),
    ]..sort((a,b)=>_normal(b.$1).length.compareTo(_normal(a.$1).length));
    for (final entry in candidates) {
      if (query.contains(' ${_normal(entry.$1)} ')) return entry.$2;
    }
    return null;
  }

  static double? _value(NbaStatsRow row, String metric, {bool totals = false}) {
    if (totals) {
      const totalsKeys = <String, String>{
        'ppg':'points','rpg':'rebounds','apg':'assists',
        'spg':'steals','bpg':'blocks','tpg':'turnovers',
      };
      final rawKey = totalsKeys[metric];
      if (rawKey != null) return _number(row.raw[rawKey]);
    }
    return _catalog.value(row, metric);
  }

  static String _display(NbaStatsRow row, String metric, {bool totals = false}) {
    if (totals && const {'ppg','rpg','apg','spg','bpg','tpg'}.contains(metric)) {
      final value = _value(row, metric, totals: true);
      return value == null ? '—' : value.round().toString();
    }
    return _catalog.format(row, metric);
  }
}
