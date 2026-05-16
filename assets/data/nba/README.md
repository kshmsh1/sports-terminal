# NBA Data Assets

This folder is reserved for normalized, app-ready NBA data files.

The current build is still mostly schema-first. Stable reference data lives in Dart files for speed while the product foundation is being designed. As the ingestion layer matures, normalized JSON snapshots should be stored here by domain.

Planned structure:

```text
assets/data/nba/
  teams/
  seasons/
  players/
  stats/
  games/
  rosters/
  awards/
  draft/
  transactions/
  financial/
  g_league/
  metadata/
```

Rules:

1. Do not store fake production data here.
2. Every dataset should have source metadata.
3. Missing values should remain null, not zero.
4. Raw source exports should not be mixed with normalized app-ready files.
5. Data rights and usage notes should be tracked before a dataset is displayed as real sports intelligence.
