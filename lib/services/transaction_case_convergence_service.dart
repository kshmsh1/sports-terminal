import 'dart:convert';

import '../models/app_session.dart';
import '../models/route_payload.dart';
import '../models/transaction_case.dart';
import '../models/transaction_workflow.dart';
import 'cba_transaction_rules_engine.dart';
import 'product_local_store.dart';
import 'transaction_case_repository.dart';
import 'transaction_workflow_repository.dart';

class TransactionImportCandidate {
  const TransactionImportCandidate({
    required this.id,
    required this.source,
    required this.title,
    required this.operatingSeason,
    required this.teams,
    required this.summary,
    required this.assumptions,
    required this.sourcePayloadId,
    this.currentTeamSalary = 0,
    this.outgoingSalary = 0,
    this.incomingSalary = 0,
    this.firstApron = 209015000,
    this.secondApron = 221686000,
    this.findings = const [],
    this.readiness = 'Ready to import',
  });

  final String id;
  final String source;
  final String title;
  final String operatingSeason;
  final List<String> teams;
  final String summary;
  final List<String> assumptions;
  final String sourcePayloadId;
  final double currentTeamSalary;
  final double outgoingSalary;
  final double incomingSalary;
  final double firstApron;
  final double secondApron;
  final List<String> findings;
  final String readiness;
}

class TransactionCaseConvergenceService {
  const TransactionCaseConvergenceService({
    ProductLocalStore store = const ProductLocalStore(),
    TransactionCaseRepository cases = const TransactionCaseRepository(),
    TransactionWorkflowRepository workflow = const TransactionWorkflowRepository(),
    CbaTransactionRulesEngine rules = const CbaTransactionRulesEngine(),
  })  : _store = store,
        _cases = cases,
        _workflow = workflow,
        _rules = rules;

  static const _frontOfficeLedgerKey = 'sports_terminal.front_office.ledger_v1';

  final ProductLocalStore _store;
  final TransactionCaseRepository _cases;
  final TransactionWorkflowRepository _workflow;
  final CbaTransactionRulesEngine _rules;

  Future<List<TransactionImportCandidate>> discover() async {
    final candidates = <TransactionImportCandidate>[];
    final trade = await _tradeCandidate();
    final frontOffice = await _frontOfficeCandidate();
    final route = await _routeCandidate();
    final cap = await _capCandidate();
    if (trade != null) candidates.add(trade);
    if (frontOffice != null) candidates.add(frontOffice);
    if (route != null) candidates.add(route);
    if (cap != null) candidates.add(cap);
    return candidates;
  }

  Future<TransactionCase> importCandidate({
    required TransactionImportCandidate candidate,
    required AppSession session,
    required bool organizationVisible,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final report = _rules.evaluate(TransactionRuleInput(
      currentTeamSalary: candidate.currentTeamSalary,
      outgoingSalary: candidate.outgoingSalary,
      incomingSalary: candidate.incomingSalary,
      salaryCap: 164961000,
      firstApron: candidate.firstApron,
      secondApron: candidate.secondApron,
      pickTermsVerified: !candidate.findings.any(
        (finding) => finding.toLowerCase().contains('unverified'),
      ),
    ));
    final item = TransactionCase(
      id: '${session.userId}_${DateTime.now().microsecondsSinceEpoch}',
      title: candidate.title,
      organizationId: session.organizationId,
      organizationName: session.organizationName,
      ownerUserId: session.userId,
      ownerName: session.displayName,
      operatingSeason: candidate.operatingSeason,
      teams: candidate.teams,
      status: organizationVisible
          ? TransactionCaseStatus.review
          : TransactionCaseStatus.analysis,
      priority: TransactionCasePriority.normal,
      createdAtIso: now,
      updatedAtIso: now,
      summary: candidate.summary,
      assumptions: candidate.assumptions,
      outgoingSalary: candidate.outgoingSalary,
      incomingSalary: candidate.incomingSalary,
      currentTeamSalary: candidate.currentTeamSalary,
      firstApron: candidate.firstApron,
      secondApron: candidate.secondApron,
      ruleFindings: [...candidate.findings, ...report.labels],
      approvals: organizationVisible
          ? [
              TransactionApproval(
                approverId: 'organization-review',
                approverName: '${session.organizationName} review queue',
                decision: TransactionApprovalDecision.pending,
                updatedAtIso: now,
              ),
            ]
          : const [],
      comments: [
        TransactionCaseComment(
          authorId: session.userId,
          authorName: session.displayName,
          body: 'Imported from ${candidate.source}.',
          createdAtIso: now,
        ),
      ],
      assignedUserIds: [session.userId],
      sourcePayloadId: candidate.sourcePayloadId,
      isOrganizationVisible: organizationVisible,
    );
    await _cases.upsertPersonal(session.userId, item);
    if (organizationVisible) {
      await _cases.upsertOrganization(session.organizationId, item);
    }
    await _workflow.addActivity(TransactionActivity(
      id: 'activity_${DateTime.now().microsecondsSinceEpoch}',
      caseId: item.id,
      organizationId: session.organizationId,
      actorUserId: session.userId,
      actorName: session.displayName,
      kind: TransactionActivityKind.imported,
      message: 'Imported ${candidate.source} into “${candidate.title}”.',
      createdAtIso: now,
      recipientUserId: session.userId,
    ));
    await _workflow.addNotification(TransactionNotification(
      id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
      caseId: item.id,
      organizationId: session.organizationId,
      recipientUserId: session.userId,
      title: organizationVisible ? 'Case submitted for review' : 'Case imported',
      body: organizationVisible
          ? '${candidate.title} is now visible to ${session.organizationName}.'
          : '${candidate.title} was added to your private workbench.',
      createdAtIso: now,
    ));
    return item;
  }

  Future<TransactionImportCandidate?> _tradeCandidate() async {
    final state = await _store.loadStringMap(ProductLocalStore.tradeMachineStateKey);
    if (state.isEmpty) return null;
    final teams = (state['teams'] ?? '')
        .split('|')
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim().toUpperCase())
        .toList();
    final destinations = _decodePairs(state['destinations']);
    final year = state['year']?.trim().isNotEmpty == true ? state['year']! : '2026-27';
    final name = state['name']?.trim().isNotEmpty == true
        ? state['name']!.trim()
        : 'Saved Trade Machine scenario';
    return TransactionImportCandidate(
      id: 'trade-machine-current',
      source: 'Trade Machine',
      title: name,
      operatingSeason: year,
      teams: teams,
      summary: '${destinations.length} routed assets across ${teams.length} teams.',
      assumptions: [
        'Trade Machine scenario imported from local product state.',
        '${destinations.length} routed asset assignments.',
        if (state['selectedOnly'] == 'true') 'Selected-assets-only view was enabled.',
        'Contract salary values must be reconciled with the Front Office ledger.',
      ],
      sourcePayloadId: 'trade-machine:${teams.join('-')}:$year',
      findings: const [
        'WARNING · SOURCE_RECONCILIATION · Trade Machine proxy salaries require Front Office contract reconciliation.',
      ],
      readiness: destinations.isEmpty ? 'Scenario saved; no routed assets' : 'Routed scenario ready',
    );
  }

  Future<TransactionImportCandidate?> _frontOfficeCandidate() async {
    final raw = await _store.loadString(_frontOfficeLedgerKey);
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final season = map['season']?.toString() ?? '2026-27';
      final team = map['teamId']?.toString().toUpperCase() ?? '';
      final contracts = map['contracts'] as List? ?? const [];
      final picks = map['draftAssets'] as List? ?? const [];
      var contractSalary = 0.0;
      var noTradeCount = 0;
      for (final item in contracts) {
        if (item is! Map) continue;
        contractSalary += _number(item['salary']);
        if (item['noTradeClause'] == true) noTradeCount++;
      }
      final charges = _storedMillions(map['deadMoney']) +
          _storedMillions(map['capHolds']) +
          _storedMillions(map['draftHolds']) +
          _storedMillions(map['rosterCharges']);
      final unverifiedPicks = picks.where((item) {
        if (item is! Map) return false;
        final protection = item['protections']?.toString().trim() ?? '';
        return protection.isEmpty || protection == 'Unspecified';
      }).length;
      return TransactionImportCandidate(
        id: 'front-office-current',
        source: 'Front Office Ledger',
        title: '$team $season front-office package',
        operatingSeason: season,
        teams: team.isEmpty ? const [] : [team],
        summary: '${contracts.length} contract rows and ${picks.length} draft assets.',
        assumptions: [
          '${contracts.length} contract records.',
          '${picks.length} draft assets.',
          'Non-contract charges: ${_money(charges)}.',
          if (noTradeCount > 0) '$noTradeCount contracts include no-trade consent assumptions.',
        ],
        sourcePayloadId: 'front-office:$team:$season',
        currentTeamSalary: contractSalary + charges,
        findings: [
          if (noTradeCount > 0)
            'BLOCKER · NO_TRADE_CONSENT · $noTradeCount contract records require consent review.',
          if (unverifiedPicks > 0)
            'WARNING · PICK_TERMS_UNVERIFIED · $unverifiedPicks draft assets have unspecified protections.',
        ],
        readiness: contracts.isEmpty && picks.isEmpty
            ? 'Ledger saved; add contracts or draft assets'
            : 'Ledger package ready',
      );
    } catch (_) {
      return null;
    }
  }

  Future<TransactionImportCandidate?> _routeCandidate() async {
    final payload = RoutePayload.tryDecode(
      await _store.loadString(ProductLocalStore.routePayloadActiveKey),
    );
    if (payload == null) return null;
    final metadataTeams = payload.metadata['teams'];
    final teams = metadataTeams is List
        ? [for (final value in metadataTeams) value.toString().toUpperCase()]
        : <String>[];
    return TransactionImportCandidate(
      id: 'route:${payload.routeKey}',
      source: 'Active routed package',
      title: payload.displayLabel,
      operatingSeason: payload.metadata['season']?.toString() ?? '2026-27',
      teams: teams,
      summary: '${payload.rowCount} rows routed from ${payload.sourceObjectType}.',
      assumptions: [
        payload.sourceSnapshot,
        payload.filterSummary,
        '${payload.columnCount} structured columns.',
        'Target route: ${payload.targetRoute}.',
      ].where((value) => value.trim().isNotEmpty).toList(),
      sourcePayloadId: payload.routeKey,
      findings: [
        for (final blocker in payload.blockers)
          'WARNING · ROUTE_BLOCKER · $blocker',
      ],
      readiness: payload.readinessState,
    );
  }

  Future<TransactionImportCandidate?> _capCandidate() async {
    final state = await _store.loadStringMap(ProductLocalStore.capLabStateKey);
    if (state.isEmpty) return null;
    final team = (state['team'] ?? state['teamId'] ?? '').toUpperCase();
    final season = state['season'] ?? state['year'] ?? '2026-27';
    final current = _storedMillions(state['teamSalary'] ?? state['currentSalary']);
    final first = _storedMillions(state['firstApron']);
    final second = _storedMillions(state['secondApron']);
    return TransactionImportCandidate(
      id: 'cap-lab-current',
      source: 'Cap Lab',
      title: team.isEmpty ? 'Saved Cap Lab scenario' : '$team $season cap scenario',
      operatingSeason: season,
      teams: team.isEmpty ? const [] : [team],
      summary: 'Saved Cap Lab environment with ${state.length} modeled fields.',
      assumptions: [
        for (final entry in state.entries.take(12)) '${entry.key}: ${entry.value}',
      ],
      sourcePayloadId: 'cap-lab:$team:$season',
      currentTeamSalary: current,
      firstApron: first > 0 ? first : 209015000,
      secondApron: second > 0 ? second : 221686000,
      readiness: 'Cap environment ready',
    );
  }
}

Map<String, String> _decodePairs(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final output = <String, String>{};
  for (final pair in raw.split('&')) {
    final index = pair.indexOf('=');
    if (index <= 0) continue;
    output[Uri.decodeComponent(pair.substring(0, index))] =
        Uri.decodeComponent(pair.substring(index + 1));
  }
  return output;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
}

double _storedMillions(Object? value) => _number(value) * 1000000;

String _money(double value) => '\$${(value / 1000000).toStringAsFixed(1)}M';
