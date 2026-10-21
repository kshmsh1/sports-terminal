import 'package:flutter/material.dart';

import '../services/website_nba_api_service.dart';

/// Source-bound historical game explorer. No live network requests are made.
class WebsiteNbaBoxScoresScreen extends StatefulWidget {
  const WebsiteNbaBoxScoresScreen({super.key});

  @override
  State<WebsiteNbaBoxScoresScreen> createState() => _WebsiteNbaBoxScoresScreenState();
}

class _WebsiteNbaBoxScoresScreenState extends State<WebsiteNbaBoxScoresScreen> {
  static const _pageSize = 20;
  final _api = const WebsiteNbaApiService();
  final _search = TextEditingController();
  late Future<_GameArchive> _archive;
  String _season = 'All';
  String _segment = 'All';
  bool _detailsOnly = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _archive = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_GameArchive> _load() async {
    final results = await Future.wait<dynamic>([
      _api.seasons(),
      _api.games(),
    ]);
    final seasons = results[0] as List<WebsiteNbaSeason>;
    final games = results[1] as List<Map<String, dynamic>>;
    games.sort((a, b) {
      final date = _day(b['game_date']).compareTo(_day(a['game_date']));
      return date != 0 ? date : _text(b['game_key']).compareTo(_text(a['game_key']));
    });
    return _GameArchive(seasons: seasons, games: games);
  }

  void _resetFilters() => setState(() {
    _search.clear();
    _season = 'All';
    _segment = 'All';
    _detailsOnly = false;
    _page = 1;
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<_GameArchive>(
    future: _archive,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(height: 460,
          child: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return _ArchiveError(
          onRetry: () => setState(() => _archive = _load()),
        );
      }
      return _content(context, snapshot.data!);
    },
  );

  Widget _content(BuildContext context, _GameArchive archive) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final filtered = archive.games.where((game) {
      if (_season != 'All' && _text(game['season_id']) != _season) return false;
      final type = _gameSegment(game);
      if (_segment != 'All' && _segment != type) return false;
      if (_detailsOnly && game['box_score_available'] != true) return false;
      if (query.isEmpty) return true;
      final haystack = [
        game['game_date'], game['game_key'], game['nba_game_id'],
        game['home_team_name'], game['away_team_name'],
        game['home_team_abbreviation'], game['away_team_abbreviation'],
      ].map((v) => _text(v).toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList(growable: false);
    final pageCount = filtered.isEmpty ? 1 :
        (filtered.length + _pageSize - 1) ~/ _pageSize;
    final currentPage = _page.clamp(1, pageCount);
    final start = (currentPage - 1) * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList(growable: false);
    final availableCount = archive.games
        .where((game) => game['box_score_available'] == true).length;
    final latest = archive.games.isEmpty ? 'Not indexed' :
        _day(archive.games.first['game_date']);
    final hasFilter = _season != 'All' || _segment != 'All' ||
        _detailsOnly || query.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('NBA / HISTORICAL GAMES',
        style: TextStyle(color: colors.primary,
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Box Scores', style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.1)),
          const Chip(
            avatar: Icon(Icons.inventory_2_outlined, size: 17),
            label: Text('Historical static archive'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Text(
          'Find a game, study the matchup and inspect verified player box scores. '
          'The archive is historical, not a live scoreboard; individual game '
          'details appear only where they have been materialized locally.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
        ),
      ),
      const SizedBox(height: 23),
      LayoutBuilder(builder: (context, bounds) {
        final wide = bounds.maxWidth >= 780;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          _ArchiveMetric(label: 'INDEXED GAMES',
            value: _compactCount(archive.games.length),
            icon: Icons.sports_basketball_rounded,
            width: wide ? (bounds.maxWidth - 24) / 3 : bounds.maxWidth),
          _ArchiveMetric(label: 'PLAYER BOXSCORES',
            value: _compactCount(availableCount),
            icon: Icons.table_rows_outlined,
            width: wide ? (bounds.maxWidth - 24) / 3 : bounds.maxWidth),
          _ArchiveMetric(label: 'LATEST INDEXED',
            value: latest,
            icon: Icons.event_rounded,
            width: wide ? (bounds.maxWidth - 24) / 3 : bounds.maxWidth),
        ]);
      }),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(builder: (context, bounds) {
            final wide = bounds.maxWidth >= 650;
            final fieldWidth = wide ? 290.0 : bounds.maxWidth;
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.tune_rounded, size: 19),
                  const SizedBox(width: 8),
                  Text('Explore games', style: Theme.of(context)
                    .textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (hasFilter)
                    TextButton.icon(onPressed: _resetFilters,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Clear filters')),
                ]),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(width: fieldWidth,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() => _page = 1),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          labelText: 'Search box scores',
                          hintText: 'Team, date, or game ID',
                        ),
                      )),
                    SizedBox(width: wide ? 160 : (bounds.maxWidth - 10) / 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('season-$_season'),
                        isExpanded: true,
                        initialValue: _season,
                        decoration: const InputDecoration(labelText: 'Season'),
                        items: [
                          const DropdownMenuItem(value: 'All',
                            child: Text('All seasons')),
                          for (final season in archive.seasons)
                            DropdownMenuItem(value: season.id,
                              child: Text(season.id)),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() { _season = value; _page = 1; });
                        },
                      )),
                    SizedBox(width: wide ? 180 : (bounds.maxWidth - 10) / 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('segment-$_segment'),
                        isExpanded: true,
                        initialValue: _segment,
                        decoration: const InputDecoration(labelText: 'Segment'),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All games')),
                          DropdownMenuItem(value: 'Regular Season',
                            child: Text('Regular Season')),
                          DropdownMenuItem(value: 'Playoffs',
                            child: Text('Playoffs')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() { _segment = value; _page = 1; });
                        },
                      )),
                    FilterChip(
                      label: const Text('Detailed box scores only'),
                      avatar: const Icon(Icons.fact_check_outlined, size: 18),
                      selected: _detailsOnly,
                      onSelected: (value) => setState(() {
                        _detailsOnly = value;
                        _page = 1;
                      }),
                    ),
                  ]),
              ],
            );
          }),
        ),
      ),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Text(
          hasFilter ? 'Filtered games' : 'Latest indexed games',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900))),
        Text('${filtered.length} results',
          style: TextStyle(color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 14),
      if (visible.isEmpty)
        Card(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
          child: Column(children: [
            Icon(Icons.search_off_rounded, size: 32, color: colors.onSurfaceVariant),
            const SizedBox(height: 10),
            const Text('No historical games match these filters.'),
            const SizedBox(height: 8),
            TextButton(onPressed: _resetFilters,
              child: const Text('Clear all filters')),
          ]),
        ))
      else
        for (var i = 0; i < visible.length; i++) ...[
          if (i == 0 || _day(visible[i]['game_date']) !=
                  _day(visible[i - 1]['game_date'])) ...[
            if (i > 0) const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 5, 3, 10),
              child: Text(_day(visible[i]['game_date']),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5, fontSize: 12)),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _GameCard(game: visible[i],
              onOpen: () => _openGame(context, visible[i])),
          ),
        ],
      if (visible.isNotEmpty) ...[
        const SizedBox(height: 15),
        LayoutBuilder(builder: (context, box) =>
          Wrap(alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            children: [
              IconButton(tooltip: 'First page',
                onPressed: currentPage > 1 ?
                  () => setState(() => _page = 1) : null,
                icon: const Icon(Icons.first_page_rounded)),
              IconButton(tooltip: 'Previous page',
                onPressed: currentPage > 1 ?
                  () => setState(() => _page = currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded)),
              Text('Page $currentPage of $pageCount  ·  '
                '${start + 1}–${start + visible.length} of ${filtered.length}',
                style: const TextStyle(fontSize: 12)),
              IconButton(tooltip: 'Next page',
                onPressed: currentPage < pageCount ?
                  () => setState(() => _page = currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded)),
              IconButton(tooltip: 'Last page',
                onPressed: currentPage < pageCount ?
                  () => setState(() => _page = pageCount) : null,
                icon: const Icon(Icons.last_page_rounded)),
            ],
          ),
        ),
      ],
    ]);
  }

  Future<void> _openGame(BuildContext context, Map<String, dynamic> game) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BoxScoreDetailLoader(game: game, api: _api),
    );
  }
}

class _ArchiveMetric extends StatelessWidget {
  const _ArchiveMetric({
    required this.label, required this.value, required this.icon,
    required this.width,
  });
  final String label;
  final String value;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(width: width,
      child: Card(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(children: [
          Icon(icon, size: 23, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10,
                letterSpacing: 1, fontWeight: FontWeight.w800,
                color: colors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()])),
            ])),
        ]),
      )),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onOpen});
  final Map<String, dynamic> game;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final awayScore = _num(game['away_score']);
    final homeScore = _num(game['home_score']);
    final available = game['box_score_available'] == true;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 690;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${_text(game['season_id'])} · ${_gameSegment(game)}',
                    style: TextStyle(color: colors.onSurfaceVariant,
                      fontSize: 11, fontWeight: FontWeight.w700)),
                  if (available) ...[
                    const SizedBox(width: 9),
                    Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: colors.primary),
                    const SizedBox(width: 3),
                    Text('Player stats', style: TextStyle(
                      color: colors.primary, fontSize: 11,
                      fontWeight: FontWeight.w700)),
                  ],
                ]),
                const SizedBox(height: 8),
                Text('${_team(game, away: true)}  @  ${_team(game, away: false)}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w900)),
              ],
            );
            final score = Row(mainAxisSize: MainAxisSize.min,
              children: [
                _ScoreText(value: awayScore,
                  winner: awayScore != null && homeScore != null &&
                    awayScore > homeScore),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('–', style: TextStyle(
                    color: colors.onSurfaceVariant, fontSize: 17)),
                ),
                _ScoreText(value: homeScore,
                  winner: awayScore != null && homeScore != null &&
                    homeScore > awayScore),
              ],
            );
            return wide
              ? Row(children: [
                  Expanded(child: details),
                  score,
                  const SizedBox(width: 16),
                  Tooltip(message: available ?
                    'Detailed player box score available' :
                    'Only historical game metadata is available',
                    child: Icon(available
                      ? Icons.table_rows_rounded : Icons.table_rows_outlined,
                      color: available ? colors.primary : colors.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: 15),
                    Row(children: [
                      score,
                      const Spacer(),
                      Text(available ? 'Open player stats' : 'Game details',
                        style: TextStyle(color: colors.primary,
                          fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                        color: colors.primary, size: 17),
                    ]),
                  ]);
          }),
        ),
      ),
    );
  }
}

class _ScoreText extends StatelessWidget {
  const _ScoreText({required this.value, required this.winner});
  final double? value;
  final bool winner;

  @override
  Widget build(BuildContext context) => Text(
    value == null ? '—' : value!.round().toString(),
    style: TextStyle(
      fontSize: 23, fontWeight: winner ? FontWeight.w900 : FontWeight.w700,
      color: winner ? Theme.of(context).colorScheme.onSurface :
        Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// Loading lives inside the dialog, so clicking a game always gives immediate
/// feedback and closing before the file resolves is safe.
class _BoxScoreDetailLoader extends StatefulWidget {
  const _BoxScoreDetailLoader({required this.game, required this.api});
  final Map<String, dynamic> game;
  final WebsiteNbaApiService api;

  @override
  State<_BoxScoreDetailLoader> createState() => _BoxScoreDetailLoaderState();
}

class _BoxScoreDetailLoaderState extends State<_BoxScoreDetailLoader> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.gameDetail(_text(widget.game['game_key']));
  }

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: (window.width - 32).clamp(0.0, 1160.0).toDouble(),
        height: (window.height - 32).clamp(200.0, 860.0).toDouble(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) => _GameDetail(
            game: widget.game,
            detail: snapshot.data,
            loading: snapshot.connectionState != ConnectionState.done,
            failed: snapshot.hasError,
          ),
        ),
      ),
    );
  }
}

class _GameDetail extends StatefulWidget {
  const _GameDetail({required this.game, required this.detail,
    required this.loading, required this.failed});
  final Map<String, dynamic> game;
  final Map<String, dynamic>? detail;
  final bool loading;
  final bool failed;

  @override
  State<_GameDetail> createState() => _GameDetailState();
}

class _GameDetailState extends State<_GameDetail> {
  int _teamIndex = 0;
  String _sortStat = 'minutes';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = _maps(widget.detail?['player_box_scores']);
    final data = _map(widget.detail?['game']);
    final displayGame = data.isEmpty ? widget.game : {...widget.game, ...data};
    final awayAbbr = _text(displayGame['away_team_abbreviation'],
      _text(widget.game['away_team_abbreviation']));
    final homeAbbr = _text(displayGame['home_team_abbreviation'],
      _text(widget.game['home_team_abbreviation']));
    final abbreviation = _teamIndex == 0 ? awayAbbr : homeAbbr;
    final isAway = _teamIndex == 0;
    final matching = rows.where((row) =>
      _text(row['team_abbreviation']).toUpperCase() ==
      abbreviation.toUpperCase()).toList(growable: false);
    matching.sort((a, b) {
      final aValue = _num(a[_sortStat]);
      final bValue = _num(b[_sortStat]);
      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return 1;
      if (bValue == null) return -1;
      return bValue.compareTo(aValue);
    });
    final played = matching.where(_hasMinutes).toList(growable: false);
    final dnp = matching.where((row) => !_hasMinutes(row)).toList(growable: false);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GAME CENTER / HISTORICAL',
                style: TextStyle(fontSize: 10, letterSpacing: 1.5,
                  color: colors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('${_team(displayGame, away: true)} at '
                '${_team(displayGame, away: false)}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text('${_day(displayGame['game_date'])} · '
                '${_text(displayGame['season_id'])} · ${_gameSegment(displayGame)}',
                style: TextStyle(color: colors.onSurfaceVariant,
                  fontSize: 12)),
            ])),
          IconButton(
            tooltip: 'Close box score',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _GameScoreBanner(game: displayGame),
      ),
      if (widget.loading) const LinearProgressIndicator(minHeight: 2),
      const SizedBox(height: 13),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          Expanded(child: Text('Player box score',
            style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w900))),
          Text('Source-backed · ${rows.length} indexed rows',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ]),
      ),
      const SizedBox(height: 11),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text('Away · $awayAbbr')),
            ButtonSegment(value: 1, label: Text('Home · $homeAbbr')),
          ],
          selected: {_teamIndex},
          onSelectionChanged: (values) =>
            setState(() => _teamIndex = values.first),
        ),
      ),
      const SizedBox(height: 12),
      if (!widget.loading && rows.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            Expanded(child: Text(
              isAway ? _team(displayGame, away: true) :
                _team(displayGame, away: false),
              style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('Sort by', style: TextStyle(color: colors.onSurfaceVariant,
              fontSize: 12)),
            const SizedBox(width: 7),
            DropdownButton<String>(
              value: _sortStat,
              items: const [
                DropdownMenuItem(value: 'minutes', child: Text('MIN')),
                DropdownMenuItem(value: 'pts', child: Text('PTS')),
                DropdownMenuItem(value: 'reb', child: Text('REB')),
                DropdownMenuItem(value: 'ast', child: Text('AST')),
                DropdownMenuItem(value: 'stl', child: Text('STL')),
                DropdownMenuItem(value: 'blk', child: Text('BLK')),
              ],
              onChanged: (value) => setState(() =>
                _sortStat = value ?? 'minutes'),
            ),
          ]),
        ),
      Expanded(
        child: widget.loading
          ? const Center(child: Text('Loading locally indexed player stats…'))
          : widget.failed || rows.isEmpty
            ? _UnavailableBoxScore(failed: widget.failed)
            : matching.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No indexed player rows for $abbreviation in '
                    'this materialized game file.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant)),
                ))
              : Column(children: [
                  Expanded(child: _PlayerBoxTable(rows: played)),
                  if (dnp.isNotEmpty)
                    ExpansionTile(
                      title: Text('Did not play / no minutes · ${dnp.length}',
                        style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700)),
                      children: [
                        for (final row in dnp)
                          ListTile(dense: true,
                            title: Text(_text(row['player_name'], 'Player')),
                            trailing: const Text('No minutes recorded')),
                      ],
                    ),
                ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 15),
        child: Text(
          'Historical file snapshot. — means a field is not reported. '
          'An unavailable player box score is not treated as zero.',
          style: TextStyle(color: colors.onSurfaceVariant,
            fontSize: 11, height: 1.4)),
      ),
    ]);
  }
}

class _GameScoreBanner extends StatelessWidget {
  const _GameScoreBanner({required this.game});
  final Map<String, dynamic> game;

  @override
  Widget build(BuildContext context) {
    final away = _num(game['away_score']);
    final home = _num(game['home_score']);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        color: colors.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(child: _SideScore(name: _team(game, away: true),
          score: away, winner: away != null && home != null && away > home,
          align: TextAlign.right)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('—', style: TextStyle(fontSize: 22)),
        ),
        Expanded(child: _SideScore(name: _team(game, away: false),
          score: home, winner: away != null && home != null && home > away,
          align: TextAlign.left)),
      ]),
    );
  }
}

class _SideScore extends StatelessWidget {
  const _SideScore({
    required this.name, required this.score,
    required this.winner, required this.align,
  });
  final String name;
  final double? score;
  final bool winner;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(name, textAlign: align, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.onSurfaceVariant,
            fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(score == null ? '—' : score!.round().toString(),
          style: TextStyle(fontSize: 31,
            fontWeight: winner ? FontWeight.w900 : FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}

class _PlayerBoxTable extends StatelessWidget {
  const _PlayerBoxTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(
      child: Text('No player minutes recorded for this team.'));
    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            dataRowMinHeight: 42,
            dataRowMaxHeight: 48,
            columns: const [
              DataColumn(label: Text('PLAYER')),
              DataColumn(label: Text('MIN'), numeric: true),
              DataColumn(label: Text('PTS'), numeric: true),
              DataColumn(label: Text('REB'), numeric: true),
              DataColumn(label: Text('AST'), numeric: true),
              DataColumn(label: Text('STL'), numeric: true),
              DataColumn(label: Text('BLK'), numeric: true),
              DataColumn(label: Text('TOV'), numeric: true),
              DataColumn(label: Text('FG')),
              DataColumn(label: Text('3PT')),
              DataColumn(label: Text('FT')),
            ],
            rows: [
              for (final row in rows)
                DataRow(cells: [
                  DataCell(SizedBox(width: 185,
                    child: Text(_text(row['player_name'], 'Player'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)))),
                  DataCell(Text(_stat(row, 'minutes'))),
                  DataCell(Text(_stat(row, 'pts'),
                    style: const TextStyle(fontWeight: FontWeight.w900))),
                  DataCell(Text(_stat(row, 'reb'))),
                  DataCell(Text(_stat(row, 'ast'))),
                  DataCell(Text(_stat(row, 'stl'))),
                  DataCell(Text(_stat(row, 'blk'))),
                  DataCell(Text(_stat(row, 'tov'))),
                  DataCell(Text(_madeAttempted(row, 'fgm', 'fga'))),
                  DataCell(Text(_madeAttempted(row, 'three_pm', 'three_pa'))),
                  DataCell(Text(_madeAttempted(row, 'ftm', 'fta'))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableBoxScore extends StatelessWidget {
  const _UnavailableBoxScore({required this.failed});
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.table_rows_outlined, size: 32,
          color: colors.onSurfaceVariant),
        const SizedBox(height: 11),
        Text(failed ? 'Player box score could not be loaded'
          : 'Player box score not materialized',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          failed ? 'Game metadata remains available. Please try again '
            'after verifying the local static game file.' :
            'This game is indexed, but no source-backed player box score '
            'has been imported yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant)),
      ]),
    ));
  }
}

class _ArchiveError extends StatelessWidget {
  const _ArchiveError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Historical game archive unavailable',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      const Text('The local static game index could not be read.'),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry')),
    ]),
  ));
}

class _GameArchive {
  const _GameArchive({required this.seasons, required this.games});
  final List<WebsiteNbaSeason> seasons;
  final List<Map<String, dynamic>> games;
}

String _team(Map<String, dynamic> game, {required bool away}) {
  final prefix = away ? 'away' : 'home';
  return _text(game['${prefix}_team_name'],
    _text(game['${prefix}_team_abbreviation'], 'Team'));
}

String _gameSegment(Map<String, dynamic> game) =>
  _text(game['season_type']).toLowerCase().contains('play')
      ? 'Playoffs' : 'Regular Season';

String _day(Object? value) {
  final text = _text(value, 'Unknown date');
  return text.length >= 10 ? text.substring(0, 10) : text;
}

String _stat(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return '—';
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toString();
}

String _madeAttempted(Map<String, dynamic> row, String made, String attempted) =>
    row[made] == null || row[attempted] == null
      ? '—' : '${_stat(row, made)}/${_stat(row, attempted)}';

bool _hasMinutes(Map<String, dynamic> row) {
  final minutes = _num(row['minutes']);
  return minutes != null && minutes > 0;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) _map(item)];
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _compactCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 10000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}
