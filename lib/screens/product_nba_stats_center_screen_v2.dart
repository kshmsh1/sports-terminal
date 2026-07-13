import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_stats_query_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);

class ProductNbaStatsCenterScreen extends StatefulWidget {
  const ProductNbaStatsCenterScreen({super.key});

  @override
  State<ProductNbaStatsCenterScreen> createState() =>
      _ProductNbaStatsCenterScreenState();
}

class _ProductNbaStatsCenterScreenState
    extends State<ProductNbaStatsCenterScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  final NbaStatsQueryEngine queryEngine = const NbaStatsQueryEngine();
  final TextEditingController queryController = TextEditingController();

  late final Future<NbaTerminalSeedSnapshot> seedFuture;
  String query = '';
  String basis = 'Per Game';
  String seasonType = 'Regular Season';
  String sortField = 'ppg';
  bool descending = true;
  bool showRebounds = false;
  int page = 0;
  int pageSize = 25;

  @override
  void initState() {
    super.initState();
    seedFuture = const NbaTerminalSeedRepository().load();
    _loadQuery();
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> _loadQuery() async {
    final saved = await localStore.loadString(ProductLocalStore.statsQueryKey);
    if (!mounted) return;
    setState(() {
      query = saved;
      queryController.text = saved;
    });
  }

  Future<void> _setQuery(String value) async {
    setState(() {
      query = value;
      page = 0;
    });
    await localStore.saveString(ProductLocalStore.statsQueryKey, value);
  }

  Future<void> _copyResults(List<Map<String, dynamic>> rows) async {
    const fields = [
      'player',
      'team',
      'age',
      'gp',
      'mpg',
      'ppg',
      'rpg',
      'apg',
      'spg',
      'bpg',
      'tov',
      'pf',
      'fg_pct',
      'three_pct',
      'ft_pct',
      'plus_minus',
    ];
    final lines = <String>[fields.join('\t')];
    for (final row in rows) {
      lines.add(fields.map((field) => '${row[field] ?? ''}').join('\t'));
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rows.length} result rows copied as TSV.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: seedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Surface(
            child: Text('Loading NBA stats center...',
                style: TextStyle(color: _muted)),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _Surface(
            child: Text('Stats unavailable: ${snapshot.error}',
                style: const TextStyle(color: _muted)),
          );
        }

        final data = snapshot.data!;
        final plan = queryEngine.parse(
          query,
          defaultSeasonType: seasonType,
          defaultBasis: basis,
        );
        final effectiveSeason = plan.seasonType;
        final normalized = [
          for (final row in data.playerSeasonTotals) _normalize(row, basis),
        ];
        var results = _filter(normalized, plan, query);
        final effectiveSort = plan.sortField ?? sortField;
        final effectiveDescending =
            plan.sortField == null ? descending : plan.sortDescending;
        results.sort((a, b) {
          final comparison =
              _number(a[effectiveSort]).compareTo(_number(b[effectiveSort]));
          return effectiveDescending ? -comparison : comparison;
        });
        if (plan.limit != null && results.length > plan.limit!) {
          results = results.take(plan.limit!).toList();
        }

        final seasonAvailable = effectiveSeason != 'Playoffs';
        final visibleResults = seasonAvailable ? results : <Map<String, dynamic>>[];
        final pageCount = visibleResults.isEmpty
            ? 1
            : (visibleResults.length / pageSize).ceil();
        if (page >= pageCount) page = pageCount - 1;
        final start = page * pageSize;
        final end = (start + pageSize).clamp(0, visibleResults.length);
        final currentRows = start < visibleResults.length
            ? visibleResults.sublist(start, end)
            : <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              total: data.playerSeasonTotals.length,
              matches: visibleResults.length,
              queryActive: query.trim().isNotEmpty,
            ),
            const SizedBox(height: 18),
            _Controls(
              controller: queryController,
              basis: basis,
              seasonType: seasonType,
              sortField: sortField,
              descending: descending,
              pageSize: pageSize,
              showRebounds: showRebounds,
              onQuery: _setQuery,
              onBasis: (value) {
                if (value == null) return;
                setState(() {
                  basis = value;
                  page = 0;
                });
              },
              onSeason: (value) {
                if (value == null) return;
                setState(() {
                  seasonType = value;
                  page = 0;
                });
              },
              onSort: (value) {
                if (value == null) return;
                setState(() {
                  sortField = value;
                  page = 0;
                });
              },
              onDirection: () => setState(() => descending = !descending),
              onPageSize: (value) {
                if (value == null) return;
                setState(() {
                  pageSize = value;
                  page = 0;
                });
              },
              onRebounds: (value) => setState(() => showRebounds = value),
              onPreset: (value) {
                queryController.text = value;
                _setQuery(value);
              },
            ),
            const SizedBox(height: 18),
            _QueryPlanPanel(
              plan: plan,
              effectiveSeason: effectiveSeason,
              basis: basis,
              resultCount: visibleResults.length,
              seasonAvailable: seasonAvailable,
            ),
            const SizedBox(height: 18),
            _ResultToolbar(
              start: visibleResults.isEmpty ? 0 : start + 1,
              end: end,
              total: visibleResults.length,
              page: page,
              pageCount: pageCount,
              onPrevious: page > 0 ? () => setState(() => page--) : null,
              onNext:
                  page + 1 < pageCount ? () => setState(() => page++) : null,
              onCopy: visibleResults.isEmpty
                  ? null
                  : () => _copyResults(visibleResults),
            ),
            const SizedBox(height: 12),
            _StatsTable(
              rows: currentRows,
              showRebounds: showRebounds,
              basis: basis,
            ),
            const SizedBox(height: 18),
            const _Methodology(),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.total,
    required this.matches,
    required this.queryActive,
  });
  final int total;
  final int matches;
  final bool queryActive;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
          boxShadow: const [
            BoxShadow(
                color: Color(0x24071A33),
                blurRadius: 32,
                offset: Offset(0, 16)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NBA STATS CENTER',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.4)),
          const SizedBox(height: 12),
          const Text('Query, sort and export official-style player tables.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 39,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8)),
          const SizedBox(height: 12),
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 900),
            child: Text(
              'Natural-language requests are translated into visible filter plans before they run. Results support pagination, basis conversion, column expansion and TSV export without hiding the current data limitations.',
              style: TextStyle(
                  color: Color(0xFFEAF2FF),
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _GlassChip('$total PLAYER SUMMARIES'),
            _GlassChip('$matches MATCHES'),
            _GlassChip(queryActive ? 'QUERY ACTIVE' : 'LEAGUE DEFAULT'),
            const _GlassChip('PAGINATED + EXPORTABLE'),
          ]),
        ]),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.basis,
    required this.seasonType,
    required this.sortField,
    required this.descending,
    required this.pageSize,
    required this.showRebounds,
    required this.onQuery,
    required this.onBasis,
    required this.onSeason,
    required this.onSort,
    required this.onDirection,
    required this.onPageSize,
    required this.onRebounds,
    required this.onPreset,
  });
  final TextEditingController controller;
  final String basis;
  final String seasonType;
  final String sortField;
  final bool descending;
  final int pageSize;
  final bool showRebounds;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onBasis;
  final ValueChanged<String?> onSeason;
  final ValueChanged<String?> onSort;
  final VoidCallback onDirection;
  final ValueChanged<int?> onPageSize;
  final ValueChanged<bool> onRebounds;
  final ValueChanged<String> onPreset;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Header('Command query',
              'Use player or team names, statistical comparisons, result limits, sorting, season type and basis language.'),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear query',
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              hintText:
                  'List players over age 29 with PPG > 15, RPG < 4 and FG% > 50',
              filled: true,
              fillColor: _soft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final preset in const {
              'Veteran scorers': 'age over 29 and ppg > 15 sort by points',
              'Efficient scorers': 'ppg > 18 and fg% > 50 sort by points',
              'Playmakers': 'apg > 6 sort by assists',
              'Rim protectors': 'bpg > 1.5 sort by blocks',
            }.entries)
              ActionChip(
                avatar: const Icon(Icons.bolt_rounded, size: 16),
                label: Text(preset.key,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => onPreset(preset.value),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Drop<String>(
              label: 'Season type',
              value: seasonType,
              values: const ['Regular Season', 'Playoffs', 'Combined'],
              labelFor: (value) => value,
              onChanged: onSeason,
            ),
            _Drop<String>(
              label: 'Basis',
              value: basis,
              values: const [
                'Per Game',
                'Per 36 Minutes',
                'Per 100 Possessions',
                'Totals'
              ],
              labelFor: (value) => value,
              onChanged: onBasis,
            ),
            _Drop<String>(
              label: 'Sort statistic',
              value: sortField,
              values: const [
                'ppg',
                'rpg',
                'apg',
                'spg',
                'bpg',
                'fg_pct',
                'three_pct',
                'plus_minus'
              ],
              labelFor: _statLabel,
              onChanged: onSort,
            ),
            _Drop<int>(
              label: 'Rows per page',
              value: pageSize,
              values: const [10, 25, 50, 100],
              labelFor: (value) => '$value',
              onChanged: onPageSize,
            ),
            OutlinedButton.icon(
              onPressed: onDirection,
              icon: Icon(descending
                  ? Icons.south_rounded
                  : Icons.north_rounded),
              label: Text(descending ? 'Highest first' : 'Lowest first'),
            ),
            FilterChip(
              selected: showRebounds,
              onSelected: onRebounds,
              label: const Text('Show OREB / DREB [+]',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      );
}

class _Drop<T> extends StatelessWidget {
  const _Drop({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: _soft,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _line),
            ),
          ),
          items: [
            for (final option in values)
              DropdownMenuItem<T>(
                value: option,
                child: Text(labelFor(option),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
          onChanged: onChanged,
        ),
      );
}

class _QueryPlanPanel extends StatelessWidget {
  const _QueryPlanPanel({
    required this.plan,
    required this.effectiveSeason,
    required this.basis,
    required this.resultCount,
    required this.seasonAvailable,
  });
  final NbaStatsQueryPlan plan;
  final String effectiveSeason;
  final String basis;
  final int resultCount;
  final bool seasonAvailable;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Header('Interpreted query plan',
              'Every recognized condition is exposed before the table runs.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Info(Icons.calendar_month_rounded, effectiveSeason),
            _Info(Icons.calculate_rounded, basis),
            _Info(Icons.table_rows_rounded, '$resultCount matching rows'),
            if (plan.sortField != null)
              _Info(Icons.sort_rounded,
                  '${plan.sortDescending ? 'Highest' : 'Lowest'} ${_statLabel(plan.sortField!)}'),
            if (plan.limit != null)
              _Info(Icons.filter_list_rounded, 'Limit ${plan.limit}'),
            for (final constraint in plan.constraints)
              _Info(Icons.rule_rounded, _constraintLabel(constraint)),
          ]),
          if (!seasonAvailable) ...[
            const SizedBox(height: 12),
            const _Notice(
              icon: Icons.info_outline_rounded,
              text:
                  'The generated seed currently contains regular-season summaries only. Playoff queries return no rows rather than reusing regular-season data.',
            ),
          ],
          if (plan.unparsedFragments.isNotEmpty &&
              plan.originalQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Notice(
              icon: Icons.visibility_rounded,
              text:
                  'Unparsed language retained for transparency: ${plan.unparsedFragments.join(' | ')}',
            ),
          ],
        ]),
      );
}

class _ResultToolbar extends StatelessWidget {
  const _ResultToolbar({
    required this.start,
    required this.end,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onCopy,
  });
  final int start;
  final int end;
  final int total;
  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              total == 0
                  ? 'No matching rows'
                  : 'Showing $start–$end of $total',
              style: const TextStyle(
                  color: _ink, fontWeight: FontWeight.w900),
            ),
            _Info(Icons.menu_book_rounded, 'Page ${page + 1} of $pageCount'),
            OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous'),
            ),
            OutlinedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
            ),
            FilledButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('Copy all results as TSV'),
            ),
          ],
        ),
      );
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({
    required this.rows,
    required this.showRebounds,
    required this.basis,
  });
  final List<Map<String, dynamic>> rows;
  final bool showRebounds;
  final String basis;

  @override
  Widget build(BuildContext context) {
    final columns = <String>[
      'Player',
      'Team',
      'Age',
      'GP',
      'MPG',
      'PPG',
      'RPG'
    ];
    if (showRebounds) columns.addAll(['OREB', 'DREB']);
    columns.addAll([
      'APG',
      'SPG',
      'BPG',
      'TOV',
      'PF',
      'FGM',
      'FG%',
      '3PM',
      '3P%',
      'FTM',
      'FT%',
      '+/-'
    ]);
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Header('Player statistics',
            '${rows.length} rows on this page • $basis • horizontally scroll for the full official-style column set.'),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No rows match the active query and season filters.',
                  style: TextStyle(
                      color: _muted, fontWeight: FontWeight.w700)),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(_soft),
              columns: [
                for (final column in columns)
                  DataColumn(
                    label: Text(column,
                        style: const TextStyle(
                            color: _muted, fontWeight: FontWeight.w900)),
                  ),
              ],
              rows: [
                for (final row in rows)
                  DataRow(cells: _cells(row, showRebounds)),
              ],
            ),
          ),
      ]),
    );
  }

  List<DataCell> _cells(Map<String, dynamic> row, bool breakdown) {
    final values = <String>[
      '${row['player']}',
      '${row['team']}',
      _format(row['age'], 0),
      _format(row['gp'], 0),
      _format(row['mpg'], 1),
      _format(row['ppg'], 1),
      _format(row['rpg'], 1),
    ];
    if (breakdown) {
      values.addAll([_format(row['oreb'], 1), _format(row['dreb'], 1)]);
    }
    values.addAll([
      _format(row['apg'], 1),
      _format(row['spg'], 1),
      _format(row['bpg'], 1),
      _format(row['tov'], 1),
      _format(row['pf'], 1),
      _format(row['fgm'], 1),
      _percent(row['fg_pct']),
      _format(row['three_pm'], 1),
      _percent(row['three_pct']),
      _format(row['ftm'], 1),
      _percent(row['ft_pct']),
      _format(row['plus_minus'], 1),
    ]);
    return [
      for (final value in values)
        DataCell(Text(value,
            style: const TextStyle(
                color: _ink, fontWeight: FontWeight.w700))),
    ];
  }
}

class _Methodology extends StatelessWidget {
  const _Methodology();

  @override
  Widget build(BuildContext context) => const _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header('Source and methodology',
              'How the current prototype transforms the generated warehouse.'),
          SizedBox(height: 12),
          _Notice(
            icon: Icons.dataset_rounded,
            text:
                'Source: generated 2024–25 NBA seed assets. Missing source fields display as em dashes or zero-value placeholders only where necessary for query execution.',
          ),
          SizedBox(height: 8),
          _Notice(
            icon: Icons.straighten_rounded,
            text:
                'Per-36 values scale counting statistics by minutes. Per-100 values are explicitly estimated using 2.05 possessions per player-minute until possession-level data is connected.',
          ),
          SizedBox(height: 8),
          _Notice(
            icon: Icons.download_rounded,
            text:
                'TSV export copies the full filtered result set, not only the current page, for direct paste into Workspace, Excel or Python Lab.',
          ),
        ]),
      );
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
            color: _soft,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _blue, size: 16),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: _ink, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _soft,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _blue, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: _muted,
                    height: 1.35,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: _muted, height: 1.35, fontWeight: FontWeight.w600)),
        ],
      );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.26)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8)),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F071A33),
                blurRadius: 22,
                offset: Offset(0, 10)),
          ],
        ),
        child: child,
      );
}

List<Map<String, dynamic>> _filter(
  List<Map<String, dynamic>> rows,
  NbaStatsQueryPlan plan,
  String query,
) {
  var result = plan.apply(rows);
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty || plan.constraints.isNotEmpty) return result;
  return result.where((row) {
    final text = '${row['player']} ${row['team']}'.toLowerCase();
    return text.contains(trimmed) ||
        trimmed.split(RegExp(r'\s+')).any(
              (token) => token.length > 2 && text.contains(token),
            );
  }).toList();
}

Map<String, dynamic> _normalize(Map<String, dynamic> row, String basis) {
  final games = _number(row['games']);
  final minutes = _perGame(row, 'minutes', 'minutes_per_game');
  final perGame = <String, double>{
    'mpg': minutes,
    'ppg': _perGame(row, 'points', 'points_per_game'),
    'rpg': _perGame(row, 'rebounds', 'rebounds_per_game'),
    'oreb': _perGame(
        row, 'offensive_rebounds', 'offensive_rebounds_per_game'),
    'dreb': _perGame(
        row, 'defensive_rebounds', 'defensive_rebounds_per_game'),
    'apg': _perGame(row, 'assists', 'assists_per_game'),
    'spg': _perGame(row, 'steals', 'steals_per_game'),
    'bpg': _perGame(row, 'blocks', 'blocks_per_game'),
    'tov': _perGame(row, 'turnovers', 'turnovers_per_game'),
    'pf': _perGame(row, 'personal_fouls', 'personal_fouls_per_game'),
    'fgm': _perGame(row, 'field_goals', 'field_goals_per_game'),
    'three_pm':
        _perGame(row, 'three_pointers', 'three_pointers_per_game'),
    'ftm': _perGame(row, 'free_throws', 'free_throws_per_game'),
    'plus_minus': _perGame(row, 'plus_minus', 'plus_minus_per_game'),
  };

  double factor = 1;
  if (basis == 'Per 36 Minutes' && minutes > 0) factor = 36 / minutes;
  if (basis == 'Per 100 Possessions' && minutes > 0) {
    factor = 100 / (minutes * 2.05);
  }
  if (basis == 'Totals') factor = games > 0 ? games : 1;

  final normalized = <String, dynamic>{
    ...row,
    'player': _text(row['player_label']),
    'team': _text(row['team_ids']),
    'age': _nullableNumber(row['age']),
    'gp': games,
    'fg_pct': _percentage(row, const ['fg_pct', 'field_goal_pct', 'avg_fg_pct']),
    'three_pct': _percentage(
        row, const ['three_point_pct', 'fg3_pct', 'avg_fg3_pct']),
    'ft_pct': _percentage(
        row, const ['free_throw_pct', 'ft_pct', 'avg_ft_pct']),
  };
  for (final entry in perGame.entries) {
    normalized[entry.key] =
        entry.key == 'mpg' && basis != 'Totals' ? entry.value : entry.value * factor;
  }
  return normalized;
}

double _perGame(Map<String, dynamic> row, String totalKey, String perKey) {
  final direct = _nullableNumber(row[perKey]);
  if (direct != null) return direct;
  final games = _nullableNumber(row['games']);
  final total = _nullableNumber(row[totalKey]);
  if (games == null || games <= 0 || total == null) return 0;
  return total / games;
}

double _percentage(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _nullableNumber(row[key]);
    if (value != null) return value > 1 ? value / 100 : value;
  }
  return 0;
}

double _number(Object? value) => _nullableNumber(value) ?? 0;

double? _nullableNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(
      value.toString().replaceAll(',', '').replaceAll('%', ''));
}

String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _format(Object? value, int decimals) {
  final number = _nullableNumber(value);
  if (number == null) return '—';
  return decimals == 0
      ? number.round().toString()
      : number.toStringAsFixed(decimals);
}

String _percent(Object? value) {
  final number = _nullableNumber(value);
  if (number == null || number == 0) return '—';
  return '${(number * 100).toStringAsFixed(1)}%';
}

String _statLabel(String field) {
  const labels = {
    'ppg': 'PPG',
    'rpg': 'RPG',
    'apg': 'APG',
    'spg': 'SPG',
    'bpg': 'BPG',
    'fg_pct': 'FG%',
    'three_pct': '3P%',
    'ft_pct': 'FT%',
    'plus_minus': '+/-',
    'age': 'Age',
    'gp': 'GP',
    'mpg': 'MPG',
    'tov': 'TOV',
    'pf': 'PF',
  };
  return labels[field] ?? field.toUpperCase();
}

String _constraintLabel(NbaStatConstraint constraint) {
  final operator = switch (constraint.operator) {
    NbaStatOperator.greaterThan => '>',
    NbaStatOperator.greaterThanOrEqual => '≥',
    NbaStatOperator.lessThan => '<',
    NbaStatOperator.lessThanOrEqual => '≤',
    NbaStatOperator.equal => '=',
    NbaStatOperator.between => 'between',
  };
  final percentage = constraint.field.endsWith('_pct');
  final value = percentage
      ? '${(constraint.value * 100).toStringAsFixed(1)}%'
      : constraint.value.toStringAsFixed(
          constraint.value == constraint.value.roundToDouble() ? 0 : 1);
  return '${_statLabel(constraint.field)} $operator $value';
}
