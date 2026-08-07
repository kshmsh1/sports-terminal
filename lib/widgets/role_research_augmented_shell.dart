import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/product_nba_research_command_center_screen.dart';
import '../screens/product_nba_universe_screen.dart';
import '../services/nba_research_context_store.dart';
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

  Future<void> _openUniverse(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF09111C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121D2B),
            foregroundColor: Colors.white,
            title: const Text('NBA Universe'),
            leading: IconButton(
              tooltip: 'Close NBA Universe',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: ProductNbaUniverseScreen(
            onOpenStats: () {
              Navigator.of(dialogContext).pop();
              Future<void>.delayed(
                Duration.zero,
                () => _openResearch(
                  context,
                  initialSection: NbaResearchSection.stats,
                ),
              );
            },
            onOpenAnalytics: () {
              Navigator.of(dialogContext).pop();
              Future<void>.delayed(
                Duration.zero,
                () => _openResearch(
                  context,
                  initialSection: NbaResearchSection.analytics,
                ),
              );
            },
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
        final left = compact ? 18.0 : 306.0;
        return Stack(
          children: [
            LaunchRoleProductShell(
              session: session,
              workspaceController: workspaceController,
              onSignOut: onSignOut,
            ),
            Positioned(
              left: left,
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
              left: left,
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
            Positioned(
              left: left,
              bottom: 128,
              child: SafeArea(
                child: Material(
                  color: const Color(0xFF132338),
                  elevation: 9,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () => _openUniverse(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.public_rounded,
                            color: Color(0xFFFFCB45),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'NBA Universe',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<NbaResearchContext>(
                            future: const NbaResearchContextStore().load(),
                            builder: (context, snapshot) {
                              final active = snapshot.data;
                              if (active == null) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                constraints: const BoxConstraints(maxWidth: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: active.historical
                                      ? const Color(0x22FFCB45)
                                      : const Color(0x2265E3A5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  active.historical
                                      ? active.season
                                      : 'CURRENT',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active.historical
                                        ? const Color(0xFFFFCB45)
                                        : const Color(0xFF65E3A5),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
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
