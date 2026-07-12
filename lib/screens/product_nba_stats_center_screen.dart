import 'package:flutter/material.dart';

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
  State<ProductNbaStatsCenterScreen> createState() => _ProductNbaStatsCenterScreenState();
}

class _ProductNbaStatsCenterScreenState extends State<ProductNbaStatsCenterScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  final TextEditingController queryController = TextEditingController();
  bool showReboundBreakdown = false;
  String basis = 'Per Game';
  String seasonType = 'Regular Season';
  String query = '';

  @override
  void initState() {
    super.initState();
    _loadQuery();
  }

  Future<void> _loadQuery() async {
    final saved = await localStore.loadString(ProductLocalStore.statsQueryKey);
    if (!mounted) return;
    setState(() {
      query = saved;
      queryController.text = saved;
    });
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> _setQuery(String value) async {
    setState(() => query = value);
    await localStore.saveString(ProductLocalStore.statsQueryKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Surface(child: Text('Loading NBA stats center...', style: TextStyle(color: _muted)));
        if (snapshot.hasError) return _Surface(child: Text('Stats unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        final data = snapshot.data!;
        final rows = _filteredRows(data.playerSeasonTotals, query)..sort((a, b) => _perGameNum(b, 'points', 'points_per_game').compareTo(_perGameNum(a, 'points', 'points_per_game')));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroBand(totalPlayers: data.playerSeasonTotals.length, query: query),
          const SizedBox(height: 18),
          _ControlPanel(
            controller: queryController,
            basis: basis,
            seasonType: seasonType,
            showReboundBreakdown: showReboundBreakdown,
            onQueryChanged: _setQuery,
            onBasisChanged: (value) => setState(() => basis = value ?? basis),
            onSeasonTypeChanged: (value) => setState(() => seasonType = value ?? seasonType),
            onToggleRebounds: (value) => setState(() => showReboundBreakdown = value),
          ),
          const SizedBox(height: 18),
          _SourcePanel(query: query, seasonType: seasonType, basis: basis),
          const SizedBox(height: 18),
          _StatsTable(rows: rows.take(250).toList(), showReboundBreakdown: showReboundBreakdown, basis: basis),
        ]);
      },
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.totalPlayers, required this.query});
  final int totalPlayers;
  final String query;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(colors: [_navy, _blue, _orange]), boxShadow: const [BoxShadow(color: Color(0x24071A33), blurRadius: 32, offset: Offset(0, 16))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NBA STATS CENTER', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
          const SizedBox(height: 12),
          const Text('Official-stats-style tables with a command-query layer.', style: TextStyle(color: Colors.white, fontSize: 39, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          const SizedBox(width: 880, child: Text('The default view is player per-game production. The long-term version should support every NBA.com/stats-style category, regular season/playoffs, lineup filters, shot zones, clutch, tracking, hustle, and natural-language stat queries with source transparency.', style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [_GlassChip('$totalPlayers PLAYER SUMMARIES'), _GlassChip(query.isEmpty ? 'NO QUERY FILTER' : 'QUERY ACTIVE'), const _GlassChip('PER-GAME DEFAULT'), const _GlassChip('REGULAR SEASON / PLAYOFFS SLOT')]),
        ]),
      );
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.controller, required this.basis, required this.seasonType, required this.showReboundBreakdown, required this.onQueryChanged, required this.onBasisChanged, required this.onSeasonTypeChanged, required this.onToggleRebounds});
  final TextEditingController controller;
  final String basis;
  final String seasonType;
  final bool showReboundBreakdown;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onBasisChanged;
  final ValueChanged<String?> onSeasonTypeChanged;
  final ValueChanged<bool> onToggleRebounds;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionHeader('Query the stat table', 'Examples: "over 15 PPG", "less than 4 RPG", "FG% > 50", "BOS", "age over 29". Current parsing is a first local prototype.'),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'List players over age 29 with more than 15 PPG, less than 4 RPG, FG% > 50%', filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line))),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _Drop(label: 'Season type', value: seasonType, values: const ['Regular Season', 'Playoffs', 'Combined'], onChanged: onSeasonTypeChanged),
            _Drop(label: 'Basis', value: basis, values: const ['Per Game', 'Per 36', 'Per 100 Possessions'], onChanged: onBasisChanged),
            FilterChip(selected: showReboundBreakdown, onSelected: onToggleRebounds, selectedColor: const Color(0xFFEFF6FF), checkmarkColor: _blue, label: const Text('Show OREB / DREB [+]', style: TextStyle(fontWeight: FontWeight.w900))),
          ]),
        ]),
      );
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.rows, required this.showReboundBreakdown, required this.basis});
  final List<Map<String, dynamic>> rows;
  final bool showReboundBreakdown;
  final String basis;

  @override
  Widget build(BuildContext context) {
    final columns = <String>['Player', 'Team', 'Age', 'GP', 'MPG', 'PPG', 'RPG'];
    if (showReboundBreakdown) columns.addAll(['OREB', 'DREB']);
    columns.addAll(['APG', 'SPG', 'BPG', 'TOV', 'PF', 'FGM', 'FG%', '3PM', '3P%', 'FTM', 'FT%', '+/-']);
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader('Player statistics', '${rows.length} matching rows • $basis • columns mirror the requested NBA.com/stats-style default.'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowColor: WidgetStateProperty.all(_soft),
            columns: [for (final column in columns) DataColumn(label: Text(column, style: const TextStyle(color: _muted, fontWeight: FontWeight.w900)))],
            rows: [for (final row in rows) DataRow(cells: _cellsFor(row, showReboundBreakdown))],
          ),
        ),
      ]),
    );
  }

  List<DataCell> _cellsFor(Map<String, dynamic> row, bool showBreakdown) {
    final cells = <String>[
      _txt(row['player_label']),
      _txt(row['team_ids']),
      _number(row['age'], decimals: 0),
      _number(row['games'], decimals: 0),
      _perGame(row, 'minutes', 'minutes_per_game'),
      _perGame(row, 'points', 'points_per_game'),
      _perGame(row, 'rebounds', 'rebounds_per_game'),
    ];
    if (showBreakdown) cells.addAll([_perGame(row, 'offensive_rebounds', 'offensive_rebounds_per_game'), _perGame(row, 'defensive_rebounds', 'defensive_rebounds_per_game')]);
    cells.addAll([
      _perGame(row, 'assists', 'assists_per_game'),
      _perGame(row, 'steals', 'steals_per_game'),
      _perGame(row, 'blocks', 'blocks_per_game'),
      _perGame(row, 'turnovers', 'turnovers_per_game'),
      _perGame(row, 'personal_fouls', 'personal_fouls_per_game'),
      _perGame(row, 'field_goals', 'field_goals_per_game'),
      _pct(row, const ['fg_pct', 'field_goal_pct', 'avg_fg_pct']),
      _perGame(row, 'three_pointers', 'three_pointers_per_game'),
      _pct(row, const ['three_point_pct', 'fg3_pct', 'avg_fg3_pct']),
      _perGame(row, 'free_throws', 'free_throws_per_game'),
      _pct(row, const ['free_throw_pct', 'ft_pct', 'avg_ft_pct']),
      _perGame(row, 'plus_minus', 'plus_minus_per_game'),
    ]);
    return [for (final cell in cells) DataCell(Text(cell, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)))];
  }
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({required this.query, required this.seasonType, required this.basis});
  final String query;
  final String seasonType;
  final String basis;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          _InfoChip(Icons.dataset_rounded, 'Source', 'Generated 2024-25 NBA seed assets'),
          _InfoChip(Icons.filter_alt_rounded, 'Season type', seasonType),
          _InfoChip(Icons.calculate_rounded, 'Basis', basis),
          _InfoChip(Icons.terminal_rounded, 'Query', query.isEmpty ? 'none' : query),
          const _InfoChip(Icons.info_outline_rounded, 'Method', 'Local prototype; missing columns display as em dashes until expanded data feeds arrive'),
        ]),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _soft, border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: _blue, size: 18), const SizedBox(width: 8), Text('$label: ', style: const TextStyle(color: _muted, fontWeight: FontWeight.w900, fontSize: 12)), Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 12))]),
      );
}

class _Drop extends StatelessWidget {
  const _Drop({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line))),
          items: [for (final option in values) DropdownMenuItem(value: option, child: Text(option, style: const TextStyle(fontWeight: FontWeight.w800)))],
          onChanged: onChanged,
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600))]);
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.26))), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)));
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 22, offset: Offset(0, 10))]), child: child);
}

List<Map<String, dynamic>> _filteredRows(List<Map<String, dynamic>> rows, String rawQuery) {
  final query = rawQuery.toLowerCase().trim();
  if (query.isEmpty) return List<Map<String, dynamic>>.from(rows);
  return rows.where((row) {
    final haystack = '${_txt(row['player_label'])} ${_txt(row['team_ids'])}'.toLowerCase();
    if (haystack.contains(query)) return true;
    final ppg = _perGameNum(row, 'points', 'points_per_game');
    final rpg = _perGameNum(row, 'rebounds', 'rebounds_per_game');
    final fg = _pctNum(row, const ['fg_pct', 'field_goal_pct', 'avg_fg_pct']);
    final age = _maybe(row['age']);
    if (query.contains('ppg') && query.contains('15') && !(ppg > 15)) return false;
    if (query.contains('rpg') && query.contains('4') && !(rpg < 4)) return false;
    if (query.contains('fg') && query.contains('50') && fg != null && !(fg > 0.50 || fg > 50)) return false;
    if (query.contains('age') && (query.contains('29') || query.contains('over 29')) && age != null && !(age > 29)) return false;
    return query.split(' ').where((token) => token.length > 2).any((token) => haystack.contains(token)) || query.contains('ppg') || query.contains('rpg') || query.contains('fg');
  }).toList();
}

String _txt(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

double? _maybe(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value.toString().replaceAll('%', '').replaceAll(',', ''));
  return parsed;
}

String _number(Object? value, {int decimals = 1}) {
  final n = _maybe(value);
  if (n == null) return '—';
  return decimals == 0 ? n.round().toString() : n.toStringAsFixed(decimals);
}

double _perGameNum(Map<String, dynamic> row, String totalKey, String perKey) {
  final direct = _maybe(row[perKey]);
  if (direct != null) return direct;
  final total = _maybe(row[totalKey]);
  final games = _maybe(row['games']);
  if (total != null && games != null && games > 0) return total / games;
  return 0;
}

String _perGame(Map<String, dynamic> row, String totalKey, String perKey) {
  final direct = _maybe(row[perKey]);
  if (direct != null) return direct.toStringAsFixed(1);
  final total = _maybe(row[totalKey]);
  final games = _maybe(row['games']);
  if (total != null && games != null && games > 0) return (total / games).toStringAsFixed(1);
  return '—';
}

double? _pctNum(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _maybe(row[key]);
    if (value != null) return value;
  }
  return null;
}

String _pct(Map<String, dynamic> row, List<String> keys) {
  final value = _pctNum(row, keys);
  if (value == null) return '—';
  final normalized = value <= 1 ? value * 100 : value;
  return '${normalized.toStringAsFixed(1)}%';
}
