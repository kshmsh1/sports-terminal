# Connected Data and Finance Studio Phase

## Purpose

This phase connects previously separate product surfaces through one persistent, structured sports-object contract. NBA tables and modeled financial scenarios can now be packaged once and routed into Python Lab, Workspace and other product targets without screen-specific copy logic.

## Shared package contract

`RoutePayload` remains backward-compatible with the original string-based routing contract while adding:

- schema version and creation timestamp;
- typed column definitions;
- JSON-compatible row data;
- package metadata;
- JSON serialization and safe decoding;
- persistent active package and package history.

The application hydrates the active package and the last 25 packages at startup. Older payloads without structured rows remain readable.

## Universal NBA Object Router

The Object Router packages live rows from the generated NBA warehouse:

- player season totals;
- team performance records;
- game results;
- team game logs;
- player game logs.

Users can search, select explicit rows or use the first 100 filtered rows, choose a target route, preview the package, copy TSV, publish to Python Lab, or import directly into Workspace.

Every package preserves the source dataset, warehouse generation timestamp, validation state, filter summary, selected rows and row/column counts.

## Workspace interoperability

`WorkspaceRouteImportService` converts a structured package into the existing 24-column by 60-row persisted workbook grid:

- row 1 records the package label and source;
- row 2 contains typed column labels;
- rows 3–59 contain routed data;
- import metadata records source, object identity, route and truncation counts.

The importer explicitly reports omitted rows or columns when a package exceeds the current workbook grid. It reuses the existing workbook storage instead of creating a parallel spreadsheet implementation.

## Data and Code Studio

The former notebook-only Python Lab now contains four connected modules:

1. Notebook
2. Object Router
3. Cap Lab
4. Route History

The notebook can bind the active package, generate package-specific starter Python, run safe Dart-side numeric summaries, preview the dataframe, copy TSV and export the package to Workspace. Arbitrary Python execution remains disabled until Pyodide or a sandboxed backend kernel is integrated.

## Official NBA financial warehouse

The versioned cap environment asset includes official league thresholds for 2024–25, 2025–26 and 2026–27:

- salary cap;
- tax level;
- minimum team salary;
- first apron;
- second apron;
- non-taxpayer mid-level exception;
- taxpayer mid-level exception;
- room mid-level exception.

The Cap Lab combines those sourced league thresholds with a clearly labeled user-entered modeled team salary. It does not invent or estimate a live team payroll. The scenario can be routed into Workspace or Python Lab through the same shared package contract.

## Accuracy boundary

The Cap Lab is a threshold and scenario-planning layer, not a complete CBA legality engine. Transaction-specific salary matching, aggregation, hard-cap triggers, sign-and-trades, base-year compensation, poison-pill treatment, cash limits, exception expiry and second-apron restrictions still require dedicated rule modules and sourced team/player contract ledgers.

## Validation plan

The phase adds deterministic tests for:

- schema-v2 payload serialization and legacy compatibility;
- object packaging, type inference, TSV and generated Python;
- workbook cell mapping and truncation reporting;
- persistent active package and history hydration;
- cap-tier classification and room calculations.

The dedicated branch validation completed `flutter analyze`, the complete test suite and `flutter build web --release` before the validated repair commit was pushed. The normal Flutter Quality and Pre-Data workflows are required to pass again against the final branch head before merge.
