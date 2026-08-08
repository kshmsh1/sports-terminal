# NBA API metric population architecture

Sports Terminal should use `nba_api` as a broad NBA.com schema and data source, but it should not treat every registered terminal metric as NBA-native.

## Strategy

The first stage is schema discovery. `tools/audit_nba_api_metric_coverage.py` reads the endpoint metadata distributed with the installed `nba_api` package, inventories every declared endpoint/result set/column, and matches those fields against the Sports Terminal metric registry. This stage makes no calls to `stats.nba.com`, so it is fast, deterministic, and safe to run repeatedly.

Run it from one Terminal window:

```bash
bash scripts/audit_nba_api_metric_coverage.sh --check
```

The audit writes:

- `artifacts/nba_api_metric_coverage.json` for machine-readable endpoint-to-metric mapping.
- `artifacts/nba_api_metric_coverage.md` for human/AI review.

The second stage should use that report to build targeted collectors for the highest-yield endpoint families rather than blindly calling every endpoint for every player and season. Candidate families include player box score, hustle, defensive tracking, passing, rebounding, movement/touches, clutch, shot location/type, Synergy play types, on/off, estimated metrics, physical measurements, gravity, and dunk tracking.

## AI-assisted mapping

The coverage report is designed to be reviewed by ChatGPT or another model. The model can inspect unmatched Sports Terminal metrics, identify likely NBA API synonyms, distinguish direct fields from derivable fields, and propose endpoint-specific transforms. Those mappings should then be encoded as deterministic source contracts rather than left as runtime model guesses.

This is a better use of AI than asking a model to manually ingest millions of raw API rows in a chat session. The backend scripts collect and normalize the data; AI helps reason across the complete schemas, map terminology, identify gaps, and design defensible derived metrics.

## Source truth rules

A Sports Terminal column may be populated from NBA API when there is a direct field or a transparent derivation from NBA-native fields. Source provenance should record endpoint, result set, original column, request parameters, season, season type, retrieval time, and package/API version.

Regular season and playoffs must be collected and stored separately. They should never be blended into a single default player-season row.

When the NBA API does not provide a metric, the product should keep displaying `—` until another authorized source or an explicitly versioned Sports Terminal model supplies it. Proprietary third-party metrics such as EPM, LEBRON, and DARKO must not be reverse-labeled from unrelated NBA fields. RAPM-family and other modeled measures require our own documented model pipeline or an authorized upstream source.

## Expected coverage

NBA API should be capable of materially increasing coverage for:

- traditional player and team box-score statistics;
- advanced rates and estimated metrics;
- hustle and defensive tracking;
- passing, potential assists, secondary assists, touches, drives, rebounding and movement;
- clutch splits;
- shot locations, shot types and several shooting-context splits;
- play-type data exposed by Synergy endpoints;
- on/off and lineup context;
- combine and physical-measurement data;
- newer gravity and dunk-tracking data where the endpoint is available.

It will not, by itself, solve every requested metric. Injury histories, suspensions, proprietary public models, custom gravity/decision-time concepts, video-derived defensive concepts, and Sports Terminal-original metrics need other sources or dedicated model pipelines.

## Next ingestion layer

After running the audit on the developer machine, use its JSON output to generate an explicit endpoint manifest. Each manifest entry should define request grain, supported seasons, season type, expected result set, selected raw columns, canonical metric keys, retry/rate-limit policy, and provenance fields. The resulting data belongs in the server-side NBA warehouse, not as giant Flutter assets.
