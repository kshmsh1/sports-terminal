import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/product_nba_research_command_center_screen.dart';
import 'launch_role_product_shell.dart';

class RoleResearchAugmentedShell extends StatelessWidget {
  const RoleResearchAugmentedShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  Future<void> _openResearch(
    BuildContext context, {
    NbaResearchSection initialSection = NbaResearchSection.overview,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF0D1420),
          appBar: AppBar(
            backgroundColor: const Color(0xFF151F2F),
            foregroundColor: Colors.white,
            title: Text(
              session.role.canManageOrganization
                  ? '${session.organizationName} NBA Research'
                  : 'NBA Research Command Center',
            ),
            leading: IconButton(
              tooltip: 'Close research center',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: ProductNbaResearchCommandCenterScreen(
            session: session,
            initialSection: initialSection,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1020;
        return Stack(
          children: [
            LaunchRoleProductShell(
              session: session,
              workspaceController: workspaceController,
              onSignOut: onSignOut,
            ),
            Positioned(
              left: compact ? 18 : 306,
              bottom: 18,
              child: SafeArea(
                child: FloatingActionButton.extended(
                  heroTag: 'nba-research-command-center',
                  onPressed: () => _openResearch(context),
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.query_stats_rounded),
                  label: Text(
                    session.role.canManageOrganization
                        ? 'Organization Research'
                        : 'NBA Research',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            Positioned(
              left: compact ? 18 : 306,
              bottom: 82,
              child: SafeArea(
                child: Material(
                  color: const Color(0xFF071A33),
                  elevation: 8,
                  borderRadius: BorderRadius.circular(999),
                  child: PopupMenuButton<NbaResearchSection>(
                    tooltip: 'Open a research module directly',
                    onSelected: (section) =>
                        _openResearch(context, initialSection: section),
                    itemBuilder: (context) => [
                      for (final section in NbaResearchSection.values.skip(1))
                        PopupMenuItem(
                          value: section,
                          child: Row(
                            children: [
                              Icon(section.icon, size: 18),
                              const SizedBox(width: 9),
                              Text(section.label),
                            ],
                          ),
                        ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFFFCB45),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Quick research',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
