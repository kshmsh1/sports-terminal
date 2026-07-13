import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_stats_query_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
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
  final ProductLocalStore store = const ProductLocalStore();
  final NbaStatsQueryEngine queryEngine = const NbaStatsQueryEngine();
  final TextEditingController queryController = TextEditingController();

  late final Future<NbaTerminalSeedSnapshot> seedFuture;
  String query = '';
  String basis = 'Per Game';
  String seasonType = 'Regular Season';
  String sortField = 'ppg';
  bool descending = true;
  bool showReboundBreakdown = false;
  int page = 0;
  int pageSize = 25;

  @override
  void initState() {
    super.initState();
    seedFuture = const NbaTerminalSeedRepository().load();
    _restoreQuery();
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> _restoreQuery() async {
    final saved = await store.loadString(ProductLocalStore.statsQueryKey);
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
    await store.saveString(ProductLocalStore.statsQueryKey, value);
  }

  Future<void> _copyRows(List<Map<String, dynamic>> rows) async {
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
      SnackBar(content: Text('${rows.length} rows copied as TSV.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: seedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Surface(
            child: Text(
              'Loading NBA stats center...',
              style: TextStyle(color: _muted),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _Surface(
            child: Text(
              'Stats unavailable: ${snapshot.error}',
              style: const TextStyle(color: _muted),
            ),
          );
        }

        final data = snapshot.data!;
        final plan = queryEngine.parse(
          query,
          defaultSeasonType: seasonType,
          defaultBasis: basis,
        );
        final normalizedRows = [
          for (final row in data.playerSeasonTotals)
            _normalizePlayerRow(row, basis),
        ];
        var filteredRows = _applyTextAndStatQuery(normalizedRows, plan, query);

        final activeSortField = plan.sortField ?? sortField;
        final activeDescending =
            plan.sortField == null ? descending : plan.sortDescending;
        filteredRows.sort((left, right) {
          final comparison = _number(left[activeSortField])
              .compareTo(_number(right[activeSortField]));
          return activeDescending ? -comparison : comparison;
        });
        if (plan.limit != null && filteredRows.length > plan.limit!) {
          filteredRows = filteredRows.take(plan.limit!).toList();
        }

        final playoffDataUnavailable = plan.seasonType == 'Playoffs';
        final visibleRows = playoffDataUnavailable
            ? <Map<String, dynamic>>[]
            : filteredRows;
        final calculatedPages = (visibleRows.length / pageSize).ceil();
        final totalPages = calculatedPages < 1 ? 1 : calculatedPages;
        final effectivePage = page < 0
            ? 0
            : page >= totalPages
                ? totalPages - 1
                : page;
        final start = effectivePage * pageSize;
        final end = math.min(start + pageSize, visibleRows.length);
        final currentRows = start < visibleRows.length
            ? visibleRows.sublist(start, end)
            : <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsHero(
              totalPlayers: data.playerSeasonTotals.length,
              matchingPlayers: visibleRows.length,
              queryActive: query.trim().isNotEmpty,
            ),
            const SizedBox(height: 18),
            _StatsControls(
              queryController: queryController,
              basis: basis,
              seasonType: seasonType,
              sortField: sortField,
              descending: descending,
              pageSize: pageSize,
              showReboundBreakdown: showReboundBreakdown,
              onQueryChanged: _setQuery,
              onPresetSelected: (preset) {
                queryController.text = preset;
                _setQuery(preset);
              },
              onBasisChanged: (value) {
                if (value == null) return;
                setState(() {
                  basis = value;
                  page = 0;
                });
              },
              onSeasonChanged: (value) {
                if (value == null) return;
                setState(() {
                  seasonType = value;
                  page = 0;
                });
              },
              onSortChanged: (value) {
                if (value == null) return;
                setState(() {
                  sortField = value;
                  page = 0;
                });
              },
              onDirectionChanged: () {
                setState(() => descending = !descending);
              },
              onPageSizeChanged: (value) {
                if (value == null) return;
                setState(() {
                  pageSize = value;
                  page = 0;
                });
              },
              onReboundBreakdownChanged: (value) {
                setState(() => showReboundBreakdown = value);
              },
            ),
            const SizedBox(height: 18),
            _QueryPlanPanel(
              plan: plan,
              basis: basis,
              resultCount: visibleRows.length,
              playoffDataUnavailable: playoffDataUnavailable,
            ),
            const SizedBox(height: 18),
            _PaginationToolbar(
              firstVisible: visibleRows.isEmpty ? 0 : start + 1,
              lastVisible: end,
              totalRows: visibleRows.length,
              page: effectivePage,
              totalPages: totalPages,
              onPrevious: effectivePage > 0
                  ? () => setState(() => page = effectivePage - 1)
                  : null,
              onNext: effectivePage + 1 < totalPages
                  ? () => setState(() => page = effectivePage + 1)
                  : null,
              onCopy: visibleRows.isEmpty
                  ? null
                  : () => _copyRows(visibleRows),
            ),
            const SizedBox(height: 12),
            _StatsTable(
              rows: currentRows,
              showReboundBreakdown: showReboundBreakdown,
              basis: basis,
            ),
            const SizedBox(height: 18),
            const _StatsMethodologyPanel(),
          ],
        );
      },
    );
  }
}

class _StatsHero extends StatelessWidget {
  const _StatsHero({
    required this.totalPlayers,
    required this.matchingPlayers,
    required this.queryActive,
  });

  final int totalPlayers;
  final int matchingPlayers;
  final bool queryActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24071A33),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NBA STATS CENTER',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Query, sort and export official-style player tables.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 39,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 900),
            child: Text(
              'Natural-language requests become visible filter plans before execution. Results paginate, convert statistical basis, expand rebound columns and export directly as tab-separated data.',
              style: TextStyle(
                color: Color(0xFFEAF2FF),
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip('$totalPlayers PLAYER SUMMARIES'),
              _HeroChip('$matchingPlayers MATCHES'),
              _HeroChip(queryActive ? 'QUERY ACTIVE' : 'LEAGUE DEFAULT'),
              const _HeroChip('PAGINATED + EXPORTABLE'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsControls extends StatelessWidget {
  const _StatsControls({
    required this.queryController,
    required this.basis,
    required this.seasonType,
    required this.sortField,
    required this.descending,
    required this.pageSize,
    required this.showReboundBreakdown,
    required this.onQueryChanged,
    required this.onPresetSelected,
    required this.onBasisChanged,
    required this.onSeasonChanged,
    required this.onSortChanged,
    required this.onDirectionChanged,
    required this.onPageSizeChanged,
    required this.onReboundBreakdownChanged,
  });

  final TextEditingController queryController;
  final String basis;
  final String seasonType;
  final String sortField;
  final bool descending;
  final int pageSize;
  final bool showReboundBreakdown;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onPresetSelected;
  final ValueChanged<String?> onBasisChanged;
  final ValueChanged<String?> onSeasonChanged;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onDirectionChanged;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<bool> onReboundBreakdownChanged;

  @override
  Widget build(BuildContext context) {
    const presets = {
      'Veteran scorers': 'age over 29 and ppg > 15 sort by points',
      'Efficient scorers': 'ppg > 18 and fg% > 50 sort by points',
      'Playmakers': 'apg > 6 sort by assists',
      'Rim protectors': 'bpg > 1.5 sort by blocks',
    };

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            'Command query',
            'Use player or team names, comparisons, limits, sorting, season and basis language.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: queryController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Players over age 29 with PPG > 15 and FG% > 50',
              filled: true,
              fillColor: _soft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets.entries)
                ActionChip(
                  label: Text(
                    preset.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => onPresetSelected(preset.value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ResponsiveDropdown<String>(
                label: 'Season',
                value: seasonType,
                values: const ['Regular Season', 'Playoffs', 'Combined'],
                labelFor: (value) => value,
                onChanged: onSeasonChanged,
              ),
              _ResponsiveDropdown<String>(
                label: 'Basis',
                value: basis,
                values: const [
                  'Per Game',
                  'Per 36 Minutes',
                  'Per 100 Possessions',
                  'Totals',
                ],
                labelFor: (value) => value,
                onChanged: onBasisChanged,
              ),
              _ResponsiveDropdown<String>(
                label: 'Sort',
                value: sortField,
                values: const [
                  'ppg',
                  'rpg',
                  'apg',
                  'spg',
                  'bpg',
                  'fg_pct',
                  'three_pct',
                  'plus_minus',
                ],
                labelFor: _statLabel,
                onChanged: onSortChanged,
              ),
              _ResponsiveDropdown<int>(
                label: 'Rows',
                value: pageSize,
                values: const [10, 25, 50, 100],
                labelFor: (value) => '$value',
                onChanged: onPageSizeChanged,
              ),
              OutlinedButton.icon(
                onPressed: onDirectionChanged,
                icon: Icon(
                  descending ? Icons.south_rounded : Icons.north_rounded,
                ),
                label: Text(
                  descending ? 'Highest first' : 'Lowest first',
                ),
              ),
              FilterChip(
                selected: showReboundBreakdown,
                onSelected: onReboundBreakdownChanged,
                label: const Text(
                  'Show OREB / DREB [+]',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResponsiveDropdown<T> extends StatelessWidget {
  const _ResponsiveDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _soft,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _line),
          ),
        ),
        items: [
          for (final option in values)
            DropdownMenuItem<T>(
              value: option,
              child: Text(
                labelFor(option),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _QueryPlanPanel extends StatelessWidget {
  const _QueryPlanPanel({
    required this.plan,
    required this.basis,
    required this.resultCount,
    required this.playoffDataUnavailable,
  });

  final NbaStatsQueryPlan plan;
  final String basis;
  final int resultCount;
  final bool playoffDataUnavailable;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            'Interpreted query plan',
            'Every recognized condition is exposed before the table runs.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(Icons.calendar_month_rounded, plan.seasonType),
              _InfoPill(Icons.calculate_rounded, basis),
              _InfoPill(Icons.table_rows_rounded, '$resultCount rows'),
              for (final constraint in plan.constraints)
                _InfoPill(Icons.rule_rounded, _constraintLabel(constraint)),
              if (plan.sortField != null)
                _InfoPill(
                  Icons.sort_rounded,
                  '${plan.sortDescending ? 'Highest' : 'Lowest'} ${_statLabel(plan.sortField!)}',
                ),
              if (plan.limit != null)
                _InfoPill(Icons.filter_list_rounded, 'Limit ${plan.limit}'),
            ],
          ),
          if (playoffDataUnavailable) ...[
            const SizedBox(height: 12),
            const _Notice(
              'The current generated seed contains regular-season summaries only. Playoff queries return no rows rather than relabeling regular-season data.',
            ),
          ],
          if (plan.unparsedFragments.isNotEmpty &&
              plan.originalQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Notice(
              'Unparsed language retained for transparency: ${plan.unparsedFragments.join(' | ')}',
            ),
          ],
        ],
      ),
    );
  }
}

class _PaginationToolbar extends StatelessWidget {
  const _PaginationToolbar({
    required this.firstVisible,
    required this.lastVisible,
    required this.totalRows,
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    required this.onCopy,
  });

  final int firstVisible;
  final int lastVisible;
  final int totalRows;
  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            totalRows == 0
                ? 'No matching rows'
                : 'Showing $firstVisible–$lastVisible of $totalRows',
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          _InfoPill(
            Icons.menu_book_rounded,
            'Page ${page + 1} of $totalPages',
          ),
          OutlinedButton(
            onPressed: onPrevious,
            child: const Text('Previous'),
          ),
          OutlinedButton(
            onPressed: onNext,
            child: const Text('Next'),
          ),
          FilledButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text('Copy all as TSV'),
          ),
        ],
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({
    required this.rows,
    required this.showReboundBreakdown,
    required this.basis,
  });

  final List<Map<String, dynamic>> rows;
  final bool showReboundBreakdown;
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
      'RPG',
    ];
    if (showReboundBreakdown) columns.addAll(['OREB', 'DREB']);
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
      '+/-',
    ]);

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Player statistics',
            '${rows.length} rows on this page • $basis • horizontally scroll for all columns.',
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No matching rows.',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                      label: Text(
                        column,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(cells: _cellsForRow(row)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<DataCell> _cellsForRow(Map<String, dynamic> row) {
    final values = <String>[
      '${row['player']}',
      '${row['team']}',
      _formatNumber(row['age'], 0),
      _formatNumber(row['gp'], 0),
      _formatNumber(row['mpg'], 1),
      _formatNumber(row['ppg'], 1),
      _formatNumber(row['rpg'], 1),
    ];
    if (showReboundBreakdown) {
      values.addAll([
        _formatNumber(row['oreb'], 1),
        _formatNumber(row['dreb'], 1),
      ]);
    }
    values.addAll([
      _formatNumber(row['apg'], 1),
      _formatNumber(row['spg'], 1),
      _formatNumber(row['bpg'], 1),
      _formatNumber(row['tov'], 1),
      _formatNumber(row['pf'], 1),
      _formatNumber(row['fgm'], 1),
      _formatPercent(row['fg_pct']),
      _formatNumber(row['three_pm'], 1),
      _formatPercent(row['three_pct']),
      _formatNumber(row['ftm'], 1),
      _formatPercent(row['ft_pct']),
      _formatNumber(row['plus_minus'], 1),
    ]);

    return [
      for (final value in values)
        DataCell(
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ];
  }
}

class _StatsMethodologyPanel extends StatelessWidget {
  const _StatsMethodologyPanel();

  @override
  Widget build(BuildContext context) {
    return const _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Source and methodology',
            'Generated 2024–25 assets with transparent transformation rules.',
          ),
          SizedBox(height: 12),
          _Notice(
            'Per-36 scales counting statistics by minutes. Per-100 is an explicit estimate using 2.05 possessions per player-minute until possession data is connected.',
          ),
          SizedBox(height: 8),
          _Notice(
            'TSV export copies the complete filtered result set for Workspace, Excel or Python Lab, not only the current page.',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _muted,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _soft,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _blue, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.26)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

List<Map<String, dynamic>> _applyTextAndStatQuery(
  List<Map<String, dynamic>> rows,
  NbaStatsQueryPlan plan,
  String query,
) {
  final filtered = plan.apply(rows);
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty || plan.constraints.isNotEmpty) return filtered;

  return filtered.where((row) {
    final haystack = '${row['player']} ${row['team']}'.toLowerCase();
    if (haystack.contains(normalizedQuery)) return true;
    return normalizedQuery.split(RegExp(r'\s+')).any(
          (token) => token.length > 2 && haystack.contains(token),
        );
  }).toList();
}

Map<String, dynamic> _normalizePlayerRow(
  Map<String, dynamic> source,
  String basis,
) {
  final games = _number(source['games']);
  final minutes = _perGame(source, 'minutes', 'minutes_per_game');
  double factor = 1;
  if (basis == 'Per 36 Minutes' && minutes > 0) factor = 36 / minutes;
  if (basis == 'Per 100 Possessions' && minutes > 0) {
    factor = 100 / (minutes * 2.05);
  }
  if (basis == 'Totals') factor = games > 0 ? games : 1;

  double scaled(String totalKey, String perGameKey) {
    return _perGame(source, totalKey, perGameKey) * factor;
  }

  return {
    ...source,
    'player': _text(source['player_label']),
    'team': _text(source['team_ids']),
    'age': _nullableNumber(source['age']),
    'gp': games,
    'mpg': basis == 'Totals' ? minutes * factor : minutes,
    'ppg': scaled('points', 'points_per_game'),
    'rpg': scaled('rebounds', 'rebounds_per_game'),
    'oreb': scaled(
      'offensive_rebounds',
      'offensive_rebounds_per_game',
    ),
    'dreb': scaled(
      'defensive_rebounds',
      'defensive_rebounds_per_game',
    ),
    'apg': scaled('assists', 'assists_per_game'),
    'spg': scaled('steals', 'steals_per_game'),
    'bpg': scaled('blocks', 'blocks_per_game'),
    'tov': scaled('turnovers', 'turnovers_per_game'),
    'pf': scaled('personal_fouls', 'personal_fouls_per_game'),
    'fgm': scaled('field_goals', 'field_goals_per_game'),
    'three_pm': scaled('three_pointers', 'three_pointers_per_game'),
    'ftm': scaled('free_throws', 'free_throws_per_game'),
    'plus_minus': scaled('plus_minus', 'plus_minus_per_game'),
    'fg_pct': _percentage(
      source,
      const ['fg_pct', 'field_goal_pct', 'avg_fg_pct'],
    ),
    'three_pct': _percentage(
      source,
      const ['three_point_pct', 'fg3_pct', 'avg_fg3_pct'],
    ),
    'ft_pct': _percentage(
      source,
      const ['free_throw_pct', 'ft_pct', 'avg_ft_pct'],
    ),
  };
}

double _perGame(
  Map<String, dynamic> row,
  String totalKey,
  String perGameKey,
) {
  final direct = _nullableNumber(row[perGameKey]);
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
    value.toString().replaceAll(',', '').replaceAll('%', ''),
  );
}

String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _formatNumber(Object? value, int decimals) {
  final number = _nullableNumber(value);
  if (number == null) return '—';
  if (decimals == 0) return number.round().toString();
  return number.toStringAsFixed(decimals);
}

String _formatPercent(Object? value) {
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
  final value = constraint.field.endsWith('_pct')
      ? '${(constraint.value * 100).toStringAsFixed(1)}%'
      : constraint.value.toStringAsFixed(
          constraint.value == constraint.value.roundToDouble() ? 0 : 1,
        );
  return '${_statLabel(constraint.field)} $operator $value';
}
