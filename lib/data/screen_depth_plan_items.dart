class ScreenDepthPlanItem {
  const ScreenDepthPlanItem({
    required this.screen,
    required this.currentRole,
    required this.futureDepth,
    required this.priority,
    required this.status,
  });

  final String screen;
  final String currentRole;
  final String futureDepth;
  final String priority;
  final String status;
}

const screenDepthPlanItems = <ScreenDepthPlanItem>[
  ScreenDepthPlanItem(
    screen: 'Dashboard',
    currentRole: 'Command overview and source posture.',
    futureDepth: 'Personalized workspace, alerts, saved views, recent datasets, refresh history, data warnings, and key NBA/G League intelligence panels.',
    priority: 'P0',
    status: 'Started',
  ),
  ScreenDepthPlanItem(
    screen: 'Teams',
    currentRole: 'Current NBA team directory.',
    futureDepth: 'Team profiles, franchise history, records, rosters, leaders, playoff history, transactions, draft assets, salary context, affiliates, arenas, ownership, and front office.',
    priority: 'P0',
    status: 'Started',
  ),
  ScreenDepthPlanItem(
    screen: 'Players',
    currentRole: 'Pending player data connection with blank-data policy.',
    futureDepth: 'Player profiles, bios, team history, season logs, advanced stats, awards, injuries, contracts, transactions, draft context, G League assignments, media, and notes.',
    priority: 'P0',
    status: 'Schema ready',
  ),
  ScreenDepthPlanItem(
    screen: 'Seasons',
    currentRole: 'Historical NBA/BAA season catalog.',
    futureDepth: 'Season hubs with standings, leaders, playoffs, champions, awards, transactions, draft class, rule context, statistical environment, and era overlays.',
    priority: 'P0',
    status: 'Started',
  ),
  ScreenDepthPlanItem(
    screen: 'Data Model',
    currentRole: 'Object/domain model map.',
    futureDepth: 'Schema browser, entity relationships, field definitions, null rules, validation rules, source bindings, and migration readiness.',
    priority: 'P0',
    status: 'Started',
  ),
  ScreenDepthPlanItem(
    screen: 'Information Architecture',
    currentRole: 'Coverage map beyond simple stats.',
    futureDepth: 'Full product ontology covering sports, leagues, teams, players, games, financials, media, research, documents, and user workflows.',
    priority: 'P0',
    status: 'Started',
  ),
  ScreenDepthPlanItem(
    screen: 'Ingestion Pipeline',
    currentRole: 'Source-to-app data flow.',
    futureDepth: 'Script status, source registry, import jobs, raw/normalized file map, validation failures, refresh cadence, and API migration plan.',
    priority: 'P1',
    status: 'Started',
  ),
  ScreenDepthPlanItem(
    screen: 'Quality Controls',
    currentRole: 'Validation and governance checklist.',
    futureDepth: 'Automated QC results, source completeness, broken joins, duplicate detection, impossible values, historical alias mapping, and manual override logs.',
    priority: 'P1',
    status: 'Started',
  ),
  ScreenDepthPlanItem(
    screen: 'G League Roadmap',
    currentRole: 'Future development-league strategy.',
    futureDepth: 'Affiliate directory, assignment history, call-ups, two-way players, prospect profiles, G League stats, development outcomes, and NBA transition paths.',
    priority: 'P2',
    status: 'Planned',
  ),
  ScreenDepthPlanItem(
    screen: 'Compare',
    currentRole: 'Pending comparison shell.',
    futureDepth: 'Player, team, franchise, season, era, draft class, playoff series, contract, and roster-composition comparisons with configurable fields.',
    priority: 'P3',
    status: 'Shell started',
  ),
];
