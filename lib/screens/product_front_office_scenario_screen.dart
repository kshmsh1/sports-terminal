import 'dart:convert';

import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../models/front_office_ledger.dart';
import '../models/nba_cap_environment.dart';
import '../services/front_office_ledger_engine.dart';
import '../services/nba_financial_repository.dart';
import '../services/product_local_store.dart';
import '../services/workspace_route_import_service.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
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
  static const _ledgerKey = 'sports_terminal.front_office.ledger_v1';
  final ProductLocalStore store = const ProductLocalStore();
  final FrontOfficeLedgerEngine engine = const FrontOfficeLedgerEngine();
  final WorkspaceRouteImportService workspaceImporter = const WorkspaceRouteImportService();
  final TextEditingController playerController = TextEditingController();
  final TextEditingController teamController = TextEditingController(text: 'BOS');
  final TextEditingController salaryController = TextEditingController();
  final TextEditingController guaranteeController = TextEditingController();
  final TextEditingController deadMoneyController = TextEditingController(text: '0');
  final TextEditingController capHoldsController = TextEditingController(text: '0');
  final TextEditingController draftHoldsController = TextEditingController(text: '0');
  final TextEditingController rosterChargesController = TextEditingController(text: '0');
  final TextEditingController outgoingController = TextEditingController(text: '0');
  final TextEditingController incomingController = TextEditingController(text: '0');
  final TextEditingController draftOwnerController = TextEditingController(text: 'BOS');
  final TextEditingController draftOriginalController = TextEditingController(text: 'BOS');
  final TextEditingController draftYearController = TextEditingController(text: '2028');
  final TextEditingController draftProtectionController = TextEditingController(text: 'Unspecified');

  List<NbaContractYear> contracts = [];
  List<NbaDraftAsset> draftAssets = [];
  String tab = 'Contracts';
  String season = '2026-27';
  ContractGuarantee guarantee = ContractGuarantee.full;
  ContractOption option = ContractOption.none;
  bool noTradeClause = false;
  int draftRound = 1;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    for (final controller in [
      playerController,
      teamController,
      salaryController,
      guaranteeController,
      deadMoneyController,
      capHoldsController,
      draftHoldsController,
      rosterChargesController,
      outgoingController,
      incomingController,
      draftOwnerController,
      draftOriginalController,
      draftYearController,
      draftProtectionController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    final raw = await store.loadString(_ledgerKey);
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          contracts = [
            for (final item in (decoded['contracts'] as List? ?? const []))
              if (item is Map) NbaContractYear.fromJson(item.map((key, value) => MapEntry(key.toString(), value))),
          ];
          draftAssets = [
            for (final item in (decoded['draftAssets'] as List? ?? const []))
              if (item is Map) NbaDraftAsset.fromJson(item.map((key, value) => MapEntry(key.toString(), value))),
          ];
          season = decoded['season']?.toString() ?? season;
          teamController.text = decoded['teamId']?.toString() ?? teamController.text;
          deadMoneyController.text = decoded['deadMoney']?.toString() ?? '0';
          capHoldsController.text = decoded['capHolds']?.toString() ?? '0';
          draftHoldsController.text = decoded['draftHolds']?.toString() ?? '0';
          rosterChargesController.text = decoded['rosterCharges']?.toString() ?? '0';
        }
      } catch (_) {
        contracts = [];
        draftAssets = [];
      }
    }
    if (!mounted) return;
    setState(() => loaded = true);
  }

  Future<void> _persist() async {
    await store.saveString(
      _ledgerKey,
      jsonEncode({
        'season': season,
        'teamId': teamController.text.trim().toUpperCase(),
        'deadMoney': deadMoneyController.text,
        'capHolds': capHoldsController.text,
        'draftHolds': draftHoldsController.text,
        'rosterCharges': rosterChargesController.text,
        'contracts': [for (final contract in contracts) contract.toJson()],
        'draftAssets': [for (final asset in draftAssets) asset.toJson()],
      }),
    );
  }

  void _addContract() {
    final salary = _millions(salaryController.text);
    final guaranteed = guaranteeController.text.trim().isEmpty ? salary : _millions(guaranteeController.text);
    final player = playerController.text.trim();
    final team = teamController.text.trim().toUpperCase();
    if (player.isEmpty || team.isEmpty || salary <= 0) {
      _show('Enter a player, team and positive salary.');
      return;
    }
    final id = '${team}_${season}_${player.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      contracts = [
        ...contracts,
        NbaContractYear(
          id: id,
          playerLabel: player,
          teamId: team,
          season: season,
          salary: salary,
          guaranteedAmount: guaranteed,
          guarantee: guarantee,
          option: option,
          noTradeClause: noTradeClause,
        ),
      ];
      playerController.clear();
      salaryController.clear();
      guaranteeController.clear();
      noTradeClause = false;
    });
    _persist();
  }

  void _addDraftAsset() {
    final owner = draftOwnerController.text.trim().toUpperCase();
    final original = draftOriginalController.text.trim().toUpperCase();
    final year = int.tryParse(draftYearController.text.trim()) ?? 0;
    if (owner.isEmpty || original.isEmpty || year < 2024) {
      _show('Enter valid owner, original team and draft year.');
      return;
    }
    final id = '${owner}_${original}_${year}_R$draftRound_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      draftAssets = [
        ...draftAssets,
        NbaDraftAsset(
          id: id,
          currentOwner: owner,
          originalTeam: original,
          year: year,
          round: draftRound,
          protections: draftProtectionController.text.trim().isEmpty ? 'Unspecified' : draftProtectionController.text.trim(),
        ),
      ];
    });
    _persist();
  }

  NbaTeamLedgerInputs _inputs() => NbaTeamLedgerInputs(
        teamId: teamController.text.trim().toUpperCase(),
        season: season,
        deadMoney: _millions(deadMoneyController.text),
        capHolds: _millions(capHoldsController.text),
        draftCapHolds: _millions(draftHoldsController.text),
        incompleteRosterCharges: _millions(rosterChargesController.text),
      );

  Future<void> _publishContracts(String target) async {
    final payload = engine.packageContracts(
      contracts: contracts,
      targetRoute: target,
      sourceSnapshot: 'User-entered contract ledger · $season',
    );
    RoutePayloadScope.maybeOf(context)?.setActivePayload(payload, origin: 'Front Office Ledger');
    if (target == 'Workspace') {
      final result = await workspaceImporter.importPayload(payload);
      if (!mounted) return;
      _show(result.summary);
    } else {
      _show('${payload.rowCount} contract rows published to $target.');
    }
  }

  Future<void> _publishDraftAssets(String target) async {
    final payload = engine.packageDraftAssets(assets: draftAssets, targetRoute: target);
    RoutePayloadScope.maybeOf(context)?.setActivePayload(payload, origin: 'Front Office Draft Ledger');
    if (target == 'Workspace') {
      final result = await workspaceImporter.importPayload(payload);
      if (!mounted) return;
      _show(result.summary);
    } else {
      _show('${payload.rowCount} draft assets published to $target.');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const _Surface(child: Text('Loading front-office ledger...', style: TextStyle(color: _muted)));
    return FutureBuilder<List<NbaCapEnvironment>>(
      future: const NbaFinancialRepository().loadCapEnvironments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _Surface(child: Text('Loading official cap environments...', style: TextStyle(color: _muted)));
        final environments = snapshot.data!;
        final environment = environments.firstWhere((item) => item.season == season, orElse: () => environments.last);
        final inputs = _inputs();
        final summary = engine.summarize(contracts: contracts, inputs: inputs, environment: environment);
        final impact = engine.modelTransaction(
          current: summary,
          outgoingSalary: _millions(outgoingController.text),
          incomingSalary: _millions(incomingController.text),
          environment: environment,
        );
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Hero(summary: summary, contracts: contracts.length, assets: draftAssets.length),
          const SizedBox(height: 18),
          _Controls(
            season: season,
            seasons: [for (final item in environments) item.season],
            teamController: teamController,
            selectedTab: tab,
            onSeason: (value) {
              setState(() => season = value);
              _persist();
            },
            onTab: (value) => setState(() => tab = value),
            onChanged: () {
              setState(() {});
              _persist();
            },
          ),
          const SizedBox(height: 18),
          if (tab == 'Draft Assets')
            _DraftPanel(
              assets: draftAssets,
              owner: draftOwnerController,
              original: draftOriginalController,
              year: draftYearController,
              protections: draftProtectionController,
              round: draftRound,
              findings: engine.validateDraftAssets(draftAssets),
              onRound: (value) => setState(() => draftRound = value),
              onAdd: _addDraftAsset,
              onDelete: (id) {
                setState(() => draftAssets = draftAssets.where((item) => item.id != id).toList());
                _persist();
              },
              onWorkspace: () => _publishDraftAssets('Workspace'),
              onPython: () => _publishDraftAssets('Python Lab'),
            )
          else if (tab == 'Transaction Impact')
            _TransactionPanel(
              summary: summary,
              impact: impact,
              outgoing: outgoingController,
              incoming: incomingController,
              onChanged: () => setState(() {}),
            )
          else if (tab == 'Cap Reconciliation')
            _CapPanel(
              environment: environment,
              summary: summary,
              deadMoney: deadMoneyController,
              capHolds: capHoldsController,
              draftHolds: draftHoldsController,
              rosterCharges: rosterChargesController,
              onChanged: () {
                setState(() {});
                _persist();
              },
            )
          else
            _ContractsPanel(
              contracts: contracts,
              player: playerController,
              team: teamController,
              salary: salaryController,
              guaranteed: guaranteeController,
              guarantee: guarantee,
              option: option,
              noTradeClause: noTradeClause,
              findings: summary.findings,
              onGuarantee: (value) => setState(() => guarantee = value),
              onOption: (value) => setState(() => option = value),
              onNoTrade: (value) => setState(() => noTradeClause = value),
              onAdd: _addContract,
              onDelete: (id) {
                setState(() => contracts = contracts.where((item) => item.id != id).toList());
                _persist();
              },
              onWorkspace: () => _publishContracts('Workspace'),
              onPython: () => _publishContracts('Python Lab'),
            ),
          const SizedBox(height: 18),
          _AccuracyBoundary(environment: environment),
        ]);
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.contracts, required this.assets});
  final TeamLedgerSummary summary;
  final int contracts;
  final int assets;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [_navy, _blue, _orange])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FRONT OFFICE LEDGER', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
          const SizedBox(height: 10),
          Text('${summary.teamId.isEmpty ? 'TEAM' : summary.teamId} · ${summary.season}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('A persistent contract, cap-charge, draft-asset and transaction-readiness workspace. Every salary and asset row is user modeled until a sourced ledger is connected.', style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 15, height: 1.4)),
          const SizedBox(height: 16),
          Wrap(spacing: 9, runSpacing: 9, children: [
            _Pill('$contracts CONTRACT ROWS'),
            _Pill('$assets DRAFT ASSETS'),
            _Pill(_money(summary.teamSalary)),
            _Pill(summary.position.tierLabel.toUpperCase()),
          ]),
        ]),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.season, required this.seasons, required this.teamController, required this.selectedTab, required this.onSeason, required this.onTab, required this.onChanged});
  final String season;
  final List<String> seasons;
  final TextEditingController teamController;
  final String selectedTab;
  final ValueChanged<String> onSeason;
  final ValueChanged<String> onTab;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Heading('Ledger controls', 'Select the operating season and team, then work across contracts, cap reconciliation, draft assets and transaction impact.'),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 190, child: DropdownButtonFormField<String>(value: season, isExpanded: true, decoration: _input('Season'), items: [for (final item in seasons) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) { if (value != null) onSeason(value); })),
          SizedBox(width: 190, child: TextField(controller: teamController, decoration: _input('Team ID'), onChanged: (_) => onChanged())),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final item in const ['Contracts', 'Cap Reconciliation', 'Draft Assets', 'Transaction Impact']) ChoiceChip(label: Text(item), selected: item == selectedTab, onSelected: (_) => onTab(item))]),
      ]));
}

class _ContractsPanel extends StatelessWidget {
  const _ContractsPanel({required this.contracts, required this.player, required this.team, required this.salary, required this.guaranteed, required this.guarantee, required this.option, required this.noTradeClause, required this.findings, required this.onGuarantee, required this.onOption, required this.onNoTrade, required this.onAdd, required this.onDelete, required this.onWorkspace, required this.onPython});
  final List<NbaContractYear> contracts;
  final TextEditingController player;
  final TextEditingController team;
  final TextEditingController salary;
  final TextEditingController guaranteed;
  final ContractGuarantee guarantee;
  final ContractOption option;
  final bool noTradeClause;
  final List<LedgerFinding> findings;
  final ValueChanged<ContractGuarantee> onGuarantee;
  final ValueChanged<ContractOption> onOption;
  final ValueChanged<bool> onNoTrade;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;
  final VoidCallback onWorkspace;
  final VoidCallback onPython;

  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Heading('Contract-year ledger', 'Add modeled annual salary rows with guarantee and option metadata. No live contract data is inferred.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: 220, child: TextField(controller: player, decoration: _input('Player'))),
          SizedBox(width: 110, child: TextField(controller: team, decoration: _input('Team'))),
          SizedBox(width: 150, child: TextField(controller: salary, keyboardType: TextInputType.number, decoration: _input('Salary · millions'))),
          SizedBox(width: 170, child: TextField(controller: guaranteed, keyboardType: TextInputType.number, decoration: _input('Guaranteed · millions'))),
          SizedBox(width: 170, child: DropdownButtonFormField<ContractGuarantee>(value: guarantee, decoration: _input('Guarantee'), items: [for (final value in ContractGuarantee.values) DropdownMenuItem(value: value, child: Text(value.name))], onChanged: (value) { if (value != null) onGuarantee(value); })),
          SizedBox(width: 180, child: DropdownButtonFormField<ContractOption>(value: option, decoration: _input('Option'), items: [for (final value in ContractOption.values) DropdownMenuItem(value: value, child: Text(value.name))], onChanged: (value) { if (value != null) onOption(value); })),
          FilterChip(label: const Text('No-trade clause'), selected: noTradeClause, onSelected: onNoTrade),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add row')),
        ]),
        const SizedBox(height: 16),
        _ActionRow(onWorkspace: onWorkspace, onPython: onPython),
        const SizedBox(height: 12),
        _HorizontalTable(columns: const ['Player', 'Team', 'Season', 'Salary', 'Guaranteed', 'Guarantee', 'Option', 'NTC', ''], rows: [for (final item in contracts) [item.playerLabel, item.teamId, item.season, _money(item.salary), _money(item.guaranteedAmount), item.guarantee.name, item.option.name, item.noTradeClause ? 'Yes' : 'No', 'DELETE:${item.id}']], onDelete: onDelete),
        const SizedBox(height: 14),
        _Findings(findings: findings),
      ]));
}

class _CapPanel extends StatelessWidget {
  const _CapPanel({required this.environment, required this.summary, required this.deadMoney, required this.capHolds, required this.draftHolds, required this.rosterCharges, required this.onChanged});
  final NbaCapEnvironment environment;
  final TeamLedgerSummary summary;
  final TextEditingController deadMoney;
  final TextEditingController capHolds;
  final TextEditingController draftHolds;
  final TextEditingController rosterCharges;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Heading('Cap reconciliation', 'Reconcile modeled active contracts with dead money, cap holds, draft holds and incomplete-roster charges.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final entry in [('Dead money', deadMoney), ('Cap holds', capHolds), ('Draft holds', draftHolds), ('Roster charges', rosterCharges)]) SizedBox(width: 180, child: TextField(controller: entry.$2, keyboardType: TextInputType.number, decoration: _input('${entry.$1} · millions'), onChanged: (_) => onChanged())),
        ]),
        const SizedBox(height: 16),
        _MetricGrid(items: [
          _Metric('Active salary', _money(summary.activeSalary), '${summary.rosterCount} rows'),
          _Metric('Guaranteed', _money(summary.guaranteedSalary), 'modeled guarantees'),
          _Metric('Other charges', _money(summary.nonContractCharges), 'holds and charges'),
          _Metric('Team salary', _money(summary.teamSalary), summary.position.tierLabel),
          _Metric('Cap room', _signed(summary.position.capRoom), 'vs salary cap'),
          _Metric('Tax room', _signed(summary.position.taxRoom), 'vs tax line'),
          _Metric('First apron', _signed(summary.position.firstApronRoom), 'remaining room'),
          _Metric('Second apron', _signed(summary.position.secondApronRoom), 'remaining room'),
        ]),
        const SizedBox(height: 14),
        Text('Official ${environment.season} thresholds: cap ${_money(environment.salaryCap)} · tax ${_money(environment.taxLevel)} · first apron ${_money(environment.firstApron)} · second apron ${_money(environment.secondApron)}.', style: const TextStyle(color: _muted, height: 1.4)),
      ]));
}

class _DraftPanel extends StatelessWidget {
  const _DraftPanel({required this.assets, required this.owner, required this.original, required this.year, required this.protections, required this.round, required this.findings, required this.onRound, required this.onAdd, required this.onDelete, required this.onWorkspace, required this.onPython});
  final List<NbaDraftAsset> assets;
  final TextEditingController owner;
  final TextEditingController original;
  final TextEditingController year;
  final TextEditingController protections;
  final int round;
  final List<LedgerFinding> findings;
  final ValueChanged<int> onRound;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;
  final VoidCallback onWorkspace;
  final VoidCallback onPython;

  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Heading('Draft asset ledger', 'Track modeled ownership, original team, round and protections. Source verification remains mandatory before transaction use.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: 130, child: TextField(controller: owner, decoration: _input('Current owner'))),
          SizedBox(width: 130, child: TextField(controller: original, decoration: _input('Original team'))),
          SizedBox(width: 130, child: TextField(controller: year, keyboardType: TextInputType.number, decoration: _input('Draft year'))),
          SizedBox(width: 130, child: DropdownButtonFormField<int>(value: round, decoration: _input('Round'), items: const [DropdownMenuItem(value: 1, child: Text('1')), DropdownMenuItem(value: 2, child: Text('2'))], onChanged: (value) { if (value != null) onRound(value); })),
          SizedBox(width: 260, child: TextField(controller: protections, decoration: _input('Protections / conveyance'))),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add asset')),
        ]),
        const SizedBox(height: 16),
        _ActionRow(onWorkspace: onWorkspace, onPython: onPython),
        const SizedBox(height: 12),
        _HorizontalTable(columns: const ['Owner', 'Original', 'Year', 'Round', 'Protections', 'Swap', 'Stepien', ''], rows: [for (final item in assets) [item.currentOwner, item.originalTeam, '${item.year}', '${item.round}', item.protections, item.swapRights ? 'Yes' : 'No', item.stepienAvailable ? 'Yes' : 'No', 'DELETE:${item.id}']], onDelete: onDelete),
        const SizedBox(height: 14),
        _Findings(findings: findings),
      ]));
}

class _TransactionPanel extends StatelessWidget {
  const _TransactionPanel({required this.summary, required this.impact, required this.outgoing, required this.incoming, required this.onChanged});
  final TeamLedgerSummary summary;
  final TransactionImpact impact;
  final TextEditingController outgoing;
  final TextEditingController incoming;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Heading('Transaction impact', 'Model salary movement and post-transaction cap position. This is a reconciliation layer, not a legal trade approval.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: 190, child: TextField(controller: outgoing, keyboardType: TextInputType.number, decoration: _input('Outgoing · millions'), onChanged: (_) => onChanged())),
          SizedBox(width: 190, child: TextField(controller: incoming, keyboardType: TextInputType.number, decoration: _input('Incoming · millions'), onChanged: (_) => onChanged())),
        ]),
        const SizedBox(height: 16),
        _MetricGrid(items: [
          _Metric('Current salary', _money(summary.teamSalary), summary.position.tierLabel),
          _Metric('Outgoing', _money(impact.outgoingSalary), 'modeled'),
          _Metric('Incoming', _money(impact.incomingSalary), 'modeled'),
          _Metric('Post salary', _money(impact.postTransactionSalary), impact.position.tierLabel),
          _Metric('Cap room', _signed(impact.position.capRoom), 'post transaction'),
          _Metric('Second apron', _signed(impact.position.secondApronRoom), 'post transaction'),
        ]),
        const SizedBox(height: 14),
        if (impact.reviewFlags.isEmpty)
          const _Notice(text: 'No basic reconciliation flags. Full salary matching, aggregation, hard-cap and exception review is still required.', danger: false)
        else
          for (final flag in impact.reviewFlags) Padding(padding: const EdgeInsets.only(bottom: 8), child: _Notice(text: flag, danger: true)),
      ]));
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onWorkspace, required this.onPython});
  final VoidCallback onWorkspace;
  final VoidCallback onPython;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(onPressed: onWorkspace, icon: const Icon(Icons.grid_on), label: const Text('Send to Workspace')),
        OutlinedButton.icon(onPressed: onPython, icon: const Icon(Icons.code), label: const Text('Send to Python Lab')),
      ]);
}

class _Findings extends StatelessWidget {
  const _Findings({required this.findings});
  final List<LedgerFinding> findings;
  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const _Notice(text: 'No structural ledger findings.', danger: false);
    return Column(children: [for (final finding in findings) Padding(padding: const EdgeInsets.only(bottom: 8), child: _Notice(text: '${finding.code}: ${finding.message}', danger: finding.severity == 'error'))]);
  }
}

class _HorizontalTable extends StatelessWidget {
  const _HorizontalTable({required this.columns, required this.rows, required this.onDelete});
  final List<String> columns;
  final List<List<String>> rows;
  final ValueChanged<String> onDelete;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(_soft),
        columns: [for (final column in columns) DataColumn(label: Text(column, style: const TextStyle(fontWeight: FontWeight.w900)))],
        rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(cell.startsWith('DELETE:') ? IconButton(icon: const Icon(Icons.delete_outline, color: _red), onPressed: () => onDelete(cell.substring(7))) : Text(cell))])],
      ));
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 620 ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final item in items) SizedBox(width: width, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _soft, border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 7), Text(item.value, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900)), Text(item.caption, style: const TextStyle(color: _muted, fontSize: 11))])))]);
      });
}

class _Metric {
  const _Metric(this.label, this.value, this.caption);
  final String label;
  final String value;
  final String caption;
}

class _AccuracyBoundary extends StatelessWidget {
  const _AccuracyBoundary({required this.environment});
  final NbaCapEnvironment environment;
  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Heading('Accuracy boundary', 'The current NBA–NBPA CBA took effect July 1, 2023. This studio preserves source and modeling boundaries instead of presenting incomplete transaction logic as authoritative.'),
        const SizedBox(height: 10),
        Text('League thresholds are sourced from ${environment.sourceLabel}. Contract rows, draft assets, holds, cash and transaction inputs are user modeled until connected to verified ledgers.', style: const TextStyle(color: _muted, height: 1.45)),
        const SizedBox(height: 8),
        const Text('Still required for complete legality: salary-matching bands, aggregation restrictions, hard-cap triggers, sign-and-trades, base-year compensation, poison-pill treatment, trade exceptions, cash limits, option dates, guarantee dates and Stepien/conveyance logic.', style: TextStyle(color: _muted, height: 1.45)),
      ]));
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.danger});
  final String text;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF3), border: Border.all(color: danger ? const Color(0xFFFDA4AF) : const Color(0xFF86EFAC)), borderRadius: BorderRadius.circular(14)), child: Text(text, style: TextStyle(color: danger ? _red : _green, height: 1.35, fontWeight: FontWeight.w700)));
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, height: 1.4))]);
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 20, offset: Offset(0, 8))]), child: child);
}

InputDecoration _input(String label) => InputDecoration(labelText: label, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)));

double _millions(String raw) => (double.tryParse(raw.trim()) ?? 0) * 1000000;
String _money(double value) => '\$${(value / 1000000).toStringAsFixed(3)}M';
String _signed(double value) => '${value >= 0 ? '+' : '−'}\$${(value.abs() / 1000000).toStringAsFixed(3)}M';
