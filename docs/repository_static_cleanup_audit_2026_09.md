# Repository Static-Data and Cleanup Audit — September 2026

## Scope

This audit was intentionally conservative. The instruction is to remove files only when their obsolescence is clear; ambiguous files remain in the repository.

## Confirmed regression repaired

The current Advanced Stats page had been reduced to six manually hard-coded groups even though the canonical metric catalog still contains the broader source-aware workstation taxonomy. The customer page is now driven by that catalog again, restoring the intended families including Defensive / Hustle, Playmaking / Possession, Rebounding, Efficiency, Impact, Aggregate Metrics, Movement, Clutch, Shot Profile, Play Type, Gravity / Creation, Physical Profile, Fouls / Discipline and Availability, plus the existing Overview, Shooting & Efficiency and Rate Adjusted views.

Source-gated fields remain unavailable when the static corpus does not contain them. The UI must not manufacture values.

## Runtime network/data audit

Confirmed mutable runtime network paths found in the customer application:
- NBA live scoreboard and live box-score polling;
- embedded X/Twitter timelines;
- generic product REST client;
- generic launch/backend sync transport.

Changes in this pass:
- NBA live network methods are disabled;
- Schedule is now a static snapshot surface;
- the media feed is now a static source directory with no social embed;
- backend sync transport is disabled;
- the legacy product REST client is retained only as a source-compatible disabled facade;
- the standard launcher no longer has a live-refresh option and no longer materializes the schedule from a remote endpoint.

The website still reads its own static JSON files from the application host. On web, that means the browser can issue same-origin file requests for bundled/static application assets. These are file-delivery operations, not third-party/live sports APIs.

## Build-time collection tools

Historical collectors, importers and normalization scripts are retained unless clearly obsolete. They are not part of the customer-facing runtime. Retaining ingestion tooling is important because immutable static releases still need a reproducible way to be built and audited.

Any future collection job should run explicitly outside the customer application, write an immutable reviewed snapshot, and never become a runtime dependency.

## Old/legacy file review

The repository contains files whose names suggest prior generations, including examples such as:
- entity_profile_screens_legacy.dart
- website_nba_entity_pages_legacy.dart
- multiple historical Trade Machine and versioned screen implementations
- old planning and readiness documents

They are **not deleted in this pass** because connector-level inspection cannot prove every import/reference path and the instruction is to retain files when uncertain.

Recommended deletion gate:
1. produce a full reference graph from a local checkout;
2. run flutter analyze and all tests;
3. prove the candidate is unreachable from application and test imports;
4. delete in a dedicated cleanup commit;
5. rerun all quality gates.

## Policy going forward

- Customer-facing product data is static/snapshot-based.
- Missing data is explicit, not silently fetched.
- Third-party remote feeds are not runtime dependencies.
- A source collector may exist only as an offline build tool.
- Legacy code is removed only after reference and test proof.
