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
  WorkspaceBuildItem(area: 'Game records', priority: 'P1', status: 'Schema ready', description: 'Game identity, date, season, season type, teams, scores, location, and source metadata.', firstDataNeed: 'Historical schedule and result snapshots.'),
  WorkspaceBuildItem(area: 'Team box scores', priority: 'P2', status: 'Planned', description: 'Team-level production for each game, including points, pace, efficiency, possessions, and shooting splits.', firstDataNeed: 'Official or licensed box-score source.'),
  WorkspaceBuildItem(area: 'Player box scores', priority: 'P2', status: 'Planned', description: 'Player-level game production with minutes, usage, shooting, counting stats, PF, turnovers, and availability context.', firstDataNeed: 'Historical player game-log data.'),
  WorkspaceBuildItem(area: 'Playoff linkage', priority: 'P2', status: 'Planned', description: 'Series-level matchup context, seeds, round, home-court status, game-by-game results, and advancement.', firstDataNeed: 'Playoff bracket and series records.'),
  WorkspaceBuildItem(area: 'Matchup context', priority: 'P2', status: 'Future', description: 'Team form, rest, schedule density, home/away context, rivalry notes, standings position, and roster availability later.', firstDataNeed: 'Game records plus team stats and roster windows.'),
  WorkspaceBuildItem(area: 'Trend chart hooks', priority: 'P3', status: 'Future', description: 'Game rows should support player and team game-by-game charts, rolling averages, and selected metric overlays.', firstDataNeed: 'Game logs, team box scores, player box scores.'),
  WorkspaceBuildItem(area: 'Fantasy matchup hooks', priority: 'P3', status: 'Future', description: 'Game schedules should power fantasy matchup density, back-to-backs, opponent quality, and start/sit context.', firstDataNeed: 'Games plus fantasy scoring and roster state.'),
];

const rosterWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Team-season rosters', priority: 'P1', status: 'Schema ready', description: 'Player-to-team-to-season relationships with position, jersey number, and roster status.', firstDataNeed: 'Historical roster snapshots by team and season.'),
  WorkspaceBuildItem(area: 'Active windows', priority: 'P2', status: 'Planned', description: 'Dates when players were active, inactive, assigned, recalled, signed, waived, or traded.', firstDataNeed: 'Transaction and roster status history.'),
  WorkspaceBuildItem(area: 'Two-way players', priority: 'P2', status: 'Future', description: 'Two-way contract status and NBA/G League movement.', firstDataNeed: 'Contract and assignment source.'),
  WorkspaceBuildItem(area: 'Roster role context', priority: 'P2', status: 'Planned', description: 'Position, role, minutes band later, starter/bench label later, and eligibility context for player/team pages.', firstDataNeed: 'Roster rows plus player stats and game logs.'),
  WorkspaceBuildItem(area: 'Roster construction', priority: 'P2', status: 'Future', description: 'How each team-season roster was built across draft, trades, signings, two-way movement, and development pathways.', firstDataNeed: 'Rosters plus draft and transaction rows.'),
  WorkspaceBuildItem(area: 'Game eligibility', priority: 'P3', status: 'Future', description: 'Connect roster windows to individual games, availability, injuries later, player logs, and fantasy decisions.', firstDataNeed: 'Game records plus roster windows.'),
  WorkspaceBuildItem(area: 'Lineup context', priority: 'P4', status: 'Future', description: 'Player combinations, minutes overlap, lineup performance, and role changes.', firstDataNeed: 'Lineup or play-by-play data.'),
];

const awardWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Major awards', priority: 'P1', status: 'Schema ready', description: 'MVP, Finals MVP, Rookie of the Year, Defensive Player of the Year, Sixth Man, Most Improved, and Coach of the Year.', firstDataNeed: 'Historical award winner list.'),
  WorkspaceBuildItem(area: 'All-NBA and All-Defense', priority: 'P1', status: 'Planned', description: 'Team selections, positions, vote totals, and season-level recognition.', firstDataNeed: 'Historical team selections and voting records.'),
  WorkspaceBuildItem(area: 'All-Star context', priority: 'P2', status: 'Planned', description: 'All-Star selections, starters, reserves, replacements, captains, and game participation.', firstDataNeed: 'Historical All-Star data.'),
  WorkspaceBuildItem(area: 'Voting shares', priority: 'P2', status: 'Planned', description: 'Vote shares, ranks, points, first-place votes, and voting body context.', firstDataNeed: 'Detailed voting tables.'),
  WorkspaceBuildItem(area: 'Award race boards', priority: 'P2', status: 'Planned', description: 'Season-by-season race pages showing winner, runners-up, finalists, voting ranks, points, and team context.', firstDataNeed: 'Award voting records with player and team IDs.'),
  WorkspaceBuildItem(area: 'Award case context', priority: 'P2', status: 'Future', description: 'Connect player stats, games played, standings, team record, playoffs, and prior awards to each race.', firstDataNeed: 'Awards plus player stats and standings.'),
  WorkspaceBuildItem(area: 'Report-ready award packets', priority: 'P3', status: 'Future', description: 'Generate award race reports and debate-ready comparison boards with source notes.', firstDataNeed: 'Award race rows plus report builder input.'),
];

const draftWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Draft picks', priority: 'P1', status: 'Schema ready', description: 'Draft year, round, pick number, team, player, school or club, country, and source metadata.', firstDataNeed: 'Historical NBA draft records.'),
  WorkspaceBuildItem(area: 'Draft classes', priority: 'P2', status: 'Planned', description: 'Class-level summaries, lottery context, pick distributions, outcomes, and team-level draft histories.', firstDataNeed: 'Draft pick records plus player identity links.'),
  WorkspaceBuildItem(area: 'Player identity joins', priority: 'P1', status: 'Planned', description: 'Connect each pick to a stable player profile, career rows, awards, rosters, and transactions.', firstDataNeed: 'Player profiles plus draft pick IDs.'),
  WorkspaceBuildItem(area: 'Team draft history', priority: 'P2', status: 'Future', description: 'Franchise draft boards by year, pick range, player outcome, retained value, and team-building context.', firstDataNeed: 'Draft picks plus team and franchise history.'),
  WorkspaceBuildItem(area: 'Prospect context', priority: 'P3', status: 'Future', description: 'College, international, G League, Ignite, combine, and pre-draft pathway context.', firstDataNeed: 'Prospect and combine sources.'),
  WorkspaceBuildItem(area: 'Draft rights and trades', priority: 'P4', status: 'Future', description: 'Pick trades, draft rights, swaps, protections, and transaction context.', firstDataNeed: 'Transaction and cap/legal source.'),
  WorkspaceBuildItem(area: 'Outcome model hooks', priority: 'P3', status: 'Future', description: 'Connect draft picks to award outcomes, career production, playoff impact, roster tenure, and fantasy relevance.', firstDataNeed: 'Draft rows plus player stats and awards.'),
];

const transactionWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Trades', priority: 'P1', status: 'Schema ready', description: 'Player movement between teams, dates, descriptions, and future asset context.', firstDataNeed: 'Historical transaction logs.'),
  WorkspaceBuildItem(area: 'Signings and waivers', priority: 'P2', status: 'Planned', description: 'Free-agent signings, waivers, releases, hardship deals, ten-days, and roster conversions.', firstDataNeed: 'Transaction source with event type detail.'),
  WorkspaceBuildItem(area: 'Assignments and recalls', priority: 'P2', status: 'Future', description: 'NBA/G League movement through assignments, recalls, and two-way player activity.', firstDataNeed: 'G League and NBA assignment source.'),
  WorkspaceBuildItem(area: 'Roster effects', priority: 'P2', status: 'Planned', description: 'Every movement event should explain how a team roster changed and which roster window opened or closed.', firstDataNeed: 'Transactions plus roster windows.'),
  WorkspaceBuildItem(area: 'Trade trees', priority: 'P3', status: 'Future', description: 'Connect multi-player trades, draft picks, downstream assets, later outcomes, and team-building impact.', firstDataNeed: 'Normalized transaction groups and draft links.'),
  WorkspaceBuildItem(area: 'Timeline reports', priority: 'P3', status: 'Future', description: 'Generate player movement timelines, team transaction histories, and franchise-building reports.', firstDataNeed: 'Transaction rows plus report builder inputs.'),
  WorkspaceBuildItem(area: 'Contract events', priority: 'P3', status: 'Source needed', description: 'Extensions, options, guarantees, conversions, buyouts, and salary/cap effects.', firstDataNeed: 'Lawful contract and salary source.'),
];

const contractWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Player contracts', priority: 'P2', status: 'Schema ready, source needed', description: 'Contract type, start/end seasons, total value, AAV, guarantees, options, and source metadata.', firstDataNeed: 'Lawful salary/contract source or licensed provider.'),
  WorkspaceBuildItem(area: 'Team payroll views', priority: 'P3', status: 'Future', description: 'Team-season payroll, cap allocation, tax/apron context, dead money, guarantees, and roster construction.', firstDataNeed: 'Salary records plus CBA context.'),
  WorkspaceBuildItem(area: 'Contract event timeline', priority: 'P3', status: 'Future', description: 'Extensions, options, waivers, buyouts, conversions, two-way contracts, and guarantee dates.', firstDataNeed: 'Transaction and contract-event source.'),
  WorkspaceBuildItem(area: 'CBA rules context', priority: 'P4', status: 'Future', description: 'Cap mechanics, apron constraints, exceptions, trade rules, draft rights, and team-building restrictions.', firstDataNeed: 'CBA reference and rules interpretation layer.'),
];

const mediaWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Source-linked articles', priority: 'P3', status: 'Schema ready', description: 'Articles, reports, interviews, clips, notes, and documents linked to teams, players, games, seasons, and transactions.', firstDataNeed: 'Manual research/source entry or licensed content feed.'),
  WorkspaceBuildItem(area: 'Internal research notes', priority: 'P3', status: 'Future', description: 'Private notes, investment-style memos, scouting writeups, source summaries, and user-authored research artifacts.', firstDataNeed: 'Local notes model and persistence layer.'),
  WorkspaceBuildItem(area: 'Media entity linking', priority: 'P4', status: 'Future', description: 'Attach content to entities with source, date, credibility, topic tags, and data-rights treatment.', firstDataNeed: 'Entity linking rules and content metadata.'),
  WorkspaceBuildItem(area: 'Narrative timeline', priority: 'P4', status: 'Future', description: 'Chronological story layer for player development, team changes, injuries, transactions, playoff moments, and historical context.', firstDataNeed: 'Media assets, transactions, games, and roster events.'),
];

const scoutingWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(area: 'Player scouting profile', priority: 'P3', status: 'Future', description: 'Strengths, weaknesses, physical profile, role projection, production context, development path, and comparable players.', firstDataNeed: 'Manual scouting template and player identity layer.'),
  WorkspaceBuildItem(area: 'Team scouting profile', priority: 'P3', status: 'Future', description: 'Team style, roster construction, offensive/defensive identity, coaching context, and matchup tendencies.', firstDataNeed: 'Team stats, roster history, games, media notes.'),
  WorkspaceBuildItem(area: 'Prospect scouting layer', priority: 'P4', status: 'Future', description: 'Draft prospects, combine context, pre-NBA pathway, G League/Ignite/international history, and outcome tracking.', firstDataNeed: 'Draft, combine, player identity, and prospect notes.'),
  WorkspaceBuildItem(area: 'Scouting note workflow', priority: 'P4', status: 'Future', description: 'Repeatable note structure with tags, grades, evidence, source links, and reviewer metadata.', firstDataNeed: 'Local persistence and note schema.'),
];
