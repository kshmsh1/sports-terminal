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
  final NbaStatsQueryEngine engine = const NbaStatsQueryEngine();
  final TextEditingController controller = TextEditingController();

  late final Future<NbaTerminalSeedSnapshot> seedFuture;
  String query = '';
  String basis = 'Per Game';
  String season = 'Regular Season';
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
    controller.dispose();
    super.dispose();
  }

  Future<void> _restoreQuery() async {
    final saved = await store.loadString(ProductLocalStore.statsQueryKey);
    if (!mounted) return;
    setState(() {
      query = saved;
      controller.text = saved;
    });
  }

  Future<void> _changeQuery(String value) async {
    setState(() {
      query = value;
      page = 0;
    });
    await store.saveString(ProductLocalStore.statsQueryKey, value);
  }

  Future<void> _copy(List<Map<String, dynamic>> rows) async {
    const fields = [
      'player', 'team', 'age', 'gp', 'mpg', 'ppg', 'rpg', 'apg',
      'spg', 'bpg', 'tov', 'pf', 'fg_pct', 'three_pct', 'ft_pct',
      'plus_minus'
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
        final plan = engine.parse(
          query,
          defaultSeasonType: season,
          defaultBasis: basis,
        );
        final normalized = [
          for (final row in data.playerSeasonTotals) _normalize(row, basis),
        ];
        var results = _applyQuery(normalized, plan, query);
        final activeSort = plan.sortField ?? sortField;
        final activeDescending =
            plan.sortField == null ? descending : plan.sortDescending;
        results.sort((a, b) {
          final comparison =
              _number(a[activeSort]).compareTo(_number(b[activeSort]));
          return activeDescending ? -comparison : comparison;
        });
        if (plan.limit != null && results.length > plan.limit!) {
          results = results.take(plan.limit!).toList();
        }

        final playoffUnavailable = plan.seasonType == 'Playoffs';
        final visible = playoffUnavailable ? <Map<String, dynamic>>[] : results;
        final pages = math.max(1, (visible.length / pageSize).ceil());
        final safePage = page.clamp(0, pages - 1).toInt();
        if (safePage != page) page = safePage;
        final start = safePage * pageSize;
        final end = math.min(start + pageSize, visible.length);
        final rows = start < visible.length
            ? visible.sublist(start, end)
            : <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(total: data.playerSeasonTotals.length, matches: visible.length),
            const SizedBox(height: 18),
            _Controls(
              controller: controller,
              basis: basis,
              season: season,
              sortField: sortField,
              descending: descending,
              pageSize: pageSize,
              showRebounds: showRebounds,
              onQuery: _changeQuery,
              onBasis: (value) => setState(() {
                basis = value ?? basis;
                page = 0;
              }),
              onSeason: (value) => setState(() {
                season = value ?? season;
                page = 0;
              }),
              onSort: (value) => setState(() {
                sortField = value ?? sortField;
                page = 0;
              }),
              onDirection: () => setState(() => descending = !descending),
              onPageSize: (value) => setState(() {
                pageSize = value ?? pageSize;
                page = 0;
              }),
              onRebounds: (value) => setState(() => showRebounds = value),
              onPreset: (value) {
                controller.text = value;
                _changeQuery(value);
              },
            ),
            const SizedBox(height: 18),
            _Plan(
              plan: plan,
              basis: basis,
              resultCount: visible.length,
              playoffUnavailable: playoffUnavailable,
            ),
            const SizedBox(height: 18),
            _Pager(
              start: visible.isEmpty ? 0 : start + 1,
              end: end,
              total: visible.length,
              page: safePage,
              pages: pages,
              previous: safePage > 0
                  ? () => setState(() => page = safePage - 1)
                  : null,
              next: safePage + 1 < pages
                  ? () => setState(() => page = safePage + 1)
                  : null,
              copy: visible.isEmpty ? null : () => _copy(visible),
            ),
            const SizedBox(height: 12),
            _StatsTable(rows: rows, showRebounds: showRebounds, basis: basis),
            const SizedBox(height: 18),
            const _Method(),
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
          boxShadow: const [
            BoxShadow(color: Color(0x24071A33), blurRadius: 32,
                offset: Offset(0, 16)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NBA STATS CENTER', style: TextStyle(
              color: Colors.white70, fontWeight: FontWeight.w900,
              fontSize: 12, letterSpacing: 1.4)),
          const SizedBox(height: 12),
          const Text('Query, sort and export official-style player tables.',
              style: TextStyle(color: Colors.white, fontSize: 39, height: 1.04,
                  fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 900),
            child: Text(
              'Natural-language requests become visible filter plans before execution. Results paginate, convert statistical basis, expand rebound columns and export directly as tab-separated data.',
              style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16,
                  height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _Chip('$total PLAYER SUMMARIES'),
            _Chip('$matches MATCHES'),
            const _Chip('QUERY PLAN VISIBLE'),
            const _Chip('PAGINATED + EXPORTABLE'),
          ]),
        ]),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller, required this.basis, required this.season,
    required this.sortField, required this.descending,
    required this.pageSize, required this.showRebounds,
    required this.onQuery, required this.onBasis, required this.onSeason,
    required this.onSort, required this.onDirection,
    required this.onPageSize, required this.onRebounds,
    required this.onPreset,
  });
  final TextEditingController controller;
  final String basis;
  final String season;
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
              'Use player or team names, comparisons, limits, sorting, season and basis language.'),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Players over age 29 with PPG > 15 and FG% > 50',
              filled: true, fillColor: _soft,
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
                label: Text(preset.key,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => onPreset(preset.value),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Drop<String>(label: 'Season', value: season,
                values: const ['Regular Season', 'Playoffs', 'Combined'],
                text: (value) => value, onChanged: onSeason),
            _Drop<String>(label: 'Basis', value: basis,
                values: const ['Per Game', 'Per 36 Minutes',
                  'Per 100 Possessions', 'Totals'],
                text: (value) => value, onChanged: onBasis),
            _Drop<String>(label: 'Sort', value: sortField,
                values: const ['ppg', 'rpg', 'apg', 'spg', 'bpg',
                  'fg_pct', 'three_pct', 'plus_minus'],
                text: _statLabel, onChanged: onSort),
            _Drop<int>(label: 'Rows', value: pageSize,
                values: const [10, 25, 50, 100],
                text: (value) => '$value', onChanged: onPageSize),
            OutlinedButton.icon(
              onPressed: onDirection,
              icon: Icon(descending ? Icons.south_rounded : Icons.north_rounded),
              label: Text(descending ? 'Highest first' : 'Lowest first'),
            ),
            FilterChip(
              selected: showRebounds, onSelected: onRebounds,
              label: const Text('Show OREB / DREB [+]',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      );
}

class _Drop<T> extends StatelessWidget {
  const _Drop({required this.label, required this.value,
    required this.values, required this.text, required this.onChanged});
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) text;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label, filled: true, fillColor: _soft,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12,
                vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _line),
            ),
          ),
          items: [for (final option in values) DropdownMenuItem<T>(
            value: option,
            child: Text(text(option), overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          )],
          onChanged: onChanged,
        ),
      );
}

class _Plan extends StatelessWidget {
  const _Plan({required this.plan, required this.basis,
    required this.resultCount, required this.playoffUnavailable});
  final NbaStatsQueryPlan plan;
  final String basis;
  final int resultCount;
  final bool playoffUnavailable;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Header('Interpreted query plan',
              'Every recognized condition is exposed before the table runs.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Info(Icons.calendar_month_rounded, plan.seasonType),
            _Info(Icons.calculate_rounded, basis),
            _Info(Icons.table_rows_rounded, '$resultCount rows'),
            for (final constraint in plan.constraints)
              _Info(Icons.rule_rounded, _constraint(constraint)),
            if (plan.sortField != null)
              _Info(Icons.sort_rounded, _statLabel(plan.sortField!)),
            if (plan.limit != null)
              _Info(Icons.filter_list_rounded, 'Limit ${plan.limit}'),
          ]),
          if (playoffUnavailable) ...[
            const SizedBox(height: 12),
            const _Notice(
              'The current seed contains regular-season summaries only. Playoff queries return no rows rather than relabeling regular-season data.'),
          ],
          if (plan.unparsedFragments.isNotEmpty &&
              plan.originalQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Notice('Unparsed language retained: '
                '${plan.unparsedFragments.join(' | ')}'),
          ],
        ]),
      );
}

class _Pager extends StatelessWidget {
  const _Pager({required this.start, required this.end, required this.total,
    required this.page, required this.pages, required this.previous,
    required this.next, required this.copy});
  final int start;
  final int end;
  final int total;
  final int page;
  final int pages;
  final VoidCallback? previous;
  final VoidCallback? next;
  final VoidCallback? copy;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(spacing: 10, runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(total == 0 ? 'No matching rows' : 'Showing $start–$end of $total',
                style: const TextStyle(color: _ink,
                    fontWeight: FontWeight.w900)),
            _Info(Icons.menu_book_rounded, 'Page ${page + 1} of $pages'),
            OutlinedButton(onPressed: previous, child: const Text('Previous')),
            OutlinedButton(onPressed: next, child: const Text('Next')),
            FilledButton.icon(onPressed: copy,
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('Copy all as TSV')),
          ],
        ),
      );
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.rows, required this.showRebounds,
    required this.basis});
  final List<Map<String, dynamic>> rows;
  final bool showRebounds;
  final String basis;

  @override
  Widget build(BuildContext context) {
    final columns = <String>['Player', 'Team', 'Age', 'GP', 'MPG', 'PPG', 'RPG'];
    if (showRebounds) columns.addAll(['OREB', 'DREB']);
    columns.addAll(['APG', 'SPG', 'BPG', 'TOV', 'PF', 'FGM', 'FG%',
      '3PM', '3P%', 'FTM', 'FT%', '+/-']);
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Header('Player statistics',
            '${rows.length} rows on this page • $basis • horizontally scroll for all columns.'),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No matching rows.',
                style: TextStyle(color: _muted,
                    fontWeight: FontWeight.w700))))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(_soft),
              columns: [for (final column in columns) DataColumn(
                label: Text(column, style: const TextStyle(color: _muted,
                    fontWeight: FontWeight.w900)))],
              rows: [for (final row in rows) DataRow(cells: _cells(row))],
            ),
          ),
      ]),
    );
  }

  List<DataCell> _cells(Map<String, dynamic> row) {
    final values = <String>[
      '${row['player']}', '${row['team']}', _format(row['age'], 0),
      _format(row['gp'], 0), _format(row['mpg'], 1),
      _format(row['ppg'], 1), _format(row['rpg'], 1),
    ];
    if (showRebounds) {
      values.addAll([_format(row['oreb'], 1), _format(row['dreb'], 1)]);
    }
    values.addAll([
      _format(row['apg'], 1), _format(row['spg'], 1),
      _format(row['bpg'], 1), _format(row['tov'], 1),
      _format(row['pf'], 1), _format(row['fgm'], 1),
      _percent(row['fg_pct']), _format(row['three_pm'], 1),
      _percent(row['three_pct']), _format(row['ftm'], 1),
      _percent(row['ft_pct']), _format(row['plus_minus'], 1),
    ]);
    return [for (final value in values) DataCell(Text(value,
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)))];
  }
}

class _Method extends StatelessWidget {
  const _Method();
  @override
  Widget build(BuildContext context) => const _Surface(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Header('Source and methodology',
          'Generated 2024–25 assets with transparent transformation rules.'),
      SizedBox(height: 12),
      _Notice('Per-36 scales counting statistics by minutes. Per-100 is an explicit estimate using 2.05 possessions per player-minute until possession data is connected.'),
      SizedBox(height: 8),
      _Notice('TSV export copies the complete filtered result set for Workspace, Excel or Python Lab, not only the current page.'),
    ]),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 22,
          fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _muted, height: 1.35,
          fontWeight: FontWeight.w600)),
    ],
  );
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(color: _soft, border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: _blue, size: 16), const SizedBox(width: 7),
      Text(label, style: const TextStyle(color: _ink, fontSize: 12,
          fontWeight: FontWeight.w800)),
    ]),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _soft, border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(16)),
    child: Text(text, style: const TextStyle(color: _muted, height: 1.35,
        fontWeight: FontWeight.w700)),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.26))),
    child: Text(label, style: const TextStyle(color: Colors.white,
        fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: _line), borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 22,
          offset: Offset(0, 10))]),
    child: child,
  );
}

List<Map<String, dynamic>> _applyQuery(List<Map<String, dynamic>> rows,
    NbaStatsQueryPlan plan, String query) {
  final filtered = plan.apply(rows);
  final value = query.trim().toLowerCase();
  if (value.isEmpty || plan.constraints.isNotEmpty) return filtered;
  return filtered.where((row) {
    final haystack = '${row['player']} ${row['team']}'.toLowerCase();
    return haystack.contains(value) || value.split(RegExp(r'\s+')).any(
        (token) => token.length > 2 && haystack.contains(token));
  }).toList();
}

Map<String, dynamic> _normalize(Map<String, dynamic> row, String basis) {
  final games = _number(row['games']);
  final minutes = _perGame(row, 'minutes', 'minutes_per_game');
  double factor = 1;
  if (basis == 'Per 36 Minutes' && minutes > 0) factor = 36 / minutes;
  if (basis == 'Per 100 Possessions' && minutes > 0) {
    factor = 100 / (minutes * 2.05);
  }
  if (basis == 'Totals') factor = games > 0 ? games : 1;
  double scaled(String total, String per) => _perGame(row, total, per) * factor;
  return {
    ...row,
    'player': _text(row['player_label']),
    'team': _text(row['team_ids']),
    'age': _nullable(row['age']),
    'gp': games,
    'mpg': basis == 'Totals' ? minutes * factor : minutes,
    'ppg': scaled('points', 'points_per_game'),
    'rpg': scaled('rebounds', 'rebounds_per_game'),
    'oreb': scaled('offensive_rebounds', 'offensive_rebounds_per_game'),
    'dreb': scaled('defensive_rebounds', 'defensive_rebounds_per_game'),
    'apg': scaled('assists', 'assists_per_game'),
    'spg': scaled('steals', 'steals_per_game'),
    'bpg': scaled('blocks', 'blocks_per_game'),
    'tov': scaled('turnovers', 'turnovers_per_game'),
    'pf': scaled('personal_fouls', 'personal_fouls_per_game'),
    'fgm': scaled('field_goals', 'field_goals_per_game'),
    'three_pm': scaled('three_pointers', 'three_pointers_per_game'),
    'ftm': scaled('free_throws', 'free_throws_per_game'),
    'plus_minus': scaled('plus_minus', 'plus_minus_per_game'),
    'fg_pct': _pct(row, const ['fg_pct', 'field_goal_pct', 'avg_fg_pct']),
    'three_pct': _pct(row,
        const ['three_point_pct', 'fg3_pct', 'avg_fg3_pct']),
    'ft_pct': _pct(row, const ['free_throw_pct', 'ft_pct', 'avg_ft_pct']),
  };
}

double _perGame(Map<String, dynamic> row, String total, String per) {
  final direct = _nullable(row[per]);
  if (direct != null) return direct;
  final games = _nullable(row['games']);
  final totalValue = _nullable(row[total]);
  return games != null && games > 0 && totalValue != null
      ? totalValue / games : 0;
}

double _pct(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _nullable(row[key]);
    if (value != null) return value > 1 ? value / 100 : value;
  }
  return 0;
}

double _number(Object? value) => _nullable(value) ?? 0;
double? _nullable(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString().replaceAll(',', '').replaceAll('%', ''));
}
String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}
String _format(Object? value, int decimals) {
  final number = _nullable(value);
  if (number == null) return '—';
  return decimals == 0 ? number.round().toString() : number.toStringAsFixed(decimals);
}
String _percent(Object? value) {
  final number = _nullable(value);
  return number == null || number == 0 ? '—' : '${(number * 100).toStringAsFixed(1)}%';
}
String _statLabel(String field) => const {
  'ppg': 'PPG', 'rpg': 'RPG', 'apg': 'APG', 'spg': 'SPG', 'bpg': 'BPG',
  'fg_pct': 'FG%', 'three_pct': '3P%', 'ft_pct': 'FT%',
  'plus_minus': '+/-', 'age': 'Age', 'gp': 'GP', 'mpg': 'MPG',
}[field] ?? field.toUpperCase();
String _constraint(NbaStatConstraint value) {
  final operator = switch (value.operator) {
    NbaStatOperator.greaterThan => '>',
    NbaStatOperator.greaterThanOrEqual => '≥',
    NbaStatOperator.lessThan => '<',
    NbaStatOperator.lessThanOrEqual => '≤',
    NbaStatOperator.equal => '=',
    NbaStatOperator.between => 'between',
  };
  final number = value.field.endsWith('_pct')
      ? '${(value.value * 100).toStringAsFixed(1)}%'
      : value.value.toStringAsFixed(
          value.value == value.value.roundToDouble() ? 0 : 1);
  return '${_statLabel(value.field)} $operator $number';
}
