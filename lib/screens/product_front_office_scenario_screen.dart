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

class ProductFrontOfficeScenarioScreen extends StatefulWidget {
  const ProductFrontOfficeScenarioScreen({super.key});

  @override
  State<ProductFrontOfficeScenarioScreen> createState() => _ProductFrontOfficeScenarioScreenState();
}

class _ProductFrontOfficeScenarioScreenState extends State<ProductFrontOfficeScenarioScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  String teamA = 'OKC';
  String teamB = 'BOS';
  String savedScenario = '';

  @override
  void initState() {
    super.initState();
    _loadScenario();
  }

  Future<void> _loadScenario() async {
    final saved = await localStore.loadStringMap(ProductLocalStore.frontOfficeScenarioKey);
    if (!mounted || saved.isEmpty) return;
    setState(() {
      teamA = saved['teamA'] ?? teamA;
      teamB = saved['teamB'] ?? teamB;
      savedScenario = saved['summary'] ?? '';
    });
  }

  Future<void> _saveScenario(String summary) async {
    setState(() => savedScenario = summary);
    await localStore.saveStringMap(ProductLocalStore.frontOfficeScenarioKey, {'teamA': teamA, 'teamB': teamB, 'summary': summary});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Surface(child: Text('Loading front-office lab...', style: TextStyle(color: _muted)));
        if (snapshot.hasError) return _Surface(child: Text('Scenario data unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        final data = snapshot.data!;
        final teams = _teamIds(data);
        if (!teams.contains(teamA)) teamA = teams.isEmpty ? teamA : teams.first;
        if (!teams.contains(teamB)) teamB = teams.length > 1 ? teams[1] : teamA;
        final rosterA = _roster(data, teamA);
        final rosterB = _roster(data, teamB);
        final outgoingA = rosterA.take(3).toList();
        final outgoingB = rosterB.take(3).toList();
        final valueA = outgoingA.fold<double>(0, (sum, row) => sum + _scenarioValue(row));
        final valueB = outgoingB.fold<double>(0, (sum, row) => sum + _scenarioValue(row));
        final summary = '$teamA sends ${outgoingA.map((row) => _txt(row['player_label'])).join(', ')} for $teamB package ${outgoingB.map((row) => _txt(row['player_label'])).join(', ')}. Value balance: ${_d(valueA)} vs ${_d(valueB)}.';

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroBand(teamA: teamA, teamB: teamB, valueA: valueA, valueB: valueB),
          const SizedBox(height: 18),
          _Surface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionHeader('Scenario controls', 'A first front-office simulator shell using the 2024-25 generated player/team data. Real salary/cap/CBA feeds come later.'),
              const SizedBox(height: 14),
              Wrap(spacing: 14, runSpacing: 14, children: [
                _TeamPicker(label: 'Team A', value: teamA, teams: teams, onChanged: (value) => setState(() => teamA = value ?? teamA)),
                _TeamPicker(label: 'Team B', value: teamB, teams: teams, onChanged: (value) => setState(() => teamB = value ?? teamB)),
                FilledButton.icon(onPressed: () => _saveScenario(summary), icon: const Icon(Icons.save_rounded), label: const Text('Save scenario locally')),
              ]),
              if (savedScenario.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoStrip(icon: Icons.bookmark_rounded, text: 'Saved scenario: $savedScenario'),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 950;
            final left = _TradePackage(team: teamA, outgoing: outgoingA, incoming: outgoingB, value: valueA, otherValue: valueB);
            final right = _TradePackage(team: teamB, outgoing: outgoingB, incoming: outgoingA, value: valueB, otherValue: valueA);
            return compact ? Column(children: [left, const SizedBox(height: 18), right]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 18), Expanded(child: right)]);
          }),
          const SizedBox(height: 18),
          _Surface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              _SectionHeader('What this becomes', 'The full version should beat cap/trade tools by combining financial legality with basketball impact and community reaction.'),
              SizedBox(height: 12),
              _ChecklistItem('Contract cards, salary matching, apron/tax status, exceptions, options, guarantees, and trade restrictions.'),
              _ChecklistItem('Rotation fit, on/off impact, lineup consequences, timeline fit, fantasy impact, and player development context.'),
              _ChecklistItem('Fan voting, realism score, team winner, comment thread, article draft, and export to workspace.'),
              _ChecklistItem('Scenario objects that can be saved, compared, shared, revised, and attached to team/player pages.'),
            ]),
          ),
        ]);
      },
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.teamA, required this.teamB, required this.valueA, required this.valueB});
  final String teamA;
  final String teamB;
  final double valueA;
  final double valueB;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(colors: [_navy, _blue, _orange]), boxShadow: const [BoxShadow(color: Color(0x24071A33), blurRadius: 32, offset: Offset(0, 16))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FRONT OFFICE LAB', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
          const SizedBox(height: 12),
          Text('$teamA ↔ $teamB scenario engine', style: const TextStyle(color: Colors.white, fontSize: 39, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          const SizedBox(width: 840, child: Text('This is the first version of the front-office simulator: not a fake cap sheet, but a product shell for trades, contracts, roster fit, fantasy impact, community reaction, and workspace export.', style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [_GlassChip('VALUE ${_d(valueA)} / ${_d(valueB)}'), const _GlassChip('CAP DATA SLOT'), const _GlassChip('ROTATION FIT'), const _GlassChip('COMMUNITY VOTE'), const _GlassChip('WORKSPACE EXPORT')]),
        ]),
      );
}

class _TradePackage extends StatelessWidget {
  const _TradePackage({required this.team, required this.outgoing, required this.incoming, required this.value, required this.otherValue});
  final String team;
  final List<Map<String, dynamic>> outgoing;
  final List<Map<String, dynamic>> incoming;
  final double value;
  final double otherValue;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: const Color(0xFFEFF6FF), child: Text(team, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 11))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$team scenario', style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(value >= otherValue ? 'Value-positive proxy package' : 'Needs more value or picks', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
            ])),
          ]),
          const SizedBox(height: 16),
          _MetricGrid(items: [
            _Metric('Outgoing value', _d(value), 'basketball proxy'),
            _Metric('Incoming value', _d(otherValue), 'basketball proxy'),
            _Metric('Balance', _d(value - otherValue), 'positive helps this side'),
          ]),
          const SizedBox(height: 14),
          _PlayerTable(title: 'Outgoing package', rows: outgoing),
          const SizedBox(height: 12),
          _PlayerTable(title: 'Incoming package', rows: incoming),
          const SizedBox(height: 12),
          _InfoStrip(icon: Icons.info_outline_rounded, text: 'Value is a transparent placeholder: PPG + 0.4×MPG + 1.5×BPM. Salary and CBA validation are intentionally marked as future data slots.'),
        ]),
      );
}

class _TeamPicker extends StatelessWidget {
  const _TeamPicker({required this.label, required this.value, required this.teams, required this.onChanged});
  final String label;
  final String value;
  final List<String> teams;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: DropdownButtonFormField<String>(
          value: teams.contains(value) ? value : (teams.isEmpty ? null : teams.first),
          decoration: InputDecoration(labelText: label, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line))),
          items: [for (final team in teams) DropdownMenuItem(value: team, child: Text(team, style: const TextStyle(fontWeight: FontWeight.w900)))],
          onChanged: onChanged,
        ),
      );
}

class _PlayerTable extends StatelessWidget {
  const _PlayerTable({required this.title, required this.rows});
  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const _TableRow(cells: ['Player', 'PPG', 'MPG', 'BPM', 'Value'], header: true),
            for (final row in rows) _TableRow(cells: [_txt(row['player_label']), _d(row['points_per_game']), _d(row['minutes_per_game']), _d(row['avg_bpm']), _d(_scenarioValue(row))]),
          ]),
        ),
      ]);
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.header = false});
  final List<String> cells;
  final bool header;

  @override
  Widget build(BuildContext context) => Container(
        color: header ? _soft : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(children: [
          for (final cell in cells)
            Expanded(flex: cell == cells.first ? 2 : 1, child: Text(cell, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: header ? _muted : _ink, fontWeight: header ? FontWeight.w900 : FontWeight.w700, fontSize: 12))),
        ]),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 720 ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final item in items) SizedBox(width: width, child: _MetricCard(item))]);
      });
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.item);
  final _Metric item;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _soft, border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.label.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(item.value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 21)),
          Text(item.caption, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), border: Border.all(color: const Color(0xFFFFD9B8)), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _orange, size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700)))]),
      );
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_rounded, color: _green, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700))),
        ]),
      );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.26))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 22, offset: Offset(0, 10))]),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600)),
      ]);
}

class _Metric {
  const _Metric(this.label, this.value, this.caption);
  final String label;
  final String value;
  final String caption;
}

List<String> _teamIds(NbaTerminalSeedSnapshot data) => data.teamRecords.map((row) => _txt(row['team_id'])).where((team) => team.isNotEmpty).toSet().toList()..sort();

List<Map<String, dynamic>> _roster(NbaTerminalSeedSnapshot data, String teamId) {
  final rows = data.playerSeasonTotals.where((row) => _txt(row['team_ids']).contains(teamId)).toList();
  rows.sort((a, b) => _scenarioValue(b).compareTo(_scenarioValue(a)));
  return rows;
}

double _scenarioValue(Map<String, dynamic> row) => _num(row['points_per_game']) + 0.4 * _num(row['minutes_per_game']) + 1.5 * _num(row['avg_bpm']);

String _txt(Object? value) => value == null ? '' : '$value';

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _d(Object? value) => _num(value).toStringAsFixed(1);
