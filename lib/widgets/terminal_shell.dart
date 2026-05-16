import 'package:flutter/material.dart';

import '../screens/compare_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/data_model_screen.dart';
import '../screens/data_roadmap_screen.dart';
import '../screens/era_context_screen.dart';
import '../screens/franchise_history_screen.dart';
import '../screens/g_league_roadmap_screen.dart';
import '../screens/information_architecture_screen.dart';
import '../screens/ingestion_pipeline_screen.dart';
import '../screens/league_ecosystem_screen.dart';
import '../screens/module_inventory_screen.dart';
import '../screens/player_schema_screen.dart';
import '../screens/players_screen.dart';
import '../screens/quality_controls_screen.dart';
import '../screens/screen_depth_plan_screen.dart';
import '../screens/seasons_screen.dart';
import '../screens/source_policy_screen.dart';
import '../screens/teams_screen.dart';

class TerminalShell extends StatefulWidget {
  const TerminalShell({super.key});

  @override
  State<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends State<TerminalShell> {
  int selectedIndex = 0;

  final tabs = const [
    _TerminalTab(label: 'Dashboard', icon: Icons.dashboard_outlined),
    _TerminalTab(label: 'Module Inventory', icon: Icons.view_module_outlined),
    _TerminalTab(label: 'Screen Depth Plan', icon: Icons.layers_outlined),
    _TerminalTab(label: 'Basketball Ecosystem', icon: Icons.hub_outlined),
    _TerminalTab(label: 'Information Architecture', icon: Icons.account_tree_outlined),
    _TerminalTab(label: 'Data Model', icon: Icons.data_object_outlined),
    _TerminalTab(label: 'Players', icon: Icons.person_search_outlined),
    _TerminalTab(label: 'Teams', icon: Icons.groups_outlined),
    _TerminalTab(label: 'Seasons', icon: Icons.calendar_month_outlined),
    _TerminalTab(label: 'Franchise History', icon: Icons.history_edu_outlined),
    _TerminalTab(label: 'Era Context', icon: Icons.timeline_outlined),
    _TerminalTab(label: 'Player Schema', icon: Icons.badge_outlined),
    _TerminalTab(label: 'Data Roadmap', icon: Icons.storage_outlined),
    _TerminalTab(label: 'Quality Controls', icon: Icons.verified_outlined),
    _TerminalTab(label: 'Source Policy', icon: Icons.policy_outlined),
    _TerminalTab(label: 'Ingestion Pipeline', icon: Icons.schema_outlined),
    _TerminalTab(label: 'G League Roadmap', icon: Icons.sports_basketball_outlined),
    _TerminalTab(label: 'Compare', icon: Icons.compare_arrows_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Row(
        children: [
          Container(
            width: 268,
            decoration: const BoxDecoration(
              color: Color(0xFF111820),
              border: Border(right: BorderSide(color: Color(0xFF263241))),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 20),
                    const _SidebarSectionLabel(label: 'Terminal'),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: tabs.length,
                        itemBuilder: (context, i) => _NavButton(
                          label: tabs[i].label,
                          icon: tabs[i].icon,
                          isSelected: selectedIndex == i,
                          onTap: () => setState(() => selectedIndex = i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _SidebarFooter(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(title: tabs[selectedIndex].label),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _ScreenBody(index: selectedIndex),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalTab {
  const _TerminalTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF152235),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B3B52)),
          ),
          child: const Icon(Icons.sports_basketball, color: Color(0xFF8AB4F8)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sports Terminal',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'NBA Historical Build',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFF8794A5), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF657386),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B2A3F) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF385A86) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF8AB4F8) : const Color(0xFF8794A5),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFB6C0CC),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1218),
        border: Border(bottom: BorderSide(color: Color(0xFF263241))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            width: 360,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF121A23),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF263241)),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Color(0xFF8794A5), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search players, teams, seasons, reports...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0xFF8794A5), fontSize: 13),
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

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1218),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: const Text(
        'NBA first. G League later. Real data only; blanks until sources are connected.',
        style: TextStyle(color: Color(0xFF8794A5), fontSize: 12, height: 1.35),
      ),
    );
  }
}

class _ScreenBody extends StatelessWidget {
  const _ScreenBody({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 1:
        return const ModuleInventoryScreen();
      case 2:
        return const ScreenDepthPlanScreen();
      case 3:
        return const LeagueEcosystemScreen();
      case 4:
        return const InformationArchitectureScreen();
      case 5:
        return const DataModelScreen();
      case 6:
        return const PlayersScreen();
      case 7:
        return const TeamsScreen();
      case 8:
        return const SeasonsScreen();
      case 9:
        return const FranchiseHistoryScreen();
      case 10:
        return const EraContextScreen();
      case 11:
        return const PlayerSchemaScreen();
      case 12:
        return const DataRoadmapScreen();
      case 13:
        return const QualityControlsScreen();
      case 14:
        return const SourcePolicyScreen();
      case 15:
        return const IngestionPipelineScreen();
      case 16:
        return const GLeagueRoadmapScreen();
      case 17:
        return const CompareScreen();
      default:
        return const DashboardScreen();
    }
  }
}
