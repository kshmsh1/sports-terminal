import 'package:flutter/material.dart';

class WebsiteNbaStatGlossaryScreen extends StatefulWidget {
  const WebsiteNbaStatGlossaryScreen({super.key});

  @override
  State<WebsiteNbaStatGlossaryScreen> createState() => _WebsiteNbaStatGlossaryScreenState();
}

class _WebsiteNbaStatGlossaryScreenState extends State<WebsiteNbaStatGlossaryScreen> {
  final _search = TextEditingController();
  String _type = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final types = <String>{'All', ..._glossary.map((entry) => entry.type).where((type) => type.isNotEmpty)}.toList()..sort();
    final query = _search.text.trim().toLowerCase();
    final entries = _glossary.where((entry) {
      if (_type != 'All' && entry.type != _type) return false;
      if (query.isEmpty) return true;
      return '${entry.term} ${entry.name} ${entry.definition} ${entry.type} ${entry.contexts}'.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NBA Stat Glossary', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 8),
        Text(
          'Definitions, formulas and source contexts used across Sports Terminal. NBA terminology is kept distinct when similarly named metrics measure different things.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 330,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search metrics and definitions', isDense: true),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Metric type', isDense: true),
                    items: [for (final type in types) DropdownMenuItem(value: type, child: Text(type))],
                    onChanged: (value) { if (value != null) setState(() => _type = value); },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('${entries.length} definitions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1250 ? 3 : constraints.maxWidth >= 760 ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Text(entry.term, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                          if (entry.type.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
                              child: Text(entry.type, style: Theme.of(context).textTheme.labelSmall),
                            ),
                        ]),
                        if (entry.name.isNotEmpty && entry.name != entry.term) ...[
                          const SizedBox(height: 4),
                          Text(entry.name, style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 8),
                        Text(entry.definition, style: const TextStyle(height: 1.4)),
                        if (entry.formula.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Formula: ${entry.formula}', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                        ],
                        if (entry.contexts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Contexts: ${entry.contexts}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ]),
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _GlossaryEntry {
  const _GlossaryEntry(this.term, this.name, this.definition, this.type, {this.formula = '', this.contexts = ''});
  final String term;
  final String name;
  final String definition;
  final String type;
  final String formula;
  final String contexts;
}

const _glossary = <_GlossaryEntry>[
  _GlossaryEntry('GP', 'Games Played', 'The number of games played.', 'Traditional'),
  _GlossaryEntry('MIN', 'Minutes Played', 'The number of minutes played by a player or team.', 'Traditional', contexts: 'All'),
  _GlossaryEntry('PTS', 'Points', 'The number of points scored.', 'Traditional', contexts: 'Player · Clutch · Play Type · Scoring · Box Score · Tracking'),
  _GlossaryEntry('FG%', 'Field Goal Percentage', 'The percentage of field-goal attempts that a player makes.', 'Traditional', formula: 'FGM / FGA'),
  _GlossaryEntry('3P%', '3 Point Field Goal Percentage', 'The percentage of three-point attempts that a player makes.', 'Traditional', formula: '3PM / 3PA'),
  _GlossaryEntry('FT%', 'Free Throw Percentage', 'The percentage of free-throw attempts made.', 'Traditional', formula: 'FTM / FTA'),
  _GlossaryEntry('AST', 'Assists', 'Passes that lead directly to a made basket.', 'Traditional'),
  _GlossaryEntry('REB', 'Rebounds', 'Total offensive and defensive rebounds collected.', 'Traditional'),
  _GlossaryEntry('OREB', 'Offensive Rebounds', 'Rebounds collected while the player or team is on offense.', 'Traditional'),
  _GlossaryEntry('DREB', 'Defensive Rebounds', 'Rebounds collected while the player or team is on defense.', 'Traditional'),
  _GlossaryEntry('STL', 'Steals', 'Times a defensive player or team takes the ball from the offense, causing a turnover.', 'Traditional'),
  _GlossaryEntry('BLK', 'Blocks', 'Shots tipped by a defender before they can score.', 'Traditional'),
  _GlossaryEntry('TOV', 'Turnovers', 'Possessions where the offense loses the ball to the defense.', 'Traditional'),
  _GlossaryEntry('PF', 'Personal Fouls', 'Personal fouls committed by a player or team.', 'Traditional'),
  _GlossaryEntry('+/-', 'Plus-Minus', 'Point differential while a player or team is on the floor.', 'Traditional'),
  _GlossaryEntry('DD2', 'Double Doubles', 'Games in which a player reaches double digits in two of the five major box-score categories.', 'Traditional'),
  _GlossaryEntry('TD3', 'Triple Doubles', 'Games in which a player reaches double digits in three of the five major box-score categories.', 'Traditional'),
  _GlossaryEntry('FP', 'Fantasy Points', 'NBA fantasy-point total using the NBA scoring formula.', 'Traditional', formula: 'PTS + 1.2×REB + 1.5×AST + 3×STL + 3×BLK − TOV'),
  _GlossaryEntry('OFFRTG', 'Offensive Rating', 'Team points scored per 100 possessions. At player level, team points per 100 possessions while the player is on court.', 'Advanced', formula: '100 × Points / Possessions'),
  _GlossaryEntry('DEFRTG', 'Defensive Rating', 'Team points allowed per 100 possessions. At player level, team points allowed per 100 possessions while the player is on court.', 'Advanced', formula: '100 × Opponent Points / Opponent Possessions'),
  _GlossaryEntry('NetRtg', 'Net Rating', 'Point differential per 100 possessions; at player level it reflects team performance while the player is on court.', 'Advanced', formula: 'OFFRTG − DEFRTG'),
  _GlossaryEntry('AST%', 'Assist Percentage', 'Percentage of teammate field goals a player assisted on while on the floor.', 'Advanced', formula: 'AST / (Team FGM − Player FGM)'),
  _GlossaryEntry('AST/TO', 'Assist to Turnover Ratio', 'Assists compared with turnovers committed.', 'Advanced'),
  _GlossaryEntry('AST Ratio', 'Assist Ratio', 'Assists per 100 possessions used.', 'Advanced', formula: 'AST × 100 / POSS'),
  _GlossaryEntry('OREB%', 'Offensive Rebounding Percentage', 'Percentage of available offensive rebounds obtained while on the floor.', 'Advanced'),
  _GlossaryEntry('DREB%', 'Defensive Rebounding Percentage', 'Percentage of available defensive rebounds obtained while on the floor.', 'Advanced'),
  _GlossaryEntry('REB%', 'Rebounding Percentage', 'Percentage of available rebounds grabbed while on the floor.', 'Advanced'),
  _GlossaryEntry('TO Ratio', 'Turnover Ratio', 'Turnovers per 100 possessions used.', 'Advanced', formula: 'TOV × 100 / POSS'),
  _GlossaryEntry('eFG%', 'Effective Field Goal Percentage', 'Field-goal percentage adjusted because made threes are worth 1.5 times made twos.', 'Advanced', formula: '(FGM + 0.5×3PM) / FGA'),
  _GlossaryEntry('TS%', 'True Shooting Percentage', 'Shooting efficiency incorporating twos, threes and free throws.', 'Advanced', formula: 'PTS / [2 × (FGA + 0.44×FTA)]'),
  _GlossaryEntry('USG%', 'Usage Percentage', 'Percentage of team plays used by a player while on the floor.', 'Advanced'),
  _GlossaryEntry('PACE', 'Pace', 'Possessions per 48 minutes for a player or team.', 'Advanced'),
  _GlossaryEntry('PIE', 'Player Impact Estimate', 'Overall statistical contribution relative to total statistics in games played.', 'Advanced'),
  _GlossaryEntry('Poss', 'Possessions', 'Possessions played by a player or team. Offensive rebounds extend a possession rather than creating a new one.', 'Play Type'),
  _GlossaryEntry('%FGA 2PT', 'Percent of Field Goals Attempted — 2PT', 'Share of field-goal attempts that are two-point attempts.', 'Scoring'),
  _GlossaryEntry('%FGA 3PT', 'Percent of Field Goals Attempted — 3PT', 'Share of field-goal attempts that are three-point attempts.', 'Scoring'),
  _GlossaryEntry('%PTS 2PT', 'Percent of Points — 2PT', 'Share of points scored from two-point field goals.', 'Scoring'),
  _GlossaryEntry('%PTS 2PT MR', 'Percent of Points — Midrange', 'Share of points scored from midrange two-point field goals.', 'Scoring'),
  _GlossaryEntry('%PTS 3PT', 'Percent of Points — 3PT', 'Share of points scored from three-point field goals.', 'Scoring'),
  _GlossaryEntry('%PTS FBPS', 'Percent of Points — Fast Break', 'Share of points scored from fast-break opportunities.', 'Scoring'),
  _GlossaryEntry('%PTS FT', 'Percent of Points — Free Throws', 'Share of points scored from free throws.', 'Scoring'),
  _GlossaryEntry('%PTS OFF TO', 'Percent of Points — Off Turnovers', 'Share of points scored on the possession after forcing an opponent turnover.', 'Scoring'),
  _GlossaryEntry('%PTS PITP', 'Percent of Points — Paint', 'Share of points scored in the paint.', 'Scoring'),
  _GlossaryEntry('FGM %AST', 'Field Goals Made — Assisted', 'Percentage of made field goals assisted by a teammate.', 'Scoring'),
  _GlossaryEntry('FGM %UAST', 'Field Goals Made — Unassisted', 'Percentage of made field goals not assisted by a teammate.', 'Scoring'),
  _GlossaryEntry('2FGM %AST', 'Two-Point Field Goals Made — Assisted', 'Percentage of made twos assisted by a teammate.', 'Scoring'),
  _GlossaryEntry('2FGM %UAST', 'Two-Point Field Goals Made — Unassisted', 'Percentage of made twos not assisted by a teammate.', 'Scoring'),
  _GlossaryEntry('3FGM %AST', 'Three-Point Field Goals Made — Assisted', 'Percentage of made threes assisted by a teammate.', 'Scoring'),
  _GlossaryEntry('3FGM %UAST', 'Three-Point Field Goals Made — Unassisted', 'Percentage of made threes not assisted by a teammate.', 'Scoring'),
  _GlossaryEntry('DFG%', 'Defended Field Goal Percentage', 'Opponent field-goal percentage on shots where the player is the defender.', 'Defense', formula: 'DFGM / DFGA'),
  _GlossaryEntry('3P DFG%', 'Defended Three-Point Percentage', 'Opponent three-point percentage on defended three-point attempts. This is not the defender’s own 3P%.', 'Defense'),
  _GlossaryEntry('Rim DFG%', 'Field Goals Defended at Rim Percentage', 'Opponent percentage on shots defended at the rim.', 'Defense', formula: 'Rim DFGM / Rim DFGA'),
  _GlossaryEntry('DIFF%', 'Percentage Points Difference', 'Difference between a shooter’s normal percentage and percentage on shots defended by the selected player or team.', 'Defense'),
  _GlossaryEntry('Deflections', 'Deflections', 'Times a defender gets a hand on the ball on a non-shot attempt.', 'Hustle'),
  _GlossaryEntry('Charges Drawn', 'Charges Drawn', 'Times a defensive player or team draws a charge.', 'Hustle'),
  _GlossaryEntry('Contested Shots', 'Contested Shots', 'Times a defender closes out and raises a hand to contest a shot before release.', 'Hustle'),
  _GlossaryEntry('Contested 2PT Shots', 'Contested 2PT Shots', 'Contested two-point shots.', 'Hustle'),
  _GlossaryEntry('Contested 3PT Shots', 'Contested 3PT Shots', 'Contested three-point shots.', 'Hustle'),
  _GlossaryEntry('Loose Balls Recovered', 'Loose Balls Recovered', 'Times a player or team gains sole possession of a live ball not controlled by either team.', 'Hustle'),
  _GlossaryEntry('Boxouts', 'Boxouts', 'Successful physical efforts that disadvantage an opponent pursuing a rebound and prevent that opponent from securing it.', 'Hustle'),
  _GlossaryEntry('DEF WS', 'Defensive Win Shares', 'Estimated share of team wins contributed by a player’s defense.', 'Defense'),
  _GlossaryEntry('Contested REB', 'Contested Rebounds', 'Rebounds collected with an opponent within 3.5 feet.', 'Rebounding'),
  _GlossaryEntry('Uncontested REB', 'Uncontested Rebounds', 'Rebounds collected with no opponent within 3.5 feet.', 'Rebounding'),
  _GlossaryEntry('REB Chances', 'Rebound Chances', 'A rebound chance occurs when the player is closest to the ball during the rebound window.', 'Rebounding'),
  _GlossaryEntry('REB Chance%', 'Rebound Chance Percentage', 'Rebounds recovered divided by rebound chances.', 'Rebounding', formula: 'REB / REB Chances'),
  _GlossaryEntry('Deferred REB Chances', 'Deferred Rebound Chances', 'Rebound chances where the player allows a teammate to collect the rebound.', 'Rebounding'),
  _GlossaryEntry('Adjusted REB Chance %', 'Adjusted Rebound Chance Percentage', 'Rebound chance percentage excluding deferred rebounds.', 'Rebounding', formula: 'REB / (REB Chances − Deferred REB Chances)'),
  _GlossaryEntry('AVG REB Distance', 'Average Rebound Distance', 'Average distance of a rebound.', 'Rebounding'),
  _GlossaryEntry('Drives', 'Drives', 'Halfcourt attacks toward the basket off the dribble, excluding catches already moving close to the basket and immediate perimeter cutoffs.', 'Tracking'),
  _GlossaryEntry('Drive FG%', 'Drive Field Goal Percentage', 'Field-goal percentage on drives.', 'Tracking'),
  _GlossaryEntry('Drive PTS', 'Drive Points', 'Points scored on drives.', 'Tracking'),
  _GlossaryEntry('Passes Made', 'Passes Made', 'Total passes made per game.', 'Tracking'),
  _GlossaryEntry('Passes Received', 'Passes Received', 'Total passes received per game.', 'Tracking'),
  _GlossaryEntry('Secondary Assist', 'Secondary Assist', 'Pass to a teammate who records an assist within one second and without dribbling.', 'Tracking'),
  _GlossaryEntry('Potential AST', 'Potential Assists', 'Passes to teammates who shoot within one dribble of receiving the ball.', 'Tracking'),
  _GlossaryEntry('FT Assists', 'Free Throw Assists', 'Passes to a teammate who draws a shooting foul within one dribble.', 'Tracking'),
  _GlossaryEntry('AST ADJ', 'Assists Adjusted', 'Assists plus free-throw assists plus secondary assists.', 'Tracking'),
  _GlossaryEntry('AST PTS Created', 'Assist Points Created', 'Points created through credited assists.', 'Tracking'),
  _GlossaryEntry('AST to PASS%', 'Assist to Pass Percentage', 'Percentage of passes made that become assists.', 'Tracking', formula: 'AST / Passes Made'),
  _GlossaryEntry('AST to PASS% ADJ', 'Adjusted Assist to Pass Percentage', 'Percentage of passes that become assists, free-throw assists or secondary assists.', 'Tracking', formula: 'Adjusted AST / Passes Made'),
  _GlossaryEntry('Touches', 'Touches', 'Times a player or team touches and possesses the ball.', 'Tracking'),
  _GlossaryEntry('FRONT CT TOUCHES', 'Front Court Touches', 'Touches made in the front court.', 'Tracking'),
  _GlossaryEntry('TIME OF POSS', 'Time of Possession', 'Minutes a player or team possesses the ball.', 'Tracking'),
  _GlossaryEntry('AVG SEC PER TOUCH', 'Average Seconds per Touch', 'Average seconds per touch.', 'Tracking'),
  _GlossaryEntry('AVG DRIB PER TOUCH', 'Average Dribbles per Touch', 'Average dribbles taken per touch.', 'Tracking'),
  _GlossaryEntry('PTS PER TOUCH', 'Points per Touch', 'Points scored per touch.', 'Tracking'),
  _GlossaryEntry('Catch Shoot FG%', 'Catch-and-Shoot Field Goal Percentage', 'Field-goal percentage on catch-and-shoot attempts.', 'Tracking'),
  _GlossaryEntry('Catch Shoot PTS', 'Catch-and-Shoot Points', 'Points scored on catch-and-shoot attempts.', 'Tracking'),
  _GlossaryEntry('Pull Up FG%', 'Pull-Up Field Goal Percentage', 'Field-goal percentage on pull-up attempts.', 'Tracking'),
  _GlossaryEntry('Pull Up PTS', 'Pull-Up Points', 'Points scored on pull-up attempts.', 'Tracking'),
  _GlossaryEntry('Paint Touch', 'Paint Touch', 'Touch where a player receives the ball inside the three-second lane.', 'Tracking'),
  _GlossaryEntry('Post Touches', 'Post Touches', 'Touches made in the post.', 'Tracking'),
  _GlossaryEntry('Elbow Touch', 'Elbow Touch', 'Touch where a player receives the ball near the free-throw line.', 'Tracking'),
  _GlossaryEntry('Dist. Miles', 'Distance Miles', 'Distance run measured in miles.', 'Tracking', formula: 'Distance Feet / 5280'),
  _GlossaryEntry('Avg Speed', 'Average Speed', 'Average speed in miles per hour across all on-court movement.', 'Tracking'),
  _GlossaryEntry('Avg Speed Off', 'Average Speed Offense', 'Average speed while on offense.', 'Tracking'),
  _GlossaryEntry('Avg Speed Def', 'Average Speed Defense', 'Average speed while on defense.', 'Tracking'),
  _GlossaryEntry('PPP', 'Points Per Possession', 'Points scored per possession.', 'Play Type'),
  _GlossaryEntry('Freq', 'Frequency', 'Share of total events or possessions fitting the selected play-type criteria.', 'Play Type'),
  _GlossaryEntry('FT Freq', 'Free Throw Frequency', 'Share of plays producing free throws as the result of a foul.', 'Play Type'),
  _GlossaryEntry('TO Freq', 'Turnover Frequency', 'Share of plays ending in a turnover.', 'Play Type'),
  _GlossaryEntry('SF Freq', 'Shooting Foul Frequency', 'Share of plays producing free throws because of a shooting foul.', 'Play Type'),
  _GlossaryEntry('And One Freq', 'And One Frequency', 'Share of plays producing a made field goal plus a free throw.', 'Play Type'),
  _GlossaryEntry('Score Freq', 'Score Frequency', 'Share of plays producing at least one point.', 'Play Type'),
  _GlossaryEntry('Percentile', 'Percentile', 'PPP ranking versus eligible league players or teams.', 'Play Type'),
  _GlossaryEntry('%FGM', "Percent of Team's Field Goals Made", 'Share of team made field goals credited to the player while on court.', 'Usage'),
  _GlossaryEntry('%FGA', "Percent of Team's Field Goals Attempted", 'Share of team field-goal attempts taken by the player while on court.', 'Usage'),
  _GlossaryEntry('%3PM', "Percent of Team's Three-Point Field Goals Made", 'Share of team made threes credited to the player while on court.', 'Usage'),
  _GlossaryEntry('%3PA', "Percent of Team's Three-Point Field Goals Attempted", 'Share of team three-point attempts taken by the player while on court.', 'Usage'),
  _GlossaryEntry('%AST', "Percent of Team's Assists", 'Share of team assists credited to the player while on court.', 'Usage'),
  _GlossaryEntry('%TOV', "Percent of Team's Turnovers", 'Share of team turnovers credited to the player while on court.', 'Usage'),
  _GlossaryEntry('%PTS', "Percent of Team's Points", 'Share of team points scored by the player while on court.', 'Usage'),
  _GlossaryEntry('Wingspan', 'Wingspan', 'Horizontal fingertip-to-fingertip measurement with arms extended.', 'Combine'),
  _GlossaryEntry('Standing Reach', 'Standing Reach', 'Highest reach while standing still with the arm extended overhead.', 'Combine'),
  _GlossaryEntry('Hand Length', 'Hand Length', 'Distance from the bottom of the palm to the tip of the middle finger.', 'Combine'),
  _GlossaryEntry('Hand Width', 'Hand Width', 'Distance from thumb tip to pinky tip with the hand outstretched.', 'Combine'),
  _GlossaryEntry('Standing Vertical Leap', 'Standing Vertical Leap', 'Vertical leap with no running start.', 'Combine'),
  _GlossaryEntry('Max Vertical Leap', 'Max Vertical Leap', 'Vertical leap with steps to gather before jumping.', 'Combine'),
  _GlossaryEntry('Lane Agility', 'Lane Agility', 'Timed drill measuring lateral quickness and agility.', 'Combine'),
  _GlossaryEntry('Shuttle Run', 'Shuttle Run', 'Timed drill measuring agility and change of direction.', 'Combine'),
  _GlossaryEntry('Three Quarter Sprint', 'Three Quarter Sprint', 'Timed sprint from baseline through three quarters of the court.', 'Combine'),
];
