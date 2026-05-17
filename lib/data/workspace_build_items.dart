class WorkspaceBuildItem {
  const WorkspaceBuildItem({
    required this.area,
    required this.priority,
    required this.status,
    required this.description,
    required this.firstDataNeed,
  });

  final String area;
  final String priority;
  final String status;
  final String description;
  final String firstDataNeed;
}

const gameWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Game records', priority: 'P1', status: 'Payload contract ready, schedule source pending', description: 'Game identity, date, season, season type, teams, scores, location, status, playoff linkage, and source metadata.', firstDataNeed: 'Historical schedule and result snapshots.'),
  WorkspaceBuildItem(area: 'Schedule normalization', priority: 'P1', status: 'Normalization contract ready', description: 'Normalize date, arena, city, home team, away team, neutral site later, postponed status later, and season type.', firstDataNeed: 'Approved schedule source and team/season joins.'),
  WorkspaceBuildItem(area: 'Result state', priority: 'P1', status: 'Contract ready, data pending', description: 'Track final score, status, overtime flags, winner, margin, and source-as-of state without inventing unresolved scores.', firstDataNeed: 'Schedule/results source with final status fields.'),
  WorkspaceBuildItem(area: 'Team box scores', priority: 'P2', status: 'Payload contract ready, box-score source pending', description: 'Team-level production for each game, including points, pace, efficiency, possessions, shooting splits, turnovers, rebounds, assists, and PF.', firstDataNeed: 'Official or licensed box-score source.'),
  WorkspaceBuildItem(area: 'Player box scores', priority: 'P2', status: 'Payload contract ready, game-log source pending', description: 'Player-level game production with minutes, usage, shooting, counting stats, personal fouls, turnovers, and availability context.', firstDataNeed: 'Historical player game-log data.'),
  WorkspaceBuildItem(area: 'Playoff linkage', priority: 'P2', status: 'Join contract ready, playoff data pending', description: 'Series-level matchup context, seeds, round, home-court status, game number, game-by-game results, and advancement.', firstDataNeed: 'Playoff bracket and series records.'),
  WorkspaceBuildItem(area: 'Matchup context', priority: 'P2', status: 'Contract ready, data pending', description: 'Team form, rest, schedule density, home/away context, rivalry notes, standings position, and roster availability later.', firstDataNeed: 'Game records plus team stats and roster windows.'),
  WorkspaceBuildItem(area: 'Trend chart hooks', priority: 'P3', status: 'Chart contract ready, data pending', description: 'Game rows should support player and team game-by-game charts, rolling averages, and selected metric overlays.', firstDataNeed: 'Game logs, team box scores, player box scores.'),
  WorkspaceBuildItem(area: 'Fantasy matchup hooks', priority: 'P3', status: 'Contract ready, future product', description: 'Game schedules should power fantasy matchup density, back-to-backs, opponent quality, and start/sit context.', firstDataNeed: 'Games plus fantasy scoring and roster state.'),
  WorkspaceBuildItem(area: 'Game report route', priority: 'P2', status: 'Payload contract ready', description: 'Selected game rows can become matchup reports, box-score packets later, playoff game notes, and source audit appendices.', firstDataNeed: 'Game records plus report builder payload state.'),
  WorkspaceBuildItem(area: 'Game export route', priority: 'P2', status: 'Payload contract ready', description: 'Game schedules, result boards, and matchup tables can flow into Export Center with source notes and selected columns.', firstDataNeed: 'Game table state and source snapshot.'),
];

const rosterWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Team-season rosters', priority: 'P1', status: 'Payload contract ready, roster source pending', description: 'Player-to-team-to-season relationships with position, jersey number, roster status, source ID, and as-of state.', firstDataNeed: 'Historical roster snapshots by team and season.'),
  WorkspaceBuildItem(area: 'Active windows', priority: 'P2', status: 'Window contract ready', description: 'Dates when players were active, inactive, assigned, recalled, signed, waived, or traded.', firstDataNeed: 'Transaction and roster status history.'),
  WorkspaceBuildItem(area: 'Two-way players', priority: 'P2', status: 'Contract ready, source-gated', description: 'Two-way contract status and NBA/G League movement.', firstDataNeed: 'Contract and assignment source.'),
  WorkspaceBuildItem(area: 'Roster role context', priority: 'P2', status: 'Contract ready, player stat data pending', description: 'Position, role, minutes band later, starter/bench label later, and eligibility context for player/team pages.', firstDataNeed: 'Roster rows plus player stats and game logs.'),
  WorkspaceBuildItem(area: 'Roster construction', priority: 'P2', status: 'Join contract ready, transaction/draft data pending', description: 'How each team-season roster was built across draft, trades, signings, two-way movement, and development pathways.', firstDataNeed: 'Rosters plus draft and transaction rows.'),
  WorkspaceBuildItem(area: 'Game eligibility', priority: 'P3', status: 'Join contract ready, game data pending', description: 'Connect roster windows to individual games, availability, injuries later, player logs, and fantasy decisions.', firstDataNeed: 'Game records plus roster windows.'),
  WorkspaceBuildItem(area: 'Lineup context', priority: 'P4', status: 'Contract ready, future data', description: 'Player combinations, minutes overlap, lineup performance, and role changes.', firstDataNeed: 'Lineup or play-by-play data.'),
  WorkspaceBuildItem(area: 'Roster report route', priority: 'P2', status: 'Payload contract ready', description: 'Roster boards can become team-season roster reports, player availability packets, and roster-construction sections.', firstDataNeed: 'Roster rows, team rows, player identity, and source snapshot.'),
  WorkspaceBuildItem(area: 'Roster alert route', priority: 'P2', status: 'Contract ready, evaluator pending', description: 'Roster windows can trigger movement, eligibility, assignment, recall, and source-change alerts.', firstDataNeed: 'Roster rows plus alert evaluator.'),
];

const awardWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Major awards', priority: 'P1', status: 'Payload contract ready, award source pending', description: 'MVP, Finals MVP, Rookie of the Year, Defensive Player of the Year, Sixth Man, Most Improved, and Coach of the Year.', firstDataNeed: 'Historical award winner list.'),
  WorkspaceBuildItem(area: 'All-NBA and All-Defense', priority: 'P1', status: 'Payload contract ready, ballot source pending', description: 'Team selections, positions, vote totals, and season-level recognition.', firstDataNeed: 'Historical team selections and voting records.'),
  WorkspaceBuildItem(area: 'All-Star context', priority: 'P2', status: 'Contract ready, source pending', description: 'All-Star selections, starters, reserves, replacements, captains, and game participation.', firstDataNeed: 'Historical All-Star data.'),
  WorkspaceBuildItem(area: 'Voting shares', priority: 'P2', status: 'Voting contract ready', description: 'Vote shares, ranks, points, first-place votes, and voting body context.', firstDataNeed: 'Detailed voting tables.'),
  WorkspaceBuildItem(area: 'Award race boards', priority: 'P2', status: 'Payload contract ready, race data pending', description: 'Season-by-season race pages showing winner, runners-up, finalists, voting ranks, points, and team context.', firstDataNeed: 'Award voting records with player and team IDs.'),
  WorkspaceBuildItem(area: 'Award case context', priority: 'P2', status: 'Join contract ready, stat/standings data pending', description: 'Connect player stats, games played, standings, team record, playoffs, and prior awards to each race.', firstDataNeed: 'Awards plus player stats and standings.'),
  WorkspaceBuildItem(area: 'Report-ready award packets', priority: 'P3', status: 'Payload contract ready', description: 'Generate award race reports and debate-ready comparison boards with source notes.', firstDataNeed: 'Award race rows plus report builder input.'),
  WorkspaceBuildItem(area: 'Award compare route', priority: 'P2', status: 'Payload contract ready', description: 'Compare award candidates by vote fields, player stat context, team record, season type, and source status.', firstDataNeed: 'Award race rows plus stats and standings.'),
  WorkspaceBuildItem(area: 'Award export route', priority: 'P2', status: 'Payload contract ready', description: 'Export voting boards, winner tables, race histories, and source audit appendices.', firstDataNeed: 'Award table state and source snapshot.'),
];

const draftWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Draft picks', priority: 'P1', status: 'Payload contract ready, draft source pending', description: 'Draft year, round, pick number, team, player, school or club, country, and source metadata.', firstDataNeed: 'Historical NBA draft records.'),
  WorkspaceBuildItem(area: 'Draft classes', priority: 'P2', status: 'Payload contract ready, player identity pending', description: 'Class-level summaries, lottery context, pick distributions, outcomes, and team-level draft histories.', firstDataNeed: 'Draft pick records plus player identity links.'),
  WorkspaceBuildItem(area: 'Player identity joins', priority: 'P1', status: 'Join contract ready, player identity pending', description: 'Connect each pick to a stable player profile, career rows, awards, rosters, and transactions.', firstDataNeed: 'Player profiles plus draft pick IDs.'),
  WorkspaceBuildItem(area: 'Team draft history', priority: 'P2', status: 'Payload contract ready, draft data pending', description: 'Franchise draft boards by year, pick range, player outcome, retained value, and team-building context.', firstDataNeed: 'Draft picks plus team and franchise history.'),
  WorkspaceBuildItem(area: 'Prospect context', priority: 'P3', status: 'Contract ready, future data', description: 'College, international, G League, Ignite, combine, and pre-draft pathway context.', firstDataNeed: 'Prospect and combine sources.'),
  WorkspaceBuildItem(area: 'Draft rights and trades', priority: 'P4', status: 'Contract ready, transaction data pending', description: 'Pick trades, draft rights, swaps, protections, and transaction context.', firstDataNeed: 'Transaction and cap/legal source.'),
  WorkspaceBuildItem(area: 'Outcome model hooks', priority: 'P3', status: 'Formula contract ready, outcome data pending', description: 'Connect draft picks to award outcomes, career production, playoff impact, roster tenure, and fantasy relevance.', firstDataNeed: 'Draft rows plus player stats and awards.'),
  WorkspaceBuildItem(area: 'Draft report route', priority: 'P2', status: 'Payload contract ready', description: 'Draft classes and team draft histories can generate class reports, team-building reports, and prospect outcome packets.', firstDataNeed: 'Draft rows plus player/team joins.'),
  WorkspaceBuildItem(area: 'Draft workspace route', priority: 'P2', status: 'Payload contract ready', description: 'Draft boards can flow into Workspace Studio for custom ranking, outcome formulas, and team draft-history filters.', firstDataNeed: 'Draft table state and source snapshot.'),
];

const transactionWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Trades', priority: 'P1', status: 'Payload contract ready, transaction source pending', description: 'Player movement between teams, dates, descriptions, and future asset context.', firstDataNeed: 'Historical transaction logs.'),
  WorkspaceBuildItem(area: 'Signings and waivers', priority: 'P2', status: 'Event contract ready, source pending', description: 'Free-agent signings, waivers, releases, hardship deals, ten-days, and roster conversions.', firstDataNeed: 'Transaction source with event type detail.'),
  WorkspaceBuildItem(area: 'Assignments and recalls', priority: 'P2', status: 'Event contract ready, future data', description: 'NBA/G League movement through assignments, recalls, and two-way player activity.', firstDataNeed: 'G League and NBA assignment source.'),
  WorkspaceBuildItem(area: 'Roster effects', priority: 'P2', status: 'Join contract ready, roster data pending', description: 'Every movement event should explain how a team roster changed and which roster window opened or closed.', firstDataNeed: 'Transactions plus roster windows.'),
  WorkspaceBuildItem(area: 'Trade trees', priority: 'P3', status: 'Graph contract ready, future implementation', description: 'Connect multi-player trades, draft picks, downstream assets, later outcomes, and team-building impact.', firstDataNeed: 'Normalized transaction groups and draft links.'),
  WorkspaceBuildItem(area: 'Timeline reports', priority: 'P3', status: 'Payload contract ready', description: 'Generate player movement timelines, team transaction histories, and franchise-building reports.', firstDataNeed: 'Transaction rows plus report builder inputs.'),
  WorkspaceBuildItem(area: 'Contract events', priority: 'P3', status: 'Contract ready, source-rights gated', description: 'Extensions, options, guarantees, conversions, buyouts, and salary/cap effects.', firstDataNeed: 'Lawful contract and salary source.'),
  WorkspaceBuildItem(area: 'Transaction alert route', priority: 'P2', status: 'Contract ready, evaluator pending', description: 'Transaction rows can drive player movement, team-building, roster-window, and source-change alerts.', firstDataNeed: 'Transactions plus alert evaluator.'),
  WorkspaceBuildItem(area: 'Transaction export route', priority: 'P2', status: 'Payload contract ready', description: 'Movement timelines and team-building boards can export with source metadata, row filters, and event taxonomy.', firstDataNeed: 'Transaction table state and source snapshot.'),
];

const contractWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Player contracts', priority: 'P2', status: 'Schema ready, source-rights gated', description: 'Contract type, start/end seasons, total value, AAV, guarantees, options, and source metadata.', firstDataNeed: 'Lawful salary/contract source or licensed provider.'),
  WorkspaceBuildItem(area: 'Team payroll views', priority: 'P3', status: 'Contract ready, source-rights gated', description: 'Team-season payroll, cap allocation, tax/apron context, dead money, guarantees, and roster construction.', firstDataNeed: 'Salary records plus CBA context.'),
  WorkspaceBuildItem(area: 'Contract event timeline', priority: 'P3', status: 'Contract ready, source-rights gated', description: 'Extensions, options, waivers, buyouts, conversions, two-way contracts, and guarantee dates.', firstDataNeed: 'Transaction and contract-event source.'),
  WorkspaceBuildItem(area: 'CBA rules context', priority: 'P4', status: 'Research contract ready, future implementation', description: 'Cap mechanics, apron constraints, exceptions, trade rules, draft rights, and team-building restrictions.', firstDataNeed: 'CBA reference and rules interpretation layer.'),
  WorkspaceBuildItem(area: 'Contract governance gate', priority: 'P0', status: 'Active rule', description: 'Contract and salary rows stay gated until a lawful display and export posture is selected.', firstDataNeed: 'Source policy decision and rights review.'),
];

const mediaWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Source-linked articles', priority: 'P3', status: 'Schema ready, source-gated', description: 'Articles, reports, interviews, clips, notes, and documents linked to teams, players, games, seasons, and transactions.', firstDataNeed: 'Manual research/source entry or licensed content feed.'),
  WorkspaceBuildItem(area: 'Internal research notes', priority: 'P3', status: 'Notes contract ready, persistence pending', description: 'Private notes, investment-style memos, scouting writeups, source summaries, and user-authored research artifacts.', firstDataNeed: 'Local notes model and persistence layer.'),
  WorkspaceBuildItem(area: 'Media entity linking', priority: 'P4', status: 'Entity-link contract ready', description: 'Attach content to entities with source, date, credibility, topic tags, and data-rights treatment.', firstDataNeed: 'Entity linking rules and content metadata.'),
  WorkspaceBuildItem(area: 'Narrative timeline', priority: 'P4', status: 'Timeline contract ready, data pending', description: 'Chronological story layer for player development, team changes, injuries, transactions, playoff moments, and historical context.', firstDataNeed: 'Media assets, transactions, games, and roster events.'),
  WorkspaceBuildItem(area: 'Research report route', priority: 'P3', status: 'Payload contract ready', description: 'Research notes and source-linked artifacts can feed reports, scouting packets, community posts later, and source audit outputs.', firstDataNeed: 'Research item state and report builder payload.'),
];

const scoutingWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Player scouting profile', priority: 'P3', status: 'Template contract ready, future product', description: 'Strengths, weaknesses, physical profile, role projection, production context, development path, and comparable players.', firstDataNeed: 'Manual scouting template and player identity layer.'),
  WorkspaceBuildItem(area: 'Team scouting profile', priority: 'P3', status: 'Template contract ready, future product', description: 'Team style, roster construction, offensive/defensive identity, coaching context, and matchup tendencies.', firstDataNeed: 'Team stats, roster history, games, media notes.'),
  WorkspaceBuildItem(area: 'Prospect scouting layer', priority: 'P4', status: 'Template contract ready, future product', description: 'Draft prospects, combine context, pre-NBA pathway, G League/Ignite/international history, and outcome tracking.', firstDataNeed: 'Draft, combine, player identity, and prospect notes.'),
  WorkspaceBuildItem(area: 'Scouting note workflow', priority: 'P4', status: 'Notes contract ready, persistence pending', description: 'Repeatable note structure with tags, grades, evidence, source links, and reviewer metadata.', firstDataNeed: 'Local persistence and note schema.'),
  WorkspaceBuildItem(area: 'Scouting report route', priority: 'P3', status: 'Payload contract ready', description: 'Scouting profiles and notes can feed reports, compare views, player pages, draft boards, and community posts later.', firstDataNeed: 'Scouting note state and report builder payload.'),
];
