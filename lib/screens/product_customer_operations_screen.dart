import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/customer_ops_service.dart';

const _opsNavy = Color(0xFF071A33);
const _opsBlue = Color(0xFF2563EB);
const _opsOrange = Color(0xFFFF7A1A);
const _opsGreen = Color(0xFF059669);
const _opsRed = Color(0xFFDC2626);
const _opsInk = Color(0xFF102033);
const _opsMuted = Color(0xFF667085);
const _opsLine = Color(0xFFE3E8F0);
const _opsSoft = Color(0xFFF6F8FC);

class ProductCustomerOperationsScreen extends StatefulWidget {
  const ProductCustomerOperationsScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductCustomerOperationsScreen> createState() =>
      _ProductCustomerOperationsScreenState();
}

class _ProductCustomerOperationsScreenState
    extends State<ProductCustomerOperationsScreen> {
  final CustomerOpsService service = const CustomerOpsService();
  late Future<CustomerOpsSnapshot> snapshotFuture;
  String selectedTab = 'Launch Center';
  bool actionBusy = false;

  bool get organizationMode =>
      widget.session.role.canManageOrganization &&
      widget.session.organizationId.isNotEmpty;
  bool get platformMode => widget.session.role.canAccessPlatformAdmin;

  List<String> get tabs => [
        'Launch Center',
        'Plan & Access',
        'Onboarding',
        'Notifications',
        'Support',
        'Privacy & Data',
        if (organizationMode) 'Team & Seats',
        if (organizationMode) 'Reliability',
        if (organizationMode) 'Organization Audit',
        if (platformMode) 'Provider Operations',
      ];

  @override
  void initState() {
    super.initState();
    snapshotFuture = service.load(widget.session);
  }

  Future<void> _refresh() async {
    setState(() => snapshotFuture = service.load(widget.session));
    await snapshotFuture;
  }

  Future<void> _perform(
    Future<CustomerOpsResult> action, {
    required String successMessage,
  }) async {
    if (actionBusy) return;
    setState(() => actionBusy = true);
    final result = await action;
    if (!mounted) return;
    setState(() => actionBusy = false);
    _show(result.succeeded ? successMessage : result.error);
    if (result.succeeded) await _refresh();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.isEmpty ? 'Action completed.' : message)),
    );
  }

  Future<void> _choosePlan(
    CustomerOpsSnapshot snapshot,
    Map<String, dynamic> plan,
  ) async {
    final current = organizationMode
        ? snapshot.organizationSubscription
        : snapshot.subscription;
    var seats = _integer(current['seat_count'], fallback: organizationMode ? 10 : 1);
    var billingPeriod = current['billing_period']?.toString() ?? 'monthly';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select ${plan['name'] ?? plan['id']}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _planPrice(plan),
                  style: const TextStyle(
                    color: _opsNavy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sports Terminal records this selection and queues the provider event. No charge is attempted until a real payment provider is configured.',
                  style: TextStyle(color: _opsMuted, height: 1.45),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: billingPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Billing period',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'annual', child: Text('Annual')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => billingPeriod = value ?? 'monthly',
                  ),
                ),
                if (organizationMode) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Organization seats',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: seats <= 1
                            ? null
                            : () => setDialogState(() => seats--),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$seats',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => seats++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Record selection'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    await _perform(
      service.updateSubscription(
        session: widget.session,
        planId: plan['id']?.toString() ?? 'free',
        status: _providerConfigured(snapshot, 'billing') ? 'active' : 'pending_provider',
        seatCount: seats,
        billingPeriod: billingPeriod,
      ),
      successMessage: _providerConfigured(snapshot, 'billing')
          ? 'Subscription updated.'
          : 'Plan selection recorded and queued for payment-provider activation.',
    );
  }

  Future<void> _markOnboardingStep(
    CustomerOpsSnapshot snapshot,
    String step,
  ) async {
    final onboarding = organizationMode
        ? snapshot.organizationOnboarding
        : snapshot.onboarding;
    final completed = _strings(onboarding['completed_steps']).toSet();
    completed.add(step);
    final steps = organizationMode ? _organizationSteps : _personalSteps;
    final next = steps.firstWhere(
      (item) => !completed.contains(item.key),
      orElse: () => const _OnboardingStep('complete', 'Launch setup complete', ''),
    );
    await _perform(
      service.updateOnboarding(
        session: widget.session,
        completedSteps: completed.toList(),
        dismissedSteps: _strings(onboarding['dismissed_steps']),
        currentStep: next.key,
      ),
      successMessage: 'Onboarding progress updated.',
    );
  }

  Future<void> _createSupportTicket() async {
    final subject = TextEditingController();
    final body = TextEditingController();
    var category = 'general';
    var priority = 'normal';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create support request'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'general', child: Text('General')),
                            DropdownMenuItem(value: 'account', child: Text('Account')),
                            DropdownMenuItem(value: 'workspace', child: Text('Workspace')),
                            DropdownMenuItem(value: 'data', child: Text('NBA data')),
                            DropdownMenuItem(value: 'billing', child: Text('Billing')),
                            DropdownMenuItem(value: 'security', child: Text('Security')),
                          ],
                          onChanged: (value) => setDialogState(
                            () => category = value ?? 'general',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'high', child: Text('High')),
                            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                          ],
                          onChanged: (value) => setDialogState(
                            () => priority = value ?? 'normal',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: body,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create request'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || subject.text.trim().isEmpty || body.text.trim().isEmpty) {
      return;
    }
    await _perform(
      service.createSupportTicket(
        session: widget.session,
        category: category,
        priority: priority,
        subject: subject.text.trim(),
        body: body.text.trim(),
      ),
      successMessage: 'Support request created.',
    );
  }

  Future<void> _createPrivacyRequest() async {
    var type = 'export';
    final details = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Privacy and data request'),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Request type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'access', child: Text('Access my data')),
                    DropdownMenuItem(value: 'export', child: Text('Export my data')),
                    DropdownMenuItem(value: 'correction', child: Text('Correct my data')),
                    DropdownMenuItem(value: 'deletion', child: Text('Delete my account data')),
                    DropdownMenuItem(value: 'restriction', child: Text('Restrict processing')),
                    DropdownMenuItem(value: 'objection', child: Text('Object to processing')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'export'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await _perform(
      service.createPrivacyRequest(
        session: widget.session,
        requestType: type,
        details: details.text.trim(),
      ),
      successMessage: 'Privacy request submitted with a 30-day due date.',
    );
  }

  Future<void> _createInvitation() async {
    final email = TextEditingController();
    final message = TextEditingController();
    var role = 'analyst';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite organization member'),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                    DropdownMenuItem(value: 'analyst', child: Text('Analyst')),
                    DropdownMenuItem(value: 'reviewer', child: Text('Reviewer')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? 'analyst'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Optional message',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Queue invitation'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || email.text.trim().isEmpty) return;
    await _perform(
      service.createInvitation(
        session: widget.session,
        email: email.text.trim(),
        role: role,
        message: message.text.trim(),
      ),
      successMessage:
          'Invitation created and queued in the email-provider outbox.',
    );
  }

  Future<void> _createIncident() async {
    final title = TextEditingController();
    final summary = TextEditingController();
    var severity = 'sev3';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Open service incident'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'sev1', child: Text('SEV1 · Critical')),
                    DropdownMenuItem(value: 'sev2', child: Text('SEV2 · Major')),
                    DropdownMenuItem(value: 'sev3', child: Text('SEV3 · Degraded')),
                    DropdownMenuItem(value: 'sev4', child: Text('SEV4 · Minor')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => severity = value ?? 'sev3'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Incident title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summary,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Customer impact summary',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open incident'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || title.text.trim().isEmpty) return;
    await _perform(
      service.createIncident(
        session: widget.session,
        severity: severity,
        title: title.text.trim(),
        summary: summary.text.trim(),
        componentIds: const [],
      ),
      successMessage: 'Service incident opened.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerOpsSnapshot>(
      future: snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _OpsSurface(
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading customer launch operations...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _OpsSurface(
            child: Text('Launch Center unavailable: ${snapshot.error}'),
          );
        }
        final data = snapshot.data ?? CustomerOpsSnapshot.empty();
        if (!tabs.contains(selectedTab)) selectedTab = tabs.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OpsHero(
              organizationMode: organizationMode,
              organizationName: widget.session.organizationName,
              remoteAvailable: data.remoteAvailable,
              readinessStatus:
                  data.readiness['status']?.toString() ?? 'not checked',
              onRefresh: _refresh,
            ),
            const SizedBox(height: 18),
            _MetricGrid(
              items: [
                _Metric(
                  'Plan',
                  (organizationMode
                          ? data.organizationSubscription['plan_id']
                          : data.subscription['plan_id'])
                      ?.toString()
                      .toUpperCase() ??
                      'FREE',
                  (organizationMode
                          ? data.organizationSubscription['status']
                          : data.subscription['status'])
                      ?.toString() ??
                      'not activated',
                ),
                _Metric(
                  'Notifications',
                  '${data.unreadNotifications}',
                  'unread',
                ),
                _Metric(
                  'Support',
                  '${data.openSupportTickets}',
                  'open requests',
                ),
                _Metric(
                  organizationMode ? 'Seats' : 'Privacy',
                  organizationMode
                      ? '${data.organization['active_seats'] ?? 0}/${data.organization['seat_limit'] ?? 1}'
                      : '${data.openPrivacyRequests}',
                  organizationMode ? 'active / limit' : 'active requests',
                ),
                _Metric(
                  'Reliability',
                  data.activeIncidents == 0 ? 'Operational' : '${data.activeIncidents} active',
                  '${data.components.length} components',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _OpsTabs(
              tabs: tabs,
              selected: selectedTab,
              onSelected: (value) => setState(() => selectedTab = value),
            ),
            const SizedBox(height: 18),
            _selectedView(data),
          ],
        );
      },
    );
  }

  Widget _selectedView(CustomerOpsSnapshot snapshot) {
    return switch (selectedTab) {
      'Plan & Access' => _planView(snapshot),
      'Onboarding' => _onboardingView(snapshot),
      'Notifications' => _notificationsView(snapshot),
      'Support' => _supportView(snapshot),
      'Privacy & Data' => _privacyView(snapshot),
      'Team & Seats' => _teamView(snapshot),
      'Reliability' => _reliabilityView(snapshot),
      'Organization Audit' => _auditView(snapshot),
      'Provider Operations' => _providerView(snapshot),
      _ => _overview(snapshot),
    };
  }

  Widget _overview(CustomerOpsSnapshot snapshot) {
    final providerState = snapshot.providerState;
    final blockers = [
      ..._strings(snapshot.readiness['provider_blockers']),
      ..._strings(snapshot.readiness['infrastructure_blockers']),
    ];
    final onboarding = organizationMode
        ? snapshot.organizationOnboarding
        : snapshot.onboarding;
    final completed = _strings(onboarding['completed_steps']);
    final steps = organizationMode ? _organizationSteps : _personalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TwoColumn(
          left: _OpsSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  'Launch readiness',
                  'Internal product workflows and external activation are tracked separately.',
                ),
                const SizedBox(height: 14),
                _StatusBanner(
                  status: snapshot.readiness['status']?.toString() ?? 'offline',
                  message: blockers.isEmpty
                      ? 'No provider or infrastructure blockers were reported.'
                      : '${blockers.length} external activation items remain. The internal workflows are available now.',
                ),
                const SizedBox(height: 14),
                for (final entry in providerState.entries)
                  _KeyValueRow(
                    _label(entry.key),
                    entry.value is Map
                        ? (_map(entry.value)['configured'] == true
                            ? 'Configured'
                            : _map(entry.value)['mode']?.toString() ?? 'Not configured')
                        : entry.value == true
                            ? 'Configured'
                            : 'Not configured',
                  ),
              ],
            ),
          ),
          right: _OpsSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  'Setup progress',
                  'Complete the remaining account-specific steps.',
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: steps.isEmpty ? 1 : completed.length / steps.length,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                Text(
                  '${completed.length} of ${steps.length} launch steps completed',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                for (final step in steps.take(6))
                  _ChecklistRow(
                    label: step.title,
                    complete: completed.contains(step.key),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _OpsSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                'Operating snapshot',
                'Customer workflows, service state and queued external actions.',
              ),
              const SizedBox(height: 14),
              _MetricGrid(
                items: [
                  _Metric(
                    'Queued provider events',
                    '${snapshot.readiness['record_counts'] is Map ? _map(snapshot.readiness['record_counts'])['pending_provider_events'] ?? 0 : 0}',
                    'auditable delivery queue',
                  ),
                  _Metric(
                    'Active incidents',
                    '${snapshot.activeIncidents}',
                    'service operations',
                  ),
                  _Metric(
                    'Pending invitations',
                    '${snapshot.invitations.where((item) => item['status'] == 'pending').length}',
                    organizationMode ? 'organization seats' : 'not applicable',
                  ),
                  _Metric(
                    'Last loaded',
                    _shortTimestamp(snapshot.loadedAtIso),
                    snapshot.remoteAvailable ? 'shared backend' : 'local cache',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planView(CustomerOpsSnapshot snapshot) {
    final current = organizationMode
        ? snapshot.organizationSubscription
        : snapshot.subscription;
    final currentPlan = current['plan_id']?.toString() ?? 'free';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpsSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                'Plan and feature access',
                'Plan selection is connected to the entitlement engine. Provider activation remains queued until billing credentials exist.',
              ),
              const SizedBox(height: 14),
              _StatusBanner(
                status: _providerConfigured(snapshot, 'billing')
                    ? 'provider configured'
                    : 'outbox only',
                message: _providerConfigured(snapshot, 'billing')
                    ? 'Billing-provider configuration is present.'
                    : 'Selections are recorded and versioned, but no payment is attempted.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 840
                ? constraints.maxWidth
                : (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final plan in snapshot.plans)
                  SizedBox(
                    width: width,
                    child: _PlanCard(
                      plan: plan,
                      active: currentPlan == plan['id'],
                      onSelect: () => _choosePlan(snapshot, plan),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _onboardingView(CustomerOpsSnapshot snapshot) {
    final onboarding = organizationMode
        ? snapshot.organizationOnboarding
        : snapshot.onboarding;
    final completed = _strings(onboarding['completed_steps']).toSet();
    final steps = organizationMode ? _organizationSteps : _personalSteps;
    return _OpsSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            'Launch onboarding',
            'Progress is persisted for the active personal or organization scope.',
          ),
          for (var index = 0; index < steps.length; index++)
            _OnboardingRow(
              number: index + 1,
              step: steps[index],
              complete: completed.contains(steps[index].key),
              busy: actionBusy,
              onComplete: () => _markOnboardingStep(snapshot, steps[index].key),
            ),
        ],
      ),
    );
  }

  Widget _notificationsView(CustomerOpsSnapshot snapshot) {
    return _OpsSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            'Notification center',
            'In-app notifications are immediate. Email, SMS and webhook delivery use the auditable provider outbox.',
          ),
          if (snapshot.notifications.isEmpty)
            const _EmptyState('No notifications yet.')
          else
            for (final item in snapshot.notifications)
              _NotificationRow(
                item: item,
                onRead: () => _perform(
                  service.notificationAction(
                    session: widget.session,
                    notificationId: item['id']?.toString() ?? '',
                    action: item['status'] == 'read' ? 'unread' : 'read',
                  ),
                  successMessage: 'Notification updated.',
                ),
                onArchive: () => _perform(
                  service.notificationAction(
                    session: widget.session,
                    notificationId: item['id']?.toString() ?? '',
                    action: 'archive',
                  ),
                  successMessage: 'Notification archived.',
                ),
              ),
        ],
      ),
    );
  }

  Widget _supportView(CustomerOpsSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: actionBusy ? null : _createSupportTicket,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New support request'),
          ),
        ),
        const SizedBox(height: 12),
        _OpsSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                'Support requests',
                'Tickets retain customer-visible event history, ownership and resolution state.',
              ),
              if (snapshot.supportTickets.isEmpty)
                const _EmptyState('No support requests in this scope.')
              else
                for (final item in snapshot.supportTickets)
                  _TicketRow(item: item),
            ],
          ),
        ),
      ],
    );
  }

  Widget _privacyView(CustomerOpsSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpsSurface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy and account data',
                      style: TextStyle(
                        color: _opsInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create access, export, correction, deletion, restriction or objection requests. Every request receives a due date and immutable event history.',
                      style: TextStyle(color: _opsMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: actionBusy ? null : _createPrivacyRequest,
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Create request'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _OpsSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                'Request history',
                'Open and completed requests remain visible for compliance evidence.',
              ),
              if (snapshot.privacyRequests.isEmpty)
                const _EmptyState('No privacy or data requests yet.')
              else
                for (final item in snapshot.privacyRequests)
                  _PrivacyRow(item: item),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamView(CustomerOpsSnapshot snapshot) {
    final members = _list(snapshot.organization['members']);
    final seatLimit = _integer(snapshot.organization['seat_limit'], fallback: 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricGrid(
          items: [
            _Metric('Active seats', '${members.length}', 'of $seatLimit'),
            _Metric(
              'Available seats',
              '${(seatLimit - members.length).clamp(0, seatLimit)}',
              'current plan',
            ),
            _Metric(
              'Pending invitations',
              '${snapshot.invitations.where((item) => item['status'] == 'pending').length}',
              '7-day expiration',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TwoColumn(
          left: _OpsSurface(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  'Organization members',
                  'Active seat assignment and role visibility.',
                ),
                if (members.isEmpty)
                  const _EmptyState('No organization members returned.')
                else
                  for (final member in members)
                    _MemberRow(member: member),
              ],
            ),
          ),
          right: _OpsSurface(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  'Invitations',
                  'Invitation delivery is queued until email-provider credentials are configured.',
                  action: FilledButton.icon(
                    onPressed: actionBusy ? null : _createInvitation,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Invite'),
                  ),
                ),
                if (snapshot.invitations.isEmpty)
                  const _EmptyState('No invitations created yet.')
                else
                  for (final invitation in snapshot.invitations)
                    _InvitationRow(item: invitation),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _reliabilityView(CustomerOpsSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (platformMode)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: actionBusy ? null : _createIncident,
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Open incident'),
            ),
          ),
        if (platformMode) const SizedBox(height: 12),
        _OpsSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                'Service components',
                'Current operating state for customer-facing platform services.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final component in snapshot.components)
                    _ComponentCard(item: component),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _OpsSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                'Incident history',
                'Investigations, customer impact and chronological updates.',
              ),
              if (snapshot.incidents.isEmpty)
                const _EmptyState('No service incidents have been recorded.')
              else
                for (final incident in snapshot.incidents)
                  _IncidentRow(item: incident),
            ],
          ),
        ),
      ],
    );
  }

  Widget _auditView(CustomerOpsSnapshot snapshot) {
    return _OpsSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            'Organization operating audit',
            'Immutable customer-operations events for subscription, onboarding, invitations, support and privacy workflows.',
          ),
          if (snapshot.auditEvents.isEmpty)
            const _EmptyState('No organization audit events yet.')
          else
            for (final event in snapshot.auditEvents)
              _AuditRow(item: event),
        ],
      ),
    );
  }

  Widget _providerView(CustomerOpsSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpsSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                'External provider operations',
                'Outbox events are durable and idempotent. Delivery status changes only through an adapter or explicit operator action.',
              ),
              const SizedBox(height: 12),
              _StatusBanner(
                status: 'operator only',
                message:
                    '${snapshot.providerOutbox.length} provider events · ${snapshot.backups.length} backup records · ${snapshot.retentionPolicies.length} retention policies',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _OpsSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                'Provider outbox',
                'Billing, email, SMS and webhook events waiting for or returned by provider adapters.',
              ),
              if (snapshot.providerOutbox.isEmpty)
                const _EmptyState('No provider events queued.')
              else
                for (final item in snapshot.providerOutbox.take(100))
                  _OutboxRow(
                    item: item,
                    onRetry: () => _perform(
                      service.providerOutboxAction(
                        session: widget.session,
                        eventId: item['id']?.toString() ?? '',
                        action: 'retry',
                      ),
                      successMessage: 'Provider event returned to the pending queue.',
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _TwoColumn(
          left: _OpsSurface(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  'Backup evidence',
                  'Recorded backup and restore-test evidence.',
                ),
                if (snapshot.backups.isEmpty)
                  const _EmptyState('No backup evidence recorded.')
                else
                  for (final item in snapshot.backups)
                    _BackupRow(item: item),
              ],
            ),
          ),
          right: _OpsSurface(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  'Retention policies',
                  'Configured lifecycle for operational and customer records.',
                ),
                if (snapshot.retentionPolicies.isEmpty)
                  const _EmptyState('No retention policies returned.')
                else
                  for (final item in snapshot.retentionPolicies)
                    _RetentionRow(item: item),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpsHero extends StatelessWidget {
  const _OpsHero({
    required this.organizationMode,
    required this.organizationName,
    required this.remoteAvailable,
    required this.readinessStatus,
    required this.onRefresh,
  });

  final bool organizationMode;
  final String organizationName;
  final bool remoteAvailable;
  final String readinessStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [_opsNavy, _opsBlue, _opsOrange],
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
                Expanded(
                  child: Text(
                    organizationMode
                        ? 'ORGANIZATION LAUNCH OPERATIONS'
                        : 'CUSTOMER LAUNCH CENTER',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                _StatusPill(
                  remoteAvailable ? 'SHARED' : 'LOCAL CACHE',
                  remoteAvailable ? _opsGreen : _opsOrange,
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onRefresh,
                  tooltip: 'Refresh launch operations',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              organizationMode
                  ? 'Operate ${organizationName.isEmpty ? 'your organization' : organizationName} from one connected surface.'
                  : 'Set up, operate and control your Sports Terminal account.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                height: 1.07,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 980,
              child: Text(
                'Plan access, onboarding, notifications, support, privacy, seats, provider queues and service reliability are connected to durable workflows. External vendors remain explicitly separated until real credentials are configured.',
                style: TextStyle(
                  color: Color(0xFFEAF2FF),
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _StatusPill(readinessStatus.toUpperCase(), Colors.white24),
          ],
        ),
      );
}

class _OpsTabs extends StatelessWidget {
  const _OpsTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => _OpsSurface(
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final tab in tabs)
              ChoiceChip(
                label: Text(tab),
                selected: tab == selected,
                selectedColor: _opsNavy,
                labelStyle: TextStyle(
                  color: tab == selected ? Colors.white : _opsInk,
                  fontWeight: FontWeight.w900,
                ),
                onSelected: (_) => onSelected(tab),
              ),
          ],
        ),
      );
}

class _OpsSurface extends StatelessWidget {
  const _OpsSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _opsLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D071A33),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _opsInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: _opsMuted, height: 1.4),
          ),
        ],
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle, {this.action});
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _SectionTitle(title, subtitle)),
            if (action != null) ...[
              const SizedBox(width: 12),
              action!,
            ],
          ],
        ),
      );
}

class _Metric {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 620
              ? 1
              : constraints.maxWidth < 980
                  ? 2
                  : items.length.clamp(3, 5);
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _OpsSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label.toUpperCase(),
                          style: const TextStyle(
                            color: _opsMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _opsNavy,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.detail,
                          style: const TextStyle(color: _opsMuted, fontSize: 12),
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

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              children: [left, const SizedBox(height: 14), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              Expanded(child: right),
            ],
          );
        },
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.message});
  final String status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final good = {'operational', 'launch_candidate', 'provider configured'}
        .contains(status.toLowerCase());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFECFDF5) : const Color(0xFFFFF7E8),
        border: Border.all(
          color: good ? const Color(0xFF86EFAC) : const Color(0xFFFFD28A),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            good ? Icons.check_circle_rounded : Icons.info_rounded,
            color: good ? _opsGreen : _opsOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: good ? _opsGreen : _opsOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: _opsInk, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.active,
    required this.onSelect,
  });
  final Map<String, dynamic> plan;
  final bool active;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final entitlements = _list(plan['entitlements']);
    return _OpsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan['name']?.toString() ?? 'Plan',
                  style: const TextStyle(
                    color: _opsInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (active) const _SmallBadge('CURRENT', _opsGreen),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _planPrice(plan),
            style: const TextStyle(
              color: _opsNavy,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (final entitlement in entitlements.take(9))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, size: 17, color: _opsGreen),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${_label(entitlement['entitlement_key']?.toString() ?? '')}${entitlement['limit_value'] == null ? '' : ' · ${entitlement['limit_value']}'}',
                      style: const TextStyle(color: _opsMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: active
                ? OutlinedButton(onPressed: onSelect, child: const Text('Review plan'))
                : FilledButton(onPressed: onSelect, child: const Text('Select plan')),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep(this.key, this.title, this.description);
  final String key;
  final String title;
  final String description;
}

const _personalSteps = [
  _OnboardingStep('profile', 'Complete your profile', 'Confirm identity, display name and public-profile settings.'),
  _OnboardingStep('favorites', 'Choose favorite teams', 'Personalize NBA navigation and alerts.'),
  _OnboardingStep('watchlist', 'Build a player watchlist', 'Save the players you follow most closely.'),
  _OnboardingStep('workspace', 'Open your first workbook', 'Create or import a routed sports dataset.'),
  _OnboardingStep('route_data', 'Route NBA data', 'Send a structured package to Workspace or Python Lab.'),
  _OnboardingStep('notifications', 'Review notifications', 'Choose delivery and digest preferences.'),
  _OnboardingStep('support', 'Know where to get help', 'Open the connected support surface.'),
];

const _organizationSteps = [
  _OnboardingStep('organization_profile', 'Confirm organization profile', 'Review organization identity and operating scope.'),
  _OnboardingStep('billing', 'Select organization plan', 'Record plan and seat requirements.'),
  _OnboardingStep('invite_team', 'Invite the team', 'Assign analyst, reviewer and administrator roles.'),
  _OnboardingStep('workspace', 'Create a shared workbook', 'Establish a versioned organization modeling surface.'),
  _OnboardingStep('approval_flow', 'Run an approval workflow', 'Create, assign and approve a transaction case.'),
  _OnboardingStep('security', 'Review security controls', 'Confirm membership, audit and privacy workflows.'),
  _OnboardingStep('reliability', 'Review service health', 'Know where incidents and provider states appear.'),
];

class _OnboardingRow extends StatelessWidget {
  const _OnboardingRow({
    required this.number,
    required this.step,
    required this.complete,
    required this.busy,
    required this.onComplete,
  });
  final int number;
  final _OnboardingStep step;
  final bool complete;
  final bool busy;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _opsLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: complete ? _opsGreen : _opsSoft,
              foregroundColor: complete ? Colors.white : _opsNavy,
              child: complete
                  ? const Icon(Icons.check_rounded, size: 19)
                  : Text('$number', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      color: _opsInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.description,
                    style: const TextStyle(color: _opsMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (complete)
              const _SmallBadge('COMPLETE', _opsGreen)
            else
              OutlinedButton(
                onPressed: busy ? null : onComplete,
                child: const Text('Mark complete'),
              ),
          ],
        ),
      );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.onRead,
    required this.onArchive,
  });
  final Map<String, dynamic> item;
  final VoidCallback onRead;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: Icon(
          item['status'] == 'unread'
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: item['status'] == 'unread' ? _opsOrange : _opsMuted,
        ),
        title: item['title']?.toString() ?? 'Notification',
        subtitle:
            '${item['body'] ?? ''}\n${_label(item['kind']?.toString() ?? '')} · ${_label(item['channel']?.toString() ?? '')} · ${_shortTimestamp(item['created_at']?.toString() ?? '')}',
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'archive' ? onArchive() : onRead(),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'read',
              child: Text(item['status'] == 'read' ? 'Mark unread' : 'Mark read'),
            ),
            const PopupMenuItem(value: 'archive', child: Text('Archive')),
          ],
        ),
      );
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: const Icon(Icons.support_agent_rounded, color: _opsBlue),
        title: item['subject']?.toString() ?? 'Support request',
        subtitle:
            '${item['body'] ?? ''}\n${_label(item['category']?.toString() ?? '')} · ${_label(item['priority']?.toString() ?? '')} priority · ${_shortTimestamp(item['updated_at']?.toString() ?? '')}',
        trailing: _SmallBadge(
          (item['status']?.toString() ?? 'open').toUpperCase(),
          _statusColor(item['status']?.toString() ?? ''),
        ),
      );
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: const Icon(Icons.privacy_tip_outlined, color: _opsNavy),
        title: _label(item['request_type']?.toString() ?? 'request'),
        subtitle:
            '${item['details'] ?? 'No additional details'}\nDue ${_shortTimestamp(item['due_at']?.toString() ?? '')} · verification ${_label(item['verification_status']?.toString() ?? '')}',
        trailing: _SmallBadge(
          (item['status']?.toString() ?? 'requested').toUpperCase(),
          _statusColor(item['status']?.toString() ?? ''),
        ),
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});
  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: CircleAvatar(
          backgroundColor: _opsSoft,
          foregroundColor: _opsNavy,
          child: Text(
            _initials(member['display_name']?.toString() ?? member['user_id']?.toString() ?? 'U'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: member['display_name']?.toString() ?? member['user_id']?.toString() ?? 'Member',
        subtitle: '${member['email'] ?? ''}\n${_label(member['role']?.toString() ?? 'analyst')}',
        trailing: _SmallBadge(
          (member['status']?.toString() ?? 'active').toUpperCase(),
          _statusColor(member['status']?.toString() ?? 'active'),
        ),
      );
}

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: const Icon(Icons.outgoing_mail, color: _opsOrange),
        title: item['email']?.toString() ?? 'Invitation',
        subtitle:
            '${_label(item['role']?.toString() ?? 'analyst')} · expires ${_shortTimestamp(item['expires_at']?.toString() ?? '')}',
        trailing: _SmallBadge(
          (item['status']?.toString() ?? 'pending').toUpperCase(),
          _statusColor(item['status']?.toString() ?? ''),
        ),
      );
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _opsSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _opsLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item['status'] == 'operational'
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: _statusColor(item['status']?.toString() ?? ''),
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item['name']?.toString() ?? item['id']?.toString() ?? 'Service',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              _label(item['status']?.toString() ?? ''),
              style: TextStyle(
                color: _statusColor(item['status']?.toString() ?? ''),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item['public_message']?.toString().isNotEmpty == true
                  ? item['public_message'].toString()
                  : item['description']?.toString() ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _opsMuted, fontSize: 12, height: 1.35),
            ),
          ],
        ),
      );
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: _statusColor(item['status']?.toString() ?? ''),
        ),
        title: item['title']?.toString() ?? 'Service incident',
        subtitle:
            '${item['summary'] ?? ''}\n${(item['severity'] ?? 'sev3').toString().toUpperCase()} · ${_shortTimestamp(item['started_at']?.toString() ?? '')} · ${_list(item['updates']).length} updates',
        trailing: _SmallBadge(
          (item['status']?.toString() ?? 'investigating').toUpperCase(),
          _statusColor(item['status']?.toString() ?? ''),
        ),
      );
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: const Icon(Icons.history_rounded, color: _opsBlue),
        title: _label(item['action']?.toString() ?? 'event'),
        subtitle:
            '${_label(item['target_type']?.toString() ?? '')} · ${item['target_id'] ?? ''}\nActor ${item['actor_user_id'] ?? 'system'} · ${_shortTimestamp(item['created_at']?.toString() ?? '')}',
      );
}

class _OutboxRow extends StatelessWidget {
  const _OutboxRow({required this.item, required this.onRetry});
  final Map<String, dynamic> item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: const Icon(Icons.outbox_rounded, color: _opsBlue),
        title: _label(item['event_type']?.toString() ?? 'provider event'),
        subtitle:
            '${_label(item['provider_type']?.toString() ?? '')} · ${item['destination'] ?? ''}\nAttempts ${item['attempt_count'] ?? 0} · ${item['last_error'] ?? ''}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmallBadge(
              (item['status']?.toString() ?? 'pending').toUpperCase(),
              _statusColor(item['status']?.toString() ?? ''),
            ),
            if (item['status'] == 'failed') ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Retry provider event',
                onPressed: onRetry,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ],
        ),
      );
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: const Icon(Icons.backup_rounded, color: _opsNavy),
        title: _label(item['backup_type']?.toString() ?? 'backup'),
        subtitle:
            '${item['location'] ?? 'No location recorded'}\n${item['size_bytes'] ?? 0} bytes · ${_shortTimestamp(item['started_at']?.toString() ?? '')}',
        trailing: _SmallBadge(
          item['restore_tested'] == true ? 'RESTORE TESTED' : 'NOT TESTED',
          item['restore_tested'] == true ? _opsGreen : _opsOrange,
        ),
      );
}

class _RetentionRow extends StatelessWidget {
  const _RetentionRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _ListRow(
        leading: const Icon(Icons.schedule_rounded, color: _opsBlue),
        title: _label(item['key']?.toString() ?? 'policy'),
        subtitle:
            '${item['retention_days'] ?? 0} days · ${_label(item['action']?.toString() ?? '')}\n${item['legal_basis'] ?? ''}',
        trailing: _SmallBadge(
          item['enabled'] == true ? 'ENABLED' : 'DISABLED',
          item['enabled'] == true ? _opsGreen : _opsMuted,
        ),
      );
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _opsLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 40, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _opsInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _opsMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      );
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .4,
          ),
        ),
      );
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.complete});
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              complete ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: complete ? _opsGreen : _opsMuted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: complete ? _opsInk : _opsMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 155,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(color: _opsMuted)),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Text(message, style: const TextStyle(color: _opsMuted)),
      );
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

int _integer(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _planPrice(Map<String, dynamic> plan) {
  final cents = _integer(plan['price_cents']);
  if (cents == 0) return r'$0';
  return '\$${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)} / month';
}

bool _providerConfigured(CustomerOpsSnapshot snapshot, String provider) {
  final value = snapshot.providerState[provider];
  return value is Map && value['configured'] == true;
}

String _shortTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.isEmpty ? 'not recorded' : value;
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'U';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

Color _statusColor(String status) {
  final normalized = status.toLowerCase();
  if ({
    'active',
    'accepted',
    'completed',
    'delivered',
    'enabled',
    'operational',
    'resolved',
    'verified',
  }.contains(normalized)) {
    return _opsGreen;
  }
  if ({
    'failed',
    'major_outage',
    'rejected',
    'revoked',
    'sev1',
  }.contains(normalized)) {
    return _opsRed;
  }
  if ({
    'pending',
    'pending_provider',
    'trialing',
    'investigating',
    'degraded',
    'partial_outage',
    'requested',
  }.contains(normalized)) {
    return _opsOrange;
  }
  return _opsBlue;
}
