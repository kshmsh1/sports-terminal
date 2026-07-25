import 'dart:convert';

import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../models/app_session.dart';
import '../models/route_payload.dart';
import '../services/front_office_registry_service.dart';

const _foNavy = Color(0xFF071A33);
const _foBlue = Color(0xFF2563EB);
const _foOrange = Color(0xFFFF7A1A);
const _foGreen = Color(0xFF059669);
const _foInk = Color(0xFF102033);
const _foMuted = Color(0xFF667085);
const _foLine = Color(0xFFE3E8F0);
const _foSoft = Color(0xFFF6F8FC);

class ProductFrontOfficeRegistryScreen extends StatefulWidget {
  const ProductFrontOfficeRegistryScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductFrontOfficeRegistryScreen> createState() =>
      _ProductFrontOfficeRegistryScreenState();
}

class _ProductFrontOfficeRegistryScreenState
    extends State<ProductFrontOfficeRegistryScreen> {
  final FrontOfficeRegistryService service =
      const FrontOfficeRegistryService();
  final TextEditingController teamController =
      TextEditingController(text: 'CHI');

  late Future<FrontOfficeRegistrySnapshot> future;
  String tab = 'Contracts';
  String season = '2025-26';
  Map<String, dynamic>? reconciliation;
  bool reconciling = false;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void dispose() {
    teamController.dispose();
    super.dispose();
  }

  Future<FrontOfficeRegistrySnapshot> _load() {
    return service.load(session: widget.session, season: season);
  }

  Future<void> _refresh() async {
    setState(() => future = _load());
    await future;
  }

  Future<void> _reconcile() async {
    final team = teamController.text.trim().toUpperCase();
    if (team.isEmpty) return;
    setState(() => reconciling = true);
    final result = await service.reconcile(teamId: team, season: season);
    if (!mounted) return;
    setState(() {
      reconciliation = result;
      reconciling = false;
    });
  }

  Future<void> _createContract() async {
    final record = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _ContractDialog(),
    );
    if (record == null) return;
    final id = 'contract-${record['player_id']}-${record['team_id']}-$season'
        .toLowerCase();
    final saved = await service.upsertContract(
      session: widget.session,
      id: id,
      record: record,
    );
    if (!mounted) return;
    _show(saved == null
        ? 'The backend is offline. Contract was not saved remotely.'
        : 'Contract saved as ${saved['source_status']} source data.');
    await _refresh();
  }

  Future<void> _createPosition() async {
    final record = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _TeamPositionDialog(),
    );
    if (record == null) return;
    final id = 'position-${record['team_id']}-$season'.toLowerCase();
    final saved = await service.upsertTeamPosition(
      session: widget.session,
      id: id,
      record: record,
    );
    if (!mounted) return;
    _show(saved == null
        ? 'The backend is offline. Team position was not saved remotely.'
        : 'Team position saved and validated.');
    await _refresh();
  }

  Future<void> _createAsset() async {
    final record = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _DraftAssetDialog(),
    );
    if (record == null) return;
    final id = 'asset-${record['current_team_id']}-${record['draft_year']}-${record['round']}-${DateTime.now().millisecondsSinceEpoch}'
        .toLowerCase();
    final saved = await service.upsertDraftAsset(
      session: widget.session,
      id: id,
      record: record,
    );
    if (!mounted) return;
    _show(saved == null
        ? 'The backend is offline. Draft asset was not saved remotely.'
        : 'Draft asset saved with protection and provenance metadata.');
    await _refresh();
  }

  Future<void> _createLedger() async {
    final record = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _LedgerDialog(
        organizationId: widget.session.organizationId,
      ),
    );
    if (record == null) return;
    final id = 'ledger-${DateTime.now().millisecondsSinceEpoch}';
    final saved = await service.upsertLedger(
      session: widget.session,
      id: id,
      record: record,
    );
    if (!mounted) return;
    _show(saved == null
        ? 'The backend is offline. Ledger transaction was not saved remotely.'
        : 'Transaction added to the versioned ledger.');
    await _refresh();
  }

  Future<void> _versions(Map<String, dynamic> item) async {
    final versions = await service.versions(item['id']?.toString() ?? '');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Version history · ${item['id']}'),
        content: SizedBox(
          width: 720,
          child: versions.isEmpty
              ? const Text('No version history is available.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: versions.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final version = versions[index];
                    final validation = version['validation'];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${version['version']}'),
                      ),
                      title: Text('Version ${version['version']}'),
                      subtitle: Text(
                        '${version['created_at']} · ${validation is Map ? validation['status'] : 'unknown'}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _route(Map<String, dynamic> item, String target) {
    final record = item['record'] is Map
        ? (item['record'] as Map)
            .map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final flattened = <String, dynamic>{
      for (final entry in record.entries)
        entry.key: entry.value is Map || entry.value is List
            ? jsonEncode(entry.value)
            : entry.value,
    };
    final columns = <RoutePayloadColumn>[
      for (final entry in flattened.entries)
        RoutePayloadColumn(
          key: entry.key,
          label: _label(entry.key),
          dataType: entry.value is num ? 'number' : 'text',
          unit: entry.key.contains('salary') || entry.key.contains('amount')
              ? 'USD'
              : '',
        ),
    ];
    final validation = item['validation'];
    final errors = validation is Map && validation['errors'] is List
        ? [for (final value in validation['errors'] as List) value.toString()]
        : <String>[];
    final payload = RoutePayload(
      sourceObjectType: 'Front Office ${item['record_type']}',
      sourceObjectId: item['id']?.toString() ?? 'unknown',
      displayLabel: _recordTitle(item),
      selectedColumns: [for (final column in columns) column.key],
      selectedRows: const ['registered record'],
      filterSummary: 'Season $season · source ${item['source_status']}',
      sourceSnapshot:
          '${item['source_status']} · version ${item['version']} · ${item['updated_at']}',
      readinessState: errors.isEmpty ? 'Ready' : 'Blocked',
      blockers: errors,
      targetRoute: target,
      availableActions: const [
        'Open',
        'Workspace',
        'Python Lab',
        'Source Audit',
      ],
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      columns: columns,
      rows: [flattened],
      metadata: {
        'recordType': item['record_type'],
        'sourceStatus': item['source_status'],
        'version': item['version'],
        'validation': item['validation'],
      },
    );
    RoutePayloadScope.maybeOf(context)?.setActivePayload(
      payload,
      origin: 'Contracts & Assets registry',
    );
    _show('${_recordTitle(item)} routed to $target.');
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FrontOfficeRegistrySnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Surface(
            child: Text(
              'Loading contracts, cap positions, draft assets and ledger...',
              style: TextStyle(color: _foMuted),
            ),
          );
        }
        if (snapshot.hasError) {
          return _Surface(
            child: Text(
              'Front-office registry unavailable: ${snapshot.error}',
              style: const TextStyle(color: _foMuted),
            ),
          );
        }
        final data = snapshot.data!;
        final rows = switch (tab) {
          'Contracts' => data.contracts,
          'Team Cap' => data.teamPositions,
          'Draft Assets' => data.draftAssets,
          'Ledger' => data.ledger,
          _ => const <Map<String, dynamic>>[],
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(remote: data.remoteAvailable),
            const SizedBox(height: 18),
            _MetricGrid(
              items: [
                _Metric('Contracts', '${data.contracts.length}', 'versioned'),
                _Metric('Team positions', '${data.teamPositions.length}', season),
                _Metric('Draft assets', '${data.draftAssets.length}', 'ownership ledger'),
                _Metric('Transactions', '${data.ledger.length}', 'immutable events'),
                _Metric('Verified', '${data.verifiedCount}', 'source-backed'),
                _Metric('Needs review', '${data.reviewCount}', 'validation state'),
              ],
            ),
            const SizedBox(height: 18),
            _Toolbar(
              tab: tab,
              season: season,
              onTab: (value) => setState(() => tab = value),
              onSeason: (value) {
                setState(() {
                  season = value;
                  future = _load();
                });
              },
              onRefresh: _refresh,
              onCreate: switch (tab) {
                'Contracts' => _createContract,
                'Team Cap' => _createPosition,
                'Draft Assets' => _createAsset,
                'Ledger' => _createLedger,
                _ => null,
              },
            ),
            const SizedBox(height: 18),
            if (tab == 'Reconcile')
              _ReconciliationPanel(
                teamController: teamController,
                season: season,
                loading: reconciling,
                result: reconciliation,
                onRun: _reconcile,
              )
            else
              _RegistryTable(
                tab: tab,
                rows: rows,
                onVersions: _versions,
                onRoute: _route,
              ),
            const SizedBox(height: 18),
            const _BoundaryNotice(),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.remote});
  final bool remote;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [_foNavy, _foBlue, _foOrange],
          ),
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CONTRACTS, ASSETS & TRANSACTION LEDGER',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                _Pill(
                  remote ? 'SHARED REGISTRY' : 'LOCAL CACHE',
                  remote ? _foGreen : _foOrange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'One source of truth for front-office work.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 930,
              child: Text(
                'Register contract years, guarantees, options, incentives, cap holds, exceptions, draft protections, swap rights and completed or modeled transactions. Every record is versioned, validated, source-classified and routable into Workspace or Python Lab.',
                style: TextStyle(
                  color: Color(0xFFEAF2FF),
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.tab,
    required this.season,
    required this.onTab,
    required this.onSeason,
    required this.onRefresh,
    required this.onCreate,
  });

  final String tab;
  final String season;
  final ValueChanged<String> onTab;
  final ValueChanged<String> onSeason;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in const [
              'Contracts',
              'Team Cap',
              'Draft Assets',
              'Ledger',
              'Reconcile',
            ])
              ChoiceChip(
                label: Text(item),
                selected: tab == item,
                selectedColor: _foNavy,
                labelStyle: TextStyle(
                  color: tab == item ? Colors.white : _foInk,
                  fontWeight: FontWeight.w900,
                ),
                onSelected: (_) => onTab(item),
              ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: season,
              items: const [
                DropdownMenuItem(value: '2024-25', child: Text('2024–25')),
                DropdownMenuItem(value: '2025-26', child: Text('2025–26')),
                DropdownMenuItem(value: '2026-27', child: Text('2026–27')),
              ],
              onChanged: (value) {
                if (value != null) onSeason(value);
              },
            ),
            IconButton(
              tooltip: 'Refresh registry',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (onCreate != null)
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text('Add ${tab == 'Team Cap' ? 'position' : tab.toLowerCase()}'),
              ),
          ],
        ),
      );
}

class _RegistryTable extends StatelessWidget {
  const _RegistryTable({
    required this.tab,
    required this.rows,
    required this.onVersions,
    required this.onRoute,
  });

  final String tab;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onVersions;
  final void Function(Map<String, dynamic>, String) onRoute;

  @override
  Widget build(BuildContext context) => _Surface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '$tab registry',
                style: const TextStyle(
                  color: _foInk,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  'No records exist yet. Add a modeled or sourced record to establish the registry.',
                  style: TextStyle(color: _foMuted),
                ),
              )
            else
              for (final item in rows)
                _RegistryRow(
                  item: item,
                  onVersions: () => onVersions(item),
                  onRoute: (target) => onRoute(item, target),
                ),
          ],
        ),
      );
}

class _RegistryRow extends StatelessWidget {
  const _RegistryRow({
    required this.item,
    required this.onVersions,
    required this.onRoute,
  });

  final Map<String, dynamic> item;
  final VoidCallback onVersions;
  final ValueChanged<String> onRoute;

  @override
  Widget build(BuildContext context) {
    final validation = item['validation'];
    final status = validation is Map
        ? validation['status']?.toString() ?? 'unknown'
        : 'unknown';
    final warnings = validation is Map && validation['warnings'] is List
        ? (validation['warnings'] as List).length
        : 0;
    final errors = validation is Map && validation['errors'] is List
        ? (validation['errors'] as List).length
        : 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _foLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _foSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_recordIcon(item['record_type']?.toString() ?? '')),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _recordTitle(item),
                      style: const TextStyle(
                        color: _foInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _Pill(
                      item['source_status']?.toString().toUpperCase() ??
                          'MODELED',
                      item['source_status'] == 'verified'
                          ? _foGreen
                          : _foOrange,
                    ),
                    _Pill(
                      status.toUpperCase(),
                      status == 'pass'
                          ? _foGreen
                          : status == 'fail'
                              ? Colors.red
                              : _foOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${item['season']} · version ${item['version']} · $warnings warnings · $errors errors · updated ${item['updated_at']}',
                  style: const TextStyle(
                    color: _foMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _recordDetail(item),
                  style: const TextStyle(color: _foMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Record actions',
            onSelected: (value) {
              if (value == 'versions') {
                onVersions();
              } else {
                onRoute(value);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Workspace', child: Text('Route to Workspace')),
              PopupMenuItem(value: 'Python Lab', child: Text('Route to Python Lab')),
              PopupMenuItem(value: 'Source Audit', child: Text('Route to Source Audit')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'versions', child: Text('View version history')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReconciliationPanel extends StatelessWidget {
  const _ReconciliationPanel({
    required this.teamController,
    required this.season,
    required this.loading,
    required this.result,
    required this.onRun,
  });

  final TextEditingController teamController;
  final String season;
  final bool loading;
  final Map<String, dynamic>? result;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team financial reconciliation',
              style: TextStyle(
                color: _foInk,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compare registered contract-year cap charges with the latest registered team financial position and identify source or balance gaps.',
              style: TextStyle(color: _foMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: teamController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Team ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: loading ? null : onRun,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.balance_rounded),
                  label: Text('Reconcile $season'),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 20),
              _MetricGrid(
                items: [
                  _Metric('Contract cap charge', _money(result!['contract_cap_charge']), '${result!['contract_count']} contracts'),
                  _Metric('Reported active salary', _money(result!['reported_active_salary']), 'team position'),
                  _Metric('Variance', _money(result!['active_salary_variance']), result!['status']?.toString() ?? 'review'),
                  _Metric('Guaranteed', _money(result!['guaranteed_amount']), 'registered years'),
                  _Metric('Draft assets', '${result!['draft_asset_count']}', 'current owner'),
                  _Metric('Ledger entries', '${result!['ledger_transaction_count']}', season),
                ],
              ),
              const SizedBox(height: 16),
              if (result!['blockers'] is List &&
                  (result!['blockers'] as List).isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    border: Border.all(color: const Color(0xFFFFD28A)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reconciliation blockers',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      for (final blocker in result!['blockers'] as List)
                        Text('• $blocker'),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
}

class _ContractDialog extends StatefulWidget {
  const _ContractDialog();

  @override
  State<_ContractDialog> createState() => _ContractDialogState();
}

class _ContractDialogState extends State<_ContractDialog> {
  final playerId = TextEditingController();
  final playerName = TextEditingController();
  final team = TextEditingController();
  final salary = TextEditingController();
  final guaranteed = TextEditingController();
  final sourceLabel = TextEditingController();
  final sourceReference = TextEditingController();
  String sourceStatus = 'modeled';
  String optionType = 'none';
  bool noTrade = false;

  @override
  void dispose() {
    for (final controller in [
      playerId,
      playerName,
      team,
      salary,
      guaranteed,
      sourceLabel,
      sourceReference,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Register player contract'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _DialogField(controller: playerId, label: 'Player ID'),
                _DialogField(controller: playerName, label: 'Player name'),
                _DialogField(controller: team, label: 'Team ID'),
                _DialogField(controller: salary, label: '2025–26 salary in millions', number: true),
                _DialogField(controller: guaranteed, label: 'Guaranteed amount in millions', number: true),
                DropdownButtonFormField<String>(
                  initialValue: optionType,
                  decoration: const InputDecoration(labelText: 'Option type'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(value: 'player', child: Text('Player option')),
                    DropdownMenuItem(value: 'team', child: Text('Team option')),
                    DropdownMenuItem(value: 'early_termination', child: Text('Early termination')),
                  ],
                  onChanged: (value) => setState(() => optionType = value ?? 'none'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: noTrade,
                  title: const Text('No-trade clause'),
                  onChanged: (value) => setState(() => noTrade = value),
                ),
                _SourceFields(
                  status: sourceStatus,
                  onStatus: (value) => setState(() => sourceStatus = value),
                  labelController: sourceLabel,
                  referenceController: sourceReference,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final salaryValue = double.tryParse(salary.text.trim()) ?? 0;
              final guaranteedValue = double.tryParse(guaranteed.text.trim()) ?? salaryValue;
              Navigator.of(context).pop({
                'player_id': playerId.text.trim(),
                'player_name': playerName.text.trim(),
                'team_id': team.text.trim().toUpperCase(),
                'season': '2025-26',
                'contract_type': 'standard',
                'years': [
                  {
                    'season': '2025-26',
                    'salary': salaryValue * 1000000,
                    'guaranteed_amount': guaranteedValue * 1000000,
                    'likely_incentives': 0,
                    'unlikely_incentives': 0,
                    'dead_money': 0,
                    'option_type': optionType,
                  }
                ],
                'no_trade_clause': noTrade,
                'source_status': sourceStatus,
                'source_label': sourceLabel.text.trim(),
                if (sourceReference.text.trim().startsWith('http'))
                  'source_url': sourceReference.text.trim()
                else
                  'source_document_id': sourceReference.text.trim(),
                'as_of_date': DateTime.now().toIso8601String().split('T').first,
              });
            },
            child: const Text('Save contract'),
          ),
        ],
      );
}

class _TeamPositionDialog extends StatefulWidget {
  const _TeamPositionDialog();

  @override
  State<_TeamPositionDialog> createState() => _TeamPositionDialogState();
}

class _TeamPositionDialogState extends State<_TeamPositionDialog> {
  final team = TextEditingController();
  final activeSalary = TextEditingController();
  final capHolds = TextEditingController(text: '0');
  final deadMoney = TextEditingController(text: '0');
  final sourceLabel = TextEditingController();
  final sourceReference = TextEditingController();
  String sourceStatus = 'modeled';

  @override
  void dispose() {
    for (final controller in [team, activeSalary, capHolds, deadMoney, sourceLabel, sourceReference]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Register team financial position'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _DialogField(controller: team, label: 'Team ID'),
                _DialogField(controller: activeSalary, label: 'Active salary in millions', number: true),
                _DialogField(controller: capHolds, label: 'Cap holds in millions', number: true),
                _DialogField(controller: deadMoney, label: 'Dead money in millions', number: true),
                _SourceFields(
                  status: sourceStatus,
                  onStatus: (value) => setState(() => sourceStatus = value),
                  labelController: sourceLabel,
                  referenceController: sourceReference,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'team_id': team.text.trim().toUpperCase(),
              'season': '2025-26',
              'salary_cap': 154647000,
              'luxury_tax': 187895000,
              'first_apron': 195945000,
              'second_apron': 207824000,
              'active_salary': (double.tryParse(activeSalary.text) ?? 0) * 1000000,
              'cap_holds': (double.tryParse(capHolds.text) ?? 0) * 1000000,
              'dead_money': (double.tryParse(deadMoney.text) ?? 0) * 1000000,
              'incomplete_roster_charges': 0,
              'hard_cap': 0,
              'exceptions': const [],
              'source_status': sourceStatus,
              'source_label': sourceLabel.text.trim(),
              if (sourceReference.text.trim().startsWith('http'))
                'source_url': sourceReference.text.trim()
              else
                'source_document_id': sourceReference.text.trim(),
              'as_of_date': DateTime.now().toIso8601String().split('T').first,
            }),
            child: const Text('Save position'),
          ),
        ],
      );
}

class _DraftAssetDialog extends StatefulWidget {
  const _DraftAssetDialog();

  @override
  State<_DraftAssetDialog> createState() => _DraftAssetDialogState();
}

class _DraftAssetDialogState extends State<_DraftAssetDialog> {
  final currentTeam = TextEditingController();
  final originalTeam = TextEditingController();
  final year = TextEditingController(text: '2029');
  final description = TextEditingController();
  final protection = TextEditingController();
  final sourceLabel = TextEditingController();
  final sourceReference = TextEditingController();
  String sourceStatus = 'modeled';
  int round = 1;
  String assetType = 'pick';
  bool encumbered = false;
  bool stepienEligible = true;

  @override
  void dispose() {
    for (final controller in [currentTeam, originalTeam, year, description, protection, sourceLabel, sourceReference]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Register draft asset'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _DialogField(controller: currentTeam, label: 'Current owner team ID'),
                _DialogField(controller: originalTeam, label: 'Original team ID'),
                _DialogField(controller: year, label: 'Draft year', number: true),
                DropdownButtonFormField<int>(
                  initialValue: round,
                  decoration: const InputDecoration(labelText: 'Round'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('First round')),
                    DropdownMenuItem(value: 2, child: Text('Second round')),
                  ],
                  onChanged: (value) => setState(() => round = value ?? 1),
                ),
                DropdownButtonFormField<String>(
                  initialValue: assetType,
                  decoration: const InputDecoration(labelText: 'Asset type'),
                  items: const [
                    DropdownMenuItem(value: 'pick', child: Text('Pick')),
                    DropdownMenuItem(value: 'swap', child: Text('Swap right')),
                    DropdownMenuItem(value: 'conditional', child: Text('Conditional pick')),
                  ],
                  onChanged: (value) => setState(() => assetType = value ?? 'pick'),
                ),
                _DialogField(controller: description, label: 'Description'),
                _DialogField(controller: protection, label: 'Protection condition'),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: encumbered,
                  title: const Text('Encumbered'),
                  onChanged: (value) => setState(() => encumbered = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: stepienEligible,
                  title: const Text('Modeled Stepien eligible'),
                  onChanged: (value) => setState(() => stepienEligible = value),
                ),
                _SourceFields(
                  status: sourceStatus,
                  onStatus: (value) => setState(() => sourceStatus = value),
                  labelController: sourceLabel,
                  referenceController: sourceReference,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final draftYear = int.tryParse(year.text.trim()) ?? 2029;
              Navigator.of(context).pop({
                'current_team_id': currentTeam.text.trim().toUpperCase(),
                'original_team_id': originalTeam.text.trim().toUpperCase(),
                'draft_year': draftYear,
                'round': round,
                'asset_type': assetType,
                'description': description.text.trim(),
                'protections': protection.text.trim().isEmpty
                    ? const []
                    : [
                        {
                          'year': draftYear,
                          'condition': protection.text.trim(),
                          'fallback': '',
                        }
                      ],
                'swap_terms': assetType == 'swap' ? description.text.trim() : '',
                'conveyance_chain': const [],
                'encumbered': encumbered,
                'stepien_eligible': stepienEligible,
                'source_status': sourceStatus,
                'source_label': sourceLabel.text.trim(),
                if (sourceReference.text.trim().startsWith('http'))
                  'source_url': sourceReference.text.trim()
                else
                  'source_document_id': sourceReference.text.trim(),
                'as_of_date': DateTime.now().toIso8601String().split('T').first,
              });
            },
            child: const Text('Save asset'),
          ),
        ],
      );
}

class _LedgerDialog extends StatefulWidget {
  const _LedgerDialog({required this.organizationId});
  final String organizationId;

  @override
  State<_LedgerDialog> createState() => _LedgerDialogState();
}

class _LedgerDialogState extends State<_LedgerDialog> {
  final teams = TextEditingController();
  final summary = TextEditingController();
  final effectiveDate = TextEditingController();
  final sourceLabel = TextEditingController();
  final sourceReference = TextEditingController();
  String sourceStatus = 'modeled';
  String transactionType = 'trade';

  @override
  void dispose() {
    for (final controller in [teams, summary, effectiveDate, sourceLabel, sourceReference]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add transaction ledger entry'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _DialogField(controller: teams, label: 'Team IDs, comma separated'),
                _DialogField(controller: summary, label: 'Transaction summary', lines: 3),
                _DialogField(controller: effectiveDate, label: 'Effective date, YYYY-MM-DD'),
                DropdownButtonFormField<String>(
                  initialValue: transactionType,
                  decoration: const InputDecoration(labelText: 'Transaction type'),
                  items: const [
                    DropdownMenuItem(value: 'trade', child: Text('Trade')),
                    DropdownMenuItem(value: 'signing', child: Text('Signing')),
                    DropdownMenuItem(value: 'waiver', child: Text('Waiver')),
                    DropdownMenuItem(value: 'extension', child: Text('Extension')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft transaction')),
                  ],
                  onChanged: (value) => setState(() => transactionType = value ?? 'trade'),
                ),
                _SourceFields(
                  status: sourceStatus,
                  onStatus: (value) => setState(() => sourceStatus = value),
                  labelController: sourceLabel,
                  referenceController: sourceReference,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'organization_id': widget.organizationId,
              'case_id': '',
              'season': '2025-26',
              'transaction_type': transactionType,
              'effective_date': effectiveDate.text.trim(),
              'status': 'modeled',
              'teams': [
                for (final team in teams.text.split(','))
                  if (team.trim().isNotEmpty) team.trim().toUpperCase(),
              ],
              'summary': summary.text.trim(),
              'contract_ids': const [],
              'draft_asset_ids': const [],
              'salary_movements': const [],
              'assumptions': const [],
              'approvals': const [],
              'source_status': sourceStatus,
              'source_label': sourceLabel.text.trim(),
              if (sourceReference.text.trim().startsWith('http'))
                'source_url': sourceReference.text.trim()
              else
                'source_document_id': sourceReference.text.trim(),
              'as_of_date': DateTime.now().toIso8601String().split('T').first,
            }),
            child: const Text('Save ledger entry'),
          ),
        ],
      );
}

class _SourceFields extends StatelessWidget {
  const _SourceFields({
    required this.status,
    required this.onStatus,
    required this.labelController,
    required this.referenceController,
  });

  final String status;
  final ValueChanged<String> onStatus;
  final TextEditingController labelController;
  final TextEditingController referenceController;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Source status'),
            items: const [
              DropdownMenuItem(value: 'modeled', child: Text('Modeled')),
              DropdownMenuItem(value: 'uploaded', child: Text('Uploaded')),
              DropdownMenuItem(value: 'verified', child: Text('Verified')),
            ],
            onChanged: (value) => onStatus(value ?? 'modeled'),
          ),
          _DialogField(controller: labelController, label: 'Source label'),
          _DialogField(controller: referenceController, label: 'Source URL or document ID'),
          if (status == 'verified')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Verified records require both a source label and a source URL or document ID.',
                style: TextStyle(color: _foMuted, fontSize: 12),
              ),
            ),
        ],
      );
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.number = false,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool number;
  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          controller: controller,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          minLines: lines,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class _BoundaryNotice extends StatelessWidget {
  const _BoundaryNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          border: Border.all(color: const Color(0xFFFFD28A)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Authoritative use requires licensed or otherwise approved contract and draft data, complete team salary facts, verified transaction dates, sourced protections and final CBA/legal review. Modeled and uploaded records remain visibly distinct from verified records.',
          style: TextStyle(color: _foInk, height: 1.45, fontWeight: FontWeight.w600),
        ),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - 20) / 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in items) SizedBox(width: width, child: item),
            ],
          );
        },
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _foMuted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: _foInk, fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: _foMuted, fontSize: 12)),
          ],
        ),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _foLine),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 22, offset: Offset(0, 10)),
          ],
        ),
        child: child,
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
}

String _recordTitle(Map<String, dynamic> item) {
  final record = item['record'];
  if (record is! Map) return item['id']?.toString() ?? 'Untitled record';
  return switch (item['record_type']) {
    'contract' => '${record['player_name']} · ${record['team_id']}',
    'team_position' => '${record['team_id']} financial position',
    'draft_asset' => record['description']?.toString().isNotEmpty == true
        ? record['description'].toString()
        : '${record['current_team_id']} ${record['draft_year']} R${record['round']}',
    'ledger' => record['summary']?.toString() ?? 'Ledger transaction',
    _ => item['id']?.toString() ?? 'Untitled record',
  };
}

String _recordDetail(Map<String, dynamic> item) {
  final record = item['record'];
  if (record is! Map) return '';
  if (item['record_type'] == 'contract') {
    final years = record['years'];
    if (years is List && years.isNotEmpty && years.first is Map) {
      final year = years.first as Map;
      return '${year['season']} salary ${_money(year['salary'])} · guaranteed ${_money(year['guaranteed_amount'])} · ${year['option_type']} option';
    }
  }
  if (item['record_type'] == 'team_position') {
    return 'Active salary ${_money(record['active_salary'])} · cap holds ${_money(record['cap_holds'])} · dead money ${_money(record['dead_money'])}';
  }
  if (item['record_type'] == 'draft_asset') {
    return 'Original ${record['original_team_id']} · current ${record['current_team_id']} · ${record['asset_type']} · Stepien ${record['stepien_eligible']}';
  }
  if (item['record_type'] == 'ledger') {
    final teams = record['teams'];
    return '${teams is List ? teams.join(' ↔ ') : ''} · ${record['transaction_type']} · effective ${record['effective_date']?.toString().isEmpty == true ? 'unspecified' : record['effective_date']}';
  }
  return '';
}

IconData _recordIcon(String type) => switch (type) {
      'contract' => Icons.description_rounded,
      'team_position' => Icons.account_balance_wallet_rounded,
      'draft_asset' => Icons.inventory_2_rounded,
      'ledger' => Icons.receipt_long_rounded,
      _ => Icons.folder_rounded,
    };

String _label(String key) => key
    .split('_')
    .map((part) => part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _money(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return '\$${(number / 1000000).toStringAsFixed(1)}M';
}
