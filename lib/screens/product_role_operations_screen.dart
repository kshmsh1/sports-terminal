import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/transaction_case.dart';
import '../services/cba_transaction_rules_engine.dart';
import '../services/transaction_case_repository.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF5F7FB);

class ProductRoleOperationsScreen extends StatefulWidget {
  const ProductRoleOperationsScreen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  State<ProductRoleOperationsScreen> createState() =>
      _ProductRoleOperationsScreenState();
}

class _ProductRoleOperationsScreenState
    extends State<ProductRoleOperationsScreen> {
  final repository = const TransactionCaseRepository();
  final rules = const CbaTransactionRulesEngine();
  final titleController = TextEditingController();
  final teamsController = TextEditingController(text: 'BOS, PHI');
  final currentSalaryController = TextEditingController(text: '200');
  final outgoingController = TextEditingController(text: '20');
  final incomingController = TextEditingController(text: '18');
  final firstApronController = TextEditingController(text: '209.015');
  final secondApronController = TextEditingController(text: '221.686');
  final noteController = TextEditingController();

  List<TransactionCase> cases = [];
  String selectedTab = 'Pipeline';
  TransactionCasePriority priority = TransactionCasePriority.normal;
  bool organizationVisible = false;
  bool aggregates = false;
  bool usesCash = false;
  bool usesException = false;
  bool noTradeClause = false;
  bool stepienAvailable = true;
  bool pickTermsVerified = true;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      titleController,
      teamsController,
      currentSalaryController,
      outgoingController,
      incomingController,
      firstApronController,
      secondApronController,
      noteController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = widget.organizationMode
        ? await repository.loadOrganization(widget.session.organizationId)
        : await repository.loadPersonal(widget.session.userId);
    if (!mounted) return;
    setState(() {
      cases = loaded;
      loading = false;
    });
  }

  double _millions(String value) =>
      (double.tryParse(value.trim()) ?? 0) * 1000000;

  TransactionRuleInput _ruleInput() {
    return TransactionRuleInput(
      currentTeamSalary: _millions(currentSalaryController.text),
      outgoingSalary: _millions(outgoingController.text),
      incomingSalary: _millions(incomingController.text),
      salaryCap: 164961000,
      firstApron: _millions(firstApronController.text),
      secondApron: _millions(secondApronController.text),
      aggregatesMultiplePlayers: aggregates,
      usesCash: usesCash,
      usesTradeException: usesException,
      hasNoTradeClause: noTradeClause,
      stepienAvailable: stepienAvailable,
      pickTermsVerified: pickTermsVerified,
    );
  }

  Future<void> _createCase() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      _show('Enter a case title.');
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final report = rules.evaluate(_ruleInput());
    final transactionCase = TransactionCase(
      id: '${widget.session.userId}_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      organizationId: widget.session.organizationId,
      organizationName: widget.session.organizationName,
      ownerUserId: widget.session.userId,
      ownerName: widget.session.displayName,
      operatingSeason: '2026-27',
      teams: teamsController.text
          .split(',')
          .map((item) => item.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toList(),
      status: widget.organizationMode
          ? TransactionCaseStatus.review
          : TransactionCaseStatus.analysis,
      priority: priority,
      createdAtIso: now,
      updatedAtIso: now,
      summary: noteController.text.trim(),
      outgoingSalary: _ruleInput().outgoingSalary,
      incomingSalary: _ruleInput().incomingSalary,
      currentTeamSalary: _ruleInput().currentTeamSalary,
      firstApron: _ruleInput().firstApron,
      secondApron: _ruleInput().secondApron,
      ruleFindings: report.labels,
      approvals: widget.organizationMode
          ? [
              TransactionApproval(
                approverId: 'org-admin',
                approverName: '${widget.session.organizationName} reviewer',
                decision: TransactionApprovalDecision.pending,
                updatedAtIso: now,
              ),
            ]
          : const [],
      assignedUserIds: [widget.session.userId],
      isOrganizationVisible:
          widget.organizationMode || organizationVisible,
    );
    await repository.upsertPersonal(widget.session.userId, transactionCase);
    if (transactionCase.isOrganizationVisible) {
      await repository.upsertOrganization(
        widget.session.organizationId,
        transactionCase,
      );
    }
    titleController.clear();
    noteController.clear();
    await _load();
    _show('Transaction case created with ${report.outcome.toLowerCase()}.');
  }

  Future<void> _transition(
    TransactionCase item,
    TransactionCaseStatus status,
  ) async {
    final updated = item.copyWith(
      status: status,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await repository.upsertPersonal(item.ownerUserId, updated);
    if (updated.isOrganizationVisible) {
      await repository.upsertOrganization(updated.organizationId, updated);
    }
    await _load();
  }

  Future<void> _decide(
    TransactionCase item,
    TransactionApprovalDecision decision,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final approval = TransactionApproval(
      approverId: widget.session.userId,
      approverName: widget.session.displayName,
      decision: decision,
      updatedAtIso: now,
      note: decision == TransactionApprovalDecision.approved
          ? 'Approved in organization operations center.'
          : 'Changes requested in organization operations center.',
    );
    final updated = item.copyWith(
      approvals: [approval],
      status: decision == TransactionApprovalDecision.approved
          ? TransactionCaseStatus.approved
          : TransactionCaseStatus.analysis,
      updatedAtIso: now,
    );
    await repository.upsertOrganization(updated.organizationId, updated);
    await repository.upsertPersonal(updated.ownerUserId, updated);
    await _load();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _Panel(child: Text('Loading transaction operations...'));
    }
    final metrics = TransactionCaseMetrics.fromCases(cases);
    final title = widget.organizationMode
        ? '${widget.session.organizationName} operations'
        : '${widget.session.displayName} workbench';
    final subtitle = widget.organizationMode
        ? 'Shared transaction portfolio, assignments, review queues and approval decisions for the organization.'
        : 'Private analysis queue, modeled transaction cases and a direct path to organization review.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(
          title: title,
          subtitle: subtitle,
          organizationMode: widget.organizationMode,
          metrics: metrics,
        ),
        const SizedBox(height: 18),
        _metrics(metrics),
        const SizedBox(height: 18),
        _tabs(),
        const SizedBox(height: 18),
        if (selectedTab == 'Builder')
          _builder()
        else if (selectedTab == 'Approvals')
          _approvals()
        else if (selectedTab == 'Portfolio')
          _portfolio()
        else
          _pipeline(),
      ],
    );
  }

  Widget _metrics(TransactionCaseMetrics metrics) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard('Total cases', '${metrics.total}', 'active and archived'),
        _MetricCard('Drafts', '${metrics.drafts}', 'not submitted'),
        _MetricCard('In review', '${metrics.inReview}', 'approval queue'),
        _MetricCard('Approved', '${metrics.approved}', 'completed decisions'),
        _MetricCard('Blocked', '${metrics.blocked}', 'changes or rejection'),
        _MetricCard('Urgent', '${metrics.urgent}', 'priority cases'),
      ],
    );
  }

  Widget _tabs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in const [
          'Pipeline',
          'Builder',
          'Approvals',
          'Portfolio',
        ])
          ChoiceChip(
            label: Text(tab),
            selected: selectedTab == tab,
            onSelected: (_) => setState(() => selectedTab = tab),
          ),
      ],
    );
  }

  Widget _builder() {
    final report = rules.evaluate(_ruleInput());
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.organizationMode
                ? 'Create organization transaction case'
                : 'Create personal transaction case',
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every value is modeled. The evaluator creates preliminary blockers and review flags, not final CBA approval.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _field(titleController, 'Case title', 260),
              _field(teamsController, 'Teams', 180),
              _field(currentSalaryController, 'Current salary · M', 170),
              _field(outgoingController, 'Outgoing · M', 150),
              _field(incomingController, 'Incoming · M', 150),
              _field(firstApronController, 'First apron · M', 160),
              _field(secondApronController, 'Second apron · M', 170),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<TransactionCasePriority>(
                  value: priority,
                  decoration: _input('Priority'),
                  items: [
                    for (final item in TransactionCasePriority.values)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => priority = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _flag('Aggregate players', aggregates,
                  (value) => setState(() => aggregates = value)),
              _flag('Uses cash', usesCash,
                  (value) => setState(() => usesCash = value)),
              _flag('Uses exception', usesException,
                  (value) => setState(() => usesException = value)),
              _flag('No-trade clause', noTradeClause,
                  (value) => setState(() => noTradeClause = value)),
              _flag('Stepien available', stepienAvailable,
                  (value) => setState(() => stepienAvailable = value)),
              _flag('Pick terms verified', pickTermsVerified,
                  (value) => setState(() => pickTermsVerified = value)),
              if (!widget.organizationMode)
                _flag('Share with organization', organizationVisible,
                    (value) => setState(() => organizationVisible = value)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: _input('Summary and assumptions'),
          ),
          const SizedBox(height: 14),
          _RulePreview(report: report),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _createCase,
            icon: const Icon(Icons.add_task_rounded),
            label: Text(widget.organizationMode
                ? 'Create and submit for review'
                : 'Save transaction case'),
          ),
        ],
      ),
    );
  }

  Widget _pipeline() {
    final statuses = TransactionCaseStatus.values
        .where((status) => status != TransactionCaseStatus.archived)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 900
            ? constraints.maxWidth
            : (constraints.maxWidth - 36) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final status in statuses)
              SizedBox(
                width: width,
                child: _CaseColumn(
                  status: status,
                  cases: cases.where((item) => item.status == status).toList(),
                  onTransition: _transition,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _approvals() {
    final queue = cases.where((item) => item.needsApproval).toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval queue',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (queue.isEmpty)
            const Text('No cases currently require approval.')
          else
            for (final item in queue)
              _ApprovalRow(
                item: item,
                organizationMode: widget.organizationMode,
                onDecision: _decide,
              ),
        ],
      ),
    );
  }

  Widget _portfolio() {
    final byTeam = <String, int>{};
    final byOwner = <String, int>{};
    for (final item in cases) {
      for (final team in item.teams) {
        byTeam[team] = (byTeam[team] ?? 0) + 1;
      }
      byOwner[item.ownerName] = (byOwner[item.ownerName] ?? 0) + 1;
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.organizationMode
                ? 'Organization portfolio'
                : 'Personal portfolio',
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _Breakdown(
                title: 'Cases by team',
                values: byTeam,
              ),
              _Breakdown(
                title: widget.organizationMode
                    ? 'Cases by owner'
                    : 'Ownership',
                values: byOwner,
              ),
              _Breakdown(
                title: 'Cases by priority',
                values: {
                  for (final priority in TransactionCasePriority.values)
                    priority.name: cases
                        .where((item) => item.priority == priority)
                        .length,
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: _input(label),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _flag(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.organizationMode,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final bool organizationMode;
  final TransactionCaseMetrics metrics;

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
          Text(
            organizationMode ? 'ORGANIZATION TERMINAL' : 'INDIVIDUAL TERMINAL',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 820,
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFEAF2FF),
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('${metrics.total} CASES'),
              _pill('${metrics.inReview} IN REVIEW'),
              _pill('${metrics.approved} APPROVED'),
              _pill(organizationMode ? 'SHARED PORTFOLIO' : 'PRIVATE WORKBENCH'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      );
}

class _RulePreview extends StatelessWidget {
  const _RulePreview({required this.report});
  final TransactionRuleReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: report.hasBlockers
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: report.hasBlockers
              ? const Color(0xFFFECACA)
              : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.outcome,
            style: TextStyle(
              color: report.hasBlockers ? _red : _green,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final finding in report.findings)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                finding.label,
                style: const TextStyle(color: _muted, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaseColumn extends StatelessWidget {
  const _CaseColumn({
    required this.status,
    required this.cases,
    required this.onTransition,
  });

  final TransactionCaseStatus status;
  final List<TransactionCase> cases;
  final Future<void> Function(TransactionCase, TransactionCaseStatus)
      onTransition;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${status.name.toUpperCase()} · ${cases.length}',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (cases.isEmpty)
            const Text('No cases', style: TextStyle(color: _muted))
          else
            for (final item in cases)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${item.teams.join(' / ')} · ${item.ownerName}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.ruleFindings.length} rule findings · ${item.priority.name}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<TransactionCaseStatus>(
                      onSelected: (value) => onTransition(item, value),
                      itemBuilder: (context) => [
                        for (final value in TransactionCaseStatus.values)
                          PopupMenuItem(
                            value: value,
                            child: Text('Move to ${value.name}'),
                          ),
                      ],
                      child: const Text(
                        'Change status',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w800,
                        ),
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

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.item,
    required this.organizationMode,
    required this.onDecision,
  });

  final TransactionCase item;
  final bool organizationMode;
  final Future<void> Function(
    TransactionCase,
    TransactionApprovalDecision,
  ) onDecision;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w900)),
                Text(
                  '${item.ownerName} · ${item.teams.join(' / ')} · ${item.ruleFindings.length} findings',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          if (organizationMode) ...[
            TextButton(
              onPressed: () => onDecision(
                item,
                TransactionApprovalDecision.changesRequested,
              ),
              child: const Text('Request changes'),
            ),
            FilledButton(
              onPressed: () => onDecision(
                item,
                TransactionApprovalDecision.approved,
              ),
              child: const Text('Approve'),
            ),
          ] else
            const Text('Waiting on organization review'),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.values});
  final String title;
  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final entry in values.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text('${entry.value}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.caption);
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: _ink, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(caption,
                style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
        ),
        child: child,
      );
}

InputDecoration _input(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _soft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
    );
