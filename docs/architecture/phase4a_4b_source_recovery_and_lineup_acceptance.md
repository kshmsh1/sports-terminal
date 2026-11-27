# Arcside Phase 4A/4B — source-qualified recovery and acceptance

Status: **Code implemented on PR #97; actual owner-local NBA corpus acceptance pending.** The previous 9,101 missing references are a sum of missing game IDs per captured scope, not a guaranteed 9,101 recoverable distinct games.

## Phase 4A

The existing canonical game builder initially reads the Wyatt historical game source. The separately captured NBA.com traditional player game logs include entire additional season/segment groups. The new tool `tools/phase4_recover_capture_games.py` validates each missing game against source date, season, NBA game/team/player IDs, two teams, complementary home/away matchup and consistent final scores before inserting canonical game, team-game, player-game and source-provenance rows. Ambiguous source records are rejected and reported rather than guessed.

The original full v5 static compiler replaces the output tree, which can delete captured NBA.com materializations. For recovery, `tools/phase4_publish_recovered_games.py` updates the existing v5 game index incrementally, preserving old references and the NBA.com capture tree, while backing up index, manifest, season and coverage metadata. It calls the existing source-aware box-score detail materializer.

On your Mac, run from the existing Phase 4 branch:

```bash
cd ~/sports_terminal
git fetch origin
git switch phase4/react-product-migration
git pull --ff-only
python3 -m unittest discover -s test -p 'phase4_*test.py' -v
python3 tools/phase4_recover_capture_games.py
```

The last command is preview-only. Inspect the generated ignored JSON report `experimental/arcside-react/evidence/coverage/phase4a-recovery.json` for counts qualified and rejected by reason. When ready to apply, the first command below creates an SQLite-consistent database backup; inspect its printed path. The second previews how many public game-index rows are missing. The third updates original v5 static metadata and publishes real detail files from the previously captured data:

```bash
python3 tools/phase4_recover_capture_games.py --apply
python3 tools/phase4_publish_recovered_games.py
python3 tools/phase4_publish_recovered_games.py --apply
python3 tools/phase4_warehouse_audit.py --verify-details
node experimental/arcside-react/scripts/phase4_source_coverage.mjs
```

Acceptance: zero contradictory or duplicate canonical identities; existing game/detail records retained; actual published player box-score details valid; each still-missing captured game explained by a source-specific rejection reason. Report actual recovered numbers **only after** the owner's local audit. Never run the resetting canonical builder against the sole local database merely for this recovery; the standalone importer is safer. Do not run the old full v5 static compiler over this archive unless captured source preservation is separately established.

## Phase 4B

The new `tools/phase4_materialize_with_without.py` consumes the event-level Wyatt play-by-play table identified in the existing warehouse inventory. Event ordering, player-to-team identities, game clocks, substitution transitions, and scores are validated. A time interval contributes minutes only once the five on-court players for both teams are evidenced. Earlier unverified time is excluded. A contradicted lineup fails closed. Source-quality and covered seconds are included in the output rather than implied to represent a full NBA season.

The pair output's available numerical metrics are team-on-court PTS and +/- per 36, plus observed together/apart minutes. They are not personal player box-score totals, nor complete-season stats. Scores are suppressed when scoreboard reconciliation fails; all unavailable metrics remain blank. Both the React page and output explain partial coverage and units.

Preview a season, inspect the ignored local coverage report, then publish source-qualified rows:

```bash
python3 tools/phase4_materialize_with_without.py --season 2022-23
python3 tools/phase4_materialize_with_without.py --season 2022-23 --publish
node experimental/arcside-react/scripts/phase4_source_coverage.mjs
```

To attempt all historical source-supported scopes **after checking a representative season**, run:

```bash
python3 tools/phase4_materialize_with_without.py --publish
node experimental/arcside-react/scripts/phase4_source_coverage.mjs
```

A season with no verified stints remains unpublished; the generator refuses to overwrite unrelated prior lineup data. The full warehouse and multi-million-event PBP exist only on your Mac, so the definitive number of published splits is currently unknown. Coverage is not 100% until established by independent evidence.

## CI and rollback

The Historical Research Quality GitHub workflow includes synthetic tests for strict captured-game ingestion and partial lineup reconstruction. These confirm safe behavior on fixtures, **not real historical coverage**. The 4C–4F migration packages, retained performance failure, exhaustive CBA review and native/device gates are unchanged. Keep Flutter as an executable fallback.

## November 26 corrective implementation and release gates

Owner-local 2022-23 results: 2,558 accepted PBP periods across regular/playoffs. That is not certified full-game individual or possession accuracy.

Historical aliases now resolve strictly by season+NBA team ID+abbreviation: CHP / 1610612764 / 1961-62 and NYN / 1610612751 / 1976-77. Re-run preview before --apply: 162 candidates were previously rejected only for this identity conflict. Remaining 25 cases (10 home/away conflicts, 12 score contradictions, 3 tied final point sums) require independent game-specific score/box-score verification. Never override those inconsistencies simply to force acceptance.

New opt-in NBA.com capture utility: `tools/phase4_collect_nba_pbp.py`. This uses canonical game IDs, verifies response `gameId` and `actions` array, caches original responses, spaces requests, defaults to ten requests, and stops on HTTP 403/429. It never alters canonical tables or publishes lineups. Respect source terms and never bypass access restrictions.

```bash
python3 tools/phase4_collect_nba_pbp.py --season 2025-26 --segment regular
python3 tools/phase4_collect_nba_pbp.py --season 2025-26 --segment regular --fetch --limit 10 --delay 2
python3 tools/phase4_collect_nba_pbp.py --season 2024-25 --segment playoffs --fetch --limit 10 --delay 2
```

Raw NBA Live V3 action rows have a different schema from Wyatt legacy play-by-play and require an independently validated adapter before statistical materialization. Existing 4B partial splits should not be promoted to full-season player stats.

NBA.com requested source data, if accessible: full action-level play-by-play JSON for 2023-24, 2024-25, 2025-26; complete game box scores including players' actual minutes and starters for the same IDs; official final scores for the 25 historical contradictions. Preserve original JSON, game IDs, URLs and capture timestamps. Avoid screenshots when raw machine-readable responses are available.

### Official starter and minute audit (code added)

NBA Live data is available in two distinct raw feeds: `playbyplay/playbyplay_{gameId}.json` and `boxscore/boxscore_{gameId}.json`. The source collector supports `--kind pbp` (default) and `--kind boxscore`, storing immutable raw JSON under `web/data/nba_static/nba_com/pbp_live/<kind>/<season>/<segment>/<game-id>.json`. It is opt-in and does not convert modern action formats to the historical Wyatt format.

```bash
python3 tools/phase4_collect_nba_pbp.py --season 2022-23 --segment regular --kind boxscore --fetch --limit 10 --delay 2
python3 tools/phase4_audit_pbp_vs_boxscore.py --season 2022-23
```

The external minute audit verifies official final score, team identity, optional opening five (only when the reconstructed first interval starts at 12:00 and the boxscore has exactly five starter flags) and upper bounds for each reconstructed player's court seconds. It does not certify an exact score-event attribution, full-game minutes, possessions or individual shooting statistics. A valid audit must have `verified_player_minute_upper_bound > 0`, zero mismatches on published games and separately validated possession rules before production approval.

The legacy reconstruction still rejects descending-clock violations and incomplete periods. No fabricated clock repair is performed; NBA.com V3 source capture and conversion must be separately certified. There is no safe basis for publishing final 2023-26 splits until that adapter exists.

### Modern NBA Live V3 source-qualified Q1 adapter

The new `tools/phase4_materialize_live_nba_pbp.py` uses captured NBA Live play-by-play actions and matching official boxscore starters. It reconstructs only quarter 1, requires exactly five independently identified starters on both teams, handles explicitly paired out/in substitution actions at an identical clock, verifies that official player-minute upper bounds are respected, and fails closed for ambiguous substitutions, final-score discrepancies or clock reversals. Scores at substitution timestamps are suppressed if attribution is ambiguous. This is not a full-game player-stat or possession engine.

```bash
python3 tools/phase4_collect_nba_pbp.py --season 2025-26 --segment regular --kind pbp --fetch --limit 10 --delay 2
python3 tools/phase4_collect_nba_pbp.py --season 2025-26 --segment regular --kind boxscore --fetch --limit 10 --delay 2
python3 tools/phase4_materialize_live_nba_pbp.py --season 2025-26 --segment regular
```

Only after reviewing the generated Q1 report and testing against real official game files should `--publish` be considered. Publication still carries explicit `nba_live/q1_starters_and_actions` provenance and first-quarter partial coverage; full-season comparisons must not treat it as equivalent to entire-game data.

### Targeted 4A neutral-site official boxscores

Ten remaining home/away collisions are specific 2024-25 and 2025-26 regular-season games. Their captured traditional game logs are already on the owner machine; those IDs can be passed to the official source collector even before recovery into canonical tables. The source collector refuses IDs not present in the canonical DB or captured source. Game-specific NBA official homeTeam / awayTeam is accepted **only when** both team IDs, final scores, and nonempty boxscore player lists agree with the captured player rows. Otherwise the original rejection is preserved.

```bash
python3 tools/phase4_collect_nba_pbp.py --season 2024-25 --segment regular --kind boxscore --fetch --delay 2 --game-id 0022400147 --game-id 0022400621 --game-id 0022400633 --game-id 0022401229 --game-id 0022401230
python3 tools/phase4_collect_nba_pbp.py --season 2025-26 --segment regular --kind boxscore --fetch --delay 2 --game-id 0022500147 --game-id 0022500578 --game-id 0022500602 --game-id 0022501229 --game-id 0022501230
python3 tools/phase4_recover_capture_games.py
```

The first two commands are opt-in HTTP downloads; each stops on 403/429 and caches source response. The third previews local recovery only. If the official source does not support a game, do not infer home assignment from date or tournament context. The 15 older scoring inconsistencies require independently audited player-level statistics and official scores, not merely an override of the result field.
