class ComparisonOutputRouteItem {
  const ComparisonOutputRouteItem({required this.route, required this.status, required this.target, required this.payload, required this.use});

  final String route;
  final String status;
  final String target;
  final String payload;
  final String use;
}

const comparisonOutputRouteItems = <ComparisonOutputRouteItem>[
  ComparisonOutputRouteItem(route: 'Workspace', status: 'Planned', target: 'Workspace Studio', payload: 'entity slots, metric package, selected rows, source snapshot, delta fields', use: 'Turn a comparison into an editable table with formulas, filters, joins, and notes.'),
  ComparisonOutputRouteItem(route: 'Report', status: 'Planned', target: 'Reports', payload: 'comparison title, entities, deltas, source notes, chart blocks, narrative prompts', use: 'Generate player, team, season, award, draft, fantasy, or scouting comparison sections.'),
  ComparisonOutputRouteItem(route: 'Saved View', status: 'Planned', target: 'Saved Views', payload: 'template ID, entities, filters, columns, metric package, source snapshot', use: 'Persist a reusable comparison board that can later power alerts and dashboard pins.'),
  ComparisonOutputRouteItem(route: 'Export', status: 'Planned', target: 'Export Center', payload: 'comparison table, selected columns, missing-data flags, rights posture', use: 'Export comparison outputs with source and null-policy notes.'),
  ComparisonOutputRouteItem(route: 'Alert', status: 'Future', target: 'Alerts', payload: 'saved comparison, metric threshold, rank movement, source update rule', use: 'Monitor when a comparison meaningfully changes after new rows are imported.'),
  ComparisonOutputRouteItem(route: 'Fantasy', status: 'Future', target: 'Fantasy Terminal', payload: 'players, scoring rules, schedule context, role signals, projection assumptions', use: 'Compare fantasy players, trade packages, waiver targets, and matchup choices.'),
  ComparisonOutputRouteItem(route: 'Scouting', status: 'Future', target: 'Scouting', payload: 'player profiles, stats, media notes, evidence tags, qualitative grades', use: 'Compare prospects or NBA players with statistical and qualitative context.'),
  ComparisonOutputRouteItem(route: 'Community', status: 'Future', target: 'Community Hub', payload: 'snapshot, audience, permissions, moderation state, embedded table', use: 'Publish comparison boards into posts, debates, private rooms, and creator analysis later.'),
];
