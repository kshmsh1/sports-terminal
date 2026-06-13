import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/alerts_screen.dart';
import '../screens/award_races_screen.dart';
import '../screens/compare_screen.dart';
import '../screens/context_assets_overview_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/final_rosters_screen.dart';
import '../screens/games_screen.dart';
import '../screens/internal_spreadsheet_screen.dart';
import '../screens/players_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/safe_sql_screen.dart';
import '../screens/saved_views_screen.dart';
import '../screens/search_screen.dart';
import '../screens/seasons_screen.dart';
import '../screens/standings_playoffs_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/teams_screen.dart';

class UserTerminalShell extends StatefulWidget {
  const UserTerminalShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<UserTerminalShell> createState() => _UserTerminalShellState();
}

class _UserTerminalShellState extends State<UserTerminalShell> {
  int selectedIndex = 0;
  String navFilter = '';

  List<_UserTab> get tabs => [
        const _UserTab(
          'Dashboard',
          Icons.dashboard_outlined,
          DashboardScreen(),
          'Command',
        ),
        const _UserTab('Search', Icons.search, SearchScreen(), 'Command'),
        const _UserTab(
          'Players',
          Icons.person_search_outlined,
          PlayersScreen(),
          'NBA',
        ),
        const _UserTab('Teams', Icons.groups_outlined, TeamsScreen(), 'NBA'),
        const _UserTab(
          'Seasons',
          Icons.calendar_month_outlined,
          SeasonsScreen(),
          'NBA',
        ),
        const _UserTab(
          'Stats',
          Icons.query_stats_outlined,
          StatsScreen(),
          'NBA',
        ),
        const _UserTab(
          'Standings',
          Icons.leaderboard_outlined,
          StandingsScreen(),
          'NBA',
        ),
        const _UserTab(
          'Playoffs',
          Icons.military_tech_outlined,
          PlayoffsScreen(),
          'NBA',
        ),
        const _UserTab(
          'Games',
          Icons.sports_basketball_outlined,
          GamesScreen(),
          'NBA',
        ),
        const _UserTab(
          'Rosters',
          Icons.assignment_ind_outlined,
          FinalRostersScreen(),
          'NBA',
        ),
        const _UserTab(
          'Context',
          Icons.hub_outlined,
          ContextAssetsOverviewScreen(),
          'NBA',
        ),
        const _UserTab(
          'Awards',
          Icons.emoji_events_outlined,
          AwardRacesScreen(),
          'NBA',
        ),
        const _UserTab(
          'Compare',
          Icons.compare_arrows_outlined,
          CompareScreen(),
          'Research',
        ),
        const _UserTab(
          'Reports',
          Icons.article_outlined,
          ReportsScreen(),
          'Research',
        ),
        const _UserTab(
          'Saved Views',
          Icons.bookmark_border_outlined,
          SavedViewsScreen(),
          'Research',
        ),
        const _UserTab(
          'Alerts',
          Icons.notifications_none_outlined,
          AlertsScreen(),
          'Research',
        ),
        _UserTab(
          'Spreadsheet',
          Icons.grid_on_outlined,
          InternalSpreadsheetScreen(
            session: widget.session,
            workspaceController: widget.workspaceController,
          ),
          'Workspace',
        ),
        const _UserTab(
          'Code Workspace',
          Icons.code_outlined,
          SafeSqlScreen(),
          'Workspace',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final currentTabs = tabs;
    if (selectedIndex >= currentTabs.length) {
      selectedIndex = 0;
    }
    final selected = currentTabs[selectedIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        if (compact) {
          return Scaffold(
            backgroundColor: const Color(0xFF0B0F14),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0D1218),
              foregroundColor: Colors.white,
              title: Text(
                selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: widget.onSignOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            drawer: Drawer(
              backgroundColor: const Color(0xFF111820),
              child: SafeArea(
                child: _NavigationPanel(
                  session: widget.session,
                  tabs: currentTabs,
                  selectedIndex: selectedIndex,
                  navFilter: navFilter,
                  onFilterChanged: (value) {
                    setState(() => navFilter = value);
                  },
                  onSelected: (index) {
                    setState(() => selectedIndex = index);
                    Navigator.of(context).pop();
                  },
                  onSignOut: widget.onSignOut,
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: selected.screen,
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F14),
          body: Row(
            children: [
              SizedBox(
                width: 286,
                child: _NavigationPanel(
                  session: widget.session,
                  tabs: currentTabs,
                  selectedIndex: selectedIndex,
                  navFilter: navFilter,
                  onFilterChanged: (value) {
                    setState(() => navFilter = value);
                  },
                  onSelected: (index) {
                    setState(() => selectedIndex = index);
                  },
                  onSignOut: widget.onSignOut,
                ),
              ),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      _UserTopBar(session: widget.session, tab: selected),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: selected.screen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.session,
    required this.tabs,
    required this.selectedIndex,
    required this.navFilter,
    required this.onFilterChanged,
    required this.onSelected,
    required this.onSignOut,
  });

  final AppSession session;
  final List<_UserTab> tabs;
  final int selectedIndex;
  final String navFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final normalizedFilter = navFilter.trim().toLowerCase();
    final filtered = <({int index, _UserTab tab})>[
      for (var i = 0; i < tabs.length; i++)
        if (normalizedFilter.isEmpty ||
            '${tabs[i].label} ${tabs[i].group}'
                .toLowerCase()
                .contains(normalizedFilter))
          (index: i, tab: tabs[i]),
    ];

    return Material(
      color: const Color(0xFF111820),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.sports_basketball,
                    color: Color(0xFF8AB4F8),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sports Terminal',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1218),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF263241)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.organizationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.role.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8AB4F8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: onFilterChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Filter navigation...',
                  hintStyle: const TextStyle(color: Color(0xFF657386)),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF657386),
                    size: 18,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0D1218),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF263241)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8AB4F8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, position) {
                    final item = filtered[position];
                    return _NavigationEntry(
                      icon: item.tab.icon,
                      title: item.tab.label,
                      subtitle: item.tab.group,
                      selected: item.index == selectedIndex,
                      onTap: () => onSelected(item.index),
                    );
                  },
                ),
              ),
              const Divider(color: Color(0xFF263241)),
              _NavigationEntry(
                icon: Icons.logout,
                title: 'Sign out',
                onTap: onSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationEntry extends StatelessWidget {
  const _NavigationEntry({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? Colors.white : const Color(0xFFB6C0CC);
    final iconColor =
        selected ? const Color(0xFF8AB4F8) : const Color(0xFF8794A5);

    return Material(
      color: selected ? const Color(0xFF1B2A3F) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF657386),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTopBar extends StatelessWidget {
  const _UserTopBar({required this.session, required this.tab});

  final AppSession session;
  final _UserTab tab;

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${tab.group} • ${session.organizationName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8794A5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF121A23),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF263241)),
            ),
            child: Text(
              session.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB6C0CC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTab {
  const _UserTab(this.label, this.icon, this.screen, this.group);

  final String label;
  final IconData icon;
  final Widget screen;
  final String group;
}
