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
  NavigationStrategyItem(
    area: 'Main user navigation',
    currentState: 'Large flat sidebar with product and architecture tabs exposed together.',
    futureState: 'Lean terminal navigation focused on Dashboard, Search, Players, Teams, Seasons, Games, Reports, Compare, and Settings.',
    priority: 'P0',
    status: 'Temporary',
  ),
  NavigationStrategyItem(
    area: 'Build Lab / Admin area',
    currentState: 'Architecture, schema, roadmap, policy, quality controls, and ingestion pages appear in the main sidebar.',
    futureState: 'Move architecture and governance pages into a dedicated Build Lab or Admin section that can be hidden from normal users.',
    priority: 'P0',
    status: 'Planned',
  ),
  NavigationStrategyItem(
    area: 'Entity pages',
    currentState: 'Teams and seasons are directory-style screens; players are source-pending.',
    futureState: 'Each entity should support profile pages, related records, historical tables, source metadata, and drill-down navigation.',
    priority: 'P1',
    status: 'Planned',
  ),
  NavigationStrategyItem(
    area: 'Search and command palette',
    currentState: 'Search bar is visual only.',
    futureState: 'A command-palette-style search should jump to players, teams, seasons, datasets, reports, saved views, and admin pages.',
    priority: 'P1',
    status: 'Future',
  ),
  NavigationStrategyItem(
    area: 'Saved workspaces',
    currentState: 'No saved user views yet.',
    futureState: 'Saved screens for scouting, fantasy, front-office style analysis, historical research, team reports, and player comparisons.',
    priority: 'P3',
    status: 'Future',
  ),
  NavigationStrategyItem(
    area: 'Responsive layout',
    currentState: 'Desktop web layout is the priority.',
    futureState: 'Desktop terminal first, then tablet-friendly views, mobile summaries, and future desktop app packaging.',
    priority: 'P3',
    status: 'Future',
  ),
];
