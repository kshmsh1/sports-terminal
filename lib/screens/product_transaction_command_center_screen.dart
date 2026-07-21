import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/transaction_case.dart';
import '../models/transaction_workflow.dart';
import '../services/transaction_case_convergence_service.dart';
import '../services/transaction_case_repository.dart';
import '../services/transaction_workflow_repository.dart';
import 'product_role_operations_screen.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF5F7FB);

class ProductTransactionCommandCenterScreen extends StatefulWidget {
  const ProductTransactionCommandCenterScreen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  State<ProductTransactionCommandCenterScreen> createState() =>
      _ProductTransactionCommandCenterScreenState();
}

class _ProductTransactionCommandCenterScreenState
    extends State<ProductTransactionCommandCenterScreen> {
  final caseRepository = const TransactionCaseRepository();
  final workflowRepository = const TransactionWorkflowRepository();
  final convergence = const TransactionCaseConvergenceService();
  final commentController = TextEditingController();
  final assigneeController = TextEditingController();
  final memberIdController = TextEditingController();
  final memberNameController = TextEditingController();
  final memberFocusController = TextEditingController(text: 'League-wide');

  String selectedTab = 'Cases';
  String selectedCaseId = '';
  String memberRole = 'Analyst';
  bool loading = true;
  bool mutating = false;
  List<TransactionCase> cases = [];
  List<TransactionImportCandidate> candidates = [];
  List<TransactionActivity> activities = [];
  List<TransactionNotification> notifications = [];
  List<OrganizationMemberRecord> members = [];

  List<String> get tabs => [
        'Cases',
        'Imports',
        'Collaboration',
        'Activity',
        'Notifications',
        if (widget.organizationMode) 'Members',
      ];

  TransactionCase? get selectedCase {
    if (cases.isEmpty) return null;
    return cases.firstWhere(
      (item) => item.id == selectedCaseId,
      orElse: () => cases.first,
    );
  }

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    commentController.dispose();
    assigneeController.dispose();
    memberIdController.dispose();
    memberNameController.dispose();
    memberFocusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loadedCases = widget.organizationMode
        ? await caseRepository.loadOrganization(widget.session.organizationId)
        : await caseRepository.loadPersonal(widget.session.userId);
    final loadedCandidates = await convergence.discover();
    final loadedActivities = await workflowRepository.loadActivities(
      widget.session.organizationId,
    );
    final loadedNotifications = await workflowRepository.loadNotifications(
      widget.session.userId,
    );
    var loadedMembers = await workflowRepository.loadMembers(
      widget.session.organizationId,
    );
    if (widget.organizationMode &&
        !loadedMembers.any((item) => item.userId == widget.session.userId)) {
      final self = OrganizationMemberRecord(
        userId: widget.session.userId,
        displayName: widget.session.displayName,
        roleLabel: widget.session.role.label,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        teamFocus: 'Organization-wide',
        reviewCapacity: 12,
      );
      await workflowRepository.upsertMember(widget.session.organizationId, self);
      loadedMembers = [self, ...loadedMembers];
    }
    if (!mounted) return;
    setState(() {
      cases = loadedCases;
      candidates = loadedCandidates;
      activities = loadedActivities;
      notifications = loadedNotifications;
      members = loadedMembers;
      if (cases.isNotEmpty && !cases.any((item) => item.id == selectedCaseId)) {
        selectedCaseId = cases.first.id;
      }
      loading = false;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (mutating) return;
    setState(() => mutating = true);
    try {
      await action();
      await _load();
    } catch (error) {
      _show('The workflow update could not be completed: $error');
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  Future<void> _importCandidate(
    TransactionImportCandidate candidate, {
    required bool organizationVisible,
  }) {
    return _run(() async {
      final item = await convergence.importCandidate(
        candidate: candidate,
        session: widget.session,
        organizationVisible: organizationVisible,
      );
      selectedCaseId = item.id;
      selectedTab = 'Collaboration';
      _show('Imported “${item.title}”.');
    });
  }

  Future<void> _publish(TransactionCase item) {
    return _run(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final updated = item.copyWith(
        status: TransactionCaseStatus.review,
        isOrganizationVisible: true,
        approvals: [
          TransactionApproval(
            approverId: 'organization-review',
            approverName: '${item.organizationName} review queue',
            decision: TransactionApprovalDecision.pending,
            updatedAtIso: now,
          ),
        ],
        updatedAtIso: now,
      );
      await caseRepository.publishToOrganization(updated);
      await workflowRepository.addActivity(TransactionActivity(
        id: 'activity_${DateTime.now().microsecondsSinceEpoch}',
        caseId: item.id,
        organizationId: item.organizationId,
        actorUserId: widget.session.userId,
        actorName: widget.session.displayName,
        kind: TransactionActivityKind.status,
        message: 'Submitted “${item.title}” to the organization review queue.',
        createdAtIso: now,
        recipientUserId: item.ownerUserId,
      ));
      await workflowRepository.addNotification(TransactionNotification(
        id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
        caseId: item.id,
        organizationId: item.organizationId,
        recipientUserId: item.ownerUserId,
        title: 'Case submitted',
        body: '${item.title} is awaiting organization review.',
        createdAtIso: now,
      ));
      _show('Submitted to ${item.organizationName}.');
    });
  }

  Future<void> _addComment(TransactionCase item) {
    final body = commentController.text.trim();
    if (body.isEmpty) {
      _show('Enter a comment first.');
      return Future.value();
    }
    return _run(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final updated = item.copyWith(
        comments: [
          ...item.comments,
          TransactionCaseComment(
            authorId: widget.session.userId,
            authorName: widget.session.displayName,
            body: body,
            createdAtIso: now,
          ),
        ],
        updatedAtIso: now,
      );
      await caseRepository.upsertPersonal(item.ownerUserId, updated);
      if (updated.isOrganizationVisible) {
        await caseRepository.upsertOrganization(item.organizationId, updated);
      }
      await workflowRepository.addActivity(TransactionActivity(
        id: 'activity_${DateTime.now().microsecondsSinceEpoch}',
        caseId: item.id,
        organizationId: item.organizationId,
        actorUserId: widget.session.userId,
        actorName: widget.session.displayName,
        kind: TransactionActivityKind.comment,
        message: 'Commented on “${item.title}”: $body',
        createdAtIso: now,
        recipientUserId: item.ownerUserId,
      ));
      if (item.ownerUserId != widget.session.userId) {
        await workflowRepository.addNotification(TransactionNotification(
          id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
          caseId: item.id,
          organizationId: item.organizationId,
          recipientUserId: item.ownerUserId,
          title: 'New case comment',
          body: '${widget.session.displayName} commented on ${item.title}.',
          createdAtIso: now,
        ));
      }
      commentController.clear();
    });
  }

  Future<void> _assign(TransactionCase item) {
    final raw = assigneeController.text.trim();
    if (raw.isEmpty) {
      _show('Enter a member ID or name.');
      return Future.value();
    }
    final member = members.where((candidate) {
      return candidate.userId.toLowerCase() == raw.toLowerCase() ||
          candidate.displayName.toLowerCase() == raw.toLowerCase();
    }).firstOrNull;
    final assigneeId = member?.userId ?? raw;
    final assigneeName = member?.displayName ?? raw;
    return _run(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final assignments = {...item.assignedUserIds, assigneeId}.toList();
      final updated = item.copyWith(
        assignedUserIds: assignments,
        updatedAtIso: now,
      );
      await caseRepository.upsertPersonal(item.ownerUserId, updated);
      if (updated.isOrganizationVisible) {
        await caseRepository.upsertOrganization(item.organizationId, updated);
      }
      await workflowRepository.addActivity(TransactionActivity(
        id: 'activity_${DateTime.now().microsecondsSinceEpoch}',
        caseId: item.id,
        organizationId: item.organizationId,
        actorUserId: widget.session.userId,
        actorName: widget.session.displayName,
        kind: TransactionActivityKind.assignment,
        message: 'Assigned $assigneeName to “${item.title}”.',
        createdAtIso: now,
        recipientUserId: assigneeId,
      ));
      await workflowRepository.addNotification(TransactionNotification(
        id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
        caseId: item.id,
        organizationId: item.organizationId,
        recipientUserId: assigneeId,
        title: 'Transaction case assignment',
        body: 'You were assigned to ${item.title}.',
        createdAtIso: now,
      ));
      assigneeController.clear();
    });
  }

  Future<void> _addMember() {
    final id = memberIdController.text.trim();
    final name = memberNameController.text.trim();
    if (id.isEmpty || name.isEmpty) {
      _show('Enter a member ID and display name.');
      return Future.value();
    }
    return _run(() async {
      final member = OrganizationMemberRecord(
        userId: id,
        displayName: name,
        roleLabel: memberRole,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        teamFocus: memberFocusController.text.trim().isEmpty
            ? 'League-wide'
            : memberFocusController.text.trim(),
      );
      await workflowRepository.upsertMember(widget.session.organizationId, member);
      memberIdController.clear();
      memberNameController.clear();
      memberFocusController.text = 'League-wide';
    });
  }

  Future<void> _markNotificationsRead() {
    return _run(() async {
      await workflowRepository.markAllNotificationsRead(widget.session.userId);
    });
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _Panel(child: Text('Loading transaction command center...'));
    }
    final visibleActivities = widget.organizationMode
        ? activities
        : activities.where((activity) {
            return cases.any((item) => item.id == activity.caseId);
          }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(visibleActivities.length),
        const SizedBox(height: 16),
        _metrics(visibleActivities.length),
        const SizedBox(height: 16),
        _tabBar(),
        const SizedBox(height: 16),
        if (selectedTab == 'Imports')
          _imports()
        else if (selectedTab == 'Collaboration')
          _collaboration()
        else if (selectedTab == 'Activity')
          _activity(visibleActivities)
        else if (selectedTab == 'Notifications')
          _notificationCenter()
        else if (selectedTab == 'Members')
          _members()
        else
          ProductRoleOperationsScreen(
            key: ValueKey('cases_${cases.length}_${cases.firstOrNull?.updatedAtIso}'),
            session: widget.session,
            organizationMode: widget.organizationMode,
          ),
      ],
    );
  }

  Widget _hero(int activityCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.organizationMode
                ? 'ORGANIZATION TRANSACTION COMMAND'
                : 'INDIVIDUAL TRANSACTION COMMAND',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            widget.organizationMode
                ? 'Run the shared transaction operation from one surface.'
                : 'Move analysis from an idea to an organization decision.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.organizationMode
                ? 'Cases, imported scenarios, assignments, comments, approvals, activity, members and notifications now share one organization workflow.'
                : 'Import Trade Machine and Front Office work, collaborate on cases, submit for review and follow every organization update.',
            style: const TextStyle(
              color: Color(0xFFEAF2FF),
              height: 1.45,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroPill('${cases.length} CASES'),
              _heroPill('${candidates.length} IMPORT SOURCES'),
              _heroPill('$activityCount EVENTS'),
              _heroPill('$unreadCount UNREAD'),
              if (widget.organizationMode) _heroPill('${members.length} MEMBERS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metrics(int activityCount) {
    final shared = cases.where((item) => item.isOrganizationVisible).length;
    final assigned = cases.where((item) => item.assignedUserIds.length > 1).length;
    final commented = cases.where((item) => item.comments.isNotEmpty).length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Metric('Shared cases', '$shared', 'organization-visible'),
        _Metric('Collaborative', '$assigned', 'multiple assignees'),
        _Metric('Discussed', '$commented', 'cases with comments'),
        _Metric('Activity', '$activityCount', 'workflow events'),
        _Metric('Unread', '$unreadCount', 'personal notifications'),
      ],
    );
  }

  Widget _tabBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in tabs)
          ChoiceChip(
            selected: selectedTab == tab,
            onSelected: (_) => setState(() => selectedTab = tab),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab),
                if (tab == 'Notifications' && unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: _orange,
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _imports() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            'Connected product imports',
            'Saved analytical work becomes a persistent transaction case instead of remaining trapped in an isolated tool.',
          ),
          const SizedBox(height: 14),
          if (candidates.isEmpty)
            const Text(
              'No saved Trade Machine, Front Office, Cap Lab or routed-data package is available yet.',
              style: TextStyle(color: _muted),
            )
          else
            for (final candidate in candidates)
              _ImportRow(
                candidate: candidate,
                organizationMode: widget.organizationMode,
                busy: mutating,
                onPrivate: () => _importCandidate(
                  candidate,
                  organizationVisible: false,
                ),
                onShared: () => _importCandidate(
                  candidate,
                  organizationVisible: true,
                ),
              ),
        ],
      ),
    );
  }

  Widget _collaboration() {
    final item = selectedCase;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            'Case collaboration',
            'Assign work, add decision context, publish private cases and preserve a shared operating history.',
          ),
          const SizedBox(height: 14),
          if (cases.isEmpty)
            const Text('Create or import a transaction case first.')
          else ...[
            DropdownButtonFormField<String>(
              value: item?.id,
              isExpanded: true,
              decoration: _input('Selected transaction case'),
              items: [
                for (final candidate in cases)
                  DropdownMenuItem(
                    value: candidate.id,
                    child: Text('${candidate.title} · ${candidate.status.name}'),
                  ),
              ],
              onChanged: (value) => setState(() => selectedCaseId = value ?? ''),
            ),
            const SizedBox(height: 14),
            if (item != null) ...[
              _caseSummary(item),
              const SizedBox(height: 14),
              if (!widget.organizationMode && !item.isOrganizationVisible)
                FilledButton.icon(
                  onPressed: mutating ? null : () => _publish(item),
                  icon: const Icon(Icons.publish_rounded),
                  label: Text('Submit to ${item.organizationName}'),
                ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final comment = _collaborationCard(
                    title: 'Add comment',
                    child: Column(
                      children: [
                        TextField(
                          controller: commentController,
                          maxLines: 3,
                          decoration: _input('Decision context or question'),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: mutating ? null : () => _addComment(item),
                            icon: const Icon(Icons.comment_rounded),
                            label: const Text('Post comment'),
                          ),
                        ),
                      ],
                    ),
                  );
                  final assignment = _collaborationCard(
                    title: 'Assign member',
                    child: Column(
                      children: [
                        TextField(
                          controller: assigneeController,
                          decoration: _input('Member ID or display name'),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: mutating ? null : () => _assign(item),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Assign'),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (compact) {
                    return Column(
                      children: [comment, const SizedBox(height: 12), assignment],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: comment),
                      const SizedBox(width: 12),
                      Expanded(child: assignment),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Comments',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (item.comments.isEmpty)
                const Text('No comments yet.', style: TextStyle(color: _muted))
              else
                for (final comment in item.comments.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.comment_rounded)),
                    title: Text(comment.authorName),
                    subtitle: Text(comment.body),
                    trailing: Text(_date(comment.createdAtIso)),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _activity(List<TransactionActivity> visibleActivities) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            'Immutable-style activity stream',
            'A chronological operating history for imports, submissions, comments, assignments and organization decisions.',
          ),
          const SizedBox(height: 14),
          if (visibleActivities.isEmpty)
            const Text('No workflow activity has been recorded yet.')
          else
            for (final activity in visibleActivities)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(_activityIcon(activity.kind))),
                title: Text(activity.message),
                subtitle: Text('${activity.actorName} · ${activity.kind.name}'),
                trailing: Text(_date(activity.createdAtIso)),
              ),
        ],
      ),
    );
  }

  Widget _notificationCenter() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _Title(
                  'Notification inbox',
                  'Assignments, comments, submissions and decisions surface in the user’s own operating queue.',
                ),
              ),
              TextButton.icon(
                onPressed: unreadCount == 0 || mutating ? null : _markNotificationsRead,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (notifications.isEmpty)
            const Text('No transaction notifications yet.')
          else
            for (final notification in notifications)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: notification.isRead ? Colors.white : const Color(0xFFEFF6FF),
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      notification.isRead
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                      color: notification.isRead ? _muted : _blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notification.body,
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Text(_date(notification.createdAtIso)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _members() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            'Organization members and reviewers',
            'Create the local organization directory used by assignments, workload views and review routing.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 210,
                child: TextField(
                  controller: memberIdController,
                  decoration: _input('Member user ID'),
                ),
              ),
              SizedBox(
                width: 230,
                child: TextField(
                  controller: memberNameController,
                  decoration: _input('Display name'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  value: memberRole,
                  decoration: _input('Role'),
                  items: const [
                    DropdownMenuItem(value: 'Analyst', child: Text('Analyst')),
                    DropdownMenuItem(value: 'Reviewer', child: Text('Reviewer')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (value) => setState(() => memberRole = value ?? 'Analyst'),
                ),
              ),
              SizedBox(
                width: 210,
                child: TextField(
                  controller: memberFocusController,
                  decoration: _input('Team or coverage focus'),
                ),
              ),
              FilledButton.icon(
                onPressed: mutating ? null : _addMember,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add member'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (members.isEmpty)
            const Text('No organization members have been added.')
          else
            for (final member in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.badge_rounded)),
                title: Text(member.displayName),
                subtitle: Text(
                  '${member.roleLabel} · ${member.teamFocus} · capacity ${member.reviewCapacity}',
                ),
                trailing: member.userId == widget.session.userId
                    ? const Chip(label: Text('You'))
                    : IconButton(
                        tooltip: 'Remove member',
                        onPressed: mutating
                            ? null
                            : () => _run(() async {
                                  await workflowRepository.removeMember(
                                    widget.session.organizationId,
                                    member.userId,
                                  );
                                }),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
              ),
        ],
      ),
    );
  }

  Widget _caseSummary(TransactionCase item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _soft,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(label: Text(item.status.name)),
            ],
          ),
          Text(
            '${item.teams.join(' / ')} · ${item.operatingSeason} · ${item.ownerName}',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag('${item.assignedUserIds.length} assignees'),
              _tag('${item.comments.length} comments'),
              _tag('${item.ruleFindings.length} findings'),
              _tag(item.isOrganizationVisible ? 'Organization shared' : 'Private'),
              if (item.sourcePayloadId.isNotEmpty) _tag('Connected source'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _collaborationCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({
    required this.candidate,
    required this.organizationMode,
    required this.busy,
    required this.onPrivate,
    required this.onShared,
  });

  final TransactionImportCandidate candidate;
  final bool organizationMode;
  final bool busy;
  final VoidCallback onPrivate;
  final VoidCallback onShared;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _soft,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.source.toUpperCase(),
                style: const TextStyle(
                  color: _blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                candidate.title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(candidate.summary, style: const TextStyle(color: _muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _tag(candidate.operatingSeason),
                  _tag(candidate.teams.isEmpty ? 'Teams unresolved' : candidate.teams.join(' / ')),
                  _tag(candidate.readiness),
                  _tag('${candidate.findings.length} source findings'),
                ],
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!organizationMode)
                OutlinedButton.icon(
                  onPressed: busy ? null : onPrivate,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Import privately'),
                ),
              FilledButton.icon(
                onPressed: busy ? null : onShared,
                icon: const Icon(Icons.corporate_fare_rounded),
                label: Text(organizationMode ? 'Create shared case' : 'Submit to organization'),
              ),
            ],
          );
          if (constraints.maxWidth < 840) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            children: [Expanded(child: copy), const SizedBox(width: 16), actions],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D071A33),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: _muted, height: 1.4)),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      );
}

InputDecoration _input(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _soft,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

Widget _tag(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
    );

Widget _heroPill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

IconData _activityIcon(TransactionActivityKind kind) => switch (kind) {
      TransactionActivityKind.created => Icons.add_task_rounded,
      TransactionActivityKind.imported => Icons.input_rounded,
      TransactionActivityKind.status => Icons.sync_alt_rounded,
      TransactionActivityKind.comment => Icons.comment_rounded,
      TransactionActivityKind.assignment => Icons.person_add_alt_1_rounded,
      TransactionActivityKind.approval => Icons.approval_rounded,
      TransactionActivityKind.notification => Icons.notifications_rounded,
    };

String _date(String iso) {
  final value = DateTime.tryParse(iso)?.toLocal();
  if (value == null) return '—';
  return '${value.month}/${value.day}/${value.year}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
