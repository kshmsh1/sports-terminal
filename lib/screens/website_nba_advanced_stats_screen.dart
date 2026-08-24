import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaAdvancedStatsScreen extends StatefulWidget {
  const WebsiteNbaAdvancedStatsScreen({super.key, required this.session});
  final AppSession session;

  @override
  State<WebsiteNbaAdvancedStatsScreen> createState() => _WebsiteNbaAdvancedStatsScreenState();
}

class _WebsiteNbaAdvancedStatsScreenState extends State<WebsiteNbaAdvancedStatsScreen> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();
  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<NbaTerminalSeedSnapshot>? _dataFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _category = 'Overview';
  String _team = 'All';
  String _position = 'All';
  String _sortKey = 'pts';
  bool _descending = true;
  final Set<String> _expandedMetrics = <String>{};

  @override
  void initState() {
    super.initState();
    _seasonsFuture = _loadSeasons();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<WebsiteNbaSeason>> _loadSeasons() async {
    final seasons = await _api.seasons();
    if (seasons.isNotEmpty) {
      _seasons = seasons;
      _season = seasons.firstWhere((item) => item.id == '2025-26', orElse: () => seasons.first).id;
      _dataFuture = _loadData();
    }
    return seasons;
  }

  Future<NbaTerminalSeedSnapshot> _loadData() => _api.seasonSnapshot(
        _season,
        seasonType: _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      );

  void _reload() {
    setState(() {
      _team = 'All';
      _dataFuture = _loadData();
    });
  }

  void _selectCategory(String category) {
    final definition = _categories.firstWhere((item) => item.name == category);
    setState(() {
      _category = category;
      _sortKey = definition.metrics.first.key;
      _descending = true;
      _expandedMetrics.clear();
    });
  }

  List<_Metric> _visibleMetrics(_Category category) {
    final result = <_Metric>[];
    for (final metric in category.metrics) {
      result.add(metric);
      if (_expandedMetrics.contains(metric.key)) result.addAll(metric.children);
    }
    return result;
  }

  Widget _metricHeader(_Metric metric) {
    if (metric.children.isEmpty) return Text(metric.label);
    final expanded = _expandedMetrics.contains(metric.key);
    return InkWell(
      onTap: () => setState(() {
        if (expanded) {
          _expandedMetrics.remove(metric.key);
        } else {
          _expandedMetrics.add(metric.key);
        }
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(expanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 19),
          const SizedBox(width: 2),
          Text(metric.label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, catalog) {
        if (catalog.connectionState != ConnectionState.done) return const _Loading();
        if (catalog.hasError || _seasons.isEmpty || _dataFuture == null) {
          return _ErrorState(error: catalog.error, onRetry: () => setState(() => _seasonsFuture = _loadSeasons()));
        }
        return FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _Loading();
            if (snapshot.hasError || snapshot.data == null) return _ErrorState(error: snapshot.error, onRetry: _reload);
            return _buildPage(context, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, NbaTerminalSeedSnapshot data) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(data, basis: _basis, seasonType: _seasonType);
    final query = _search.text.trim().toLowerCase();
    final teams = <String>{'All'};
    for (final row in rows) {
      teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—'));
    }
    final visible = rows.where((row) {
      if (query.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) return false;
      if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
      if (_position != 'All' && !_matchesPosition(row.position, _position)) return false;
      return true;
    }).toList();

    final definition = _categories.firstWhere((item) => item.name == _category);
    // Intentionally never remove a column just because the active release lacks it.
    // Stable schemas make historical gaps explicit: unavailable cells render as an em dash.
    final metrics = _visibleMetrics(definition);
    visible.sort((a, b) {
      final left = _metricValue(a, _sortKey);
      final right = _metricValue(b, _sortKey);
      if (left == null && right == null) return a.player.compareTo(b.player);
      if (left == null) return 1;
      if (right == null) return -1;
      return _descending ? right.compareTo(left) : left.compareTo(right);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Advanced Stats', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 8),
        Text('Deep player statistics organized by the basketball questions they answer—not by a terminal command system.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45)),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _season,
                    decoration: const InputDecoration(labelText: 'Season', isDense: true),
                    items: [for (final item in _seasons) DropdownMenuItem(value: item.id, child: Text(item.id))],
                    onChanged: (value) {
                      if (value == null || value == _season) return;
                      _season = value;
                      _reload();
                    },
                  ),
                ),
                SegmentedButton<NbaStatsSeasonType>(
                  segments: const [
                    ButtonSegment(value: NbaStatsSeasonType.regular, label: Text('Regular Season')),
                    ButtonSegment(value: NbaStatsSeasonType.playoffs, label: Text('Playoffs')),
                  ],
                  selected: {_seasonType},
                  onSelectionChanged: (value) {
                    _seasonType = value.first;
                    _reload();
                  },
                ),
                SizedBox(
                  width: 145,
                  child: DropdownButtonFormField<NbaStatsBasis>(
                    initialValue: _basis,
                    decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                    items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) { if (value != null) setState(() => _basis = value); },
                  ),
                ),
                _StringDropdown(
                  label: 'Stat group',
                  value: _category,
                  values: [for (final item in _categories) item.name],
                  width: 220,
                  onChanged: _selectCategory,
                ),
                SizedBox(
                  width: 240,
                  child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players', isDense: true)),
                ),
                _StringDropdown(label: 'Team', value: _team, values: teams.toList()..sort(), onChanged: (value) => setState(() => _team = value)),
                _StringDropdown(label: 'Position', value: _position, values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'], onChanged: (value) => setState(() => _position = value)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.name),
                    selected: item.name == _category,
                    onSelected: (_) => _selectCategory(item.name),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(definition.description, style: TextStyle(color: colors.onSurfaceVariant, height: 1.45)),
        if (definition.metrics.any((metric) => metric.children.isNotEmpty)) ...[
          const SizedBox(height: 6),
          Text('Select the triangle beside an expandable column to reveal its component stats. Missing source coverage stays visible as —.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ],
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 48,
              columns: [
                const DataColumn(label: Text('Player')),
                const DataColumn(label: Text('Team')),
                const DataColumn(label: Text('Pos')),
                for (final metric in metrics)
                  DataColumn(
                    numeric: true,
                    label: _metricHeader(metric),
                    onSort: (_, ascending) => setState(() {
                      _sortKey = metric.key;
                      _descending = !ascending;
                    }),
                  ),
              ],
              rows: [
                for (final row in visible.take(750))
                  DataRow(cells: [
                    DataCell(
                      Text(row.player, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                      onTap: () => openWebsiteNbaPlayerPage(context, session: widget.session, playerKey: row.playerId, playerName: row.player),
                    ),
                    DataCell(
                      Text(row.team, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                      onTap: () {
                        final team = row.team.split(RegExp(r'[,/ ]+')).firstWhere((item) => item.isNotEmpty && item != '—', orElse: () => '');
                        if (team.isNotEmpty) openWebsiteNbaTeamPage(context, session: widget.session, teamKey: team, teamName: team);
                      },
                    ),
                    DataCell(Text(row.position)),
                    for (final metric in metrics) DataCell(Text(_formatMetric(_metricValue(row, metric.key), metric))),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _StatGlossary(),
        const SizedBox(height: 14),
        Text('Source boundary: columns remain part of the Sports Terminal schema even when a season or source does not contain the metric. Sports Terminal displays sourced fields and transparent derivations only; unavailable values are shown as — rather than fabricated.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.5)),
      ],
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({required this.label, required this.value, required this.values, required this.onChanged, this.width = 145});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          initialValue: values.contains(value) ? value : values.first,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))],
          onChanged: (next) { if (next != null) onChanged(next); },
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Advanced NBA data unavailable', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('Sports Terminal could not read its precompiled static NBA season file. ${error ?? ''}'),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ]),
        ),
      );
}

class _Category {
  const _Category(this.name, this.description, this.metrics);
  final String name;
  final String description;
  final List<_Metric> metrics;
}

class _Metric {
  const _Metric(
    this.key,
    this.label,
    this.glossary, {
    this.percent = false,
    this.signed = false,
    this.integer = false,
    this.children = const [],
  });
  final String key;
  final String label;
  final String glossary;
  final bool percent;
  final bool signed;
  final bool integer;
  final List<_Metric> children;
}

const _categories = <_Category>[
  _Category('Overview', 'Core production, traditional efficiency and headline all-in-one measures.', [
    _Metric('min', 'MPG', 'Minutes played per game.'),
    _Metric('pts', 'PPG', 'Points scored per game.'),
    _Metric('reb', 'RPG', 'Total rebounds per game.', children: [
      _Metric('oreb', 'ORB', 'Offensive rebounds per game.'),
      _Metric('dreb', 'DRB', 'Defensive rebounds per game.'),
    ]),
    _Metric('ast', 'APG', 'Assists per game.'),
    _Metric('stl', 'SPG', 'Steals per game.'),
    _Metric('blk', 'BPG', 'Blocks per game.'),
    _Metric('tov', 'TPG', 'Turnovers per game.'),
    _Metric('pf', 'PF', 'Personal fouls under the selected rate basis.'),
    _Metric('fg_pct', 'FG%', 'Field-goal percentage.', percent: true, children: [
      _Metric('fgm', 'FGM', 'Field goals made under the selected rate basis.'),
      _Metric('fga', 'FGA', 'Field goals attempted under the selected rate basis.'),
    ]),
    _Metric('three_pct', '3P%', 'Three-point percentage.', percent: true, children: [
      _Metric('three_made', '3PM', 'Three-pointers made under the selected rate basis.'),
      _Metric('three_att', '3PA', 'Three-pointers attempted under the selected rate basis.'),
    ]),
    _Metric('ft_pct', 'FT%', 'Free-throw percentage.', percent: true, children: [
      _Metric('ftm', 'FTM', 'Free throws made under the selected rate basis.'),
      _Metric('fta', 'FTA', 'Free throws attempted under the selected rate basis.'),
    ]),
    _Metric('pace', 'Pace', 'Estimated possessions per 48 minutes while the player is on the floor.'),
    _Metric('pie', 'PIE', 'Player Impact Estimate summarizes a player’s box-score contribution relative to game totals.', percent: true),
    _Metric('per', 'PER', 'Player Efficiency Rating is a pace-adjusted per-minute box-score efficiency metric.'),
    _Metric('bpm', 'BPM', 'Box Plus/Minus estimates points per 100 possessions above or below league average.', signed: true, children: [
      _Metric('obpm', 'OBPM', 'Offensive component of Box Plus/Minus.', signed: true),
      _Metric('dbpm', 'DBPM', 'Defensive component of Box Plus/Minus.', signed: true),
    ]),
    _Metric('vorp', 'VORP', 'Value Over Replacement Player converts BPM into cumulative value above replacement.'),
    _Metric('ws', 'WS', 'Win Shares estimates the number of team wins attributable to a player.'),
    _Metric('epm', 'EPM', 'Estimated Plus-Minus is an impact estimate combining play-by-play and contextual information.', signed: true),
    _Metric('lebron', 'LEBRON', 'LEBRON is an all-in-one impact estimate when a licensed/source-backed value is available.', signed: true),
  ]),
  _Category('Shooting & Efficiency', 'Efficiency, shot profile, location, creation mode and scoring decision context.', [
    _Metric('efg_pct', 'eFG%', 'Effective field-goal percentage gives extra weight to made three-pointers.', percent: true),
    _Metric('ts_pct', 'TS%', 'True shooting percentage measures scoring efficiency including twos, threes and free throws.', percent: true),
    _Metric('ftr', 'FTR', 'Free-throw rate measures free-throw attempts relative to field-goal attempts.'),
    _Metric('three_par', '3PAr', 'Three-point attempt rate measures the share of field-goal attempts taken from three.'),
    _Metric('pps', 'PPS', 'Points per shot measures points generated per field-goal attempt.'),
    _Metric('rim_freq', 'Rim Freq', 'Share of shooting attempts taken at the rim.', percent: true),
    _Metric('rim_fg_pct', 'Rim FG%', 'Field-goal percentage on shots at the rim.', percent: true),
    _Metric('paint_freq', 'Paint Freq', 'Share of shooting attempts taken in the paint.', percent: true),
    _Metric('paint_fg_pct', 'Paint FG%', 'Field-goal percentage on paint attempts.', percent: true),
    _Metric('midrange_freq', 'Midrange Freq', 'Share of shooting attempts taken from midrange.', percent: true),
    _Metric('midrange_fg_pct', 'Midrange FG%', 'Field-goal percentage on midrange attempts.', percent: true),
    _Metric('three_freq', '3P Freq', 'Share of shooting attempts taken from three-point range.', percent: true),
    _Metric('three_pct', '3P%', 'Three-point percentage.', percent: true),
    _Metric('halfcourt_freq', 'Halfcourt Freq', 'Share of offensive attempts or possessions occurring in halfcourt offense.', percent: true),
    _Metric('halfcourt_fg_pct', 'Halfcourt FG%', 'Field-goal percentage in halfcourt possessions.', percent: true),
    _Metric('heaves_pg', 'HPG', 'Heaves attempted per game.'),
    _Metric('corner_three_freq', 'Corner 3P Freq', 'Share of attempts taken from either corner three location.', percent: true),
    _Metric('corner_three_pct', 'Corner 3P%', 'Three-point percentage from the corners.', percent: true),
    _Metric('right_corner_three_freq', 'R Corner Freq', 'Share of attempts taken from the right corner three.', percent: true),
    _Metric('right_corner_three_pct', 'R Corner 3P%', 'Three-point percentage from the right corner.', percent: true),
    _Metric('left_corner_three_freq', 'L Corner Freq', 'Share of attempts taken from the left corner three.', percent: true),
    _Metric('left_corner_three_pct', 'L Corner 3P%', 'Three-point percentage from the left corner.', percent: true),
    _Metric('catch_shoot_three_freq', 'C&S 3P Freq', 'Share of attempts that are catch-and-shoot threes.', percent: true),
    _Metric('catch_shoot_three_pct', 'C&S 3P%', 'Three-point percentage on catch-and-shoot attempts.', percent: true),
    _Metric('pullup_three_freq', 'Pull-Up 3P Freq', 'Share of attempts that are pull-up threes.', percent: true),
    _Metric('pullup_three_pct', 'Pull-Up 3P%', 'Three-point percentage on pull-up attempts.', percent: true),
    _Metric('right_wing_three_freq', 'R Wing Freq', 'Share of attempts taken from the right wing three area.', percent: true),
    _Metric('right_wing_three_pct', 'R Wing 3P%', 'Three-point percentage from the right wing.', percent: true),
    _Metric('left_wing_three_freq', 'L Wing Freq', 'Share of attempts taken from the left wing three area.', percent: true),
    _Metric('left_wing_three_pct', 'L Wing 3P%', 'Three-point percentage from the left wing.', percent: true),
    _Metric('wing_three_freq', 'Wing 3P Freq', 'Share of attempts taken from either wing three area.', percent: true),
    _Metric('wing_three_pct', 'Wing 3P%', 'Three-point percentage from the wings.', percent: true),
    _Metric('middle_three_freq', 'Middle 3P Freq', 'Share of attempts taken from above-the-break middle three areas.', percent: true),
    _Metric('middle_three_pct', 'Middle 3P%', 'Three-point percentage from the middle/above-the-break area.', percent: true),
    _Metric('unassisted_fg_pct', 'Unassisted FG%', 'Field-goal percentage on unassisted attempts.', percent: true),
    _Metric('assisted_fg_pct', 'Assisted FG%', 'Field-goal percentage on assisted attempts.', percent: true),
    _Metric('unassisted_pts_pg', 'Unassisted PPG', 'Points per game scored without an assist.'),
    _Metric('assisted_pts_pg', 'Assisted PPG', 'Points per game scored on assisted field goals.'),
    _Metric('dunks_pg', 'Dunks PG', 'Made or attempted dunks per game, depending on the source definition.'),
    _Metric('layups_pg', 'Layups PG', 'Made or attempted layups per game, depending on the source definition.'),
    _Metric('scoring_decision_time', 'Scoring Decision Time', 'Average time before a shooting decision when a tracking source provides it.'),
    _Metric('buzzer_beaters', 'Buzzer Beaters', 'Recorded made shots at a game, quarter or shot-clock buzzer.'),
  ]),
  _Category('Playmaking & Creation', 'Passing volume, creation quality, turnover control and advantage generation.', [
    _Metric('ast', 'APG', 'Assists per game.'),
    _Metric('tov', 'TPG', 'Turnovers per game.'),
    _Metric('screen_ast_pg', 'Screen APG', 'Screen assists per game credited to the screener.'),
    _Metric('secondary_ast_pg', 'Secondary APG', 'Secondary or hockey assists per game.'),
    _Metric('potential_ast_pg', 'Potential APG', 'Passes per game that would become assists if the receiving shot were made.'),
    _Metric('passes_pg', 'Passes PG', 'Passes made per game.'),
    _Metric('ast_tov', 'AST:TO', 'Assist-to-turnover ratio.'),
    _Metric('ast_pct', 'AST%', 'Estimated share of teammate field goals a player assists while on the floor.', percent: true),
    _Metric('tov_pct', 'TO%', 'Estimated turnovers per 100 possessions or plays used, according to source definition.', percent: true),
    _Metric('adj_ast_ratio', 'Adj. Assist Ratio', 'Adjusted assist ratio credits assists, free-throw assists and secondary assists in creation outcomes.'),
    _Metric('ft_ast_pg', 'FT APG', 'Free-throw assists per game when tracked.'),
    _Metric('ast_points_created', 'AST Pts Created', 'Points directly created by a player’s assists.'),
    _Metric('pass_windows_opened', 'Pass Windows', 'Estimated passing windows or lanes created by player movement and gravity.'),
    _Metric('passing_decision_time', 'Passing Decision Time', 'Average time before a pass decision when tracking data supports it.'),
    _Metric('panic_tov_rate', 'Panic TO Rate', 'Turnover rate on pressured or late-decision possessions when a defined tracking source exists.', percent: true),
    _Metric('double_team_navigation', 'Double-Team Navigation', 'Performance navigating double teams when source-backed tracking or event labels exist.'),
    _Metric('triple_team_navigation', 'Triple-Team Navigation', 'Performance navigating triple teams when source-backed tracking or event labels exist.'),
  ]),
  _Category('Defense', 'Defensive events, shot suppression, matchup results, hustle and foul discipline.', [
    _Metric('stl', 'SPG', 'Steals per game.', children: [
      _Metric('stl_pct', 'STL%', 'Estimated percentage of opponent possessions ending in a steal by the player.', percent: true),
    ]),
    _Metric('blk', 'BPG', 'Blocks per game.', children: [
      _Metric('blk_pct', 'BLK%', 'Estimated percentage of opponent two-point attempts blocked while the player is on court.', percent: true),
    ]),
    _Metric('deflections_pg', 'DPG', 'Deflections per game.'),
    _Metric('dreb', 'DREB', 'Defensive rebounds under the selected rate basis.', children: [
      _Metric('contested_dreb_pg', 'Contested DREB', 'Contested defensive rebounds per game.'),
      _Metric('uncontested_dreb_pg', 'Uncontested DREB', 'Uncontested defensive rebounds per game.'),
    ]),
    _Metric('charges_drawn_pg', 'Charges Drawn PG', 'Charges drawn per game.'),
    _Metric('contested_shots_pg', 'Contested Shots PG', 'Two- and three-point shots contested per game.'),
    _Metric('loose_balls_recovered_pg', 'Loose Balls PG', 'Loose balls recovered per game.'),
    _Metric('dfg_pct', 'DFG%', 'Opponent field-goal percentage on attempts defended by the player.', percent: true, children: [
      _Metric('dfgm', 'DFGM', 'Defended field goals made by opponents.'),
      _Metric('dfga', 'DFGA', 'Defended field-goal attempts by opponents.'),
    ]),
    _Metric('rim_dfg_pct', 'Rim DFG%', 'Opponent field-goal percentage at the rim when defended by the player.', percent: true),
    _Metric('three_dfg_pct', '3P DFG%', 'Opponent three-point percentage on shots defended by the player.', percent: true),
    _Metric('midrange_dfg_pct', 'Midrange DFG%', 'Opponent midrange field-goal percentage on defended attempts.', percent: true),
    _Metric('blow_by_rate', 'Blow-By Rate', 'Rate at which the primary defender is beaten off the dribble under a defined tracking source.', percent: true),
    _Metric('avg_contest_distance', 'Contest Distance', 'Average defender-to-shooter distance at the contest when tracked.'),
    _Metric('help_defense_rate', 'Help Defense', 'Rate or volume of source-defined help-defense actions.', percent: true),
    _Metric('deterrence_rate', 'Deterrence Rate', 'Estimated reduction in opponent attempts attributable to the defender’s presence.', percent: true),
    _Metric('transition_def_ppp', 'Transition Def PPP', 'Points allowed per transition possession when the player is the relevant defender or on court.'),
    _Metric('pf', 'PF', 'Personal fouls under the selected rate basis.'),
    _Metric('shooting_fouls', 'Shooting Fouls', 'Shooting fouls committed under the selected rate basis.'),
    _Metric('offensive_fouls', 'Offensive Fouls', 'Offensive fouls committed under the selected rate basis.'),
    _Metric('defensive_fouls', 'Defensive Fouls', 'Defensive fouls committed under the selected rate basis.'),
    _Metric('other_fouls', 'Other Fouls', 'Other categorized fouls under the selected rate basis.'),
  ]),
  _Category('Rebounding', 'Rebound volume, contest context, opportunity conversion and box-out value.', [
    _Metric('reb', 'RPG', 'Total rebounds per game.', children: [
      _Metric('contested_reb_pg', 'Contested RPG', 'Contested rebounds per game.'),
      _Metric('uncontested_reb_pg', 'Uncontested RPG', 'Uncontested rebounds per game.'),
      _Metric('reb_pct', 'TRB%', 'Estimated percentage of available rebounds collected while on court.', percent: true),
    ]),
    _Metric('dreb', 'DRB', 'Defensive rebounds per game.', children: [
      _Metric('contested_dreb_pg', 'Contested DRB', 'Contested defensive rebounds per game.'),
      _Metric('uncontested_dreb_pg', 'Uncontested DRB', 'Uncontested defensive rebounds per game.'),
      _Metric('dreb_pct', 'DRB%', 'Estimated percentage of available defensive rebounds collected while on court.', percent: true),
    ]),
    _Metric('oreb', 'ORB', 'Offensive rebounds per game.', children: [
      _Metric('contested_oreb_pg', 'Contested ORB', 'Contested offensive rebounds per game.'),
      _Metric('uncontested_oreb_pg', 'Uncontested ORB', 'Uncontested offensive rebounds per game.'),
      _Metric('oreb_pct', 'ORB%', 'Estimated percentage of available offensive rebounds collected while on court.', percent: true),
    ]),
    _Metric('rebound_chances_pg', 'Rebound Chances PG', 'Tracked rebound opportunities per game.'),
    _Metric('rebound_chance_pct', 'Rebound Chance%', 'Share of tracked rebound opportunities converted into rebounds.', percent: true),
    _Metric('box_out_pct', 'Box Out%', 'Source-defined share or success rate of box-out opportunities.', percent: true),
    _Metric('box_outs_pg', 'Box Outs PG', 'Box outs recorded per game.'),
    _Metric('tap_outs_pg', 'Tap Outs PG', 'Controlled rebound tap-outs per game when tracked.'),
    _Metric('deferred_rebounds_pg', 'Deferred Rebounds PG', 'Rebound opportunities intentionally left to a teammate per game when tracked.'),
  ]),
  _Category('Impact', 'Possession impact, plus-minus families and cumulative player-value models.', [
    _Metric('ortg', 'ORtg', 'Offensive Rating estimates points produced or team points per 100 possessions, depending on source.'),
    _Metric('drtg', 'DRtg', 'Defensive Rating estimates points allowed per 100 possessions while the player is on court or by player estimate.'),
    _Metric('net_rating', 'Net Rating', 'Offensive Rating minus Defensive Rating.', signed: true),
    _Metric('on_off_net', 'On/Off Differential', 'Difference in team net rating with the player on court versus off court.', signed: true),
    _Metric('per', 'PER', 'Player Efficiency Rating is a pace-adjusted per-minute box-score efficiency metric.'),
    _Metric('bpm', 'BPM', 'Box Plus/Minus estimates points per 100 possessions above or below league average.', signed: true, children: [
      _Metric('obpm', 'OBPM', 'Offensive component of Box Plus/Minus.', signed: true),
      _Metric('dbpm', 'DBPM', 'Defensive component of Box Plus/Minus.', signed: true),
    ]),
    _Metric('vorp', 'VORP', 'Value Over Replacement Player converts BPM into cumulative value above replacement.'),
    _Metric('ws', 'WS', 'Win Shares estimates the number of team wins attributable to a player.'),
    _Metric('ws48', 'WS/48', 'Win Shares normalized to 48 minutes.'),
    _Metric('epm', 'EPM', 'Estimated Plus-Minus is an all-in-one impact estimate when source-backed.', signed: true),
    _Metric('lebron', 'LEBRON', 'LEBRON is an all-in-one impact estimate when source-backed.', signed: true),
    _Metric('darko', 'DARKO', 'DARKO is a forward-looking player impact estimate when source-backed.', signed: true),
    _Metric('rapm', 'RAPM', 'Regularized Adjusted Plus-Minus estimates impact while controlling for teammates and opponents.', signed: true),
    _Metric('la_rapm', 'LA-RAPM', 'Luck-adjusted RAPM variant when a source-backed implementation is available.', signed: true),
    _Metric('warv', 'WARV', 'Wins Above Replacement Value converts impact and playing time into wins above replacement.'),
    _Metric('pie', 'PIE', 'Player Impact Estimate summarizes a player’s box-score contribution relative to game totals.', percent: true),
  ]),
  _Category('Rate Adjusted', 'Counting production under the selected Per Game, Per 36, Per 48 or other supported rate basis.', [
    _Metric('min', 'MIN', 'Minutes under the selected rate basis.'),
    _Metric('pts', 'PTS', 'Points under the selected rate basis.'),
    _Metric('reb', 'REB', 'Rebounds under the selected rate basis.'),
    _Metric('ast', 'AST', 'Assists under the selected rate basis.'),
    _Metric('stl', 'STL', 'Steals under the selected rate basis.'),
    _Metric('blk', 'BLK', 'Blocks under the selected rate basis.'),
    _Metric('tov', 'TOV', 'Turnovers under the selected rate basis.'),
    _Metric('pf', 'PF', 'Personal fouls under the selected rate basis.'),
    _Metric('fgm', 'FGM', 'Field goals made under the selected rate basis.'),
    _Metric('fga', 'FGA', 'Field-goal attempts under the selected rate basis.'),
    _Metric('three_made', '3PM', 'Three-pointers made under the selected rate basis.'),
    _Metric('three_att', '3PA', 'Three-point attempts under the selected rate basis.'),
    _Metric('ftm', 'FTM', 'Free throws made under the selected rate basis.'),
    _Metric('fta', 'FTA', 'Free-throw attempts under the selected rate basis.'),
    _Metric('pace', 'Pace', 'Estimated possessions per 48 minutes while the player is on floor.'),
    _Metric('possessions', 'Poss', 'Possessions attributed to the player or lineup by the active source.', integer: true),
  ]),
  _Category('Clutch', 'Close-game production and efficiency; unavailable historical clutch fields remain visible as —.', [
    _Metric('clutch_pts_pg', 'CPPG', 'Points per game in the active clutch definition.'),
    _Metric('clutch_reb_pg', 'CRPG', 'Rebounds per game in the active clutch definition.'),
    _Metric('clutch_ast_pg', 'CAPG', 'Assists per game in the active clutch definition.'),
    _Metric('clutch_stl_pg', 'CSPG', 'Steals per game in the active clutch definition.'),
    _Metric('clutch_blk_pg', 'CBPG', 'Blocks per game in the active clutch definition.'),
    _Metric('clutch_tov_pg', 'CTPG', 'Turnovers per game in the active clutch definition.'),
    _Metric('clutch_fg_pct', 'Clutch FG%', 'Field-goal percentage in the active clutch definition.', percent: true),
    _Metric('clutch_three_pct', 'Clutch 3P%', 'Three-point percentage in the active clutch definition.', percent: true),
    _Metric('clutch_ft_pct', 'Clutch FT%', 'Free-throw percentage in the active clutch definition.', percent: true),
    _Metric('clutch_efg_pct', 'Clutch eFG%', 'Effective field-goal percentage in the active clutch definition.', percent: true),
    _Metric('clutch_ts_pct', 'Clutch TS%', 'True shooting percentage in the active clutch definition.', percent: true),
    _Metric('clutch_ortg', 'Clutch ORtg', 'Offensive Rating in the active clutch definition.'),
    _Metric('clutch_drtg', 'Clutch DRtg', 'Defensive Rating in the active clutch definition.'),
    _Metric('clutch_net', 'Clutch Net', 'Net Rating in the active clutch definition.', signed: true),
    _Metric('clutch_plus_minus', 'Clutch +/-', 'Plus/minus in the active clutch definition.', signed: true),
  ]),
  _Category('Gravity & Spacing', 'Spacing pressure, defensive attention and advantage creation from tracking or model-based sources.', [
    _Metric('gravity', 'Player Gravity', 'Overall defensive attention or spacing impact attributed to a player by a source-backed model.'),
    _Metric('offensive_gravity', 'Off. Gravity', 'Source-backed estimate of a player’s total offensive gravity.'),
    _Metric('shot_gravity', 'Shot Gravity', 'Defensive attention created by shooting threat.'),
    _Metric('drive_gravity', 'Drive Gravity', 'Defensive attention created by drives and rim pressure.'),
    _Metric('spacing_value', 'Spacing Value', 'Estimated value created by floor spacing and defensive displacement.'),
    _Metric('double_team_rate', 'Double-Team%', 'Share of relevant possessions on which a player is double-teamed.', percent: true),
    _Metric('triple_team_rate', 'Triple-Team%', 'Share of relevant possessions on which a player is triple-teamed.', percent: true),
    _Metric('blitz_rate', 'Blitz/Trap%', 'Share of pick-and-roll or relevant possessions defended with a blitz or trap.', percent: true),
    _Metric('blitz_escape_rate', 'Blitz Escape%', 'Rate at which a player successfully exits a blitz or trap while preserving the possession advantage.', percent: true),
    _Metric('pass_windows_opened', 'Pass Windows', 'Estimated passing windows or lanes opened by a player’s movement and gravity.'),
    _Metric('freeze_time', 'Freeze Time', 'Time defenders are held or delayed by the player’s threat under a defined tracking model.'),
    _Metric('deterrence_rate', 'Deterrence Rate', 'Estimated reduction in opponent attempts or actions due to player presence.', percent: true),
  ]),
  _Category('On / Off', 'Team performance with the player on court, off court and the differential between those states.', [
    _Metric('on_off_net', 'On/Off Net', 'Difference in team net rating with the player on versus off court.', signed: true),
    _Metric('on_off_ortg', 'On/Off ORtg', 'Difference in team Offensive Rating with the player on versus off court.', signed: true),
    _Metric('on_off_drtg', 'On/Off DRtg', 'Difference in team Defensive Rating with the player on versus off court.', signed: true),
    _Metric('on_court_net', 'On Net', 'Team Net Rating while the player is on court.', signed: true),
    _Metric('off_court_net', 'Off Net', 'Team Net Rating while the player is off court.', signed: true),
    _Metric('on_court_ortg', 'On ORtg', 'Team Offensive Rating while the player is on court.'),
    _Metric('off_court_ortg', 'Off ORtg', 'Team Offensive Rating while the player is off court.'),
    _Metric('on_court_drtg', 'On DRtg', 'Team Defensive Rating while the player is on court.'),
    _Metric('off_court_drtg', 'Off DRtg', 'Team Defensive Rating while the player is off court.'),
    _Metric('on_court_pace', 'On Pace', 'Team pace while the player is on court.'),
    _Metric('off_court_pace', 'Off Pace', 'Team pace while the player is off court.'),
  ]),
  _Category('Lineups & Play Types', 'Lineup combinations, possession archetypes, screens, drives and cutting actions.', [
    _Metric('lineup_net', 'Lineup Net', 'Net Rating for the relevant lineup or player combination.', signed: true),
    _Metric('lineup_ortg', 'Lineup ORtg', 'Offensive Rating for the relevant lineup or player combination.'),
    _Metric('lineup_drtg', 'Lineup DRtg', 'Defensive Rating for the relevant lineup or player combination.'),
    _Metric('possessions', 'Poss', 'Possessions in the relevant lineup or play-type sample.', integer: true),
    _Metric('isolation_ppp', 'Isolation PPP', 'Points per possession on isolation plays.'),
    _Metric('transition_ppp', 'Transition PPP', 'Points per possession on offensive transition plays.'),
    _Metric('transition_def_ppp', 'Transition Def PPP', 'Points allowed per transition possession.'),
    _Metric('pnr_ball_handler_ppp', 'PnR Handler PPP', 'Points per possession as pick-and-roll ball handler.'),
    _Metric('pnr_roll_man_ppp', 'PnR Roll Man PPP', 'Points per possession as pick-and-roll roll man.'),
    _Metric('post_up_ppp', 'Post-Up PPP', 'Points per possession on post-ups.'),
    _Metric('spot_up_ppp', 'Spot-Up PPP', 'Points per possession on spot-up plays.'),
    _Metric('handoff_ppp', 'Handoff PPP', 'Points per possession on handoff plays.'),
    _Metric('cut_ppp', 'Cut PPP', 'Points per possession on cuts.'),
    _Metric('off_screen_ppp', 'Off-Screen PPP', 'Points per possession on off-screen actions.'),
    _Metric('putback_ppp', 'Putback PPP', 'Points per possession on putbacks.'),
    _Metric('drive_pts_pg', 'Drive PPG', 'Points per game generated directly from drives.'),
    _Metric('drive_ast_pg', 'Drive APG', 'Assists per game generated from drives.'),
    _Metric('screens_set_pg', 'Screens Set PG', 'Screens set per game by the screener.'),
    _Metric('screens_used_pg', 'Screens Used PG', 'Ball-handler possessions using a screen per game.'),
    _Metric('backdoor_cuts_pg', 'Backdoor Cuts PG', 'Backdoor cuts per game when event classification supports them.'),
    _Metric('v_cuts_pg', 'V-Cuts PG', 'V-cuts per game when event classification supports them.'),
    _Metric('l_cuts_pg', 'L-Cuts PG', 'L-cuts per game when event classification supports them.'),
  ]),
  _Category('Movement & Physical', 'Movement load, touch profile and physical measurements when a source provides them.', [
    _Metric('usg_pct', 'Usage', 'Usage percentage estimates the share of team possessions a player finishes while on court.', percent: true),
    _Metric('distance_traveled', 'Distance Traveled', 'Distance traveled per game or selected sample from player tracking.'),
    _Metric('avg_speed', 'Average Speed', 'Average movement speed while tracked.'),
    _Metric('time_per_touch', 'Time/Touch', 'Average seconds of possession per touch.'),
    _Metric('dribbles_per_touch', 'Dribbles/Touch', 'Average dribbles taken per touch.'),
    _Metric('height', 'Height', 'Listed or measured player height.'),
    _Metric('weight', 'Weight', 'Listed or measured player weight.'),
    _Metric('wingspan', 'Wingspan', 'Measured fingertip-to-fingertip wingspan.'),
    _Metric('standing_reach', 'Standing Reach', 'Measured standing reach.'),
    _Metric('hand_length', 'Hand Length', 'Measured hand length.'),
    _Metric('hand_width', 'Hand Width', 'Measured hand width.'),
    _Metric('standing_jump', 'Standing Jump', 'Measured standing vertical jump.'),
    _Metric('max_vertical', 'Max Vertical', 'Measured maximum vertical jump.'),
  ]),
  _Category('Discipline & Events', 'Violations, foul events, sanctions and unusual game-ending events.', [
    _Metric('technical_fouls', 'Technical Fouls', 'Technical fouls assessed to the player.'),
    _Metric('ejections', 'Ejections', 'Ejections recorded for the player.'),
    _Metric('disqualifications', 'Disqualifications', 'Game disqualifications recorded for the player.'),
    _Metric('suspensions', 'Suspensions', 'Games or incidents of suspension when a reliable source is available.'),
    _Metric('shooting_fouls', 'Shooting Fouls', 'Shooting fouls committed.'),
    _Metric('personal_fouls', 'Personal Fouls', 'Personal fouls committed.'),
    _Metric('offensive_fouls', 'Offensive Fouls', 'Offensive fouls committed.'),
    _Metric('defensive_fouls', 'Defensive Fouls', 'Defensive fouls committed.'),
    _Metric('travel', 'Travels', 'Traveling violations.'),
    _Metric('double_dribble', 'Double Dribble', 'Double-dribble violations.'),
    _Metric('discontinued_dribble', 'Discontinued Dribble', 'Discontinued-dribble violations.'),
    _Metric('off_three_sec', 'Off. 3 Sec', 'Offensive three-second violations.'),
    _Metric('def_three_sec', 'Def. 3 Sec', 'Defensive three-second violations.'),
    _Metric('backcourt', 'Backcourt', 'Backcourt violations.'),
    _Metric('palming', 'Palming', 'Palming/carrying violations.'),
    _Metric('off_goaltending', 'Off. Goaltend', 'Offensive goaltending violations.'),
    _Metric('def_goaltending', 'Def. Goaltend', 'Defensive goaltending violations.'),
    _Metric('kicked_ball', 'Kicked Ball', 'Kicked-ball violations.'),
    _Metric('game_buzzer_beaters', 'Game Buzzer Beaters', 'Made shots that beat the final game buzzer.'),
    _Metric('quarter_buzzer_beaters', 'Quarter Buzzer Beaters', 'Made shots that beat a quarter-ending buzzer.'),
    _Metric('shot_clock_beaters', 'Shot-Clock Beaters', 'Made shots released immediately before the shot clock expires.'),
  ]),
];

class _StatGlossary extends StatelessWidget {
  const _StatGlossary();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metrics = <_Metric>[];
    final seen = <String>{};
    for (final category in _categories) {
      for (final metric in category.metrics) {
        _collectMetric(metric, metrics, seen);
      }
    }
    metrics.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text('Stat Glossary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        subtitle: const Text('Concise definitions for every metric shown on this page.'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050 ? 3 : constraints.maxWidth >= 680 ? 2 : 1;
              final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(metric.glossary, style: TextStyle(color: colors.onSurfaceVariant, height: 1.35)),
                        ]),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

void _collectMetric(_Metric metric, List<_Metric> output, Set<String> seen) {
  if (seen.add(metric.key)) output.add(metric);
  for (final child in metric.children) {
    _collectMetric(child, output, seen);
  }
}

double? _metricValue(NbaStatsRow row, String key) {
  final normalized = row.value(key);
  if (normalized != null) return normalized;

  double? rawValue(List<String> names) {
    for (final name in names) {
      final value = row.raw[name];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  final aliases = <String, List<String>>{
    'min': ['mpg', 'min', 'minutes'], 'pts': ['ppg', 'pts', 'points'], 'reb': ['rpg', 'reb', 'trb'],
    'oreb': ['oreb', 'orb', 'offensive_rebounds'], 'dreb': ['dreb', 'drb', 'defensive_rebounds'],
    'ast': ['apg', 'ast', 'assists'], 'stl': ['spg', 'stl', 'steals'], 'blk': ['bpg', 'blk', 'blocks'],
    'tov': ['tpg', 'tov', 'turnovers'], 'pf': ['pf', 'personal_fouls'], 'personal_fouls': ['pf', 'personal_fouls'],
    'fgm': ['fgm'], 'fga': ['fga'], 'fg_pct': ['fg_pct'], 'three_made': ['fg3m', 'three_pm', 'three_made'],
    'three_att': ['fg3a', 'three_pa', 'three_att'], 'three_pct': ['fg3_pct', 'three_pct'],
    'ftm': ['ftm'], 'fta': ['fta'], 'ft_pct': ['ft_pct'], 'efg_pct': ['efg_pct'], 'ts_pct': ['ts_pct'],
    'per': ['per'], 'ws': ['win_shares', 'ws'], 'ws48': ['win_shares_per_48', 'ws48'],
    'obpm': ['offensive_bpm', 'obpm'], 'dbpm': ['defensive_bpm', 'dbpm'], 'bpm': ['avg_bpm', 'bpm'],
    'vorp': ['vorp'], 'usg_pct': ['usage_percentage', 'usg_pct'], 'ortg': ['offensive_rating', 'off_rating', 'ortg'],
    'drtg': ['defensive_rating', 'def_rating', 'drtg'], 'net_rating': ['net_rating'], 'pace': ['pace'], 'pie': ['pie'],
    'ast_pct': ['ast_pct'], 'tov_pct': ['tm_tov_pct', 'tov_pct', 'e_tov_pct'], 'stl_pct': ['stl_pct'],
    'blk_pct': ['blk_pct'], 'oreb_pct': ['oreb_pct'], 'dreb_pct': ['dreb_pct'], 'reb_pct': ['reb_pct', 'trb_pct'],
    'ast_tov': ['ast_to', 'ast_tov'], 'epm': ['epm'], 'lebron': ['lebron'], 'darko': ['darko'], 'rapm': ['rapm'],
    'la_rapm': ['la_rapm'], 'warv': ['warv'], 'deflections_pg': ['deflections_pg', 'deflections'],
    'charges_drawn_pg': ['charges_drawn_pg', 'charges_drawn'], 'contested_shots_pg': ['contested_shots_pg', 'contested_shots'],
    'loose_balls_recovered_pg': ['loose_balls_recovered_pg', 'loose_balls_recovered'],
    'dfg_pct': ['d_fg_pct', 'dfg_pct'], 'dfgm': ['d_fgm', 'dfgm'], 'dfga': ['d_fga', 'dfga'],
    'box_out_pct': ['box_out_pct', 'pct_box_outs_reb'], 'box_outs_pg': ['box_outs_pg', 'box_outs'],
    'screen_ast_pg': ['screen_ast_pg', 'screen_assists'], 'secondary_ast_pg': ['secondary_ast_pg', 'secondary_ast'],
    'potential_ast_pg': ['potential_ast_pg', 'potential_ast'], 'passes_pg': ['passes_pg', 'passes_made'],
    'ft_ast_pg': ['ft_ast_pg', 'ft_ast'], 'ast_points_created': ['ast_points_created'],
    'distance_traveled': ['distance_traveled', 'dist_miles'], 'avg_speed': ['avg_speed'],
    'time_per_touch': ['time_per_touch', 'time_of_possession_per_touch'], 'dribbles_per_touch': ['dribbles_per_touch'],
    'clutch_pts_pg': ['clutch_pts_pg', 'clutch_points', 'clutch_pts'], 'clutch_reb_pg': ['clutch_reb_pg'],
    'clutch_ast_pg': ['clutch_ast_pg'], 'clutch_stl_pg': ['clutch_stl_pg'], 'clutch_blk_pg': ['clutch_blk_pg'],
    'clutch_tov_pg': ['clutch_tov_pg'], 'clutch_fg_pct': ['clutch_fg_pct'], 'clutch_three_pct': ['clutch_three_pct'],
    'clutch_ft_pct': ['clutch_ft_pct'], 'clutch_efg_pct': ['clutch_efg_pct'], 'clutch_ts_pct': ['clutch_ts_pct'],
    'clutch_ortg': ['clutch_ortg'], 'clutch_drtg': ['clutch_drtg'], 'clutch_net': ['clutch_net'],
    'clutch_plus_minus': ['clutch_plus_minus'], 'gravity': ['gravity', 'gravity_score'],
    'spacing_value': ['spacing_value'], 'double_team_rate': ['double_team_rate'], 'on_off_net': ['on_off_net', 'on_off_net_rating'],
    'on_court_net': ['on_court_net', 'on_court_net_rating'], 'off_court_net': ['off_court_net', 'off_court_net_rating'],
    'lineup_net': ['lineup_net', 'lineup_net_rating'], 'possessions': ['possessions', 'poss'],
    'travel': ['travel'], 'double_dribble': ['double_dribble'], 'discontinued_dribble': ['discontinued_dribble'],
    'off_three_sec': ['off_three_sec'], 'def_three_sec': ['def_three_sec'], 'backcourt': ['backcourt'],
    'palming': ['palming'], 'off_goaltending': ['off_goaltending'], 'def_goaltending': ['def_goaltending'],
    'kicked_ball': ['kicked_ball'],
  };

  final direct = rawValue(aliases[key] ?? [key]);
  if (direct != null) return direct;

  // Transparent derivations from sourced traditional totals when the needed inputs exist.
  final fga = rawValue(['fga']);
  final fta = rawValue(['fta']);
  final threeA = rawValue(['fg3a', 'three_pa', 'three_att']);
  final pts = rawValue(['pts', 'points']);
  if (key == 'ftr' && fga != null && fga != 0 && fta != null) return fta / fga;
  if (key == 'three_par' && fga != null && fga != 0 && threeA != null) return threeA / fga;
  if (key == 'pps' && fga != null && fga != 0 && pts != null) return pts / fga;
  return null;
}

bool _matchesPosition(String value, String wanted) {
  final positions = RegExp(r'PG|SG|SF|PF|C').allMatches(value.toUpperCase()).map((match) => match.group(0)).whereType<String>().toSet();
  return positions.contains(wanted.toUpperCase());
}

String _formatMetric(double? value, _Metric metric) {
  if (value == null) return '—';
  if (metric.integer) return value.round().toString();
  if (metric.percent) {
    final scaled = value.abs() <= 1.5 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  if (metric.signed) return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  return value.toStringAsFixed(1);
}
