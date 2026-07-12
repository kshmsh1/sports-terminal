import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);

class ProductAdvancedNbaToolsScreen extends StatefulWidget {
  const ProductAdvancedNbaToolsScreen({super.key});

  @override
  State<ProductAdvancedNbaToolsScreen> createState() => _ProductAdvancedNbaToolsScreenState();
}

class _ProductAdvancedNbaToolsScreenState extends State<ProductAdvancedNbaToolsScreen> {
  String mode = 'Player Dashboard';
  String basis = 'Per Game';
  int gamesBack = 10;
  String selectedTeam = 'BOS';
  String? playerA;
  String? playerB;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Surface(child: Text('Loading advanced NBA tools...', style: TextStyle(color: _muted)));
        if (snapshot.hasError) return _Surface(child: Text('Advanced tools unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        final data = snapshot.data!;
        final players = List<Map<String, dynamic>>.from(data.playerSeasonTotals)..sort((a, b) => _num(b['points_per_game']).compareTo(_num(a['points_per_game'])));
        final teams = data.teamRecords.map((row) => _txt(row['team_id'])).where((team) => team != '—').toList()..sort();
        selectedTeam = teams.contains(selectedTeam) ? selectedTeam : (teams.isEmpty ? selectedTeam : teams.first);
        playerA ??= players.isEmpty ? null : _txt(players.first['player_id']);
        playerB ??= players.length < 2 ? playerA : _txt(players[1]['player_id']);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _HeroBand(),
          const SizedBox(height: 18),
          _ModeBar(mode: mode, onChanged: (value) => setState(() => mode = value)),
          const SizedBox(height: 18),
          if (mode == 'Player Dashboard') _PlayerDashboard(data: data, players: players, playerId: playerA, basis: basis, gamesBack: gamesBack, onPlayerChanged: (value) => setState(() => playerA = value), onBasisChanged: (value) => setState(() => basis = value ?? basis), onGamesBackChanged: (value) => setState(() => gamesBack = value ?? gamesBack))
          else if (mode == 'Lineups') _LineupBuilder(data: data, team: selectedTeam, teams: teams, onTeamChanged: (value) => setState(() => selectedTeam = value ?? selectedTeam))
          else if (mode == 'Comparisons') _ComparisonTool(players: players, playerA: playerA, playerB: playerB, onPlayerA: (value) => setState(() => playerA = value), onPlayerB: (value) => setState(() => playerB = value))
          else if (mode == 'Tier Lists') _TierListTool(players: players)
          else _MatchupTool(players: players, playerA: playerA, playerB: playerB, onPlayerA: (value) => setState(() => playerA = value), onPlayerB: (value) => setState(() => playerB = value)),
        ]);
      },
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(colors: [_navy, _blue, _orange]), boxShadow: const [BoxShadow(color: Color(0x24071A33), blurRadius: 32, offset: Offset(0, 16))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('ADVANCED NBA TOOLS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
          SizedBox(height: 12),
          Text('Lineups, dashboards, comparisons, tier lists, and matchup analysis.', style: TextStyle(color: Colors.white, fontSize: 39, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          SizedBox(height: 12),
          SizedBox(width: 900, child: Text('This is the first unified surface for the advanced workflows that usually live across many sites: recent-game tracking, per-game/per-36/per-100 modes, lineup together/apart analysis, shot-profile comps, head-to-head comparisons, tier lists, and matchup-defense analysis.', style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [_GlassChip('RECENT FORM'), _GlassChip('LINEUPS'), _GlassChip('SHOT COMPS'), _GlassChip('TIER LISTS'), _GlassChip('MATCHUPS')]),
        ]),
      );
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.mode, required this.onChanged});
  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final item in const ['Player Dashboard', 'Lineups', 'Comparisons', 'Tier Lists', 'Matchups'])
            ChoiceChip(label: Text(item, style: const TextStyle(fontWeight: FontWeight.w900)), selected: mode == item, selectedColor: _navy, labelStyle: TextStyle(color: mode == item ? Colors.white : _ink), onSelected: (_) => onChanged(item)),
        ]),
      );
}

class _PlayerDashboard extends StatelessWidget {
  const _PlayerDashboard({required this.data, required this.players, required this.playerId, required this.basis, required this.gamesBack, required this.onPlayerChanged, required this.onBasisChanged, required this.onGamesBackChanged});
  final NbaTerminalSeedSnapshot data;
  final List<Map<String, dynamic>> players;
  final String? playerId;
  final String basis;
  final int gamesBack;
  final ValueChanged<String?> onPlayerChanged;
  final ValueChanged<String?> onBasisChanged;
  final ValueChanged<int?> onGamesBackChanged;

  @override
  Widget build(BuildContext context) {
    final player = players.firstWhere((row) => _txt(row['player_id']) == playerId, orElse: () => players.isEmpty ? <String, dynamic>{} : players.first);
    final gameRows = data.playerGameLogsTop.where((row) => _txt(row['player_id']) == _txt(player['player_id'])).take(gamesBack).toList();
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader('Player dashboard', 'Recent-game tracking with per-game, per-36, and per-100 possession mode slots.'),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _PlayerDrop(label: 'Player', players: players.take(80).toList(), value: playerId, onChanged: onPlayerChanged),
          _StringDrop(label: 'Basis', value: basis, values: const ['Per Game', 'Per 36', 'Per 100 Possessions'], onChanged: onBasisChanged),
          _IntDrop(label: 'Games back', value: gamesBack, values: const [5, 10, 15, 20, 30], onChanged: onGamesBackChanged),
        ]),
        const SizedBox(height: 16),
        _MetricGrid(items: [_Metric('PPG', _d(player['points_per_game']), basis), _Metric('MPG', _d(player['minutes_per_game']), 'role'), _Metric('BPM', _d(player['avg_bpm']), 'impact slot'), _Metric('Games', _txt(player['games']), 'sample')]),
        const SizedBox(height: 14),
        _MiniTable(title: 'Recent game rows', headers: const ['Game', 'Team', 'PTS', 'REB', 'AST', '+/-'], rows: [for (final row in gameRows) [_txt(row['game_id']), _txt(row['team_id']), _d(row['pts']), _d(row['trb']), _d(row['ast']), _d(row['plus_minus'])]]),
      ]),
    );
  }
}

class _LineupBuilder extends StatelessWidget {
  const _LineupBuilder({required this.data, required this.team, required this.teams, required this.onTeamChanged});
  final NbaTerminalSeedSnapshot data;
  final String team;
  final List<String> teams;
  final ValueChanged<String?> onTeamChanged;

  @override
  Widget build(BuildContext context) {
    final roster = data.playerSeasonTotals.where((row) => _txt(row['team_ids']).contains(team)).toList()..sort((a, b) => _num(b['minutes_per_game']).compareTo(_num(a['minutes_per_game'])));
    final lineup = roster.take(5).toList();
    final points = lineup.fold<double>(0, (sum, row) => sum + _num(row['points_per_game']));
    final bpm = lineup.fold<double>(0, (sum, row) => sum + _num(row['avg_bpm']));
    return _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('Lineup builder', 'Analyze how players perform together and apart. Current version uses transparent lineup proxy stats until full possession/on-off data is surfaced.'),
      const SizedBox(height: 14),
      _StringDrop(label: 'Team', value: team, values: teams, onChanged: onTeamChanged),
      const SizedBox(height: 16),
      _MetricGrid(items: [_Metric('Lineup PPG sum', _d(points), 'scoring proxy'), _Metric('BPM sum', _d(bpm), 'impact proxy'), _Metric('Together/apart', 'Slot', 'PBP/WOWY needed'), _Metric('Possessions', 'Slot', 'lineup stints needed')]),
      const SizedBox(height: 14),
      _MiniTable(title: '$team projected lineup', headers: const ['Player', 'PPG', 'MPG', 'BPM'], rows: [for (final row in lineup) [_txt(row['player_label']), _d(row['points_per_game']), _d(row['minutes_per_game']), _d(row['avg_bpm'])]]),
    ]));
  }
}

class _ComparisonTool extends StatelessWidget {
  const _ComparisonTool({required this.players, required this.playerA, required this.playerB, required this.onPlayerA, required this.onPlayerB});
  final List<Map<String, dynamic>> players;
  final String? playerA;
  final String? playerB;
  final ValueChanged<String?> onPlayerA;
  final ValueChanged<String?> onPlayerB;

  @override
  Widget build(BuildContext context) {
    final a = _find(players, playerA);
    final b = _find(players, playerB);
    return _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('Head-to-head player comparison', 'Overall, offense, defense, and shot-profile comparison slots.'),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 12, children: [_PlayerDrop(label: 'Player A', players: players.take(80).toList(), value: playerA, onChanged: onPlayerA), _PlayerDrop(label: 'Player B', players: players.take(80).toList(), value: playerB, onChanged: onPlayerB)]),
      const SizedBox(height: 16),
      _MiniTable(title: 'Comparison', headers: const ['Metric', 'Player A', 'Player B'], rows: [
        ['Name', _txt(a['player_label']), _txt(b['player_label'])],
        ['PPG', _d(a['points_per_game']), _d(b['points_per_game'])],
        ['RPG', _d(_num(a['rebounds']) / (_num(a['games']) == 0 ? 1 : _num(a['games']))), _d(_num(b['rebounds']) / (_num(b['games']) == 0 ? 1 : _num(b['games'])))],
        ['APG', _d(_num(a['assists']) / (_num(a['games']) == 0 ? 1 : _num(a['games']))), _d(_num(b['assists']) / (_num(b['games']) == 0 ? 1 : _num(b['games'])))],
        ['BPM', _d(a['avg_bpm']), _d(b['avg_bpm'])],
        ['Shot profile', 'Rim/mid/3 slot', 'Rim/mid/3 slot'],
        ['Defense', 'Matchup slot', 'Matchup slot'],
      ]),
    ]));
  }
}

class _TierListTool extends StatelessWidget {
  const _TierListTool({required this.players});
  final List<Map<String, dynamic>> players;

  @override
  Widget build(BuildContext context) {
    final superstar = players.where((row) => _num(row['points_per_game']) >= 25).take(12).toList();
    final allStar = players.where((row) => _num(row['points_per_game']) >= 18 && _num(row['points_per_game']) < 25).take(12).toList();
    final starter = players.where((row) => _num(row['minutes_per_game']) >= 24 && _num(row['points_per_game']) < 18).take(12).toList();
    return _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('NBA tier lists', 'Create shareable tiers from transparent stat rules first; later make this drag-and-drop with community voting.'),
      const SizedBox(height: 14),
      _Tier('Superstar scoring tier', superstar),
      _Tier('All-Star production tier', allStar),
      _Tier('Starter / rotation tier', starter),
    ]));
  }
}

class _MatchupTool extends StatelessWidget {
  const _MatchupTool({required this.players, required this.playerA, required this.playerB, required this.onPlayerA, required this.onPlayerB});
  final List<Map<String, dynamic>> players;
  final String? playerA;
  final String? playerB;
  final ValueChanged<String?> onPlayerA;
  final ValueChanged<String?> onPlayerB;

  @override
  Widget build(BuildContext context) {
    final a = _find(players, playerA);
    final b = _find(players, playerB);
    return _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('Player matchup analysis', 'Defenders faced, players guarded, and possession-result stats need tracking data. This screen defines the product shape.'),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 12, children: [_PlayerDrop(label: 'Offensive player', players: players.take(80).toList(), value: playerA, onChanged: onPlayerA), _PlayerDrop(label: 'Defender', players: players.take(80).toList(), value: playerB, onChanged: onPlayerB)]),
      const SizedBox(height: 16),
      _MetricGrid(items: [_Metric('Offense', _txt(a['player_label']), '${_d(a['points_per_game'])} PPG'), _Metric('Defense', _txt(b['player_label']), '${_d(b['avg_bpm'])} BPM slot'), const _Metric('Possessions', 'Slot', 'tracking feed required'), const _Metric('Result stats', 'Slot', 'FG%, TO%, FTs')]),
      const SizedBox(height: 14),
      const _InfoStrip('Future matchup module: defender assignments, possession outcomes, shot quality, help defense, switches, screens, and playoff/regular-season splits.'),
    ]));
  }
}

class _Tier extends StatelessWidget {
  const _Tier(this.title, this.players);
  final String title;
  final List<Map<String, dynamic>> players;

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [for (final row in players) Chip(label: Text(_txt(row['player_label']), style: const TextStyle(fontWeight: FontWeight.w800)))])]));
}

class _PlayerDrop extends StatelessWidget {
  const _PlayerDrop({required this.label, required this.players, required this.value, required this.onChanged});
  final String label;
  final List<Map<String, dynamic>> players;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(width: 290, child: DropdownButtonFormField<String>(value: players.any((row) => _txt(row['player_id']) == value) ? value : null, decoration: InputDecoration(labelText: label, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line))), items: [for (final row in players) DropdownMenuItem(value: _txt(row['player_id']), child: Text(_txt(row['player_label']), overflow: TextOverflow.ellipsis))], onChanged: onChanged));
}

class _StringDrop extends StatelessWidget {
  const _StringDrop({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(width: 240, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : null, decoration: InputDecoration(labelText: label, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line))), items: [for (final option in values) DropdownMenuItem(value: option, child: Text(option, style: const TextStyle(fontWeight: FontWeight.w800)))], onChanged: onChanged));
}

class _IntDrop extends StatelessWidget {
  const _IntDrop({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(width: 180, child: DropdownButtonFormField<int>(value: value, decoration: InputDecoration(labelText: label, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line))), items: [for (final option in values) DropdownMenuItem(value: option, child: Text('$option games', style: const TextStyle(fontWeight: FontWeight.w800)))], onChanged: onChanged));
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) { final width = constraints.maxWidth < 720 ? constraints.maxWidth : (constraints.maxWidth - 36) / 4; return Wrap(spacing: 12, runSpacing: 12, children: [for (final item in items) SizedBox(width: width, child: _MetricCard(item))]); });
}

class _MetricCard extends StatelessWidget { const _MetricCard(this.item); final _Metric item; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _soft, border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 20)), Text(item.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700))])); }
class _Metric { const _Metric(this.label, this.value, this.caption); final String label; final String value; final String caption; }

class _MiniTable extends StatelessWidget { const _MiniTable({required this.title, required this.headers, required this.rows}); final String title; final List<String> headers; final List<List<String>> rows; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 8), Container(decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)), child: Column(children: [_TableRow(cells: headers, header: true), for (final row in rows.take(16)) _TableRow(cells: row)]))]); }
class _TableRow extends StatelessWidget { const _TableRow({required this.cells, this.header = false}); final List<String> cells; final bool header; @override Widget build(BuildContext context) => Container(color: header ? _soft : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), child: Row(children: [for (final cell in cells) Expanded(child: Text(cell, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: header ? _muted : _ink, fontWeight: header ? FontWeight.w900 : FontWeight.w700, fontSize: 12)))])); }

class _InfoStrip extends StatelessWidget { const _InfoStrip(this.text); final String text; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), border: Border.all(color: const Color(0xFFFFD9B8)), borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, color: _orange, size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700)))])); }
class _SectionHeader extends StatelessWidget { const _SectionHeader(this.title, this.subtitle); final String title; final String subtitle; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600))]); }
class _GlassChip extends StatelessWidget { const _GlassChip(this.label); final String label; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.26))), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8))); }
class _Surface extends StatelessWidget { const _Surface({required this.child}); final Widget child; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 22, offset: Offset(0, 10))]), child: child); }

Map<String, dynamic> _find(List<Map<String, dynamic>> rows, String? id) => rows.firstWhere((row) => _txt(row['player_id']) == id, orElse: () => rows.isEmpty ? <String, dynamic>{} : rows.first);
String _txt(Object? value) { final text = value?.toString().trim() ?? ''; return text.isEmpty ? '—' : text; }
double _num(Object? value) { if (value == null) return 0; if (value is num) return value.toDouble(); return double.tryParse(value.toString().replaceAll(',', '').replaceAll('%', '')) ?? 0; }
String _d(Object? value) => _num(value).toStringAsFixed(1);
