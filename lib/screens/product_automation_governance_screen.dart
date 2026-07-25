import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/automation_governance_service.dart';

class ProductAutomationGovernanceScreen extends StatefulWidget {
  const ProductAutomationGovernanceScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductAutomationGovernanceScreen> createState() =>
      _ProductAutomationGovernanceScreenState();
}

class _ProductAutomationGovernanceScreenState
    extends State<ProductAutomationGovernanceScreen> {
  final service = const AutomationGovernanceService();
  final alertName = TextEditingController();
  final alertThreshold = TextEditingController(text: '10');
  final reportTitle = TextEditingController();
  final inviteEmail = TextEditingController();
  String tab = 'Overview';
  String alertCategory = 'transaction';
  String reportType = 'transaction_pipeline';
  String reportSchedule = 'weekly';
  String inviteRole = 'analyst';
  bool loading = true;
  Map<String, dynamic> snapshot = {};
  List<Map<String, dynamic>> rules = [];
  List<Map<String, dynamic>> reports = [];
  List<Map<String, dynamic>> exports = [];
  List<Map<String, dynamic>> invites = [];
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> audit = [];

  bool get organizationMode => widget.session.role.canManageOrganization;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    alertName.dispose();
    alertThreshold.dispose();
    reportTitle.dispose();
    inviteEmail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final values = await Future.wait([
      service.snapshot(widget.session),
      service.alertRules(widget.session),
      service.scheduledReports(widget.session),
      service.exports(widget.session),
      service.invites(widget.session),
      service.deliveryJobs(widget.session),
      service.audit(widget.session),
    ]);
    if (!mounted) return;
    setState(() {
      snapshot = values[0] as Map<String, dynamic>;
      rules = values[1] as List<Map<String, dynamic>>;
      reports = values[2] as List<Map<String, dynamic>>;
      exports = values[3] as List<Map<String, dynamic>>;
      invites = values[4] as List<Map<String, dynamic>>;
      jobs = values[5] as List<Map<String, dynamic>>;
      audit = values[6] as List<Map<String, dynamic>>;
      loading = false;
    });
  }

  Future<void> _createAlert() async {
    final name = alertName.text.trim();
    if (name.isEmpty) return;
    final threshold = double.tryParse(alertThreshold.text.trim()) ?? 10;
    final ok = await service.saveAlertRule(
      session: widget.session,
      id: 'rule-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      category: alertCategory,
      condition: {'operator': 'gte', 'threshold': threshold},
    );
    if (!mounted) return;
    _message(ok ? 'Alert rule created.' : 'Alert rule could not be created.');
    if (ok) {
      alertName.clear();
      await _load();
    }
  }

  Future<void> _createReport() async {
    final title = reportTitle.text.trim();
    if (title.isEmpty) return;
    final ok = await service.saveScheduledReport(
      session: widget.session,
      id: 'report-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      reportType: reportType,
      schedule: reportSchedule,
    );
    if (!mounted) return;
    _message(ok ? 'Scheduled report created.' : 'Report could not be created.');
    if (ok) {
      reportTitle.clear();
      await _load();
    }
  }

  Future<void> _requestExport(String type) async {
    final ok = await service.requestExport(widget.session, type);
    if (!mounted) return;
    _message(ok ? 'Export queued.' : 'Export could not be queued.');
    if (ok) await _load();
  }

  Future<void> _invite() async {
    final email = inviteEmail.text.trim();
    if (email.isEmpty) return;
    final result = await service.createInvite(
      session: widget.session,
      email: email,
      role: inviteRole,
    );
    if (!mounted) return;
    if (result == null) {
      _message('Invite could not be created.');
      return;
    }
    inviteEmail.clear();
    final token = result['token']?.toString() ?? '';
    _message(token.isEmpty ? 'Invite created.' : 'Invite created. Token: $token');
    await _load();
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tabs = [
      'Overview',
      'Alerts',
      'Reports',
      'Exports',
      if (organizationMode) 'Invitations',
      'Delivery',
      if (organizationMode) 'Audit',
    ];
    if (!tabs.contains(tab)) tab = tabs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(organizationMode: organizationMode),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in tabs)
              ChoiceChip(
                label: Text(value),
                selected: tab == value,
                onSelected: (_) => setState(() => tab = value),
              ),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (tab == 'Overview') _overview()
        else if (tab == 'Alerts') _alerts()
        else if (tab == 'Reports') _reports()
        else if (tab == 'Exports') _exports()
        else if (tab == 'Invitations') _invitations()
        else if (tab == 'Audit') _audit()
        else _delivery(),
      ],
    );
  }

  Widget _overview() {
    final metrics = [
      ('Alert rules', snapshot['alert_rules']),
      ('Enabled alerts', snapshot['enabled_alert_rules']),
      ('Scheduled reports', snapshot['scheduled_reports']),
      ('Queued exports', snapshot['queued_exports']),
      if (organizationMode) ('Pending invites', snapshot['pending_invites']),
      ('Queued delivery jobs', snapshot['queued_delivery_jobs']),
    ];
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: 210,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric.$1,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text('${metric.$2 ?? 0}',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Launch automation boundary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text(
                'Rules, schedules, invitations, export requests, delivery queues and audit records are implemented in the Sports Terminal control plane. External email, webhook, storage and payment providers remain provider-neutral until credentials are configured.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alerts() {
    return _TwoColumn(
      left: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create alert rule',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: alertName,
              decoration: const InputDecoration(
                  labelText: 'Rule name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: alertCategory,
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'transaction', child: Text('Transaction')),
                DropdownMenuItem(value: 'salary_cap', child: Text('Salary cap')),
                DropdownMenuItem(value: 'player_stat', child: Text('Player statistic')),
                DropdownMenuItem(value: 'data_release', child: Text('Data release')),
                DropdownMenuItem(value: 'workflow', child: Text('Workflow')),
              ],
              onChanged: (value) => setState(() => alertCategory = value!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alertThreshold,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Threshold', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _createAlert,
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Create rule'),
            ),
          ],
        ),
      ),
      right: _ListCard(
        title: 'Active rules',
        empty: 'No alert rules yet.',
        rows: rules,
        titleKey: 'name',
        subtitle: (row) =>
            '${row['category']} · ${row['enabled'] == true ? 'enabled' : 'disabled'} · ${row['cooldown_minutes']} min cooldown',
      ),
    );
  }

  Widget _reports() {
    return _TwoColumn(
      left: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Schedule report',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: reportTitle,
              decoration: const InputDecoration(
                  labelText: 'Report title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: reportType,
              decoration: const InputDecoration(
                  labelText: 'Report type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'transaction_pipeline', child: Text('Transaction pipeline')),
                DropdownMenuItem(
                    value: 'cap_position', child: Text('Cap position')),
                DropdownMenuItem(
                    value: 'player_watchlist', child: Text('Player watchlist')),
                DropdownMenuItem(
                    value: 'organization_activity', child: Text('Organization activity')),
              ],
              onChanged: (value) => setState(() => reportType = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: reportSchedule,
              decoration: const InputDecoration(
                  labelText: 'Schedule', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
              ],
              onChanged: (value) => setState(() => reportSchedule = value!),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _createReport,
              icon: const Icon(Icons.schedule_send_rounded),
              label: const Text('Schedule report'),
            ),
          ],
        ),
      ),
      right: _ListCard(
        title: 'Scheduled reports',
        empty: 'No reports scheduled.',
        rows: reports,
        titleKey: 'title',
        subtitle: (row) =>
            '${row['report_type']} · ${row['schedule']} · ${row['enabled'] == true ? 'enabled' : 'disabled'}',
      ),
    );
  }

  Widget _exports() {
    final types = organizationMode
        ? ['transactions', 'workspace', 'audit', 'support', 'full']
        : ['account', 'workspace', 'transactions', 'support', 'full'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final type in types)
                FilledButton.tonalIcon(
                  onPressed: () => _requestExport(type),
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Export ${type.replaceAll('_', ' ')}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ListCard(
          title: 'Export queue',
          empty: 'No exports requested.',
          rows: exports,
          titleKey: 'export_type',
          subtitle: (row) =>
              '${row['format']} · ${row['status']} · ${row['requested_at'] ?? ''}',
        ),
      ],
    );
  }

  Widget _invitations() {
    return _TwoColumn(
      left: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invite organization member',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: inviteEmail,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: inviteRole,
              decoration: const InputDecoration(
                  labelText: 'Role', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                DropdownMenuItem(value: 'analyst', child: Text('Analyst')),
                DropdownMenuItem(value: 'reviewer', child: Text('Reviewer')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) => setState(() => inviteRole = value!),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _invite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create invite'),
            ),
          ],
        ),
      ),
      right: _ListCard(
        title: 'Organization invitations',
        empty: 'No invitations.',
        rows: invites,
        titleKey: 'email',
        subtitle: (row) => '${row['role']} · ${row['status']}',
      ),
    );
  }

  Widget _delivery() => _ListCard(
        title: 'Delivery queue',
        empty: 'No delivery jobs.',
        rows: jobs,
        titleKey: 'job_type',
        subtitle: (row) =>
            '${row['channel']} · ${row['status']} · ${row['attempts'] ?? 0} attempts',
      );

  Widget _audit() => _ListCard(
        title: 'Governance audit trail',
        empty: 'No governance events.',
        rows: audit,
        titleKey: 'action',
        subtitle: (row) =>
            '${row['target_type']} · ${row['target_id']} · ${row['created_at']}',
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.organizationMode});
  final bool organizationMode;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF071A33), Color(0xFF2563EB), Color(0xFFFF7A1A)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              organizationMode ? 'ORGANIZATION CONTROL PLANE' : 'MY AUTOMATION CENTER',
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              organizationMode
                  ? 'Govern access, automate reporting and operate delivery.'
                  : 'Automate monitoring, reporting and portable account data.',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.08,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'One connected control surface for alert rules, scheduled analysis, exports and delivery operations.',
              style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16),
            ),
          ],
        ),
      );
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(children: [left, const SizedBox(height: 16), right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        },
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: child,
      );
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.empty,
    required this.rows,
    required this.titleKey,
    required this.subtitle,
  });

  final String title;
  final String empty;
  final List<Map<String, dynamic>> rows;
  final String titleKey;
  final String Function(Map<String, dynamic>) subtitle;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(empty)
            else
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row[titleKey]?.toString() ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(subtitle(row)),
                ),
          ],
        ),
      );
}
