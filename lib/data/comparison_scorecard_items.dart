class ComparisonScorecardItem {
  const ComparisonScorecardItem({required this.block, required this.status, required this.fields, required this.purpose});

  final String block;
  final String status;
  final String fields;
  final String purpose;
}

const comparisonScorecardItems = <ComparisonScorecardItem>[
  ComparisonScorecardItem(block: 'Identity', status: 'First', fields: 'entity name, season, team, type, source status', purpose: 'Make the two compared objects unambiguous before stats are shown.'),
  ComparisonScorecardItem(block: 'Availability', status: 'Planned', fields: 'games, minutes, starts later, roster window, award eligibility', purpose: 'Separate production from durability and qualification.'),
  ComparisonScorecardItem(block: 'Production', status: 'Planned', fields: 'points, rebounds, assists, steals, blocks, turnovers, personal fouls', purpose: 'Show traditional box-score differences.'),
  ComparisonScorecardItem(block: 'Efficiency', status: 'Planned', fields: 'FG%, 3P%, FT%, eFG%, TS%, usage, assist-to-turnover later', purpose: 'Show whether volume was efficient.'),
  ComparisonScorecardItem(block: 'Team Context', status: 'Planned', fields: 'team record, seed, net rating, pace, playoff result', purpose: 'Explain environment and winning context.'),
  ComparisonScorecardItem(block: 'Advanced Value', status: 'Future', fields: 'BPM, VORP, win shares, PER, EPM, DARKO, LEBRON', purpose: 'Add advanced value systems when the source path is clear.'),
  ComparisonScorecardItem(block: 'Defense', status: 'Future', fields: 'stocks, fouls, DFG%, deflections, contests, charges, forced turnovers', purpose: 'Avoid treating defense as only steals and blocks.'),
  ComparisonScorecardItem(block: 'Awards and Recognition', status: 'Planned', fields: 'award rank, points, share, first-place votes, All-NBA, All-Star', purpose: 'Connect comparison outputs to award-race context.'),
  ComparisonScorecardItem(block: 'Source Audit', status: 'Planned', fields: 'sourceId, asOf, lineage, missing fields, rights posture', purpose: 'Make every comparison trustworthy and export-safe.'),
];
