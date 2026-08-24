# NBA.com Stats Local Landing Zone

This directory is reserved for **local, uncommitted** NBA.com Stats response files that the developer is authorized to use.

The repository commits this README only. Response bodies, HAR files, session material, and generated normalized data must remain local.

## Discovery

Use:

```bash
python3 tools/inventory_nba_com_stats_har.py ~/Downloads/nba-stats.har
```

for endpoint discovery.

## Import a captured response

Save the response JSON locally, then run:

```bash
python3 tools/import_nba_com_authorized_response.py RESPONSE.json \
  --surface players_advanced \
  --season 2025-26 \
  --season-type "Regular Season"
```

The importer writes an exact local source copy plus `normalized.json` and provenance metadata under:

```text
raw/nba_com_stats/<surface>/<season>/<season-type>/
```

A response or PDF pasted into ChatGPT, or an endpoint marked confirmed in the registry, is **not** automatically a local data import. The response must exist in this landing zone as normalized local data before the application can display its values.

## Website integration

Normal application launch now runs the offline NBA.com enrichment step automatically after the historical static compiler:

```bash
bash scripts/open_terminal.sh
```

The enrichment step performs **no NBA.com network requests**. It reads only already-imported local `normalized.json` files, joins player-season aggregate surfaces into the canonical season rows, derives explicitly defined per-game values such as deflections per game from the source surface's own games denominator, and preserves exact source rows under namespaced provenance.

Currently integrated player-season surfaces are Base, Advanced, Misc, Scoring, Usage, Defense, Estimated Advanced, Defense Dashboard, Hustle, and Violations. Opponent/on-court, lineup, game-log, leaderboard and other non-player-season grains are intentionally not flattened into player-season rows.

The generated static manifest records the NBA.com enrichment fingerprint, matched and unmatched source-row counts, and surface coverage. A changed local capture fingerprint causes enrichment to run on the next normal launch even when the historical SQLite warehouse itself is unchanged.

For an explicit re-run of only the offline enrichment layer:

```bash
python3 tools/nba_com_static_enrichment.py --force
```

For the deterministic regression contract:

```bash
python3 tools/nba_com_static_enrichment_test.py
```

Do not place cookies, authorization tokens, API keys, or licensed vendor credentials in committed files.
