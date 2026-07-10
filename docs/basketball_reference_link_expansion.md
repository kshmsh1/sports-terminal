# Basketball Reference Stored-Link Expansion

Completed pages retain every recognized Basketball Reference link in the raw catalog. Use `promote-links` to move selected stored targets into the queue without requesting the completed source pages again.

Promotion is deterministic and idempotent. Existing pages are not duplicated. Season bounds apply to the effective linked-page season. When a linked target lacks explicit season metadata, it inherits the season of the completed source page. Re-running promotion can therefore repair missing metadata on existing pages without refetching them.

## Review schema variation

```bash
python tools/crawl_basketball_reference.py schema-review
```

This separates schema changes within one page family from expected differences between regular-season and playoff pages. Anonymous table labels are treated as page-local ordinals rather than stable table identities.

## Preview team-season expansion

```bash
python tools/crawl_basketball_reference.py \
  promote-links \
  --families team_season \
  --from-season 2025 \
  --to-season 2025 \
  --source-depth 0 \
  --dry-run
```

The dry run makes no network requests and does not change the queue.

## Restrict promotion to a source family

Use `--source-families` when the same target family is linked from several kinds of completed pages. For example, playoff box scores can be isolated from regular-season schedule links:

```bash
python tools/crawl_basketball_reference.py \
  promote-links \
  --families boxscore \
  --source-families playoff \
  --from-season 2025 \
  --to-season 2025 \
  --source-depth 0 \
  --dry-run
```

Multiple source families may be supplied as a comma-separated value. Seasonless source pages, such as player profiles, can still promote linked season-specific detail pages when the detail link itself carries season metadata:

```bash
python tools/crawl_basketball_reference.py \
  promote-links \
  --families player_detail \
  --source-families player \
  --from-season 2025 \
  --to-season 2025 \
  --source-depth 1 \
  --dry-run
```

## Restrict promotion and crawling to a target path

Use `--target-path-prefix` when several routes share a page family. For example, promote play-by-play pages without also queueing shot charts or plus/minus pages:

```bash
python tools/crawl_basketball_reference.py \
  promote-links \
  --families boxscore_detail \
  --source-families boxscore \
  --target-path-prefix /boxscores/pbp/ \
  --from-season 2025 \
  --to-season 2025 \
  --source-depth 2 \
  --dry-run
```

Use the same prefix while crawling so only matching queued pages are processed and only matching links may be recursively queued:

```bash
python tools/crawl_basketball_reference.py \
  crawl \
  --max-pages 5 \
  --max-depth 3 \
  --families boxscore_detail \
  --target-path-prefix /boxscores/pbp/ \
  --from-season 2025 \
  --to-season 2025 \
  --minimum-interval 7 \
  --acknowledge-site-rules
```

The prefix must be a canonical path beginning with `/`. Other game-detail prefixes include `/boxscores/shot-chart/` and `/boxscores/plus-minus/`.

## Repair missing season metadata

Existing box-score pages originally promoted from team-season pages can inherit the correct season without being requeued or refetched:

```bash
python tools/crawl_basketball_reference.py \
  promote-links \
  --families boxscore \
  --source-families team_season \
  --from-season 2025 \
  --to-season 2025 \
  --source-depth 1
```

The output reports `metadataUpdateCount` separately from newly inserted pages.

## First linked-page pilot

```bash
python tools/crawl_basketball_reference.py \
  crawl \
  --max-pages 5 \
  --max-depth 1 \
  --from-season 2025 \
  --to-season 2025 \
  --minimum-interval 7 \
  --families team_season \
  --acknowledge-site-rules
```

Afterward, inspect `status`, `coverage`, `schema-review`, failed pages, and blocked pages before expanding the next page family.
