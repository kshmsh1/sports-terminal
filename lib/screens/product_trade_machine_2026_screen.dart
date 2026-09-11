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

const _cap = 166000000.0;
const _tax = 201690000.0;
const _first = 210690000.0;
const _second = 223690000.0;

class ProductTradeMachine2026Screen extends StatefulWidget {
  const ProductTradeMachine2026Screen({super.key});
  @override
  State<ProductTradeMachine2026Screen> createState() => _ProductTradeMachine2026ScreenState();
}

class _ProductTradeMachine2026ScreenState extends State<ProductTradeMachine2026Screen> {
  final repo = const NbaTradeContractRepository();
  final engine = const TradeMachineEngine();
  final store = const ProductLocalStore();
  late final Future<NbaTradeContractSnapshot> future;
  final routes = <String, String>{};
  final searches = <String, String>{};
  List<String> teams = ['BOS', 'PHI'];
  bool routedOnly = false;

  @override
  void initState() {
    super.initState();
    future = repo.load();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await store.loadStringMap(ProductLocalStore.tradeMachineStateKey);
    if (!mounted || saved.isEmpty) return;
    final restored = (saved['teams'] ?? '').split('|').where((e) => e.isNotEmpty).take(5).toList();
    setState(() {
      if (restored.length >= 2) teams = restored;
      routes.addAll(_decode(saved['destinations']));
      routedOnly = saved['selectedOnly'] == 'true';
    });
  }

  Future<void> _save() => store.saveStringMap(ProductLocalStore.tradeMachineStateKey, {
        'year': '2026-27',
        'teams': teams.join('|'),
        'name': '2026-27 Trade',
        'destinations': _encode(routes),
        'tabs': '',
        'selectedOnly': '$routedOnly',
      });

  void _route(String id, String? team) {
    setState(() {
      if (team == null || team.isEmpty) {
        routes.remove(id);
      } else {
        routes[id] = team;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTradeContractSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _panelBox(Center(
            child: snapshot.hasError
                ? Text('Trade data unavailable: ${snapshot.error}', style: const TextStyle(color: _red))
                : const CircularProgressIndicator(),
          ));
        }
        final data = snapshot.data!;
        _repairTeams(data.teams);
        routes.removeWhere((id, dest) => !data.records.any((p) => p.id == id) || !teams.contains(dest));
        final scenario = _scenario(data);
        final report = engine.validate(scenario);

        return ColoredBox(
          color: _bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelBox(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SPORTS TERMINAL / FRONT OFFICE',
                      style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  const SizedBox(height: 7),
                  const Text('NBA Trade Machine',
                      style: TextStyle(color: _text, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                    'Build two- through five-team trades with the uploaded 2026-27 player salaries. Salary matching, post-trade payroll, apron status and CBA findings update immediately.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    _pill('2026-27', _blue),
                    _pill('${data.records.length} SALARY ROWS', _green),
                    _pill('${teams.length} TEAMS', _cyan),
                    _pill('${routes.length} ROUTED', _amber),
                    _pill('AS OF ${data.asOf}', _muted),
                  ]),
                ],
              )),
              const SizedBox(height: 12),
              _capBox(),
              const SizedBox(height: 12),
              _teamPicker(data),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth >= 1040 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final team in teams)
                      SizedBox(width: width, child: _teamBoard(data, team)),
                  ],
                );
              }),
              const SizedBox(height: 12),
              _tradeFlow(data),
              const SizedBox(height: 12),
              _validation(report),
              const SizedBox(height: 12),
              _financials(report),
              const SizedBox(height: 12),
              _boundary(data),
            ],
          ),
        );
      },
    );
  }

  Widget _capBox() => _panelBox(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('2026-27 CAP ENVIRONMENT'),
          const SizedBox(height: 9),
          Wrap(spacing: 9, runSpacing: 9, children: const [
            _CapMetric('SALARY CAP', 166000000),
            _CapMetric('LUXURY TAX', 201690000),
            _CapMetric('1ST APRON', 210690000),
            _CapMetric('2ND APRON', 223690000),
            _CapMetric('NON-TAX MLE', 15139000),
            _CapMetric('TAX MLE', 6102000),
            _CapMetric('ROOM MLE', 9425000),
            _CapMetric('BI-ANNUAL', 5511000),
          ]),
        ],
      ));

  Widget _teamPicker(NbaTradeContractSnapshot data) {
    final available = data.teams.where((t) => !teams.contains(t)).toList();
    return _panelBox(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('PARTICIPATING TEAMS'),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final team in teams)
            InputChip(
              label: Text(team),
              onDeleted: teams.length <= 2 ? null : () {
                setState(() {
                  teams.remove(team);
                  routes.removeWhere((id, dest) => id.startsWith('$team:') || dest == team);
                });
                _save();
              },
            ),
          if (teams.length < 5)
            PopupMenuButton<String>(
              onSelected: (team) {
                setState(() => teams = [...teams, team]);
                _save();
              },
              itemBuilder: (_) => [
                for (final team in available) PopupMenuItem(value: team, child: Text(team)),
              ],
              child: const Chip(avatar: Icon(Icons.add_rounded, size: 16), label: Text('Add team')),
            ),
          FilterChip(
            label: const Text('Routed only'),
            selected: routedOnly,
            onSelected: (value) {
              setState(() => routedOnly = value);
              _save();
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset trade'),
            onPressed: () {
              setState(() {
                routes.clear();
                searches.clear();
                routedOnly = false;
              });
              _save();
            },
          ),
        ]),
      ],
    ));
  }

  Widget _teamBoard(NbaTradeContractSnapshot data, String team) {
    final payroll = data.payroll(team, '2026-27');
    final q = (searches[team] ?? '').trim().toLowerCase();
    var rows = data.forTeam(team, '2026-27')
        .where((p) => q.isEmpty || p.player.toLowerCase().contains(q));
    if (routedOnly) rows = rows.where((p) => routes.containsKey(p.id));
    final list = rows.toList();
    return _panelBox(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 38, height: 38, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _panel2, border: Border.all(color: _blue)),
            child: Text(team, style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(team, style: const TextStyle(color: _text, fontSize: 19, fontWeight: FontWeight.w900)),
            Text('${list.length} shown · ${_money(payroll)} active-contract payroll',
                style: const TextStyle(color: _muted, fontSize: 10)),
          ])),
          _pill(_tier(payroll), _tierColor(payroll)),
        ]),
        const SizedBox(height: 9),
        TextField(
          onChanged: (value) => setState(() => searches[team] = value),
          style: const TextStyle(color: _text),
          decoration: const InputDecoration(
            isDense: true, border: OutlineInputBorder(), prefixIcon: Icon(Icons.search_rounded), hintText: 'Search roster',
          ),
        ),
        const SizedBox(height: 6),
        for (final player in list)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(player.player, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
                Text(player.guaranteed == null ? 'Uploaded salary record' : 'Guaranteed field ${_money(player.guaranteed!)}',
                    overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 9)),
              ])),
              SizedBox(width: 92, child: Text(_money(player.salaryFor('2026-27')),
                  textAlign: TextAlign.right, style: const TextStyle(color: _text, fontWeight: FontWeight.w900))),
              const SizedBox(width: 8),
              SizedBox(
                width: 128,
                child: DropdownButtonFormField<String>(
                  value: teams.where((t) => t != team).contains(routes[player.id]) ? routes[player.id] : null,
                  hint: const Text('Route to…'),
                  isDense: true,
                  items: [
                    for (final destination in teams.where((t) => t != team))
                      DropdownMenuItem(value: destination, child: Text(destination)),
                  ],
                  onChanged: (value) => _route(player.id, value),
                ),
              ),
            ]),
          ),
      ],
    ));
  }

  Widget _tradeFlow(NbaTradeContractSnapshot data) => _panelBox(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('TRADE FLOW'),
          const SizedBox(height: 8),
          if (routes.isEmpty)
            const Text('Route a player to start building the transaction.', style: TextStyle(color: _muted))
          else
            for (final team in teams)
              if (data.records.any((p) => (p.team == team && routes.containsKey(p.id)) || routes[p.id] == team))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(team, style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
                    Text(
                      'Sends: ${data.records.where((p) => p.team == team && routes.containsKey(p.id)).map((p) => '${p.player} → ${routes[p.id]}').join(' • ')}',
                      style: const TextStyle(color: _red, fontSize: 10),
                    ),
                    Text(
                      'Receives: ${data.records.where((p) => routes[p.id] == team).map((p) => p.player).join(' • ')}',
                      style: const TextStyle(color: _green, fontSize: 10),
                    ),
                  ]),
                ),
        ],
      ));

  Widget _validation(TradeValidationReport report) => _panelBox(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _section('CBA / STRUCTURAL VALIDATION')),
            _pill(report.isValid ? 'PASS' : '${report.errorCount} ERRORS', report.isValid ? _green : _red),
            const SizedBox(width: 6),
            _pill('${report.warningCount} WARNINGS', report.warningCount == 0 ? _green : _amber),
          ]),
          const SizedBox(height: 8),
          for (final finding in report.findings)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text('${finding.code}: ${finding.message}',
                  style: TextStyle(
                    color: finding.severity == TradeValidationSeverity.error
                        ? _red
                        : finding.severity == TradeValidationSeverity.warning ? _amber : _muted,
                    height: 1.35,
                  )),
            ),
        ],
      ));

  Widget _financials(TradeValidationReport report) => _panelBox(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('POST-TRADE FINANCIALS'),
          const SizedBox(height: 8),
          for (final entry in report.teamSummaries.entries)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
              child: Wrap(spacing: 20, runSpacing: 7, children: [
                _mini(entry.key, 'TEAM'),
                _mini(_money(entry.value.outgoingSalary), 'MATCH OUT'),
                _mini(_money(entry.value.incomingSalary), 'MATCH IN'),
                _mini(_money(entry.value.maximumIncomingSalary), 'MAX IN'),
                _mini(_money(entry.value.postTradeSalary), 'POST PAYROLL'),
                _mini('${entry.value.projectedRosterPlayers}', 'ROSTER'),
                _mini(entry.value.apronStatus.toUpperCase(), 'STATUS'),
              ]),
            ),
        ],
      ));

  Widget _boundary(NbaTradeContractSnapshot data) => _panelBox(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('DATA & RULE BOUNDARY'),
          const SizedBox(height: 7),
          Text(
            'Player matching uses the uploaded 2026-27 salary schedule rather than a statistical salary proxy. ${data.sourceNote} The CBA engine checks salary matching, apron restrictions, hard caps, roster counts and any player/pick restrictions present in metadata.',
            style: const TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 6),
          const Text(
            'Salary rows do not by themselves prove options, guarantees, no-trade/consent rights, trade kickers, recently signed/acquired dates, BYC or poison-pill treatment, exceptions, dead money/cap holds, cash usage or draft-pick encumbrances. Those fields remain execution-grade data dependencies and are not silently invented.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ));

  TradeScenario _scenario(NbaTradeContractSnapshot data) {
    final assignments = <TradeAssignment>[];
    for (final route in routes.entries) {
      NbaTradeContract? player;
      for (final row in data.records) {
        if (row.id == route.key) {
          player = row;
          break;
        }
      }
      if (player == null) continue;
      assignments.add(TradeAssignment(
        asset: TradeAsset(
          id: player.id,
          type: TradeAssetType.player,
          label: player.player,
          originTeam: player.team,
          salary: player.salaryFor('2026-27'),
          metadata: {'source_status': player.sourceStatus, 'guaranteed_amount': player.guaranteed},
        ),
        destinationTeam: route.value,
      ));
    }
    return TradeScenario(
      id: 'sports-terminal-2026-27',
      name: '2026-27 Trade',
      operatingSeason: '2026-27',
      asOfDateIso: DateTime.now().toUtc().toIso8601String(),
      teams: List<String>.from(teams),
      assignments: assignments,
      capContexts: {
        for (final team in teams)
          team: TeamCapContext(
            team: team,
            teamSalary: data.payroll(team, '2026-27'),
            salaryCap: _cap,
            taxLine: _tax,
            firstApron: _first,
            secondApron: _second,
            standardRosterPlayers: data.forTeam(team, '2026-27').length,
          ),
      },
    );
  }

  void _repairTeams(List<String> all) {
    final valid = teams.where(all.contains).toList();
    for (final fallback in const ['BOS', 'PHI']) {
      if (valid.length >= 2) break;
      if (all.contains(fallback) && !valid.contains(fallback)) valid.add(fallback);
    }
    if (valid.length >= 2 && valid.join('|') != teams.join('|')) teams = valid;
  }
}

class _CapMetric extends StatelessWidget {
  const _CapMetric(this.label, this.value);
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Container(
        width: 140,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_money(value), style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900)),
        ]),
      );
}

Widget _panelBox(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: child,
    );

Widget _section(String text) => Text(text,
    style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9));

Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );

Widget _mini(String value, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12)),
        Text(label, style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w800)),
      ],
    );

String _tier(double payroll) {
  if (payroll > _second) return '2ND APRON';
  if (payroll > _first) return '1ST APRON';
  if (payroll > _tax) return 'TAX';
  if (payroll > _cap) return 'OVER CAP';
  return 'CAP SPACE';
}

Color _tierColor(double payroll) {
  if (payroll > _second) return _red;
  if (payroll > _tax) return _amber;
  if (payroll > _cap) return _blue;
  return _green;
}

String _money(double value) {
  if (value.abs() >= 1000000) return '\$${(value / 1000000).toStringAsFixed(2)}M';
  if (value.abs() >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
  return '\$${value.toStringAsFixed(0)}';
}

String _encode(Map<String, String> values) =>
    values.entries.map((e) => '${e.key}=>${e.value}').join('||');

Map<String, String> _decode(String? raw) {
  final result = <String, String>{};
  if (raw == null || raw.isEmpty) return result;
  for (final item in raw.split('||')) {
    final split = item.lastIndexOf('=>');
    if (split > 0) result[item.substring(0, split)] = item.substring(split + 2);
  }
  return result;
}
