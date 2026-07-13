import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import '../services/trade_machine_engine.dart';

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
  State<ProductTradeMachineScreen> createState() =>
      _ProductTradeMachineScreenState();
}

class _ProductTradeMachineScreenState extends State<ProductTradeMachineScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  final TradeMachineEngine engine = const TradeMachineEngine();
  final TextEditingController scenarioController =
      TextEditingController(text: 'Untitled multi-team scenario');

  late final Future<NbaTerminalSeedSnapshot> seedFuture;
  String operatingYear = '2026-27';
  List<String> selectedTeams = ['BOS', 'PHI'];
  Map<String, String> assetDestinations = {};
  Map<String, String> activeTabs = {};
  bool selectedOnly = false;

  @override
  void initState() {
    super.initState();
    seedFuture = const NbaTerminalSeedRepository().load();
    _loadState();
  }

  @override
  void dispose() {
    scenarioController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final saved = await localStore.loadStringMap(
      ProductLocalStore.tradeMachineStateKey,
    );
    if (!mounted || saved.isEmpty) return;
    final teams = (saved['teams'] ?? '')
        .split('|')
        .where((value) => value.isNotEmpty)
        .toList();
    setState(() {
      operatingYear = saved['year'] ?? operatingYear;
      if (teams.length >= 2) selectedTeams = teams;
      scenarioController.text = saved['name'] ?? scenarioController.text;
      assetDestinations = _decodeMap(saved['assignments']);
      activeTabs = _decodeMap(saved['tabs']);
      selectedOnly = saved['selectedOnly'] == 'true';
    });
  }

  Future<void> _persist({bool announce = false}) async {
    await localStore.saveStringMap(
      ProductLocalStore.tradeMachineStateKey,
      {
        'year': operatingYear,
        'teams': selectedTeams.join('|'),
        'name': scenarioController.text.trim(),
        'assignments': _encodeMap(assetDestinations),
        'tabs': _encodeMap(activeTabs),
        'selectedOnly': '$selectedOnly',
      },
    );
    if (announce && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trade scenario saved locally.')),
      );
    }
  }

  Future<void> _setDestination(String id, String? destination) async {
    setState(() {
      if (destination == null || destination.isEmpty) {
        assetDestinations.remove(id);
      } else {
        assetDestinations[id] = destination;
      }
    });
    await _persist();
  }

  Future<void> _addTeam(String team) async {
    if (selectedTeams.contains(team)) return;
    setState(() => selectedTeams = [...selectedTeams, team]);
    await _persist();
  }

  Future<void> _removeTeam(String team) async {
    if (selectedTeams.length <= 2) return;
    setState(() {
      selectedTeams = selectedTeams.where((value) => value != team).toList();
      assetDestinations.removeWhere(
        (id, destination) => id.startsWith('$team:') || destination == team,
      );
      activeTabs.remove(team);
    });
    await _persist();
  }

  Future<void> _reset() async {
    setState(() {
      assetDestinations = {};
      activeTabs = {};
      selectedOnly = false;
      scenarioController.text = 'Untitled multi-team scenario';
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: seedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Surface(
            child: Text('Loading trade machine...',
                style: TextStyle(color: _muted)),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _Surface(
            child: Text('Trade machine data unavailable: ${snapshot.error}',
                style: const TextStyle(color: _muted)),
          );
        }

        final data = snapshot.data!;
        final allTeams = _teamIds(data);
        _ensureTeams(allTeams);
        final catalog = _catalog(data, selectedTeams);
        assetDestinations.removeWhere(
          (id, destination) =>
              !catalog.containsKey(id) || !selectedTeams.contains(destination),
        );
        final scenario = _scenario(data, catalog);
        final report = engine.validate(scenario);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              year: operatingYear,
              teams: selectedTeams.length,
              assets: scenario.assignments.length,
            ),
            const SizedBox(height: 18),
            _ScenarioControls(
              controller: scenarioController,
              year: operatingYear,
              selectedOnly: selectedOnly,
              assetCount: scenario.assignments.length,
              onYear: (value) async {
                if (value == null) return;
                setState(() => operatingYear = value);
                await _persist();
              },
              onSelectedOnly: (value) async {
                setState(() => selectedOnly = value);
                await _persist();
              },
              onSave: () => _persist(announce: true),
              onReset: _reset,
            ),
            const SizedBox(height: 18),
            _TeamPicker(
              allTeams: allTeams,
              selectedTeams: selectedTeams,
              onAdd: _addTeam,
              onRemove: _removeTeam,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 1180;
                final width = twoColumns
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final team in selectedTeams)
                      SizedBox(
                        width: width,
                        child: _TeamBoard(
                          team: team,
                          data: data,
                          selectedTeams: selectedTeams,
                          tab: activeTabs[team] ?? _Category.roster.label,
                          destinations: assetDestinations,
                          selectedOnly: selectedOnly,
                          onTab: (value) async {
                            setState(() => activeTabs[team] = value);
                            await _persist();
                          },
                          onDestination: _setDestination,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _ValidationPanel(scenario: scenario, report: report),
            const SizedBox(height: 18),
            _CapTracker(
              data: data,
              teams: selectedTeams,
              report: report,
              year: operatingYear,
            ),
            const SizedBox(height: 18),
            const _Roadmap(),
          ],
        );
      },
    );
  }

  void _ensureTeams(List<String> allTeams) {
    if (selectedTeams.length >= 2) return;
    for (final team in [...const ['BOS', 'PHI'], ...allTeams]) {
      if (allTeams.contains(team) && !selectedTeams.contains(team)) {
        selectedTeams.add(team);
      }
      if (selectedTeams.length >= 2) return;
    }
  }

  TradeScenario _scenario(
    NbaTerminalSeedSnapshot data,
    Map<String, _Asset> catalog,
  ) {
    final assignments = <TradeAssignment>[];
    for (final entry in assetDestinations.entries) {
      final asset = catalog[entry.key];
      if (asset == null) continue;
      assignments.add(
        TradeAssignment(
          asset: asset.domain,
          destinationTeam: entry.value,
        ),
      );
    }
    return TradeScenario(
      id: 'local-active-scenario',
      name: scenarioController.text.trim().isEmpty
          ? 'Untitled multi-team scenario'
          : scenarioController.text.trim(),
      operatingSeason: operatingYear,
      teams: List<String>.from(selectedTeams),
      assignments: assignments,
      capContexts: {
        for (final team in selectedTeams)
          team: _capContext(data, team, operatingYear),
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.year, required this.teams, required this.assets});
  final String year;
  final int teams;
  final int assets;

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
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NBA TRADE MACHINE',
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.4)),
            const SizedBox(height: 12),
            const Text('Build, route and review multi-team transactions.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 39,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8)),
            const SizedBox(height: 12),
            const ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 920),
              child: Text(
                'Players, picks, draft rights, cash, free-agent rights and exceptions now share one scenario model. Generated salary proxies remain clearly separated from the future contract and CBA warehouse.',
                style: TextStyle(
                    color: Color(0xFFEAF2FF),
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _GlassChip(year),
              _GlassChip('$teams TEAMS'),
              _GlassChip('$assets ASSETS'),
              const _GlassChip('MULTI-TEAM ROUTING'),
              const _GlassChip('CAP / TAX / APRON REVIEW'),
            ]),
          ],
        ),
      );
}

class _ScenarioControls extends StatelessWidget {
  const _ScenarioControls({
    required this.controller,
    required this.year,
    required this.selectedOnly,
    required this.assetCount,
    required this.onYear,
    required this.onSelectedOnly,
    required this.onSave,
    required this.onReset,
  });
  final TextEditingController controller;
  final String year;
  final bool selectedOnly;
  final int assetCount;
  final ValueChanged<String?> onYear;
  final ValueChanged<bool> onSelectedOnly;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Header('Scenario control center',
              'Name, persist and reset the active transaction. Asset destinations save locally as you work.'),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final name = TextField(
              controller: controller,
              decoration: _decoration('Scenario name', Icons.edit_note_rounded),
            );
            final yearField = DropdownButtonFormField<String>(
              value: year,
              isExpanded: true,
              decoration:
                  _decoration('Operating year', Icons.calendar_month_rounded),
              items: [
                for (final option in const [
                  '2024-25',
                  '2025-26',
                  '2026-27',
                  '2027-28',
                  '2028-29'
                ])
                  DropdownMenuItem(
                    value: option,
                    child: Text(option,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
              ],
              onChanged: onYear,
            );
            if (compact) {
              return Column(children: [
                name,
                const SizedBox(height: 12),
                yearField,
              ]);
            }
            return Row(children: [
              Expanded(flex: 2, child: name),
              const SizedBox(width: 12),
              Expanded(child: yearField),
            ]);
          }),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _Status('$assetCount assets routed'),
            FilterChip(
              selected: selectedOnly,
              onSelected: onSelectedOnly,
              label: const Text('Show selected only',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save scenario'),
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset assets'),
            ),
          ]),
        ]),
      );
}

class _TeamPicker extends StatelessWidget {
  const _TeamPicker({
    required this.allTeams,
    required this.selectedTeams,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> allTeams;
  final List<String> selectedTeams;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Header('Participating teams',
              'Add as many teams as needed. At least two teams remain active.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final team in selectedTeams)
              InputChip(
                label: Text(team,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                selected: true,
                selectedColor: const Color(0xFFEFF6FF),
                onDeleted:
                    selectedTeams.length <= 2 ? null : () => onRemove(team),
              ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final team in allTeams)
              OutlinedButton.icon(
                onPressed:
                    selectedTeams.contains(team) ? null : () => onAdd(team),
                icon: Icon(
                    selectedTeams.contains(team)
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 17),
                label: Text(team,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
          ]),
        ]),
      );
}

class _TeamBoard extends StatelessWidget {
  const _TeamBoard({
    required this.team,
    required this.data,
    required this.selectedTeams,
    required this.tab,
    required this.destinations,
    required this.selectedOnly,
    required this.onTab,
    required this.onDestination,
  });
  final String team;
  final NbaTerminalSeedSnapshot data;
  final List<String> selectedTeams;
  final String tab;
  final Map<String, String> destinations;
  final bool selectedOnly;
  final ValueChanged<String> onTab;
  final Future<void> Function(String, String?) onDestination;

  @override
  Widget build(BuildContext context) {
    final category = _Category.values.firstWhere(
      (value) => value.label == tab,
      orElse: () => _Category.roster,
    );
    var assets = _assets(data, team, category);
    if (selectedOnly) {
      assets = assets.where((value) => destinations.containsKey(value.id)).toList();
    }
    final selectedCount = destinations.keys
        .where((value) => value.startsWith('$team:'))
        .length;
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(team,
                style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$team transaction board',
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
              Text('$selectedCount outgoing assets selected',
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        _CapStrip(context: _capContext(data, team, '2026-27')),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final category in _Category.values) ...[
              ChoiceChip(
                label: Text(category.label,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                selected: tab == category.label,
                selectedColor: _navy,
                labelStyle:
                    TextStyle(color: tab == category.label ? Colors.white : _ink),
                onSelected: (_) => onTab(category.label),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        if (assets.isEmpty)
          const Text('No assets match this view.',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w700))
        else
          for (final asset in assets)
            _AssetRow(
              asset: asset,
              teams: selectedTeams.where((value) => value != team).toList(),
              destination: destinations[asset.id],
              onChanged: (value) => onDestination(asset.id, value),
            ),
      ]),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.asset,
    required this.teams,
    required this.destination,
    required this.onChanged,
  });
  final _Asset asset;
  final List<String> teams;
  final String? destination;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration:
            const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final selector = DropdownButtonFormField<String>(
            value: teams.contains(destination) ? destination : null,
            isExpanded: true,
            hint: const Text('Destination', overflow: TextOverflow.ellipsis),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              filled: true,
              fillColor: _soft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _line),
              ),
            ),
            items: [
              for (final team in teams)
                DropdownMenuItem(
                  value: team,
                  child: Text(team,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
            onChanged: teams.isEmpty ? null : onChanged,
          );
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(asset.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(asset.detail,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          );
          final value = asset.salary > 0 ? _money(asset.salary) : asset.typeLabel;
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              identity,
              const SizedBox(height: 9),
              Row(children: [
                Expanded(
                  child: Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 170, child: selector),
              ]),
            ]);
          }
          return Row(children: [
            Expanded(child: identity),
            const SizedBox(width: 10),
            SizedBox(
              width: 112,
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 150, child: selector),
          ]);
        }),
      );
}

class _CapStrip extends StatelessWidget {
  const _CapStrip({required this.context});
  final TeamCapContext context;

  @override
  Widget build(BuildContext buildContext) => LayoutBuilder(
        builder: (buildContext, constraints) {
          final width = constraints.maxWidth >= 620
              ? (constraints.maxWidth - 24) / 4
              : constraints.maxWidth >= 330
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
          final values = <String, double>{
            'Cap': context.salaryCap - context.teamSalary,
            'Tax': context.taxLine - context.teamSalary,
            '1st apron': context.firstApron - context.teamSalary,
            '2nd apron': context.secondApron - context.teamSalary,
          };
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in values.entries)
              SizedBox(
                width: width,
                child: _CapMetric(label: entry.key, value: entry.value),
              ),
          ]);
        },
      );
}

class _CapMetric extends StatelessWidget {
  const _CapMetric({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFEAFBF2) : const Color(0xFFFFEFEF),
        border: Border.all(
            color: positive
                ? const Color(0xFFB9F2CF)
                : const Color(0xFFFFC6C6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _muted, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(_money(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: positive ? _green : _red,
                fontSize: 12,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.scenario, required this.report});
  final TradeScenario scenario;
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) {
    final errors = report.findings
        .where((value) => value.severity == TradeValidationSeverity.error)
        .length;
    final warnings = report.findings
        .where((value) => value.severity == TradeValidationSeverity.warning)
        .length;
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Header('Scenario validation',
            '${scenario.assignments.length} assets across ${scenario.teams.length} teams. Current checks are structural and cap-context based, not a complete CBA opinion.'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: errors > 0
                ? const Color(0xFFFFEFEF)
                : warnings > 0
                    ? const Color(0xFFFFF7E8)
                    : const Color(0xFFEAFBF2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: errors > 0
                  ? const Color(0xFFFFC6C6)
                  : warnings > 0
                      ? const Color(0xFFFFDFA8)
                      : const Color(0xFFB9F2CF),
            ),
          ),
          child: Text(
            errors > 0
                ? '$errors blocking findings'
                : warnings > 0
                    ? 'Structurally valid with $warnings review items'
                    : 'Scenario passes current structural checks',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 900
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final team in scenario.teams)
              SizedBox(
                width: width,
                child: _Summary(
                  team: team,
                  summary: report.teamSummaries[team],
                ),
              ),
          ]);
        }),
        if (report.findings.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final finding in report.findings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.circle,
                    size: 9,
                    color: finding.severity == TradeValidationSeverity.error
                        ? _red
                        : finding.severity == TradeValidationSeverity.warning
                            ? _orange
                            : _blue),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(finding.message,
                      style: const TextStyle(
                          color: _ink,
                          height: 1.35,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.team, required this.summary});
  final String team;
  final TeamTradeSummary? summary;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _soft,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$team transaction summary',
              style: const TextStyle(
                  color: _ink, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _KeyValue('Outgoing salary', _money(summary?.outgoingSalary ?? 0)),
          _KeyValue('Incoming salary', _money(summary?.incomingSalary ?? 0)),
          _KeyValue(
              'Post-trade salary', _money(summary?.postTradeSalary ?? 0)),
          _KeyValue('Outgoing assets', '${summary?.outgoingAssets ?? 0}'),
          _KeyValue('Incoming assets', '${summary?.incomingAssets ?? 0}'),
        ]),
      );
}

class _CapTracker extends StatelessWidget {
  const _CapTracker({
    required this.data,
    required this.teams,
    required this.report,
    required this.year,
  });
  final NbaTerminalSeedSnapshot data;
  final List<String> teams;
  final TradeValidationReport report;
  final String year;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Header('Team salary, tax and apron tracker',
              'A first combined tracker using generated salary proxies until current contract data is connected.'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_soft),
              columns: const [
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Season')),
                DataColumn(label: Text('Baseline')),
                DataColumn(label: Text('Post-trade')),
                DataColumn(label: Text('Tax status')),
                DataColumn(label: Text('Apron status')),
              ],
              rows: [
                for (final team in teams)
                  DataRow(cells: [
                    DataCell(Text(team)),
                    DataCell(Text(year)),
                    DataCell(Text(_money(_capContext(data, team, year).teamSalary))),
                    DataCell(Text(
                        _money(report.teamSummaries[team]?.postTradeSalary ?? 0))),
                    DataCell(Text(_position(
                        report.teamSummaries[team]?.postTradeSalary ?? 0,
                        _capContext(data, team, year).taxLine,
                        'tax'))),
                    DataCell(Text(_apron(
                        report.teamSummaries[team]?.postTradeSalary ?? 0,
                        _capContext(data, team, year)))),
                  ]),
              ],
            ),
          ),
        ]),
      );
}

class _Roadmap extends StatelessWidget {
  const _Roadmap();

  @override
  Widget build(BuildContext context) => const _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header('Next contract and CBA layers',
              'The workflow is ready for sourced financial data rather than more placeholder layout.'),
          SizedBox(height: 12),
          _Checklist('Current contracts, guarantees, options, trade kickers, cap holds, Bird rights and transaction restrictions.'),
          _Checklist('Pick ownership chains, Stepien availability, protections, swaps, conveyance rules and draft-rights inventories.'),
          _Checklist('Salary matching, aggregation, apron restrictions, sign-and-trades, BYC, poison-pill treatment and exception expiration.'),
          _Checklist('Backend scenario persistence, comparison, sharing, Workspace export and Python Lab handoff.'),
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

class _Status extends StatelessWidget {
  const _Status(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: _soft,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: const TextStyle(
                color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
      );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: _muted, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _ink, fontWeight: FontWeight.w900)),
          ),
        ]),
      );
}

class _Checklist extends StatelessWidget {
  const _Checklist(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_rounded, color: _green, size: 18),
          const SizedBox(width: 10),
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

enum _Category {
  roster('Active Roster'),
  picks('Draft Picks'),
  rights('Draft Rights'),
  cash('Cash'),
  freeAgents('Free Agents'),
  exceptions('Exceptions');

  const _Category(this.label);
  final String label;
}

class _Asset {
  const _Asset({
    required this.id,
    required this.label,
    required this.detail,
    required this.origin,
    required this.type,
    required this.typeLabel,
    this.salary = 0,
  });
  final String id;
  final String label;
  final String detail;
  final String origin;
  final TradeAssetType type;
  final String typeLabel;
  final double salary;

  TradeAsset get domain => TradeAsset(
        id: id,
        type: type,
        label: label,
        originTeam: origin,
        salary: salary,
        metadata: {'detail': detail},
      );
}

Map<String, _Asset> _catalog(
    NbaTerminalSeedSnapshot data, List<String> teams) {
  final result = <String, _Asset>{};
  for (final team in teams) {
    for (final category in _Category.values) {
      for (final asset in _assets(data, team, category)) {
        result[asset.id] = asset;
      }
    }
  }
  return result;
}

List<_Asset> _assets(
    NbaTerminalSeedSnapshot data, String team, _Category category) {
  if (category == _Category.roster) {
    return [
      for (final row in _roster(data, team).take(15))
        _Asset(
          id: '$team:player:${_text(row['player_id'])}',
          label: _text(row['player_label']),
          detail:
              '${_decimal(_perGame(row, 'points', 'points_per_game'))} PPG • ${_decimal(_perGame(row, 'minutes', 'minutes_per_game'))} MPG • ${_decimal(_number(row['avg_bpm']))} BPM',
          origin: team,
          type: TradeAssetType.player,
          typeLabel: 'Player',
          salary: _salary(row),
        ),
    ];
  }
  if (category == _Category.picks) {
    return [
      _Asset(id: '$team:pick:2027-1', label: '$team 2027 first-round pick', detail: 'Protection and conveyance data pending', origin: team, type: TradeAssetType.draftPick, typeLabel: '1st-round pick'),
      _Asset(id: '$team:pick:2028-2', label: '$team 2028 second-round pick', detail: 'Ownership chain data pending', origin: team, type: TradeAssetType.draftPick, typeLabel: '2nd-round pick'),
      _Asset(id: '$team:swap:2029-1', label: '$team 2029 first-round swap right', detail: 'Swap priority and counterpart pending', origin: team, type: TradeAssetType.draftPick, typeLabel: 'Pick swap'),
    ];
  }
  if (category == _Category.rights) {
    return [
      _Asset(id: '$team:rights:international', label: 'International draft-rights slot', detail: 'Player identity and status feed pending', origin: team, type: TradeAssetType.draftRights, typeLabel: 'Draft rights'),
      _Asset(id: '$team:rights:unsigned', label: 'Unsigned second-round rights slot', detail: 'Rights retention and tender status pending', origin: team, type: TradeAssetType.draftRights, typeLabel: 'Draft rights'),
    ];
  }
  if (category == _Category.cash) {
    return [
      _Asset(id: '$team:cash:outgoing', label: 'Cash considerations', detail: 'Annual limit and remaining balance pending', origin: team, type: TradeAssetType.cash, typeLabel: 'Cash'),
    ];
  }
  if (category == _Category.freeAgents) {
    return [
      _Asset(id: '$team:fa:bird-rights', label: 'Free-agent Bird rights slot', detail: 'Cap hold and sign-and-trade rules pending', origin: team, type: TradeAssetType.freeAgentRights, typeLabel: 'FA rights'),
      _Asset(id: '$team:fa:cap-hold', label: 'Free-agent cap-hold slot', detail: 'Renunciation effect pending contract data', origin: team, type: TradeAssetType.freeAgentRights, typeLabel: 'Cap hold'),
    ];
  }
  return [
    _Asset(id: '$team:exception:tpe', label: 'Trade Player Exception', detail: 'Amount and expiration date pending', origin: team, type: TradeAssetType.tradeException, typeLabel: 'TPE'),
    _Asset(id: '$team:exception:ntmle', label: 'Non-Taxpayer Mid-Level Exception', detail: 'Availability and hard-cap trigger pending', origin: team, type: TradeAssetType.signingException, typeLabel: 'NTMLE'),
    _Asset(id: '$team:exception:tmle', label: 'Taxpayer Mid-Level Exception', detail: 'Availability and apron eligibility pending', origin: team, type: TradeAssetType.signingException, typeLabel: 'TMLE'),
  ];
}

TeamCapContext _capContext(
    NbaTerminalSeedSnapshot data, String team, String year) {
  final rosterSalary = _roster(data, team)
      .take(15)
      .fold<double>(0, (sum, row) => sum + _salary(row));
  final years = ['2024-25', '2025-26', '2026-27', '2027-28', '2028-29'];
  final index = years.indexOf(year);
  final growth = index <= 0 ? 0.0 : index * 0.035;
  return TeamCapContext(
    team: team,
    teamSalary: rosterSalary,
    salaryCap: 141000000 * (1 + growth),
    taxLine: 171000000 * (1 + growth),
    firstApron: 178000000 * (1 + growth),
    secondApron: 189000000 * (1 + growth),
  );
}

List<String> _teamIds(NbaTerminalSeedSnapshot data) {
  final values = data.teamRecords
      .map((row) => _text(row['team_id']))
      .where((value) => value != '—')
      .toSet()
      .toList();
  values.sort();
  return values;
}

List<Map<String, dynamic>> _roster(
    NbaTerminalSeedSnapshot data, String team) {
  final values = data.playerSeasonTotals
      .where((row) => _text(row['team_ids']).contains(team))
      .toList();
  values.sort((a, b) => _salary(b).compareTo(_salary(a)));
  return values;
}

double _salary(Map<String, dynamic> row) {
  final ppg = _perGame(row, 'points', 'points_per_game');
  final mpg = _perGame(row, 'minutes', 'minutes_per_game');
  final bpm = _number(row['avg_bpm']);
  final value =
      2100000 + ppg * 1200000 + mpg * 220000 + (bpm > 0 ? bpm * 900000 : 0);
  return value < 2100000 ? 2100000 : value;
}

double _perGame(Map<String, dynamic> row, String totalKey, String perKey) {
  final direct = _number(row[perKey]);
  if (direct > 0) return direct;
  final games = _number(row['games']);
  return games > 0 ? _number(row[totalKey]) / games : 0;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(
          (value ?? '').toString().replaceAll(',', '').replaceAll('%', '')) ??
      0;
}

String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _decimal(double value) => value.toStringAsFixed(1);

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final raw = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '$sign\$${buffer.toString()}';
}

String _position(double salary, double threshold, String label) {
  final delta = threshold - salary;
  return delta >= 0
      ? '${_money(delta)} below $label'
      : '${_money(delta.abs())} above $label';
}

String _apron(double salary, TeamCapContext context) {
  if (salary > context.secondApron) return 'Above second apron';
  if (salary > context.firstApron) return 'Above first apron';
  return 'Below first apron';
}

Map<String, String> _decodeMap(String? encoded) {
  final result = <String, String>{};
  if (encoded == null || encoded.isEmpty) return result;
  for (final pair in encoded.split('|')) {
    final index = pair.indexOf('>');
    if (index <= 0 || index >= pair.length - 1) continue;
    result[pair.substring(0, index)] = pair.substring(index + 1);
  }
  return result;
}

String _encodeMap(Map<String, String> values) {
  final entries = values.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => '${entry.key}>${entry.value}').join('|');
}

InputDecoration _decoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _soft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _line),
      ),
    );
