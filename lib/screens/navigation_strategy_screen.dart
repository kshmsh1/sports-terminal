import 'package:flutter/material.dart';

import '../data/navigation_strategy_items.dart';
import '../widgets/terminal_primitives.dart';

class NavigationStrategyScreen extends StatelessWidget {
  const NavigationStrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final temporary = navigationStrategyItems.where((item) => item.status == 'Temporary').length;
    final planned = navigationStrategyItems.where((item) => item.status == 'Planned').length;
    final future = navigationStrategyItems.where((item) => item.status == 'Future').length;
    final inProgress = navigationStrategyItems.where((item) => item.status == 'In Progress').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Navigation Strategy', subtitle: 'A UI plan for moving from today’s architecture-heavy sidebar to a cleaner terminal shell with grouped navigation, command search, favorites, action bars, workspaces, and admin-only Build Lab surfaces.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _NavMetric(label: 'Navigation Areas', value: '${navigationStrategyItems.length}', detail: 'UX map'),
          _NavMetric(label: 'In Progress', value: '$inProgress', detail: 'Active shell work'),
          _NavMetric(label: 'Planned', value: '$planned', detail: 'Near-term cleanup'),
          _NavMetric(label: 'Future', value: '$future', detail: '$temporary temporary'),
        ]);
      }),
      const SizedBox(height: 22),
      const _SidebarGroupingPanel(),
      const SizedBox(height: 22),
      const _NavigationEndgamePanel(),
      const SizedBox(height: 22),
      const _NavigationGroupMatrix(),
      const SizedBox(height: 22),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Navigation Evolution Plan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStateProperty.all(terminalPanelDark),
          headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
          columnSpacing: 30,
          columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Area')), DataColumn(label: Text('Status')), DataColumn(label: Text('Current State')), DataColumn(label: Text('Future State'))],
          rows: [for (final item in navigationStrategyItems) DataRow(cells: [
            DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
            DataCell(SizedBox(width: 260, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
            DataCell(InfoPill(label: item.status)),
            DataCell(SizedBox(width: 540, child: Text(item.currentState))),
            DataCell(SizedBox(width: 660, child: Text(item.futureState))),
          ])],
        )),
      ])),
    ]);
  }
}

class _NavGroupSpec { const _NavGroupSpec(this.group, this.status, this.visibleExamples, this.futureState); final String group; final String status; final String visibleExamples; final String futureState; }

const _navGroups = <_NavGroupSpec>[
  _NavGroupSpec('Command', 'Core', 'Dashboard, Search, Action Center', 'Command palette, operating cockpit, and universal actions stay highly visible.'),
  _NavGroupSpec('NBA Core', 'Core', 'Players, Teams, Seasons, Games, Stats, Standings, Playoffs', 'Primary NBA entity and performance pages remain normal-user surfaces.'),
  _NavGroupSpec('Context', 'Core', 'Rosters, Awards, Draft, Transactions, Contracts, Media, Scouting', 'Context modules become adjacent entity tabs and drill-downs rather than scattered pages.'),
  _NavGroupSpec('Workflows', 'Core', 'Reports, Saved Views, Alerts, Compare, Workspace Studio, Export Center', 'Reusable work products become the main reason users return.'),
  _NavGroupSpec('Network', 'Future', 'Fantasy Terminal, Community Hub', 'Keep visible as product direction, but gate real launch behind accounts, permissions, and moderation.'),
  _NavGroupSpec('Data Ops', 'Admin', 'Dataset Registry, Source Registry, Data Coverage, Data Health, QA, Imports, Lineage', 'Move into an operations/admin workspace once users do not need to see internals.'),
  _NavGroupSpec('Build Lab', 'Admin', 'Platform Endgame, MVP Gaps, Release Plan, Product Backlog, Risks', 'Keep as internal product planning and architecture system.'),
  _NavGroupSpec('Design System', 'Admin', 'UI Patterns, Table Templates, Column Library, Metric Packages, Accessibility', 'Become reusable design controls rather than user-facing pages.'),
  _NavGroupSpec('Governance', 'Admin', 'Privacy, Source Policy, Integration Plan, Performance Budget, Audit Trail', 'Move into admin-only governance once product surfaces stabilize.'),
];

class _SidebarGroupingPanel extends StatelessWidget { const _SidebarGroupingPanel(); @override Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Current Sidebar Is Still Temporary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 10), Text('The prototype is intentionally exposing product pages, architecture pages, data operations, trust controls, workflow surfaces, and future platform layers together. The new direction is not to keep adding an endless sidebar forever. The transition plan is grouped navigation first, then command palette, favorites, workspace switcher, context drawer, and eventually admin-only Build Lab surfaces.', style: TextStyle(color: terminalTextSoft, height: 1.45)), SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Group filters now'), InfoPill(label: 'Command palette next'), InfoPill(label: 'Favorites later'), InfoPill(label: 'Build Lab admin'), InfoPill(label: 'Context drawer future')]) ])); }
class _NavigationEndgamePanel extends StatelessWidget { const _NavigationEndgamePanel(); @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Navigation Endgame', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), const Text('The terminal should feel dense without feeling chaotic. Normal users should mostly navigate through Dashboard, Search, entity pages, workspaces, saved views, reports, alerts, fantasy, and community. Internal product/build/data-governance surfaces should stay available, but they should be grouped, searchable, and eventually hidden behind an admin/build mode.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: const [InfoPill(label: 'Dashboard'), InfoPill(label: 'Search'), InfoPill(label: 'Entities'), InfoPill(label: 'Workflows'), InfoPill(label: 'Workspaces'), InfoPill(label: 'Network'), InfoPill(label: 'Admin')]) ])); }
class _NavigationGroupMatrix extends StatelessWidget { const _NavigationGroupMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Navigation Group Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Group')), DataColumn(label: Text('Status')), DataColumn(label: Text('Examples')), DataColumn(label: Text('Future State'))], rows: [for (final item in _navGroups) DataRow(cells: [DataCell(SizedBox(width: 180, child: Text(item.group, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.visibleExamples))), DataCell(SizedBox(width: 660, child: Text(item.futureState)))])]))])); }

class _NavMetric extends StatelessWidget { const _NavMetric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
