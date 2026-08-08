import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/customer_operations_service.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF5F7FB);

class ProductLaunchCenterScreen extends StatefulWidget {
  const ProductLaunchCenterScreen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  State<ProductLaunchCenterScreen> createState() =>
      _ProductLaunchCenterScreenState();
}

class _ProductLaunchCenterScreenState extends State<ProductLaunchCenterScreen> {
  final CustomerOperationsService service = const CustomerOperationsService();
  late Future<CustomerOperationsSnapshot> future;
  String tab = 'Overview';

  @override
  void initState() {
    super.initState();
    future = service.load(widget.session);
  }

  void _refresh() {
    setState(() {
      future = service.load(widget.session);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerOperationsSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _Surface(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final data = snapshot.data!;
        final tabs = [
          'Overview',
          'Onboarding',
          'Notifications',
          'Support',
          if (widget.organizationMode) 'Incidents',
          'Plan & Access',
        ];
        if (!tabs.contains(tab)) tab = tabs.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              organizationMode: widget.organizationMode,
              remoteAvailable: data.remoteAvailable,
              onRefresh: _refresh,
            ),
            const SizedBox(height: 18),
            _MetricGrid(
              items: [
                _Metric('Unread', '${data.unreadNotifications}', 'notifications'),
                _Metric('Support', '${data.openSupportCases}', 'open cases'),
                _Metric(
                  widget.organizationMode ? 'Seats' : 'Plan',
                  widget.organizationMode
                      ? '${data.activeMembers}/${data.seatLimit}'
                      : _text(data.entitlement['plan_id'], fallback: 'individual'),
                  widget.organizationMode ? 'active members' : _text(data.entitlement['status']),
                ),
                _Metric(
                  'Service',
                  data.remoteAvailable ? 'Connected' : 'Offline',
                  data.remoteAvailable ? 'shared backend' : 'cached snapshot',
                ),
              ],
            ),
            if (!data.remoteAvailable && data.error.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Notice(data.error),
            ],
            const SizedBox(height: 18),
            _Tabs(
              values: tabs,
              selected: tab,
              onSelected: (value) => setState(() => tab = value),
            ),
            const SizedBox(height: 18),
            if (tab == 'Overview')
              _Overview(data: data, organizationMode: widget.organizationMode)
            else if (tab == 'Onboarding')
              _Onboarding(
                data: data,
                organizationMode: widget.organizationMode,
                onSave: (steps) async {
                  final ok = await service.saveOnboarding(
                    session: widget.session,
                    completedSteps: steps,
                  );
                  if (mounted) {
                    _message(ok ? 'Onboarding progress saved.' : 'Unable to save onboarding progress.');
                    if (ok) _refresh();
                  }
                },
              )
            else if (tab == 'Notifications')
              _Notifications(
                data: data,
                onRead: (id) async {
                  final ok = await service.markNotificationRead(
                    session: widget.session,
                    notificationId: id,
                  );
                  if (ok) _refresh();
                },
                onReadAll: () async {
                  final ok = await service.markAllNotificationsRead(widget.session);
                  if (ok) _refresh();
                },
              )
            else if (tab == 'Support')
              _Support(
                data: data,
                onCreate: _createSupportCase,
                onComment: _addSupportComment,
              )
            else if (tab == 'Incidents')
              _Incidents(data: data, onCreate: _createIncident)
            else
              _PlanAccess(data: data, organizationMode: widget.organizationMode),
          ],
        );
      },
    );
  }

  Future<void> _createSupportCase() async {
    final result = await showDialog<_SupportDraft>(
      context: context,
      builder: (context) => const _SupportDialog(),
    );
    if (result == null) return;
    final created = await service.createSupportCase(
      session: widget.session,
      category: result.category,
      priority: result.priority,
      subject: result.subject,
      description: result.description,
      routeContext: 'Launch Center',
      diagnostics: {
        'role': widget.session.role.name,
        'organization_id': widget.session.organizationId,
      },
    );
    if (!mounted) return;
    _message(created == null ? 'Support request could not be created.' : 'Support request created.');
    if (created != null) _refresh();
  }

  Future<void> _addSupportComment(String caseId) async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add support reply'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Add context, reproduction steps, or a question.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty) return;
    final ok = await service.addSupportComment(
      session: widget.session,
      caseId: caseId,
      body: body,
    );
    if (!mounted) return;
    _message(ok ? 'Reply added.' : 'Reply could not be added.');
    if (ok) _refresh();
  }

  Future<void> _createIncident() async {
    final result = await showDialog<_IncidentDraft>(
      context: context,
      builder: (context) => const _IncidentDialog(),
    );
    if (result == null) return;
    final created = await service.createIncident(
      session: widget.session,
      title: result.title,
      summary: result.summary,
      severity: result.severity,
      affectedModules: result.modules,
    );
    if (!mounted) return;
    _message(created == null ? 'Incident could not be created.' : 'Incident opened.');
    if (created != null) _refresh();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.organizationMode,
    required this.remoteAvailable,
    required this.onRefresh,
  });

  final bool organizationMode;
  final bool remoteAvailable;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 18,
          children: [
            SizedBox(
              width: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organizationMode ? 'ORGANIZATION LAUNCH CENTER' : 'MY LAUNCH CENTER',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.3),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Operate the complete customer relationship.',
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.05),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    organizationMode
                        ? 'Onboard your team, govern access, monitor service health, manage support and keep the organization launch-ready.'
                        : 'Finish setup, understand your access, manage alerts and get help without leaving the terminal.',
                    style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Chip(
                  avatar: Icon(remoteAvailable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 17),
                  label: Text(remoteAvailable ? 'Connected' : 'Offline cache'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
              ],
            ),
          ],
        ),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data, required this.organizationMode});
  final CustomerOperationsSnapshot data;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) {
    final completed = _strings(data.onboarding['completed_steps']);
    final required = organizationMode ? _organizationSteps : _personalSteps;
    final remaining = required.where((item) => !completed.contains(item.$1)).toList();
    return _TwoColumn(
      left: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header('Next launch actions', 'The highest-value work remaining for this account.'),
            if (remaining.isEmpty)
              const _Success('Core onboarding is complete.')
            else
              for (final item in remaining.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.radio_button_unchecked_rounded, color: _blue),
                  title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(item.$3),
                ),
          ],
        ),
      ),
      right: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header('Operating pulse', 'Live customer, support and service indicators.'),
            _KeyValue('Plan', _text(data.entitlement['plan_id'])),
            _KeyValue('Status', _text(data.entitlement['status'])),
            _KeyValue('Unread notifications', '${data.unreadNotifications}'),
            _KeyValue('Open support cases', '${data.openSupportCases}'),
            if (organizationMode) _KeyValue('Active incidents', '${data.activeIncidents}'),
            if (organizationMode) _KeyValue('Seat utilization', '${data.activeMembers} of ${data.seatLimit}'),
          ],
        ),
      ),
    );
  }
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.data, required this.organizationMode, required this.onSave});
  final CustomerOperationsSnapshot data;
  final bool organizationMode;
  final Future<void> Function(Set<String>) onSave;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  late Set<String> completed;

  @override
  void initState() {
    super.initState();
    completed = _strings(widget.data.onboarding['completed_steps']).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.organizationMode ? _organizationSteps : _personalSteps;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Launch checklist', 'Progress is shared across devices and organization members where applicable.'),
          for (final step in steps)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: completed.contains(step.$1),
              title: Text(step.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(step.$3),
              onChanged: (value) => setState(() {
                value == true ? completed.add(step.$1) : completed.remove(step.$1);
              }),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => widget.onSave(completed),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save progress'),
          ),
        ],
      ),
    );
  }
}

class _Notifications extends StatelessWidget {
  const _Notifications({required this.data, required this.onRead, required this.onReadAll});
  final CustomerOperationsSnapshot data;
  final ValueChanged<String> onRead;
  final VoidCallback onReadAll;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _Header('Notification center', 'Data releases, cases, transactions, community and security alerts.')),
                TextButton.icon(onPressed: data.unreadNotifications == 0 ? null : onReadAll, icon: const Icon(Icons.done_all), label: const Text('Read all')),
              ],
            ),
            if (data.notifications.isEmpty)
              const _Empty('No notifications yet.')
            else
              for (final item in data.notifications)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_severityIcon(_text(item['severity'])), color: item['is_read'] == true ? _muted : _blue),
                  title: Text(_text(item['title']), style: TextStyle(fontWeight: item['is_read'] == true ? FontWeight.w600 : FontWeight.w900)),
                  subtitle: Text('${_text(item['body'])}\n${_text(item['created_at'])}'),
                  isThreeLine: true,
                  trailing: item['is_read'] == true
                      ? const Icon(Icons.done, color: _muted)
                      : IconButton(onPressed: () => onRead(_text(item['id'])), icon: const Icon(Icons.mark_email_read_outlined)),
                ),
          ],
        ),
      );
}

class _Support extends StatelessWidget {
  const _Support({required this.data, required this.onCreate, required this.onComment});
  final CustomerOperationsSnapshot data;
  final VoidCallback onCreate;
  final ValueChanged<String> onComment;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _Header('Support workspace', 'Persistent cases, diagnostics and threaded follow-up.')),
                FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('New request')),
              ],
            ),
            if (data.supportCases.isEmpty)
              const _Empty('No support cases have been opened.')
            else
              for (final item in data.supportCases)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(_text(item['subject']), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${_text(item['priority']).toUpperCase()} • ${_text(item['status'])} • ${_text(item['category'])}'),
                  children: [
                    Align(alignment: Alignment.centerLeft, child: Text(_text(item['description']))),
                    const SizedBox(height: 10),
                    for (final comment in _maps(item['comments']))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('${_text(comment['author_user_id'])}: ${_text(comment['body'])}'),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => onComment(_text(item['id'])),
                        icon: const Icon(Icons.reply),
                        label: const Text('Add reply'),
                      ),
                    ),
                  ],
                ),
          ],
        ),
      );
}

class _Incidents extends StatelessWidget {
  const _Incidents({required this.data, required this.onCreate});
  final CustomerOperationsSnapshot data;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _Header('Organization incidents', 'Track service degradation and customer-impacting operating events.')),
                FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.warning_amber_rounded), label: const Text('Open incident')),
              ],
            ),
            if (data.incidents.isEmpty)
              const _Success('No incidents are recorded.')
            else
              for (final item in data.incidents)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_severityIcon(_text(item['severity'])), color: _text(item['status']) == 'resolved' ? Colors.green : _orange),
                  title: Text(_text(item['title']), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${_text(item['summary'])}\n${_text(item['status'])} • ${_strings(item['affected_modules']).join(', ')}'),
                  isThreeLine: true,
                ),
          ],
        ),
      );
}

class _PlanAccess extends StatelessWidget {
  const _PlanAccess({required this.data, required this.organizationMode});
  final CustomerOperationsSnapshot data;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) {
    final features = _strings(data.entitlement['features']);
    final limits = data.entitlement['limits'] is Map
        ? (data.entitlement['limits'] as Map).map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    return _TwoColumn(
      left: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header('Plan status', 'The internal entitlement state is provider-neutral until billing is connected.'),
            _KeyValue('Plan', _text(data.entitlement['plan_id'])),
            _KeyValue('Status', _text(data.entitlement['status'])),
            _KeyValue('Seats', _text(data.entitlement['seats'])),
            _KeyValue('Trial ends', _text(data.entitlement['trial_ends_at'], fallback: 'Not scheduled')),
            _KeyValue('Renews', _text(data.entitlement['renews_at'], fallback: 'Provider not connected')),
            const SizedBox(height: 12),
            const _Notice('No payment is collected by this screen. Billing-provider activation remains an external launch dependency.'),
          ],
        ),
      ),
      right: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header('Access and limits', 'The backend remains the source of truth for plan enforcement.'),
            const Text('Features', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final feature in features) Chip(label: Text(feature.replaceAll('_', ' ')))]),
            const SizedBox(height: 16),
            const Text('Limits', style: TextStyle(fontWeight: FontWeight.w900)),
            for (final entry in limits.entries) _KeyValue(entry.key.replaceAll('_', ' '), '${entry.value}'),
          ],
        ),
      ),
    );
  }
}

class _SupportDialog extends StatefulWidget {
  const _SupportDialog();
  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  final subject = TextEditingController();
  final description = TextEditingController();
  String category = 'product';
  String priority = 'normal';

  @override
  void dispose() {
    subject.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create support request'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(value: category, items: const ['product', 'data', 'billing', 'account', 'security'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => category = value ?? category), decoration: const InputDecoration(labelText: 'Category'))),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(value: priority, items: const ['low', 'normal', 'high', 'urgent'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => priority = value ?? priority), decoration: const InputDecoration(labelText: 'Priority'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 12),
              TextField(controller: description, maxLines: 5, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: subject.text.trim().isEmpty || description.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _SupportDraft(category, priority, subject.text.trim(), description.text.trim())),
            child: const Text('Create'),
          ),
        ],
      );
}

class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog();
  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  final title = TextEditingController();
  final summary = TextEditingController();
  final modules = TextEditingController();
  String severity = 'minor';

  @override
  void dispose() {
    title.dispose();
    summary.dispose();
    modules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Open organization incident'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(value: severity, items: const ['minor', 'major', 'critical'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => severity = value ?? severity), decoration: const InputDecoration(labelText: 'Severity')),
              const SizedBox(height: 12),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextField(controller: summary, maxLines: 4, decoration: const InputDecoration(labelText: 'Summary')),
              const SizedBox(height: 12),
              TextField(controller: modules, decoration: const InputDecoration(labelText: 'Affected modules', hintText: 'Workspace, Trade Machine, API')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: title.text.trim().isEmpty || summary.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _IncidentDraft(title.text.trim(), summary.text.trim(), severity, modules.text.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList())),
            child: const Text('Open incident'),
          ),
        ],
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 760 ? constraints.maxWidth : (constraints.maxWidth - 36) / 4;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final item in items) SizedBox(width: width, child: _Surface(child: item))]);
      });
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(color: _muted, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .7)), const SizedBox(height: 8), Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 26)), const SizedBox(height: 4), Text(detail, style: const TextStyle(color: _muted))]);
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.values, required this.selected, required this.onSelected});
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => _Surface(child: Wrap(spacing: 8, runSpacing: 8, children: [for (final value in values) ChoiceChip(label: Text(value), selected: value == selected, onSelected: (_) => onSelected(value))]));
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 900) return Column(children: [left, const SizedBox(height: 16), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: left), const SizedBox(width: 16), Expanded(flex: 2, child: right)]);
      });
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)), child: child);
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted))]));
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))), Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w900))]));
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFD28A))), child: Text(text));
}

class _Success extends StatelessWidget {
  const _Success(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFA7F3D0))), child: Text(text));
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(text, style: const TextStyle(color: _muted))));
}

class _SupportDraft {
  const _SupportDraft(this.category, this.priority, this.subject, this.description);
  final String category;
  final String priority;
  final String subject;
  final String description;
}

class _IncidentDraft {
  const _IncidentDraft(this.title, this.summary, this.severity, this.modules);
  final String title;
  final String summary;
  final String severity;
  final List<String> modules;
}

const _personalSteps = <(String, String, String)>[
  ('profile', 'Complete your profile', 'Add the identity and preferences used across the terminal.'),
  ('favorites', 'Choose NBA favorites', 'Seed personalized dashboards, alerts and entity shortcuts.'),
  ('workspace', 'Create your first workbook', 'Route NBA data into a connected multi-sheet model.'),
  ('front_office', 'Run a front-office scenario', 'Build and save a contract, pick or trade workflow.'),
  ('notifications', 'Review notification settings', 'Choose which product, data and security events reach you.'),
  ('support', 'Know where to get help', 'Use persistent support cases instead of losing context in email.'),
];

const _organizationSteps = <(String, String, String)>[
  ('organization_profile', 'Confirm organization profile', 'Verify the organization identity and operating context.'),
  ('members', 'Invite and assign members', 'Set owner, admin, reviewer, analyst and viewer responsibilities.'),
  ('workspace_permissions', 'Configure shared Workspace access', 'Grant viewer, editor and owner permissions.'),
  ('transaction_workflow', 'Create the first shared transaction case', 'Confirm assignment, review and approval behavior.'),
  ('trust_safety', 'Assign Trust & Safety ownership', 'Ensure reports, sanctions and appeals have accountable operators.'),
  ('incident_response', 'Confirm incident ownership', 'Define who opens, updates and closes customer-impacting incidents.'),
  ('data_sources', 'Review source readiness', 'Confirm the 2025–26 release and financial catalogs are appropriately sourced.'),
  ('support_escalation', 'Configure support escalation', 'Document urgent routing and internal response expectations.'),
];

String _text(dynamic value, {String fallback = '—'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

List<String> _strings(dynamic value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) item.map((key, value) => MapEntry(key.toString(), value))];
}

IconData _severityIcon(String value) => switch (value) {
      'critical' => Icons.error_rounded,
      'warning' || 'major' => Icons.warning_amber_rounded,
      'success' || 'resolved' => Icons.check_circle_rounded,
      _ => Icons.info_rounded,
    };
