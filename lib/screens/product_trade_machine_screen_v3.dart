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

class _ProductTradeMachineScreenState
    extends State<ProductTradeMachineScreen> {
  final ProductLocalStore store = const ProductLocalStore();
  final TradeMachineEngine engine = const TradeMachineEngine();
  final TextEditingController scenarioController =
      TextEditingController(text: 'Untitled multi-team scenario');

  late final Future<NbaTerminalSeedSnapshot> seedFuture;
  String year = '2026-27';
  List<String> selectedTeams = ['BOS', 'PHI'];
  Map<String, String> destinations = {};
  Map<String, String> tabs = {};
  bool selectedOnly = false;

  @override
  void initState() {
    super.initState();
    seedFuture = const NbaTerminalSeedRepository().load();
    _restore();
  }

  @override
  void dispose() {
    scenarioController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final saved = await store.loadStringMap(
      ProductLocalStore.tradeMachineStateKey,
    );
    if (!mounted || saved.isEmpty) return;
    final teams = (saved['teams'] ?? '')
        .split('|')
        .where((team) => team.isNotEmpty)
        .toList();
    setState(() {
      year = saved['year'] ?? year;
      if (teams.length >= 2) selectedTeams = teams;
      scenarioController.text = saved['name'] ?? scenarioController.text;
      destinations = _decode(saved['destinations']);
      tabs = _decode(saved['tabs']);
      selectedOnly = saved['selectedOnly'] == 'true';
    });
  }

  Future<void> _persist({bool announce = false}) async {
    await store.saveStringMap(
      ProductLocalStore.tradeMachineStateKey,
      {
        'year': year,
        'teams': selectedTeams.join('|'),
        'name': scenarioController.text.trim(),
        'destinations': _encode(destinations),
        'tabs': _encode(tabs),
        'selectedOnly': '$selectedOnly',
      },
    );
    if (!announce || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trade scenario saved locally.')),
    );
  }

  Future<void> _setDestination(String id, String? destination) async {
    setState(() {
      if (destination == null || destination.isEmpty) {
        destinations.remove(id);
      } else {
        destinations[id] = destination;
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
      selectedTeams = selectedTeams.where((item) => item != team).toList();
      destinations.removeWhere(
        (id, destination) => id.startsWith('$team:') || destination == team,
      );
      tabs.remove(team);
    });
    await _persist();
  }

  Future<void> _reset() async {
    setState(() {
      destinations = {};
      tabs = {};
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
            child: Text(
              'Loading trade machine...',
              style: TextStyle(color: _muted),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _Surface(
            child: Text(
              'Trade machine data unavailable: ${snapshot.error}',
              style: const TextStyle(color: _muted),
            ),
          );
        }

        final data = snapshot.data!;
        final allTeams = _teamIds(data);
        _ensureSelectedTeams(allTeams);
        final catalog = _catalog(data, selectedTeams);
        destinations.removeWhere(
          (id, destination) =>
              !catalog.containsKey(id) || !selectedTeams.contains(destination),
        );
        final scenario = _scenario(data, catalog);
        final report = engine.validate(scenario);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              year: year,
              teams: selectedTeams.length,
              assets: scenario.assignments.length,
            ),
            const SizedBox(height: 18),
            _ScenarioControls(
              controller: scenarioController,
              year: year,
              selectedOnly: selectedOnly,
              onYear: (value) {
                if (value == null) return;
                setState(() => year = value);
                _persist();
              },
              onSelectedOnly: (value) {
                setState(() => selectedOnly = value);
                _persist();
              },
              onSave: () => _persist(announce: true),
              onReset: _reset,
            ),
            const SizedBox(height: 18),
            _TeamSelector(
              allTeams: allTeams,
              selectedTeams: selectedTeams,
              onAdd: _addTeam,
              onRemove: _removeTeam,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final useColumns =
                    constraints.maxWidth >= 1180 && selectedTeams.length == 2;
                final boards = [
                  for (final team in selectedTeams)
                    _TeamBoard(
                      team: team,
                      data: data,
                      selectedTeams: selectedTeams,
                      activeTab: tabs[team] ?? _AssetCategory.roster.label,
                      destinations: destinations,
                      selectedOnly: selectedOnly,
                      onTab: (value) {
                        setState(() => tabs[team] = value);
                        _persist();
                      },
                      onDestination: _setDestination,
                    ),
                ];
                if (!useColumns) {
                  return Column(
                    children: [
                      for (final board in boards) ...[
                        board,
                        const SizedBox(height: 18),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: boards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: boards[1]),
                  ],
                );
              },
            ),
            _ValidationPanel(scenario: scenario, report: report),
            const SizedBox(height: 18),
            _CapTracker(report: report, contexts: scenario.capContexts),
          ],
        );
      },
    );
  }

  void _ensureSelectedTeams(List<String> allTeams) {
    final valid = selectedTeams.where(allTeams.contains).toList();
    for (final fallback in const ['BOS', 'PHI']) {
      if (valid.length >= 2) break;
      if (allTeams.contains(fallback) && !valid.contains(fallback)) {
        valid.add(fallback);
      }
    }
    if (valid.length < 2) {
      for (final team in allTeams) {
        if (!valid.contains(team)) valid.add(team);
        if (valid.length == 2) break;
      }
    }
    if (valid.join('|') != selectedTeams.join('|')) {
      selectedTeams = valid;
    }
  }

  TradeScenario _scenario(
    NbaTerminalSeedSnapshot data,
    Map<String, _AssetView> catalog,
  ) {
    final assignments = <TradeAssignment>[];
    for (final entry in destinations.entries) {
      final asset = catalog[entry.key];
      if (asset == null || !selectedTeams.contains(entry.value)) continue;
      assignments.add(
        TradeAssignment(asset: asset.asset, destinationTeam: entry.value),
      );
    }
    return TradeScenario(
      id: 'local-trade-scenario',
      name: scenarioController.text.trim().isEmpty
          ? 'Untitled multi-team scenario'
          : scenarioController.text.trim(),
      operatingSeason: year,
      teams: List<String>.from(selectedTeams),
      assignments: assignments,
      capContexts: {
        for (final team in selectedTeams) team: _capContext(data, team),
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
            'NBA TRADE MACHINE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Build, route and review multi-team transactions.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Players, picks, rights, cash and exceptions share one scenario model. Current salary values are transparent proxies until the contract warehouse is connected.',
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
              _HeroChip(year),
              _HeroChip('$teams TEAMS'),
              _HeroChip('$assets ROUTED ASSETS'),
              const _HeroChip('CAP + APRON REVIEW'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioControls extends StatelessWidget {
  const _ScenarioControls({
    required this.controller,
    required this.year,
    required this.selectedOnly,
    required this.onYear,
    required this.onSelectedOnly,
    required this.onSave,
    required this.onReset,
  });

  final TextEditingController controller;
  final String year;
  final bool selectedOnly;
  final ValueChanged<String?> onYear;
  final ValueChanged<bool> onSelectedOnly;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            'Scenario control center',
            'Name, save, filter and reset the current local transaction scenario.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              final nameField = TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Scenario name',
                  filled: true,
                  fillColor: _soft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
              final yearField = DropdownButtonFormField<String>(
                value: year,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Operating year',
                  filled: true,
                  fillColor: _soft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: [
                  for (final option in const [
                    '2024-25',
                    '2025-26',
                    '2026-27',
                    '2027-28',
                  ])
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: onYear,
              );
              if (compact) {
                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 10),
                    yearField,
                    const SizedBox(height: 10),
                    _ScenarioButtons(
                      selectedOnly: selectedOnly,
                      onSelectedOnly: onSelectedOnly,
                      onSave: onSave,
                      onReset: onReset,
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: nameField),
                      const SizedBox(width: 12),
                      SizedBox(width: 210, child: yearField),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ScenarioButtons(
                    selectedOnly: selectedOnly,
                    onSelectedOnly: onSelectedOnly,
                    onSave: onSave,
                    onReset: onReset,
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

class _ScenarioButtons extends StatelessWidget {
  const _ScenarioButtons({
    required this.selectedOnly,
    required this.onSelectedOnly,
    required this.onSave,
    required this.onReset,
  });

  final bool selectedOnly;
  final ValueChanged<bool> onSelectedOnly;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          selected: selectedOnly,
          onSelected: onSelectedOnly,
          label: const Text('Selected assets only'),
        ),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Save scenario'),
        ),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}

class _TeamSelector extends StatefulWidget {
  const _TeamSelector({
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
  State<_TeamSelector> createState() => _TeamSelectorState();
}

class _TeamSelectorState extends State<_TeamSelector> {
  String? pendingTeam;

  @override
  Widget build(BuildContext context) {
    final available = widget.allTeams
        .where((team) => !widget.selectedTeams.contains(team))
        .toList();
    if (pendingTeam != null && !available.contains(pendingTeam)) {
      pendingTeam = null;
    }
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            'Participating teams',
            'A scenario requires at least two teams and can expand beyond a two-team trade.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final team in widget.selectedTeams)
                InputChip(
                  label: Text(team),
                  selected: true,
                  onDeleted: widget.selectedTeams.length > 2
                      ? () => widget.onRemove(team)
                      : null,
                ),
            ],
          ),
          if (available.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final dropdown = DropdownButtonFormField<String>(
                  value: pendingTeam,
                  isExpanded: true,
                  hint: const Text('Add another team'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _soft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    for (final team in available)
                      DropdownMenuItem(value: team, child: Text(team)),
                  ],
                  onChanged: (value) => setState(() => pendingTeam = value),
                );
                if (constraints.maxWidth < 460) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dropdown,
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: pendingTeam == null
                            ? null
                            : () {
                                widget.onAdd(pendingTeam!);
                                setState(() => pendingTeam = null);
                              },
                        child: const Text('Add team'),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 260, child: dropdown),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: pendingTeam == null
                          ? null
                          : () {
                              widget.onAdd(pendingTeam!);
                              setState(() => pendingTeam = null);
                            },
                      child: const Text('Add team'),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamBoard extends StatelessWidget {
  const _TeamBoard({
    required this.team,
    required this.data,
    required this.selectedTeams,
    required this.activeTab,
    required this.destinations,
    required this.selectedOnly,
    required this.onTab,
    required this.onDestination,
  });

  final String team;
  final NbaTerminalSeedSnapshot data;
  final List<String> selectedTeams;
  final String activeTab;
  final Map<String, String> destinations;
  final bool selectedOnly;
  final ValueChanged<String> onTab;
  final Future<void> Function(String, String?) onDestination;

  @override
  Widget build(BuildContext context) {
    final category = _AssetCategory.values.firstWhere(
      (value) => value.label == activeTab,
      orElse: () => _AssetCategory.roster,
    );
    var assets = _assets(data, team, category);
    if (selectedOnly) {
      assets = assets.where((asset) => destinations.containsKey(asset.asset.id)).toList();
    }

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$team transaction board',
            style: const TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _CapStrip(context: _capContext(data, team)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in _AssetCategory.values) ...[
                  ChoiceChip(
                    label: Text(option.label),
                    selected: option == category,
                    onSelected: (_) => onTab(option.label),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (assets.isEmpty)
            const Text(
              'No assets match this view.',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
            )
          else
            for (final asset in assets)
              _AssetRow(
                asset: asset,
                teams: selectedTeams.where((item) => item != team).toList(),
                destination: destinations[asset.asset.id],
                onChanged: (value) => onDestination(asset.asset.id, value),
              ),
        ],
      ),
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

  final _AssetView asset;
  final List<String> teams;
  final String? destination;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final selector = DropdownButtonFormField<String>(
            value: teams.contains(destination) ? destination : null,
            isExpanded: true,
            hint: const Text('Destination', overflow: TextOverflow.ellipsis),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _soft,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              for (final team in teams)
                DropdownMenuItem(
                  value: team,
                  child: Text(team, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: teams.isEmpty ? null : onChanged,
          );
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset.asset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                asset.detail,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          final value = asset.asset.salary > 0
              ? _money(asset.asset.salary)
              : asset.typeLabel;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                selector,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 150, child: selector),
            ],
          );
        },
      ),
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
        .where((finding) => finding.severity == TradeValidationSeverity.error)
        .length;
    final warnings = report.findings
        .where((finding) => finding.severity == TradeValidationSeverity.warning)
        .length;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            'Scenario validation',
            '${scenario.assignments.length} routed assets • $errors errors • $warnings warnings',
          ),
          const SizedBox(height: 12),
          if (report.findings.isEmpty)
            const Text(
              'No structural findings. Full CBA validation still requires current contracts and versioned league rules.',
              style: TextStyle(color: _green, fontWeight: FontWeight.w800),
            )
          else
            for (final finding in report.findings)
              _FindingRow(finding: finding),
        ],
      ),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final TradeValidationFinding finding;

  @override
  Widget build(BuildContext context) {
    final color = switch (finding.severity) {
      TradeValidationSeverity.error => _red,
      TradeValidationSeverity.warning => _orange,
      TradeValidationSeverity.info => _blue,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              finding.message,
              style: const TextStyle(
                color: _ink,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapTracker extends StatelessWidget {
  const _CapTracker({required this.report, required this.contexts});

  final TradeValidationReport report;
  final Map<String, TeamCapContext> contexts;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            'Post-trade financial tracker',
            'Salary proxy movement is separated from future authoritative contract and CBA data.',
          ),
          const SizedBox(height: 12),
          for (final entry in report.teamSummaries.entries)
            _TeamSummary(
              summary: entry.value,
              context: contexts[entry.key],
            ),
        ],
      ),
    );
  }
}

class _TeamSummary extends StatelessWidget {
  const _TeamSummary({required this.summary, required this.context});

  final TeamTradeSummary summary;
  final TeamCapContext? context;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _Metric(summary.team, 'Team'),
          _Metric(_money(summary.outgoingSalary), 'Outgoing'),
          _Metric(_money(summary.incomingSalary), 'Incoming'),
          _Metric(_money(summary.postTradeSalary), 'Post-trade salary'),
          if (this.context != null)
            _Metric(
              _money(this.context!.secondApron - summary.postTradeSalary),
              'Second-apron room',
            ),
        ],
      ),
    );
  }
}

class _CapStrip extends StatelessWidget {
  const _CapStrip({required this.context});

  final TeamCapContext context;

  @override
  Widget build(BuildContext context) {
    final metrics = {
      'Cap': this.context.salaryCap - this.context.teamSalary,
      'Tax': this.context.taxLine - this.context.teamSalary,
      '1st apron': this.context.firstApron - this.context.teamSalary,
      '2nd apron': this.context.secondApron - this.context.teamSalary,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 620
            ? (constraints.maxWidth - 24) / 4
            : constraints.maxWidth >= 340
                ? (constraints.maxWidth - 8) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in metrics.entries)
              SizedBox(
                width: width,
                child: _CapMetric(label: metric.key, value: metric.value),
              ),
          ],
        );
      },
    );
  }
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _money(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: positive ? _green : _red,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      ],
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

enum _AssetCategory {
  roster('Active Roster'),
  picks('Draft Picks'),
  rights('Draft Rights'),
  cash('Cash'),
  freeAgents('Free Agents'),
  exceptions('Exceptions');

  const _AssetCategory(this.label);
  final String label;
}

class _AssetView {
  const _AssetView({
    required this.asset,
    required this.detail,
    required this.typeLabel,
  });

  final TradeAsset asset;
  final String detail;
  final String typeLabel;
}

Map<String, _AssetView> _catalog(
  NbaTerminalSeedSnapshot data,
  List<String> teams,
) {
  final result = <String, _AssetView>{};
  for (final team in teams) {
    for (final category in _AssetCategory.values) {
      for (final asset in _assets(data, team, category)) {
        result[asset.asset.id] = asset;
      }
    }
  }
  return result;
}

List<_AssetView> _assets(
  NbaTerminalSeedSnapshot data,
  String team,
  _AssetCategory category,
) {
  if (category == _AssetCategory.roster) {
    final roster = data.playerSeasonTotals
        .where((row) => _text(row['team_ids']).contains(team))
        .toList()
      ..sort((a, b) => _salary(b).compareTo(_salary(a)));
    return [
      for (final row in roster.take(10))
        _AssetView(
          asset: TradeAsset(
            id: '$team:player:${_text(row['player_id'])}',
            type: TradeAssetType.player,
            label: _text(row['player_label']),
            originTeam: team,
            salary: _salary(row),
          ),
          detail:
              '${_perGame(row, 'points', 'points_per_game').toStringAsFixed(1)} PPG • ${_perGame(row, 'minutes', 'minutes_per_game').toStringAsFixed(1)} MPG',
          typeLabel: 'Player',
        ),
    ];
  }
  if (category == _AssetCategory.picks) {
    return [
      _simpleAsset(team, 'pick-2027-1', '2027 first-round pick', TradeAssetType.draftPick),
      _simpleAsset(team, 'pick-2028-2', '2028 second-round pick', TradeAssetType.draftPick),
      _simpleAsset(team, 'swap-2029', '2029 first-round swap', TradeAssetType.draftPick),
    ];
  }
  if (category == _AssetCategory.rights) {
    return [
      _simpleAsset(team, 'rights-intl', 'International draft rights', TradeAssetType.draftRights),
      _simpleAsset(team, 'rights-r2', 'Unsigned second-round rights', TradeAssetType.draftRights),
    ];
  }
  if (category == _AssetCategory.cash) {
    return [
      _simpleAsset(team, 'cash', 'Cash considerations', TradeAssetType.cash),
    ];
  }
  if (category == _AssetCategory.freeAgents) {
    return [
      _simpleAsset(team, 'bird-rights', 'Bird rights / cap hold', TradeAssetType.freeAgentRights),
    ];
  }
  return [
    _simpleAsset(team, 'tpe', 'Trade exception', TradeAssetType.tradeException),
    _simpleAsset(team, 'ntmle', 'Non-taxpayer MLE', TradeAssetType.signingException),
    _simpleAsset(team, 'tmle', 'Taxpayer MLE', TradeAssetType.signingException),
  ];
}

_AssetView _simpleAsset(
  String team,
  String suffix,
  String label,
  TradeAssetType type,
) {
  return _AssetView(
    asset: TradeAsset(
      id: '$team:$suffix',
      type: type,
      label: '$team $label',
      originTeam: team,
    ),
    detail: 'Prototype asset slot; authoritative data feed pending',
    typeLabel: label,
  );
}

TeamCapContext _capContext(NbaTerminalSeedSnapshot data, String team) {
  final roster = data.playerSeasonTotals
      .where((row) => _text(row['team_ids']).contains(team));
  final salary = roster.fold<double>(0, (sum, row) => sum + _salary(row));
  return TeamCapContext(
    team: team,
    teamSalary: salary,
    salaryCap: 141000000,
    taxLine: 171000000,
    firstApron: 178000000,
    secondApron: 189000000,
  );
}

List<String> _teamIds(NbaTerminalSeedSnapshot data) {
  final teams = data.teamRecords
      .map((row) => _text(row['team_id']))
      .where((team) => team != '—')
      .toSet()
      .toList()
    ..sort();
  return teams;
}

double _salary(Map<String, dynamic> row) {
  final ppg = _perGame(row, 'points', 'points_per_game');
  final mpg = _perGame(row, 'minutes', 'minutes_per_game');
  final bpm = _number(row['avg_bpm']);
  final salary = 2100000 + ppg * 1200000 + mpg * 220000 + (bpm > 0 ? bpm * 900000 : 0);
  return salary < 2100000 ? 2100000 : salary;
}

double _perGame(Map<String, dynamic> row, String totalKey, String perGameKey) {
  final direct = _nullableNumber(row[perGameKey]);
  if (direct != null) return direct;
  final games = _nullableNumber(row['games']);
  final total = _nullableNumber(row[totalKey]);
  if (games == null || games <= 0 || total == null) return 0;
  return total / games;
}

double _number(Object? value) => _nullableNumber(value) ?? 0;

double? _nullableNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '').replaceAll('%', ''));
}

String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs().round().toString();
  final output = StringBuffer();
  for (var index = 0; index < amount.length; index++) {
    if (index > 0 && (amount.length - index) % 3 == 0) output.write(',');
    output.write(amount[index]);
  }
  return '$sign\$${output.toString()}';
}

String _encode(Map<String, String> values) {
  return values.entries
      .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
      .join('&');
}

Map<String, String> _decode(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final result = <String, String>{};
  for (final pair in raw.split('&')) {
    final index = pair.indexOf('=');
    if (index <= 0) continue;
    final key = Uri.decodeComponent(pair.substring(0, index));
    final value = Uri.decodeComponent(pair.substring(index + 1));
    result[key] = value;
  }
  return result;
}
