# Competitor-Driven Feature Backlog

This backlog translates the competitive landscape into concrete Sports Terminal build modules. It should guide future product pushes so we do not drift into generic dashboards or isolated analytics tabs.

## Universal features

| Feature | User job | Product implementation |
| --- | --- | --- |
| Universal command bar | Ask anything, search anything, jump anywhere. | Search players/teams/games/pages now; later add natural-language query interpreter, saved queries, and source-backed answer cards. |
| Source and method panel | Trust a number. | Every stat module gets source, filter, date, and method metadata. |
| Save to workspace | Continue analysis later. | Any table/chart/player card can be sent to the Excel-like workbook. |
| Share to community | Turn analysis into discussion. | Any player/team/game/trade/workbook/article can create a thread. |
| Compare mode | Evaluate two players, teams, games, or scenarios. | Side-by-side cards, percentile differences, trend deltas, and export. |
| Watchlist alerts | Follow what matters. | Persisted watchlists plus threshold triggers once backend jobs exist. |
| Entity-attached articles | Turn analysis into readable content. | CMS modules on player/team/game pages. |

## Player-page feature backlog

| Module | Inspired by | Build goal |
| --- | --- | --- |
| Overview card | NBA.com, Dunks & Threes | Bio, team, role, season summary, recent form, watchlist button. |
| Stat modes | NBA.com, databallr | Per-game, per-75, totals, advanced, percentiles. |
| Impact card | Dunks & Threes, NBA RAPM, BBall Index | Impact score slots, offense/defense split, metric comparison and methodology notes. |
| Role/archetype | BBall Index, Dynatyze | Scorer/playmaker/rim protector/etc. labels based on transparent thresholds first. |
| Game log | NBA.com, Proballers | Sortable game table with highs/lows and trend chart. |
| On/off / WOWY | PBP Stats, Cleaning the Glass, databallr | Player on/off, with/without teammate filters. |
| Shot profile | NBA.com, databallr, Hooper-style shot cards | Zones, rim/midrange/three/FT profile, similarity matches. |
| Fantasy panel | Dynatyze, ESPN/Yahoo ecosystem | Fantasy score, watchlist notes, role alerts, league import later. |
| Contract panel | SalarySwish, Spotrac, HoopsHype | Salary, years, options, cap hit, trade eligibility. |
| Discussion | Fanspo | Player-attached threads, polls, saved posts, moderation. |

## Team-page feature backlog

| Module | Inspired by | Build goal |
| --- | --- | --- |
| Team pulse | NBA.com, Dunks & Threes | Record, net rating, offense/defense rank, recent form. |
| Roster/rotation | SalarySwish, Cleaning the Glass | Active roster, minutes, roles, status, rotation graph. |
| Lineups | NBA.com, PBP Stats | Lineup performance, stints, on/off, closing groups. |
| Four factors | Cleaning the Glass | Offensive/defensive four factors with explanation. |
| Schedule/results | NBA.com, ESPN | Results, upcoming games, game cards, trends. |
| Salary/cap | SalarySwish, Spotrac | Team payroll, cap room, apron, exceptions, trade assets. |
| Trade needs | Fanspo, HoopsMatic | Needs board, realistic target list, scenario launcher. |
| Team room | Fanspo | Team-specific discussion, polls, shared workbooks. |

## Game-page feature backlog

| Module | Inspired by | Build goal |
| --- | --- | --- |
| Scoreboard | NBA.com, ESPN | Final/live score, period scoring, game state. |
| Box score | NBA.com | Basic and advanced player/team rows. |
| Four factors | Cleaning the Glass | Why the game was won/lost. |
| Momentum | Dunks & Threes | Lead changes, runs, win-probability-style chart. |
| Play-by-play | PBP Stats | Event timeline and filters. |
| Lineup stints | PBP Stats | Which units won/lost stretches. |
| Recap builder | NBA.com articles, StatMuse facts | Auto-draft recap from game facts and top rows. |
| Discussion | Fanspo | Game thread, postgame reactions, report/moderation. |

## Workspace backlog

| Feature | Why it matters |
| --- | --- |
| Copy/paste | Makes it feel like a real workbook. |
| Import table from NBA Hub | Connects data surfaces to analysis. |
| Formulas beyond SUM/AVG/MIN/MAX | Enables actual modeling. |
| Saved multi-sheet workbooks | Needed for fantasy boards, trade boards, and research. |
| Charts | Make workbooks visual and shareable. |
| Scenario tabs | Let trades, lineups, and fantasy boards live inside one workbook. |
| Backend sync | Makes the workspace cross-device and shareable. |

## Community/social backlog

| Feature | Inspired by | Product goal |
| --- | --- | --- |
| Entity threads | Fanspo, Reddit-like team spaces | Threads attached to players, teams, games, trades, and articles. |
| Polls | Fanspo | Quick debate and prediction modules. |
| Trade reactions | Fanspo, HoopsMatic | Vote on realism, team winner, fan acceptance. |
| Tier lists / rankings | databallr, Fanspo | User-created rankings with data embeds. |
| Moderation queue | Safety requirement | Reports, statuses, audit log, bans/mutes/blocks. |
| Reputation | Quality control | Weight high-quality users/comments without making product elitist. |

## Front-office/cap backlog

| Feature | Inspired by | Product goal |
| --- | --- | --- |
| Contract cards | Spotrac, SalarySwish, HoopsHype | Player salary, options, guarantees, trade restrictions. |
| Team cap sheet | SalarySwish, Spotrac | Payroll, apron, cap room, exceptions, tax. |
| Trade machine | Fanspo, HoopsMatic, SalarySwish | Salary legality plus basketball impact and community response. |
| Free agency tracker | HoopsHype, SalarySwish | Signings, unsigned players, projections. |
| Draft board | Fanspo, SalarySwish, databallr | Prospect ranking, mock draft, team needs. |
| Scenario save/share | Unique advantage | Save trades as objects; discuss, compare, export to workspace. |

## Defensive moat

The moat is not a single stat. It is the integration layer: every stat, scenario, article, post, message, and workbook points back to the same canonical objects. Competitors win specific jobs. Sports Terminal should win the entire workflow.
