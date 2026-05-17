class SearchRouteIntentItem {
  const SearchRouteIntentItem({required this.intent, required this.status, required this.target, required this.inputObjects, required this.output});

  final String intent;
  final String status;
  final String target;
  final String inputObjects;
  final String output;
}

const searchRouteIntentItems = <SearchRouteIntentItem>[
  SearchRouteIntentItem(intent: 'Open Object', status: 'First', target: 'Entity pages', inputObjects: 'team, player, season, game, award, draft pick, transaction', output: 'Open a detail page or selected-detail panel.'),
  SearchRouteIntentItem(intent: 'Create Workspace', status: 'Planned', target: 'Workspace Studio', inputObjects: 'dataset, entity, selected rows, saved view', output: 'Workspace table with columns, filters, joins, formulas, source snapshot.'),
  SearchRouteIntentItem(intent: 'Compare', status: 'Planned', target: 'Compare', inputObjects: 'players, teams, seasons, games, saved views, stat rows', output: 'Comparison template with entity slots and metric package.'),
  SearchRouteIntentItem(intent: 'Generate Report', status: 'Planned', target: 'Reports', inputObjects: 'player, team, season, award race, draft class, transaction set', output: 'Report shell with structured blocks and source notes.'),
  SearchRouteIntentItem(intent: 'Save View', status: 'Planned', target: 'Saved Views', inputObjects: 'current filters, result set, workspace state, stat table', output: 'Reusable view state with route intent and source snapshot.'),
  SearchRouteIntentItem(intent: 'Create Alert', status: 'Future', target: 'Alerts', inputObjects: 'saved view, stat threshold, source status, roster event', output: 'Monitoring rule for source changes or sports-object movement.'),
  SearchRouteIntentItem(intent: 'Export', status: 'Planned', target: 'Export Center', inputObjects: 'table, report, selected rows, saved view', output: 'Export package with missing-data flags and rights notes.'),
  SearchRouteIntentItem(intent: 'Audit Source', status: 'Planned', target: 'Source Registry', inputObjects: 'source-backed row, dataset, report block, imported asset', output: 'Provenance view with source, lineage, validation, and as-of state.'),
  SearchRouteIntentItem(intent: 'Send to Fantasy', status: 'Future', target: 'Fantasy Terminal', inputObjects: 'player, team, schedule, stat row, saved view', output: 'Fantasy board, watchlist, matchup lab, waiver or trade context.'),
  SearchRouteIntentItem(intent: 'Publish or Discuss', status: 'Future', target: 'Community Hub', inputObjects: 'report, chart, workspace snapshot, entity, debate topic', output: 'Entity-linked post, room, creator object, or discussion thread.'),
];
