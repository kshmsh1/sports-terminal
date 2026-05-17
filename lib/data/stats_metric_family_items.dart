class StatsMetricFamilyItem {
  const StatsMetricFamilyItem({required this.family, required this.status, required this.playerFields, required this.teamFields, required this.firstUse, required this.sourceNote});

  final String family;
  final String status;
  final String playerFields;
  final String teamFields;
  final String firstUse;
  final String sourceNote;
}

const statsMetricFamilyItems = <StatsMetricFamilyItem>[
  StatsMetricFamilyItem(family: 'Traditional', status: 'First', playerFields: 'GP, MPG, PTS, REB, AST, STL, BLK, TOV, PF', teamFields: 'W, L, Win%, PPG, Opp PPG, REB, AST, STL, BLK, TOV, PF', firstUse: 'Core tables, player reports, team reports, MVP models, fantasy base.', sourceNote: 'Official/basic box-score source path first.'),
  StatsMetricFamilyItem(family: 'Shooting', status: 'Planned', playerFields: 'FG%, 3P%, FT%, eFG%, TS%, FTA later, C&S later', teamFields: 'FG%, 3P%, FT%, eFG%, TS%, shot profile later', firstUse: 'Efficiency boards, trend charts, award cases, team environment.', sourceNote: 'Some derived fields can be calculated after attempts/makes are loaded.'),
  StatsMetricFamilyItem(family: 'Advanced', status: 'Planned', playerFields: 'USG%, ORtg, DRtg, Net, BPM, VORP, WS, PER, EPM/DARKO/LEBRON later', teamFields: 'Pace, ORtg, DRtg, Net, possession context, lineup ratings later', firstUse: 'High-signal analysis, Compare, custom rankings, Workspace Studio formulas.', sourceNote: 'Separate public/official/derived metrics from licensed placeholders.'),
  StatsMetricFamilyItem(family: 'Defense', status: 'Future', playerFields: 'STL, BLK, PF, DFG%, deflections, charges drawn, contests, turnovers forced', teamFields: 'Opp PPG, DRtg, opponent shooting, forced turnovers, defensive rebounding', firstUse: 'DPOY cases, scouting, matchup analysis, team defensive profiles.', sourceNote: 'Tracking fields require a clear source and rights path.'),
  StatsMetricFamilyItem(family: 'Playmaking', status: 'Future', playerFields: 'AST, TOV, AST/TOV, potential assists, drives, P&R creation', teamFields: 'AST, TOV, AST%, assist rate, turnover rate, drive creation later', firstUse: 'Creator comparisons, offensive role analysis, guard boards.', sourceNote: 'Potential assists and drives are tracking-dependent.'),
  StatsMetricFamilyItem(family: 'Play Type', status: 'Future', playerFields: 'Isolation, P&R ball handler, roll man, spot-up, transition, C&S, post-up', teamFields: 'Transition offense/defense, spot-up profile, P&R mix, isolation efficiency', firstUse: 'Scouting, matchup prep, player role context, team style.', sourceNote: 'Needs play-type feed or licensed data.'),
  StatsMetricFamilyItem(family: 'Context', status: 'Planned', playerFields: 'Team record, seed, roster window, playoffs, awards, draft slot', teamFields: 'Standings, playoff path, roster construction, draft, transactions', firstUse: 'Transforms stat rows into command-ready analysis objects.', sourceNote: 'Comes from joins rather than standalone stat import.'),
  StatsMetricFamilyItem(family: 'Source Audit', status: 'Planned', playerFields: 'sourceId, asOf, lineage, missing flags, rights label', teamFields: 'sourceId, asOf, lineage, missing flags, rights label', firstUse: 'Export governance, report footnotes, QA, trust controls.', sourceNote: 'Required for every sourced stat surface.'),
];
