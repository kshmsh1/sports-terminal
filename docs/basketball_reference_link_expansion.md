# Basketball Reference Stored-Link Expansion

Completed seed pages retain every recognized Basketball Reference link in the raw catalog. A depth-zero pilot intentionally stores those links without adding them to the fetch queue.

Use `promote-links` to move selected stored targets into the queue without requesting the completed source pages again.

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

## Queue team-season pages

```bash
python tools/crawl_basketball_reference.py \
  promote-links \
  --families team_season \
  --from-season 2025 \
  --to-season 2025 \
  --source-depth 0
```

Promotion is idempotent. Existing pages are not duplicated.

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

Afterward, inspect `status`, `coverage`, `schema-review`, failed pages, and blocked pages before promoting player or box-score links.
