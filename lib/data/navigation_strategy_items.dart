class NavigationStrategyItem {
  const NavigationStrategyItem({
    required this.area,
    required this.currentState,
    required this.futureState,
    required this.priority,
    required this.status,
  });

  final String area;
  final String currentState;
  final String futureState;
  final String priority;
  final String status;
}

const navigationStrategyItems = <NavigationStrategyItem>[
  NavigationStrategyItem(area: 'Main user navigation', currentState: 'Large flat sidebar with product and architecture tabs exposed together.', futureState: 'Lean grouped terminal navigation focused on Dashboard, Search, NBA entities, workflows, workspaces, fantasy, community, and selected user-owned outputs.', priority: 'P0', status: 'Temporary'),
  NavigationStrategyItem(area: 'Sidebar group filter', currentState: 'Users can filter by tab name, but every tab is still visible by default.', futureState: 'Add group filters for Command, NBA Core, Workflows, Network, Data Ops, Build Lab, Design, and Governance so the long sidebar is easier to scan while buildout continues.', priority: 'P0', status: 'In Progress'),
  NavigationStrategyItem(area: 'Build Lab / Admin area', currentState: 'Architecture, schema, roadmap, policy, quality controls, and ingestion pages appear in the main sidebar.', futureState: 'Move architecture and governance pages into a dedicated Build Lab or Admin section that can be hidden from normal users once the MVP stabilizes.', priority: 'P0', status: 'Planned'),
  NavigationStrategyItem(area: 'Command-first search', currentState: 'Search is becoming an indexed command cockpit across assets, actions, routes, workflows, and operations.', futureState: 'Make Search the primary command palette: open objects, route actions, create workspaces, generate reports, audit sources, and explain unavailable actions.', priority: 'P0', status: 'In Progress'),
  NavigationStrategyItem(area: 'Top bar command affordance', currentState: 'The top search affordance jumps to Search.', futureState: 'Top bar should eventually become a keyboard-first command launcher with current-context actions.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Favorites and pinned surfaces', currentState: 'No user-specific favorites exist yet.', futureState: 'Users should pin frequently used tabs, saved views, workspaces, fantasy boards, alerts, reports, and source monitors to a compact favorites rail.', priority: 'P2', status: 'Future'),
  NavigationStrategyItem(area: 'Workspace switcher', currentState: 'Workspace Studio and Saved Views are separate pages.', futureState: 'Add a workspace switcher for active tables, reports, comparisons, saved views, fantasy boards, and source-audit workspaces.', priority: 'P2', status: 'Future'),
  NavigationStrategyItem(area: 'Entity pages', currentState: 'Teams and seasons are directory-style screens; players are source-pending.', futureState: 'Each entity should support profile pages, related records, historical tables, action bars, source metadata, and drill-down navigation.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Entity action bars', currentState: 'Actions are centralized in Action Center but not yet present across entity pages.', futureState: 'Player, team, season, game, award, draft, transaction, roster, and contract pages should expose compare, workspace, report, save view, alert, export, and source audit actions.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Table action bars', currentState: 'Tables are mostly read-only display surfaces.', futureState: 'All major tables should support selected rows, bulk actions, add to workspace, compare, report, export, save view, and cell-level source audit.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Context drawer', currentState: 'Selected detail panels vary by screen.', futureState: 'A reusable right-side context drawer should show selected object details, source status, action routes, related entities, and recent changes.', priority: 'P2', status: 'Future'),
  NavigationStrategyItem(area: 'Dashboard as operating cockpit', currentState: 'Dashboard summarizes data coverage, operations, workflow items, and operating layers.', futureState: 'Dashboard should become the default operating view with pinned saved views, alert cards, import monitors, recent reports, and data-health status.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Data operations grouping', currentState: 'Source Registry, Data Coverage, Data Health, QA, Imports, Lineage, and Source Policy are separate Build Lab entries.', futureState: 'Group source and data operations under a single operations workspace with nested tabs and shared filters.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Design and governance grouping', currentState: 'UI, accessibility, performance, privacy, risk, release, and integration surfaces appear separately.', futureState: 'Group design and governance pages into admin-only planning workspaces.', priority: 'P2', status: 'Future'),
  NavigationStrategyItem(area: 'Network surfaces', currentState: 'Fantasy Terminal and Community Hub are visible product cockpits with future-state models.', futureState: 'Network surfaces should remain gated behind identity, permissions, moderation, league state, and source-aware embedded objects.', priority: 'P3', status: 'Future'),
  NavigationStrategyItem(area: 'Export and report outputs', currentState: 'Reports and Export Center now have builder-stage models and route-aware output plans.', futureState: 'Generated outputs should be reachable from Dashboard, Search, Action Center, Workspace Studio, Compare, Saved Views, and entity action bars.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Keyboard shortcuts', currentState: 'Keyboard shortcuts exist as a Build Lab planning surface.', futureState: 'Add command palette shortcuts, tab switching, workspace actions, saved-view actions, and table navigation shortcuts.', priority: 'P2', status: 'Future'),
  NavigationStrategyItem(area: 'Progressive disclosure', currentState: 'Many screens expose architecture details because the prototype is still being designed.', futureState: 'Normal users should see useful product controls first, while advanced architecture tables remain hidden behind drill-downs or admin mode.', priority: 'P1', status: 'Planned'),
  NavigationStrategyItem(area: 'Responsive layout', currentState: 'Desktop web layout is the priority.', futureState: 'Desktop terminal first, then tablet-friendly views, mobile summaries, and future desktop app packaging.', priority: 'P3', status: 'Future'),
  NavigationStrategyItem(area: 'Future sport expansion', currentState: 'NBA-first navigation is still mixed with future architecture planning.', futureState: 'Future sports should reuse command, action, workspace, report, export, saved view, alert, source, and community navigation patterns without crowding the NBA MVP.', priority: 'P3', status: 'Future'),
];
