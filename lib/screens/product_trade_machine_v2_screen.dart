import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import '../services/trade_machine_engine.dart';
import 'product_nba_entity_pages_v2.dart';

const _tmPanel = Color(0xFF0F151C);
const _tmPanel2 = Color(0xFF141C25);
const _tmLine = Color(0xFF263342);
const _tmText = Color(0xFFE8EDF3);
const _tmMuted = Color(0xFF8895A5);
const _tmBlue = Color(0xFF63A9FF);
const _tmGreen = Color(0xFF69C99A);
const _tmAmber = Color(0xFFE2B866);
const _tmRed = Color(0xFFE57D7D);

class ProductTradeMachineV2Screen extends StatefulWidget {
  const ProductTradeMachineV2Screen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  State<ProductTradeMachineV2Screen> createState() => _ProductTradeMachineV2ScreenState();
}

class _ProductTradeMachineV2ScreenState extends State<ProductTradeMachineV2Screen> {
  static const _stateKey = 'sports_terminal.trade_machine.v2.state';
  final ProductLocalStore _store = const ProductLocalStore();
  final TradeMachineEngine _engine = const TradeMachineEngine();
  final NbaStatsWorkstationEngine _stats = const NbaStatsWorkstationEngine();
  final TextEditingController _name = TextEditingController(text: 'Untitled Trade Scenario');
  final TextEditingController _notes = TextEditingController();
  String _season = '2025-26';
  List<String> _teams = const [];
  final Map<String, double> _teamSalary = {};
  final Map<String, int> _rosterCount = {};
  final List<_EditableAssignment> _assignments = [];
  bool _stepien = true;
  bool _loadingState = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final raw = await _store.loadString(_stateKey);
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final state = decoded.map((key, value) => MapEntry(key.toString(), value));
          _name.text = state['name']?.toString() ?? _name.text;
          _notes.text = state['notes']?.toString() ?? '';
          _season = state['season']?.toString() ?? _season;
          _stepien = state['stepien'] != false;
          if (state['teams'] is List) _teams = (state['teams'] as List).map((item) => item.toString()).toList();
          if (state['teamSalary'] is Map) {
            for (final entry in (state['teamSalary'] as Map).entries) {
              _teamSalary[entry.key.toString()] = _double(entry.value);
            }
          }
          if (state['rosterCount'] is Map) {
            for (final entry in (state['rosterCount'] as Map).entries) {
              _rosterCount[entry.key.toString()] = _int(entry.value);
            }
          }
          if (state['assignments'] is List) {
            for (final item in state['assignments']) {
              if (item is Map) _assignments.add(_EditableAssignment.fromJson(item.map((key, value) => MapEntry(key.toString(), value))));
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _loadingState = false);
  }

  Future<void> _persist() async {
    await _store.saveString(_stateKey, jsonEncode({
      'name': _name.text,
      'notes': _notes.text,
      'season': _season,
      'stepien': _stepien,
      'teams': _teams,
      'teamSalary': _teamSalary,
      'rosterCount': _rosterCount,
      'assignments': _assignments.map((item) => item.toJson()).toList(),
    }));
  }

  void _initializeTeams(NbaTerminalSeedSnapshot data) {
    if (_teams.length >= 2) return;
    final teamIds = _teamIds(data);
    if (teamIds.length >= 2) {
      _teams = teamIds.take(2).toList();
      for (final team in _teams) {
        _teamSalary.putIfAbsent(team, () => _discoverTeamSalary(data, team));
        _rosterCount.putIfAbsent(team, () => _discoverRosterCount(data, team));
      }
      _persist();
    }
  }

  TradeScenario _scenario(NbaTerminalSeedSnapshot data) {
    final thresholds = NbaCbaSeasonThresholds.forSeason(_season) ?? NbaCbaSeasonThresholds.seasons.values.first;
    final contexts = <String, TeamCapContext>{};
    for (final team in _teams) {
      contexts[team] = TeamCapContext(
        team: team,
        teamSalary: _teamSalary[team] ?? _discoverTeamSalary(data, team),
        salaryCap: thresholds.salaryCap,
        taxLine: thresholds.taxLine,
        firstApron: thresholds.firstApron,
        secondApron: thresholds.secondApron,
        standardRosterCount: _rosterCount[team] ?? _discoverRosterCount(data, team),
      );
    }
    return TradeScenario(
      id: 'trade-v2-local',
      name: _name.text.trim().isEmpty ? 'Untitled Trade Scenario' : _name.text.trim(),
      operatingSeason: _season,
      teams: _teams,
      capContexts: contexts,
      assignments: [
        for (final item in _assignments)
          TradeAssignment(asset: item.toAsset(), destinationTeam: item.destinationTeam),
      ],
      asOfDate: DateTime.now(),
      enforceStepien: _stepien,
    );
  }

  Future<void> _setTeam(int index, String team, NbaTerminalSeedSnapshot data) async {
    if (_teams.contains(team) && _teams[index] != team) {
      _toast('$team is already in this scenario.');
      return;
    }
    final previous = _teams[index];
    setState(() {
      _teams[index] = team;
      _teamSalary.putIfAbsent(team, () => _discoverTeamSalary(data, team));
      _rosterCount.putIfAbsent(team, () => _discoverRosterCount(data, team));
      _assignments.removeWhere((item) => item.originTeam == previous || item.destinationTeam == previous);
    });
    await _persist();
  }

  Future<void> _addTeam(NbaTerminalSeedSnapshot data) async {
    if (_teams.length >= 5) return;
    final available = _teamIds(data).where((team) => !_teams.contains(team)).toList();
    if (available.isEmpty) return;
    setState(() {
      _teams = [..._teams, available.first];
      _teamSalary.putIfAbsent(available.first, () => _discoverTeamSalary(data, available.first));
      _rosterCount.putIfAbsent(available.first, () => _discoverRosterCount(data, available.first));
    });
    await _persist();
  }

  Future<void> _removeTeam(String team) async {
    if (_teams.length <= 2) return;
    setState(() {
      _teams = _teams.where((item) => item != team).toList();
      _assignments.removeWhere((item) => item.originTeam == team || item.destinationTeam == team);
    });
    await _persist();
  }

  Future<void> _addPlayer(String originTeam, NbaStatsRow row, NbaTerminalSeedSnapshot data) async {
    if (_teams.length < 2) return;
    final salary = _discoverPlayerSalary(data, row.playerId, row.player);
    final destination = _teams.firstWhere((team) => team != originTeam);
    final item = _EditableAssignment(
      id: 'player:${row.playerId}:${DateTime.now().microsecondsSinceEpoch}',
      type: TradeAssetType.player,
      label: row.player,
      originTeam: originTeam,
      destinationTeam: destination,
      salary: salary,
      metadata: const {},
    );
    setState(() => _assignments.add(item));
    await _persist();
  }

  Future<void> _addManualAsset(String team) async {
    final draft = await showDialog<_ManualAssetDraft>(
      context: context,
      builder: (_) => _ManualAssetDialog(originTeam: team),
    );
    if (draft == null || _teams.length < 2) return;
    final destination = _teams.firstWhere((item) => item != team);
    setState(() {
      _assignments.add(_EditableAssignment(
        id: '${draft.type.name}:${team}:${DateTime.now().microsecondsSinceEpoch}',
        type: draft.type,
        label: draft.label,
        originTeam: team,
        destinationTeam: destination,
        salary: draft.salary,
        metadata: draft.metadata,
      ));
    });
    await _persist();
  }

  Future<void> _editAsset(_EditableAssignment item) async {
    final edited = await showDialog<_EditableAssignment>(
      context: context,
      builder: (_) => _AssetEditDialog(item: item, teams: _teams),
    );
    if (edited == null) return;
    final index = _assignments.indexOf(item);
    if (index < 0) return;
    setState(() => _assignments[index] = edited);
    await _persist();
  }

  Future<void> _removeAsset(_EditableAssignment item) async {
    setState(() => _assignments.remove(item));
    await _persist();
  }

  Future<void> _reset(NbaTerminalSeedSnapshot data) async {
    final ids = _teamIds(data);
    setState(() {
      _name.text = 'Untitled Trade Scenario';
      _notes.clear();
      _season = '2025-26';
      _stepien = true;
      _assignments.clear();
      _teams = ids.take(math.min(2, ids.length)).toList();
      _teamSalary.clear();
      _rosterCount.clear();
      for (final team in _teams) {
        _teamSalary[team] = _discoverTeamSalary(data, team);
        _rosterCount[team] = _discoverRosterCount(data, team);
      }
    });
    await _persist();
  }

  Future<void> _copyScenario(NbaTerminalSeedSnapshot data, TradeValidationReport report) async {
    final scenario = _scenario(data);
    final payload = {
      'sports_terminal_trade': 2,
      'name': scenario.name,
      'season': scenario.operatingSeason,
      'teams': scenario.teams,
      'valid': report.isValid,
      'notes': _notes.text.trim(),
      'assignments': _assignments.map((item) => item.toJson()).toList(),
      'team_summary': {
        for (final entry in report.teamSummaries.entries)
          entry.key: {
            'outgoing_salary': entry.value.outgoingSalary,
            'incoming_salary': entry.value.incomingSalary,
            'allowed_incoming': entry.value.allowedIncomingSalary,
            'post_trade_salary': entry.value.postTradeSalary,
            'post_trade_roster': entry.value.postTradeRosterCount,
          },
      },
      'findings': [for (final finding in report.findings) {'code': finding.code, 'severity': finding.severity.name, 'team': finding.team, 'message': finding.message}],
    };
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)));
    if (mounted) _toast('Trade scenario copied as portable JSON.');
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (_loadingState) return const _TradePanel(child: Center(child: CircularProgressIndicator()));
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _TradePanel(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _TradePanel(child: Text('Trade Machine data unavailable: ${snapshot.error}', style: const TextStyle(color: _tmRed)));
        }
        final data = snapshot.data!;
        _initializeTeams(data);
        final scenario = _scenario(data);
        final report = _engine.validate(scenario);
        final thresholds = NbaCbaSeasonThresholds.forSeason(_season);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _TradeHero(report: report, teamCount: _teams.length, assetCount: _assignments.length, organizationMode: widget.organizationMode),
          const SizedBox(height: 12),
          _ScenarioToolbar(
            name: _name,
            notes: _notes,
            season: _season,
            stepien: _stepien,
            canAddTeam: _teams.length < 5,
            onSeason: (value) {
              setState(() => _season = value);
              _persist();
            },
            onStepien: (value) {
              setState(() => _stepien = value);
              _persist();
            },
            onChanged: _persist,
            onAddTeam: () => _addTeam(data),
            onReset: () => _reset(data),
            onCopy: () => _copyScenario(data, report),
          ),
          const SizedBox(height: 12),
          if (thresholds != null) _ThresholdStrip(thresholds: thresholds),
          if (thresholds != null) const SizedBox(height: 12),
          _TeamSelector(
            teams: _teams,
            allTeams: _teamIds(data),
            data: data,
            onSetTeam: (index, team) => _setTeam(index, team, data),
            onRemove: _removeTeam,
          ),
          const SizedBox(height: 12),
          for (final team in _teams) ...[
            _TeamTradeWorkbench(
              team: team,
              teams: _teams,
              data: data,
              stats: _stats,
              context: scenario.capContexts[team]!,
              summary: report.teamSummaries[team],
              assignments: _assignments.where((item) => item.originTeam == team).toList(),
              incoming: _assignments.where((item) => item.destinationTeam == team).toList(),
              onSalary: (value) {
                setState(() => _teamSalary[team] = value);
                _persist();
              },
              onRoster: (value) {
                setState(() => _rosterCount[team] = value);
                _persist();
              },
              onAddPlayer: (row) => _addPlayer(team, row, data),
              onAddManual: () => _addManualAsset(team),
              onEditAsset: _editAsset,
              onRemoveAsset: _removeAsset,
            ),
            const SizedBox(height: 12),
          ],
          _ValidationCenter(report: report),
          const SizedBox(height: 12),
          _TradeNotes(controller: _notes, onChanged: _persist),
          const SizedBox(height: 12),
          const _TradeDisclaimer(),
        ]);
      },
    );
  }
}

class _TradeHero extends StatelessWidget {
  const _TradeHero({required this.report, required this.teamCount, required this.assetCount, required this.organizationMode});
  final TradeValidationReport report;
  final int teamCount;
  final int assetCount;
  final bool organizationMode;
  @override
  Widget build(BuildContext context) => _TradePanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FRONT OFFICE / TRADE MACHINE', style: TextStyle(color: _tmBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 5),
            const Text('Build the transaction. See every rule it touches.', style: TextStyle(color: _tmText, fontSize: 29, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('Two-to-five-team routing, players, picks, cash, rights and exceptions; live salary matching; cap/tax/apron states; roster effects; trade eligibility; no-trade rights; poison-pill/kicker flags; Stepien screening and rule-by-rule findings.', style: TextStyle(color: _tmMuted, height: 1.4)),
          ]);
          final status = Wrap(spacing: 7, runSpacing: 7, children: [
            _Tag(report.isValid ? 'MODELED PASS' : '${report.errorCount} BLOCKERS', report.isValid ? _tmGreen : _tmRed),
            _Tag('$teamCount TEAMS', _tmBlue),
            _Tag('$assetCount ASSETS', _tmAmber),
            if (report.warningCount > 0) _Tag('${report.warningCount} REVIEW ITEMS', _tmAmber),
            if (organizationMode) const _Tag('ORG WORKFLOW', _tmBlue),
          ]);
          if (constraints.maxWidth < 860) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 12), status]);
          return Row(children: [Expanded(child: copy), const SizedBox(width: 20), Flexible(child: status)]);
        }),
      );
}

class _ScenarioToolbar extends StatelessWidget {
  const _ScenarioToolbar({required this.name, required this.notes, required this.season, required this.stepien, required this.canAddTeam, required this.onSeason, required this.onStepien, required this.onChanged, required this.onAddTeam, required this.onReset, required this.onCopy});
  final TextEditingController name;
  final TextEditingController notes;
  final String season;
  final bool stepien;
  final bool canAddTeam;
  final ValueChanged<String> onSeason;
  final ValueChanged<bool> onStepien;
  final VoidCallback onChanged;
  final VoidCallback onAddTeam;
  final VoidCallback onReset;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => _TradePanel(
        padding: const EdgeInsets.all(10),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
          SizedBox(width: 280, child: TextField(controller: name, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Scenario name', isDense: true, border: OutlineInputBorder()))),
          SizedBox(width: 130, child: DropdownButtonFormField<String>(value: season, decoration: const InputDecoration(labelText: 'CBA season', isDense: true, border: OutlineInputBorder()), items: [for (final value in NbaCbaSeasonThresholds.seasons.keys) DropdownMenuItem(value: value, child: Text(value))], onChanged: (value) { if (value != null) onSeason(value); })),
          FilterChip(label: const Text('Enforce Stepien screen'), selected: stepien, onSelected: onStepien),
          FilledButton.icon(onPressed: canAddTeam ? onAddTeam : null, icon: const Icon(Icons.add_rounded), label: const Text('Add team')),
          OutlinedButton.icon(onPressed: onCopy, icon: const Icon(Icons.ios_share_rounded), label: const Text('Copy / share')),
          OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.restart_alt_rounded), label: const Text('Reset')),
        ]),
      );
}

class _ThresholdStrip extends StatelessWidget {
  const _ThresholdStrip({required this.thresholds});
  final NbaCbaSeasonThresholds thresholds;
  @override
  Widget build(BuildContext context) => _TradePanel(
        child: Wrap(spacing: 15, runSpacing: 9, children: [
          _Threshold('CAP', thresholds.salaryCap),
          _Threshold('TAX', thresholds.taxLine),
          _Threshold('1ST APRON', thresholds.firstApron),
          _Threshold('2ND APRON', thresholds.secondApron),
          _Threshold('MIN TEAM SALARY', thresholds.minimumTeamSalary),
          _Threshold('NON-TAX MLE', thresholds.nonTaxpayerMle),
          _Threshold('TAX MLE', thresholds.taxpayerMle),
          _Threshold('ROOM MLE', thresholds.roomMle),
        ]),
      );
}

class _Threshold extends StatelessWidget {
  const _Threshold(this.label, this.value);
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _tmMuted, fontSize: 7, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(_money(value), style: const TextStyle(color: _tmText, fontSize: 11, fontWeight: FontWeight.w900))]);
}

class _TeamSelector extends StatelessWidget {
  const _TeamSelector({required this.teams, required this.allTeams, required this.data, required this.onSetTeam, required this.onRemove});
  final List<String> teams;
  final List<String> allTeams;
  final NbaTerminalSeedSnapshot data;
  final void Function(int index, String team) onSetTeam;
  final ValueChanged<String> onRemove;
  @override
  Widget build(BuildContext context) => _TradePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TEAMS IN TRADE', style: TextStyle(color: _tmBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var index = 0; index < teams.length; index++)
              Container(
                width: 250,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _tmPanel2, border: Border.all(color: _tmLine), borderRadius: BorderRadius.circular(7)),
                child: Row(children: [
                  Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: teams[index], isExpanded: true, dropdownColor: _tmPanel2, items: [for (final team in allTeams) DropdownMenuItem(value: team, child: Text('$team · ${_teamName(data, team)}', overflow: TextOverflow.ellipsis))], onChanged: (value) { if (value != null) onSetTeam(index, value); }))),
                  if (teams.length > 2) IconButton(tooltip: 'Remove team', onPressed: () => onRemove(teams[index]), icon: const Icon(Icons.close_rounded, color: _tmMuted, size: 17)),
                ]),
              ),
          ]),
        ]),
      );
}

class _TeamTradeWorkbench extends StatefulWidget {
  const _TeamTradeWorkbench({required this.team, required this.teams, required this.data, required this.stats, required this.context, required this.summary, required this.assignments, required this.incoming, required this.onSalary, required this.onRoster, required this.onAddPlayer, required this.onAddManual, required this.onEditAsset, required this.onRemoveAsset});
  final String team;
  final List<String> teams;
  final NbaTerminalSeedSnapshot data;
  final NbaStatsWorkstationEngine stats;
  final TeamCapContext context;
  final TeamTradeSummary? summary;
  final List<_EditableAssignment> assignments;
  final List<_EditableAssignment> incoming;
  final ValueChanged<double> onSalary;
  final ValueChanged<int> onRoster;
  final ValueChanged<NbaStatsRow> onAddPlayer;
  final VoidCallback onAddManual;
  final ValueChanged<_EditableAssignment> onEditAsset;
  final ValueChanged<_EditableAssignment> onRemoveAsset;
  @override
  State<_TeamTradeWorkbench> createState() => _TeamTradeWorkbenchState();
}

class _TeamTradeWorkbenchState extends State<_TeamTradeWorkbench> {
  final TextEditingController _search = TextEditingController();
  bool _showRoster = false;
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final players = widget.stats.buildRows(widget.data).where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(widget.team)).where((row) => !widget.assignments.any((item) => item.type == TradeAssetType.player && item.label == row.player)).toList();
    final query = _search.text.trim().toLowerCase();
    final filtered = players.where((row) => query.isEmpty || '${row.player} ${row.position}'.toLowerCase().contains(query)).toList()..sort((a,b) => (b.value('min') ?? 0).compareTo(a.value('min') ?? 0));
    final summary = widget.summary;
    return _TradePanel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: const BoxDecoration(color: _tmPanel2, border: Border(bottom: BorderSide(color: _tmLine))),
          child: Row(children: [
            InkWell(onTap: () => openNbaTeamPage(context, teamId: widget.team), child: Container(width: 50, height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: _tmPanel, border: Border.all(color: _tmBlue), borderRadius: BorderRadius.circular(8)), child: Text(widget.team, style: const TextStyle(color: _tmBlue, fontWeight: FontWeight.w900)))),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_teamName(widget.data, widget.team), style: const TextStyle(color: _tmText, fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('${summary?.preTradeTier ?? 'Unknown'} → ${summary?.postTradeTier ?? 'Unknown'}', style: const TextStyle(color: _tmMuted, fontSize: 9))])),
            _Tag('${widget.assignments.length} OUT', _tmAmber),
            const SizedBox(width: 6),
            _Tag('${widget.incoming.length} IN', _tmGreen),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CapImpactGrid(context: widget.context, summary: summary),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
              _NumberEditor(label: 'Current team salary', value: widget.context.teamSalary, prefix: r'$', onChanged: widget.onSalary),
              _IntegerEditor(label: 'Current roster', value: widget.context.standardRosterCount, onChanged: widget.onRoster),
              OutlinedButton.icon(onPressed: widget.onAddManual, icon: const Icon(Icons.add_box_outlined), label: const Text('Add pick / cash / exception / rights')),
              OutlinedButton.icon(onPressed: () => setState(() => _showRoster = !_showRoster), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(_showRoster ? 'Hide player list' : 'Add player')),
            ]),
            const SizedBox(height: 12),
            _AssetColumns(assignments: widget.assignments, incoming: widget.incoming, onEdit: widget.onEditAsset, onRemove: widget.onRemoveAsset),
            if (_showRoster) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _tmPanel2, border: Border.all(color: _tmLine), borderRadius: BorderRadius.circular(7)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded), hintText: 'Search roster…', border: OutlineInputBorder()))), const SizedBox(width: 8), _Tag('${filtered.length} AVAILABLE', _tmBlue)]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final row in filtered)
                      ActionChip(avatar: const Icon(Icons.add_rounded, size: 14), label: Text('${row.player} · ${row.position}'), onPressed: () => widget.onAddPlayer(row)),
                  ]),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _CapImpactGrid extends StatelessWidget {
  const _CapImpactGrid({required this.context, required this.summary});
  final TeamCapContext context;
  final TeamTradeSummary? summary;
  @override
  Widget build(BuildContext context) {
    final items = <(String,String,Color)>[
      ('PRE-TRADE', _money(this.context.teamSalary), _tmText),
      ('OUTGOING', _money(summary?.outgoingSalary ?? 0), _tmAmber),
      ('INCOMING', _money(summary?.incomingSalary ?? 0), _tmGreen),
      ('MAX INCOMING', _money(summary?.allowedIncomingSalary ?? 0), _tmBlue),
      ('MATCHING ROOM', _money(summary?.salaryMatchingRoom ?? 0), (summary?.salaryMatchingRoom ?? 0) >= 0 ? _tmGreen : _tmRed),
      ('POST-TRADE', _money(summary?.postTradeSalary ?? this.context.teamSalary), _tmText),
      ('ROSTER', '${summary?.postTradeRosterCount ?? this.context.standardRosterCount}', _tmText),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 900 ? (constraints.maxWidth - 6 * 7) / 7 : 135.0;
      return Wrap(spacing: 6, runSpacing: 6, children: [for (final item in items) SizedBox(width: width, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _tmPanel2, border: Border.all(color: _tmLine), borderRadius: BorderRadius.circular(6)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: const TextStyle(color: _tmMuted, fontSize: 7, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(item.$2, style: TextStyle(color: item.$3, fontSize: 12, fontWeight: FontWeight.w900))])))]);
    });
  }
}

class _AssetColumns extends StatelessWidget {
  const _AssetColumns({required this.assignments, required this.incoming, required this.onEdit, required this.onRemove});
  final List<_EditableAssignment> assignments;
  final List<_EditableAssignment> incoming;
  final ValueChanged<_EditableAssignment> onEdit;
  final ValueChanged<_EditableAssignment> onRemove;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final outgoing = _AssetList(title: 'SENDING', rows: assignments, editable: true, onEdit: onEdit, onRemove: onRemove);
    final incomingList = _AssetList(title: 'RECEIVING', rows: incoming, editable: false, onEdit: onEdit, onRemove: onRemove);
    if (constraints.maxWidth < 760) return Column(children: [outgoing, const SizedBox(height: 8), incomingList]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: outgoing), const SizedBox(width: 8), Expanded(child: incomingList)]);
  });
}

class _AssetList extends StatelessWidget {
  const _AssetList({required this.title, required this.rows, required this.editable, required this.onEdit, required this.onRemove});
  final String title;
  final List<_EditableAssignment> rows;
  final bool editable;
  final ValueChanged<_EditableAssignment> onEdit;
  final ValueChanged<_EditableAssignment> onRemove;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: _tmPanel2, border: Border.all(color: _tmLine), borderRadius: BorderRadius.circular(7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _tmBlue, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 6),
          if (rows.isEmpty) const Text('No assets', style: TextStyle(color: _tmMuted, fontSize: 10)),
          for (final item in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _tmLine, width: .5))),
              child: Row(children: [
                _AssetIcon(type: item.type),
                const SizedBox(width: 7),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(color: _tmText, fontSize: 10, fontWeight: FontWeight.w900)), Text('${item.originTeam} → ${item.destinationTeam}${item.salary > 0 ? ' · ${_money(item.salary)}' : ''}', style: const TextStyle(color: _tmMuted, fontSize: 8))])),
                if (editable) IconButton(tooltip: 'Edit routing / restrictions', onPressed: () => onEdit(item), icon: const Icon(Icons.tune_rounded, color: _tmBlue, size: 17)),
                if (editable) IconButton(tooltip: 'Remove asset', onPressed: () => onRemove(item), icon: const Icon(Icons.close_rounded, color: _tmMuted, size: 17)),
              ]),
            ),
        ]),
      );
}

class _ValidationCenter extends StatelessWidget {
  const _ValidationCenter({required this.report});
  final TradeValidationReport report;
  @override
  Widget build(BuildContext context) {
    final global = report.findings.where((item) => item.team == null).toList();
    return _TradePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(report.isValid ? Icons.verified_rounded : Icons.gpp_bad_rounded, color: report.isValid ? _tmGreen : _tmRed, size: 26),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(report.isValid ? 'Modeled trade passes implemented rules' : 'Trade has modeled blockers', style: const TextStyle(color: _tmText, fontSize: 20, fontWeight: FontWeight.w900)), Text('${report.errorCount} errors · ${report.warningCount} warnings · ${report.infoCount} informational findings', style: const TextStyle(color: _tmMuted, fontSize: 10))])),
          _Tag(report.operatingSeason, _tmBlue),
        ]),
        if (global.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('GLOBAL', style: TextStyle(color: _tmAmber, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
          for (final finding in global) _FindingRow(finding: finding),
        ],
        for (final team in report.teamSummaries.keys) ...[
          const SizedBox(height: 10),
          Text(team, style: const TextStyle(color: _tmBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
          for (final finding in report.findings.where((item) => item.team == team)) _FindingRow(finding: finding),
        ],
      ]),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});
  final TradeValidationFinding finding;
  @override
  Widget build(BuildContext context) {
    final color = switch (finding.severity) { TradeValidationSeverity.error => _tmRed, TradeValidationSeverity.warning => _tmAmber, TradeValidationSeverity.info => _tmGreen };
    final icon = switch (finding.severity) { TradeValidationSeverity.error => Icons.error_rounded, TradeValidationSeverity.warning => Icons.warning_amber_rounded, TradeValidationSeverity.info => Icons.info_outline_rounded };
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: color.withValues(alpha: .06), border: Border.all(color: color.withValues(alpha: .45)), borderRadius: BorderRadius.circular(6)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(finding.message, style: const TextStyle(color: _tmText, fontSize: 10, height: 1.35)), if (finding.ruleReference.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(finding.ruleReference, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800)))])),
        const SizedBox(width: 8),
        Text(finding.code, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _TradeNotes extends StatelessWidget {
  const _TradeNotes({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => _TradePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SCENARIO NOTES & FRONT-OFFICE THESIS', style: TextStyle(color: _tmBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 8),
          TextField(controller: controller, minLines: 4, maxLines: 10, onChanged: (_) => onChanged(), decoration: const InputDecoration(hintText: 'Why does each team do this? What assumptions matter? What is the pick/contract valuation? What follow-on roster move is needed?', border: OutlineInputBorder())),
        ]),
      );
}

class _TradeDisclaimer extends StatelessWidget {
  const _TradeDisclaimer();
  @override
  Widget build(BuildContext context) => const _TradePanel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.balance_rounded, color: _tmAmber),
          SizedBox(width: 9),
          Expanded(child: Text('Trade Machine results are research aids, not official NBA transaction determinations. Collective bargaining rules, contract amendments, trade bonuses, guarantees, options, rights, transaction timing and league interpretations can change or require facts not present in this model. “Modeled pass” means the scenario passed the currently implemented Sports Terminal rules and data—not that the NBA will approve it.', style: TextStyle(color: _tmMuted, fontSize: 10, height: 1.45))),
        ]),
      );
}

class _ManualAssetDialog extends StatefulWidget {
  const _ManualAssetDialog({required this.originTeam});
  final String originTeam;
  @override
  State<_ManualAssetDialog> createState() => _ManualAssetDialogState();
}

class _ManualAssetDialogState extends State<_ManualAssetDialog> {
  final _label = TextEditingController();
  final _salary = TextEditingController();
  final _year = TextEditingController(text: '${DateTime.now().year + 1}');
  TradeAssetType _type = TradeAssetType.draftPick;
  int _round = 1;
  bool _protected = false;
  bool _frozen = false;
  bool _stepienReview = true;
  @override
  void dispose() { _label.dispose(); _salary.dispose(); _year.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Add ${widget.originTeam} asset'),
        content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(children: [
          DropdownButtonFormField<TradeAssetType>(value: _type, isExpanded: true, decoration: const InputDecoration(labelText: 'Asset type', border: OutlineInputBorder()), items: const [
            DropdownMenuItem(value: TradeAssetType.draftPick, child: Text('Draft pick')),
            DropdownMenuItem(value: TradeAssetType.cash, child: Text('Cash')),
            DropdownMenuItem(value: TradeAssetType.tradeException, child: Text('Traded player exception')),
            DropdownMenuItem(value: TradeAssetType.signingException, child: Text('Signing exception')),
            DropdownMenuItem(value: TradeAssetType.draftRights, child: Text('Draft rights')),
            DropdownMenuItem(value: TradeAssetType.freeAgentRights, child: Text('Free-agent rights')),
          ], onChanged: (value) { if (value != null) setState(() => _type = value); }),
          const SizedBox(height: 10),
          TextField(controller: _label, decoration: const InputDecoration(labelText: 'Label', hintText: '2028 first-round pick / $3.0M cash / $12.5M TPE…', border: OutlineInputBorder())),
          if (_type == TradeAssetType.cash || _type == TradeAssetType.tradeException || _type == TradeAssetType.signingException) ...[
            const SizedBox(height: 10),
            TextField(controller: _salary, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixText: r'$', border: OutlineInputBorder())),
          ],
          if (_type == TradeAssetType.draftPick) ...[
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Draft year', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<int>(value: _round, decoration: const InputDecoration(labelText: 'Round', border: OutlineInputBorder()), items: const [DropdownMenuItem(value:1,child:Text('1st')), DropdownMenuItem(value:2,child:Text('2nd'))], onChanged: (value) { if (value != null) setState(() => _round = value); }))]),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _protected, onChanged: (value) => setState(() => _protected = value == true), title: const Text('Protected pick')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _frozen, onChanged: (value) => setState(() => _frozen = value == true), title: const Text('Second-apron frozen / otherwise unavailable')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _stepienReview, onChanged: (value) => setState(() => _stepienReview = value == true), title: const Text('Flag for Stepien inventory review')),
          ],
        ]))),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')), FilledButton(onPressed: () {
          final label = _label.text.trim().isEmpty ? _defaultAssetLabel(_type, _year.text, _round) : _label.text.trim();
          Navigator.of(context).pop(_ManualAssetDraft(type: _type, label: label, salary: _double(_salary.text), metadata: _type == TradeAssetType.draftPick ? {'year': _int(_year.text), 'round': _round, 'protected': _protected, 'frozen': _frozen, 'stepien_review': _stepienReview} : const {}));
        }, child: const Text('Add asset'))],
      );
}

class _AssetEditDialog extends StatefulWidget {
  const _AssetEditDialog({required this.item, required this.teams});
  final _EditableAssignment item;
  final List<String> teams;
  @override
  State<_AssetEditDialog> createState() => _AssetEditDialogState();
}

class _AssetEditDialogState extends State<_AssetEditDialog> {
  late String _destination;
  late TextEditingController _salary;
  late bool _notTradeable;
  late bool _aggregationRestricted;
  late bool _noTradeClause;
  late bool _tradeConsent;
  late bool _poisonPill;
  late bool _recentlySigned;
  late TextEditingController _tradeKicker;
  @override
  void initState() {
    super.initState();
    _destination = widget.item.destinationTeam;
    _salary = TextEditingController(text: widget.item.salary.toStringAsFixed(0));
    _notTradeable = _bool(widget.item.metadata['not_tradeable']);
    _aggregationRestricted = _bool(widget.item.metadata['aggregation_restricted']);
    _noTradeClause = _bool(widget.item.metadata['no_trade_clause']);
    _tradeConsent = widget.item.metadata.containsKey('no_trade_consent')
        ? !_bool(widget.item.metadata['no_trade_consent'])
        : _bool(widget.item.metadata['trade_consent']);
    _poisonPill = _bool(widget.item.metadata['poison_pill']);
    _recentlySigned = _bool(widget.item.metadata['recently_signed_restricted']);
    _tradeKicker = TextEditingController(text: (_double(widget.item.metadata['trade_kicker_pct']) * 100).toStringAsFixed(1));
  }
  @override
  void dispose() { _salary.dispose(); _tradeKicker.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Edit ${widget.item.label}'),
        content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(children: [
          DropdownButtonFormField<String>(value: _destination, decoration: const InputDecoration(labelText: 'Destination team', border: OutlineInputBorder()), items: [for (final team in widget.teams.where((team) => team != widget.item.originTeam)) DropdownMenuItem(value: team, child: Text(team))], onChanged: (value) { if (value != null) setState(() => _destination = value); }),
          if (widget.item.type == TradeAssetType.player) ...[
            const SizedBox(height: 10),
            TextField(controller: _salary, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Matching salary', prefixText: r'$', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _notTradeable, onChanged: (value) => setState(() => _notTradeable = value == true), title: const Text('Marked not tradeable')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _aggregationRestricted, onChanged: (value) => setState(() => _aggregationRestricted = value == true), title: const Text('Recently acquired / aggregation restricted')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _recentlySigned, onChanged: (value) => setState(() => _recentlySigned = value == true), title: const Text('Recently signed / trade eligibility restricted')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _noTradeClause, onChanged: (value) => setState(() => _noTradeClause = value == true), title: const Text('No-trade / consent right')),
            if (_noTradeClause) CheckboxListTile(contentPadding: EdgeInsets.zero, value: _tradeConsent, onChanged: (value) => setState(() => _tradeConsent = value == true), title: const Text('Player consent recorded for this scenario')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _poisonPill, onChanged: (value) => setState(() => _poisonPill = value == true), title: const Text('Poison-pill affected')),
            TextField(controller: _tradeKicker, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Trade bonus / kicker %', suffixText: '%', border: OutlineInputBorder())),
          ],
        ]))),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')), FilledButton(onPressed: () {
          final metadata = Map<String,dynamic>.from(widget.item.metadata)..addAll({'not_tradeable': _notTradeable, 'aggregation_restricted': _aggregationRestricted, 'recently_signed_restricted': _recentlySigned, 'no_trade_clause': _noTradeClause, 'no_trade_consent': _noTradeClause && !_tradeConsent, 'poison_pill': _poisonPill, 'trade_kicker_pct': _double(_tradeKicker.text) / 100});
          Navigator.of(context).pop(widget.item.copyWith(destinationTeam: _destination, salary: widget.item.type == TradeAssetType.player ? _double(_salary.text) : widget.item.salary, metadata: metadata));
        }, child: const Text('Apply'))],
      );
}

class _NumberEditor extends StatelessWidget {
  const _NumberEditor({required this.label, required this.value, required this.prefix, required this.onChanged});
  final String label;
  final double value;
  final String prefix;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value.toStringAsFixed(0));
    return SizedBox(width: 165, child: TextField(controller: controller, keyboardType: TextInputType.number, onSubmitted: (text) => onChanged(_double(text)), decoration: InputDecoration(labelText: label, prefixText: prefix, isDense: true, border: const OutlineInputBorder())));
  }
}

class _IntegerEditor extends StatelessWidget {
  const _IntegerEditor({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: '$value');
    return SizedBox(width: 120, child: TextField(controller: controller, keyboardType: TextInputType.number, onSubmitted: (text) => onChanged(_int(text)), decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder())));
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon({required this.type});
  final TradeAssetType type;
  @override
  Widget build(BuildContext context) => Icon(switch (type) { TradeAssetType.player => Icons.person_rounded, TradeAssetType.draftPick => Icons.confirmation_number_outlined, TradeAssetType.draftRights => Icons.flag_outlined, TradeAssetType.cash => Icons.payments_outlined, TradeAssetType.freeAgentRights => Icons.person_search_rounded, TradeAssetType.tradeException => Icons.receipt_long_outlined, TradeAssetType.signingException => Icons.add_card_rounded }, color: _tmBlue, size: 17);
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)));
}

class _TradePanel extends StatelessWidget {
  const _TradePanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _tmPanel, border: Border.all(color: _tmLine), borderRadius: BorderRadius.circular(9)), child: child);
}

class _EditableAssignment {
  const _EditableAssignment({required this.id, required this.type, required this.label, required this.originTeam, required this.destinationTeam, required this.salary, required this.metadata});
  final String id;
  final TradeAssetType type;
  final String label;
  final String originTeam;
  final String destinationTeam;
  final double salary;
  final Map<String,dynamic> metadata;
  TradeAsset toAsset() => TradeAsset(id: id, type: type, label: label, originTeam: originTeam, salary: salary, metadata: metadata);
  _EditableAssignment copyWith({String? destinationTeam, double? salary, Map<String,dynamic>? metadata}) => _EditableAssignment(id: id, type: type, label: label, originTeam: originTeam, destinationTeam: destinationTeam ?? this.destinationTeam, salary: salary ?? this.salary, metadata: metadata ?? this.metadata);
  Map<String,dynamic> toJson() => {'id':id,'type':type.name,'label':label,'originTeam':originTeam,'destinationTeam':destinationTeam,'salary':salary,'metadata':metadata};
  factory _EditableAssignment.fromJson(Map<String,dynamic> json) => _EditableAssignment(id:json['id']?.toString() ?? '', type:TradeAssetType.values.firstWhere((item) => item.name == json['type'], orElse: () => TradeAssetType.player), label:json['label']?.toString() ?? 'Asset', originTeam:json['originTeam']?.toString() ?? '', destinationTeam:json['destinationTeam']?.toString() ?? '', salary:_double(json['salary']), metadata:json['metadata'] is Map ? (json['metadata'] as Map).map((key,value)=>MapEntry(key.toString(),value)) : const {});
}

class _ManualAssetDraft {
  const _ManualAssetDraft({required this.type, required this.label, required this.salary, required this.metadata});
  final TradeAssetType type;
  final String label;
  final double salary;
  final Map<String,dynamic> metadata;
}

List<String> _teamIds(NbaTerminalSeedSnapshot data) {
  final ids = <String>{};
  for (final row in [...data.teamRecords, ...data.teams]) {
    final id = _teamId(row);
    if (id != '—' && id.length <= 5) ids.add(id);
  }
  final result = ids.toList()..sort();
  return result;
}
String _teamId(Map<String,dynamic> row) {
  for (final key in const ['team_id','abbreviation','team_abbreviation','id']) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '—';
}
String _teamName(NbaTerminalSeedSnapshot data, String team) {
  for (final row in [...data.teamRecords, ...data.teams]) {
    if (_teamId(row) != team) continue;
    for (final key in const ['team_name','name','full_name']) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
  }
  return team;
}
double _discoverTeamSalary(NbaTerminalSeedSnapshot data, String team) {
  for (final row in data.teamRecords.where((row) => _teamId(row) == team)) {
    for (final key in const ['team_salary','payroll','total_salary','salary']) {
      final value = _double(row[key]);
      if (value > 10000000) return value;
    }
  }
  final threshold = NbaCbaSeasonThresholds.forSeason('2025-26');
  return threshold?.salaryCap ?? 154647000;
}
int _discoverRosterCount(NbaTerminalSeedSnapshot data, String team) {
  final names = <String>{};
  for (final row in const NbaStatsWorkstationEngine().buildRows(data)) {
    if (row.team.split(RegExp(r'[,/ ]+')).contains(team)) names.add(row.playerId);
  }
  return names.isEmpty ? 15 : names.length.clamp(10, 18);
}
double _discoverPlayerSalary(NbaTerminalSeedSnapshot data, String playerId, String playerName) {
  for (final row in data.players) {
    final id = (row['player_id'] ?? row['id'] ?? row['person_id'])?.toString() ?? '';
    final name = (row['player_name'] ?? row['name'] ?? row['full_name'])?.toString() ?? '';
    if (id != playerId && name != playerName) continue;
    for (final key in const ['salary','current_salary','cap_hit','contract_salary']) {
      final value = _double(row[key]);
      if (value > 0) return value;
    }
  }
  return 0;
}
String _defaultAssetLabel(TradeAssetType type, String year, int round) => switch (type) { TradeAssetType.draftPick => '$year ${round == 1 ? '1st' : '2nd'}-round pick', TradeAssetType.cash => 'Cash considerations', TradeAssetType.tradeException => 'Traded player exception', TradeAssetType.signingException => 'Signing exception', TradeAssetType.draftRights => 'Draft rights', TradeAssetType.freeAgentRights => 'Free-agent rights', TradeAssetType.player => 'Player' };
double _double(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString().replaceAll(',', '').replaceAll(r'$', '') ?? '') ?? 0;
int _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
bool _bool(Object? value) => value is bool ? value : {'true','1','yes','y'}.contains(value?.toString().toLowerCase().trim());
String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000) return '$sign\$${(amount / 1000000).toStringAsFixed(2)}M';
  if (amount >= 1000) return '$sign\$${(amount / 1000).toStringAsFixed(0)}K';
  return '$sign\$${amount.toStringAsFixed(0)}';
}
