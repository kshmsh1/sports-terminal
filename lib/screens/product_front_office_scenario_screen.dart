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
  State<ProductFrontOfficeScenarioScreen> createState() =>
      _ProductFrontOfficeScenarioScreenState();
}

class _ProductFrontOfficeScenarioScreenState
    extends State<ProductFrontOfficeScenarioScreen> {
  static const _storageKey = 'sports_terminal.front_office.ledger_v1';

  final ProductLocalStore store = const ProductLocalStore();
  final FrontOfficeLedgerEngine engine = const FrontOfficeLedgerEngine();
  final WorkspaceRouteImportService workspaceImporter =
      const WorkspaceRouteImportService();

  final playerController = TextEditingController();
  final teamController = TextEditingController(text: 'BOS');
  final salaryController = TextEditingController();
  final guaranteedController = TextEditingController();
  final deadMoneyController = TextEditingController(text: '0');
  final capHoldsController = TextEditingController(text: '0');
  final draftHoldsController = TextEditingController(text: '0');
  final rosterChargesController = TextEditingController(text: '0');
  final outgoingController = TextEditingController(text: '0');
  final incomingController = TextEditingController(text: '0');
  final draftOwnerController = TextEditingController(text: 'BOS');
  final draftOriginalController = TextEditingController(text: 'BOS');
  final draftYearController = TextEditingController(text: '2028');
  final draftProtectionController = TextEditingController(text: 'Unspecified');

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
    final controllers = <TextEditingController>[
      playerController,
      teamController,
      salaryController,
      guaranteedController,
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
    ];
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    final raw = await store.loadString(_storageKey);
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          contracts = [
            for (final item in (decoded['contracts'] as List? ?? const []))
              if (item is Map)
                NbaContractYear.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
          ];
          draftAssets = [
            for (final item in (decoded['draftAssets'] as List? ?? const []))
              if (item is Map)
                NbaDraftAsset.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
          ];
          season = decoded['season']?.toString() ?? season;
          teamController.text = decoded['teamId']?.toString() ?? 'BOS';
          deadMoneyController.text = decoded['deadMoney']?.toString() ?? '0';
          capHoldsController.text = decoded['capHolds']?.toString() ?? '0';
          draftHoldsController.text = decoded['draftHolds']?.toString() ?? '0';
          rosterChargesController.text =
              decoded['rosterCharges']?.toString() ?? '0';
        }
      } catch (_) {
        contracts = [];
        draftAssets = [];
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => loaded = true);
  }

  Future<void> _persist() async {
    await store.saveString(
      _storageKey,
      jsonEncode({
        'season': season,
        'teamId': teamController.text.trim().toUpperCase(),
        'deadMoney': deadMoneyController.text,
        'capHolds': capHoldsController.text,
        'draftHolds': draftHoldsController.text,
        'rosterCharges': rosterChargesController.text,
        'contracts': [for (final item in contracts) item.toJson()],
        'draftAssets': [for (final item in draftAssets) item.toJson()],
      }),
    );
  }

  void _addContract() {
    final player = playerController.text.trim();
    final team = teamController.text.trim().toUpperCase();
    final salary = _millions(salaryController.text);
    final guaranteed = guaranteedController.text.trim().isEmpty
        ? salary
        : _millions(guaranteedController.text);
    if (player.isEmpty || team.isEmpty || salary <= 0) {
      _show('Enter a player, team and positive salary.');
      return;
    }
    final slug = player
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final id =
        '${team}_${season}_${slug}_${DateTime.now().microsecondsSinceEpoch}';
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
      guaranteedController.clear();
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
    final id =
        '${owner}_${original}_${year}_R${draftRound}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      draftAssets = [
        ...draftAssets,
        NbaDraftAsset(
          id: id,
          currentOwner: owner,
          originalTeam: original,
          year: year,
          round: draftRound,
          protections: draftProtectionController.text.trim().isEmpty
              ? 'Unspecified'
              : draftProtectionController.text.trim(),
        ),
      ];
    });
    _persist();
  }

  NbaTeamLedgerInputs _inputs() {
    return NbaTeamLedgerInputs(
      teamId: teamController.text.trim().toUpperCase(),
      season: season,
      deadMoney: _millions(deadMoneyController.text),
      capHolds: _millions(capHoldsController.text),
      draftCapHolds: _millions(draftHoldsController.text),
      incompleteRosterCharges: _millions(rosterChargesController.text),
    );
  }

  Future<void> _routeContracts(String target) async {
    final payload = engine.packageContracts(
      contracts: contracts,
      targetRoute: target,
      sourceSnapshot: 'User-entered contract ledger · $season',
    );
    RoutePayloadScope.maybeOf(context)?.setActivePayload(
      payload,
      origin: 'Front Office Ledger',
    );
    if (target == 'Workspace') {
      final result = await workspaceImporter.importPayload(payload);
      if (!mounted) {
        return;
      }
      _show(result.summary);
    } else {
      _show('${payload.rowCount} contract rows published to $target.');
    }
  }

  Future<void> _routeDraftAssets(String target) async {
    final payload = engine.packageDraftAssets(
      assets: draftAssets,
      targetRoute: target,
    );
    RoutePayloadScope.maybeOf(context)?.setActivePayload(
      payload,
      origin: 'Front Office Draft Ledger',
    );
    if (target == 'Workspace') {
      final result = await workspaceImporter.importPayload(payload);
      if (!mounted) {
        return;
      }
      _show(result.summary);
    } else {
      _show('${payload.rowCount} draft assets published to $target.');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const _Panel(
        child: Text(
          'Loading front-office ledger...',
          style: TextStyle(color: _muted),
        ),
      );
    }
    return FutureBuilder<List<NbaCapEnvironment>>(
      future: const NbaFinancialRepository().loadCapEnvironments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _Panel(
            child: Text(
              'Loading official cap environments...',
              style: TextStyle(color: _muted),
            ),
          );
        }
        final environments = snapshot.data!;
        final environment = environments.firstWhere(
          (item) => item.season == season,
          orElse: () => environments.last,
        );
        final summary = engine.summarize(
          contracts: contracts,
          inputs: _inputs(),
          environment: environment,
        );
        final impact = engine.modelTransaction(
          current: summary,
          outgoingSalary: _millions(outgoingController.text),
          incomingSalary: _millions(incomingController.text),
          environment: environment,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              summary: summary,
              contractCount: contracts.length,
              draftCount: draftAssets.length,
            ),
            const SizedBox(height: 18),
            _controlPanel(environments),
            const SizedBox(height: 18),
            _activePanel(environment, summary, impact),
            const SizedBox(height: 18),
            _accuracyPanel(environment),
          ],
        );
      },
    );
  }

  Widget _controlPanel(List<NbaCapEnvironment> environments) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Ledger controls',
            'Select the team and operating season, then work across contracts, cap reconciliation, draft assets and transaction impact.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  value: season,
                  isExpanded: true,
                  decoration: _input('Season'),
                  items: [
                    for (final item in environments)
                      DropdownMenuItem(
                        value: item.season,
                        child: Text(item.season),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => season = value);
                      _persist();
                    }
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: teamController,
                  decoration: _input('Team ID'),
                  onChanged: (_) {
                    setState(() {});
                    _persist();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const [
                'Contracts',
                'Cap Reconciliation',
                'Draft Assets',
                'Transaction Impact',
              ])
                ChoiceChip(
                  label: Text(item),
                  selected: tab == item,
                  onSelected: (_) => setState(() => tab = item),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activePanel(
    NbaCapEnvironment environment,
    TeamLedgerSummary summary,
    TransactionImpact impact,
  ) {
    switch (tab) {
      case 'Cap Reconciliation':
        return _capPanel(environment, summary);
      case 'Draft Assets':
        return _draftPanel();
      case 'Transaction Impact':
        return _transactionPanel(summary, impact);
      default:
        return _contractsPanel(summary);
    }
  }

  Widget _contractsPanel(TeamLedgerSummary summary) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Contract-year ledger',
            'Add modeled annual salary rows with guarantee and option metadata. No live contract data is inferred.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: playerController,
                  decoration: _input('Player'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: salaryController,
                  keyboardType: TextInputType.number,
                  decoration: _input('Salary · millions'),
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: guaranteedController,
                  keyboardType: TextInputType.number,
                  decoration: _input('Guaranteed · millions'),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<ContractGuarantee>(
                  value: guarantee,
                  decoration: _input('Guarantee'),
                  items: [
                    for (final item in ContractGuarantee.values)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => guarantee = value);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<ContractOption>(
                  value: option,
                  decoration: _input('Option'),
                  items: [
                    for (final item in ContractOption.values)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => option = value);
                    }
                  },
                ),
              ),
              FilterChip(
                label: const Text('No-trade clause'),
                selected: noTradeClause,
                onSelected: (value) => setState(() => noTradeClause = value),
              ),
              FilledButton.icon(
                onPressed: _addContract,
                icon: const Icon(Icons.add),
                label: const Text('Add contract'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _routeButtons(_routeContracts),
          const SizedBox(height: 14),
          _contractTable(),
          const SizedBox(height: 14),
          _findings(summary.findings),
        ],
      ),
    );
  }

  Widget _contractTable() {
    return _table(
      columns: const [
        'Player',
        'Team',
        'Season',
        'Salary',
        'Guaranteed',
        'Guarantee',
        'Option',
        'NTC',
        '',
      ],
      rows: [
        for (final item in contracts)
          [
            item.playerLabel,
            item.teamId,
            item.season,
            _money(item.salary),
            _money(item.guaranteedAmount),
            item.guarantee.name,
            item.option.name,
            item.noTradeClause ? 'Yes' : 'No',
            item.id,
          ],
      ],
      onDelete: (id) {
        setState(() {
          contracts = contracts.where((item) => item.id != id).toList();
        });
        _persist();
      },
    );
  }

  Widget _capPanel(
    NbaCapEnvironment environment,
    TeamLedgerSummary summary,
  ) {
    final inputs = <MapEntry<String, TextEditingController>>[
      MapEntry('Dead money', deadMoneyController),
      MapEntry('Cap holds', capHoldsController),
      MapEntry('Draft holds', draftHoldsController),
      MapEntry('Roster charges', rosterChargesController),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Cap reconciliation',
            'Reconcile modeled contracts with dead money, cap holds, draft holds and incomplete-roster charges.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in inputs)
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: item.value,
                    keyboardType: TextInputType.number,
                    decoration: _input('${item.key} · millions'),
                    onChanged: (_) {
                      setState(() {});
                      _persist();
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _metrics([
            _Metric('Active salary', _money(summary.activeSalary),
                '${summary.rosterCount} rows'),
            _Metric('Guaranteed', _money(summary.guaranteedSalary),
                'modeled guarantees'),
            _Metric('Other charges', _money(summary.nonContractCharges),
                'holds and charges'),
            _Metric('Team salary', _money(summary.teamSalary),
                summary.position.tierLabel),
            _Metric('Cap room', _signed(summary.position.capRoom), 'vs cap'),
            _Metric('Tax room', _signed(summary.position.taxRoom), 'vs tax'),
            _Metric('First apron', _signed(summary.position.firstApronRoom),
                'remaining'),
            _Metric('Second apron', _signed(summary.position.secondApronRoom),
                'remaining'),
          ]),
          const SizedBox(height: 14),
          Text(
            'Official ${environment.season}: cap ${_money(environment.salaryCap)} · tax ${_money(environment.taxLevel)} · first apron ${_money(environment.firstApron)} · second apron ${_money(environment.secondApron)}.',
            style: const TextStyle(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _draftPanel() {
    final findings = engine.validateDraftAssets(draftAssets);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Draft asset ledger',
            'Track modeled ownership, original team, round and protections. Source verification remains mandatory.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 130,
                child: TextField(
                  controller: draftOwnerController,
                  decoration: _input('Owner'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: draftOriginalController,
                  decoration: _input('Original team'),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: draftYearController,
                  keyboardType: TextInputType.number,
                  decoration: _input('Year'),
                ),
              ),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<int>(
                  value: draftRound,
                  decoration: _input('Round'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => draftRound = value);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: draftProtectionController,
                  decoration: _input('Protections / conveyance'),
                ),
              ),
              FilledButton.icon(
                onPressed: _addDraftAsset,
                icon: const Icon(Icons.add),
                label: const Text('Add asset'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _routeButtons(_routeDraftAssets),
          const SizedBox(height: 14),
          _table(
            columns: const [
              'Owner',
              'Original',
              'Year',
              'Round',
              'Protections',
              '',
            ],
            rows: [
              for (final item in draftAssets)
                [
                  item.currentOwner,
                  item.originalTeam,
                  '${item.year}',
                  '${item.round}',
                  item.protections,
                  item.id,
                ],
            ],
            onDelete: (id) {
              setState(() {
                draftAssets =
                    draftAssets.where((item) => item.id != id).toList();
              });
              _persist();
            },
          ),
          const SizedBox(height: 14),
          _findings(findings),
        ],
      ),
    );
  }

  Widget _transactionPanel(
    TeamLedgerSummary summary,
    TransactionImpact impact,
  ) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Transaction impact',
            'Model salary movement and post-transaction cap position. This is reconciliation, not legal approval.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 190,
                child: TextField(
                  controller: outgoingController,
                  keyboardType: TextInputType.number,
                  decoration: _input('Outgoing · millions'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 190,
                child: TextField(
                  controller: incomingController,
                  keyboardType: TextInputType.number,
                  decoration: _input('Incoming · millions'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _metrics([
            _Metric('Current salary', _money(summary.teamSalary),
                summary.position.tierLabel),
            _Metric('Outgoing', _money(impact.outgoingSalary), 'modeled'),
            _Metric('Incoming', _money(impact.incomingSalary), 'modeled'),
            _Metric('Post salary', _money(impact.postTransactionSalary),
                impact.position.tierLabel),
            _Metric('Cap room', _signed(impact.position.capRoom), 'post trade'),
            _Metric('Second apron', _signed(impact.position.secondApronRoom),
                'post trade'),
          ]),
          const SizedBox(height: 14),
          if (impact.reviewFlags.isEmpty)
            const _Notice(
              text:
                  'No basic reconciliation flags. Full salary matching, aggregation, hard-cap and exception review is still required.',
              danger: false,
            )
          else
            for (final flag in impact.reviewFlags)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Notice(text: flag, danger: true),
              ),
        ],
      ),
    );
  }

  Widget _routeButtons(Future<void> Function(String) handler) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () => handler('Workspace'),
          icon: const Icon(Icons.grid_on),
          label: const Text('Send to Workspace'),
        ),
        OutlinedButton.icon(
          onPressed: () => handler('Python Lab'),
          icon: const Icon(Icons.code),
          label: const Text('Send to Python Lab'),
        ),
      ],
    );
  }

  Widget _table({
    required List<String> columns,
    required List<List<String>> rows,
    required ValueChanged<String> onDelete,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_soft),
        columns: [
          for (final column in columns)
            DataColumn(
              label: Text(
                column,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (var index = 0; index < row.length; index++)
                  DataCell(
                    index == row.length - 1
                        ? IconButton(
                            onPressed: () => onDelete(row[index]),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: _red,
                            ),
                          )
                        : Text(row[index]),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _findings(List<LedgerFinding> findings) {
    if (findings.isEmpty) {
      return const _Notice(
        text: 'No structural ledger findings.',
        danger: false,
      );
    }
    return Column(
      children: [
        for (final finding in findings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Notice(
              text: '${finding.code}: ${finding.message}',
              danger: finding.severity == 'error',
            ),
          ),
      ],
    );
  }

  Widget _metrics(List<_Metric> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 620
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _soft,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.label.toUpperCase(),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        metric.value,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        metric.caption,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _accuracyPanel(NbaCapEnvironment environment) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Accuracy boundary',
            'The current NBA–NBPA CBA took effect July 1, 2023. This studio preserves source and modeling boundaries rather than presenting incomplete rules as authoritative.',
          ),
          const SizedBox(height: 10),
          Text(
            'League thresholds are sourced from ${environment.sourceLabel}. Contract rows, draft assets, holds and transaction inputs are user modeled until connected to verified ledgers.',
            style: const TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 8),
          const Text(
            'Still required for complete legality: salary-matching bands, aggregation restrictions, hard-cap triggers, sign-and-trades, base-year compensation, poison-pill treatment, exceptions, cash limits, option dates, guarantee dates and Stepien/conveyance logic.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.summary,
    required this.contractCount,
    required this.draftCount,
  });

  final TeamLedgerSummary summary;
  final int contractCount;
  final int draftCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FRONT OFFICE LEDGER',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.teamId.isEmpty ? 'TEAM' : summary.teamId} · ${summary.season}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Persistent contracts, cap charges, draft assets and transaction readiness—without fabricating live payroll data.',
            style: TextStyle(
              color: Color(0xFFEAF2FF),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _Pill('$contractCount CONTRACT ROWS'),
              _Pill('$draftCount DRAFT ASSETS'),
              _Pill(_money(summary.teamSalary)),
              _Pill(summary.position.tierLabel.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F071A33),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.subtitle);

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
          style: const TextStyle(color: _muted, height: 1.4),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.danger});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF3),
        border: Border.all(
          color: danger ? const Color(0xFFFDA4AF) : const Color(0xFF86EFAC),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: danger ? _red : _green,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.caption);

  final String label;
  final String value;
  final String caption;
}

InputDecoration _input(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _soft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _line),
    ),
  );
}

double _millions(String raw) {
  return (double.tryParse(raw.trim()) ?? 0) * 1000000;
}

String _money(double value) {
  return '\$${(value / 1000000).toStringAsFixed(3)}M';
}

String _signed(double value) {
  final sign = value >= 0 ? '+' : '−';
  return '$sign\$${(value.abs() / 1000000).toStringAsFixed(3)}M';
}
