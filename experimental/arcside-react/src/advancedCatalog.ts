// Generated from Flutter reference: lib/services/nba_stats_metric_catalog.dart
// and lib/screens/website_nba_advanced_stats_v4_screen.dart (Phase 3 pilot).
// Provider-native fields must remain unavailable when absent in the v5 shard.
export type AdvancedMetric = {key:string;label:string;description:string;engine:string|null;raw:string[];children:string[];format:string;decimals:number};
export type AdvancedGroup = {name:string;description:string;keys:string[]};
export const advancedMetricCatalog:Record<string,AdvancedMetric> = {
 "gp": {
  "key": "gp",
  "label": "GP",
  "description": "Games played in the selected season segment.",
  "engine": "gp",
  "raw": [],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "mpg": {
  "key": "mpg",
  "label": "MPG",
  "description": "Average minutes played per game.",
  "engine": "min",
  "raw": [
   "mpg",
   "minutes_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "ppg": {
  "key": "ppg",
  "label": "PPG",
  "description": "Points scored under the selected rate basis.",
  "engine": "pts",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "rpg": {
  "key": "rpg",
  "label": "RPG",
  "description": "Total rebounds under the selected rate basis.",
  "engine": "reb",
  "raw": [],
  "children": [
   "oreb",
   "dreb"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "oreb": {
  "key": "oreb",
  "label": "ORB",
  "description": "Offensive rebounds under the selected rate basis.",
  "engine": "oreb",
  "raw": [],
  "children": [
   "contested_orb_pg",
   "uncontested_orb_pg",
   "orb_pct"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "dreb": {
  "key": "dreb",
  "label": "DRB",
  "description": "Defensive rebounds under the selected rate basis.",
  "engine": "dreb",
  "raw": [],
  "children": [
   "contested_dreb_pg",
   "uncontested_dreb_pg",
   "drb_pct"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "apg": {
  "key": "apg",
  "label": "APG",
  "description": "Assists under the selected rate basis.",
  "engine": "ast",
  "raw": [],
  "children": [
   "ast_pct"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "spg": {
  "key": "spg",
  "label": "SPG",
  "description": "Steals under the selected rate basis.",
  "engine": "stl",
  "raw": [],
  "children": [
   "stl_pct"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "bpg": {
  "key": "bpg",
  "label": "BPG",
  "description": "Blocks under the selected rate basis.",
  "engine": "blk",
  "raw": [],
  "children": [
   "blk_pct"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "tpg": {
  "key": "tpg",
  "label": "TPG",
  "description": "Turnovers under the selected rate basis.",
  "engine": "tov",
  "raw": [],
  "children": [
   "tov_pct"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "pf": {
  "key": "pf",
  "label": "PF",
  "description": "Personal fouls under the selected rate basis.",
  "engine": "pf",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "fg_pct": {
  "key": "fg_pct",
  "label": "FG%",
  "description": "Field goals made divided by field-goal attempts.",
  "engine": "fg_pct",
  "raw": [],
  "children": [
   "fgm",
   "fga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "fgm": {
  "key": "fgm",
  "label": "FGM",
  "description": "Field goals made under the selected rate basis.",
  "engine": "fgm",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "fga": {
  "key": "fga",
  "label": "FGA",
  "description": "Field-goal attempts under the selected rate basis.",
  "engine": "fga",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "two_pct": {
  "key": "two_pct",
  "label": "2P%",
  "description": "Two-point field goals made divided by two-point attempts.",
  "engine": "two_pct",
  "raw": [],
  "children": [
   "two_pm",
   "two_pa"
  ],
  "format": "percent",
  "decimals": 1
 },
 "two_pm": {
  "key": "two_pm",
  "label": "2PM",
  "description": "Two-point field goals made under the selected rate basis.",
  "engine": "two_pm",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "two_pa": {
  "key": "two_pa",
  "label": "2PA",
  "description": "Two-point field-goal attempts under the selected rate basis.",
  "engine": "two_pa",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "three_pct": {
  "key": "three_pct",
  "label": "3P%",
  "description": "Three-pointers made divided by three-point attempts.",
  "engine": "three_pct",
  "raw": [],
  "children": [
   "three_pm",
   "three_pa"
  ],
  "format": "percent",
  "decimals": 1
 },
 "three_pm": {
  "key": "three_pm",
  "label": "3PM",
  "description": "Three-pointers made under the selected rate basis.",
  "engine": "three_pm",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "three_pa": {
  "key": "three_pa",
  "label": "3PA",
  "description": "Three-point attempts under the selected rate basis.",
  "engine": "three_pa",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "ft_pct": {
  "key": "ft_pct",
  "label": "FT%",
  "description": "Free throws made divided by free-throw attempts.",
  "engine": "ft_pct",
  "raw": [],
  "children": [
   "ftm",
   "fta"
  ],
  "format": "percent",
  "decimals": 1
 },
 "ftm": {
  "key": "ftm",
  "label": "FTM",
  "description": "Free throws made under the selected rate basis.",
  "engine": "ftm",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "fta": {
  "key": "fta",
  "label": "FTA",
  "description": "Free-throw attempts under the selected rate basis.",
  "engine": "fta",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "stl_pct": {
  "key": "stl_pct",
  "label": "STL%",
  "description": "Estimated percentage of opponent possessions ending in a steal while the player is on court.",
  "engine": null,
  "raw": [
   "stl_pct",
   "steal_pct",
   "steal_percentage"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "blk_pct": {
  "key": "blk_pct",
  "label": "BLK%",
  "description": "Estimated percentage of opponent two-point attempts blocked while the player is on court.",
  "engine": null,
  "raw": [
   "blk_pct",
   "block_pct",
   "block_percentage"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "deflections_pg": {
  "key": "deflections_pg",
  "label": "Deflections PG",
  "description": "Deflections credited to the player per game.",
  "engine": null,
  "raw": [
   "deflections_per_game",
   "deflections_pg",
   "avg_deflections"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "contested_dreb_pg": {
  "key": "contested_dreb_pg",
  "label": "Contested DRB PG",
  "description": "Defensive rebounds secured with an opponent contest nearby.",
  "engine": null,
  "raw": [
   "contested_dreb_pg",
   "contested_defensive_rebounds_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "uncontested_dreb_pg": {
  "key": "uncontested_dreb_pg",
  "label": "Uncontested DRB PG",
  "description": "Defensive rebounds secured without a nearby opponent contest.",
  "engine": null,
  "raw": [
   "uncontested_dreb_pg",
   "uncontested_defensive_rebounds_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "charges_drawn_pg": {
  "key": "charges_drawn_pg",
  "label": "Charges PG",
  "description": "Offensive fouls drawn as charges per game.",
  "engine": null,
  "raw": [
   "charges_drawn_per_game",
   "charges_drawn_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "contested_shots_pg": {
  "key": "contested_shots_pg",
  "label": "Contested Shots PG",
  "description": "Opponent shot attempts contested by the player per game.",
  "engine": null,
  "raw": [
   "contested_shots_per_game",
   "contested_shots_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "loose_balls_recovered_pg": {
  "key": "loose_balls_recovered_pg",
  "label": "Loose Balls Recovered PG",
  "description": "Loose balls recovered by the player per game.",
  "engine": null,
  "raw": [
   "loose_balls_recovered_per_game",
   "loose_balls_recovered_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "hustle_gp": {
  "key": "hustle_gp",
  "label": "HUSTLE GP",
  "description": "Games with NBA.com hustle tracking; may differ from season games.",
  "engine": null,
  "raw": [
   "hustle_gp"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "hustle_minutes": {
  "key": "hustle_minutes",
  "label": "HUSTLE MIN",
  "description": "Total minutes in NBA.com hustle tracking for the selected season and season type.",
  "engine": null,
  "raw": [
   "hustle_minutes"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "hustle_mpg": {
  "key": "hustle_mpg",
  "label": "HUSTLE MPG",
  "description": "Tracked minutes divided by hustle games.",
  "engine": null,
  "raw": [
   "hustle_mpg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "contested_twos_pg": {
  "key": "contested_twos_pg",
  "label": "2PT CONT PG",
  "description": "Tracked two-point shots contested per hustle game.",
  "engine": null,
  "raw": [
   "contested_twos_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "contested_threes_pg": {
  "key": "contested_threes_pg",
  "label": "3PT CONT PG",
  "description": "Tracked three-point shots contested per hustle game.",
  "engine": null,
  "raw": [
   "contested_threes_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "screen_assist_points_pg": {
  "key": "screen_assist_points_pg",
  "label": "SCR PTS PG",
  "description": "Points generated from screen assists per hustle game.",
  "engine": null,
  "raw": [
   "screen_assist_points_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "off_loose_balls_recovered_pg": {
  "key": "off_loose_balls_recovered_pg",
  "label": "OFF LBR PG",
  "description": "Offensive loose balls recovered per hustle game.",
  "engine": null,
  "raw": [
   "off_loose_balls_recovered_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "def_loose_balls_recovered_pg": {
  "key": "def_loose_balls_recovered_pg",
  "label": "DEF LBR PG",
  "description": "Defensive loose balls recovered per hustle game.",
  "engine": null,
  "raw": [
   "def_loose_balls_recovered_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "loose_ball_off_pct": {
  "key": "loose_ball_off_pct",
  "label": "OFF LBR%",
  "description": "NBA.com offensive percentage of loose balls recovered.",
  "engine": null,
  "raw": [
   "loose_ball_off_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "loose_ball_def_pct": {
  "key": "loose_ball_def_pct",
  "label": "DEF LBR%",
  "description": "NBA.com defensive percentage of loose balls recovered.",
  "engine": null,
  "raw": [
   "loose_ball_def_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "off_box_outs_pg": {
  "key": "off_box_outs_pg",
  "label": "OFF BOX PG",
  "description": "Offensive box outs per hustle game.",
  "engine": null,
  "raw": [
   "off_box_outs_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "def_box_outs_pg": {
  "key": "def_box_outs_pg",
  "label": "DEF BOX PG",
  "description": "Defensive box outs per hustle game.",
  "engine": null,
  "raw": [
   "def_box_outs_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "box_out_team_rebounds_pg": {
  "key": "box_out_team_rebounds_pg",
  "label": "TEAM REB PG",
  "description": "Box outs on which the player’s team recovered the rebound per hustle game.",
  "engine": null,
  "raw": [
   "box_out_team_rebounds_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "box_out_player_rebounds_pg": {
  "key": "box_out_player_rebounds_pg",
  "label": "OWN REB PG",
  "description": "Box outs on which this player recovered the rebound per hustle game.",
  "engine": null,
  "raw": [
   "box_out_player_rebounds_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "off_box_out_pct": {
  "key": "off_box_out_pct",
  "label": "OFF BOX%",
  "description": "Share of player box outs recorded on offense.",
  "engine": null,
  "raw": [
   "off_box_out_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "def_box_out_pct": {
  "key": "def_box_out_pct",
  "label": "DEF BOX%",
  "description": "Share of player box outs recorded on defense.",
  "engine": null,
  "raw": [
   "def_box_out_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "box_out_team_reb_pct": {
  "key": "box_out_team_reb_pct",
  "label": "TEAM BOX%",
  "description": "Fraction of box outs on which the player’s team gets the rebound.",
  "engine": null,
  "raw": [
   "box_out_team_reb_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "dfg_pct": {
  "key": "dfg_pct",
  "label": "DFG%",
  "description": "Opponent field-goal percentage on attempts for which the player is the recorded defender.",
  "engine": null,
  "raw": [
   "dfg_pct",
   "defended_field_goal_pct"
  ],
  "children": [
   "dfgm",
   "dfga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "dfgm": {
  "key": "dfgm",
  "label": "DFGM",
  "description": "Opponent makes on shots attributed to this defender.",
  "engine": null,
  "raw": [
   "dfgm",
   "defended_field_goals_made"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "dfga": {
  "key": "dfga",
  "label": "DFGA",
  "description": "Opponent attempts on shots attributed to this defender.",
  "engine": null,
  "raw": [
   "dfga",
   "defended_field_goal_attempts"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "rim_dfg_pct": {
  "key": "rim_dfg_pct",
  "label": "Rim DFG%",
  "description": "Opponent field-goal percentage at the rim when this player is the defender.",
  "engine": null,
  "raw": [
   "rim_dfg_pct",
   "rim_defended_fg_pct"
  ],
  "children": [
   "rim_dfgm",
   "rim_dfga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "rim_dfgm": {
  "key": "rim_dfgm",
  "label": "Rim DFGM",
  "description": "Opponent makes at the rim attributed to this defender.",
  "engine": null,
  "raw": [
   "rim_dfgm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "rim_dfga": {
  "key": "rim_dfga",
  "label": "Rim DFGA",
  "description": "Opponent rim attempts attributed to this defender.",
  "engine": null,
  "raw": [
   "rim_dfga"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "midrange_dfg_pct": {
  "key": "midrange_dfg_pct",
  "label": "Midrange DFG%",
  "description": "Opponent midrange field-goal percentage when this player is the defender.",
  "engine": null,
  "raw": [
   "midrange_dfg_pct"
  ],
  "children": [
   "midrange_dfgm",
   "midrange_dfga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "midrange_dfgm": {
  "key": "midrange_dfgm",
  "label": "Midrange DFGM",
  "description": "Opponent midrange makes attributed to this defender when supplied by the source.",
  "engine": null,
  "raw": [
   "midrange_dfgm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "midrange_dfga": {
  "key": "midrange_dfga",
  "label": "Midrange DFGA",
  "description": "Opponent midrange attempts attributed to this defender when supplied by the source.",
  "engine": null,
  "raw": [
   "midrange_dfga"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "three_dfg_pct": {
  "key": "three_dfg_pct",
  "label": "3P DFG%",
  "description": "Opponent three-point percentage when this player is the defender.",
  "engine": null,
  "raw": [
   "three_dfg_pct",
   "three_point_dfg_pct"
  ],
  "children": [
   "three_dfgm",
   "three_dfga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "three_dfgm": {
  "key": "three_dfgm",
  "label": "3P DFGM",
  "description": "Opponent three-point makes attributed to this defender.",
  "engine": null,
  "raw": [
   "three_dfgm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "three_dfga": {
  "key": "three_dfga",
  "label": "3P DFGA",
  "description": "Opponent three-point attempts attributed to this defender.",
  "engine": null,
  "raw": [
   "three_dfga"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "box_outs_pg": {
  "key": "box_outs_pg",
  "label": "Box Outs PG",
  "description": "Recorded box outs per game.",
  "engine": null,
  "raw": [
   "box_outs_pg",
   "box_outs_per_game"
  ],
  "children": [
   "box_out_pct"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "box_out_pct": {
  "key": "box_out_pct",
  "label": "Box Out %",
  "description": "Share of the player’s recorded box outs on which that player secures the rebound (NBA PCT_BOX_OUTS_REB).",
  "engine": null,
  "raw": [
   "box_out_pct",
   "boxout_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "blow_by_rate": {
  "key": "blow_by_rate",
  "label": "Blow-By Rate",
  "description": "Rate at which the primary ball handler beats the defender cleanly off the dribble.",
  "engine": null,
  "raw": [
   "blow_by_rate",
   "blowby_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "contest_distance": {
  "key": "contest_distance",
  "label": "Contest Distance",
  "description": "Average defender-to-shooter distance at the tracked contest.",
  "engine": null,
  "raw": [
   "contest_distance",
   "avg_contest_distance"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "help_defense_pg": {
  "key": "help_defense_pg",
  "label": "Help Defense PG",
  "description": "Tracked help rotations or help-defense interventions per game.",
  "engine": null,
  "raw": [
   "help_defense_pg",
   "help_events_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "deterrence_rate": {
  "key": "deterrence_rate",
  "label": "Deterrence Rate",
  "description": "Estimated reduction in opponent shot or drive attempts attributable to the defender’s presence.",
  "engine": null,
  "raw": [
   "deterrence_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "switch_attrition_rate": {
  "key": "switch_attrition_rate",
  "label": "Switch Attrition Rate",
  "description": "Rate at which an offense abandons or degrades an action after the player switches onto it.",
  "engine": null,
  "raw": [
   "switch_attrition_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "closeout_speed": {
  "key": "closeout_speed",
  "label": "Closeout Speed",
  "description": "Tracked average speed while closing out to a shooter.",
  "engine": null,
  "raw": [
   "closeout_speed",
   "avg_closeout_speed"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "anticipation": {
  "key": "anticipation",
  "label": "Defensive Anticipation",
  "description": "Model or tracking estimate of how early a defender recognizes and reacts to developing actions.",
  "engine": null,
  "raw": [
   "anticipation",
   "defensive_anticipation"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "screen_apg": {
  "key": "screen_apg",
  "label": "Screen APG",
  "description": "Screens directly leading to a made field goal per game.",
  "engine": null,
  "raw": [
   "screen_assists_per_game",
   "screen_apg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "secondary_apg": {
  "key": "secondary_apg",
  "label": "Secondary APG",
  "description": "Passes immediately preceding the credited assist, also called hockey assists.",
  "engine": null,
  "raw": [
   "secondary_assists_per_game",
   "secondary_apg",
   "hockey_assists_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "potential_apg": {
  "key": "potential_apg",
  "label": "Potential APG",
  "description": "Passes that would become assists if the receiving player makes the resulting shot.",
  "engine": null,
  "raw": [
   "potential_assists_per_game",
   "potential_apg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "passes_pg": {
  "key": "passes_pg",
  "label": "Passes Made PG",
  "description": "Tracked passes made by the player per game.",
  "engine": null,
  "raw": [
   "passes_per_game",
   "passes_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "ast_to": {
  "key": "ast_to",
  "label": "AST:TO",
  "description": "Assists divided by turnovers.",
  "engine": "ast_tov",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "ast_pct": {
  "key": "ast_pct",
  "label": "AST%",
  "description": "Estimated percentage of teammate field goals assisted while the player is on court.",
  "engine": null,
  "raw": [
   "ast_pct",
   "assist_pct",
   "assist_percentage"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "tov_pct": {
  "key": "tov_pct",
  "label": "TO%",
  "description": "Estimated turnovers per 100 individual possessions used.",
  "engine": null,
  "raw": [
   "tov_pct",
   "turnover_pct",
   "turnover_percentage"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "adjusted_assist_ratio": {
  "key": "adjusted_assist_ratio",
  "label": "Adjusted Assist Ratio",
  "description": "Creation rate counting direct assists, free-throw assists and secondary assists.",
  "engine": null,
  "raw": [
   "adjusted_assist_ratio",
   "adj_assist_ratio"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "ft_apg": {
  "key": "ft_apg",
  "label": "Free Throw Assist PG",
  "description": "Passes leading directly to shooting fouls and free-throw trips per game.",
  "engine": null,
  "raw": [
   "free_throw_assists_per_game",
   "ft_assists_per_game",
   "ft_apg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "touches_pg": {
  "key": "touches_pg",
  "label": "Touches PG",
  "description": "Tracked offensive touches per game.",
  "engine": null,
  "raw": [
   "touches_per_game",
   "touches_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "pass_windows_opened": {
  "key": "pass_windows_opened",
  "label": "Pass Windows Opened",
  "description": "Estimated passing lanes created for teammates by player positioning, movement or gravity.",
  "engine": null,
  "raw": [
   "pass_windows_opened",
   "passing_lanes_opened"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "passing_decision_time": {
  "key": "passing_decision_time",
  "label": "Passing Decision Time",
  "description": "Average elapsed time from gaining possession to initiating a pass.",
  "engine": null,
  "raw": [
   "passing_decision_time",
   "avg_passing_decision_time"
  ],
  "children": [],
  "format": "seconds",
  "decimals": 1
 },
 "panic_turnover_rate": {
  "key": "panic_turnover_rate",
  "label": "Panic Turnover Rate",
  "description": "Share of pressure possessions ending in an unplanned or forced turnover.",
  "engine": null,
  "raw": [
   "panic_turnover_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "blitz_trap_escape_rate": {
  "key": "blitz_trap_escape_rate",
  "label": "Blitz / Trap Escape Rate",
  "description": "Share of blitzed or trapped possessions escaped without a turnover or dead possession.",
  "engine": null,
  "raw": [
   "blitz_trap_escape_rate",
   "trap_escape_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "double_team_escape_rate": {
  "key": "double_team_escape_rate",
  "label": "Double-Team Navigation Rate",
  "description": "Successful navigation rate when two defenders commit to the ball.",
  "engine": null,
  "raw": [
   "double_team_escape_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "triple_team_escape_rate": {
  "key": "triple_team_escape_rate",
  "label": "Triple-Team Navigation Rate",
  "description": "Successful navigation rate when three defenders commit to the ball.",
  "engine": null,
  "raw": [
   "triple_team_escape_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "contested_rpg": {
  "key": "contested_rpg",
  "label": "Contested RPG",
  "description": "Rebounds secured with an opponent contest nearby.",
  "engine": null,
  "raw": [
   "contested_rebounds_per_game",
   "contested_rpg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "uncontested_rpg": {
  "key": "uncontested_rpg",
  "label": "Uncontested RPG",
  "description": "Rebounds secured without a nearby opponent contest.",
  "engine": null,
  "raw": [
   "uncontested_rebounds_per_game",
   "uncontested_rpg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "trb_pct": {
  "key": "trb_pct",
  "label": "REB%",
  "description": "Estimated share of available rebounds secured while the player is on court.",
  "engine": null,
  "raw": [
   "trb_pct",
   "total_rebound_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "drb_pct": {
  "key": "drb_pct",
  "label": "DRB%",
  "description": "Estimated share of available defensive rebounds secured while the player is on court.",
  "engine": null,
  "raw": [
   "drb_pct",
   "defensive_rebound_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "contested_orb_pg": {
  "key": "contested_orb_pg",
  "label": "Contested ORB PG",
  "description": "Offensive rebounds secured with an opponent contest nearby.",
  "engine": null,
  "raw": [
   "contested_orb_pg",
   "contested_offensive_rebounds_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "uncontested_orb_pg": {
  "key": "uncontested_orb_pg",
  "label": "Uncontested ORB PG",
  "description": "Offensive rebounds secured without a nearby opponent contest.",
  "engine": null,
  "raw": [
   "uncontested_orb_pg",
   "uncontested_offensive_rebounds_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "orb_pct": {
  "key": "orb_pct",
  "label": "ORB%",
  "description": "Estimated share of available offensive rebounds secured while the player is on court.",
  "engine": null,
  "raw": [
   "orb_pct",
   "offensive_rebound_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "tap_outs_pg": {
  "key": "tap_outs_pg",
  "label": "Tap Outs PG",
  "description": "Rebound opportunities intentionally redirected to a teammate per game.",
  "engine": null,
  "raw": [
   "tap_outs_per_game",
   "tap_outs_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "deferred_rebounds_pg": {
  "key": "deferred_rebounds_pg",
  "label": "Deferred Rebounds PG",
  "description": "Rebound opportunities intentionally left for a teammate per game.",
  "engine": null,
  "raw": [
   "deferred_rebounds_per_game",
   "deferred_rebounds_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "efg_pct": {
  "key": "efg_pct",
  "label": "eFG%",
  "description": "Field-goal percentage adjusted to value made threes as 1.5 made field goals.",
  "engine": "efg_pct",
  "raw": [],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "ts_pct": {
  "key": "ts_pct",
  "label": "TS%",
  "description": "Scoring efficiency that incorporates twos, threes and free throws.",
  "engine": "ts_pct",
  "raw": [],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "ftr": {
  "key": "ftr",
  "label": "FTR",
  "description": "Free-throw attempts divided by field-goal attempts.",
  "engine": "ft_rate",
  "raw": [],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "three_par": {
  "key": "three_par",
  "label": "3PAr",
  "description": "Three-point attempts divided by field-goal attempts.",
  "engine": "three_rate",
  "raw": [],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "pps": {
  "key": "pps",
  "label": "PPS",
  "description": "Points scored per field-goal attempt when source PPS is unavailable.",
  "engine": null,
  "raw": [
   "points_per_shot",
   "pps"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "pie": {
  "key": "pie",
  "label": "PIE",
  "description": "NBA-style estimate of a player’s share of statistical game events.",
  "engine": null,
  "raw": [
   "pie",
   "player_impact_estimate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "assisted_fg_pct": {
  "key": "assisted_fg_pct",
  "label": "ASTD FG%",
  "description": "Share of made field goals that were assisted.",
  "engine": null,
  "raw": [
   "assisted_fg_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "unassisted_fg_pct": {
  "key": "unassisted_fg_pct",
  "label": "UNAST FG%",
  "description": "Share of made field goals that were self-created without a credited assist.",
  "engine": null,
  "raw": [
   "unassisted_fg_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "assisted_ppg": {
  "key": "assisted_ppg",
  "label": "ASTD PPG",
  "description": "Points scored on assisted field goals per game.",
  "engine": null,
  "raw": [
   "assisted_points_per_game",
   "assisted_ppg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "unassisted_ppg": {
  "key": "unassisted_ppg",
  "label": "UNAST PPG",
  "description": "Points scored on unassisted field goals per game.",
  "engine": null,
  "raw": [
   "unassisted_points_per_game",
   "unassisted_ppg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "ortg": {
  "key": "ortg",
  "label": "ORTG",
  "description": "Team points scored per 100 possessions while the player is on court, or source player ORtg.",
  "engine": null,
  "raw": [
   "offensive_rating",
   "ortg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "drtg": {
  "key": "drtg",
  "label": "DRTG",
  "description": "Team points allowed per 100 possessions while the player is on court, or source player DRtg.",
  "engine": null,
  "raw": [
   "defensive_rating",
   "drtg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "net_rating": {
  "key": "net_rating",
  "label": "NRTG",
  "description": "Offensive rating minus defensive rating.",
  "engine": null,
  "raw": [
   "net_rating",
   "net_rtg"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "on_off": {
  "key": "on_off",
  "label": "On/Off",
  "description": "Difference in team net rating with the player on the floor versus off the floor.",
  "engine": null,
  "raw": [
   "on_off",
   "on_off_differential",
   "on_off_net_rating"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "pace": {
  "key": "pace",
  "label": "Pace",
  "description": "Estimated possessions per 48 minutes in the player’s on-court minutes.",
  "engine": null,
  "raw": [
   "pace",
   "pace_per_48"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "per": {
  "key": "per",
  "label": "PER",
  "description": "Minute-adjusted box-score productivity metric standardized around league average.",
  "engine": null,
  "raw": [
   "per",
   "player_efficiency_rating"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "bpm": {
  "key": "bpm",
  "label": "BPM",
  "description": "Box-score estimate of points per 100 possessions above league average.",
  "engine": "bpm",
  "raw": [
   "bpm",
   "box_plus_minus"
  ],
  "children": [
   "obpm",
   "dbpm"
  ],
  "format": "signed",
  "decimals": 1
 },
 "obpm": {
  "key": "obpm",
  "label": "Offensive BPM",
  "description": "Offensive component of Box Plus/Minus.",
  "engine": null,
  "raw": [
   "obpm",
   "offensive_box_plus_minus"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "dbpm": {
  "key": "dbpm",
  "label": "Defensive BPM",
  "description": "Defensive component of Box Plus/Minus.",
  "engine": null,
  "raw": [
   "dbpm",
   "defensive_box_plus_minus"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "vorp": {
  "key": "vorp",
  "label": "VORP",
  "description": "BPM-based estimate of total value above a replacement-level player.",
  "engine": null,
  "raw": [
   "vorp",
   "value_over_replacement_player"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "ws": {
  "key": "ws",
  "label": "WS",
  "description": "Estimate of wins contributed using offensive and defensive box-score components.",
  "engine": null,
  "raw": [
   "ws",
   "win_shares"
  ],
  "children": [
   "ows",
   "dws"
  ],
  "format": "decimal",
  "decimals": 1
 },
 "ows": {
  "key": "ows",
  "label": "Offensive WS",
  "description": "Offensive component of Win Shares.",
  "engine": null,
  "raw": [
   "ows",
   "offensive_win_shares"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "dws": {
  "key": "dws",
  "label": "Defensive WS",
  "description": "Defensive component of Win Shares.",
  "engine": null,
  "raw": [
   "dws",
   "defensive_win_shares"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "epm": {
  "key": "epm",
  "label": "EPM",
  "description": "Estimated Plus-Minus value when supplied by an authorized source.",
  "engine": null,
  "raw": [
   "epm",
   "estimated_plus_minus"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "lebron": {
  "key": "lebron",
  "label": "LEBRON",
  "description": "Luck-adjusted player impact estimate when supplied by an authorized source.",
  "engine": null,
  "raw": [
   "lebron",
   "lebron_metric"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "darko": {
  "key": "darko",
  "label": "DARKO",
  "description": "DARKO player impact estimate when supplied by an authorized source.",
  "engine": null,
  "raw": [
   "darko",
   "darko_metric"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "rapm": {
  "key": "rapm",
  "label": "RAPM",
  "description": "Regularized adjusted plus-minus estimate controlling for teammates and opponents.",
  "engine": null,
  "raw": [
   "rapm"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "la_rapm": {
  "key": "la_rapm",
  "label": "LA-RAPM",
  "description": "RAPM variant using luck-adjusted scoring inputs when supplied by a model source.",
  "engine": null,
  "raw": [
   "la_rapm",
   "luck_adjusted_rapm"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "warv": {
  "key": "warv",
  "label": "WARP",
  "description": "Model estimate of wins created above a replacement-level player.",
  "engine": null,
  "raw": [
   "warp",
   "warv",
   "wins_above_replacement_player",
   "wins_above_replacement_value"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "usage": {
  "key": "usage",
  "label": "USG%",
  "description": "Estimated share of team possessions used by the player while on court.",
  "engine": null,
  "raw": [
   "usage",
   "usage_pct",
   "usg_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "distance_traveled": {
  "key": "distance_traveled",
  "label": "Distance PG",
  "description": "Tracked distance covered by the player over the selected sample.",
  "engine": null,
  "raw": [
   "distance_traveled",
   "distance_miles",
   "distance"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "average_speed": {
  "key": "average_speed",
  "label": "Average Speed",
  "description": "Tracked average player speed while on the floor.",
  "engine": null,
  "raw": [
   "average_speed",
   "avg_speed"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "time_per_touch": {
  "key": "time_per_touch",
  "label": "Seconds / Touch",
  "description": "Average seconds the player controls the ball per touch.",
  "engine": null,
  "raw": [
   "time_per_touch",
   "avg_seconds_per_touch"
  ],
  "children": [],
  "format": "seconds",
  "decimals": 1
 },
 "dribbles_per_touch": {
  "key": "dribbles_per_touch",
  "label": "Dribbles / Touch",
  "description": "Average dribbles taken per tracked touch.",
  "engine": null,
  "raw": [
   "dribbles_per_touch",
   "avg_dribbles_per_touch"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "freeze_time": {
  "key": "freeze_time",
  "label": "Freeze Time",
  "description": "Tracked time defenders remain committed or stationary because of the player’s action.",
  "engine": null,
  "raw": [
   "freeze_time",
   "freeze_time_seconds"
  ],
  "children": [],
  "format": "seconds",
  "decimals": 1
 },
 "scoring_decision_time": {
  "key": "scoring_decision_time",
  "label": "Scoring Decision Time",
  "description": "Average time from gaining possession to committing to a shot attempt.",
  "engine": null,
  "raw": [
   "scoring_decision_time"
  ],
  "children": [],
  "format": "seconds",
  "decimals": 1
 },
 "driving_decision_time": {
  "key": "driving_decision_time",
  "label": "Driving Decision Time",
  "description": "Average time from gaining possession to committing to a drive.",
  "engine": null,
  "raw": [
   "driving_decision_time"
  ],
  "children": [],
  "format": "seconds",
  "decimals": 1
 },
 "clutch_mpg": {
  "key": "clutch_mpg",
  "label": "Clutch MPG",
  "description": "Minutes played per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_mpg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_ppg": {
  "key": "clutch_ppg",
  "label": "Clutch PPG",
  "description": "Points per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_ppg",
   "clutch_points_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_rpg": {
  "key": "clutch_rpg",
  "label": "Clutch RPG",
  "description": "Rebounds per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_rpg",
   "clutch_rebounds_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_apg": {
  "key": "clutch_apg",
  "label": "Clutch APG",
  "description": "Assists per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_apg",
   "clutch_assists_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_spg": {
  "key": "clutch_spg",
  "label": "Clutch SPG",
  "description": "Steals per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_spg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_bpg": {
  "key": "clutch_bpg",
  "label": "Clutch BPG",
  "description": "Blocks per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_bpg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_tpg": {
  "key": "clutch_tpg",
  "label": "Clutch TPG",
  "description": "Turnovers per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_tpg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_pf_pg": {
  "key": "clutch_pf_pg",
  "label": "Clutch PF PG",
  "description": "Personal fouls per source-defined clutch game or clutch appearance.",
  "engine": null,
  "raw": [
   "clutch_pf_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_fg_pct": {
  "key": "clutch_fg_pct",
  "label": "Clutch FG%",
  "description": "Field-goal percentage in source-defined clutch possessions.",
  "engine": null,
  "raw": [
   "clutch_fg_pct"
  ],
  "children": [
   "clutch_fgm",
   "clutch_fga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "clutch_fgm": {
  "key": "clutch_fgm",
  "label": "Clutch FGM",
  "description": "Field goals made in source-defined clutch minutes.",
  "engine": null,
  "raw": [
   "clutch_fgm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_fga": {
  "key": "clutch_fga",
  "label": "Clutch FGA",
  "description": "Field-goal attempts in source-defined clutch minutes.",
  "engine": null,
  "raw": [
   "clutch_fga"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_three_pct": {
  "key": "clutch_three_pct",
  "label": "Clutch 3P%",
  "description": "Three-point percentage in source-defined clutch possessions.",
  "engine": null,
  "raw": [
   "clutch_three_pct",
   "clutch_3p_pct"
  ],
  "children": [
   "clutch_three_pm",
   "clutch_three_pa"
  ],
  "format": "percent",
  "decimals": 1
 },
 "clutch_three_pm": {
  "key": "clutch_three_pm",
  "label": "Clutch 3PM",
  "description": "Three-pointers made in source-defined clutch minutes.",
  "engine": null,
  "raw": [
   "clutch_three_pm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_three_pa": {
  "key": "clutch_three_pa",
  "label": "Clutch 3PA",
  "description": "Three-point attempts in source-defined clutch minutes.",
  "engine": null,
  "raw": [
   "clutch_three_pa"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_ft_pct": {
  "key": "clutch_ft_pct",
  "label": "Clutch FT%",
  "description": "Free-throw percentage in source-defined clutch possessions.",
  "engine": null,
  "raw": [
   "clutch_ft_pct"
  ],
  "children": [
   "clutch_ftm",
   "clutch_fta"
  ],
  "format": "percent",
  "decimals": 1
 },
 "clutch_ftm": {
  "key": "clutch_ftm",
  "label": "Clutch FTM",
  "description": "Free throws made in source-defined clutch minutes.",
  "engine": null,
  "raw": [
   "clutch_ftm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_fta": {
  "key": "clutch_fta",
  "label": "Clutch FTA",
  "description": "Free-throw attempts in source-defined clutch minutes.",
  "engine": null,
  "raw": [
   "clutch_fta"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "clutch_net_rating": {
  "key": "clutch_net_rating",
  "label": "Clutch Net Rating",
  "description": "Team net rating during source-defined clutch minutes.",
  "engine": null,
  "raw": [
   "clutch_net_rating"
  ],
  "children": [],
  "format": "signed",
  "decimals": 1
 },
 "rim_frequency": {
  "key": "rim_frequency",
  "label": "RIM FREQ",
  "description": "Share of field-goal attempts taken at the rim.",
  "engine": null,
  "raw": [
   "rim_frequency",
   "rim_freq"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "rim_fg_pct": {
  "key": "rim_fg_pct",
  "label": "Rim FG%",
  "description": "Field-goal percentage on attempts at the rim.",
  "engine": null,
  "raw": [
   "rim_fg_pct"
  ],
  "children": [
   "rim_fgm",
   "rim_fga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "rim_fgm": {
  "key": "rim_fgm",
  "label": "Rim FGM",
  "description": "Field goals made in the restricted-area rim bucket.",
  "engine": null,
  "raw": [
   "rim_fgm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "rim_fga": {
  "key": "rim_fga",
  "label": "Rim FGA",
  "description": "Field-goal attempts in the restricted-area rim bucket.",
  "engine": null,
  "raw": [
   "rim_fga"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "paint_frequency": {
  "key": "paint_frequency",
  "label": "PAINT FREQ",
  "description": "Share of field-goal attempts taken in the paint.",
  "engine": null,
  "raw": [
   "paint_frequency",
   "paint_freq"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "paint_fg_pct": {
  "key": "paint_fg_pct",
  "label": "PAINT FG%",
  "description": "Field-goal percentage on paint attempts.",
  "engine": null,
  "raw": [
   "paint_fg_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "midrange_frequency": {
  "key": "midrange_frequency",
  "label": "MID FREQ",
  "description": "Share of field-goal attempts classified as midrange.",
  "engine": null,
  "raw": [
   "midrange_frequency",
   "midrange_freq"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "midrange_fg_pct": {
  "key": "midrange_fg_pct",
  "label": "Midrange FG%",
  "description": "Field-goal percentage on midrange attempts.",
  "engine": null,
  "raw": [
   "midrange_fg_pct"
  ],
  "children": [
   "midrange_fgm",
   "midrange_fga"
  ],
  "format": "percent",
  "decimals": 1
 },
 "midrange_fgm": {
  "key": "midrange_fgm",
  "label": "Midrange FGM",
  "description": "Field goals made in NBA.com’s Mid-Range shot-location bucket.",
  "engine": null,
  "raw": [
   "midrange_fgm"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "midrange_fga": {
  "key": "midrange_fga",
  "label": "Midrange FGA",
  "description": "Field-goal attempts in NBA.com’s Mid-Range shot-location bucket.",
  "engine": null,
  "raw": [
   "midrange_fga"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "three_frequency": {
  "key": "three_frequency",
  "label": "3P FREQ",
  "description": "Share of field-goal attempts taken from three-point range.",
  "engine": "three_rate",
  "raw": [
   "three_frequency",
   "three_point_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "halfcourt_frequency": {
  "key": "halfcourt_frequency",
  "label": "HC FREQ",
  "description": "Share of offensive possessions ending in a halfcourt shot attempt.",
  "engine": null,
  "raw": [
   "halfcourt_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "halfcourt_fg_pct": {
  "key": "halfcourt_fg_pct",
  "label": "HC FG%",
  "description": "Field-goal percentage on halfcourt attempts.",
  "engine": null,
  "raw": [
   "halfcourt_fg_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "heaves_pg": {
  "key": "heaves_pg",
  "label": "HPG",
  "description": "Long-distance end-of-period heave attempts per game.",
  "engine": null,
  "raw": [
   "heaves_per_game",
   "heaves_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "corner_three_frequency": {
  "key": "corner_three_frequency",
  "label": "C3 FREQ",
  "description": "Share of attempts taken from either corner three location.",
  "engine": null,
  "raw": [
   "corner_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "corner_three_pct": {
  "key": "corner_three_pct",
  "label": "C3%",
  "description": "Three-point percentage from either corner.",
  "engine": null,
  "raw": [
   "corner_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "right_corner_three_frequency": {
  "key": "right_corner_three_frequency",
  "label": "RC3 FREQ",
  "description": "Share of attempts taken from the right corner.",
  "engine": null,
  "raw": [
   "right_corner_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "right_corner_three_pct": {
  "key": "right_corner_three_pct",
  "label": "RC3%",
  "description": "Three-point percentage from the right corner.",
  "engine": null,
  "raw": [
   "right_corner_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "left_corner_three_frequency": {
  "key": "left_corner_three_frequency",
  "label": "LC3 FREQ",
  "description": "Share of attempts taken from the left corner.",
  "engine": null,
  "raw": [
   "left_corner_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "left_corner_three_pct": {
  "key": "left_corner_three_pct",
  "label": "LC3%",
  "description": "Three-point percentage from the left corner.",
  "engine": null,
  "raw": [
   "left_corner_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "catch_shoot_three_frequency": {
  "key": "catch_shoot_three_frequency",
  "label": "C&S FREQ",
  "description": "Share of attempts that are catch-and-shoot threes.",
  "engine": null,
  "raw": [
   "catch_shoot_three_frequency",
   "catch_and_shoot_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "catch_shoot_three_pct": {
  "key": "catch_shoot_three_pct",
  "label": "C&S 3P%",
  "description": "Three-point percentage on catch-and-shoot attempts.",
  "engine": null,
  "raw": [
   "catch_shoot_three_pct",
   "catch_and_shoot_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "pull_up_three_frequency": {
  "key": "pull_up_three_frequency",
  "label": "PU3 FREQ",
  "description": "Share of attempts that are pull-up threes.",
  "engine": null,
  "raw": [
   "pull_up_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "pull_up_three_pct": {
  "key": "pull_up_three_pct",
  "label": "PU3%",
  "description": "Three-point percentage on pull-up attempts.",
  "engine": null,
  "raw": [
   "pull_up_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "right_wing_three_frequency": {
  "key": "right_wing_three_frequency",
  "label": "RW3 FREQ",
  "description": "Share of attempts taken from the right wing.",
  "engine": null,
  "raw": [
   "right_wing_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "right_wing_three_pct": {
  "key": "right_wing_three_pct",
  "label": "RW3%",
  "description": "Three-point percentage from the right wing.",
  "engine": null,
  "raw": [
   "right_wing_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "left_wing_three_frequency": {
  "key": "left_wing_three_frequency",
  "label": "LW3 FREQ",
  "description": "Share of attempts taken from the left wing.",
  "engine": null,
  "raw": [
   "left_wing_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "left_wing_three_pct": {
  "key": "left_wing_three_pct",
  "label": "LW3%",
  "description": "Three-point percentage from the left wing.",
  "engine": null,
  "raw": [
   "left_wing_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "wing_three_frequency": {
  "key": "wing_three_frequency",
  "label": "WING FREQ",
  "description": "Share of attempts taken from either wing.",
  "engine": null,
  "raw": [
   "wing_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "wing_three_pct": {
  "key": "wing_three_pct",
  "label": "WING 3P%",
  "description": "Three-point percentage from the wings.",
  "engine": null,
  "raw": [
   "wing_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "middle_three_frequency": {
  "key": "middle_three_frequency",
  "label": "TOP3 FREQ",
  "description": "Share of attempts taken from the middle or top-of-key three area.",
  "engine": null,
  "raw": [
   "middle_three_frequency",
   "top_three_frequency"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "middle_three_pct": {
  "key": "middle_three_pct",
  "label": "TOP3%",
  "description": "Three-point percentage from the middle or top-of-key area.",
  "engine": null,
  "raw": [
   "middle_three_pct",
   "top_three_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "dunks_pg": {
  "key": "dunks_pg",
  "label": "DUNK PG",
  "description": "Made or attempted dunks per game according to the source definition.",
  "engine": null,
  "raw": [
   "dunks_per_game",
   "dunks_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "dunk_fg_pct": {
  "key": "dunk_fg_pct",
  "label": "DUNK FG%",
  "description": "Field-goal percentage on dunk attempts.",
  "engine": null,
  "raw": [
   "dunk_fg_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "layups_pg": {
  "key": "layups_pg",
  "label": "LAYUP PG",
  "description": "Layup attempts or makes per game according to the source definition.",
  "engine": null,
  "raw": [
   "layups_per_game",
   "layups_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "layup_fg_pct": {
  "key": "layup_fg_pct",
  "label": "LAYUP FG%",
  "description": "Field-goal percentage on layup attempts.",
  "engine": null,
  "raw": [
   "layup_fg_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "isolation_ppp": {
  "key": "isolation_ppp",
  "label": "ISO PPP",
  "description": "Points scored per isolation possession.",
  "engine": null,
  "raw": [
   "isolation_ppp",
   "iso_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "transition_ppp": {
  "key": "transition_ppp",
  "label": "TRANS PPP",
  "description": "Points scored per transition possession.",
  "engine": null,
  "raw": [
   "transition_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "transition_offense_ppp": {
  "key": "transition_offense_ppp",
  "label": "TRANS O",
  "description": "Offensive points per transition possession.",
  "engine": null,
  "raw": [
   "transition_offense_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "transition_defense_ppp": {
  "key": "transition_defense_ppp",
  "label": "TRANS D",
  "description": "Opponent points per transition possession while this player is the primary tracked defender or on court.",
  "engine": null,
  "raw": [
   "transition_defense_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "pnr_ball_handler_ppp": {
  "key": "pnr_ball_handler_ppp",
  "label": "PnR BH",
  "description": "Points per possession when the player is the pick-and-roll ball handler.",
  "engine": null,
  "raw": [
   "pnr_ball_handler_ppp",
   "pick_roll_ball_handler_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "pnr_roll_man_ppp": {
  "key": "pnr_roll_man_ppp",
  "label": "PnR RM",
  "description": "Points per possession when the player is the roll man.",
  "engine": null,
  "raw": [
   "pnr_roll_man_ppp",
   "pick_roll_roll_man_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "post_up_ppp": {
  "key": "post_up_ppp",
  "label": "POST PPP",
  "description": "Points scored per post-up possession.",
  "engine": null,
  "raw": [
   "post_up_ppp",
   "postup_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "spot_up_ppp": {
  "key": "spot_up_ppp",
  "label": "SPOT PPP",
  "description": "Points scored per spot-up possession.",
  "engine": null,
  "raw": [
   "spot_up_ppp",
   "spotup_ppp"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 2
 },
 "drive_ppg": {
  "key": "drive_ppg",
  "label": "DRIVE PPG",
  "description": "Points scored from tracked drives per game.",
  "engine": null,
  "raw": [
   "drive_points_per_game",
   "drive_ppg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "drive_apg": {
  "key": "drive_apg",
  "label": "DRIVE APG",
  "description": "Assists generated from tracked drives per game.",
  "engine": null,
  "raw": [
   "drive_assists_per_game",
   "drive_apg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "backdoor_cut_pg": {
  "key": "backdoor_cut_pg",
  "label": "BACKDOOR",
  "description": "Tracked backdoor cuts per game.",
  "engine": null,
  "raw": [
   "backdoor_cuts_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "v_cut_pg": {
  "key": "v_cut_pg",
  "label": "V-CUT PG",
  "description": "Tracked V-cuts per game.",
  "engine": null,
  "raw": [
   "v_cuts_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "l_cut_pg": {
  "key": "l_cut_pg",
  "label": "L-CUT PG",
  "description": "Tracked L-cuts per game.",
  "engine": null,
  "raw": [
   "l_cuts_per_game"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "offensive_gravity": {
  "key": "offensive_gravity",
  "label": "OFF GRAV",
  "description": "Model estimate of how strongly a player pulls defenders and changes team spacing.",
  "engine": null,
  "raw": [
   "offensive_gravity"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "shot_gravity": {
  "key": "shot_gravity",
  "label": "SHOT GRAV",
  "description": "Model estimate of defensive attention created by the threat of the player’s shot.",
  "engine": null,
  "raw": [
   "shot_gravity"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "drive_gravity": {
  "key": "drive_gravity",
  "label": "DRIVE GRAV",
  "description": "Model estimate of defensive attention created by the threat of the player’s drive.",
  "engine": null,
  "raw": [
   "drive_gravity"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "screens_set_pg": {
  "key": "screens_set_pg",
  "label": "SCR SET PG",
  "description": "Tracked screens set by the player per game.",
  "engine": null,
  "raw": [
   "screens_set_per_game",
   "screens_set_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "screens_used_pg": {
  "key": "screens_used_pg",
  "label": "SCR USE PG",
  "description": "Tracked screens used by the player as the ball handler per game.",
  "engine": null,
  "raw": [
   "screens_used_per_game",
   "screens_used_pg"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "age": {
  "key": "age",
  "label": "AGE",
  "description": "Player age for the selected season and segment.",
  "engine": "age",
  "raw": [
   "age"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "draft_year": {
  "key": "draft_year",
  "label": "DRAFT YR",
  "description": "Year selected in the NBA draft, where applicable.",
  "engine": null,
  "raw": [
   "draft_year"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "draft_round": {
  "key": "draft_round",
  "label": "DRAFT RD",
  "description": "Round selected in the NBA draft, where applicable.",
  "engine": null,
  "raw": [
   "draft_round"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "draft_number": {
  "key": "draft_number",
  "label": "DRAFT #",
  "description": "Overall selection number in the NBA draft, where applicable.",
  "engine": null,
  "raw": [
   "draft_number"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "height": {
  "key": "height",
  "label": "HEIGHT",
  "description": "Measured player height.",
  "engine": null,
  "raw": [
   "height_inches",
   "height"
  ],
  "children": [],
  "format": "feetInches",
  "decimals": 1
 },
 "weight": {
  "key": "weight",
  "label": "WEIGHT",
  "description": "Measured player weight.",
  "engine": null,
  "raw": [
   "weight_lbs",
   "weight"
  ],
  "children": [],
  "format": "pounds",
  "decimals": 1
 },
 "wingspan": {
  "key": "wingspan",
  "label": "WINGSPAN",
  "description": "Measured fingertip-to-fingertip wingspan.",
  "engine": null,
  "raw": [
   "wingspan_inches",
   "wingspan"
  ],
  "children": [],
  "format": "inches",
  "decimals": 1
 },
 "standing_reach": {
  "key": "standing_reach",
  "label": "ST REACH",
  "description": "Measured standing reach.",
  "engine": null,
  "raw": [
   "standing_reach_inches",
   "standing_reach"
  ],
  "children": [],
  "format": "inches",
  "decimals": 1
 },
 "hand_length": {
  "key": "hand_length",
  "label": "HAND L",
  "description": "Measured hand length.",
  "engine": null,
  "raw": [
   "hand_length_inches",
   "hand_length"
  ],
  "children": [],
  "format": "inches",
  "decimals": 1
 },
 "hand_width": {
  "key": "hand_width",
  "label": "HAND W",
  "description": "Measured hand width.",
  "engine": null,
  "raw": [
   "hand_width_inches",
   "hand_width"
  ],
  "children": [],
  "format": "inches",
  "decimals": 1
 },
 "standing_jump": {
  "key": "standing_jump",
  "label": "ST VERT",
  "description": "Measured standing vertical jump.",
  "engine": null,
  "raw": [
   "standing_vertical_jump",
   "standing_jump"
  ],
  "children": [],
  "format": "inches",
  "decimals": 1
 },
 "max_vertical_jump": {
  "key": "max_vertical_jump",
  "label": "MAX VERT",
  "description": "Measured maximum vertical jump.",
  "engine": null,
  "raw": [
   "max_vertical_jump",
   "max_vertical"
  ],
  "children": [],
  "format": "inches",
  "decimals": 1
 },
 "technical_fouls": {
  "key": "technical_fouls",
  "label": "TECH",
  "description": "Technical fouls assessed to the player.",
  "engine": null,
  "raw": [
   "technical_fouls",
   "tech_fouls"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "shooting_fouls": {
  "key": "shooting_fouls",
  "label": "SHOOT F",
  "description": "Shooting fouls committed by the player.",
  "engine": null,
  "raw": [
   "shooting_fouls"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "personal_fouls": {
  "key": "personal_fouls",
  "label": "PF",
  "description": "Personal fouls committed by the player.",
  "engine": "pf",
  "raw": [],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "offensive_fouls": {
  "key": "offensive_fouls",
  "label": "OFF F",
  "description": "Offensive fouls committed by the player.",
  "engine": null,
  "raw": [
   "offensive_fouls"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "defensive_fouls": {
  "key": "defensive_fouls",
  "label": "DEF F",
  "description": "Defensive fouls committed by the player.",
  "engine": null,
  "raw": [
   "defensive_fouls"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "other_fouls": {
  "key": "other_fouls",
  "label": "OTHER F",
  "description": "Other foul classifications recorded by the source.",
  "engine": null,
  "raw": [
   "other_fouls"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "ejections": {
  "key": "ejections",
  "label": "EJECT",
  "description": "Games or incidents in which the player is ejected.",
  "engine": null,
  "raw": [
   "ejections"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "disqualifications": {
  "key": "disqualifications",
  "label": "DQ",
  "description": "Games in which the player is disqualified under the source definition.",
  "engine": null,
  "raw": [
   "disqualifications"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "suspensions": {
  "key": "suspensions",
  "label": "SUSP",
  "description": "Games or incidents resulting in suspension.",
  "engine": null,
  "raw": [
   "suspensions",
   "suspension_games"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "whistle_reaction": {
  "key": "whistle_reaction",
  "label": "WHISTLE",
  "description": "Model or tracking measure of player behavior immediately after whistles.",
  "engine": null,
  "raw": [
   "whistle_reaction"
  ],
  "children": [],
  "format": "decimal",
  "decimals": 1
 },
 "game_buzzer_beaters": {
  "key": "game_buzzer_beaters",
  "label": "GAME BB",
  "description": "Made shots beating the final game buzzer.",
  "engine": null,
  "raw": [
   "game_buzzer_beaters"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "quarter_buzzer_beaters": {
  "key": "quarter_buzzer_beaters",
  "label": "QTR BB",
  "description": "Made shots beating a quarter or period buzzer.",
  "engine": null,
  "raw": [
   "quarter_buzzer_beaters"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "shot_clock_buzzer_beaters": {
  "key": "shot_clock_buzzer_beaters",
  "label": "SC BB",
  "description": "Made shots released immediately before shot-clock expiration.",
  "engine": null,
  "raw": [
   "shot_clock_buzzer_beaters"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "availability_pct": {
  "key": "availability_pct",
  "label": "AVAIL%",
  "description": "Share of team games for which the player is available to play.",
  "engine": null,
  "raw": [
   "availability_pct"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 },
 "games_missed_injury": {
  "key": "games_missed_injury",
  "label": "GM INJ",
  "description": "Games missed because of recorded injuries.",
  "engine": null,
  "raw": [
   "games_missed_injury",
   "injury_games_missed"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "injury_events": {
  "key": "injury_events",
  "label": "INJ EVT",
  "description": "Distinct recorded injury events in the selected sample.",
  "engine": null,
  "raw": [
   "injury_events",
   "injury_count"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "days_missed": {
  "key": "days_missed",
  "label": "DAYS OUT",
  "description": "Calendar days missed because of recorded injuries.",
  "engine": null,
  "raw": [
   "days_missed",
   "injury_days_missed"
  ],
  "children": [],
  "format": "integer",
  "decimals": 1
 },
 "injury_rate": {
  "key": "injury_rate",
  "label": "INJ RATE",
  "description": "Recorded injury events relative to the selected exposure basis.",
  "engine": null,
  "raw": [
   "injury_rate"
  ],
  "children": [],
  "format": "percent",
  "decimals": 1
 }
};
export const advancedGroups:AdvancedGroup[] = [
 {
  "name": "Overview",
  "description": "Core production, traditional shooting efficiency and headline impact measures.",
  "keys": [
   "gp",
   "mpg",
   "ppg",
   "rpg",
   "apg",
   "spg",
   "bpg",
   "tpg",
   "pf",
   "fg_pct",
   "three_pct",
   "ft_pct",
   "per",
   "bpm",
   "vorp",
   "ws"
  ]
 },
 {
  "name": "Shooting & Efficiency",
  "description": "Shooting percentages, shot-location efficiency and possession efficiency in one consolidated view.",
  "keys": [
   "fg_pct",
   "two_pct",
   "three_pct",
   "ft_pct",
   "rim_fg_pct",
   "midrange_fg_pct",
   "efg_pct",
   "ts_pct",
   "ftr",
   "three_par",
   "pps",
   "pie",
   "assisted_fg_pct",
   "unassisted_fg_pct",
   "assisted_ppg",
   "unassisted_ppg"
  ]
 },
 {
  "name": "Defensive / Hustle",
  "description": "Defensive events, contests, hustle plays and opponent shooting.",
  "keys": [
   "spg",
   "bpg",
   "deflections_pg",
   "dreb",
   "charges_drawn_pg",
   "contested_shots_pg",
   "loose_balls_recovered_pg",
   "dfg_pct",
   "rim_dfg_pct",
   "midrange_dfg_pct",
   "three_dfg_pct",
   "box_outs_pg",
   "blow_by_rate",
   "contest_distance",
   "help_defense_pg",
   "deterrence_rate",
   "switch_attrition_rate",
   "closeout_speed",
   "anticipation"
  ]
 },
 {
  "name": "Hustle Breakdown",
  "description": "NBA.com tracked contested shots, deflections, loose balls, screens and box outs.",
  "keys": [
   "hustle_gp",
   "hustle_minutes",
   "hustle_mpg",
   "contested_shots_pg",
   "deflections_pg",
   "charges_drawn_pg",
   "screen_apg",
   "loose_balls_recovered_pg",
   "box_outs_pg"
  ]
 },
 {
  "name": "Playmaking / Possession",
  "description": "Passing volume, creation quality, turnovers and decision-making.",
  "keys": [
   "apg",
   "tpg",
   "screen_apg",
   "secondary_apg",
   "potential_apg",
   "passes_pg",
   "ast_to",
   "ast_pct",
   "tov_pct",
   "adjusted_assist_ratio",
   "ft_apg",
   "touches_pg",
   "pass_windows_opened",
   "passing_decision_time",
   "panic_turnover_rate",
   "blitz_trap_escape_rate",
   "double_team_escape_rate",
   "triple_team_escape_rate"
  ]
 },
 {
  "name": "Rebounding",
  "description": "Rebound production, contest context and rebounding rates.",
  "keys": [
   "rpg",
   "dreb",
   "oreb",
   "box_outs_pg",
   "tap_outs_pg",
   "deferred_rebounds_pg"
  ]
 },
 {
  "name": "Impact",
  "description": "Team-level impact while a player is on the floor.",
  "keys": [
   "ortg",
   "drtg",
   "net_rating",
   "on_off",
   "pace",
   "pie"
  ]
 },
 {
  "name": "Aggregate Metrics",
  "description": "Composite impact and value models from box score and plus-minus data.",
  "keys": [
   "per",
   "bpm",
   "vorp",
   "ws",
   "epm",
   "lebron",
   "darko",
   "rapm",
   "la_rapm",
   "warv"
  ]
 },
 {
  "name": "Movement",
  "description": "Usage, physical movement, touches and decision-time measures.",
  "keys": [
   "usage",
   "distance_traveled",
   "average_speed",
   "time_per_touch",
   "dribbles_per_touch",
   "freeze_time",
   "scoring_decision_time",
   "passing_decision_time",
   "driving_decision_time"
  ]
 },
 {
  "name": "Clutch",
  "description": "Production in source-defined clutch situations.",
  "keys": [
   "clutch_mpg",
   "clutch_ppg",
   "clutch_rpg",
   "clutch_apg",
   "clutch_spg",
   "clutch_bpg",
   "clutch_tpg",
   "clutch_pf_pg",
   "clutch_fg_pct",
   "clutch_three_pct",
   "clutch_ft_pct",
   "clutch_net_rating"
  ]
 },
 {
  "name": "Shot Profile",
  "description": "Location, shot type, creation mode and finishing profile.",
  "keys": [
   "rim_frequency",
   "rim_fg_pct",
   "paint_frequency",
   "paint_fg_pct",
   "midrange_frequency",
   "midrange_fg_pct",
   "three_frequency",
   "three_pct",
   "halfcourt_frequency",
   "halfcourt_fg_pct",
   "heaves_pg",
   "corner_three_frequency",
   "corner_three_pct",
   "right_corner_three_frequency",
   "right_corner_three_pct",
   "left_corner_three_frequency",
   "left_corner_three_pct",
   "catch_shoot_three_frequency",
   "catch_shoot_three_pct",
   "pull_up_three_frequency",
   "pull_up_three_pct",
   "right_wing_three_frequency",
   "right_wing_three_pct",
   "left_wing_three_frequency",
   "left_wing_three_pct",
   "wing_three_frequency",
   "wing_three_pct",
   "middle_three_frequency",
   "middle_three_pct",
   "dunks_pg",
   "dunk_fg_pct",
   "layups_pg",
   "layup_fg_pct"
  ]
 },
 {
  "name": "Play Type",
  "description": "Possession efficiency by offensive action and transition context.",
  "keys": [
   "isolation_ppp",
   "transition_ppp",
   "transition_offense_ppp",
   "transition_defense_ppp",
   "pnr_ball_handler_ppp",
   "pnr_roll_man_ppp",
   "post_up_ppp",
   "spot_up_ppp",
   "drive_ppg",
   "drive_apg",
   "backdoor_cut_pg",
   "v_cut_pg",
   "l_cut_pg"
  ]
 },
 {
  "name": "Isolation",
  "description": "Isolation scoring efficiency and nearby self-creation context.",
  "keys": [
   "isolation_ppp",
   "usage",
   "unassisted_fg_pct",
   "unassisted_ppg",
   "drive_ppg",
   "drive_apg"
  ]
 },
 {
  "name": "Gravity / Creation",
  "description": "How player movement and attention alter space and passing windows.",
  "keys": [
   "offensive_gravity",
   "shot_gravity",
   "drive_gravity",
   "pass_windows_opened",
   "freeze_time",
   "screen_apg",
   "screens_set_pg",
   "screens_used_pg"
  ]
 },
 {
  "name": "Physical Profile",
  "description": "Measured body dimensions and athletic testing.",
  "keys": [
   "age",
   "height",
   "weight",
   "draft_year",
   "draft_round",
   "draft_number",
   "wingspan",
   "standing_reach",
   "hand_length",
   "hand_width",
   "standing_jump",
   "max_vertical_jump"
  ]
 },
 {
  "name": "Fouls / Discipline",
  "description": "Foul types, technical discipline and game-removal events.",
  "keys": [
   "technical_fouls",
   "shooting_fouls",
   "personal_fouls",
   "offensive_fouls",
   "defensive_fouls",
   "other_fouls",
   "ejections",
   "disqualifications",
   "suspensions",
   "whistle_reaction",
   "game_buzzer_beaters",
   "quarter_buzzer_beaters",
   "shot_clock_buzzer_beaters"
  ]
 },
 {
  "name": "Availability / Injury",
  "description": "Availability, injury burden and time missed.",
  "keys": [
   "availability_pct",
   "games_missed_injury",
   "injury_events",
   "days_missed",
   "injury_rate"
  ]
 },
 {
  "name": "Rate Adjusted",
  "description": "Core counting production on the selected rate basis.",
  "keys": [
   "mpg",
   "ppg",
   "rpg",
   "apg",
   "spg",
   "bpg",
   "tpg",
   "fgm",
   "three_pm",
   "ftm"
  ]
 }
];
export const rateSensitiveKeys = new Set(['min','pts','ast','reb','oreb','dreb','stl','blk','tov','pf','fgm','fga','two_pm','two_pa','three_pm','three_pa','ftm','fta','plus_minus','stocks','defense_events','possessions_proxy','game_score_proxy']);

// Flutter reference Physical Profile also includes native text-only college/country.
advancedMetricCatalog.bio_college={key:'bio_college',label:'College',description:'College attended, as reported by NBA.com.',engine:null,raw:['bio_college'],children:[],format:'text',decimals:0};
advancedMetricCatalog.bio_country={key:'bio_country',label:'Country',description:'Country reported by NBA.com.',engine:null,raw:['bio_country'],children:[],format:'text',decimals:0};
const physical=advancedGroups.find(g=>g.name==='Physical Profile');
if(physical)physical.keys.push('bio_college','bio_country');
// Expansion overrides used by the original Flutter family definitions.
const overrides:Record<string,Record<string,string[]>>={
 'Defensive / Hustle':{dreb:['contested_dreb_pg','uncontested_dreb_pg']},
 'Hustle Breakdown':{
  contested_shots_pg:['contested_twos_pg','contested_threes_pg'],
  screen_apg:['screen_assist_points_pg'],
  loose_balls_recovered_pg:['off_loose_balls_recovered_pg','def_loose_balls_recovered_pg','loose_ball_off_pct','loose_ball_def_pct'],
  box_outs_pg:['off_box_outs_pg','def_box_outs_pg','box_out_team_rebounds_pg','box_out_player_rebounds_pg','off_box_out_pct','def_box_out_pct','box_out_team_reb_pct','box_out_pct']
 },
 'Rebounding':{rpg:['contested_rpg','uncontested_rpg','trb_pct']}
};
export function advancedChildren(group:string,key:string):string[]{
 return overrides[group]?.[key]??advancedMetricCatalog[key]?.children??[];
}
