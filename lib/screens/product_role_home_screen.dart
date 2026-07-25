import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/transaction_case.dart';
import '../services/transaction_case_repository.dart';
import '../services/transaction_workflow_repository.dart';
import 'product_arena_home_screen.dart';
import 'product_launch_center_screen.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);

class ProductRoleHomeScreen extends StatelessWidget {
  const ProductRoleHomeScreen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomePulse>(
      future: _load(),
      builder: (context, snapshot) {
        final pulse = snapshot.data ?? const _HomePulse();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organizationMode
                        ? '${session.organizationName} operating pulse'
                        : '${session.displayName} workflow pulse',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    organizationMode
                        ? 'Shared transaction workload, customer operations, launch readiness and review pressure now appear directly on the organization home surface.'
                        : 'Your cases, setup progress, plan access, support and unread updates now appear directly on the individual home surface.',
                    style: const TextStyle(color: _muted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _PulseMetric('Cases', '${pulse.total}', Icons.workspaces_rounded),
                      _PulseMetric('In review', '${pulse.review}', Icons.rate_review_rounded),
                      _PulseMetric('Approved', '${pulse.approved}', Icons.verified_rounded),
                      _PulseMetric('Urgent', '${pulse.urgent}', Icons.priority_high_rounded),
                      _PulseMetric('Unread', '${pulse.unread}', Icons.notifications_active_rounded),
                    ],
                  ),
                  if (pulse.latestTitle.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Latest case · ${pulse.latestTitle} · ${pulse.latestStatus}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            ProductLaunchCenterScreen(
              session: session,
              organizationMode: organizationMode,
            ),
            const SizedBox(height: 18),
            ProductArenaHomeScreen(session: session),
          ],
        );
      },
    );
  }

  Future<_HomePulse> _load() async {
    const cases = TransactionCaseRepository();
    const workflow = TransactionWorkflowRepository();
    final items = organizationMode
        ? await cases.loadOrganization(session.organizationId)
        : await cases.loadPersonal(session.userId);
    final notifications = await workflow.loadNotifications(session.userId);
    final latest = items.isEmpty ? null : items.first;
    return _HomePulse(
      total: items.length,
      review: items.where((item) => item.status == TransactionCaseStatus.review).length,
      approved: items.where((item) => item.status == TransactionCaseStatus.approved).length,
      urgent: items.where((item) => item.priority == TransactionCasePriority.urgent).length,
      unread: notifications.where((item) => !item.isRead).length,
      latestTitle: latest?.title ?? '',
      latestStatus: latest?.status.name ?? '',
    );
  }
}

class _HomePulse {
  const _HomePulse({
    this.total = 0,
    this.review = 0,
    this.approved = 0,
    this.urgent = 0,
    this.unread = 0,
    this.latestTitle = '',
    this.latestStatus = '',
  });

  final int total;
  final int review;
  final int approved;
  final int urgent;
  final int unread;
  final String latestTitle;
  final String latestStatus;
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 155,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: _blue, size: 20),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ],
        ),
      );
}
