import 'package:flutter/material.dart';

import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';

const _epBg = Color(0xFF090D12);
const _epPanel = Color(0xFF0F151C);
const _epPanel2 = Color(0xFF141C25);
const _epLine = Color(0xFF263342);
const _epText = Color(0xFFE8EDF3);
const _epMuted = Color(0xFF8895A5);
const _epBlue = Color(0xFF63A9FF);
const _epGreen = Color(0xFF69C99A);
const _epAmber = Color(0xFFE2B866);
const _epRed = Color(0xFFE57D7D);

Future<void> openNbaPlayerPage(
  BuildContext context, {
  required String playerId,
  String playerName = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProductNbaPlayerPage(
        playerId: playerId,
        playerName: playerName,
      ),
    ),
  );
}

Future<void> openNbaTeamPage(
  BuildContext context, {
  required String teamId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProductNbaTeamPage(teamId: teamId),
    ),
  );
}

class ProductNbaPlayerPage extends StatefulWidget {
  const ProductNbaPlayerPage({
    super.key,
    required this.playerId,
    this.playerName = '',
  });

  final String playerId;
  final String playerName;

  @override
  State<ProductNbaPlayerPage> createState() => _ProductNbaPlayerPageState();
}

class _ProductNbaPlayerPageState extends State<ProductNbaPlayerPage> {
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final NbaTerminalMetricResolver _resolver = const NbaTerminalMetricResolver();
  final ProductLocalStore _store = const ProductLocalStore();
  String _familyId = 'basic';
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  bool _watched = false;

  @override
  void initState() {
    super.initState();
    _loadWatched();
  }

  Future<void> _loadWatched() async {
    final values = await _store.loadStringSet(ProductLocalStore.playerWatchlistKey);
    if (!mounted) return;
    setState(() => _watched = values.contains(widget.playerId));
  }

  Future<void> _toggleWatched() async {
    final values = await _store.loadStringSet(ProductLocalStore.playerWatchlistKey);
    if (!values.add(widget.playerId)) values.remove(widget.playerId);
    await _store.saveStringSet(ProductLocalStore.playerWatchlistKey, values);
    if (!mounted) return;
    setState(() => _watched = values.contains(widget.playerId));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _epBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _epBlue,
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _epPanel,
          foregroundColor: _epText,
          title: Text(widget.playerName.isEmpty ? 'NBA Player' : widget.playerName),
          actions: [
            IconButton(
              tooltip: _watched ? 'Remove from watchlist' : 'Add to watchlist',
              onPressed: _toggleWatched,
              icon: Icon(_watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            ),
          ],
        ),
        body: FutureBuilder<NbaTerminalSeedSnapshot>(
          future: const NbaTerminalSeedRepository().load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _PageError('Player page unavailable: ${snapshot.error}');
            }
            final data = snapshot.data!;
            final rows = _engine.buildRows(
              data,
              basis: _basis,
              seasonType: _seasonType,
            );
            final matches = rows.where((row) => row.playerId == widget.playerId).toList();
            final fallback = rows.where((row) => row.player == widget.playerName).toList();
            final playerRows = matches.isNotEmpty ? matches : fallback;
            if (playerRows.isEmpty) {
              return _PageError('No player-season row is available for ${widget.playerName.isEmpty ? widget.playerId : widget.playerName}.');
            }
            final row = playerRows.first;
            final profile = data.players.firstWhere(
              (item) => _id(item, const ['player_id', 'id']) == widget.playerId,
              orElse: () => const <String, dynamic>{},
            );
            final logs = data.playerGameLogsTop
                .where((item) => _id(item, const ['player_id', 'id']) == widget.playerId)
                .toList()
              ..sort((a, b) => _text(b['game_date']).compareTo(_text(a['game_date'])));
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlayerHero(
                        row: row,
                        profile: profile,
                        watched: _watched,
                        onWatch: _toggleWatched,
                        onTeam: (team) => openNbaTeamPage(context, teamId: team),
                      ),
                      const SizedBox(height: 14),
                      _PlayerControls(
                        familyId: _familyId,
                        basis: _basis,
                        seasonType: _seasonType,
                        onFamily: (value) => setState(() => _familyId = value),
                        onBasis: (value) => setState(() => _basis = value),
                        onSeason: (value) => setState(() => _seasonType = value),
                      ),
                      const SizedBox(height: 14),
                      _PlayerMetricSection(
                        row: row,
                        family: nbaTerminalFamily(_familyId),
                        resolver: _resolver,
                      ),
                      const SizedBox(height: 14),
                      _PlayerRawSnapshot(row: row, engine: _engine),
                      const SizedBox(height: 14),
                      _RecentGames(logs: logs.take(20).toList()),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProductNbaTeamPage extends StatefulWidget {
  const ProductNbaTeamPage({super.key, required this.teamId});
  final String teamId;

  @override
  State<ProductNbaTeamPage> createState() => _ProductNbaTeamPageState();
}

class _ProductNbaTeamPageState extends State<ProductNbaTeamPage> {
  final ProductLocalStore _store = const ProductLocalStore();
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  bool _favorite = false;
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final values = await _store.loadStringSet(ProductLocalStore.favoriteTeamsKey);
    if (!mounted) return;
    setState(() => _favorite = values.contains(widget.teamId));
  }

  Future<void> _toggleFavorite() async {
    final values = await _store.loadStringSet(ProductLocalStore.favoriteTeamsKey);
    if (!values.add(widget.teamId)) values.remove(widget.teamId);
    await _store.saveStringSet(ProductLocalStore.favoriteTeamsKey, values);
    if (!mounted) return;
    setState(() => _favorite = values.contains(widget.teamId));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _epBg,
        colorScheme: ColorScheme.fromSeed(seedColor: _epBlue, brightness: Brightness.dark),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _epPanel,
          foregroundColor: _epText,
          title: Text('${widget.teamId} Team Page'),
          actions: [
            IconButton(
              tooltip: _favorite ? 'Remove favorite' : 'Favorite team',
              onPressed: _toggleFavorite,
              icon: Icon(_favorite ? Icons.star_rounded : Icons.star_border_rounded),
            ),
          ],
        ),
        body: FutureBuilder<NbaTerminalSeedSnapshot>(
          future: const NbaTerminalSeedRepository().load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _PageError('Team page unavailable: ${snapshot.error}');
            }
            final data = snapshot.data!;
            final team = data.teamRecords.firstWhere(
              (item) => _id(item, const ['team_id', 'id', 'abbreviation']) == widget.teamId,
              orElse: () => data.teams.firstWhere(
                (item) => _id(item, const ['team_id', 'id', 'abbreviation']) == widget.teamId,
                orElse: () => const <String, dynamic>{},
              ),
            );
            final rows = _engine.buildRows(
              data,
              basis: NbaStatsBasis.perGame,
              seasonType: _seasonType,
            ).where((row) => _rowHasTeam(row.team, widget.teamId)).toList()
              ..sort((a, b) => (b.value('min') ?? 0).compareTo(a.value('min') ?? 0));
            final games = data.teamGameLogs
                .where((item) => _id(item, const ['team_id', 'team']) == widget.teamId)
                .toList()
              ..sort((a, b) => _text(b['game_date']).compareTo(_text(a['game_date'])));
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TeamHero(
                        teamId: widget.teamId,
                        row: team,
                        favorite: _favorite,
                        onFavorite: _toggleFavorite,
                      ),
                      const SizedBox(height: 14),
                      _SegmentPicker(
                        seasonType: _seasonType,
                        onChanged: (value) => setState(() => _seasonType = value),
                      ),
                      const SizedBox(height: 14),
                      _TeamRoster(rows: rows),
                      const SizedBox(height: 14),
                      _TeamGames(rows: games.take(25).toList()),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayerHero extends StatelessWidget {
  const _PlayerHero({
    required this.row,
    required this.profile,
    required this.watched,
    required this.onWatch,
    required this.onTeam,
  });
  final NbaStatsRow row;
  final Map<String, dynamic> profile;
  final bool watched;
  final VoidCallback onWatch;
  final ValueChanged<String> onTeam;

  @override
  Widget build(BuildContext context) {
    final teams = row.team.split(RegExp(r'[,/ ]+')).where((value) => value.isNotEmpty && value != '—').toList();
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final avatar = Container(
            width: compact ? 72 : 92,
            height: compact ? 72 : 92,
            decoration: BoxDecoration(
              color: _epPanel2,
              border: Border.all(color: _epLine),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(row.player),
              style: TextStyle(color: _epBlue, fontSize: compact ? 24 : 32, fontWeight: FontWeight.w900),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NBA PLAYER', style: TextStyle(color: _epMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(row.player, style: const TextStyle(color: _epText, fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final team in teams)
                    TextButton.icon(
                      onPressed: () => onTeam(team),
                      icon: const Icon(Icons.groups_rounded, size: 15),
                      label: Text(team),
                    ),
                  _Pill(row.position, _epBlue),
                  if (profile['age'] != null) _Pill('Age ${profile['age']}', _epMuted),
                ],
              ),
            ],
          );
          final watch = FilledButton.icon(
            onPressed: onWatch,
            icon: Icon(watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            label: Text(watched ? 'Watching' : 'Watch player'),
          );
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [avatar, const SizedBox(width: 12), Expanded(child: details)]),
              const SizedBox(height: 12),
              watch,
            ]);
          }
          return Row(children: [avatar, const SizedBox(width: 18), Expanded(child: details), const SizedBox(width: 12), watch]);
        },
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.familyId,
    required this.basis,
    required this.seasonType,
    required this.onFamily,
    required this.onBasis,
    required this.onSeason,
  });
  final String familyId;
  final NbaStatsBasis basis;
  final NbaStatsSeasonType seasonType;
  final ValueChanged<String> onFamily;
  final ValueChanged<NbaStatsBasis> onBasis;
  final ValueChanged<NbaStatsSeasonType> onSeason;

  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Drop<String>(
              label: 'STAT CATEGORY',
              value: familyId,
              width: 240,
              items: [for (final family in nbaTerminalStatFamilies) DropdownMenuItem(value: family.id, child: Text(family.label))],
              onChanged: onFamily,
            ),
            _Drop<NbaStatsBasis>(
              label: 'RATE BASIS',
              value: basis,
              width: 155,
              items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))],
              onChanged: onBasis,
            ),
            _Drop<NbaStatsSeasonType>(
              label: 'SEGMENT',
              value: seasonType,
              width: 160,
              items: const [
                DropdownMenuItem(value: NbaStatsSeasonType.regular, child: Text('Regular Season')),
                DropdownMenuItem(value: NbaStatsSeasonType.playoffs, child: Text('Playoffs')),
              ],
              onChanged: onSeason,
            ),
          ],
        ),
      );
}

class _PlayerMetricSection extends StatelessWidget {
  const _PlayerMetricSection({required this.row, required this.family, required this.resolver});
  final NbaStatsRow row;
  final NbaTerminalStatFamily family;
  final NbaTerminalMetricResolver resolver;

  @override
  Widget build(BuildContext context) {
    final keys = nbaVisibleMetricKeys(family, family.metrics.toSet());
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(family.label.toUpperCase(), style: const TextStyle(color: _epBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 5),
          Text(family.description, style: const TextStyle(color: _epMuted, height: 1.4)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1200 ? 5 : constraints.maxWidth >= 850 ? 4 : constraints.maxWidth >= 560 ? 3 : 2;
              final gap = 8.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final key in keys)
                    SizedBox(
                      width: width,
                      child: _MetricCard(
                        metric: nbaTerminalMetricByKey[key] ?? NbaTerminalMetric(
                          key: key,
                          label: key,
                          shortLabel: key.toUpperCase(),
                          group: 'Other',
                          description: 'Source-provided metric.',
                        ),
                        value: resolver.format(row, key),
                        available: resolver.isAvailable(row, key),
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

class _PlayerRawSnapshot extends StatelessWidget {
  const _PlayerRawSnapshot({required this.row, required this.engine});
  final NbaStatsRow row;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) {
    const keys = ['gp', 'min', 'pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'fg_pct', 'three_pct', 'ft_pct', 'ts_pct'];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CORE LINE', style: TextStyle(color: _epAmber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in keys)
                _CompactMetric(label: engine.metric(key).shortLabel, value: engine.formatValue(key, row.value(key))),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentGames extends StatelessWidget {
  const _RecentGames({required this.logs});
  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RECENT GAME LOG', style: TextStyle(color: _epBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              const Text('No player game log rows are packaged for this player in the active data scope.', style: TextStyle(color: _epMuted))
            else
              for (final log in logs)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _epLine))),
                  child: Row(
                    children: [
                      SizedBox(width: 92, child: Text(_text(log['game_date']), style: const TextStyle(color: _epMuted, fontSize: 11))),
                      Expanded(child: Text(_text(log['opponent_team_id'] ?? log['opponent']), style: const TextStyle(color: _epText, fontWeight: FontWeight.w700))),
                      for (final key in const ['pts', 'reb', 'ast'])
                        SizedBox(width: 65, child: Text('${key.toUpperCase()} ${_text(log[key])}', textAlign: TextAlign.right, style: const TextStyle(color: _epText, fontSize: 10))),
                    ],
                  ),
                ),
          ],
        ),
      );
}

class _TeamHero extends StatelessWidget {
  const _TeamHero({required this.teamId, required this.row, required this.favorite, required this.onFavorite});
  final String teamId;
  final Map<String, dynamic> row;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final wins = _text(row['wins']);
    final losses = _text(row['losses']);
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(color: _epPanel2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _epLine)),
            alignment: Alignment.center,
            child: Text(teamId, style: const TextStyle(color: _epBlue, fontSize: 21, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NBA TEAM', style: TextStyle(color: _epMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(_text(row['team_name'] ?? row['name'] ?? teamId), style: const TextStyle(color: _epText, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(wins != '—' && losses != '—' ? '$wins–$losses · active data scope' : 'Active data scope', style: const TextStyle(color: _epMuted)),
            ]),
          ),
          FilledButton.icon(onPressed: onFavorite, icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded), label: Text(favorite ? 'Rooting for' : 'Root for team')),
        ],
      ),
    );
  }
}

class _SegmentPicker extends StatelessWidget {
  const _SegmentPicker({required this.seasonType, required this.onChanged});
  final NbaStatsSeasonType seasonType;
  final ValueChanged<NbaStatsSeasonType> onChanged;
  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.all(10),
        child: SegmentedButton<NbaStatsSeasonType>(
          segments: const [
            ButtonSegment(value: NbaStatsSeasonType.regular, label: Text('Regular Season')),
            ButtonSegment(value: NbaStatsSeasonType.playoffs, label: Text('Playoffs')),
          ],
          selected: {seasonType},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      );
}

class _TeamRoster extends StatelessWidget {
  const _TeamRoster({required this.rows});
  final List<NbaStatsRow> rows;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('ROSTER & PLAYER STATS', style: TextStyle(color: _epBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8))),
              Text('${rows.length} players', style: const TextStyle(color: _epMuted, fontSize: 10)),
            ]),
            const SizedBox(height: 10),
            for (final row in rows)
              InkWell(
                onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _epLine))),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text(row.player, style: const TextStyle(color: _epBlue, fontWeight: FontWeight.w800))),
                    SizedBox(width: 48, child: Text(row.position, style: const TextStyle(color: _epMuted))),
                    for (final entry in [('MIN', 'min'), ('PTS', 'pts'), ('REB', 'reb'), ('AST', 'ast')])
                      SizedBox(width: 72, child: Text('${entry.$1} ${(row.value(entry.$2) ?? 0).toStringAsFixed(1)}', textAlign: TextAlign.right, style: const TextStyle(color: _epText, fontSize: 10))),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: _epMuted, size: 18),
                  ]),
                ),
              ),
          ],
        ),
      );
}

class _TeamGames extends StatelessWidget {
  const _TeamGames({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RECENT SCHEDULE / RESULTS', style: TextStyle(color: _epAmber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text('No team game logs are available in the active data scope.', style: TextStyle(color: _epMuted))
          else
            for (final row in rows)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _epLine))),
                child: Row(children: [
                  SizedBox(width: 95, child: Text(_text(row['game_date']), style: const TextStyle(color: _epMuted, fontSize: 10))),
                  Expanded(child: Text(_text(row['opponent_team_id']), style: const TextStyle(color: _epText, fontWeight: FontWeight.w700))),
                  SizedBox(width: 55, child: Text(_text(row['result']), textAlign: TextAlign.right, style: const TextStyle(color: _epBlue, fontWeight: FontWeight.w900))),
                  SizedBox(width: 75, child: Text(_text(row['points']), textAlign: TextAlign.right, style: const TextStyle(color: _epText))),
                  SizedBox(width: 75, child: Text(_text(row['margin']), textAlign: TextAlign.right, style: const TextStyle(color: _epMuted))),
                ]),
              ),
        ]),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.value, required this.available});
  final NbaTerminalMetric metric;
  final String value;
  final bool available;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _epPanel2, border: Border.all(color: _epLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(metric.shortLabel, style: TextStyle(color: available ? _epBlue : _epMuted, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: available ? _epText : _epMuted, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(metric.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _epMuted, fontSize: 9)),
        ]),
      );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(color: _epPanel2, border: Border.all(color: _epLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _epMuted, fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _epText, fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Drop<T> extends StatelessWidget {
  const _Drop({required this.label, required this.value, required this.width, required this.items, required this.onChanged});
  final String label;
  final T value;
  final double width;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _epMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            value: value,
            dropdownColor: _epPanel2,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: items,
            onChanged: (next) { if (next != null) onChanged(next); },
          ),
        ]),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _epPanel, border: Border.all(color: _epLine), borderRadius: BorderRadius.circular(10)),
        child: child,
      );
}

class _PageError extends StatelessWidget {
  const _PageError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _epRed)),
        ),
      );
}

bool _rowHasTeam(String value, String team) => value.split(RegExp(r'[,/ ]+')).contains(team);
String _id(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}
String _initials(String value) => value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();
