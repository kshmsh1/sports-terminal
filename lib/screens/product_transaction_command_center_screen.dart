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
  final TransactionCaseRepository caseRepository =
      const TransactionCaseRepository();
  final TransactionWorkflowRepository workflowRepository =
      const TransactionWorkflowRepository();
  final TransactionCaseConvergenceService convergence =
      const TransactionCaseConvergenceService();

  final TextEditingController commentController = TextEditingController();
  final TextEditingController assigneeController = TextEditingController();
  final TextEditingController memberIdController = TextEditingController();
  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberFocusController =
      TextEditingController(text: 'League-wide');

  bool loading = true;
  bool saving = false;
  String tab = 'Cases';
  String selectedCaseId = '';
  String memberRole = 'Analyst';
  List<TransactionCase> cases = <TransactionCase>[];
  List<TransactionImportCandidate> candidates = <TransactionImportCandidate>[];
  List<TransactionActivity> activities = <TransactionActivity>[];
  List<TransactionNotification> notifications = <TransactionNotification>[];
  List<OrganizationMemberRecord> members = <OrganizationMemberRecord>[];

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

  List<String> get availableTabs => <String>[
        'Cases',
        'Imports',
        'Collaboration',
        'Activity',
        'Notifications',
        if (widget.organizationMode) 'Members',
      ];

  int get unreadCount {
    return notifications.where((TransactionNotification item) => !item.isRead).length;
  }

  TransactionCase? _selectedCase() {
    if (cases.isEmpty) return null;
    for (final TransactionCase item in cases) {
      if (item.id == selectedCaseId) return item;
    }
    return cases.first;
  }

  Future<void> _load() async {
    final List<TransactionCase> loadedCases = widget.organizationMode
        ? await caseRepository.loadOrganization(widget.session.organizationId)
        : await caseRepository.loadPersonal(widget.session.userId);
    final List<TransactionImportCandidate> loadedCandidates =
        await convergence.discover();
    final List<TransactionActivity> loadedActivities =
        await workflowRepository.loadActivities(widget.session.organizationId);
    final List<TransactionNotification> loadedNotifications =
        await workflowRepository.loadNotifications(widget.session.userId);
    List<OrganizationMemberRecord> loadedMembers =
        await workflowRepository.loadMembers(widget.session.organizationId);

    if (widget.organizationMode &&
        !loadedMembers.any(
          (OrganizationMemberRecord item) => item.userId == widget.session.userId,
        )) {
      final OrganizationMemberRecord self = OrganizationMemberRecord(
        userId: widget.session.userId,
        displayName: widget.session.displayName,
        roleLabel: widget.session.role.label,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        teamFocus: 'Organization-wide',
        reviewCapacity: 12,
      );
      await workflowRepository.upsertMember(widget.session.organizationId, self);
      loadedMembers = <OrganizationMemberRecord>[self, ...loadedMembers];
    }

    if (!mounted) return;
    setState(() {
      cases = loadedCases;
      candidates = loadedCandidates;
      activities = loadedActivities;
      notifications = loadedNotifications;
      members = loadedMembers;
      if (cases.isNotEmpty &&
          !cases.any((TransactionCase item) => item.id == selectedCaseId)) {
        selectedCaseId = cases.first.id;
      }
      loading = false;
    });
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
      await _load();
    } catch (error) {
      _message('Workflow update failed: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _import(
    TransactionImportCandidate candidate,
    bool organizationVisible,
  ) async {
    await _execute(() async {
      final TransactionCase item = await convergence.importCandidate(
        candidate: candidate,
        session: widget.session,
        organizationVisible: organizationVisible,
      );
      selectedCaseId = item.id;
      tab = 'Collaboration';
      _message('Imported “${item.title}”.');
    });
  }

  Future<void> _submit(TransactionCase item) async {
    await _execute(() async {
      final String now = DateTime.now().toUtc().toIso8601String();
      final TransactionCase updated = item.copyWith(
        status: TransactionCaseStatus.review,
        isOrganizationVisible: true,
        approvals: <TransactionApproval>[
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
      await workflowRepository.addActivity(
        TransactionActivity(
          id: 'activity_${DateTime.now().microsecondsSinceEpoch}',
          caseId: updated.id,
          organizationId: updated.organizationId,
          actorUserId: widget.session.userId,
          actorName: widget.session.displayName,
          kind: TransactionActivityKind.status,
          message: 'Submitted “${updated.title}” for organization review.',
          createdAtIso: now,
          recipientUserId: updated.ownerUserId,
        ),
      );
      await workflowRepository.addNotification(
        TransactionNotification(
          id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
          caseId: updated.id,
          organizationId: updated.organizationId,
          recipientUserId: updated.ownerUserId,
          title: 'Case submitted',
          body: '${updated.title} is awaiting organization review.',
          createdAtIso: now,
        ),
      );
      _message('Submitted to ${updated.organizationName}.');
    });
  }

  Future<void> _addComment(TransactionCase item) async {
    final String body = commentController.text.trim();
    if (body.isEmpty) {
      _message('Enter a comment first.');
      return;
    }
    await _execute(() async {
      final String now = DateTime.now().toUtc().toIso8601String();
      final TransactionCase updated = item.copyWith(
        comments: <TransactionCaseComment>[
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
      await caseRepository.upsertPersonal(updated.ownerUserId, updated);
      if (updated.isOrganizationVisible) {
        await caseRepository.upsertOrganization(updated.organizationId, updated);
      }
      await workflowRepository.addActivity(
        TransactionActivity(
          id: 'activity_${DateTime.now().microsecondsSinceEpoch}',
          caseId: updated.id,
          organizationId: updated.organizationId,
          actorUserId: widget.session.userId,
          actorName: widget.session.displayName,
          kind: TransactionActivityKind.comment,
          message: 'Commented on “${updated.title}”: $body',
          createdAtIso: now,
          recipientUserId: updated.ownerUserId,
        ),
      );
      if (updated.ownerUserId != widget.session.userId) {
        await workflowRepository.addNotification(
          TransactionNotification(
            id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
            caseId: updated.id,
            organizationId: updated.organizationId,
            recipientUserId: updated.ownerUserId,
            title: 'New transaction comment',
            body: '${widget.session.displayName} commented on ${updated.title}.',
            createdAtIso: now,
          ),
        );
      }
      commentController.clear();
    });
  }

  Future<void> _assign(TransactionCase item) async {
    final String raw = assigneeController.text.trim();
    if (raw.isEmpty) {
      _message('Enter a member ID or display name.');
      return;
    }
    String assigneeId = raw;
    String assigneeName = raw;
    for (final OrganizationMemberRecord member in members) {
      if (member.userId.toLowerCase() == raw.toLowerCase() ||
          member.displayName.toLowerCase() == raw.toLowerCase()) {
        assigneeId = member.userId;
        assigneeName = member.displayName;
        break;
      }
    }
    await _execute(() async {
      final String now = DateTime.now().toUtc().toIso8601String();
      final Set<String> nextAssignments = <String>{...item.assignedUserIds, assigneeId};
      final TransactionCase updated = item.copyWith(
        assignedUserIds: nextAssignments.toList(),
        updatedAtIso: now,
      );
      await caseRepository.upsertPersonal(updated.ownerUserId, updated);
      if (updated.isOrganizationVisible) {
        await caseRepository.upsertOrganization(updated.organizationId, updated);
      }
      await workflowRepository.addActivity(
        TransactionActivity(
          id: 'activity_${DateTime.now().microsecondsSinceEpoch}',
          caseId: updated.id,
          organizationId: updated.organizationId,
          actorUserId: widget.session.userId,
          actorName: widget.session.displayName,
          kind: TransactionActivityKind.assignment,
          message: 'Assigned $assigneeName to “${updated.title}”.',
          createdAtIso: now,
          recipientUserId: assigneeId,
        ),
      );
      await workflowRepository.addNotification(
        TransactionNotification(
          id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
          caseId: updated.id,
          organizationId: updated.organizationId,
          recipientUserId: assigneeId,
          title: 'Transaction case assignment',
          body: 'You were assigned to ${updated.title}.',
          createdAtIso: now,
        ),
      );
      assigneeController.clear();
    });
  }

  Future<void> _addMember() async {
    final String id = memberIdController.text.trim();
    final String name = memberNameController.text.trim();
    if (id.isEmpty || name.isEmpty) {
      _message('Enter a member ID and display name.');
      return;
    }
    await _execute(() async {
      await workflowRepository.upsertMember(
        widget.session.organizationId,
        OrganizationMemberRecord(
          userId: id,
          displayName: name,
          roleLabel: memberRole,
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
          teamFocus: memberFocusController.text.trim().isEmpty
              ? 'League-wide'
              : memberFocusController.text.trim(),
        ),
      );
      memberIdController.clear();
      memberNameController.clear();
      memberFocusController.text = 'League-wide';
    });
  }

  Future<void> _removeMember(String userId) async {
    await _execute(() async {
      await workflowRepository.removeMember(
        widget.session.organizationId,
        userId,
      );
    });
  }

  Future<void> _markRead() async {
    await _execute(() async {
      await workflowRepository.markAllNotificationsRead(widget.session.userId);
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _Panel(child: Text('Loading transaction command center...'));
    }
    final Set<String> visibleCaseIds = cases.map((TransactionCase item) => item.id).toSet();
    final List<TransactionActivity> visibleActivities = widget.organizationMode
        ? activities
        : activities
            .where((TransactionActivity item) => visibleCaseIds.contains(item.caseId))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _hero(visibleActivities.length),
        const SizedBox(height: 16),
        _metrics(visibleActivities.length),
        const SizedBox(height: 16),
        _tabs(),
        const SizedBox(height: 16),
        _content(visibleActivities),
      ],
    );
  }

  Widget _content(List<TransactionActivity> visibleActivities) {
    switch (tab) {
      case 'Imports':
        return _imports();
      case 'Collaboration':
        return _collaboration();
      case 'Activity':
        return _activity(visibleActivities);
      case 'Notifications':
        return _notifications();
      case 'Members':
        return _members();
      default:
        return ProductRoleOperationsScreen(
          key: ValueKey<String>('cases_${cases.length}_${cases.isEmpty ? '' : cases.first.updatedAtIso}'),
          session: widget.session,
          organizationMode: widget.organizationMode,
        );
    }
  }

  Widget _hero(int activityCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[_navy, _blue, _orange]),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                ? 'Cases, imports, assignments, comments, approvals, members, activity and notifications now share one organization workflow.'
                : 'Import Trade Machine and Front Office work, collaborate on cases, submit for review and follow every update.',
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
            children: <Widget>[
              _pill('${cases.length} CASES'),
              _pill('${candidates.length} IMPORT SOURCES'),
              _pill('$activityCount EVENTS'),
              _pill('$unreadCount UNREAD'),
              if (widget.organizationMode) _pill('${members.length} MEMBERS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metrics(int activityCount) {
    final int shared = cases.where((TransactionCase item) => item.isOrganizationVisible).length;
    final int collaborative =
        cases.where((TransactionCase item) => item.assignedUserIds.length > 1).length;
    final int discussed =
        cases.where((TransactionCase item) => item.comments.isNotEmpty).length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _Metric('Shared cases', '$shared', 'organization-visible'),
        _Metric('Collaborative', '$collaborative', 'multiple assignees'),
        _Metric('Discussed', '$discussed', 'cases with comments'),
        _Metric('Activity', '$activityCount', 'workflow events'),
        _Metric('Unread', '$unreadCount', 'personal notifications'),
      ],
    );
  }

  Widget _tabs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String name in availableTabs)
          ChoiceChip(
            selected: tab == name,
            onSelected: (bool selected) {
              if (selected) setState(() => tab = name);
            },
            label: Text(
              name == 'Notifications' && unreadCount > 0
                  ? '$name ($unreadCount)'
                  : name,
            ),
          ),
      ],
    );
  }

  Widget _imports() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Title(
            'Connected product imports',
            'Saved analytical work becomes a persistent transaction case instead of remaining trapped inside one tool.',
          ),
          const SizedBox(height: 14),
          if (candidates.isEmpty)
            const Text(
              'No saved Trade Machine, Front Office, Cap Lab or routed-data package is available.',
              style: TextStyle(color: _muted),
            )
          else
            for (final TransactionImportCandidate candidate in candidates)
              _candidateCard(candidate),
        ],
      ),
    );
  }

  Widget _candidateCard(TransactionImportCandidate candidate) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _soft,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _tag(candidate.operatingSeason),
              _tag(candidate.teams.isEmpty ? 'Teams unresolved' : candidate.teams.join(' / ')),
              _tag(candidate.readiness),
              _tag('${candidate.findings.length} source findings'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!widget.organizationMode)
                OutlinedButton.icon(
                  onPressed: saving ? null : () => _import(candidate, false),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Import privately'),
                ),
              FilledButton.icon(
                onPressed: saving ? null : () => _import(candidate, true),
                icon: const Icon(Icons.corporate_fare_rounded),
                label: Text(
                  widget.organizationMode
                      ? 'Create shared case'
                      : 'Submit to organization',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _collaboration() {
    final TransactionCase? item = _selectedCase();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Title(
            'Case collaboration',
            'Assign work, add decision context, publish private cases and preserve operating history.',
          ),
          const SizedBox(height: 14),
          if (cases.isEmpty)
            const Text('Create or import a transaction case first.')
          else ...<Widget>[
            DropdownButtonFormField<String>(
              initialValue: item?.id,
              isExpanded: true,
              decoration: _input('Selected transaction case'),
              items: <DropdownMenuItem<String>>[
                for (final TransactionCase candidate in cases)
                  DropdownMenuItem<String>(
                    value: candidate.id,
                    child: Text('${candidate.title} · ${candidate.status.name}'),
                  ),
              ],
              onChanged: (String? value) {
                if (value != null) setState(() => selectedCaseId = value);
              },
            ),
            if (item != null) ...<Widget>[
              const SizedBox(height: 14),
              _caseCard(item),
              const SizedBox(height: 12),
              if (!widget.organizationMode && !item.isOrganizationVisible)
                FilledButton.icon(
                  onPressed: saving ? null : () => _submit(item),
                  icon: const Icon(Icons.publish_rounded),
                  label: Text('Submit to ${item.organizationName}'),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: _input('Decision context or question'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: saving ? null : () => _addComment(item),
                icon: const Icon(Icons.comment_rounded),
                label: const Text('Post comment'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: assigneeController,
                decoration: _input('Member ID or display name'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: saving ? null : () => _assign(item),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Assign member'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Comments',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
              ),
              if (item.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No comments yet.', style: TextStyle(color: _muted)),
                )
              else
                for (final TransactionCaseComment comment in item.comments.reversed)
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

  Widget _caseCard(TransactionCase item) {
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
        children: <Widget>[
          Text(
            item.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.teams.join(' / ')} · ${item.operatingSeason} · ${item.ownerName}',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _tag(item.status.name),
              _tag('${item.assignedUserIds.length} assignees'),
              _tag('${item.comments.length} comments'),
              _tag('${item.ruleFindings.length} findings'),
              _tag(item.isOrganizationVisible ? 'Organization shared' : 'Private'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activity(List<TransactionActivity> visibleActivities) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Title(
            'Transaction activity stream',
            'A chronological history for imports, submissions, comments, assignments and decisions.',
          ),
          const SizedBox(height: 12),
          if (visibleActivities.isEmpty)
            const Text('No workflow activity has been recorded yet.')
          else
            for (final TransactionActivity activity in visibleActivities)
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

  Widget _notifications() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: _Title(
                  'Notification inbox',
                  'Assignments, comments, submissions and decisions enter the user’s operating queue.',
                ),
              ),
              TextButton.icon(
                onPressed: unreadCount == 0 || saving ? null : _markRead,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (notifications.isEmpty)
            const Text('No transaction notifications yet.')
          else
            for (final TransactionNotification notification in notifications)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: notification.isRead ? Colors.white : const Color(0xFFEFF6FF),
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notification.title,
                      style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(notification.body, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 5),
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
        children: <Widget>[
          const _Title(
            'Organization members and reviewers',
            'Build the directory used by assignments, workload views and review routing.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              SizedBox(
                width: 200,
                child: TextField(
                  controller: memberIdController,
                  decoration: _input('Member user ID'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: memberNameController,
                  decoration: _input('Display name'),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: memberRole,
                  decoration: _input('Role'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'Analyst', child: Text('Analyst')),
                    DropdownMenuItem<String>(value: 'Reviewer', child: Text('Reviewer')),
                    DropdownMenuItem<String>(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (String? value) {
                    if (value != null) setState(() => memberRole = value);
                  },
                ),
              ),
              SizedBox(
                width: 210,
                child: TextField(
                  controller: memberFocusController,
                  decoration: _input('Coverage focus'),
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : _addMember,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add member'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (members.isEmpty)
            const Text('No organization members have been added.')
          else
            for (final OrganizationMemberRecord member in members)
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
                        onPressed: saving ? null : () => _removeMember(member.userId),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
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
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
}

InputDecoration _input(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _soft,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
}

Widget _tag(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
  );
}

Widget _pill(String label) {
  return Container(
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
}

IconData _activityIcon(TransactionActivityKind kind) {
  switch (kind) {
    case TransactionActivityKind.created:
      return Icons.add_task_rounded;
    case TransactionActivityKind.imported:
      return Icons.input_rounded;
    case TransactionActivityKind.status:
      return Icons.sync_alt_rounded;
    case TransactionActivityKind.comment:
      return Icons.comment_rounded;
    case TransactionActivityKind.assignment:
      return Icons.person_add_alt_1_rounded;
    case TransactionActivityKind.approval:
      return Icons.approval_rounded;
    case TransactionActivityKind.notification:
      return Icons.notifications_rounded;
  }
}

String _date(String iso) {
  final DateTime? value = DateTime.tryParse(iso)?.toLocal();
  if (value == null) return '—';
  return '${value.month}/${value.day}/${value.year}';
}
