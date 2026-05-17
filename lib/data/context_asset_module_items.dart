class ContextAssetModuleItem {
  const ContextAssetModuleItem({required this.module, required this.recordType, required this.keys, required this.firstUse, required this.nextUse, required this.blocker});

  final String module;
  final String recordType;
  final String keys;
  final String firstUse;
  final String nextUse;
  final String blocker;
}

const contextAssetModuleItems = <ContextAssetModuleItem>[
  ContextAssetModuleItem(module: 'Games', recordType: 'Schedule and result rows', keys: 'gameId, seasonId, homeTeamId, awayTeamId', firstUse: 'Season schedule, matchup pages, playoff game links, team trend base.', nextUse: 'Player logs, team box scores, fantasy schedule density, rolling charts.', blocker: 'Approved schedule/result source and game ID policy.'),
  ContextAssetModuleItem(module: 'Rosters', recordType: 'Player-team-season rows', keys: 'playerId, teamId, seasonId, startDate, endDate', firstUse: 'Team roster pages, player team history, role context, eligibility windows.', nextUse: 'Roster construction, two-way movement, G League assignments, fantasy role tracking.', blocker: 'Historical roster source and window rules.'),
  ContextAssetModuleItem(module: 'Awards', recordType: 'Award race rows', keys: 'awardId, seasonId, playerId, teamId, rank', firstUse: 'Award winners, runners-up, finalists, voting points, share, first-place votes.', nextUse: 'Award reports, season race boards, player recognition profiles, compare routes.', blocker: 'Voting source with rank and vote fields.'),
  ContextAssetModuleItem(module: 'Draft', recordType: 'Draft pick rows', keys: 'draftYear, round, pickNumber, teamId, playerId', firstUse: 'Draft class pages, team draft history, player identity joins.', nextUse: 'Outcome boards, franchise value creation, development paths, scouting packets.', blocker: 'Historical draft source and player matching.'),
  ContextAssetModuleItem(module: 'Transactions', recordType: 'Movement event rows', keys: 'transactionId, date, playerId, fromTeamId, toTeamId', firstUse: 'Player movement timelines, team transaction history, roster change explanation.', nextUse: 'Trade trees, contract events, draft-rights movement, front-office reports.', blocker: 'Event source and transaction type taxonomy.'),
];
