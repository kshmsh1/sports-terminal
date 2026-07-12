import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);

class ProductTradeMachineScreen extends StatefulWidget {
  const ProductTradeMachineScreen({super.key});

  @override
  State<ProductTradeMachineScreen> createState() => _ProductTradeMachineScreenState();
}

class _ProductTradeMachineScreenState extends State<ProductTradeMachineScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  String operatingYear = '2026-27';
  List<String> selectedTeams = ['BOS', 'PHI'];
  Map<String, String> playerDestinations = {};
  Map<String, String> assetTabs = {};

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final saved = await localStore.loadStringMap(ProductLocalStore.tradeMachineStateKey);
    if (!mounted || saved.isEmpty) return;
    setState(() {
      operatingYear = saved['year'] ?? operatingYear;
      selectedTeams = (saved['teams'] ?? '').split('|').where((team) => team.isNotEmpty).toList();
      if (selectedTeams.isEmpty) selectedTeams = ['BOS', 'PHI'];
    });
  }

  Future<void> _saveState() async {
    await localStore.saveStringMap(ProductLocalStore.tradeMachineStateKey, {'year': operatingYear, 'teams': selectedTeams.join('|')});
  }

  Future<void> _addTeam(String team) async {
    if (selectedTeams.contains(team)) return;
    setState(() => selectedTeams = [...selectedTeams, team]);
    await _saveState();
  }

  Future<void> _removeTeam(String team) async {
    if (selectedTeams.length <= 1) return;
    setState(() {
      selectedTeams = selectedTeams.where((item) => item != team).toList();
      playerDestinations.removeWhere((playerId, destination) => destination == team);
    });
    await _saveState();
  }

  void _sendPlayer(String playerId, String? destination) {
    setState(() {
      if (destination == null || destination.isEmpty) {
        playerDestinations.remove(playerId);
      } else {
        playerDestinations[playerId] = destination;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Surface(child: Text('Loading trade machine...', style: TextStyle(color: _muted)));
        if (snapshot.hasError) return _Surface(child: Text('Trade machine data unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        final data = snapshot.data!;
        final allTeams = _teamIds(data);
        for (final fallback in const ['BOS', 'PHI']) {
          if (!selectedTeams.contains(fallback) && allTeams.contains(fallback) && selectedTeams.length < 2) selectedTeams.add(fallback);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroBand(year: operatingYear, teamCount: selectedTeams.length),
          const SizedBox(height: 18),
          _TeamSelectionPanel(
            allTeams: allTeams,
            selectedTeams: selectedTeams,
            operatingYear: operatingYear,
            onYearChanged: (value) async {
              setState(() => operatingYear = value ?? operatingYear);
              await _saveState();
            },
            onAdd: _addTeam,
            onRemove: _removeTeam,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 1100;
            final boards = [
              for (final team in selectedTeams)
                _TeamTradeBoard(
                  team: team,
                  data: data,
                  selectedTeams: selectedTeams,
                  activeTab: assetTabs[team] ?? 'Active Roster',
                  playerDestinations: playerDestinations,
                  onTabChanged: (value) => setState(() => assetTabs[team] = value),
                  onSendPlayer: _sendPlayer,
                ),
            ];
            if (compact) return Column(children: [for (final board in boards) ...[board, const SizedBox(height: 18)]]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final board in boards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 14), child: board))]);
          }),
          const SizedBox(height: 18),
          _TradeResults(data: data, selectedTeams: selectedTeams, playerDestinations: playerDestinations),
          const SizedBox(height: 18),
          const _RoadmapPanel(),
        ]);
      },
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.year, required this.teamCount});
  final String year;
  final int teamCount;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(colors: [_navy, _blue, _orange]), boxShadow: const [BoxShadow(color: Color(0x24071A33), blurRadius: 32, offset: Offset(0, 16))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NBA TRADE MACHINE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
          const SizedBox(height: 12),
          const Text('Build multi-team trade scenarios with roster, pick, cash, and exception slots.', style: TextStyle(color: Colors.white, fontSize: 39, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          const SizedBox(width: 900, child: Text('This is the Sports Terminal version of the trade-machine workflow: unlimited-team structure, active roster rows, draft pick/free-agent/cash/exception tabs, cap/apron/tax summary cards, and transparent placeholders where live contract/CBA feeds still need to be integrated.', style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [_GlassChip(year), _GlassChip('$teamCount TEAMS'), const _GlassChip('ROSTERS'), const _GlassChip('DRAFT PICKS'), const _GlassChip('TPE / MLE / NTMLE / TMLE'), const _GlassChip('CAP + APRON TRACKERS')]),
        ]),
      );
}

class _TeamSelectionPanel extends StatelessWidget {
  const _TeamSelectionPanel({required this.allTeams, required this.selectedTeams, required this.operatingYear, required this.onYearChanged, required this.onAdd, required this.onRemove});
  final List<String> allTeams;
  final List<String> selectedTeams;
  final String operatingYear;
  final ValueChanged<String?> onYearChanged;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionHeader('Select operating year and teams', 'Built around the 2026 offseason workflow, with local generated rosters used as the current prototype data source.'),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: operatingYear,
                decoration: InputDecoration(labelText: 'Operating year', filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line))),
                items: [for (final year in const ['2024-25', '2025-26', '2026-27', '2027-28']) DropdownMenuItem(value: year, child: Text(year, style: const TextStyle(fontWeight: FontWeight.w900)))],
                onChanged: onYearChanged,
              ),
            ),
            for (final team in selectedTeams)
              InputChip(label: Text(team, style: const TextStyle(fontWeight: FontWeight.w900)), selected: true, selectedColor: const Color(0xFFEFF6FF), onDeleted: selectedTeams.length <= 1 ? null : () => onRemove(team)),
          ]),
          const SizedBox(height: 18),
          _ConferenceGrid(allTeams: allTeams, selectedTeams: selectedTeams, onAdd: onAdd),
        ]),
      );
}

class _ConferenceGrid extends StatelessWidget {
  const _ConferenceGrid({required this.allTeams, required this.selectedTeams, required this.onAdd});
  final List<String> allTeams;
  final List<String> selectedTeams;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final east = _conferenceTeams(true, allTeams);
    final west = _conferenceTeams(false, allTeams);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _MiniHeader('Eastern Conference'),
      _TeamButtonGrid(teams: east, selectedTeams: selectedTeams, onAdd: onAdd),
      const SizedBox(height: 18),
      const _MiniHeader('Western Conference'),
      _TeamButtonGrid(teams: west, selectedTeams: selectedTeams, onAdd: onAdd),
    ]);
  }
}

class _TeamButtonGrid extends StatelessWidget {
  const _TeamButtonGrid({required this.teams, required this.selectedTeams, required this.onAdd});
  final List<String> teams;
  final List<String> selectedTeams;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 760 ? constraints.maxWidth : (constraints.maxWidth - 36) / 4;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final team in teams)
            SizedBox(
              width: width,
              child: OutlinedButton.icon(
                onPressed: selectedTeams.contains(team) ? null : () => onAdd(team),
                icon: Icon(selectedTeams.contains(team) ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, size: 18),
                label: Align(alignment: Alignment.centerLeft, child: Text(team, style: const TextStyle(fontWeight: FontWeight.w900))),
              ),
            ),
        ]);
      });
}

class _TeamTradeBoard extends StatelessWidget {
  const _TeamTradeBoard({required this.team, required this.data, required this.selectedTeams, required this.activeTab, required this.playerDestinations, required this.onTabChanged, required this.onSendPlayer});
  final String team;
  final NbaTerminalSeedSnapshot data;
  final List<String> selectedTeams;
  final String activeTab;
  final Map<String, String> playerDestinations;
  final ValueChanged<String> onTabChanged;
  final void Function(String playerId, String? destination) onSendPlayer;

  @override
  Widget build(BuildContext context) {
    final roster = _roster(data, team).take(15).toList();
    final salary = roster.fold<double>(0, (sum, row) => sum + _salary(row));
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(backgroundColor: const Color(0xFFEFF6FF), child: Text(team, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 11))), const SizedBox(width: 10), Expanded(child: Text('$team trade board', style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 14),
        _CapCards(teamSalary: salary),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tab in const ['Active Roster', 'Draft Picks', 'Draft Rights', 'Cash', 'Free Agents', 'Exceptions'])
            ChoiceChip(label: Text(tab, style: const TextStyle(fontWeight: FontWeight.w900)), selected: activeTab == tab, selectedColor: _navy, labelStyle: TextStyle(color: activeTab == tab ? Colors.white : _ink), onSelected: (_) => onTabChanged(tab)),
        ]),
        const SizedBox(height: 12),
        if (activeTab == 'Active Roster')
          _RosterAssetList(team: team, roster: roster, selectedTeams: selectedTeams, playerDestinations: playerDestinations, onSendPlayer: onSendPlayer)
        else if (activeTab == 'Draft Picks')
          _PlaceholderAssets(title: 'Draft picks', items: _pickAssets(team))
        else if (activeTab == 'Draft Rights')
          _PlaceholderAssets(title: 'Draft rights', items: const ['International draft-rights slot', 'Unsigned second-round rights slot', 'Two-way conversion rights slot'])
        else if (activeTab == 'Cash')
          const _PlaceholderAssets(title: 'Cash considerations', items: ['Outgoing cash slot', 'Incoming cash slot', 'Multi-year cash tracker slot'])
        else if (activeTab == 'Free Agents')
          const _PlaceholderAssets(title: 'Free-agent renunciation', items: ['Cap hold slot', 'Renounce rights slot', 'Bird-rights tracker slot'])
        else
          const _PlaceholderAssets(title: 'Exceptions', items: ['Trade Exception (TPE)', 'Mid-Level Exception (MLE)', 'Non-Taxpayer MLE (NTMLE)', 'Taxpayer MLE (TMLE)', 'Bi-Annual Exception slot']),
      ]),
    );
  }
}

class _RosterAssetList extends StatelessWidget {
  const _RosterAssetList({required this.team, required this.roster, required this.selectedTeams, required this.playerDestinations, required this.onSendPlayer});
  final String team;
  final List<Map<String, dynamic>> roster;
  final List<String> selectedTeams;
  final Map<String, String> playerDestinations;
  final void Function(String playerId, String? destination) onSendPlayer;

  @override
  Widget build(BuildContext context) {
    final destinations = selectedTeams.where((item) => item != team).toList();
    return Column(children: [
      for (final row in roster)
        _PlayerAssetRow(row: row, destinations: destinations, destination: destinations.contains(playerDestinations[_txt(row['player_id'])]) ? playerDestinations[_txt(row['player_id'])] : null, onChanged: (value) => onSendPlayer(_txt(row['player_id']), value)),
    ]);
  }
}

class _PlayerAssetRow extends StatelessWidget {
  const _PlayerAssetRow({required this.row, required this.destinations, required this.destination, required this.onChanged});
  final Map<String, dynamic> row;
  final List<String> destinations;
  final String? destination;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_txt(row['player_label']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${_d(_perGame(row, 'points', 'points_per_game'))} PPG • ${_d(_perGame(row, 'minutes', 'minutes_per_game'))} MPG • ${_d(row['avg_bpm'])} BPM', style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 10),
          Text(_money(_salary(row)), style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              value: destination,
              hint: const Text('Send to...'),
              decoration: InputDecoration(isDense: true, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line))),
              items: [for (final team in destinations) DropdownMenuItem(value: team, child: Text(team))],
              onChanged: destinations.isEmpty ? null : onChanged,
            ),
          ),
        ]),
      );
}

class _TradeResults extends StatelessWidget {
  const _TradeResults({required this.data, required this.selectedTeams, required this.playerDestinations});
  final NbaTerminalSeedSnapshot data;
  final List<String> selectedTeams;
  final Map<String, String> playerDestinations;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader('Trade results', 'Real salary matching and CBA validation require current contract data. This prototype computes salary proxy flow and labels the future financial breakdown structure.'),
        const SizedBox(height: 14),
        for (final team in selectedTeams) _TeamResult(team: team, incoming: _incoming(team), outgoing: _outgoing(team)),
      ]),
    );
  }

  List<Map<String, dynamic>> _incoming(String team) {
    final rows = <Map<String, dynamic>>[];
    for (final entry in playerDestinations.entries) {
      if (entry.value == team) {
        final player = _findPlayer(data, entry.key);
        if (player.isNotEmpty) rows.add(player);
      }
    }
    return rows;
  }

  List<Map<String, dynamic>> _outgoing(String team) {
    final roster = _roster(data, team);
    return roster.where((row) => playerDestinations.containsKey(_txt(row['player_id']))).toList();
  }
}

class _TeamResult extends StatelessWidget {
  const _TeamResult({required this.team, required this.incoming, required this.outgoing});
  final String team;
  final List<Map<String, dynamic>> incoming;
  final List<Map<String, dynamic>> outgoing;

  @override
  Widget build(BuildContext context) {
    final incomingSalary = incoming.fold<double>(0, (sum, row) => sum + _salary(row));
    final outgoingSalary = outgoing.fold<double>(0, (sum, row) => sum + _salary(row));
    final diff = incomingSalary - outgoingSalary;
    final pass = incoming.isEmpty && outgoing.isEmpty ? false : diff.abs() < 20000000;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: pass ? const Color(0xFFEAFBF2) : _soft, border: Border.all(color: pass ? const Color(0xFFB9F2CF) : _line), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text('$team acquires', style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)), const Spacer(), Text(pass ? 'Prototype pass' : 'Needs review', style: TextStyle(color: pass ? _green : _orange, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 10),
        if (incoming.isEmpty) const Text('No incoming players selected yet.', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        for (final row in incoming) _MiniAsset(title: _txt(row['player_label']), detail: _money(_salary(row))),
        const SizedBox(height: 10),
        _FinancialBreakdown(outgoing: outgoingSalary, incoming: incomingSalary, difference: diff),
      ]),
    );
  }
}

class _FinancialBreakdown extends StatelessWidget {
  const _FinancialBreakdown({required this.outgoing, required this.incoming, required this.difference});
  final double outgoing;
  final double incoming;
  final double difference;

  @override
  Widget build(BuildContext context) => Column(children: [
        _KeyValue('Outgoing cap proxy', _money(outgoing)),
        _KeyValue('Incoming cap proxy', _money(incoming)),
        _KeyValue('Cap difference', _money(difference)),
        _KeyValue('Allowable incoming slot', 'CBA engine pending'),
      ]);
}

class _CapCards extends StatelessWidget {
  const _CapCards({required this.teamSalary});
  final double teamSalary;

  @override
  Widget build(BuildContext context) {
    const cap = 141000000.0;
    const firstApron = 178000000.0;
    const secondApron = 189000000.0;
    const tax = 171000000.0;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _CapCard('Cap Space', cap - teamSalary),
      _CapCard('1st Apron Space', firstApron - teamSalary),
      _CapCard('2nd Apron Space', secondApron - teamSalary),
      _CapCard('Tax Space', tax - teamSalary),
    ]);
  }
}

class _CapCard extends StatelessWidget {
  const _CapCard(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
        width: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: value >= 0 ? const Color(0xFFEAFBF2) : const Color(0xFFFFEFEF), border: Border.all(color: value >= 0 ? const Color(0xFFB9F2CF) : const Color(0xFFFFC6C6)), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(_money(value), style: TextStyle(color: value >= 0 ? _green : _red, fontWeight: FontWeight.w900))]),
      );
}

class _PlaceholderAssets extends StatelessWidget {
  const _PlaceholderAssets({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        for (final item in items) _MiniAsset(title: item, detail: 'Future data slot'),
      ]);
}

class _RoadmapPanel extends StatelessWidget {
  const _RoadmapPanel();

  @override
  Widget build(BuildContext context) => const _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionHeader('Trade machine buildout', 'What needs to be layered in as real cap/contract data becomes available.'),
          SizedBox(height: 12),
          _ChecklistItem('Active roster, draft picks, draft rights, cash, free agents, TPEs, MLEs, NTMLEs, TMLEs, hard-cap triggers, aggregation rules, and trade restrictions.'),
          _ChecklistItem('Team salary cap tracker, apron tracker, tax tracker, multi-year cap/cash/AAV/cap-hit views, and player contract cards.'),
          _ChecklistItem('Unlimited-team trades, pick protections, exception usage, free-agent renunciation, scenario save/share, fan vote, and workspace export.'),
        ]),
      );
}

class _MiniHeader extends StatelessWidget {
  const _MiniHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w900)));
}

class _MiniAsset extends StatelessWidget {
  const _MiniAsset({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800))), Text(detail, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))]));
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))), Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900))]));
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_rounded, color: _green, size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700)))]));
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

List<String> _teamIds(NbaTerminalSeedSnapshot data) {
  final teams = data.teamRecords.map((row) => _txt(row['team_id'])).where((team) => team != '—').toSet().toList()..sort();
  return teams;
}

List<String> _conferenceTeams(bool east, List<String> allTeams) {
  final preferred = east
      ? const ['ATL', 'BOS', 'BKN', 'BRK', 'CHA', 'CHO', 'CHI', 'CLE', 'DET', 'IND', 'MIA', 'MIL', 'NYK', 'ORL', 'PHI', 'TOR', 'WAS']
      : const ['DAL', 'DEN', 'GSW', 'HOU', 'LAC', 'LAL', 'MEM', 'MIN', 'NOP', 'OKC', 'PHO', 'PHX', 'POR', 'SAC', 'SAS', 'UTA'];
  final set = allTeams.toSet();
  final rows = preferred.where(set.contains).toList();
  if (rows.isEmpty) return allTeams;
  return rows;
}

List<Map<String, dynamic>> _roster(NbaTerminalSeedSnapshot data, String team) {
  final rows = data.playerSeasonTotals.where((row) => _txt(row['team_ids']).contains(team)).toList();
  rows.sort((a, b) => _salary(b).compareTo(_salary(a)));
  return rows;
}

Map<String, dynamic> _findPlayer(NbaTerminalSeedSnapshot data, String playerId) {
  for (final row in data.playerSeasonTotals) {
    if (_txt(row['player_id']) == playerId) return row;
  }
  return <String, dynamic>{};
}

List<String> _pickAssets(String team) => ['$team 2027 1st round pick', '$team 2028 2nd round pick', '$team 2029 1st round swap slot', '$team 2030 2nd round pick'];

double _salary(Map<String, dynamic> row) {
  final ppg = _perGame(row, 'points', 'points_per_game');
  final mpg = _perGame(row, 'minutes', 'minutes_per_game');
  final bpm = _num(row['avg_bpm']);
  final raw = 2100000 + (ppg * 1200000) + (mpg * 220000) + (bpm > 0 ? bpm * 900000 : 0);
  return raw < 2100000 ? 2100000 : raw;
}

double _perGame(Map<String, dynamic> row, String totalKey, String perKey) {
  final direct = _num(row[perKey]);
  if (direct > 0) return direct;
  final games = _num(row['games']);
  final total = _num(row[totalKey]);
  return games > 0 ? total / games : 0;
}

double _num(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '').replaceAll('%', '')) ?? 0;
}

String _txt(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _d(Object? value) => _num(value).toStringAsFixed(1);

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < amount.length; i++) {
    if (i > 0 && (amount.length - i) % 3 == 0) buffer.write(',');
    buffer.write(amount[i]);
  }
  return '$sign\$${buffer.toString()}';
}
