import 'package:flutter/material.dart';

import '../screens/accessibility_screen.dart';
import '../screens/action_center_screen.dart';
import '../screens/advanced_stat_taxonomy_screen.dart';
import '../screens/alert_evaluation_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/audit_trail_screen.dart';
import '../screens/award_races_screen.dart';
import '../screens/build_milestones_screen.dart';
import '../screens/column_library_screen.dart';
import '../screens/community_hub_screen.dart';
import '../screens/compare_screen.dart';
import '../screens/contracts_screen.dart';
import '../screens/core_mvp_gaps_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/data_coverage_screen.dart';
import '../screens/data_health_screen.dart';
import '../screens/data_lineage_screen.dart';
import '../screens/data_model_screen.dart';
import '../screens/data_roadmap_screen.dart';
import '../screens/dataset_registry_screen.dart';
import '../screens/entity_detail_plan_screen.dart';
import '../screens/entity_graph_screen.dart';
import '../screens/era_context_screen.dart';
import '../screens/export_center_screen.dart';
import '../screens/fantasy_terminal_screen.dart';
import '../screens/field_dictionary_screen.dart';
import '../screens/franchise_history_screen.dart';
import '../screens/g_league_roadmap_screen.dart';
import '../screens/games_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/import_jobs_screen.dart';
import '../screens/information_architecture_screen.dart';
import '../screens/ingestion_pipeline_screen.dart';
import '../screens/integration_plan_screen.dart';
import '../screens/keyboard_shortcuts_screen.dart';
import '../screens/league_ecosystem_screen.dart';
import '../screens/league_expansion_screen.dart';
import '../screens/metric_packages_screen.dart';
import '../screens/module_inventory_screen.dart';
import '../screens/navigation_strategy_screen.dart';
import '../screens/nba_mvp_completion_screen.dart';
import '../screens/performance_budget_screen.dart';
import '../screens/personas_screen.dart';
import '../screens/platform_endgame_screen.dart';
import '../screens/player_identity_import_screen.dart';
import '../screens/player_schema_screen.dart';
import '../screens/players_screen.dart';
import '../screens/privacy_controls_screen.dart';
import '../screens/product_backlog_screen.dart';
import '../screens/qa_console_screen.dart';
import '../screens/quality_controls_screen.dart';
import '../screens/release_plan_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/research_source_screen.dart';
import '../screens/risk_register_screen.dart';
import '../screens/saved_view_lifecycle_screen.dart';
import '../screens/saved_views_screen.dart';
import '../screens/screen_depth_plan_screen.dart';
import '../screens/search_screen.dart';
import '../screens/season_command_screen.dart';
import '../screens/seasons_screen.dart';
import '../screens/source_policy_screen.dart';
import '../screens/source_registry_screen.dart';
import '../screens/standings_playoffs_screen.dart';
import '../screens/stat_dictionary_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/table_templates_screen.dart';
import '../screens/teams_screen.dart';
import '../screens/ui_patterns_screen.dart';
import '../screens/workflow_playbook_screen.dart';
import '../screens/workspace_studio_screen.dart';

class TerminalShell extends StatefulWidget {
  const TerminalShell({super.key});

  @override
  State<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends State<TerminalShell> {
  int selectedIndex = 0;
  String navQuery = '';
  String selectedNavGroup = 'All';

  final tabs = const [
    _TerminalTab(label: 'Dashboard', icon: Icons.dashboard_outlined, screen: DashboardScreen(), section: _TabSection.core, group: 'Command'),
    _TerminalTab(label: 'Search', icon: Icons.search, screen: SearchScreen(), section: _TabSection.core, group: 'Command'),
    _TerminalTab(label: 'Players', icon: Icons.person_search_outlined, screen: PlayersScreen(), section: _TabSection.core, group: 'NBA Core'),
    _TerminalTab(label: 'Teams', icon: Icons.groups_outlined, screen: TeamsScreen(), section: _TabSection.core, group: 'NBA Core'),
    _TerminalTab(label: 'Seasons', icon: Icons.calendar_month_outlined, screen: SeasonsScreen(), section: _TabSection.core, group: 'NBA Core'),
    _TerminalTab(label: 'Stats', icon: Icons.query_stats_outlined, screen: StatsScreen(), section: _TabSection.core, group: 'NBA Core'),
    _TerminalTab(label: 'Standings', icon: Icons.leaderboard_outlined, screen: StandingsScreen(), section: _TabSection.core, group: 'NBA Core'),
    _TerminalTab(label: 'Playoffs', icon: Icons.military_tech_outlined, screen: PlayoffsScreen(), section: _TabSection.core, group: 'NBA Core'),
    _TerminalTab(label: 'Games', icon: Icons.sports_basketball_outlined, screen: GamesScreen(), section: _TabSection.core, group: 'NBA Core'),
    _TerminalTab(label: 'Rosters', icon: Icons.assignment_ind_outlined, screen: RostersScreen(), section: _TabSection.core, group: 'Context'),
    _TerminalTab(label: 'Awards', icon: Icons.emoji_events_outlined, screen: AwardsScreen(), section: _TabSection.core, group: 'Context'),
    _TerminalTab(label: 'Draft', icon: Icons.school_outlined, screen: DraftScreen(), section: _TabSection.core, group: 'Context'),
    _TerminalTab(label: 'Transactions', icon: Icons.swap_horiz_outlined, screen: TransactionsScreen(), section: _TabSection.core, group: 'Context'),
    _TerminalTab(label: 'Contracts', icon: Icons.paid_outlined, screen: ContractsScreen(), section: _TabSection.core, group: 'Context'),
    _TerminalTab(label: 'Media & Research', icon: Icons.library_books_outlined, screen: MediaResearchScreen(), section: _TabSection.core, group: 'Context'),
    _TerminalTab(label: 'Scouting', icon: Icons.manage_search_outlined, screen: ScoutingScreen(), section: _TabSection.core, group: 'Context'),
    _TerminalTab(label: 'Reports', icon: Icons.article_outlined, screen: ReportsScreen(), section: _TabSection.core, group: 'Workflows'),
    _TerminalTab(label: 'Saved Views', icon: Icons.bookmark_border_outlined, screen: SavedViewsScreen(), section: _TabSection.core, group: 'Workflows'),
    _TerminalTab(label: 'Alerts', icon: Icons.notifications_none_outlined, screen: AlertsScreen(), section: _TabSection.core, group: 'Workflows'),
    _TerminalTab(label: 'Compare', icon: Icons.compare_arrows_outlined, screen: CompareScreen(), section: _TabSection.core, group: 'Workflows'),
    _TerminalTab(label: 'Action Center', icon: Icons.bolt_outlined, screen: ActionCenterScreen(), section: _TabSection.core, group: 'Command'),
    _TerminalTab(label: 'Workspace Studio', icon: Icons.grid_on_outlined, screen: WorkspaceStudioScreen(), section: _TabSection.core, group: 'Workflows'),
    _TerminalTab(label: 'Fantasy Terminal', icon: Icons.sports_esports_outlined, screen: FantasyTerminalScreen(), section: _TabSection.core, group: 'Network'),
    _TerminalTab(label: 'Community Hub', icon: Icons.forum_outlined, screen: CommunityHubScreen(), section: _TabSection.core, group: 'Network'),
    _TerminalTab(label: 'Platform Endgame', icon: Icons.alt_route_outlined, screen: PlatformEndgameScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'NBA MVP Completion', icon: Icons.task_alt_outlined, screen: NbaMvpCompletionScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Core MVP Gaps', icon: Icons.track_changes_outlined, screen: CoreMvpGapsScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Player Identity Import', icon: Icons.person_add_alt_1_outlined, screen: PlayerIdentityImportScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Season Command Plan', icon: Icons.calendar_view_month_outlined, screen: SeasonCommandScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Advanced Stat Taxonomy', icon: Icons.stacked_line_chart_outlined, screen: AdvancedStatTaxonomyScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Award Races', icon: Icons.emoji_events_outlined, screen: AwardRacesScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Build Milestones', icon: Icons.flag_outlined, screen: BuildMilestonesScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Release Plan', icon: Icons.rocket_launch_outlined, screen: ReleasePlanScreen(), section: _TabSection.buildLab, group: 'Governance'),
    _TerminalTab(label: 'Product Backlog', icon: Icons.checklist_rtl_outlined, screen: ProductBacklogScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'QA Console', icon: Icons.bug_report_outlined, screen: QaConsoleScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Risk Register', icon: Icons.warning_amber_outlined, screen: RiskRegisterScreen(), section: _TabSection.buildLab, group: 'Governance'),
    _TerminalTab(label: 'Performance Budget', icon: Icons.speed_outlined, screen: PerformanceBudgetScreen(), section: _TabSection.buildLab, group: 'Governance'),
    _TerminalTab(label: 'Accessibility', icon: Icons.accessibility_new_outlined, screen: AccessibilityScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Audit Trail', icon: Icons.manage_history_outlined, screen: AuditTrailScreen(), section: _TabSection.buildLab, group: 'Governance'),
    _TerminalTab(label: 'Export Center', icon: Icons.ios_share_outlined, screen: ExportCenterScreen(), section: _TabSection.buildLab, group: 'Workflows'),
    _TerminalTab(label: 'Integration Plan', icon: Icons.integration_instructions_outlined, screen: IntegrationPlanScreen(), section: _TabSection.buildLab, group: 'Governance'),
    _TerminalTab(label: 'Privacy Controls', icon: Icons.lock_outline, screen: PrivacyControlsScreen(), section: _TabSection.buildLab, group: 'Governance'),
    _TerminalTab(label: 'UI Patterns', icon: Icons.dashboard_customize_outlined, screen: UiPatternsScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Table Templates', icon: Icons.table_chart_outlined, screen: TableTemplatesScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Column Library', icon: Icons.view_column_outlined, screen: ColumnLibraryScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Metric Packages', icon: Icons.analytics_outlined, screen: MetricPackagesScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Keyboard Shortcuts', icon: Icons.keyboard_alt_outlined, screen: KeyboardShortcutsScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Navigation Strategy', icon: Icons.route_outlined, screen: NavigationStrategyScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Module Inventory', icon: Icons.view_module_outlined, screen: ModuleInventoryScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Screen Depth Plan', icon: Icons.layers_outlined, screen: ScreenDepthPlanScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Entity Detail Plan', icon: Icons.article_outlined, screen: EntityDetailPlanScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Personas', icon: Icons.supervised_user_circle_outlined, screen: PersonasScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Workflow Playbooks', icon: Icons.playlist_add_check_circle_outlined, screen: WorkflowPlaybookScreen(), section: _TabSection.buildLab, group: 'Workflows'),
    _TerminalTab(label: 'Saved View Lifecycle', icon: Icons.bookmarks_outlined, screen: SavedViewLifecycleScreen(), section: _TabSection.buildLab, group: 'Workflows'),
    _TerminalTab(label: 'Alert Evaluation', icon: Icons.notification_important_outlined, screen: AlertEvaluationScreen(), section: _TabSection.buildLab, group: 'Workflows'),
    _TerminalTab(label: 'Basketball Ecosystem', icon: Icons.hub_outlined, screen: LeagueEcosystemScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'League Expansion', icon: Icons.public_outlined, screen: LeagueExpansionScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Information Architecture', icon: Icons.account_tree_outlined, screen: InformationArchitectureScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
    _TerminalTab(label: 'Data Model', icon: Icons.data_object_outlined, screen: DataModelScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Entity Graph', icon: Icons.account_tree, screen: EntityGraphScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Field Dictionary', icon: Icons.menu_book_outlined, screen: FieldDictionaryScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Stat Dictionary', icon: Icons.functions_outlined, screen: StatDictionaryScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Glossary', icon: Icons.abc_outlined, screen: GlossaryScreen(), section: _TabSection.buildLab, group: 'Design System'),
    _TerminalTab(label: 'Franchise History', icon: Icons.history_edu_outlined, screen: FranchiseHistoryScreen(), section: _TabSection.buildLab, group: 'Context'),
    _TerminalTab(label: 'Era Context', icon: Icons.timeline_outlined, screen: EraContextScreen(), section: _TabSection.buildLab, group: 'Context'),
    _TerminalTab(label: 'Player Schema', icon: Icons.badge_outlined, screen: PlayerSchemaScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Dataset Registry', icon: Icons.dataset_outlined, screen: DatasetRegistryScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Data Coverage', icon: Icons.fact_check_outlined, screen: DataCoverageScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Data Lineage', icon: Icons.route_outlined, screen: DataLineageScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Source Registry', icon: Icons.source_outlined, screen: SourceRegistryScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Research Sources', icon: Icons.manage_search_outlined, screen: ResearchSourceScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Import Jobs', icon: Icons.cloud_upload_outlined, screen: ImportJobsScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Data Roadmap', icon: Icons.storage_outlined, screen: DataRoadmapScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Data Health', icon: Icons.health_and_safety_outlined, screen: DataHealthScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Quality Controls', icon: Icons.verified_outlined, screen: QualityControlsScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'Source Policy', icon: Icons.policy_outlined, screen: SourcePolicyScreen(), section: _TabSection.buildLab, group: 'Governance'),
    _TerminalTab(label: 'Ingestion Pipeline', icon: Icons.schema_outlined, screen: IngestionPipelineScreen(), section: _TabSection.buildLab, group: 'Data Ops'),
    _TerminalTab(label: 'G League Roadmap', icon: Icons.sports_basketball_outlined, screen: GLeagueRoadmapScreen(), section: _TabSection.buildLab, group: 'Build Lab'),
  ];

  List<String> get navGroups => ['All', ...tabs.map((tab) => tab.group).toSet().toList()..sort()];

  @override
  Widget build(BuildContext context) {
    final selected = tabs[selectedIndex];
    final filteredTabs = tabs.where((tab) {
      final matchesQuery = navQuery.trim().isEmpty || tab.label.toLowerCase().contains(navQuery.trim().toLowerCase()) || tab.group.toLowerCase().contains(navQuery.trim().toLowerCase());
      final matchesGroup = selectedNavGroup == 'All' || tab.group == selectedNavGroup;
      return matchesQuery && matchesGroup;
    }).toList();
    return Scaffold(backgroundColor: const Color(0xFF0B0F14), body: Row(children: [
      Container(width: 306, decoration: const BoxDecoration(color: Color(0xFF111820), border: Border(right: BorderSide(color: Color(0xFF263241)))), child: SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _BrandHeader(), const SizedBox(height: 16), _NavSearch(value: navQuery, onChanged: (value) => setState(() => navQuery = value)), const SizedBox(height: 12), _NavGroupSelector(groups: navGroups, selected: selectedNavGroup, onSelected: (value) => setState(() => selectedNavGroup = value)), const SizedBox(height: 14), _SidebarSectionLabel(label: '${selected.group} • ${selected.section == _TabSection.core ? 'Core Terminal' : 'Build Lab'}'), const SizedBox(height: 8),
        Expanded(child: filteredTabs.isEmpty ? const _EmptyNavState() : ListView.builder(itemCount: filteredTabs.length, itemBuilder: (context, i) {
          final tab = filteredTabs[i];
          final originalIndex = tabs.indexOf(tab);
          final previous = i == 0 ? null : filteredTabs[i - 1];
          final showDivider = previous != null && (tab.group != previous.group || tab.section != previous.section);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (showDivider) ...[const SizedBox(height: 8), const Divider(color: Color(0xFF263241)), const SizedBox(height: 8), _SidebarSectionLabel(label: tab.group), const SizedBox(height: 8)], _NavButton(label: tab.label, icon: tab.icon, group: tab.group, isSelected: selectedIndex == originalIndex, onTap: () => setState(() => selectedIndex = originalIndex))]);
        })),
        const SizedBox(height: 12), _SidebarFooter(tabCount: filteredTabs.length, group: selectedNavGroup),
      ])))),
      Expanded(child: SafeArea(child: Column(children: [_TopBar(title: selected.label, group: selected.group, onSearchTap: () => setState(() => selectedIndex = 1)), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: selected.screen))]))),
    ]));
  }
}

enum _TabSection { core, buildLab }

class _TerminalTab {
  const _TerminalTab({required this.label, required this.icon, required this.screen, required this.section, required this.group});
  final String label;
  final IconData icon;
  final Widget screen;
  final _TabSection section;
  final String group;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF152235), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2B3B52))), child: const Icon(Icons.sports_basketball, color: Color(0xFF8AB4F8))), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sports Terminal', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('NBA Historical Build', overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF8794A5), fontSize: 12))]))]);
}

class _NavSearch extends StatelessWidget {
  const _NavSearch({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(onChanged: onChanged, style: const TextStyle(color: Colors.white, fontSize: 13), cursorColor: Color(0xFF8AB4F8), decoration: InputDecoration(isDense: true, hintText: 'Filter tabs or groups...', hintStyle: const TextStyle(color: Color(0xFF657386)), prefixIcon: const Icon(Icons.search, color: Color(0xFF657386), size: 17), filled: true, fillColor: const Color(0xFF0D1218), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263241))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8AB4F8)))));
}

class _NavGroupSelector extends StatelessWidget {
  const _NavGroupSelector({required this.groups, required this.selected, required this.onSelected});
  final List<String> groups;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(height: 78, child: SingleChildScrollView(child: Wrap(spacing: 7, runSpacing: 7, children: [for (final group in groups) InkWell(borderRadius: BorderRadius.circular(999), onTap: () => onSelected(group), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: selected == group ? const Color(0xFF1B2A3F) : const Color(0xFF0D1218), borderRadius: BorderRadius.circular(999), border: Border.all(color: selected == group ? const Color(0xFF8AB4F8) : const Color(0xFF263241))), child: Text(group, style: TextStyle(color: selected == group ? Colors.white : const Color(0xFF8794A5), fontSize: 11, fontWeight: FontWeight.w800))))])));
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF657386), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1));
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.icon, required this.group, required this.isSelected, required this.onTap});
  final String label;
  final IconData icon;
  final String group;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: isSelected ? const Color(0xFF1B2A3F) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF385A86) : Colors.transparent)), child: Row(children: [Icon(icon, color: isSelected ? const Color(0xFF8AB4F8) : const Color(0xFF8794A5), size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFFB6C0CC), fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)), const SizedBox(height: 2), Text(group, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF657386), fontSize: 10, fontWeight: FontWeight.w700))]))]))));
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.group, required this.onSearchTap});
  final String title;
  final String group;
  final VoidCallback onSearchTap;
  @override
  Widget build(BuildContext context) => Container(height: 72, padding: const EdgeInsets.symmetric(horizontal: 24), decoration: const BoxDecoration(color: Color(0xFF0D1218), border: Border(bottom: BorderSide(color: Color(0xFF263241)))), child: Row(children: [Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(group, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8794A5), fontSize: 12, fontWeight: FontWeight.w700))])), InkWell(borderRadius: BorderRadius.circular(12), onTap: onSearchTap, child: Container(width: 390, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF121A23), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF263241))), child: const Row(children: [Icon(Icons.search, color: Color(0xFF8794A5), size: 18), SizedBox(width: 10), Expanded(child: Text('Command search: entities, actions, workspaces...', overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF8794A5), fontSize: 13)))])))]));
}

class _EmptyNavState extends StatelessWidget {
  const _EmptyNavState();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0D1218), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF263241))), child: const Text('No tabs match this group/search combination.', style: TextStyle(color: Color(0xFF8794A5), fontSize: 12, height: 1.35)));
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.tabCount, required this.group});
  final int tabCount;
  final String group;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0D1218), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF263241))), child: Text('$tabCount tabs shown • $group. Use group chips and tab filter to reduce sidebar clutter while the terminal is still under active buildout.', style: const TextStyle(color: Color(0xFF8794A5), fontSize: 12, height: 1.35)));
}
