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
  bool showRebounds = false;
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
      'fg_pct',
      'three_pct',
      'ft_pct',
    ];
    final output = <String>[fields.join('\t')];
    for (final row in rows) {
      output.add(fields.map((field) => '${row[field] ?? ''}').join('\t'));
    }
    await Clipboard.setData(ClipboardData(text: output.join('\n')));
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
        var rows = [
          for (final row in data.playerSeasonTotals) _normalize(row, basis),
        ];
        rows = _applyQuery(rows, plan, query);

        final activeSort = plan.sortField ?? sortField;
        final activeDescending =
            plan.sortField == null ? descending : plan.sortDescending;
        rows.sort((left, right) {
          final comparison =
              _num(left[activeSort]).compareTo(_num(right[activeSort]));
          return activeDescending ? -comparison : comparison;
        });
        if (plan.limit != null && rows.length > plan.limit!) {
          rows = rows.take(plan.limit!).toList();
        }

        final playoffUnavailable = plan.seasonType == 'Playoffs';
        final visibleRows =
            playoffUnavailable ? <Map<String, dynamic>>[] : rows;
        final totalPages = math.max(1, (visibleRows.length / pageSize).ceil());
        final safePage = math.min(page, totalPages - 1);
        final start = safePage * pageSize;
        final end = math.min(start + pageSize, visibleRows.length);
        final pageRows = start < visibleRows.length
            ? visibleRows.sublist(start, end)
            : <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              total: data.playerSeasonTotals.length,
              matches: visibleRows.length,
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
            ),
            const SizedBox(height: 18),
            _QueryPlan(
              plan: plan,
              resultCount: visibleRows.length,
              playoffUnavailable: playoffUnavailable,
            ),
            const SizedBox(height: 18),
            _Pager(
              start: visibleRows.isEmpty ? 0 : start + 1,
              end: end,
              total: visibleRows.length,
              page: safePage,
              totalPages: totalPages,
              onPrevious: safePage > 0
                  ? () => setState(() => page = safePage - 1)
                  : null,
              onNext: safePage + 1 < totalPages
                  ? () => setState(() => page = safePage + 1)
                  : null,
              onCopy: visibleRows.isEmpty ? null : () => _copyRows(visibleRows),
            ),
            const SizedBox(height: 12),
            _StatsTable(rows: pageRows, showRebounds: showRebounds, basis: basis),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.total, required this.matches});

  final int total;
  final int matches;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NBA STATS CENTER',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Query, sort and export player statistics.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Natural-language requests become visible filter plans before execution. Results remain transparent about the available regular-season source data.',
            style: TextStyle(
              color: Color(0xFFEAF2FF),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip('$total PLAYER SUMMARIES'),
              _HeroChip('$matches MATCHES'),
              const _HeroChip('PAGINATED'),
              const _HeroChip('TSV EXPORT'),
            ],
          ),
        ],
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            'Command query',
            'Try: more than 15 PPG, fewer than 4 RPG, FG% above 50, or top 25 sorted by assists.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'List players over age 29 with more than 15 PPG',
              filled: true,
              fillColor: _soft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth < 520
                  ? constraints.maxWidth
                  : math.min(210.0, constraints.maxWidth);
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Dropdown<String>(
                    width: fieldWidth,
                    label: 'Season',
                    value: seasonType,
                    values: const ['Regular Season', 'Playoffs', 'Combined'],
                    onChanged: onSeason,
                  ),
                  _Dropdown<String>(
                    width: fieldWidth,
                    label: 'Basis',
                    value: basis,
                    values: const [
                      'Per Game',
                      'Per 36 Minutes',
                      'Per 100 Possessions',
                      'Totals',
                    ],
                    onChanged: onBasis,
                  ),
                  _Dropdown<String>(
                    width: fieldWidth,
                    label: 'Sort',
                    value: sortField,
                    values: const ['ppg', 'rpg', 'apg', 'spg', 'bpg', 'fg_pct'],
                    onChanged: onSort,
                  ),
                  _Dropdown<int>(
                    width: fieldWidth,
                    label: 'Rows',
                    value: pageSize,
                    values: const [10, 25, 50, 100],
                    onChanged: onPageSize,
                  ),
                  OutlinedButton.icon(
                    onPressed: onDirection,
                    icon: Icon(
                      descending
                          ? Icons.south_rounded
                          : Icons.north_rounded,
                    ),
                    label: Text(descending ? 'Descending' : 'Ascending'),
                  ),
                  FilterChip(
                    selected: showRebounds,
                    onSelected: onRebounds,
                    label: const Text('OREB / DREB'),
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

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.width,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final double width;
  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _soft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        items: [
          for (final option in values)
            DropdownMenuItem<T>(
              value: option,
              child: Text('$option', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _QueryPlan extends StatelessWidget {
  const _QueryPlan({
    required this.plan,
    required this.resultCount,
    required this.playoffUnavailable,
  });

  final NbaStatsQueryPlan plan;
  final int resultCount;
  final bool playoffUnavailable;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            'Interpreted query plan',
            'The table only applies conditions shown here.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip('Season', plan.seasonType),
              _InfoChip('Basis', plan.basis),
              _InfoChip('Matches', '$resultCount'),
              if (plan.sortField != null)
                _InfoChip('Sort', '${plan.sortField}'),
              if (plan.limit != null) _InfoChip('Limit', '${plan.limit}'),
              for (final constraint in plan.constraints)
                _InfoChip('Filter', _constraintText(constraint)),
            ],
          ),
          if (playoffUnavailable) ...[
            const SizedBox(height: 12),
            const Text(
              'Playoff summaries are not present in the current seed warehouse, so regular-season rows are not relabeled as playoff data.',
              style: TextStyle(
                color: _orange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (plan.unparsedFragments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Unparsed: ${plan.unparsedFragments.join(' | ')}',
              style: const TextStyle(color: _muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.start,
    required this.end,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    required this.onCopy,
  });

  final int start;
  final int end;
  final int total;
  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$start-$end of $total • page ${page + 1} of $totalPages',
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
        ),
        OutlinedButton(
          onPressed: onPrevious,
          child: const Text('Previous'),
        ),
        OutlinedButton(onPressed: onNext, child: const Text('Next')),
        FilledButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy TSV'),
        ),
      ],
    );
  }
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
    final columns = <String>['Player', 'Team', 'Age', 'GP', 'MPG', 'PPG', 'RPG'];
    if (showRebounds) columns.addAll(['OREB', 'DREB']);
    columns.addAll(['APG', 'SPG', 'BPG', 'FG%', '3P%', 'FT%']);

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Player statistics', '$basis • ${rows.length} visible rows'),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text(
              'No rows match the current query and available dataset.',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
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
                    DataRow(cells: _cells(row, showRebounds)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static List<DataCell> _cells(
    Map<String, dynamic> row,
    bool showRebounds,
  ) {
    final values = <String>[
      '${row['player']}',
      '${row['team']}',
      _display(row['age'], 0),
      _display(row['gp'], 0),
      _display(row['mpg'], 1),
      _display(row['ppg'], 1),
      _display(row['rpg'], 1),
    ];
    if (showRebounds) {
      values.addAll([_display(row['oreb'], 1), _display(row['dreb'], 1)]);
    }
    values.addAll([
      _display(row['apg'], 1),
      _display(row['spg'], 1),
      _display(row['bpg'], 1),
      _percent(row['fg_pct']),
      _percent(row['three_pct']),
      _percent(row['ft_pct']),
    ]);
    return [for (final value in values) DataCell(Text(value))];
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

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
            fontSize: 21,
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

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x44FFFFFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _applyQuery(
  List<Map<String, dynamic>> rows,
  NbaStatsQueryPlan plan,
  String rawQuery,
) {
  var filtered = rows
      .where(
        (row) => plan.constraints.every((constraint) => constraint.matches(row)),
      )
      .toList();
  final textTokens = plan.unparsedFragments
      .expand((fragment) => fragment.split(' '))
      .where((token) => token.length >= 3)
      .toList();
  if (textTokens.isEmpty || rawQuery.trim().isEmpty) return filtered;
  filtered = filtered.where((row) {
    final haystack = '${row['player']} ${row['team']}'.toLowerCase();
    return textTokens.any(haystack.contains);
  }).toList();
  return filtered;
}

Map<String, dynamic> _normalize(Map<String, dynamic> row, String basis) {
  final games = _num(row['games']);
  final minutesPerGame = _perGame(row, 'minutes', 'minutes_per_game');
  double scale;
  if (basis == 'Per 36 Minutes') {
    scale = minutesPerGame > 0 ? 36 / minutesPerGame : 0;
  } else if (basis == 'Per 100 Possessions') {
    scale = minutesPerGame > 0 ? 48 / minutesPerGame : 0;
  } else if (basis == 'Totals') {
    scale = games > 0 ? games : 1;
  } else {
    scale = 1;
  }

  double value(String totalKey, String perGameKey) {
    return _perGame(row, totalKey, perGameKey) * scale;
  }

  return {
    'player': _text(row['player_label']),
    'team': _text(row['team_ids']),
    'age': _nullableNum(row['age']),
    'gp': games,
    'mpg': basis == 'Totals' ? _num(row['minutes']) : minutesPerGame,
    'ppg': value('points', 'points_per_game'),
    'rpg': value('rebounds', 'rebounds_per_game'),
    'oreb': value('offensive_rebounds', 'offensive_rebounds_per_game'),
    'dreb': value('defensive_rebounds', 'defensive_rebounds_per_game'),
    'apg': value('assists', 'assists_per_game'),
    'spg': value('steals', 'steals_per_game'),
    'bpg': value('blocks', 'blocks_per_game'),
    'tov': value('turnovers', 'turnovers_per_game'),
    'pf': value('personal_fouls', 'personal_fouls_per_game'),
    'fg_pct': _firstNumber(row, const ['fg_pct', 'field_goal_pct', 'avg_fg_pct']),
    'three_pct':
        _firstNumber(row, const ['three_point_pct', 'fg3_pct', 'avg_fg3_pct']),
    'ft_pct': _firstNumber(row, const ['free_throw_pct', 'ft_pct', 'avg_ft_pct']),
    'plus_minus': value('plus_minus', 'plus_minus_per_game'),
  };
}

String _constraintText(NbaStatConstraint constraint) {
  final operator = switch (constraint.operator) {
    NbaStatOperator.greaterThan => '>',
    NbaStatOperator.greaterThanOrEqual => '>=',
    NbaStatOperator.lessThan => '<',
    NbaStatOperator.lessThanOrEqual => '<=',
    NbaStatOperator.equal => '=',
    NbaStatOperator.between => 'between',
  };
  if (constraint.operator == NbaStatOperator.between) {
    return '${constraint.field} $operator ${constraint.value} and ${constraint.secondValue}';
  }
  return '${constraint.field} $operator ${constraint.value}';
}

double _perGame(Map<String, dynamic> row, String totalKey, String perGameKey) {
  final direct = _nullableNum(row[perGameKey]);
  if (direct != null) return direct;
  final total = _nullableNum(row[totalKey]);
  final games = _nullableNum(row['games']);
  if (total == null || games == null || games <= 0) return 0;
  return total / games;
}

double? _firstNumber(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _nullableNum(row[key]);
    if (value != null) return value > 1 ? value / 100 : value;
  }
  return null;
}

double _num(Object? value) => _nullableNum(value) ?? 0;

double? _nullableNum(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '').replaceAll('%', ''));
}

String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _display(Object? value, int decimals) {
  final number = _nullableNum(value);
  if (number == null) return '—';
  return decimals == 0 ? number.round().toString() : number.toStringAsFixed(decimals);
}

String _percent(Object? value) {
  final number = _nullableNum(value);
  if (number == null) return '—';
  return '${(number <= 1 ? number * 100 : number).toStringAsFixed(1)}%';
}
