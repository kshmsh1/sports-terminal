import 'nba_stats_workstation_engine.dart';

enum NbaTerminalMetricFormat {
  decimal,
  integer,
  percent,
  signed,
  seconds,
  inches,
  pounds,
}

class NbaTerminalMetric {
  const NbaTerminalMetric({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.group,
    required this.description,
    this.engineKey,
    this.rawAliases = const [],
    this.children = const [],
    this.format = NbaTerminalMetricFormat.decimal,
    this.decimals = 1,
    this.higherIsBetter = true,
    this.providerNative = false,
  });

  final String key;
  final String label;
  final String shortLabel;
  final String group;
  final String description;
  final String? engineKey;
  final List<String> rawAliases;
  final List<String> children;
  final NbaTerminalMetricFormat format;
  final int decimals;
  final bool higherIsBetter;
  final bool providerNative;
}

class NbaTerminalStatFamily {
  const NbaTerminalStatFamily({
    required this.id,
    required this.label,
    required this.description,
    required this.metrics,
    this.expansionOverrides = const {},
  });

  final String id;
  final String label;
  final String description;
  final List<String> metrics;
  final Map<String, List<String>> expansionOverrides;
}

const nbaTerminalStatFamilies = <NbaTerminalStatFamily>[
  NbaTerminalStatFamily(
    id: 'basic',
    label: 'Basic Stats',
    description: 'Core box-score production and shooting efficiency.',
    metrics: [
      'gp', 'mpg', 'ppg', 'rpg', 'apg', 'spg', 'bpg', 'tpg', 'pf',
      'fg_pct', 'three_pct', 'ft_pct',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'defense_hustle',
    label: 'Defensive / Hustle',
    description: 'Defensive events, contests, hustle plays and opponent shooting.',
    metrics: [
      'spg', 'bpg', 'deflections_pg', 'dreb', 'charges_drawn_pg',
      'contested_shots_pg', 'loose_balls_recovered_pg', 'dfg_pct',
      'rim_dfg_pct', 'midrange_dfg_pct', 'three_dfg_pct', 'box_out_pct',
      'blow_by_rate', 'contest_distance', 'help_defense_pg', 'deterrence_rate',
      'switch_attrition_rate', 'closeout_speed', 'anticipation',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'playmaking',
    label: 'Playmaking / Possession',
    description: 'Passing volume, creation quality, turnovers and decision-making.',
    metrics: [
      'apg', 'tpg', 'screen_apg', 'secondary_apg', 'potential_apg', 'passes_pg',
      'ast_to', 'ast_pct', 'tov_pct', 'adjusted_assist_ratio', 'ft_apg',
      'touches_pg', 'pass_windows_opened', 'passing_decision_time',
      'panic_turnover_rate', 'blitz_trap_escape_rate', 'double_team_escape_rate',
      'triple_team_escape_rate',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'rebounding',
    label: 'Rebounding',
    description: 'Rebound production, contest context and rebounding rates.',
    metrics: [
      'rpg', 'dreb', 'oreb', 'box_out_pct', 'tap_outs_pg', 'deferred_rebounds_pg',
    ],
    expansionOverrides: {
      'rpg': ['contested_rpg', 'uncontested_rpg', 'trb_pct'],
    },
  ),
  NbaTerminalStatFamily(
    id: 'efficiency',
    label: 'Efficiency',
    description: 'Shot efficiency, scoring efficiency and possession efficiency.',
    metrics: [
      'efg_pct', 'ts_pct', 'ftr', 'three_par', 'pps', 'pie',
      'assisted_fg_pct', 'unassisted_fg_pct', 'assisted_ppg', 'unassisted_ppg',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'impact',
    label: 'Impact',
    description: 'Team-level impact while a player is on the floor.',
    metrics: ['ortg', 'drtg', 'net_rating', 'on_off', 'pace'],
  ),
  NbaTerminalStatFamily(
    id: 'aggregate',
    label: 'Aggregate Metrics',
    description: 'Composite impact and value models from box score and plus-minus data.',
    metrics: [
      'per', 'bpm', 'vorp', 'ws', 'epm', 'lebron', 'darko', 'rapm', 'la_rapm', 'warv',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'movement',
    label: 'Movement',
    description: 'Usage, physical movement, touches and decision-time measures.',
    metrics: [
      'usage', 'distance_traveled', 'average_speed', 'time_per_touch',
      'dribbles_per_touch', 'freeze_time', 'scoring_decision_time',
      'passing_decision_time', 'driving_decision_time',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'clutch',
    label: 'Clutch',
    description: 'Production in source-defined clutch situations.',
    metrics: [
      'clutch_ppg', 'clutch_rpg', 'clutch_apg', 'clutch_spg', 'clutch_bpg',
      'clutch_fg_pct', 'clutch_three_pct', 'clutch_ft_pct', 'clutch_net_rating',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'shot_profile',
    label: 'Shot Profile',
    description: 'Location, shot type, creation mode and finishing profile.',
    metrics: [
      'rim_frequency', 'rim_fg_pct', 'paint_frequency', 'paint_fg_pct',
      'midrange_frequency', 'midrange_fg_pct', 'three_frequency', 'three_pct',
      'halfcourt_frequency', 'halfcourt_fg_pct', 'heaves_pg',
      'corner_three_frequency', 'corner_three_pct',
      'right_corner_three_frequency', 'right_corner_three_pct',
      'left_corner_three_frequency', 'left_corner_three_pct',
      'catch_shoot_three_frequency', 'catch_shoot_three_pct',
      'pull_up_three_frequency', 'pull_up_three_pct',
      'right_wing_three_frequency', 'right_wing_three_pct',
      'left_wing_three_frequency', 'left_wing_three_pct',
      'wing_three_frequency', 'wing_three_pct',
      'middle_three_frequency', 'middle_three_pct',
      'dunks_pg', 'dunk_fg_pct', 'layups_pg', 'layup_fg_pct',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'play_type',
    label: 'Play Type',
    description: 'Possession efficiency by offensive action and transition context.',
    metrics: [
      'isolation_ppp', 'transition_ppp', 'transition_offense_ppp',
      'transition_defense_ppp', 'pnr_ball_handler_ppp', 'pnr_roll_man_ppp',
      'post_up_ppp', 'spot_up_ppp', 'drive_ppg', 'drive_apg',
      'backdoor_cut_pg', 'v_cut_pg', 'l_cut_pg',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'gravity_creation',
    label: 'Gravity / Creation',
    description: 'How player movement and attention alter space and passing windows.',
    metrics: [
      'offensive_gravity', 'shot_gravity', 'drive_gravity', 'pass_windows_opened',
      'freeze_time', 'screen_apg', 'screens_set_pg', 'screens_used_pg',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'physical',
    label: 'Physical Profile',
    description: 'Measured body dimensions and athletic testing.',
    metrics: [
      'height', 'weight', 'wingspan', 'standing_reach', 'hand_length', 'hand_width',
      'standing_jump', 'max_vertical_jump',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'discipline',
    label: 'Fouls / Discipline',
    description: 'Foul types, technical discipline and game-removal events.',
    metrics: [
      'technical_fouls', 'shooting_fouls', 'personal_fouls', 'offensive_fouls',
      'defensive_fouls', 'other_fouls', 'ejections', 'disqualifications',
      'suspensions', 'whistle_reaction', 'game_buzzer_beaters',
      'quarter_buzzer_beaters', 'shot_clock_buzzer_beaters',
    ],
  ),
  NbaTerminalStatFamily(
    id: 'availability',
    label: 'Availability / Injury',
    description: 'Availability, injury burden and time missed.',
    metrics: [
      'availability_pct', 'games_missed_injury', 'injury_events', 'days_missed',
      'injury_rate',
    ],
  ),
];

NbaTerminalMetric _m(
  String key,
  String label,
  String shortLabel,
  String group,
  String description, {
  String? engineKey,
  List<String> raw = const [],
  List<String> children = const [],
  NbaTerminalMetricFormat format = NbaTerminalMetricFormat.decimal,
  int decimals = 1,
  bool higherIsBetter = true,
  bool providerNative = false,
}) => NbaTerminalMetric(
  key: key,
  label: label,
  shortLabel: shortLabel,
  group: group,
  description: description,
  engineKey: engineKey,
  rawAliases: raw,
  children: children,
  format: format,
  decimals: decimals,
  higherIsBetter: higherIsBetter,
  providerNative: providerNative,
);

final List<NbaTerminalMetric> nbaTerminalMetrics = [
  _m('gp', 'Games Played', 'GP', 'Basic', 'Games played in the selected season segment.', engineKey: 'gp', format: NbaTerminalMetricFormat.integer),
  _m('mpg', 'Minutes Per Game', 'MPG', 'Basic', 'Average minutes played per game.', engineKey: 'min', raw: ['mpg', 'minutes_per_game']),
  _m('ppg', 'Points Per Game', 'PPG', 'Basic', 'Points scored under the selected rate basis.', engineKey: 'pts'),
  _m('rpg', 'Rebounds Per Game', 'RPG', 'Basic', 'Total rebounds under the selected rate basis.', engineKey: 'reb', children: ['oreb', 'dreb']),
  _m('oreb', 'Offensive Rebounds', 'ORB', 'Rebounding', 'Offensive rebounds under the selected rate basis.', engineKey: 'oreb', children: ['contested_orb_pg', 'uncontested_orb_pg', 'orb_pct']),
  _m('dreb', 'Defensive Rebounds', 'DRB', 'Rebounding', 'Defensive rebounds under the selected rate basis.', engineKey: 'dreb', children: ['contested_dreb_pg', 'uncontested_dreb_pg', 'drb_pct']),
  _m('apg', 'Assists Per Game', 'APG', 'Playmaking', 'Assists under the selected rate basis.', engineKey: 'ast'),
  _m('spg', 'Steals Per Game', 'SPG', 'Defense', 'Steals under the selected rate basis.', engineKey: 'stl', children: ['stl_pct']),
  _m('bpg', 'Blocks Per Game', 'BPG', 'Defense', 'Blocks under the selected rate basis.', engineKey: 'blk', children: ['blk_pct']),
  _m('tpg', 'Turnovers Per Game', 'TPG', 'Playmaking', 'Turnovers under the selected rate basis.', engineKey: 'tov', higherIsBetter: false),
  _m('pf', 'Personal Fouls', 'PF', 'Basic', 'Personal fouls under the selected rate basis.', engineKey: 'pf', higherIsBetter: false),
  _m('fg_pct', 'Field Goal Percentage', 'FG%', 'Shooting', 'Field goals made divided by field-goal attempts.', engineKey: 'fg_pct', children: ['fgm', 'fga'], format: NbaTerminalMetricFormat.percent),
  _m('fgm', 'Field Goals Made', 'FGM', 'Shooting', 'Field goals made under the selected rate basis.', engineKey: 'fgm'),
  _m('fga', 'Field Goal Attempts', 'FGA', 'Shooting', 'Field-goal attempts under the selected rate basis.', engineKey: 'fga'),
  _m('three_pct', 'Three-Point Percentage', '3P%', 'Shooting', 'Three-pointers made divided by three-point attempts.', engineKey: 'three_pct', children: ['three_pm', 'three_pa'], format: NbaTerminalMetricFormat.percent),
  _m('three_pm', 'Three-Pointers Made', '3PM', 'Shooting', 'Three-pointers made under the selected rate basis.', engineKey: 'three_pm'),
  _m('three_pa', 'Three-Point Attempts', '3PA', 'Shooting', 'Three-point attempts under the selected rate basis.', engineKey: 'three_pa'),
  _m('ft_pct', 'Free Throw Percentage', 'FT%', 'Shooting', 'Free throws made divided by free-throw attempts.', engineKey: 'ft_pct', children: ['ftm', 'fta'], format: NbaTerminalMetricFormat.percent),
  _m('ftm', 'Free Throws Made', 'FTM', 'Shooting', 'Free throws made under the selected rate basis.', engineKey: 'ftm'),
  _m('fta', 'Free Throw Attempts', 'FTA', 'Shooting', 'Free-throw attempts under the selected rate basis.', engineKey: 'fta'),

  _m('stl_pct', 'Steal Percentage', 'STL%', 'Defense', 'Estimated percentage of opponent possessions ending in a steal while the player is on court.', raw: ['stl_pct', 'steal_pct', 'steal_percentage'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('blk_pct', 'Block Percentage', 'BLK%', 'Defense', 'Estimated percentage of opponent two-point attempts blocked while the player is on court.', raw: ['blk_pct', 'block_pct', 'block_percentage'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('deflections_pg', 'Deflections Per Game', 'DPG', 'Defense', 'Deflections credited to the player per game.', raw: ['deflections_per_game', 'deflections_pg', 'avg_deflections'], providerNative: true),
  _m('contested_dreb_pg', 'Contested Defensive Rebounds Per Game', 'C-DRB', 'Rebounding', 'Defensive rebounds secured with an opponent contest nearby.', raw: ['contested_dreb_pg', 'contested_defensive_rebounds_per_game'], providerNative: true),
  _m('uncontested_dreb_pg', 'Uncontested Defensive Rebounds Per Game', 'U-DRB', 'Rebounding', 'Defensive rebounds secured without a nearby opponent contest.', raw: ['uncontested_dreb_pg', 'uncontested_defensive_rebounds_per_game'], providerNative: true),
  _m('charges_drawn_pg', 'Charges Drawn Per Game', 'CHG PG', 'Defense', 'Offensive fouls drawn as charges per game.', raw: ['charges_drawn_per_game', 'charges_drawn_pg'], providerNative: true),
  _m('contested_shots_pg', 'Contested Shots Per Game', 'CONT PG', 'Defense', 'Opponent shot attempts contested by the player per game.', raw: ['contested_shots_per_game', 'contested_shots_pg'], providerNative: true),
  _m('loose_balls_recovered_pg', 'Loose Balls Recovered Per Game', 'LBR PG', 'Defense', 'Loose balls recovered by the player per game.', raw: ['loose_balls_recovered_per_game', 'loose_balls_recovered_pg'], providerNative: true),
  _m('dfg_pct', 'Defended Field Goal Percentage', 'DFG%', 'Defense', 'Opponent field-goal percentage on attempts for which the player is the recorded defender.', raw: ['dfg_pct', 'defended_field_goal_pct'], children: ['dfgm', 'dfga'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
  _m('dfgm', 'Defended Field Goals Made', 'DFGM', 'Defense', 'Opponent makes on shots attributed to this defender.', raw: ['dfgm', 'defended_field_goals_made'], higherIsBetter: false, providerNative: true),
  _m('dfga', 'Defended Field Goal Attempts', 'DFGA', 'Defense', 'Opponent attempts on shots attributed to this defender.', raw: ['dfga', 'defended_field_goal_attempts'], providerNative: true),
  _m('rim_dfg_pct', 'Rim Defended Field Goal Percentage', 'RIM DFG%', 'Defense', 'Opponent field-goal percentage at the rim when this player is the defender.', raw: ['rim_dfg_pct', 'rim_defended_fg_pct'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
  _m('midrange_dfg_pct', 'Midrange Defended Field Goal Percentage', 'MID DFG%', 'Defense', 'Opponent midrange field-goal percentage when this player is the defender.', raw: ['midrange_dfg_pct'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
  _m('three_dfg_pct', 'Three-Point Defended Field Goal Percentage', '3P DFG%', 'Defense', 'Opponent three-point percentage when this player is the defender.', raw: ['three_dfg_pct', 'three_point_dfg_pct'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
  _m('box_out_pct', 'Box Out Percentage', 'BOX OUT%', 'Defense', 'Share of eligible rebounding opportunities on which the player records a box out.', raw: ['box_out_pct', 'boxout_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('blow_by_rate', 'Blow-By Rate', 'BLOW-BY%', 'Defense', 'Rate at which the primary ball handler beats the defender cleanly off the dribble.', raw: ['blow_by_rate', 'blowby_rate'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
  _m('contest_distance', 'Average Contest Distance', 'CONT DIST', 'Defense', 'Average defender-to-shooter distance at the tracked contest.', raw: ['contest_distance', 'avg_contest_distance'], providerNative: true),
  _m('help_defense_pg', 'Help Defense Events Per Game', 'HELP PG', 'Defense', 'Tracked help rotations or help-defense interventions per game.', raw: ['help_defense_pg', 'help_events_per_game'], providerNative: true),
  _m('deterrence_rate', 'Deterrence Rate', 'DETER%', 'Defense', 'Estimated reduction in opponent shot or drive attempts attributable to the defender’s presence.', raw: ['deterrence_rate'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('switch_attrition_rate', 'Switch Attrition Rate', 'SW ATTR%', 'Defense', 'Rate at which an offense abandons or degrades an action after the player switches onto it.', raw: ['switch_attrition_rate'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('closeout_speed', 'Closeout Speed', 'CL SPEED', 'Defense', 'Tracked average speed while closing out to a shooter.', raw: ['closeout_speed', 'avg_closeout_speed'], providerNative: true),
  _m('anticipation', 'Defensive Anticipation', 'ANTICIP', 'Defense', 'Model or tracking estimate of how early a defender recognizes and reacts to developing actions.', raw: ['anticipation', 'defensive_anticipation'], providerNative: true),
  _m('anticipation', 'Defensive Anticipation', 'ANTICIP', 'Defense', 'Model or tracking estimate of how early a defender recognizes and reacts to developing actions.', raw: ['anticipation', 'defensive_anticipation'], providerNative: true),

  _m('screen_apg', 'Screen Assists Per Game', 'SCREEN APG', 'Playmaking', 'Screens directly leading to a made field goal per game.', raw: ['screen_assists_per_game', 'screen_apg'], providerNative: true),
  _m('secondary_apg', 'Secondary Assists Per Game', '2ND APG', 'Playmaking', 'Passes immediately preceding the credited assist, also called hockey assists.', raw: ['secondary_assists_per_game', 'secondary_apg', 'hockey_assists_per_game'], providerNative: true),
  _m('potential_apg', 'Potential Assists Per Game', 'POT APG', 'Playmaking', 'Passes that would become assists if the receiving player makes the resulting shot.', raw: ['potential_assists_per_game', 'potential_apg'], providerNative: true),
  _m('passes_pg', 'Passes Per Game', 'PASSES PG', 'Playmaking', 'Tracked passes made by the player per game.', raw: ['passes_per_game', 'passes_pg'], providerNative: true),
  _m('ast_to', 'Assist-to-Turnover Ratio', 'AST:TO', 'Playmaking', 'Assists divided by turnovers.', engineKey: 'ast_tov', decimals: 2),
  _m('ast_pct', 'Assist Percentage', 'AST%', 'Playmaking', 'Estimated percentage of teammate field goals assisted while the player is on court.', raw: ['ast_pct', 'assist_pct', 'assist_percentage'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('tov_pct', 'Turnover Percentage', 'TO%', 'Playmaking', 'Estimated turnovers per 100 individual possessions used.', raw: ['tov_pct', 'turnover_pct', 'turnover_percentage'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
  _m('adjusted_assist_ratio', 'Adjusted Assist Ratio', 'ADJ AST', 'Playmaking', 'Creation rate counting direct assists, free-throw assists and secondary assists.', raw: ['adjusted_assist_ratio', 'adj_assist_ratio'], providerNative: true),
  _m('ft_apg', 'Free-Throw Assists Per Game', 'FT APG', 'Playmaking', 'Passes leading directly to shooting fouls and free-throw trips per game.', raw: ['free_throw_assists_per_game', 'ft_assists_per_game', 'ft_apg'], providerNative: true),
  _m('touches_pg', 'Touches Per Game', 'TOUCH PG', 'Playmaking', 'Tracked offensive touches per game.', raw: ['touches_per_game', 'touches_pg'], providerNative: true),
  _m('pass_windows_opened', 'Pass Windows Opened', 'PASS WIN', 'Creation', 'Estimated passing lanes created for teammates by player positioning, movement or gravity.', raw: ['pass_windows_opened', 'passing_lanes_opened'], providerNative: true),
  _m('passing_decision_time', 'Passing Decision Time', 'PASS DT', 'Movement', 'Average elapsed time from gaining possession to initiating a pass.', raw: ['passing_decision_time', 'avg_passing_decision_time'], format: NbaTerminalMetricFormat.seconds, higherIsBetter: false, providerNative: true),
  _m('panic_turnover_rate', 'Panic Turnover Rate', 'PANIC TO%', 'Playmaking', 'Share of pressure possessions ending in an unplanned or forced turnover.', raw: ['panic_turnover_rate'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
  _m('blitz_trap_escape_rate', 'Blitz / Trap Escape Rate', 'TRAP ESC%', 'Playmaking', 'Share of blitzed or trapped possessions escaped without a turnover or dead possession.', raw: ['blitz_trap_escape_rate', 'trap_escape_rate'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('double_team_escape_rate', 'Double-Team Navigation Rate', 'DBL ESC%', 'Playmaking', 'Successful navigation rate when two defenders commit to the ball.', raw: ['double_team_escape_rate'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('triple_team_escape_rate', 'Triple-Team Navigation Rate', 'TRI ESC%', 'Playmaking', 'Successful navigation rate when three defenders commit to the ball.', raw: ['triple_team_escape_rate'], format: NbaTerminalMetricFormat.percent, providerNative: true),

  _m('contested_rpg', 'Contested Rebounds Per Game', 'C-RPG', 'Rebounding', 'Rebounds secured with an opponent contest nearby.', raw: ['contested_rebounds_per_game', 'contested_rpg'], providerNative: true),
  _m('uncontested_rpg', 'Uncontested Rebounds Per Game', 'U-RPG', 'Rebounding', 'Rebounds secured without a nearby opponent contest.', raw: ['uncontested_rebounds_per_game', 'uncontested_rpg'], providerNative: true),
  _m('trb_pct', 'Total Rebound Percentage', 'TRB%', 'Rebounding', 'Estimated share of available rebounds secured while the player is on court.', raw: ['trb_pct', 'total_rebound_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('drb_pct', 'Defensive Rebound Percentage', 'DRB%', 'Rebounding', 'Estimated share of available defensive rebounds secured while the player is on court.', raw: ['drb_pct', 'defensive_rebound_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('contested_orb_pg', 'Contested Offensive Rebounds Per Game', 'C-ORB', 'Rebounding', 'Offensive rebounds secured with an opponent contest nearby.', raw: ['contested_orb_pg', 'contested_offensive_rebounds_per_game'], providerNative: true),
  _m('uncontested_orb_pg', 'Uncontested Offensive Rebounds Per Game', 'U-ORB', 'Rebounding', 'Offensive rebounds secured without a nearby opponent contest.', raw: ['uncontested_orb_pg', 'uncontested_offensive_rebounds_per_game'], providerNative: true),
  _m('orb_pct', 'Offensive Rebound Percentage', 'ORB%', 'Rebounding', 'Estimated share of available offensive rebounds secured while the player is on court.', raw: ['orb_pct', 'offensive_rebound_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('tap_outs_pg', 'Tap Outs Per Game', 'TAP PG', 'Rebounding', 'Rebound opportunities intentionally redirected to a teammate per game.', raw: ['tap_outs_per_game', 'tap_outs_pg'], providerNative: true),
  _m('deferred_rebounds_pg', 'Deferred Rebounds Per Game', 'DEFERR PG', 'Rebounding', 'Rebound opportunities intentionally left for a teammate per game.', raw: ['deferred_rebounds_per_game', 'deferred_rebounds_pg'], providerNative: true),

  _m('efg_pct', 'Effective Field Goal Percentage', 'eFG%', 'Efficiency', 'Field-goal percentage adjusted to value made threes as 1.5 made field goals.', engineKey: 'efg_pct', format: NbaTerminalMetricFormat.percent),
  _m('ts_pct', 'True Shooting Percentage', 'TS%', 'Efficiency', 'Scoring efficiency that incorporates twos, threes and free throws.', engineKey: 'ts_pct', format: NbaTerminalMetricFormat.percent),
  _m('ftr', 'Free Throw Rate', 'FTR', 'Efficiency', 'Free-throw attempts divided by field-goal attempts.', engineKey: 'ft_rate', format: NbaTerminalMetricFormat.percent),
  _m('three_par', 'Three-Point Attempt Rate', '3PAr', 'Efficiency', 'Three-point attempts divided by field-goal attempts.', engineKey: 'three_rate', format: NbaTerminalMetricFormat.percent),
  _m('pps', 'Points Per Shot', 'PPS', 'Efficiency', 'Points scored per field-goal attempt when source PPS is unavailable.', raw: ['points_per_shot', 'pps'], decimals: 2),
  _m('pie', 'Player Impact Estimate', 'PIE', 'Efficiency', 'NBA-style estimate of a player’s share of statistical game events.', raw: ['pie', 'player_impact_estimate'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('assisted_fg_pct', 'Assisted Field Goal Percentage', 'ASTD FG%', 'Efficiency', 'Share of made field goals that were assisted.', raw: ['assisted_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('unassisted_fg_pct', 'Unassisted Field Goal Percentage', 'UNAST FG%', 'Efficiency', 'Share of made field goals that were self-created without a credited assist.', raw: ['unassisted_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('assisted_ppg', 'Assisted Points Per Game', 'ASTD PPG', 'Efficiency', 'Points scored on assisted field goals per game.', raw: ['assisted_points_per_game', 'assisted_ppg'], providerNative: true),
  _m('unassisted_ppg', 'Unassisted Points Per Game', 'UNAST PPG', 'Efficiency', 'Points scored on unassisted field goals per game.', raw: ['unassisted_points_per_game', 'unassisted_ppg'], providerNative: true),

  _m('ortg', 'Offensive Rating', 'ORtg', 'Impact', 'Team points scored per 100 possessions while the player is on court, or source player ORtg.', raw: ['offensive_rating', 'ortg'], providerNative: true),
  _m('drtg', 'Defensive Rating', 'DRtg', 'Impact', 'Team points allowed per 100 possessions while the player is on court, or source player DRtg.', raw: ['defensive_rating', 'drtg'], higherIsBetter: false, providerNative: true),
  _m('net_rating', 'Net Rating', 'NET', 'Impact', 'Offensive rating minus defensive rating.', raw: ['net_rating', 'net_rtg'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('on_off', 'On/Off Differential', 'ON/OFF', 'Impact', 'Difference in team net rating with the player on the floor versus off the floor.', raw: ['on_off', 'on_off_differential', 'on_off_net_rating'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('pace', 'Pace', 'PACE', 'Impact', 'Estimated possessions per 48 minutes in the player’s on-court minutes.', raw: ['pace', 'pace_per_48'], providerNative: true),

  _m('per', 'Player Efficiency Rating', 'PER', 'Aggregate', 'Minute-adjusted box-score productivity metric standardized around league average.', raw: ['per', 'player_efficiency_rating'], providerNative: true),
  _m('bpm', 'Box Plus/Minus', 'BPM', 'Aggregate', 'Box-score estimate of points per 100 possessions above league average.', engineKey: 'bpm', raw: ['bpm', 'box_plus_minus'], children: ['obpm', 'dbpm'], format: NbaTerminalMetricFormat.signed),
  _m('obpm', 'Offensive Box Plus/Minus', 'OBPM', 'Aggregate', 'Offensive component of Box Plus/Minus.', raw: ['obpm', 'offensive_box_plus_minus'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('dbpm', 'Defensive Box Plus/Minus', 'DBPM', 'Aggregate', 'Defensive component of Box Plus/Minus.', raw: ['dbpm', 'defensive_box_plus_minus'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('vorp', 'Value Over Replacement Player', 'VORP', 'Aggregate', 'BPM-based estimate of total value above a replacement-level player.', raw: ['vorp', 'value_over_replacement_player'], providerNative: true),
  _m('ws', 'Win Shares', 'WS', 'Aggregate', 'Estimate of wins contributed using offensive and defensive box-score components.', raw: ['ws', 'win_shares'], providerNative: true),
  _m('epm', 'Estimated Plus-Minus', 'EPM', 'Aggregate', 'Estimated Plus-Minus value when supplied by an authorized source.', raw: ['epm', 'estimated_plus_minus'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('lebron', 'LEBRON', 'LEBRON', 'Aggregate', 'Luck-adjusted player impact estimate when supplied by an authorized source.', raw: ['lebron', 'lebron_metric'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('darko', 'DARKO', 'DARKO', 'Aggregate', 'DARKO player impact estimate when supplied by an authorized source.', raw: ['darko', 'darko_metric'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('rapm', 'Regularized Adjusted Plus-Minus', 'RAPM', 'Aggregate', 'Regularized adjusted plus-minus estimate controlling for teammates and opponents.', raw: ['rapm'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('la_rapm', 'Luck-Adjusted RAPM', 'LA-RAPM', 'Aggregate', 'RAPM variant using luck-adjusted scoring inputs when supplied by a model source.', raw: ['la_rapm', 'luck_adjusted_rapm'], format: NbaTerminalMetricFormat.signed, providerNative: true),
  _m('warv', 'Wins Above Replacement Value', 'WARV', 'Aggregate', 'Model estimate of wins created above a replacement-level player.', raw: ['warv', 'wins_above_replacement_value'], providerNative: true),

  _m('usage', 'Usage Rate', 'USG%', 'Movement', 'Estimated share of team possessions used by the player while on court.', raw: ['usage', 'usage_pct', 'usg_pct'], engineKey: 'scoring_load', format: NbaTerminalMetricFormat.percent),
  _m('distance_traveled', 'Distance Traveled', 'DIST', 'Movement', 'Tracked distance covered by the player over the selected sample.', raw: ['distance_traveled', 'distance_miles', 'distance'], providerNative: true),
  _m('average_speed', 'Average Speed', 'AVG SPD', 'Movement', 'Tracked average player speed while on the floor.', raw: ['average_speed', 'avg_speed'], providerNative: true),
  _m('time_per_touch', 'Time Per Touch', 'SEC/TOUCH', 'Movement', 'Average seconds the player controls the ball per touch.', raw: ['time_per_touch', 'avg_seconds_per_touch'], format: NbaTerminalMetricFormat.seconds, providerNative: true),
  _m('dribbles_per_touch', 'Dribbles Per Touch', 'DRIB/TOUCH', 'Movement', 'Average dribbles taken per tracked touch.', raw: ['dribbles_per_touch', 'avg_dribbles_per_touch'], providerNative: true),
  _m('freeze_time', 'Freeze Time', 'FREEZE', 'Movement', 'Tracked time defenders remain committed or stationary because of the player’s action.', raw: ['freeze_time', 'freeze_time_seconds'], format: NbaTerminalMetricFormat.seconds, providerNative: true),
  _m('scoring_decision_time', 'Scoring Decision Time', 'SCORE DT', 'Movement', 'Average time from gaining possession to committing to a shot attempt.', raw: ['scoring_decision_time'], format: NbaTerminalMetricFormat.seconds, providerNative: true),
  _m('driving_decision_time', 'Driving Decision Time', 'DRIVE DT', 'Movement', 'Average time from gaining possession to committing to a drive.', raw: ['driving_decision_time'], format: NbaTerminalMetricFormat.seconds, providerNative: true),

  _m('clutch_ppg', 'Clutch Points Per Game', 'CPPG', 'Clutch', 'Points per source-defined clutch game or clutch appearance.', raw: ['clutch_ppg', 'clutch_points_per_game'], providerNative: true),
  _m('clutch_rpg', 'Clutch Rebounds Per Game', 'CRPG', 'Clutch', 'Rebounds per source-defined clutch game or clutch appearance.', raw: ['clutch_rpg', 'clutch_rebounds_per_game'], providerNative: true),
  _m('clutch_apg', 'Clutch Assists Per Game', 'CAPG', 'Clutch', 'Assists per source-defined clutch game or clutch appearance.', raw: ['clutch_apg', 'clutch_assists_per_game'], providerNative: true),
  _m('clutch_spg', 'Clutch Steals Per Game', 'CSPG', 'Clutch', 'Steals per source-defined clutch game or clutch appearance.', raw: ['clutch_spg'], providerNative: true),
  _m('clutch_bpg', 'Clutch Blocks Per Game', 'CBPG', 'Clutch', 'Blocks per source-defined clutch game or clutch appearance.', raw: ['clutch_bpg'], providerNative: true),
  _m('clutch_fg_pct', 'Clutch Field Goal Percentage', 'C FG%', 'Clutch', 'Field-goal percentage in source-defined clutch possessions.', raw: ['clutch_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('clutch_three_pct', 'Clutch Three-Point Percentage', 'C 3P%', 'Clutch', 'Three-point percentage in source-defined clutch possessions.', raw: ['clutch_three_pct', 'clutch_3p_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('clutch_ft_pct', 'Clutch Free Throw Percentage', 'C FT%', 'Clutch', 'Free-throw percentage in source-defined clutch possessions.', raw: ['clutch_ft_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('clutch_net_rating', 'Clutch Net Rating', 'C NET', 'Clutch', 'Team net rating during source-defined clutch minutes.', raw: ['clutch_net_rating'], format: NbaTerminalMetricFormat.signed, providerNative: true),

  _m('rim_frequency', 'Rim Frequency', 'RIM FREQ', 'Shot Profile', 'Share of field-goal attempts taken at the rim.', raw: ['rim_frequency', 'rim_freq'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('rim_fg_pct', 'Rim Field Goal Percentage', 'RIM FG%', 'Shot Profile', 'Field-goal percentage on attempts at the rim.', raw: ['rim_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('paint_frequency', 'Paint Frequency', 'PAINT FREQ', 'Shot Profile', 'Share of field-goal attempts taken in the paint.', raw: ['paint_frequency', 'paint_freq'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('paint_fg_pct', 'Paint Field Goal Percentage', 'PAINT FG%', 'Shot Profile', 'Field-goal percentage on paint attempts.', raw: ['paint_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('midrange_frequency', 'Midrange Frequency', 'MID FREQ', 'Shot Profile', 'Share of field-goal attempts classified as midrange.', raw: ['midrange_frequency', 'midrange_freq'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('midrange_fg_pct', 'Midrange Field Goal Percentage', 'MID FG%', 'Shot Profile', 'Field-goal percentage on midrange attempts.', raw: ['midrange_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('three_frequency', 'Three-Point Frequency', '3P FREQ', 'Shot Profile', 'Share of field-goal attempts taken from three-point range.', raw: ['three_frequency', 'three_point_frequency'], engineKey: 'three_rate', format: NbaTerminalMetricFormat.percent),
  _m('halfcourt_frequency', 'Halfcourt Frequency', 'HC FREQ', 'Shot Profile', 'Share of offensive possessions ending in a halfcourt shot attempt.', raw: ['halfcourt_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('halfcourt_fg_pct', 'Halfcourt Field Goal Percentage', 'HC FG%', 'Shot Profile', 'Field-goal percentage on halfcourt attempts.', raw: ['halfcourt_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('heaves_pg', 'Heaves Per Game', 'HPG', 'Shot Profile', 'Long-distance end-of-period heave attempts per game.', raw: ['heaves_per_game', 'heaves_pg'], providerNative: true),
  _m('corner_three_frequency', 'Corner Three Frequency', 'C3 FREQ', 'Shot Profile', 'Share of attempts taken from either corner three location.', raw: ['corner_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('corner_three_pct', 'Corner Three Percentage', 'C3%', 'Shot Profile', 'Three-point percentage from either corner.', raw: ['corner_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('right_corner_three_frequency', 'Right Corner Three Frequency', 'RC3 FREQ', 'Shot Profile', 'Share of attempts taken from the right corner.', raw: ['right_corner_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('right_corner_three_pct', 'Right Corner Three Percentage', 'RC3%', 'Shot Profile', 'Three-point percentage from the right corner.', raw: ['right_corner_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('left_corner_three_frequency', 'Left Corner Three Frequency', 'LC3 FREQ', 'Shot Profile', 'Share of attempts taken from the left corner.', raw: ['left_corner_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('left_corner_three_pct', 'Left Corner Three Percentage', 'LC3%', 'Shot Profile', 'Three-point percentage from the left corner.', raw: ['left_corner_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('catch_shoot_three_frequency', 'Catch-and-Shoot Three Frequency', 'C&S FREQ', 'Shot Profile', 'Share of attempts that are catch-and-shoot threes.', raw: ['catch_shoot_three_frequency', 'catch_and_shoot_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('catch_shoot_three_pct', 'Catch-and-Shoot Three Percentage', 'C&S 3P%', 'Shot Profile', 'Three-point percentage on catch-and-shoot attempts.', raw: ['catch_shoot_three_pct', 'catch_and_shoot_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('pull_up_three_frequency', 'Pull-Up Three Frequency', 'PU3 FREQ', 'Shot Profile', 'Share of attempts that are pull-up threes.', raw: ['pull_up_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('pull_up_three_pct', 'Pull-Up Three Percentage', 'PU3%', 'Shot Profile', 'Three-point percentage on pull-up attempts.', raw: ['pull_up_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('right_wing_three_frequency', 'Right Wing Three Frequency', 'RW3 FREQ', 'Shot Profile', 'Share of attempts taken from the right wing.', raw: ['right_wing_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('right_wing_three_pct', 'Right Wing Three Percentage', 'RW3%', 'Shot Profile', 'Three-point percentage from the right wing.', raw: ['right_wing_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('left_wing_three_frequency', 'Left Wing Three Frequency', 'LW3 FREQ', 'Shot Profile', 'Share of attempts taken from the left wing.', raw: ['left_wing_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('left_wing_three_pct', 'Left Wing Three Percentage', 'LW3%', 'Shot Profile', 'Three-point percentage from the left wing.', raw: ['left_wing_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('wing_three_frequency', 'Wing Three Frequency', 'WING FREQ', 'Shot Profile', 'Share of attempts taken from either wing.', raw: ['wing_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('wing_three_pct', 'Wing Three Percentage', 'WING 3P%', 'Shot Profile', 'Three-point percentage from the wings.', raw: ['wing_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('middle_three_frequency', 'Middle Three Frequency', 'TOP3 FREQ', 'Shot Profile', 'Share of attempts taken from the middle or top-of-key three area.', raw: ['middle_three_frequency', 'top_three_frequency'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('middle_three_pct', 'Middle Three Percentage', 'TOP3%', 'Shot Profile', 'Three-point percentage from the middle or top-of-key area.', raw: ['middle_three_pct', 'top_three_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('dunks_pg', 'Dunks Per Game', 'DUNK PG', 'Shot Profile', 'Made or attempted dunks per game according to the source definition.', raw: ['dunks_per_game', 'dunks_pg'], providerNative: true),
  _m('dunk_fg_pct', 'Dunk Field Goal Percentage', 'DUNK FG%', 'Shot Profile', 'Field-goal percentage on dunk attempts.', raw: ['dunk_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('layups_pg', 'Layups Per Game', 'LAYUP PG', 'Shot Profile', 'Layup attempts or makes per game according to the source definition.', raw: ['layups_per_game', 'layups_pg'], providerNative: true),
  _m('layup_fg_pct', 'Layup Field Goal Percentage', 'LAYUP FG%', 'Shot Profile', 'Field-goal percentage on layup attempts.', raw: ['layup_fg_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),

  _m('isolation_ppp', 'Isolation Points Per Possession', 'ISO PPP', 'Play Type', 'Points scored per isolation possession.', raw: ['isolation_ppp', 'iso_ppp'], decimals: 2, providerNative: true),
  _m('transition_ppp', 'Transition Points Per Possession', 'TRANS PPP', 'Play Type', 'Points scored per transition possession.', raw: ['transition_ppp'], decimals: 2, providerNative: true),
  _m('transition_offense_ppp', 'Transition Offensive PPP', 'TRANS O', 'Play Type', 'Offensive points per transition possession.', raw: ['transition_offense_ppp'], decimals: 2, providerNative: true),
  _m('transition_defense_ppp', 'Transition Defensive PPP', 'TRANS D', 'Play Type', 'Opponent points per transition possession while this player is the primary tracked defender or on court.', raw: ['transition_defense_ppp'], decimals: 2, higherIsBetter: false, providerNative: true),
  _m('pnr_ball_handler_ppp', 'Pick-and-Roll Ball Handler PPP', 'PnR BH', 'Play Type', 'Points per possession when the player is the pick-and-roll ball handler.', raw: ['pnr_ball_handler_ppp', 'pick_roll_ball_handler_ppp'], decimals: 2, providerNative: true),
  _m('pnr_roll_man_ppp', 'Pick-and-Roll Roll Man PPP', 'PnR RM', 'Play Type', 'Points per possession when the player is the roll man.', raw: ['pnr_roll_man_ppp', 'pick_roll_roll_man_ppp'], decimals: 2, providerNative: true),
  _m('post_up_ppp', 'Post-Up Points Per Possession', 'POST PPP', 'Play Type', 'Points scored per post-up possession.', raw: ['post_up_ppp', 'postup_ppp'], decimals: 2, providerNative: true),
  _m('spot_up_ppp', 'Spot-Up Points Per Possession', 'SPOT PPP', 'Play Type', 'Points scored per spot-up possession.', raw: ['spot_up_ppp', 'spotup_ppp'], decimals: 2, providerNative: true),
  _m('drive_ppg', 'Drive Points Per Game', 'DRIVE PPG', 'Play Type', 'Points scored from tracked drives per game.', raw: ['drive_points_per_game', 'drive_ppg'], providerNative: true),
  _m('drive_apg', 'Drive Assists Per Game', 'DRIVE APG', 'Play Type', 'Assists generated from tracked drives per game.', raw: ['drive_assists_per_game', 'drive_apg'], providerNative: true),
  _m('backdoor_cut_pg', 'Backdoor Cuts Per Game', 'BACKDOOR', 'Play Type', 'Tracked backdoor cuts per game.', raw: ['backdoor_cuts_per_game'], providerNative: true),
  _m('v_cut_pg', 'V-Cuts Per Game', 'V-CUT PG', 'Play Type', 'Tracked V-cuts per game.', raw: ['v_cuts_per_game'], providerNative: true),
  _m('l_cut_pg', 'L-Cuts Per Game', 'L-CUT PG', 'Play Type', 'Tracked L-cuts per game.', raw: ['l_cuts_per_game'], providerNative: true),

  _m('offensive_gravity', 'Offensive Gravity', 'OFF GRAV', 'Creation', 'Model estimate of how strongly a player pulls defenders and changes team spacing.', raw: ['offensive_gravity'], providerNative: true),
  _m('shot_gravity', 'Shot Gravity', 'SHOT GRAV', 'Creation', 'Model estimate of defensive attention created by the threat of the player’s shot.', raw: ['shot_gravity'], providerNative: true),
  _m('drive_gravity', 'Drive Gravity', 'DRIVE GRAV', 'Creation', 'Model estimate of defensive attention created by the threat of the player’s drive.', raw: ['drive_gravity'], providerNative: true),
  _m('screens_set_pg', 'Screens Set Per Game', 'SCR SET PG', 'Creation', 'Tracked screens set by the player per game.', raw: ['screens_set_per_game', 'screens_set_pg'], providerNative: true),
  _m('screens_used_pg', 'Screens Used Per Game', 'SCR USE PG', 'Creation', 'Tracked screens used by the player as the ball handler per game.', raw: ['screens_used_per_game', 'screens_used_pg'], providerNative: true),

  _m('height', 'Height', 'HEIGHT', 'Physical', 'Measured player height.', raw: ['height_inches', 'height'], format: NbaTerminalMetricFormat.inches, providerNative: true),
  _m('weight', 'Weight', 'WEIGHT', 'Physical', 'Measured player weight.', raw: ['weight_lbs', 'weight'], format: NbaTerminalMetricFormat.pounds, providerNative: true),
  _m('wingspan', 'Wingspan', 'WINGSPAN', 'Physical', 'Measured fingertip-to-fingertip wingspan.', raw: ['wingspan_inches', 'wingspan'], format: NbaTerminalMetricFormat.inches, providerNative: true),
  _m('standing_reach', 'Standing Reach', 'ST REACH', 'Physical', 'Measured standing reach.', raw: ['standing_reach_inches', 'standing_reach'], format: NbaTerminalMetricFormat.inches, providerNative: true),
  _m('hand_length', 'Hand Length', 'HAND L', 'Physical', 'Measured hand length.', raw: ['hand_length_inches', 'hand_length'], format: NbaTerminalMetricFormat.inches, providerNative: true),
  _m('hand_width', 'Hand Width', 'HAND W', 'Physical', 'Measured hand width.', raw: ['hand_width_inches', 'hand_width'], format: NbaTerminalMetricFormat.inches, providerNative: true),
  _m('standing_jump', 'Standing Vertical Jump', 'ST VERT', 'Physical', 'Measured standing vertical jump.', raw: ['standing_vertical_jump', 'standing_jump'], format: NbaTerminalMetricFormat.inches, providerNative: true),
  _m('max_vertical_jump', 'Maximum Vertical Jump', 'MAX VERT', 'Physical', 'Measured maximum vertical jump.', raw: ['max_vertical_jump', 'max_vertical'], format: NbaTerminalMetricFormat.inches, providerNative: true),

  _m('technical_fouls', 'Technical Fouls', 'TECH', 'Discipline', 'Technical fouls assessed to the player.', raw: ['technical_fouls', 'tech_fouls'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('shooting_fouls', 'Shooting Fouls', 'SHOOT F', 'Discipline', 'Shooting fouls committed by the player.', raw: ['shooting_fouls'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('personal_fouls', 'Personal Fouls', 'PF', 'Discipline', 'Personal fouls committed by the player.', engineKey: 'pf', higherIsBetter: false),
  _m('offensive_fouls', 'Offensive Fouls', 'OFF F', 'Discipline', 'Offensive fouls committed by the player.', raw: ['offensive_fouls'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('defensive_fouls', 'Defensive Fouls', 'DEF F', 'Discipline', 'Defensive fouls committed by the player.', raw: ['defensive_fouls'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('other_fouls', 'Other Fouls', 'OTHER F', 'Discipline', 'Other foul classifications recorded by the source.', raw: ['other_fouls'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('ejections', 'Ejections', 'EJECT', 'Discipline', 'Games or incidents in which the player is ejected.', raw: ['ejections'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('disqualifications', 'Disqualifications', 'DQ', 'Discipline', 'Games in which the player is disqualified under the source definition.', raw: ['disqualifications'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('suspensions', 'Suspensions', 'SUSP', 'Discipline', 'Games or incidents resulting in suspension.', raw: ['suspensions', 'suspension_games'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('whistle_reaction', 'Whistle-Reaction Metric', 'WHISTLE', 'Discipline', 'Model or tracking measure of player behavior immediately after whistles.', raw: ['whistle_reaction'], providerNative: true),
  _m('game_buzzer_beaters', 'Game Buzzer Beaters', 'GAME BB', 'Discipline', 'Made shots beating the final game buzzer.', raw: ['game_buzzer_beaters'], format: NbaTerminalMetricFormat.integer, providerNative: true),
  _m('quarter_buzzer_beaters', 'Quarter Buzzer Beaters', 'QTR BB', 'Discipline', 'Made shots beating a quarter or period buzzer.', raw: ['quarter_buzzer_beaters'], format: NbaTerminalMetricFormat.integer, providerNative: true),
  _m('shot_clock_buzzer_beaters', 'Shot Clock Buzzer Beaters', 'SC BB', 'Discipline', 'Made shots released immediately before shot-clock expiration.', raw: ['shot_clock_buzzer_beaters'], format: NbaTerminalMetricFormat.integer, providerNative: true),

  _m('availability_pct', 'Availability Percentage', 'AVAIL%', 'Availability', 'Share of team games for which the player is available to play.', raw: ['availability_pct'], format: NbaTerminalMetricFormat.percent, providerNative: true),
  _m('games_missed_injury', 'Games Missed — Injury', 'GM INJ', 'Availability', 'Games missed because of recorded injuries.', raw: ['games_missed_injury', 'injury_games_missed'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('injury_events', 'Injury Events', 'INJ EVT', 'Availability', 'Distinct recorded injury events in the selected sample.', raw: ['injury_events', 'injury_count'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('days_missed', 'Days Missed', 'DAYS OUT', 'Availability', 'Calendar days missed because of recorded injuries.', raw: ['days_missed', 'injury_days_missed'], format: NbaTerminalMetricFormat.integer, higherIsBetter: false, providerNative: true),
  _m('injury_rate', 'Injury Rate', 'INJ RATE', 'Availability', 'Recorded injury events relative to the selected exposure basis.', raw: ['injury_rate'], format: NbaTerminalMetricFormat.percent, higherIsBetter: false, providerNative: true),
];

final Map<String, NbaTerminalMetric> nbaTerminalMetricByKey = {
  for (final metric in nbaTerminalMetrics) metric.key: metric,
};

NbaTerminalStatFamily nbaTerminalFamily(String id) =>
    nbaTerminalStatFamilies.firstWhere(
      (family) => family.id == id,
      orElse: () => nbaTerminalStatFamilies.first,
    );

List<String> nbaVisibleMetricKeys(
  NbaTerminalStatFamily family,
  Set<String> expanded,
) {
  final output = <String>[];
  for (final key in family.metrics) {
    output.add(key);
    final metric = nbaTerminalMetricByKey[key];
    if (metric != null && expanded.contains(key)) {
      output.addAll(family.expansionOverrides[key] ?? metric.children);
    }
  }
  return output;
}

class NbaTerminalMetricResolver {
  const NbaTerminalMetricResolver();

  double? value(NbaStatsRow row, String key) {
    final metric = nbaTerminalMetricByKey[key];
    if (metric == null) return null;

    final raw = _rawValue(row.raw, metric.rawAliases);
    if (raw != null) return _normalize(metric, raw);

    if (metric.engineKey != null) {
      final value = row.value(metric.engineKey!);
      if (value != null) return value;
    }

    switch (key) {
      case 'pps':
        final points = row.value('pts');
        final attempts = row.value('fga');
        if (points != null && attempts != null && attempts > 0) {
          return points / attempts;
        }
      case 'net_rating':
        final offense = value(row, 'ortg');
        final defense = value(row, 'drtg');
        if (offense != null && defense != null) return offense - defense;
      case 'contested_rpg':
        final offense = value(row, 'contested_orb_pg');
        final defense = value(row, 'contested_dreb_pg');
        if (offense != null || defense != null) return (offense ?? 0) + (defense ?? 0);
      case 'uncontested_rpg':
        final offense = value(row, 'uncontested_orb_pg');
        final defense = value(row, 'uncontested_dreb_pg');
        if (offense != null || defense != null) return (offense ?? 0) + (defense ?? 0);
    }
    return null;
  }

  String format(NbaStatsRow row, String key) {
    final metric = nbaTerminalMetricByKey[key];
    if (metric == null) return '—';
    final resolved = value(row, key);
    if (resolved == null || !resolved.isFinite) return '—';
    switch (metric.format) {
      case NbaTerminalMetricFormat.integer:
        return resolved.round().toString();
      case NbaTerminalMetricFormat.percent:
        return '${(resolved * 100).toStringAsFixed(metric.decimals)}%';
      case NbaTerminalMetricFormat.signed:
        return '${resolved >= 0 ? '+' : ''}${resolved.toStringAsFixed(metric.decimals)}';
      case NbaTerminalMetricFormat.seconds:
        return '${resolved.toStringAsFixed(metric.decimals)}s';
      case NbaTerminalMetricFormat.inches:
        return '${resolved.toStringAsFixed(metric.decimals)} in';
      case NbaTerminalMetricFormat.pounds:
        return '${resolved.toStringAsFixed(metric.decimals)} lb';
      case NbaTerminalMetricFormat.decimal:
        return resolved.toStringAsFixed(metric.decimals);
    }
  }

  bool isAvailable(NbaStatsRow row, String key) => value(row, key) != null;

  double? _rawValue(Map<String, dynamic> row, List<String> aliases) {
    for (final alias in aliases) {
      final direct = row[alias];
      final parsed = _number(direct);
      if (parsed != null) return parsed;
      for (final entry in row.entries) {
        if (_normalizeKey(entry.key) == _normalizeKey(alias)) {
          final candidate = _number(entry.value);
          if (candidate != null) return candidate;
        }
      }
    }
    return null;
  }

  double _normalize(NbaTerminalMetric metric, double value) {
    if (metric.format == NbaTerminalMetricFormat.percent && value.abs() > 1.0) {
      return value / 100;
    }
    return value;
  }
}

double? _number(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final cleaned = value
      .toString()
      .replaceAll(',', '')
      .replaceAll('%', '')
      .replaceAll('lb', '')
      .replaceAll('lbs', '')
      .replaceAll('in', '')
      .trim();
  return double.tryParse(cleaned);
}

String _normalizeKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
