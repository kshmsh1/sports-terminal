# Historical Basketball Reference Crawler

The historical crawler is designed for the way Basketball Reference actually organizes NBA data: table-oriented pages whose cells link to players, teams, seasons, games, coaches, awards, playoff series, and related pages.

The screenshots used during design are examples of the page structure only. Their displayed values are not imported by this crawler implementation.

## Why link-aware collection matters

A flat table export preserves the numbers but loses much of the identity graph. For example, the text `Boston Celtics` may link to a specific team-season page, while `Jayson Tatum` links to a stable provider player page. The crawler stores both the displayed cell and the provider link so later normalization can resolve the row to a Sports Terminal entity without guessing from names alone.

Each parsed row stores:

```text
Typed values
Original display text
Section heading
Row class
Provider links by column
Stable provider source keys
```

## Architecture

The collection pipeline has five layers.

### 1. URL catalog and queue

`tools/sports_reference/url_scope.py` canonicalizes Basketball Reference URLs, removes query strings and fragments, rejects non-Basketball-Reference hosts, and assigns each supported page to a bounded family.

Supported families include:

```text
league
playoff
team_season
team_history
franchise
player
boxscore
boxscore_detail
draft
award
allstar
coach
executive
```

Each URL receives a provider source key, season when identifiable, team abbreviation when identifiable, and crawl priority.

### 2. Respectful cached client

`tools/sports_reference/client.py` uses:

```text
A descriptive user agent
A strict host allowlist
robots.txt checks by default
A minimum request interval
Bounded retries for transient server errors
Immediate stopping on HTTP 403 or 429
An on-disk HTML cache
```

The crawler does not include proxy rotation, CAPTCHA bypassing, identity rotation, browser automation, or any other access-control evasion.

### 3. Generic table and link parser

`tools/sports_reference/table_parser.py` parses every table on a fetched page, including tables wrapped in HTML comments. It does not require a custom scraper function for each table ID.

The parser preserves:

```text
data-stat column keys
captions and nearest headings
repeated table sections
original display strings
typed numeric values
percentage values as fractions
all links inside every cell
page-level link discovery
schema fingerprints
```

### 4. SQLite raw warehouse

The local backend is:

```text
raw/basketball_reference/catalog.sqlite
```

It contains:

```text
pages                resumable queue and page provenance
runs                 crawl configurations and outcomes
tables               discovered table registry and schema hashes
table_rows            typed values, display values, sections, and cell links
discovered_links      page-to-page provider graph
source_entities       stable provider entity index
```

The database is a raw-source warehouse, not the final canonical Sports Terminal schema.

### 5. Compressed page snapshots

Every completed page also produces a compressed normalized snapshot beneath:

```text
raw/basketball_reference/snapshots/
```

These snapshots preserve the complete parsed page independently of SQLite and include source hashes, fetch metadata, tables, rows, and links.

## Planning without network access

Preview one season:

```bash
python tools/crawl_basketball_reference.py \
  plan \
  --from-season 2025 \
  --to-season 2025 \
  --profile historical
```

Preview all NBA seasons currently represented by the site convention:

```bash
python tools/crawl_basketball_reference.py \
  plan \
  --from-season 1947 \
  --to-season 2026 \
  --profile historical
```

`plan` does not modify the queue and does not make network requests. Its time estimate covers deterministic seed pages only; linked team, player, game, and series pages can substantially increase total work.

## Queueing historical coverage

Queue one completed season first:

```bash
python tools/crawl_basketball_reference.py \
  seed \
  --from-season 2025 \
  --to-season 2025 \
  --profile historical
```

After validating that season, the full historical range can be queued without making network requests:

```bash
python tools/crawl_basketball_reference.py \
  seed \
  --from-season 1947 \
  --to-season 2026 \
  --profile historical
```

Queue insertion is idempotent. Running the same seed command again does not duplicate pages.

## Running bounded crawl batches

Review the current site rules before every live collection project. Then run a small first batch:

```bash
python tools/crawl_basketball_reference.py \
  crawl \
  --max-pages 10 \
  --max-depth 1 \
  --from-season 2025 \
  --to-season 2025 \
  --minimum-interval 4.0 \
  --acknowledge-site-rules
```

The queue is resumable. A later batch continues where the previous batch stopped:

```bash
python tools/crawl_basketball_reference.py \
  crawl \
  --max-pages 50 \
  --max-depth 2 \
  --from-season 2025 \
  --to-season 2025 \
  --minimum-interval 4.0 \
  --acknowledge-site-rules
```

The default behavior stops the entire batch on a robots failure, HTTP 403, or HTTP 429. Blocked pages are recorded separately from parser or missing-page failures.

## Inspection and recovery

Current warehouse status:

```bash
python tools/crawl_basketball_reference.py status
```

Upcoming queue records:

```bash
python tools/crawl_basketball_reference.py queue --status queued --limit 25
```

Failed or blocked records:

```bash
python tools/crawl_basketball_reference.py queue --status failed --limit 25
python tools/crawl_basketball_reference.py queue --status blocked --limit 25
```

Season and table coverage:

```bash
python tools/crawl_basketball_reference.py coverage
```

Table IDs whose schemas changed across pages or seasons:

```bash
python tools/crawl_basketball_reference.py schema-drift
```

Return ordinary failed pages to the queue:

```bash
python tools/crawl_basketball_reference.py reset-failed
```

Blocked pages are not reset unless explicitly requested after site rules have been reconfirmed:

```bash
python tools/crawl_basketball_reference.py reset-failed --include-blocked
```

## Exporting the raw backend

SQLite remains the primary raw backend. For external inspection or downstream batch processing, export its tables to JSON Lines:

```bash
python tools/crawl_basketball_reference.py \
  export \
  --output raw/basketball_reference/catalog_export
```

The export includes pages, tables, rows, links, provider entities, and crawl runs.

## Recommended rollout

The safest order is:

```text
1. One completed season, league pages only
2. That season's team-season pages
3. Player pages discovered from those tables
4. Box scores and box-score detail pages
5. Playoff series, awards, draft, coaches, and executives
6. A small multi-season range
7. Full historical queue and long-running bounded batches
```

This allows table IDs and schemas to be reviewed before millions of values are normalized.

## Boundary between raw and canonical data

The crawler deliberately does not write directly into Flutter assets. Historical source collection and product import remain separate:

```text
Fetch and cache HTML
Parse all tables and links
Store raw rows and provider identities
Measure coverage and schema drift
Build source-to-terminal identity mappings
Prepare dataset-specific candidates
Hold unmatched or ambiguous rows
Validate candidates
Apply to canonical assets
```

This separation prevents one malformed page, renamed table, or ambiguous player from corrupting the Sports Terminal product database.

## Scale expectations

A full historical crawl is not one request per season. League pages reveal team seasons, players, games, playoff series, coaches, and other linked pages. The final graph can contain many thousands of pages and millions of table values.

The system is therefore intentionally:

```text
Single-worker
Rate-limited
Cached
Idempotent
Resumable
Depth-bounded
Page-budgeted
Schema-aware
Failure-aware
```

The correct goal is a durable incremental collector, not a fast one-time scrape.
