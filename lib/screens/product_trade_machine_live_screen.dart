import 'package:flutter/material.dart';

import '../services/nba_trade_contract_repository.dart';
import '../services/product_local_store.dart';
import '../services/trade_machine_engine.dart';

const _bg = Color(0xFF08111D);
const _panel = Color(0xFF0D1927);
const _panel2 = Color(0xFF122235);
const _line = Color(0xFF20364D);
const _text = Color(0xFFF4F7FB);
const _muted = Color(0xFF91A2B5);
const _blue = Color(0xFF62A9FF);
const _cyan = Color(0xFF58D6D1);
const _green = Color(0xFF65D19E);
const _amber = Color(0xFFF2C66D);
const _red = Color(0xFFFF7C83);

const _salaryCap = 166000000.0;
const _taxLine = 201690000.0;
const _firstApron = 210690000.0;
const _secondApron = 223690000.0;
const _nonTaxMle = 15139000.0;
const _taxMle = 6102000.0;
const _roomMle = 9425000.0;
const _bae = 5511000.0;

class ProductTradeMachineLiveScreen extends StatefulWidget {
  const ProductTradeMachineLiveScreen({super.key});

  @override
  State<ProductTradeMachineLiveScreen> createState() =>
      _ProductTradeMachineLiveScreenState();
}

class _ProductTradeMachineLiveScreenState
    extends State<ProductTradeMachineLiveScreen> {
  final _repo = const NbaTradeContractRepository();
  final _engine = const TradeMachineEngine();
  final _store = const ProductLocalStore();
  final _scenarioController =
      TextEditingController(text: 'Untitled 2026-27 trade');
  late final Future<NbaTradeContractSnapshot> _future;

  final String season = '2026-27';
  List<String> teams = const ['BOS', 'PHI'];
  final Map<String, String> routes = {};
  final Map<String, String> searches = {};
  bool routedOnly = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.load();
    _restore();
  }

  @override
  void dispose() {
    _scenarioController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final saved =
        await _store.loadStringMap(ProductLocalStore.tradeMachineStateKey);
    if (!mounted || saved.isEmpty) return;
    final restoredTeams = (saved['teams'] ?? '')
        .split('|')
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
    setState(() {
      if (restoredTeams.length >= 2) teams = restoredTeams;
      _scenarioController.text = saved['name'] ?? _scenarioController.text;
      routes
        ..clear()
        ..addAll(_decode(saved['destinations']));
      routedOnly = saved['selectedOnly'] == 'true';
    });
  }

  Future<void> _save({bool announce = false}) async {
    await _store.saveStringMap(ProductLocalStore.tradeMachineStateKey, {
      'year': season,
      'teams': teams.join('|'),
      'name': _scenarioController.text.trim(),
      'destinations': _encode(routes),
      'tabs': '',
      'selectedOnly': '$routedOnly',
    });
    if (announce && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trade scenario saved locally.')),
      );
    }
  }

  void _route(String playerId, String? destination) {
    setState(() {
      if (destination == null || destination.isEmpty) {
        routes.remove(playerId);
      } else {
        routes[playerId] = destination;
      }
    });
    _save();
  }

  void _reset() {
    setState(() {
      routes.clear();
      searches.clear();
      routedOnly = false;
      _scenarioController.text = 'Untitled 2026-27 trade';
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTradeContractSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Surface(
            child: SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _Surface(
            child: Text(
              '2026-27 contract data unavailable: ${snapshot.error}',
              style: const TextStyle(color: _red),
            ),
          );
        }
        final data = snapshot.data!;
        _repairTeams(data.teams);
        routes.removeWhere((id, destination) =>
            !data.records.any((row) => row.id == id) ||
            !teams.contains(destination));
        final scenario = _scenario(data);
        final report = _engine.validate(scenario);

        return ColoredBox(
          color: _bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                rosterCount: data.records.length,
                teamCount: teams.length,
                routedCount: routes.length,
                asOf: data.asOf,
              ),
              const SizedBox(height: 12),
              _Controls(
                controller: _scenarioController,
                routedOnly: routedOnly,
                onRoutedOnly: (value) {
                  setState(() => routedOnly = value);
                  _save();
                },
                onSave: () => _save(announce: true),
                onReset: _reset,
              ),
              const SizedBox(height: 12),
              const _CapEnvironment(),
              const SizedBox(height: 12),
              _TeamPicker(
                allTeams: data.teams,
                teams: teams,
                onAdd: (team) {
                  if (teams.length >= 5 || teams.contains(team)) return;
                  setState(() => teams = [...teams, team]);
                  _save();
                },
                onRemove: (team) {
                  if (teams.length <= 2) return;
                  setState(() {
                    teams = teams.where((item) => item != team).toList();
                    routes.removeWhere((id, destination) =>
                        id.startsWith('$team:') || destination == team);
                  });
                  _save();
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 1040;
                  final boards = [
                    for (final team in teams)
                      _TeamBoard(
                        team: team,
                        teams: teams,
                        rows: data.forTeam(team, season),
                        payroll: data.payroll(team, season),
                        query: searches[team] ?? '',
                        routedOnly: routedOnly,
                        routes: routes,
                        onSearch: (value) =>
                            setState(() => searches[team] = value),
                        onRoute: _route,
                      ),
                  ];
                  if (!twoColumns) {
                    return Column(
                      children: [
                        for (var i = 0; i < boards.length; i++) ...[
                          boards[i],
                          if (i != boards.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final board in boards)
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: board,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _TradeFlow(teams: teams, data: data, routes: routes),
              const SizedBox(height: 12),
              _Validation(report: report),
              const SizedBox(height: 12),
              _FinancialSummary(report: report),
              const SizedBox(height: 12),
              _DataBoundary(note: data.sourceNote),
            ],
          ),
        );
      },
    );
  }

  TradeScenario _scenario(NbaTradeContractSnapshot data) {
    final assignments = <TradeAssignment>[];
    for (final entry in routes.entries) {
      NbaTradeContract? player;
      for (final row in data.records) {
        if (row.id == entry.key) {
          player = row;
          break;
        }
      }
      if (player == null || !teams.contains(entry.value)) continue;
      assignments.add(
        TradeAssignment(
          asset: TradeAsset(
            id: player.id,
            type: TradeAssetType.player,
            label: player.player,
            originTeam: player.team,
            salary: player.salaryFor(season),
            metadata: {
              'source_status': player.sourceStatus,
              'guaranteed_amount': player.guaranteed,
            },
          ),
          destinationTeam: entry.value,
        ),
      );
    }
    return TradeScenario(
      id: 'sports-terminal-live-2026-27',
      name: _scenarioController.text.trim().isEmpty
          ? 'Untitled 2026-27 trade'
          : _scenarioController.text.trim(),
      operatingSeason: season,
      asOfDateIso: DateTime.now().toUtc().toIso8601String(),
      teams: List<String>.from(teams),
      assignments: assignments,
      capContexts: {
        for (final team in teams)
          team: TeamCapContext(
            team: team,
            teamSalary: data.payroll(team, season),
            salaryCap: _salaryCap,
            taxLine: _taxLine,
            firstApron: _firstApron,
            secondApron: _secondApron,
            standardRosterPlayers: data.forTeam(team, season).length,
          ),
      },
    );
  }

  void _repairTeams(List<String> allTeams) {
    final valid = teams.where(allTeams.contains).toList();
    for (final fallback in const ['BOS', 'PHI']) {
      if (valid.length >= 2) break;
      if (allTeams.contains(fallback) && !valid.contains(fallback)) {
        valid.add(fallback);
      }
    }
    for (final team in allTeams) {
      if (valid.length >= 2) break;
      if (!valid.contains(team)) valid.add(team);
    }
    if (valid.join('|') != teams.join('|')) teams = valid.take(5).toList();
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.rosterCount,
    required this.teamCount,
    required this.routedCount,
    required this.asOf,
  });

  final int rosterCount;
  final int teamCount;
  final int routedCount;
  final String asOf;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SPORTS TERMINAL / FRONT OFFICE',
              style: TextStyle(
                color: _cyan,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'NBA Trade Machine',
              style: TextStyle(
                color: _text,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Build two- through five-team trades against the 2026-27 salary environment. Every routed player updates matching salary, projected team salary, apron status, roster count, and the CBA validation stack in real time.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const _Pill('2026-27', _blue),
                _Pill('$rosterCount CONTRACT ROWS', _green),
                _Pill('$teamCount TEAMS', _cyan),
                _Pill('$routedCount ROUTED', _amber),
                _Pill('AS OF $asOf', _muted),
              ],
            ),
          ],
        ),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.routedOnly,
    required this.onRoutedOnly,
    required this.onSave,
    required this.onReset,
  });

  final TextEditingController controller;
  final bool routedOnly;
  final ValueChanged<bool> onRoutedOnly;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: controller,
                style: const TextStyle(color: _text),
                decoration: const InputDecoration(
                  labelText: 'Scenario name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(
              width: 150,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Operating year',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text('2026-27'),
              ),
            ),
            FilterChip(
              label: const Text('Routed only'),
              selected: routedOnly,
              onSelected: onRoutedOnly,
            ),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset'),
            ),
          ],
        ),
      );
}

class _CapEnvironment extends StatelessWidget {
  const _CapEnvironment();

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Section('2026-27 CAP ENVIRONMENT'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _MetricCard('SALARY CAP', _salaryCap),
                _MetricCard('LUXURY TAX', _taxLine),
                _MetricCard('1ST APRON', _firstApron),
                _MetricCard('2ND APRON', _secondApron),
                _MetricCard('NON-TAX MLE', _nonTaxMle),
                _MetricCard('TAX MLE', _taxMle),
                _MetricCard('ROOM MLE', _roomMle),
                _MetricCard('BI-ANNUAL', _bae),
              ],
            ),
          ],
        ),
      );
}

class _TeamPicker extends StatefulWidget {
  const _TeamPicker({
    required this.allTeams,
    required this.teams,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> allTeams;
  final List<String> teams;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_TeamPicker> createState() => _TeamPickerState();
}

class _TeamPickerState extends State<_TeamPicker> {
  String? pending;

  @override
  Widget build(BuildContext context) {
    final available =
        widget.allTeams.where((team) => !widget.teams.contains(team)).toList();
    if (pending != null && !available.contains(pending)) pending = null;
    return _Surface(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _Section('PARTICIPATING TEAMS'),
          for (final team in widget.teams)
            InputChip(
              label: Text(team),
              avatar: const Icon(Icons.sports_basketball_rounded, size: 16),
              onDeleted: widget.teams.length > 2
                  ? () => widget.onRemove(team)
                  : null,
            ),
          if (widget.teams.length < 5 && available.isNotEmpty)
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: pending,
                hint: const Text('Add team'),
                isDense: true,
                items: [
                  for (final team in available)
                    DropdownMenuItem(value: team, child: Text(team)),
                ],
                onChanged: (value) => setState(() => pending = value),
              ),
            ),
          if (widget.teams.length < 5)
            FilledButton(
              onPressed: pending == null
                  ? null
                  : () {
                      widget.onAdd(pending!);
                      setState(() => pending = null);
                    },
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }
}

class _TeamBoard extends StatelessWidget {
  const _TeamBoard({
    required this.team,
    required this.teams,
    required this.rows,
    required this.payroll,
    required this.query,
    required this.routedOnly,
    required this.routes,
    required this.onSearch,
    required this.onRoute,
  });

  final String team;
  final List<String> teams;
  final List<NbaTradeContract> rows;
  final double payroll;
  final String query;
  final bool routedOnly;
  final Map<String, String> routes;
  final ValueChanged<String> onSearch;
  final void Function(String, String?) onRoute;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    var filtered = rows.where(
      (row) => q.isEmpty || row.player.toLowerCase().contains(q),
    );
    if (routedOnly) {
      filtered = filtered.where((row) => routes.containsKey(row.id));
    }
    final shown = filtered.toList();
    final capStatus = _statusFor(payroll);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TeamMonogram(team),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${rows.length} salary rows · ${_money(payroll)} active-contract payroll',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              _Pill(capStatus.$1, capStatus.$2),
            ],
          ),
          const SizedBox(height: 10),
          _CapBar(value: payroll),
          const SizedBox(height: 10),
          TextField(
            onChanged: onSearch,
            style: const TextStyle(color: _text),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search roster',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'PLAYER',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  '2026-27',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 140,
                child: Text(
                  'DESTINATION',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: _line),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No players match this filter.',
                style: TextStyle(color: _muted),
              ),
            ),
          for (final row in shown)
            _PlayerRow(
              row: row,
              destination: routes[row.id],
              destinations: teams.where((item) => item != team).toList(),
              onChanged: (value) => onRoute(row.id, value),
            ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.row,
    required this.destination,
    required this.destinations,
    required this.onChanged,
  });

  final NbaTradeContract row;
  final String? destination;
  final List<String> destinations;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.player,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.guaranteed == null
                        ? 'Uploaded salary row'
                        : 'Guaranteed field ${_money(row.guaranteed!)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                _money(row.salaryFor('2026-27')),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                value: destinations.contains(destination) ? destination : null,
                hint: const Text('Route to…'),
                isDense: true,
                items: [
                  for (final team in destinations)
                    DropdownMenuItem(value: team, child: Text(team)),
                ],
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
}

class _TradeFlow extends StatelessWidget {
  const _TradeFlow({
    required this.teams,
    required this.data,
    required this.routes,
  });

  final List<String> teams;
  final NbaTradeContractSnapshot data;
  final Map<String, String> routes;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section('TRADE FLOW'),
            SizedBox(height: 8),
            Text(
              'Route a player from any team board to begin the transaction.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      );
    }
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Section('TRADE FLOW'),
          const SizedBox(height: 10),
          for (final team in teams)
            _FlowTeam(
              team: team,
              outgoing: data.records
                  .where((row) => row.team == team && routes.containsKey(row.id))
                  .toList(),
              incoming: data.records
                  .where((row) => routes[row.id] == team)
                  .toList(),
              routes: routes,
            ),
        ],
      ),
    );
  }
}

class _FlowTeam extends StatelessWidget {
  const _FlowTeam({
    required this.team,
    required this.outgoing,
    required this.incoming,
    required this.routes,
  });

  final String team;
  final List<NbaTradeContract> outgoing;
  final List<NbaTradeContract> incoming;
  final Map<String, String> routes;

  @override
  Widget build(BuildContext context) {
    if (outgoing.isEmpty && incoming.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panel2,
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            team,
            style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
          if (outgoing.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'SENDS  ${outgoing.map((row) => '${row.player} → ${routes[row.id]}').join('  •  ')}',
              style: const TextStyle(color: _red, fontSize: 11),
            ),
          ],
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'RECEIVES  ${incoming.map((row) => row.player).join('  •  ')}',
              style: const TextStyle(color: _green, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _Validation extends StatelessWidget {
  const _Validation({required this.report});
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) {
    final errors = report.errorCount;
    final warnings = report.warningCount;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _Section('CBA / STRUCTURAL VALIDATION')),
              _Pill(
                report.isValid ? 'STRUCTURALLY PASSES' : '$errors ERRORS',
                report.isValid ? _green : _red,
              ),
              const SizedBox(width: 6),
              _Pill('$warnings WARNINGS', warnings == 0 ? _green : _amber),
            ],
          ),
          const SizedBox(height: 10),
          for (final finding in report.findings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    finding.severity == TradeValidationSeverity.error
                        ? Icons.cancel_rounded
                        : finding.severity == TradeValidationSeverity.warning
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded,
                    size: 17,
                    color: finding.severity == TradeValidationSeverity.error
                        ? _red
                        : finding.severity == TradeValidationSeverity.warning
                            ? _amber
                            : _blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${finding.code}: ${finding.message}',
                      style: const TextStyle(color: _muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({required this.report});
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Section('POST-TRADE FINANCIALS'),
            const SizedBox(height: 10),
            for (final entry in report.teamSummaries.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _panel2,
                  border: Border.all(color: _line),
                ),
                child: Wrap(
                  spacing: 22,
                  runSpacing: 9,
                  children: [
                    _TinyMetric(entry.key, 'TEAM'),
                    _TinyMetric(_money(entry.value.outgoingSalary), 'MATCH OUT'),
                    _TinyMetric(_money(entry.value.incomingSalary), 'MATCH IN'),
                    _TinyMetric(_money(entry.value.maximumIncomingSalary), 'MAX IN'),
                    _TinyMetric(_money(entry.value.postTradeSalary), 'POST PAYROLL'),
                    _TinyMetric('${entry.value.projectedRosterPlayers}', 'ROSTER'),
                    _TinyMetric(entry.value.apronStatus.toUpperCase(), 'STATUS'),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _DataBoundary extends StatelessWidget {
  const _DataBoundary({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Section('DATA & RULE BOUNDARY'),
            const SizedBox(height: 8),
            const Text(
              'The player salary schedule is loaded directly into this trade machine, so player matching uses the uploaded 2026-27 salary values instead of a statistical salary proxy. The cap, tax and apron figures shown above are the operating figures supplied for this build.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 7),
            Text(
              '$note Contract salary alone does not establish every trade restriction. No-trade/consent rights, options, guarantee dates, trade bonuses, recently-signed/recently-traded dates, BYC/poison-pill treatment, team exceptions, dead money/cap holds, cash usage and complete draft-pick encumbrances still require authoritative transaction metadata. The rules engine is deliberately conservative when that metadata exists, and the UI does not present missing fields as verified.',
              style: const TextStyle(color: _muted, height: 1.5),
            ),
          ],
        ),
      );
}

class _CapBar extends StatelessWidget {
  const _CapBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / (_secondApron * 1.08)).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: _panel2,
          ),
        ),
        const SizedBox(height: 5),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CAP $166.0M', style: TextStyle(color: _muted, fontSize: 8)),
            Text('TAX $201.69M', style: TextStyle(color: _muted, fontSize: 8)),
            Text('1A $210.69M', style: TextStyle(color: _muted, fontSize: 8)),
            Text('2A $223.69M', style: TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
        width: 145,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _panel2,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _money(value),
              style: const TextStyle(
                color: _text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _TeamMonogram extends StatelessWidget {
  const _TeamMonogram(this.team);
  final String team;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _blue),
          color: _panel2,
        ),
        child: Text(
          team,
          style: const TextStyle(
            color: _blue,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _cyan,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _panel2,
          border: Border.all(color: color.withValues(alpha: .6)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w800,
              fontSize: 8,
            ),
          ),
        ],
      );
}

(String, Color) _statusFor(double payroll) {
  if (payroll > _secondApron) return ('2ND APRON', _red);
  if (payroll > _firstApron) return ('1ST APRON', _amber);
  if (payroll > _taxLine) return ('TAX', _amber);
  if (payroll > _salaryCap) return ('OVER CAP', _blue);
  return ('CAP SPACE', _green);
}

String _money(double value) {
  if (value.abs() >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value.abs() >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(0)}K';
  }
  return '\$${value.toStringAsFixed(0)}';
}

String _encode(Map<String, String> values) =>
    values.entries.map((entry) => '${entry.key}=>${entry.value}').join('||');

Map<String, String> _decode(String? raw) {
  final result = <String, String>{};
  if (raw == null || raw.isEmpty) return result;
  for (final item in raw.split('||')) {
    final separator = item.lastIndexOf('=>');
    if (separator <= 0) continue;
    result[item.substring(0, separator)] = item.substring(separator + 2);
  }
  return result;
}
