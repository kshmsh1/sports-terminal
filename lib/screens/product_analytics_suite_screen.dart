import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _suiteBg = Color(0xFF151C29);
const _suitePanel = Color(0xFF1D2636);
const _suitePanel2 = Color(0xFF252F41);
const _suiteLine = Color(0xFF364256);
const _suiteText = Color(0xFFF3F6FB);
const _suiteMuted = Color(0xFFA2ACBD);
const _suiteYellow = Color(0xFFFFCB45);
const _suiteCyan = Color(0xFF65D5FF);
const _suiteGreen = Color(0xFF65E3A5);

class ProductAnalyticsSuiteScreen extends StatefulWidget {
  const ProductAnalyticsSuiteScreen({super.key});

  @override
  State<ProductAnalyticsSuiteScreen> createState() => _ProductAnalyticsSuiteScreenState();
}

class _ProductAnalyticsSuiteScreenState extends State<ProductAnalyticsSuiteScreen> {
  final NbaStatsWorkstationEngine engine = const NbaStatsWorkstationEngine();
  String tool = 'Player Dashboard';
  NbaStatsBasis basis = NbaStatsBasis.perGame;
  String? playerA;
  String? playerB;
  String teamA = 'BOS';
  String teamB = 'OKC';
  String rankMetric = 'game_score_proxy';
  String rankPosition = 'All';
  int lastGames = 10;
  final Set<String> lineupIds = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SuiteSurface(child: Text('Loading Analytics Suite…', style: TextStyle(color: _suiteMuted)));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _SuiteSurface(child: Text('Analytics unavailable: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        final data = snapshot.data!;
        final rows = engine.buildRows(data, basis: basis);
        engine.sortRows(rows, 'game_score_proxy');
        playerA ??= rows.isEmpty ? null : rows.first.playerId;
        playerB ??= rows.length < 2 ? playerA : rows[1].playerId;
        final teams = engine.groupByTeam(rows).keys.toList()..sort();
        if (teams.isNotEmpty) {
          if (!teams.contains(teamA)) teamA = teams.first;
          if (!teams.contains(teamB)) teamB = teams.length > 1 ? teams[1] : teams.first;
        }

        return Container(
          color: _suiteBg,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SuiteHeader(
                active: tool,
                basis: basis,
                onBasis: (value) => setState(() => basis = value),
              ),
              const SizedBox(height: 12),
              _FeatureGrid(active: tool, onSelect: (value) => setState(() => tool = value)),
              const SizedBox(height: 12),
              _buildTool(data, rows, teams),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTool(
    NbaTerminalSeedSnapshot data,
    List<NbaStatsRow> rows,
    List<String> teams,
  ) {
    switch (tool) {
      case 'Player Dashboard':
        return _PlayerDashboard(
          data: data,
          rows: rows,
          engine: engine,
          playerId: playerA,
          lastGames: lastGames,
          onPlayer: (value) => setState(() => playerA = value),
          onGames: (value) => setState(() => lastGames = value),
        );
      case 'Player Compare':
        return _PlayerCompare(
          rows: rows,
          engine: engine,
          playerA: playerA,
          playerB: playerB,
          onPlayerA: (value) => setState(() => playerA = value),
          onPlayerB: (value) => setState(() => playerB = value),
        );
      case 'Team Compare':
        return _TeamCompare(
          data: data,
          rows: rows,
          teams: teams,
          teamA: teamA,
          teamB: teamB,
          onTeamA: (value) => setState(() => teamA = value),
          onTeamB: (value) => setState(() => teamB = value),
        );
      case 'Rankings':
        return _RankingsTool(
          rows: rows,
          engine: engine,
          metricKey: rankMetric,
          position: rankPosition,
          onMetric: (value) => setState(() => rankMetric = value),
          onPosition: (value) => setState(() => rankPosition = value),
        );
      case 'Last X Games':
        return _LastGamesTool(
          data: data,
          rows: rows,
          playerId: playerA,
          lastGames: lastGames,
          onPlayer: (value) => setState(() => playerA = value),
          onGames: (value) => setState(() => lastGames = value),
        );
      case 'Shot Profile':
        return _ShotProfileTool(
          rows: rows,
          playerId: playerA,
          onPlayer: (value) => setState(() => playerA = value),
        );
      case 'Lineup Builder':
        return _LineupBuilder(
          rows: rows,
          teams: teams,
          team: teamA,
          selectedIds: lineupIds,
          onTeam: (value) => setState(() {
            teamA = value;
            lineupIds.clear();
          }),
          onToggle: (value) => setState(() {
            if (!lineupIds.add(value)) lineupIds.remove(value);
            while (lineupIds.length > 5) {
              lineupIds.remove(lineupIds.first);
            }
          }),
        );
      case 'Tier List':
        return _TierListTool(
          rows: rows,
          engine: engine,
          metricKey: rankMetric,
          onMetric: (value) => setState(() => rankMetric = value),
        );
      case 'ORtg Sandbox':
        return const _OffensiveRatingSandbox();
      case 'Data Coverage':
        return _DataCoverageTool(data: data);
      default:
        return _MethodologyGate(tool: tool);
    }
  }
}

class _SuiteHeader extends StatelessWidget {
  const _SuiteHeader({required this.active, required this.basis, required this.onBasis});
  final String active;
  final NbaStatsBasis basis;
  final ValueChanged<NbaStatsBasis> onBasis;

  @override
  Widget build(BuildContext context) => _SuiteSurface(
        child: Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NBA ANALYTICS SUITE', style: TextStyle(color: _suiteYellow, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                SizedBox(height: 3),
                Text('One connected research surface, not twenty disconnected microsites.', style: TextStyle(color: _suiteText, fontSize: 19, fontWeight: FontWeight.w900)),
              ],
            ),
            const Spacer(),
            Text(active, style: const TextStyle(color: _suiteMuted, fontWeight: FontWeight.w800)),
            DropdownButton<NbaStatsBasis>(
              value: basis,
              dropdownColor: _suitePanel2,
              style: const TextStyle(color: _suiteText, fontSize: 11, fontWeight: FontWeight.w800),
              underline: const SizedBox.shrink(),
              items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))],
              onChanged: (value) { if (value != null) onBasis(value); },
            ),
          ],
        ),
      );
}

class _FeatureDefinition {
  const _FeatureDefinition(this.title, this.description, this.icon, {this.sourceRequired = false});
  final String title;
  final String description;
  final IconData icon;
  final bool sourceRequired;
}

const _features = <_FeatureDefinition>[
  _FeatureDefinition('Player Dashboard', 'Percentiles, recent form, shooting and impact profile.', Icons.person_search_rounded),
  _FeatureDefinition('Player Compare', 'Side-by-side metric and percentile comparison.', Icons.compare_arrows_rounded),
  _FeatureDefinition('Team Compare', 'Records, roster production and team context.', Icons.balance_rounded),
  _FeatureDefinition('Rankings', 'Rank every player by any supported metric.', Icons.format_list_numbered_rounded),
  _FeatureDefinition('Last X Games', 'Recent game logs and rolling form.', Icons.timeline_rounded),
  _FeatureDefinition('Shot Profile', 'Two, three and free-throw volume and efficiency.', Icons.radar_rounded),
  _FeatureDefinition('Lineup Builder', 'Build five-player groups from sourced roster production.', Icons.groups_rounded),
  _FeatureDefinition('Tier List', 'Transparent metric-driven player tiers.', Icons.emoji_events_rounded),
  _FeatureDefinition('ORtg Sandbox', 'Interactive possession-efficiency calculator.', Icons.calculate_rounded),
  _FeatureDefinition('Data Coverage', 'Inspect what is sourced, derived, estimated or unavailable.', Icons.fact_check_rounded),
  _FeatureDefinition('WOWY Lineups', 'Together/apart possession analysis.', Icons.hub_rounded, sourceRequired: true),
  _FeatureDefinition('Matchup Matrix', 'Tracking-based defender and matchup outcomes.', Icons.grid_view_rounded, sourceRequired: true),
  _FeatureDefinition('Impact Decomposition', 'RAPM and component-model research.', Icons.science_rounded, sourceRequired: true),
  _FeatureDefinition('Shot Quality', 'Pre-shot quality, making and contest decomposition.', Icons.track_changes_rounded, sourceRequired: true),
  _FeatureDefinition('Draft Analysis', 'Prospect rankings and historical comparisons.', Icons.school_rounded, sourceRequired: true),
];

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.active, required this.onSelect});
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1200 ? 5 : constraints.maxWidth >= 850 ? 4 : constraints.maxWidth >= 600 ? 3 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final feature in _features)
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    feature: feature,
                    selected: active == feature.title,
                    onTap: () => onSelect(feature.title),
                  ),
                ),
            ],
          );
        },
      );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature, required this.selected, required this.onTap});
  final _FeatureDefinition feature;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF343849) : _suitePanel,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 122,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: selected ? _suiteYellow : _suiteLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(feature.icon, color: _suiteYellow, size: 19),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _suiteText, fontSize: 12, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 8),
                Expanded(child: Text(feature.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _suiteMuted, fontSize: 10, height: 1.35))),
                if (feature.sourceRequired)
                  const Text('SOURCE FEED REQUIRED', style: TextStyle(color: _suiteCyan, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .5)),
              ],
            ),
          ),
        ),
      );
}

class _PlayerDashboard extends StatelessWidget {
  const _PlayerDashboard({
    required this.data,
    required this.rows,
    required this.engine,
    required this.playerId,
    required this.lastGames,
    required this.onPlayer,
    required this.onGames,
  });

  final NbaTerminalSeedSnapshot data;
  final List<NbaStatsRow> rows;
  final NbaStatsWorkstationEngine engine;
  final String? playerId;
  final int lastGames;
  final ValueChanged<String?> onPlayer;
  final ValueChanged<int> onGames;

  @override
  Widget build(BuildContext context) {
    final player = _findRow(rows, playerId);
    final logs = data.playerGameLogsTop.where((row) => _rawText(row, const ['player_id', 'id']) == player?.playerId).take(lastGames).toList();
    final metrics = const ['pts', 'ast', 'reb', 'ts_pct', 'plus_minus', 'bpm', 'game_score_proxy', 'defense_events'];
    return _ToolSurface(
      title: 'Player Dashboard',
      subtitle: 'A source-aware profile with visible percentiles and recent-game evidence.',
      controls: [
        _PlayerDrop(rows: rows, value: playerId, onChanged: onPlayer),
        _SmallDrop<int>(value: lastGames, values: const [5, 10, 15, 20, 30], label: 'Recent games', onChanged: onGames),
      ],
      child: player == null
          ? const _EmptyTool('No player is available for the current dataset.')
          : Column(
              children: [
                _MetricCards(
                  items: [
                    for (final key in metrics.take(4))
                      _MetricCard(engine.metric(key).shortLabel, engine.formatValue(key, player.value(key)), player.percentiles[key]),
                  ],
                ),
                const SizedBox(height: 10),
                _PercentileProfile(row: player, keys: metrics, engine: engine),
                const SizedBox(height: 10),
                _GameLogTable(logs: logs),
              ],
            ),
    );
  }
}

class _PlayerCompare extends StatelessWidget {
  const _PlayerCompare({
    required this.rows,
    required this.engine,
    required this.playerA,
    required this.playerB,
    required this.onPlayerA,
    required this.onPlayerB,
  });
  final List<NbaStatsRow> rows;
  final NbaStatsWorkstationEngine engine;
  final String? playerA;
  final String? playerB;
  final ValueChanged<String?> onPlayerA;
  final ValueChanged<String?> onPlayerB;

  @override
  Widget build(BuildContext context) {
    final a = _findRow(rows, playerA);
    final b = _findRow(rows, playerB);
    final keys = const ['pts', 'ast', 'reb', 'stl', 'blk', 'tov', 'ts_pct', 'efg_pct', 'plus_minus', 'bpm', 'game_score_proxy', 'defense_events'];
    return _ToolSurface(
      title: 'Player Compare',
      subtitle: 'Compare values and percentile position without switching pages.',
      controls: [
        _PlayerDrop(rows: rows, value: playerA, onChanged: onPlayerA, label: 'Player A'),
        _PlayerDrop(rows: rows, value: playerB, onChanged: onPlayerB, label: 'Player B'),
      ],
      child: a == null || b == null
          ? const _EmptyTool('Choose two players.')
          : Column(
              children: [
                for (final key in keys)
                  _ComparisonBar(
                    label: engine.metric(key).label,
                    valueA: engine.formatValue(key, a.value(key)),
                    valueB: engine.formatValue(key, b.value(key)),
                    percentileA: a.percentiles[key] ?? 0,
                    percentileB: b.percentiles[key] ?? 0,
                    nameA: a.player,
                    nameB: b.player,
                  ),
              ],
            ),
    );
  }
}

class _TeamCompare extends StatelessWidget {
  const _TeamCompare({
    required this.data,
    required this.rows,
    required this.teams,
    required this.teamA,
    required this.teamB,
    required this.onTeamA,
    required this.onTeamB,
  });
  final NbaTerminalSeedSnapshot data;
  final List<NbaStatsRow> rows;
  final List<String> teams;
  final String teamA;
  final String teamB;
  final ValueChanged<String> onTeamA;
  final ValueChanged<String> onTeamB;

  @override
  Widget build(BuildContext context) {
    final rosterA = rows.where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(teamA)).toList();
    final rosterB = rows.where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(teamB)).toList();
    final recordA = _teamRecord(data.teamRecords, teamA);
    final recordB = _teamRecord(data.teamRecords, teamB);
    final metrics = <_TeamMetric>[
      _TeamMetric('Wins', _recordValue(recordA, const ['wins', 'w']), _recordValue(recordB, const ['wins', 'w'])),
      _TeamMetric('Losses', _recordValue(recordA, const ['losses', 'l']), _recordValue(recordB, const ['losses', 'l']), lowerBetter: true),
      _TeamMetric('Roster PPG sum', _sum(rosterA, 'pts'), _sum(rosterB, 'pts')),
      _TeamMetric('Roster AST sum', _sum(rosterA, 'ast'), _sum(rosterB, 'ast')),
      _TeamMetric('Top-8 production', _topSum(rosterA, 'game_score_proxy', 8), _topSum(rosterB, 'game_score_proxy', 8)),
      _TeamMetric('Top-8 defensive events', _topSum(rosterA, 'defense_events', 8), _topSum(rosterB, 'defense_events', 8)),
    ];
    return _ToolSurface(
      title: 'Team Compare',
      subtitle: 'Team record context plus roster-production comparisons from the same normalized player layer.',
      controls: [
        _SmallDrop<String>(value: teamA, values: teams, label: 'Team A', onChanged: onTeamA),
        _SmallDrop<String>(value: teamB, values: teams, label: 'Team B', onChanged: onTeamB),
      ],
      child: Column(
        children: [
          for (final metric in metrics) _TeamComparisonRow(metric: metric, teamA: teamA, teamB: teamB),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _RosterList(team: teamA, rows: rosterA)),
              const SizedBox(width: 10),
              Expanded(child: _RosterList(team: teamB, rows: rosterB)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingsTool extends StatelessWidget {
  const _RankingsTool({
    required this.rows,
    required this.engine,
    required this.metricKey,
    required this.position,
    required this.onMetric,
    required this.onPosition,
  });
  final List<NbaStatsRow> rows;
  final NbaStatsWorkstationEngine engine;
  final String metricKey;
  final String position;
  final ValueChanged<String> onMetric;
  final ValueChanged<String> onPosition;

  @override
  Widget build(BuildContext context) {
    final ranked = rows.where((row) => position == 'All' || row.position == position).toList();
    engine.sortRows(ranked, metricKey);
    return _ToolSurface(
      title: 'Rankings',
      subtitle: 'A transparent ranking table for every metric supported by the Stats Workstation.',
      controls: [
        _MetricDrop(value: metricKey, onChanged: onMetric),
        _SmallDrop<String>(value: position, values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'], label: 'Position', onChanged: onPosition),
      ],
      child: Column(
        children: [
          for (var index = 0; index < math.min(50, ranked.length); index++)
            _RankingRow(index: index + 1, row: ranked[index], value: engine.formatValue(metricKey, ranked[index].value(metricKey)), percentile: ranked[index].percentiles[metricKey]),
        ],
      ),
    );
  }
}

class _LastGamesTool extends StatelessWidget {
  const _LastGamesTool({required this.data, required this.rows, required this.playerId, required this.lastGames, required this.onPlayer, required this.onGames});
  final NbaTerminalSeedSnapshot data;
  final List<NbaStatsRow> rows;
  final String? playerId;
  final int lastGames;
  final ValueChanged<String?> onPlayer;
  final ValueChanged<int> onGames;

  @override
  Widget build(BuildContext context) {
    final logs = data.playerGameLogsTop.where((row) => _rawText(row, const ['player_id', 'id']) == playerId).take(lastGames).toList();
    final points = [for (final row in logs.reversed) _rawNumber(row, const ['pts', 'points']) ?? 0];
    final rebounds = [for (final row in logs.reversed) _rawNumber(row, const ['trb', 'reb', 'rebounds']) ?? 0];
    final assists = [for (final row in logs.reversed) _rawNumber(row, const ['ast', 'assists']) ?? 0];
    return _ToolSurface(
      title: 'Last X Games',
      subtitle: 'Recent-form analysis uses only available game-log rows; missing games remain missing.',
      controls: [
        _PlayerDrop(rows: rows, value: playerId, onChanged: onPlayer),
        _SmallDrop<int>(value: lastGames, values: const [5, 10, 15, 20, 30], label: 'Games', onChanged: onGames),
      ],
      child: logs.isEmpty
          ? const _EmptyTool('No player-game rows are available for this player in the current asset release.')
          : Column(
              children: [
                _MetricCards(items: [
                  _MetricCard('PTS AVG', _average(points).toStringAsFixed(1), null),
                  _MetricCard('REB AVG', _average(rebounds).toStringAsFixed(1), null),
                  _MetricCard('AST AVG', _average(assists).toStringAsFixed(1), null),
                  _MetricCard('GAMES', '${logs.length}', null),
                ]),
                const SizedBox(height: 10),
                SizedBox(height: 180, child: _SparklinePanel(series: {'PTS': points, 'REB': rebounds, 'AST': assists})),
                const SizedBox(height: 10),
                _GameLogTable(logs: logs),
              ],
            ),
    );
  }
}

class _ShotProfileTool extends StatelessWidget {
  const _ShotProfileTool({required this.rows, required this.playerId, required this.onPlayer});
  final List<NbaStatsRow> rows;
  final String? playerId;
  final ValueChanged<String?> onPlayer;

  @override
  Widget build(BuildContext context) {
    final player = _findRow(rows, playerId);
    final twoA = player?.value('two_pa') ?? 0;
    final threeA = player?.value('three_pa') ?? 0;
    final fta = player?.value('fta') ?? 0;
    final total = math.max(.0001, twoA + threeA + .44 * fta);
    final segments = [
      _ProfileSegment('Two-point volume', twoA / total, player?.value('two_pct')),
      _ProfileSegment('Three-point volume', threeA / total, player?.value('three_pct')),
      _ProfileSegment('Free-throw pressure', .44 * fta / total, player?.value('ft_pct')),
    ];
    return _ToolSurface(
      title: 'Shot Profile',
      subtitle: 'A source-backed shot-mix view from two-point, three-point and free-throw box-score data.',
      controls: [_PlayerDrop(rows: rows, value: playerId, onChanged: onPlayer)],
      child: player == null
          ? const _EmptyTool('Choose a player.')
          : Column(
              children: [
                for (final segment in segments) _ShotProfileBar(segment: segment),
                const SizedBox(height: 10),
                const _SourceNotice('Rim, midrange, openness and shot-quality components require location/tracking data and are not inferred from aggregate box scores.'),
              ],
            ),
    );
  }
}

class _LineupBuilder extends StatelessWidget {
  const _LineupBuilder({required this.rows, required this.teams, required this.team, required this.selectedIds, required this.onTeam, required this.onToggle});
  final List<NbaStatsRow> rows;
  final List<String> teams;
  final String team;
  final Set<String> selectedIds;
  final ValueChanged<String> onTeam;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final roster = rows.where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(team)).toList()..sort((a, b) => (b.value('min') ?? 0).compareTo(a.value('min') ?? 0));
    final selected = roster.where((row) => selectedIds.contains(row.playerId)).toList();
    return _ToolSurface(
      title: 'Lineup Builder',
      subtitle: 'Select up to five players. Aggregates are honest roster-production sums, not fabricated on/off or RAPM estimates.',
      controls: [_SmallDrop<String>(value: team, values: teams, label: 'Team', onChanged: onTeam)],
      child: Column(
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final row in roster)
                FilterChip(
                  selected: selectedIds.contains(row.playerId),
                  onSelected: (_) => onToggle(row.playerId),
                  selectedColor: const Color(0xFF4B4533),
                  checkmarkColor: _suiteYellow,
                  backgroundColor: _suitePanel2,
                  label: Text(row.player, style: const TextStyle(color: _suiteText, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricCards(items: [
            _MetricCard('PLAYERS', '${selected.length}/5', null),
            _MetricCard('PTS SUM', _sum(selected, 'pts').toStringAsFixed(1), null),
            _MetricCard('AST SUM', _sum(selected, 'ast').toStringAsFixed(1), null),
            _MetricCard('PROD SUM', _sum(selected, 'game_score_proxy').toStringAsFixed(1), null),
          ]),
          const SizedBox(height: 10),
          const _SourceNotice('True together/apart performance, possessions and lineup net rating will activate only when normalized lineup stints are present.'),
        ],
      ),
    );
  }
}

class _TierListTool extends StatelessWidget {
  const _TierListTool({required this.rows, required this.engine, required this.metricKey, required this.onMetric});
  final List<NbaStatsRow> rows;
  final NbaStatsWorkstationEngine engine;
  final String metricKey;
  final ValueChanged<String> onMetric;

  @override
  Widget build(BuildContext context) {
    final ranked = [...rows];
    engine.sortRows(ranked, metricKey);
    final tiers = <String, List<NbaStatsRow>>{
      'S · 95th percentile+': ranked.where((row) => (row.percentiles[metricKey] ?? 0) >= 95).toList(),
      'A · 85–94': ranked.where((row) => (row.percentiles[metricKey] ?? 0) >= 85 && (row.percentiles[metricKey] ?? 0) < 95).toList(),
      'B · 70–84': ranked.where((row) => (row.percentiles[metricKey] ?? 0) >= 70 && (row.percentiles[metricKey] ?? 0) < 85).toList(),
      'C · 50–69': ranked.where((row) => (row.percentiles[metricKey] ?? 0) >= 50 && (row.percentiles[metricKey] ?? 0) < 70).toList(),
      'D · below 50': ranked.where((row) => (row.percentiles[metricKey] ?? 0) < 50).toList(),
    };
    return _ToolSurface(
      title: 'Tier List',
      subtitle: 'Automatic tiers from transparent percentile rules; no hidden editorial score.',
      controls: [_MetricDrop(value: metricKey, onChanged: onMetric)],
      child: Column(
        children: [
          for (final entry in tiers.entries)
            _TierBand(title: entry.key, players: entry.value.take(25).toList(), metricKey: metricKey, engine: engine),
        ],
      ),
    );
  }
}

class _OffensiveRatingSandbox extends StatefulWidget {
  const _OffensiveRatingSandbox();

  @override
  State<_OffensiveRatingSandbox> createState() => _OffensiveRatingSandboxState();
}

class _OffensiveRatingSandboxState extends State<_OffensiveRatingSandbox> {
  double twoPct = .54;
  double threePct = .36;
  double threeRate = .42;
  double freeThrowRate = .24;
  double freeThrowPct = .78;
  double turnoverRate = .13;
  double offensiveReboundRate = .27;

  double get rating {
    final fieldGoalAttempts = 100 * (1 - turnoverRate);
    final threeAttempts = fieldGoalAttempts * threeRate;
    final twoAttempts = fieldGoalAttempts - threeAttempts;
    final fieldPoints = twoAttempts * twoPct * 2 + threeAttempts * threePct * 3;
    final freeThrowPoints = fieldGoalAttempts * freeThrowRate * freeThrowPct;
    final secondChanceBonus = fieldGoalAttempts * (1 - (twoPct * (1 - threeRate) + threePct * threeRate)) * offensiveReboundRate * 1.05;
    return fieldPoints + freeThrowPoints + secondChanceBonus;
  }

  @override
  Widget build(BuildContext context) => _ToolSurface(
        title: 'Offensive Rating Sandbox',
        subtitle: 'Move transparent possession levers and see the modeled points per 100 possessions.',
        controls: const [],
        child: Column(
          children: [
            _MetricCards(items: [
              _MetricCard('MODELED ORTG', rating.toStringAsFixed(1), null),
              _MetricCard('2P%', '${(twoPct * 100).toStringAsFixed(1)}%', null),
              _MetricCard('3P%', '${(threePct * 100).toStringAsFixed(1)}%', null),
              _MetricCard('TOV%', '${(turnoverRate * 100).toStringAsFixed(1)}%', null),
            ]),
            const SizedBox(height: 12),
            _Slider('Two-point percentage', twoPct, .35, .75, (value) => setState(() => twoPct = value)),
            _Slider('Three-point percentage', threePct, .20, .55, (value) => setState(() => threePct = value)),
            _Slider('Three-point attempt rate', threeRate, .10, .70, (value) => setState(() => threeRate = value)),
            _Slider('Free-throw attempt rate', freeThrowRate, .05, .60, (value) => setState(() => freeThrowRate = value)),
            _Slider('Free-throw percentage', freeThrowPct, .50, .95, (value) => setState(() => freeThrowPct = value)),
            _Slider('Turnover rate', turnoverRate, .05, .25, (value) => setState(() => turnoverRate = value), lowerBetter: true),
            _Slider('Offensive rebound rate', offensiveReboundRate, .10, .45, (value) => setState(() => offensiveReboundRate = value)),
            const _SourceNotice('This sandbox is a transparent possession model, not an official NBA offensive-rating formula or a prediction of a specific team.'),
          ],
        ),
      );
}

class _DataCoverageTool extends StatelessWidget {
  const _DataCoverageTool({required this.data});
  final NbaTerminalSeedSnapshot data;

  @override
  Widget build(BuildContext context) {
    final checks = <_CoverageItem>[
      _CoverageItem('Player identities', data.players.length, true, 'Sourced player identity rows'),
      _CoverageItem('Player season summaries', data.playerSeasonTotals.length, true, 'Core Stats and rankings input'),
      _CoverageItem('Games', data.games.length, true, 'Schedule and results layer'),
      _CoverageItem('Player game logs', data.playerGameLogsTop.length, data.playerGameLogsTop.isNotEmpty, 'Recent-form and trend layer'),
      _CoverageItem('Team records', data.teamRecords.length, true, 'Team comparison context'),
      _CoverageItem('Standings', data.standings.length, data.standings.isNotEmpty, 'Conference and playoff context'),
      _CoverageItem('Normalized play-by-play', data.playByPlayEvents, data.playByPlayEvents > 0, 'Required for possession research'),
    ];
    return _ToolSurface(
      title: 'Data Coverage',
      subtitle: 'Inspect the actual release before interpreting a missing tool as a zero or negative result.',
      controls: const [],
      child: Column(
        children: [
          for (final item in checks) _CoverageRow(item: item),
          const SizedBox(height: 10),
          _SourceNotice('Dataset status: ${data.datasetStatus} · Validation: ${data.validationStatus} · Assets: ${data.assetPath}'),
        ],
      ),
    );
  }
}

class _MethodologyGate extends StatelessWidget {
  const _MethodologyGate({required this.tool});
  final String tool;

  @override
  Widget build(BuildContext context) => _ToolSurface(
        title: tool,
        subtitle: 'The interface contract is reserved, but Sports Terminal will not publish synthetic tracking or RAPM output.',
        controls: const [],
        child: const Column(
          children: [
            Icon(Icons.lock_clock_rounded, color: _suiteYellow, size: 44),
            SizedBox(height: 12),
            Text('SOURCE-BOUND MODULE', style: TextStyle(color: _suiteText, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('This module activates when its normalized source tables, methodology version, validation report and provenance record are present. Until then, the product explains the requirement instead of filling the screen with unsupported estimates.', textAlign: TextAlign.center, style: TextStyle(color: _suiteMuted, height: 1.5)),
          ],
        ),
      );
}

class _ToolSurface extends StatelessWidget {
  const _ToolSurface({required this.title, required this.subtitle, required this.controls, required this.child});
  final String title;
  final String subtitle;
  final List<Widget> controls;
  final Widget child;

  @override
  Widget build(BuildContext context) => _SuiteSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 460,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: _suiteText, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: _suiteMuted, fontSize: 11, height: 1.4)),
                  ]),
                ),
                ...controls,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _SuiteSurface extends StatelessWidget {
  const _SuiteSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _suitePanel, borderRadius: BorderRadius.circular(10), border: Border.all(color: _suiteLine)),
        child: child,
      );
}

class _PlayerDrop extends StatelessWidget {
  const _PlayerDrop({required this.rows, required this.value, required this.onChanged, this.label = 'Player'});
  final List<NbaStatsRow> rows;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        child: DropdownButtonFormField<String>(
          value: rows.any((row) => row.playerId == value) ? value : null,
          dropdownColor: _suitePanel2,
          style: const TextStyle(color: _suiteText, fontSize: 11),
          decoration: _suiteInput(label),
          items: [for (final row in rows.take(150)) DropdownMenuItem(value: row.playerId, child: Text('${row.player} · ${row.team}', overflow: TextOverflow.ellipsis))],
          onChanged: onChanged,
        ),
      );
}

class _MetricDrop extends StatelessWidget {
  const _MetricDrop({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: _suitePanel2,
          style: const TextStyle(color: _suiteText, fontSize: 11),
          decoration: _suiteInput('Metric'),
          items: [for (final metric in nbaStatMetrics) DropdownMenuItem(value: metric.key, child: Text('${metric.group} · ${metric.label}', overflow: TextOverflow.ellipsis))],
          onChanged: (next) { if (next != null) onChanged(next); },
        ),
      );
}

class _SmallDrop<T> extends StatelessWidget {
  const _SmallDrop({required this.value, required this.values, required this.label, required this.onChanged});
  final T value;
  final List<T> values;
  final String label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: DropdownButtonFormField<T>(
          value: values.contains(value) ? value : values.first,
          dropdownColor: _suitePanel2,
          style: const TextStyle(color: _suiteText, fontSize: 11),
          decoration: _suiteInput(label),
          items: [for (final item in values) DropdownMenuItem<T>(value: item, child: Text('$item'))],
          onChanged: (next) { if (next != null) onChanged(next); },
        ),
      );
}

InputDecoration _suiteInput(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _suiteMuted, fontSize: 10),
      filled: true,
      fillColor: _suitePanel2,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _suiteLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _suiteLine)),
    );

class _MetricCard {
  const _MetricCard(this.label, this.value, this.percentile);
  final String label;
  final String value;
  final double? percentile;
}

class _MetricCards extends StatelessWidget {
  const _MetricCards({required this.items});
  final List<_MetricCard> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(135.0, (constraints.maxWidth - (items.length - 1) * 8) / items.length);
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                Container(
                  width: width,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.label, style: const TextStyle(color: _suiteMuted, fontSize: 9, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Expanded(child: Text(item.value, style: const TextStyle(color: _suiteText, fontSize: 20, fontWeight: FontWeight.w900))),
                      if (item.percentile != null) _PctPill(item.percentile!),
                    ]),
                  ]),
                ),
            ],
          );
        },
      );
}

class _PercentileProfile extends StatelessWidget {
  const _PercentileProfile({required this.row, required this.keys, required this.engine});
  final NbaStatsRow row;
  final List<String> keys;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 125, child: Text(engine.metric(key).shortLabel, style: const TextStyle(color: _suiteMuted, fontSize: 10, fontWeight: FontWeight.w800))),
                Expanded(child: _PercentileTrack(value: row.percentiles[key] ?? 0)),
                const SizedBox(width: 8),
                SizedBox(width: 62, child: Text(engine.formatValue(key, row.value(key)), textAlign: TextAlign.right, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900))),
              ]),
            ),
        ],
      );
}

class _PercentileTrack extends StatelessWidget {
  const _PercentileTrack({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(height: 9, decoration: BoxDecoration(color: _suiteBg, borderRadius: BorderRadius.circular(8))),
          FractionallySizedBox(widthFactor: (value / 100).clamp(0, 1), child: Container(height: 9, decoration: BoxDecoration(color: value >= 80 ? _suiteYellow : value >= 50 ? _suiteGreen : _suiteCyan, borderRadius: BorderRadius.circular(8)))),
        ],
      );
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({required this.label, required this.valueA, required this.valueB, required this.percentileA, required this.percentileB, required this.nameA, required this.nameB});
  final String label;
  final String valueA;
  final String valueB;
  final double percentileA;
  final double percentileB;
  final String nameA;
  final String nameB;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
        child: Row(children: [
          SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(valueA, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900)), Text(nameA, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _suiteMuted, fontSize: 8))])),
          Expanded(child: Column(children: [Text(label, style: const TextStyle(color: _suiteMuted, fontSize: 9, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Row(children: [Expanded(child: _PercentileTrack(value: percentileA)), const SizedBox(width: 5), Text('${percentileA.round()}', style: const TextStyle(color: _suiteYellow, fontSize: 8)), const SizedBox(width: 10), Text('${percentileB.round()}', style: const TextStyle(color: _suiteCyan, fontSize: 8)), const SizedBox(width: 5), Expanded(child: _PercentileTrack(value: percentileB))])])),
          SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(valueB, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900)), Text(nameB, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _suiteMuted, fontSize: 8))])),
        ]),
      );
}

class _GameLogTable extends StatelessWidget {
  const _GameLogTable({required this.logs});
  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
        child: Column(
          children: [
            const _GameRow(values: ['GAME', 'TEAM', 'PTS', 'REB', 'AST', '+/-'], header: true),
            for (final row in logs)
              _GameRow(values: [
                _rawText(row, const ['game_id', 'date']),
                _rawText(row, const ['team_id', 'team']),
                _displayNumber(_rawNumber(row, const ['pts', 'points'])),
                _displayNumber(_rawNumber(row, const ['trb', 'reb', 'rebounds'])),
                _displayNumber(_rawNumber(row, const ['ast', 'assists'])),
                _displayNumber(_rawNumber(row, const ['plus_minus', 'plusMinus']), signed: true),
              ]),
          ],
        ),
      );
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.values, this.header = false});
  final List<String> values;
  final bool header;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _suiteLine, width: .5))),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(children: [for (final value in values) Expanded(child: Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: header ? _suiteMuted : _suiteText, fontSize: header ? 8 : 10, fontWeight: header ? FontWeight.w900 : FontWeight.w700)))]),
      );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.index, required this.row, required this.value, required this.percentile});
  final int index;
  final NbaStatsRow row;
  final String value;
  final double? percentile;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(7), border: Border.all(color: _suiteLine)),
        child: Row(children: [
          SizedBox(width: 34, child: Text('#$index', style: TextStyle(color: index <= 3 ? _suiteYellow : _suiteMuted, fontWeight: FontWeight.w900))),
          Expanded(child: Text(row.player, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900))),
          SizedBox(width: 90, child: Text('${row.team} · ${row.position}', style: const TextStyle(color: _suiteMuted, fontSize: 9))),
          SizedBox(width: 80, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          if (percentile != null) _PctPill(percentile!),
        ]),
      );
}

class _TeamMetric {
  const _TeamMetric(this.label, this.a, this.b, {this.lowerBetter = false});
  final String label;
  final double a;
  final double b;
  final bool lowerBetter;
}

class _TeamComparisonRow extends StatelessWidget {
  const _TeamComparisonRow({required this.metric, required this.teamA, required this.teamB});
  final _TeamMetric metric;
  final String teamA;
  final String teamB;

  @override
  Widget build(BuildContext context) {
    final aWins = metric.lowerBetter ? metric.a < metric.b : metric.a > metric.b;
    final bWins = metric.lowerBetter ? metric.b < metric.a : metric.b > metric.a;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(7), border: Border.all(color: _suiteLine)),
      child: Row(children: [
        SizedBox(width: 100, child: Text('$teamA  ${metric.a.toStringAsFixed(1)}', style: TextStyle(color: aWins ? _suiteYellow : _suiteText, fontWeight: FontWeight.w900))),
        Expanded(child: Text(metric.label, textAlign: TextAlign.center, style: const TextStyle(color: _suiteMuted, fontSize: 9, fontWeight: FontWeight.w800))),
        SizedBox(width: 100, child: Text('${metric.b.toStringAsFixed(1)}  $teamB', textAlign: TextAlign.right, style: TextStyle(color: bWins ? _suiteYellow : _suiteText, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({required this.team, required this.rows});
  final String team;
  final List<NbaStatsRow> rows;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$team ROTATION', style: const TextStyle(color: _suiteYellow, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          for (final row in rows.take(10))
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Expanded(child: Text(row.player, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _suiteText, fontSize: 10))), Text('${(row.value('pts') ?? 0).toStringAsFixed(1)} PTS', style: const TextStyle(color: _suiteMuted, fontSize: 9))])),
        ]),
      );
}

class _ProfileSegment {
  const _ProfileSegment(this.label, this.share, this.efficiency);
  final String label;
  final double share;
  final double? efficiency;
}

class _ShotProfileBar extends StatelessWidget {
  const _ShotProfileBar({required this.segment});
  final _ProfileSegment segment;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
        child: Column(children: [
          Row(children: [Expanded(child: Text(segment.label, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900))), Text('${(segment.share * 100).toStringAsFixed(1)}% volume', style: const TextStyle(color: _suiteYellow)), const SizedBox(width: 12), Text(segment.efficiency == null ? '—' : '${(segment.efficiency! * 100).toStringAsFixed(1)}% accuracy', style: const TextStyle(color: _suiteCyan))]),
          const SizedBox(height: 8),
          Stack(children: [Container(height: 12, decoration: BoxDecoration(color: _suiteBg, borderRadius: BorderRadius.circular(8))), FractionallySizedBox(widthFactor: segment.share.clamp(0, 1), child: Container(height: 12, decoration: BoxDecoration(color: _suiteYellow, borderRadius: BorderRadius.circular(8))))]),
        ]),
      );
}

class _TierBand extends StatelessWidget {
  const _TierBand({required this.title, required this.players, required this.metricKey, required this.engine});
  final String title;
  final List<NbaStatsRow> players;
  final String metricKey;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _suiteYellow, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final row in players) Chip(backgroundColor: _suiteBg, side: const BorderSide(color: _suiteLine), label: Text('${row.player} · ${engine.formatValue(metricKey, row.value(metricKey))}', style: const TextStyle(color: _suiteText, fontSize: 9)))]),
        ]),
      );
}

class _Slider extends StatelessWidget {
  const _Slider(this.label, this.value, this.min, this.max, this.onChanged, {this.lowerBetter = false});
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool lowerBetter;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 180, child: Text(label, style: const TextStyle(color: _suiteMuted, fontSize: 10))),
        Expanded(child: Slider(value: value, min: min, max: max, activeColor: lowerBetter ? _suiteCyan : _suiteYellow, onChanged: onChanged)),
        SizedBox(width: 60, child: Text('${(value * 100).toStringAsFixed(1)}%', textAlign: TextAlign.right, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900))),
      ]);
}

class _SourceNotice extends StatelessWidget {
  const _SourceNotice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF263447), borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteCyan.withValues(alpha: .35))),
        child: Text(text, style: const TextStyle(color: _suiteCyan, fontSize: 9, height: 1.4)),
      );
}

class _SparklinePanel extends StatelessWidget {
  const _SparklinePanel({required this.series});
  final Map<String, List<double>> series;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
        child: CustomPaint(painter: _MultiSparkPainter(series), child: const SizedBox.expand()),
      );
}

class _MultiSparkPainter extends CustomPainter {
  const _MultiSparkPainter(this.series);
  final Map<String, List<double>> series;
  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()..color = _suiteLine..strokeWidth = 1;
    canvas.drawLine(Offset(25, size.height - 20), Offset(size.width - 10, size.height - 20), axis);
    final colors = [_suiteYellow, _suiteCyan, _suiteGreen];
    var seriesIndex = 0;
    for (final values in series.values) {
      if (values.isEmpty) continue;
      final min = values.reduce(math.min);
      final max = values.reduce(math.max);
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = 25 + (values.length == 1 ? .5 : i / (values.length - 1)) * (size.width - 35);
        final y = size.height - 20 - (values[i] - min) / math.max(.0001, max - min) * (size.height - 35);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, Paint()..color = colors[seriesIndex % colors.length]..strokeWidth = 2..style = PaintingStyle.stroke);
      seriesIndex++;
    }
  }
  @override
  bool shouldRepaint(covariant _MultiSparkPainter oldDelegate) => oldDelegate.series != series;
}

class _CoverageItem {
  const _CoverageItem(this.label, this.count, this.available, this.description);
  final String label;
  final int count;
  final bool available;
  final String description;
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.item});
  final _CoverageItem item;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _suitePanel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _suiteLine)),
        child: Row(children: [
          Icon(item.available ? Icons.check_circle : Icons.warning_amber_rounded, color: item.available ? _suiteGreen : _suiteYellow, size: 18),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(color: _suiteText, fontWeight: FontWeight.w900)), Text(item.description, style: const TextStyle(color: _suiteMuted, fontSize: 9))])),
          Text('${item.count}', style: const TextStyle(color: _suiteText, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _EmptyTool extends StatelessWidget {
  const _EmptyTool(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _suiteMuted))));
}

class _PctPill extends StatelessWidget {
  const _PctPill(this.value);
  final double value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: (value >= 80 ? _suiteYellow : value >= 50 ? _suiteGreen : _suiteCyan).withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
        child: Text('${value.round()}', style: TextStyle(color: value >= 80 ? _suiteYellow : value >= 50 ? _suiteGreen : _suiteCyan, fontSize: 8, fontWeight: FontWeight.w900)),
      );
}

NbaStatsRow? _findRow(List<NbaStatsRow> rows, String? id) {
  for (final row in rows) {
    if (row.playerId == id) return row;
  }
  return rows.isEmpty ? null : rows.first;
}

Map<String, dynamic> _teamRecord(List<Map<String, dynamic>> records, String team) {
  for (final row in records) {
    if (_rawText(row, const ['team_id', 'team']) == team) return row;
  }
  return const {};
}

double _recordValue(Map<String, dynamic> row, List<String> keys) => _rawNumber(row, keys) ?? 0;

double _sum(List<NbaStatsRow> rows, String key) => rows.fold(0, (sum, row) => sum + (row.value(key) ?? 0));

double _topSum(List<NbaStatsRow> rows, String key, int count) {
  final copy = [...rows]..sort((a, b) => (b.value(key) ?? 0).compareTo(a.value(key) ?? 0));
  return _sum(copy.take(count).toList(), key);
}

double _average(List<double> values) => values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

String _rawText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

double? _rawNumber(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value.toDouble();
    if (value != null) {
      final parsed = double.tryParse(value.toString().replaceAll(',', '').replaceAll('%', ''));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String _displayNumber(double? value, {bool signed = false}) {
  if (value == null) return '—';
  final prefix = signed && value >= 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)}';
}
