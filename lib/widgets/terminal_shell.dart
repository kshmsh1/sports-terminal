import 'package:flutter/material.dart';

import '../screens/accessibility_screen.dart';
import '../screens/alert_evaluation_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/audit_trail_screen.dart';
import '../screens/build_milestones_screen.dart';
import '../screens/column_library_screen.dart';
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

class TerminalShell extends StatefulWidget {
  const TerminalShell({super.key});

  @override
  State<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends State<TerminalShell> {
  int selectedIndex = 0;
  String navQuery = '';

  final tabs = const [
    _TerminalTab(label: 'Dashboard', icon: Icons.dashboard_outlined, screen: DashboardScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Search', icon: Icons.search, screen: SearchScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Players', icon: Icons.person_search_outlined, screen: PlayersScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Teams', icon: Icons.groups_outlined, screen: TeamsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Seasons', icon: Icons.calendar_month_outlined, screen: SeasonsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Stats', icon: Icons.query_stats_outlined, screen: StatsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Standings', icon: Icons.leaderboard_outlined, screen: StandingsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Playoffs', icon: Icons.military_tech_outlined, screen: PlayoffsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Games', icon: Icons.sports_basketball_outlined, screen: GamesScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Rosters', icon: Icons.assignment_ind_outlined, screen: RostersScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Awards', icon: Icons.emoji_events_outlined, screen: AwardsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Draft', icon: Icons.school_outlined, screen: DraftScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Transactions', icon: Icons.swap_horiz_outlined, screen: TransactionsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Contracts', icon: Icons.paid_outlined, screen: ContractsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Media & Research', icon: Icons.library_books_outlined, screen: MediaResearchScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Scouting', icon: Icons.manage_search_outlined, screen: ScoutingScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Reports', icon: Icons.article_outlined, screen: ReportsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Saved Views', icon: Icons.bookmark_border_outlined, screen: SavedViewsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Alerts', icon: Icons.notifications_none_outlined, screen: AlertsScreen(), section: _TabSection.core),
    _TerminalTab(label: 'Compare', icon: Icons.compare_arrows_outlined, screen: CompareScreen(), section: _TabSection.core),
    _TerminalTab(label: 'NBA MVP Completion', icon: Icons.task_alt_outlined, screen: NbaMvpCompletionScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Core MVP Gaps', icon: Icons.track_changes_outlined, screen: CoreMvpGapsScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Player Identity Import', icon: Icons.person_add_alt_1_outlined, screen: PlayerIdentityImportScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Season Command Plan', icon: Icons.calendar_view_month_outlined, screen: SeasonCommandScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Build Milestones', icon: Icons.flag_outlined, screen: BuildMilestonesScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Release Plan', icon: Icons.rocket_launch_outlined, screen: ReleasePlanScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Product Backlog', icon: Icons.checklist_rtl_outlined, screen: ProductBacklogScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'QA Console', icon: Icons.bug_report_outlined, screen: QaConsoleScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Risk Register', icon: Icons.warning_amber_outlined, screen: RiskRegisterScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Performance Budget', icon: Icons.speed_outlined, screen: PerformanceBudgetScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Accessibility', icon: Icons.accessibility_new_outlined, screen: AccessibilityScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Audit Trail', icon: Icons.manage_history_outlined, screen: AuditTrailScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Export Center', icon: Icons.ios_share_outlined, screen: ExportCenterScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Integration Plan', icon: Icons.integration_instructions_outlined, screen: IntegrationPlanScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Privacy Controls', icon: Icons.lock_outline, screen: PrivacyControlsScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'UI Patterns', icon: Icons.dashboard_customize_outlined, screen: UiPatternsScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Table Templates', icon: Icons.table_chart_outlined, screen: TableTemplatesScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Column Library', icon: Icons.view_column_outlined, screen: ColumnLibraryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Metric Packages', icon: Icons.analytics_outlined, screen: MetricPackagesScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Keyboard Shortcuts', icon: Icons.keyboard_alt_outlined, screen: KeyboardShortcutsScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Navigation Strategy', icon: Icons.route_outlined, screen: NavigationStrategyScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Module Inventory', icon: Icons.view_module_outlined, screen: ModuleInventoryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Screen Depth Plan', icon: Icons.layers_outlined, screen: ScreenDepthPlanScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Entity Detail Plan', icon: Icons.article_outlined, screen: EntityDetailPlanScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Personas', icon: Icons.supervised_user_circle_outlined, screen: PersonasScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Workflow Playbooks', icon: Icons.playlist_add_check_circle_outlined, screen: WorkflowPlaybookScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Saved View Lifecycle', icon: Icons.bookmarks_outlined, screen: SavedViewLifecycleScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Alert Evaluation', icon: Icons.notification_important_outlined, screen: AlertEvaluationScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Basketball Ecosystem', icon: Icons.hub_outlined, screen: LeagueEcosystemScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'League Expansion', icon: Icons.public_outlined, screen: LeagueExpansionScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Information Architecture', icon: Icons.account_tree_outlined, screen: InformationArchitectureScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Data Model', icon: Icons.data_object_outlined, screen: DataModelScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Entity Graph', icon: Icons.account_tree, screen: EntityGraphScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Field Dictionary', icon: Icons.menu_book_outlined, screen: FieldDictionaryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Stat Dictionary', icon: Icons.functions_outlined, screen: StatDictionaryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Glossary', icon: Icons.abc_outlined, screen: GlossaryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Franchise History', icon: Icons.history_edu_outlined, screen: FranchiseHistoryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Era Context', icon: Icons.timeline_outlined, screen: EraContextScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Player Schema', icon: Icons.badge_outlined, screen: PlayerSchemaScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Dataset Registry', icon: Icons.dataset_outlined, screen: DatasetRegistryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Data Coverage', icon: Icons.fact_check_outlined, screen: DataCoverageScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Data Lineage', icon: Icons.route_outlined, screen: DataLineageScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Source Registry', icon: Icons.source_outlined, screen: SourceRegistryScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Research Sources', icon: Icons.manage_search_outlined, screen: ResearchSourceScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Import Jobs', icon: Icons.cloud_upload_outlined, screen: ImportJobsScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Data Roadmap', icon: Icons.storage_outlined, screen: DataRoadmapScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Data Health', icon: Icons.health_and_safety_outlined, screen: DataHealthScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Quality Controls', icon: Icons.verified_outlined, screen: QualityControlsScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Source Policy', icon: Icons.policy_outlined, screen: SourcePolicyScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'Ingestion Pipeline', icon: Icons.schema_outlined, screen: IngestionPipelineScreen(), section: _TabSection.buildLab),
    _TerminalTab(label: 'G League Roadmap', icon: Icons.sports_basketball_outlined, screen: GLeagueRoadmapScreen(), section: _TabSection.buildLab),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = tabs[selectedIndex];
    final filteredTabs = tabs.where((tab) => navQuery.trim().isEmpty || tab.label.toLowerCase().contains(navQuery.trim().toLowerCase())).toList();
    return Scaffold(backgroundColor: const Color(0xFF0B0F14), body: Row(children: [
      Container(width: 286, decoration: const BoxDecoration(color: Color(0xFF111820), border: Border(right: BorderSide(color: Color(0xFF263241)))), child: SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _BrandHeader(), const SizedBox(height: 16), _NavSearch(value: navQuery, onChanged: (value) => setState(() => navQuery = value)), const SizedBox(height: 14), _SidebarSectionLabel(label: selected.section == _TabSection.core ? 'Core Terminal' : 'Build Lab'), const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: filteredTabs.length, itemBuilder: (context, i) {
          final tab = filteredTabs[i];
          final originalIndex = tabs.indexOf(tab);
          final previous = i == 0 ? null : filteredTabs[i - 1];
          final showDivider = previous != null && tab.section != previous.section;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (showDivider) ...[const SizedBox(height: 8), const Divider(color: Color(0xFF263241)), const SizedBox(height: 8), const _SidebarSectionLabel(label: 'Build Lab'), const SizedBox(height: 8)], _NavButton(label: tab.label, icon: tab.icon, isSelected: selectedIndex == originalIndex, onTap: () => setState(() => selectedIndex = originalIndex))]);
        })),
        const SizedBox(height: 12), const _SidebarFooter(),
      ])))),
      Expanded(child: SafeArea(child: Column(children: [_TopBar(title: selected.label, onSearchTap: () => setState(() => selectedIndex = 1)), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: selected.screen))]))),
    ]));
  }
}

enum _TabSection { core, buildLab }

class _TerminalTab {
  const _TerminalTab({required this.label, required this.icon, required this.screen, required this.section});
  final String label;
  final IconData icon;
  final Widget screen;
  final _TabSection section;
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
  Widget build(BuildContext context) => TextField(onChanged: onChanged, style: const TextStyle(color: Colors.white, fontSize: 13), cursorColor: Color(0xFF8AB4F8), decoration: InputDecoration(isDense: true, hintText: 'Filter tabs...', hintStyle: const TextStyle(color: Color(0xFF657386)), prefixIcon: const Icon(Icons.search, color: Color(0xFF657386), size: 17), filled: true, fillColor: const Color(0xFF0D1218), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263241))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8AB4F8)))));
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF657386), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1));
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.icon, required this.isSelected, required this.onTap});
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: isSelected ? const Color(0xFF1B2A3F) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF385A86) : Colors.transparent)), child: Row(children: [Icon(icon, color: isSelected ? const Color(0xFF8AB4F8) : const Color(0xFF8794A5), size: 20), const SizedBox(width: 12), Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFFB6C0CC), fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)))]))));
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onSearchTap});
  final String title;
  final VoidCallback onSearchTap;
  @override
  Widget build(BuildContext context) => Container(height: 72, padding: const EdgeInsets.symmetric(horizontal: 24), decoration: const BoxDecoration(color: Color(0xFF0D1218), border: Border(bottom: BorderSide(color: Color(0xFF263241)))), child: Row(children: [Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))), InkWell(borderRadius: BorderRadius.circular(12), onTap: onSearchTap, child: Container(width: 360, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF121A23), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF263241))), child: const Row(children: [Icon(Icons.search, color: Color(0xFF8794A5), size: 18), SizedBox(width: 10), Expanded(child: Text('Search players, teams, seasons, reports...', overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF8794A5), fontSize: 13)))])))]));
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0D1218), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF263241))), child: const Text('Use tab filter to jump quickly. Core tabs are product surfaces; Build Lab is internal architecture.', style: TextStyle(color: Color(0xFF8794A5), fontSize: 12, height: 1.35)));
}
