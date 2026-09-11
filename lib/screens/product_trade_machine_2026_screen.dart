import 'package:flutter/material.dart';

import '../services/nba_future_draft_asset_repository.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_exception_reference_2026.dart';
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
  final picks = const NbaFutureDraftAssetRepository();
  final engine = const TradeMachineEngine();
  final store = const ProductLocalStore();
  late final Future<NbaTradeContractSnapshot> future;
  final routes = <String, String>{};
  final searches = <String, String>{};
  final tabs = <String, int>{};
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
      for (final part in (saved['tabs'] ?? '').split('|')) {
        final bits = part.split(':');
        if (bits.length == 2) tabs[bits[0]] = int.tryParse(bits[1]) ?? 0;
      }
    });
  }

  Future<void> _save() => store.saveStringMap(ProductLocalStore.tradeMachineStateKey, {
        'year': '2026-27',
        'teams': teams.join('|'),
        'name': '2026-27 Trade',
        'destinations': _encode(routes),
        'tabs': tabs.entries.map((e) => '${e.key}:${e.value}').join('|'),
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
        final validIds = <String>{
          ...data.records.map((p) => p.id),
          ...picks.all().map((p) => p.id),
          ...teams.map((t) => 'TPE:$t'),
        };
        routes.removeWhere((id, dest) => !validIds.contains(id) || !teams.contains(dest));
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
                    'Build two- through five-team trades with 2026-27 player salaries, normalized future first-round assets, team cap-ledger totals and live exception references. Salary matching, apron status and CBA findings update immediately.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    _pill('2026-27', _blue),
                    _pill('${data.records.length} SALARY ROWS', _green),
                    _pill('${picks.all().length} DRAFT ASSETS', _cyan),
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
          _section('2026-27 OPERATING ENVIRONMENT'),
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
          const SizedBox(height: 8),
          const Text('Team cap allocation below uses the supplied Spotrac team-cap ledger. It is intentionally separate from active-player cash salary.',
              style: TextStyle(color: _muted, fontSize: 10, height: 1.4)),
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
                  routes.removeWhere((id, dest) => id.startsWith('$team:') || id.startsWith('$team-') || dest == team);
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
    final activePayroll = data.payroll(team, '2026-27');
    final capAllocation = NbaTeamCapReference202627.teamSalary(team, activePayroll);
    final tab = tabs[team] ?? 0;
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
            Text('${_money(capAllocation)} total cap allocation · ${_money(activePayroll)} active salary',
                style: const TextStyle(color: _muted, fontSize: 10)),
          ])),
          _pill(_tier(capAllocation), _tierColor(capAllocation)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _mini(_signed(capAllocation), 'CAP SPACE'),
          _mini(_signed(_tax - capAllocation), 'TAX ROOM'),
          _mini(_signed(_first - capAllocation), '1ST APRON ROOM'),
          _mini(_signed(_second - capAllocation), '2ND APRON ROOM'),
          _mini((NbaTeamCapReference202627.hardCap[team] ?? 'none').toUpperCase(), 'HARD CAP'),
        ]),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Players'), icon: Icon(Icons.person_rounded, size: 16)),
            ButtonSegment(value: 1, label: Text('Draft Picks'), icon: Icon(Icons.sports_basketball_rounded, size: 16)),
            ButtonSegment(value: 2, label: Text('Money / Exceptions'), icon: Icon(Icons.account_balance_wallet_rounded, size: 16)),
          ],
          selected: {tab},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            setState(() => tabs[team] = value.first);
            _save();
          },
        ),
        const SizedBox(height: 10),
        if (tab == 0) _playersTab(data, team),
        if (tab == 1) _draftPicksTab(team),
        if (tab == 2) _exceptionsTab(team),
      ],
    ));
  }

  Widget _playersTab(NbaTradeContractSnapshot data, String team) {
    final q = (searches[team] ?? '').trim().toLowerCase();
    var rows = data.forTeam(team, '2026-27').where((p) => q.isEmpty || p.player.toLowerCase().contains(q));
    if (routedOnly) rows = rows.where((p) => routes.containsKey(p.id));
    final list = rows.toList();
    return Column(children: [
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
            SizedBox(width: 128, child: _routeMenu(player.id, team)),
          ]),
        ),
    ]);
  }

  Widget _draftPicksTab(String team) {
    var assets = picks.forTeam(team);
    if (routedOnly) assets = assets.where((p) => routes.containsKey(p.id)).toList();
    return Column(children: [
      for (final asset in assets)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(asset.label, style: const TextStyle(color: _text, fontWeight: FontWeight.w900))),
                if (asset.frozen) _pill('FROZEN', _red),
                if (!asset.tradable && !asset.frozen) _pill('UNAVAILABLE', _muted),
                if (asset.swapRight) _pill('SWAP', _cyan),
                if (asset.conditional) _pill('CONDITIONAL', _amber),
              ]),
              const SizedBox(height: 3),
              Text(asset.description, style: const TextStyle(color: _muted, fontSize: 9, height: 1.35)),
              if (asset.protection != null)
                Text('Protection: ${asset.protection}', style: const TextStyle(color: _amber, fontSize: 9)),
            ])),
            const SizedBox(width: 8),
            SizedBox(width: 128, child: asset.tradable ? _routeMenu(asset.id, team) : const SizedBox.shrink()),
          ]),
        ),
      if (assets.isEmpty)
        const Align(alignment: Alignment.centerLeft, child: Text('No visible draft assets under the current filter.', style: TextStyle(color: _muted))),
      const SizedBox(height: 6),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Registry currently prioritizes first-round interests and frozen/forfeited assets; second-round normalization is being layered into the same model.',
            style: TextStyle(color: _muted, fontSize: 9, height: 1.35)),
      ),
    ]);
  }

  Widget _exceptionsTab(String team) {
    final balances = NbaTradeExceptionReference202627.signingExceptions[team] ?? const <String, double>{};
    final tpe = NbaTradeExceptionReference202627.largestTpe[team];
    final tpeId = 'TPE:$team';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (balances.isEmpty && tpe == null)
        const Text('No live exception balance was visible for this team in the supplied reference.', style: TextStyle(color: _muted)),
      for (final entry in balances.entries)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_exceptionName(entry.key), style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
              const Text('Remaining signing-exception balance', style: TextStyle(color: _muted, fontSize: 9)),
            ])),
            Text(_money(entry.value), style: const TextStyle(color: _green, fontWeight: FontWeight.w900)),
          ]),
        ),
      if (tpe != null)
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Largest visible TPE', style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
              const Text('Amount only from supplied team-summary reference; source transaction/expiry still need authoritative ledger metadata.',
                  style: TextStyle(color: _muted, fontSize: 9, height: 1.3)),
            ])),
            Text(_money(tpe), style: const TextStyle(color: _cyan, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            SizedBox(width: 128, child: _routeMenu(tpeId, team)),
          ]),
        ),
    ]);
  }

  Widget _routeMenu(String id, String origin) => DropdownButtonFormField<String>(
        value: teams.where((t) => t != origin).contains(routes[id]) ? routes[id] : null,
        hint: const Text('Route to…'),
        isDense: true,
        items: [for (final destination in teams.where((t) => t != origin)) DropdownMenuItem(value: destination, child: Text(destination))],
        onChanged: (value) => _route(id, value),
      );

  Widget _tradeFlow(NbaTradeContractSnapshot data) => _panelBox(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('TRADE FLOW'),
          const SizedBox(height: 8),
          if (routes.isEmpty)
            const Text('Route a player, draft asset or exception to start building the transaction.', style: TextStyle(color: _muted))
          else
            for (final team in teams)
              Builder(builder: (context) {
                final sent = <String>[];
                final received = <String>[];
                for (final p in data.records) {
                  if (p.team == team && routes[p.id] != null) sent.add('${p.player} → ${routes[p.id]}');
                  if (routes[p.id] == team) received.add(p.player);
                }
                for (final p in picks.forTeam(team)) {
                  if (routes[p.id] != null) sent.add('${p.label} → ${routes[p.id]}');
                }
                for (final p in picks.all()) {
                  if (routes[p.id] == team) received.add(p.label);
                }
                final tpeId = 'TPE:$team';
                if (routes[tpeId] != null) sent.add('TPE → ${routes[tpeId]}');
                for (final origin in teams) {
                  if (routes['TPE:$origin'] == team) received.add('$origin TPE');
                }
                if (sent.isEmpty && received.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(team, style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
                    Text('Sends: ${sent.join(' • ')}', style: const TextStyle(color: _red, fontSize: 10)),
                    Text('Receives: ${received.join(' • ')}', style: const TextStyle(color: _green, fontSize: 10)),
                  ]),
                );
              }),
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
                _mini(_money(entry.value.postTradeSalary), 'POST CAP ALLOCATION'),
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
            'Player matching uses the uploaded 2026-27 salary schedule. Team cap position now uses the supplied Spotrac total-cap allocation ledger rather than simply summing active-player salaries. Draft assets are normalized from the two supplied RealGM PDFs, preserving swaps, protections, frozen status and conditional conveyance language.',
            style: const TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 6),
          const Text(
            'The current TPE seed contains amounts visible in the supplied summary, but not yet every source transaction or expiry date. Signing-exception balances come from the supplied Spotrac screenshot and are displayed as reference data; MLE/BAE balances are not treated as generic salary-matching assets. Complex draft interests remain conditional and trigger review rather than being flattened into guaranteed ownership.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ));

  TradeScenario _scenario(NbaTradeContractSnapshot data) {
    final assignments = <TradeAssignment>[];
    for (final route in routes.entries) {
      NbaTradeContract? player;
      for (final row in data.records) {
        if (row.id == route.key) { player = row; break; }
      }
      if (player != null) {
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
        continue;
      }

      NbaFutureDraftAsset? pick;
      for (final asset in picks.all()) {
        if (asset.id == route.key) { pick = asset; break; }
      }
      if (pick != null) {
        assignments.add(TradeAssignment(
          asset: TradeAsset(
            id: pick.id,
            type: TradeAssetType.draftPick,
            label: pick.label,
            originTeam: pick.team,
            metadata: {
              'draft_year': pick.year,
              'round': '${pick.round}',
              'frozen': pick.frozen,
              'swap_right': pick.swapRight,
              'stepien_safe': pick.stepienSafe,
              'protection': pick.protection ?? '',
              'conveyance_uncertain': pick.conditional,
              'source': pick.source,
            },
          ),
          destinationTeam: route.value,
        ));
        continue;
      }

      if (route.key.startsWith('TPE:')) {
        final origin = route.key.substring(4);
        final amount = NbaTradeExceptionReference202627.largestTpe[origin] ?? 0;
        if (amount > 0) {
          assignments.add(TradeAssignment(
            asset: TradeAsset(
              id: route.key,
              type: TradeAssetType.tradeException,
              label: '$origin TPE',
              originTeam: origin,
              salary: amount,
              metadata: {'amount': amount, 'source_status': 'reference-only'},
            ),
            destinationTeam: route.value,
          ));
        }
      }
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
            teamSalary: NbaTeamCapReference202627.teamSalary(team, data.payroll(team, '2026-27')),
            salaryCap: _cap,
            taxLine: _tax,
            firstApron: _first,
            secondApron: _second,
            hardCappedAt: NbaTeamCapReference202627.hardCapAt(team, _first, _second),
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

String _signed(double value) => '${value >= 0 ? '+' : ''}${_money(value)}';

String _exceptionName(String key) => switch (key) {
  'non_tax_mle' => 'Non-Taxpayer MLE',
  'tax_mle' => 'Taxpayer MLE',
  'room_mle' => 'Room MLE',
  'bae' => 'Bi-Annual Exception',
  _ => key,
};

String _encode(Map<String, String> values) => values.entries.map((e) => '${e.key}=>${e.value}').join('||');

Map<String, String> _decode(String? raw) {
  final result = <String, String>{};
  if (raw == null || raw.isEmpty) return result;
  for (final item in raw.split('||')) {
    final split = item.lastIndexOf('=>');
    if (split > 0) result[item.substring(0, split)] = item.substring(split + 2);
  }
  return result;
}
