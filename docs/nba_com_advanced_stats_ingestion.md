# NBA.com Advanced Stats Endpoint Discovery and Ingestion

## Purpose

This subsystem maps the NBA.com Stats application into an inspectable Sports Terminal data contract without making the historical website depend on NBA.com at runtime.

The target architecture is:

```text
NBA.com Stats browser surfaces
        ↓
DevTools HAR endpoint/parameter discovery
        ↓
reviewed endpoint + schema inventory
        ↓
authorized/licensed response files
        ↓
raw immutable landing zone + provenance
        ↓
Sports Terminal normalization/warehouse/static compiler
        ↓
Stats / Advanced Stats / player / team / game pages
```

The browser-facing Sports Terminal remains static-first. NBA.com is never queried by Flutter while a user browses historical data.

## Current source constraints

NBA.com currently states that:

- advanced statistics go back to the 1996-97 season;
- lineup data goes back to 2008;
- base stats and digitized box scores reach back to the inaugural 1946-47 season;
- NBA.com Stats data is not offered for download in CSV form; and
- the NBA.com Terms of Use place restrictions on use of NBA Statistics, including comprehensive regularly updated databases and commercial products without prior consent.

Official references:

- https://www.nba.com/stats/help/faq
- https://www.nba.com/termsofuse

Because Sports Terminal is intended to become a commercial product, this repository does **not** ship an automated bulk downloader that bypasses or ignores those restrictions. The tools below perform endpoint discovery from browser traffic and normalize response files that the developer is authorized to use. A future licensed collector can plug into the same contracts without changing the downstream architecture.

## What is inventoried

`tools/nba_com_stats_registry.py` contains the visible NBA Stats families we want to map, including:

- Players / Teams / Lineups → Advanced
- Misc
- Scoring
- Usage
- Opponent
- Defense
- Estimated Advanced
- Clutch
- Tracking
- Defense Dashboard
- Shot Dashboard
- Play Type
- Advanced Box Scores
- Shooting
- Opponent Shooting
- Hustle
- Box Outs

The registry records the product surface, entity grain, known historical boundary, official page, and any endpoint hints. Endpoint hints are **not** treated as public API guarantees; the actual request path and parameters must be confirmed from the browser network trace.

List the registry:

```bash
python3 tools/nba_com_stats_registry.py
```

Machine-readable form:

```bash
python3 tools/nba_com_stats_registry.py --json
```

## Endpoint discovery workflow

Use a normal browser session and Chrome/Edge DevTools.

1. Open the NBA Stats surface to investigate, for example Players → General → Advanced.
2. Open DevTools → Network.
3. Select Fetch/XHR and enable Preserve log.
4. Clear the network list.
5. Change **one filter at a time**.
6. Record a useful sequence such as:
   - Season
   - Season Type
   - Per Mode
   - Position
   - Team
   - VS Team
   - Outcome
   - Location
   - Shot Clock Range
   - Quarter
   - By Half
   - Playoff Round
   - Date From / Date To
7. Export the network trace as a HAR file locally.
8. Do not commit the HAR. HAR files may contain cookies or other browser/session material.

Then run:

```bash
python3 tools/inventory_nba_com_stats_har.py ~/Downloads/nba-advanced.har
```

This produces local, gitignored files:

```text
artifacts/nba_com_stats_endpoint_inventory.json
artifacts/nba_com_stats_endpoint_inventory.md
```

The inventory tool intentionally strips:

- Cookie headers
- Authorization headers
- token/session/key-like query parameters

It groups requests by method + host + path and records observed parameter names/values, response status, MIME type, referer surface, and observation count.

### Why one filter at a time matters

If Season, Position, Team, Quarter, Location, and Date Range all change together, it becomes difficult to determine which request parameter corresponds to which product control. A controlled one-variable-at-a-time trace gives us a reproducible mapping from UI semantics to request semantics.

## Lowest useful grain

We do not want to replay every possible combination of NBA.com's filters. The objective is to identify the lowest useful data grain and derive higher-level filtering ourselves.

Priority order:

1. player-game advanced box scores (1996-97 onward where available)
2. team-game advanced box scores
3. lineup-level data
4. tracking tables
5. shot/defense/play-type/hustle/box-out tables
6. season aggregate tables for cross-checking and source parity

If we possess a player-game advanced table, Sports Terminal can locally derive many slices such as date range, opponent, wins/losses, home/road, and parts of season segmentation without issuing a separate source request for every filter combination.

## Authorized response import

If you have a JSON response that you are permitted to use—such as a licensed export, an authorized partner response, or another explicitly permitted source—normalize it with:

```bash
python3 tools/import_nba_com_authorized_response.py \
  ~/Downloads/advanced.json \
  --surface players_advanced \
  --season 2025-26 \
  --season-type "Regular Season"
```

The command makes **no network requests**. It writes to the gitignored local landing zone:

```text
raw/nba_com_stats/
  players_advanced/
    2025-26/
      regular-season/
        source.json
        normalized.json
        metadata.json
```

`source.json` is the untouched input. `normalized.json` converts NBA-style `headers + rowSet` result sets into row dictionaries. `metadata.json` records SHA-256, byte size, row counts, surface identity, import time, and a rights-review flag.

The importer deliberately defaults commercial-use and redistribution rights to **unverified**. The presence of a file never upgrades its rights state.

## Planned warehouse mapping

Once endpoint discovery is complete, the normalized families should map into dedicated facts rather than one enormous table:

```text
fact_player_game_advanced
fact_team_game_advanced
fact_lineup
fact_tracking
fact_shot
fact_defense_matchup
fact_playtype
fact_clutch
fact_hustle
fact_boxout
```

Each fact should retain:

- source surface
- source request fingerprint
- source response fingerprint
- season
- season type
- observed/filter context
- ingested timestamp
- source/license class
- display/export/redistribution rights state

## Sports Terminal category mapping

The new source families ultimately feed the existing analytical taxonomy:

- **Shooting & Efficiency:** eFG%, TS%, shot zones, catch-and-shoot, pull-ups, defender distance
- **Playmaking & Creation:** AST%, AST/TO, potential assists, passes, touches, drives
- **Defense:** DefRtg, matchup/defender dashboard, contested shots, DFG-related fields
- **Rebounding:** OREB%, DREB%, REB%, rebound chances, box outs
- **Impact:** OffRtg, DefRtg, NetRtg, PIE, possessions, lineup impact
- **Clutch:** context-specific clutch splits
- **Gravity & Spacing:** touches, passes, drives, shooting/defender proximity, lineup context
- **On/Off & Lineups:** lineup and possession-level data where source coverage supports it
- **Play Types:** isolation, transition, pick-and-roll, post-up, spot-up, handoff, cut, off-screen, putback, etc.

Coverage must remain era-aware. A metric should be unavailable—not fabricated—when the underlying NBA source does not provide it for the selected season.

## Validation

Run:

```bash
python3 tools/nba_com_stats_contract_test.py
```

The contract checks the registry, HAR privacy stripping, response normalization, and the intentional no-network behavior of the authorized-response importer.
