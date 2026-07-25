# Sports Terminal Platform Completion Phase

This phase completes the largest internally buildable product gaps that remained after the launch-transformation phase. It does not fabricate commercial data, vendor credentials, legal approval, production staff or customer operations.

## Default customer products

The connected terminal shell now promotes these products as the default experience:

- Contracts & Assets
- Trade Machine and Front Office
- multi-sheet Workspace
- isolated Python Lab
- moderated Community
- protected Messages
- organization Trust & Safety

The former static Community, Messages, notebook-preview and single-sheet Workspace screens are no longer the primary navigation path.

## Front-office registry

The launch backend now maintains canonical versioned records for:

- player contracts and contract years;
- guarantees, options, likely and unlikely incentives, dead money and cap-charge overrides;
- no-trade clauses, trade bonuses and rights metadata;
- team salary positions, cap holds, dead money, hard caps and exception balances;
- draft-pick ownership, protections, swaps, conveyance chains, encumbrances and modeled Stepien availability;
- completed or modeled transaction-ledger entries and immutable ledger events.

Every record has a permanent ID, object type, record status, source status, validation report, version and provenance. A record ID cannot later become a different object type. Verified records require a source label and either a source URL or source document ID.

Team reconciliation compares registered contract-year cap charges with the latest team financial position, counts every transaction in which the team appears and surfaces unverified or missing records.

## Trust, safety and messaging

The platform now provides:

- authenticated community posts and comments;
- shared reactions;
- neutral submission checks;
- report cases;
- user blocks and mutes;
- moderator approval, hide, remove, restore, warn, suspend, ban and close actions;
- user sanctions;
- immutable moderation audit events;
- explicit conversation membership;
- block-enforced message delivery;
- message reporting.

These capabilities make a controlled beta possible. Public community activation still requires staffed moderation, documented escalation and appeals, production abuse monitoring, legal policy review and incident ownership.

## Workspace

The connected Workspace now supports:

- multiple sheets;
- sheet creation, rename, duplication and deletion;
- dynamic occupied dimensions;
- row and column insertion and deletion;
- formulas including SUM, AVERAGE, MIN, MAX, COUNT, direct references and basic binary math;
- cycle detection;
- CSV and TSV paste;
- raw and evaluated CSV export;
- direct route-package import into a new sheet;
- undo and redo;
- optimistic version checks;
- server version history;
- restore-as-new-version;
- viewer, editor and owner permissions for organization workbooks;
- offline cache and migration from the earlier single-sheet keys.

Legacy route importers now create a one-time pending import envelope. Workspace consumes it as a new sheet and publishes a new version without invoking the obsolete single-sheet remote writer.

## Python runtime

Python Lab now submits routed data to a bounded backend subprocess rather than simulating code execution in Dart.

The runtime:

- rejects imports, attributes/reflection, files, networking and child processes;
- validates the syntax tree before execution;
- runs Python in isolated mode and a temporary directory;
- applies CPU, address-space, file-size, file-descriptor and process limits on supported platforms;
- enforces a wall-clock timeout;
- limits code, rows, columns, input and output;
- exposes approved analytical helpers;
- requires a JSON-compatible value assigned to `result`;
- returns stdout, result, row count, column count, duration and warnings;
- retains a Dart-side summary fallback when the backend is unavailable.

Production should additionally isolate runtime workers at the container or microVM level and apply per-account quotas and abuse monitoring.

## Front-office catalog ingestion

The repository includes:

- `schemas/front_office_catalog.schema.json`
- `docs/examples/front_office_catalog.example.json`
- `tools/front_office_catalog.py`

The example is intentionally modeled and must not be treated as real contract or pick data.

Validate a catalog:

```bash
.venv-platform-completion/bin/python tools/front_office_catalog.py validate \
  raw/front_office/catalog.json \
  --require-verified \
  --minimum-contracts 400 \
  --minimum-team-positions 30 \
  --minimum-draft-assets 1 \
  --report data/completion_reports/front_office_validation.json
```

Register a validated catalog against a running launch backend:

```bash
SPORTS_TERMINAL_TOKEN='<session token>' \
.venv-platform-completion/bin/python tools/front_office_catalog.py register \
  raw/front_office/catalog.json \
  --backend-url http://127.0.0.1:8000 \
  --actor-user-id '<user id>' \
  --require-verified \
  --minimum-contracts 400 \
  --minimum-team-positions 30 \
  --minimum-draft-assets 1 \
  --report data/completion_reports/front_office_registration.json
```

The command validates exact production models, source requirements, duplicate IDs, ledger references, team coverage and minimum population before registration.

## Overnight completion command

Run the full internally controlled launch check:

```bash
bash scripts/overnight_platform_completion.sh
```

With a front-office catalog:

```bash
bash scripts/overnight_platform_completion.sh \
  --catalog raw/front_office/catalog.json \
  --require-verified
```

To validate and register against a running backend:

```bash
SPORTS_TERMINAL_TOKEN='<session token>' \
bash scripts/overnight_platform_completion.sh \
  --catalog raw/front_office/catalog.json \
  --require-verified \
  --register-catalog \
  --actor-user-id '<user id>'
```

The pipeline runs:

1. backend dependency installation;
2. Python compilation;
3. launch backend contract;
4. completion-platform contract;
5. Workspace conflict/restore/permission contract;
6. real Uvicorn HTTP contract;
7. optional front-office catalog validation and registration;
8. Flutter dependencies;
9. Pre-Data Gate;
10. strict Flutter analysis;
11. complete Flutter tests;
12. release web build;
13. the 2025–26 NBA release pipeline when the raw NBA catalog exists;
14. Docker Compose validation and optional backend image build.

Reports and logs are written under `data/completion_reports/<timestamp>/`.

## Machine-readable readiness

The backend exposes:

- `GET /v2/completion/status`
- `GET /v2/completion/catalog-readiness`

These endpoints separate:

- internal implementation completeness;
- authoritative source population;
- external vendor, rights, staffing and deployment blockers.

## Remaining external and authoritative-data work

The repository still does not provide:

- licensed 2025–26 contract and draft-ownership data;
- commercial data-rights approval;
- managed production database hosting;
- payment credentials and tax/invoice configuration;
- production email verification, password recovery or MFA delivery;
- production DNS, TLS and secret management;
- production monitoring and incident operations;
- staffed moderation, appeals and customer support;
- final privacy, terms and legal review.

Those are deployment, commercial, legal or operational dependencies rather than missing internal product architecture.
