# Repository Cleanup — July 2026

This cleanup was generated from a full-history repository audit and merged only after Flutter analysis, the complete test suite, and a release web build passed.

## Removed

- 41 unreachable Dart libraries from superseded screens, mock data, preliminary models, and pre-data scaffolding.
- One duplicate backend launcher and three unreferenced operational stubs.
- One duplicate Boston roster source and one unused injury placeholder.
- The unused `cupertino_icons` dependency and six unused declarations.

## Normalized

- Active Stats Center, Trade Machine, query-engine, and user-shell implementations now live in their canonical filenames.
- Manual roster-ingestion source files were moved out of Flutter's runtime asset tree into `raw/manual_sources/rosters/`.
- Repository-wide unused-element and unused-local-variable suppressions were removed so future dead code is surfaced automatically.

## Preserved

All active application routes, test-only validators, data-quality services, ingestion tools, platform targets, documentation, and Git history were retained.
