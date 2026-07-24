# Sports Terminal Backend

The repository now has two compatible FastAPI layers:

- `app.main` preserves the original local prototype API.
- `app.main_launch` is the default development entrypoint and adds launch-oriented organization, transaction workflow, saved-object, data-release, and readiness contracts on top of the original API.

The service still uses local SQLite by default so the complete product contract can run without external infrastructure. The launch API is deliberately written so that the database can later move behind managed Postgres without changing the Flutter transaction-case model.

## Run locally

From the repository root:

```bash
bash scripts/dev_backend.sh
```

Or from `backend/`:

```bash
bash scripts/dev.sh
```

Both commands run:

```text
uvicorn app.main_launch:app --reload --port 8000
```

Useful endpoints:

```text
http://127.0.0.1:8000/health
http://127.0.0.1:8000/docs
http://127.0.0.1:8000/launch/readiness
http://127.0.0.1:8000/v2/launch/config
http://127.0.0.1:8000/v2/launch/readiness
```

## Launch API coverage

The `/v2` API adds:

- organizations and membership roles;
- personal and organization transaction-case snapshots;
- organization activity streams;
- per-user notifications;
- organization member/reviewer records;
- saved structured sports objects;
- NBA data-release registration and certification;
- launch checks and a consolidated readiness response.

The current Flutter transaction repositories are remote-first. When this API is reachable they synchronize through the shared SQLite database across browser sessions. When it is unavailable the product continues through its existing local fallback.

## Backend contract test

```bash
cd backend
python scripts/launch_contract_test.py
```

The contract test uses a temporary database and verifies organizations, personal/shared cases, activities, notifications, member records, data releases, and launch readiness.

## Complete 2025–26 overnight build

From the repository root:

```bash
bash scripts/overnight_launch_build.sh
```

The command:

1. builds the season-end-year 2026 warehouse from the local raw catalog;
2. exports the compact terminal seed;
3. exports complete player game logs and launch supplements;
4. performs launch-specific reconciliation checks;
5. activates `nba_2026` assets only after validation passes;
6. compiles and smoke-tests the launch backend;
7. runs Flutter analysis, tests, and the release web build;
8. writes timestamped logs and a machine-readable launch report under `data/launch_reports/`.

The raw catalog must already exist at `raw/basketball_reference/catalog.sqlite`, or a known preparation command can be supplied through:

```bash
bash scripts/overnight_launch_build.sh \
  --prepare-raw-command '<your existing raw-catalog command>'
```

The pipeline never activates a failed dataset.

## Environment variables

```bash
export SPORTS_TERMINAL_DB_PATH="/absolute/path/to/sports_terminal.db"
export SPORTS_TERMINAL_CORS_ORIGINS="http://localhost:5000,http://localhost:8000"
export SPORTS_TERMINAL_AUTH_PROVIDER="external-provider-name"
export DATABASE_URL="postgresql://..."
export SPORTS_TERMINAL_PAYMENT_PROVIDER="external-provider-name"
export SPORTS_TERMINAL_DATA_RIGHTS_APPROVED="true"
export SPORTS_TERMINAL_PUBLIC_COMMUNITY="false"
```

The final five variables are launch-readiness signals. The repository does not fabricate external provider integration or legal approval.

## Production boundaries

The launch contracts are materially stronger than the previous local-only workflow, but public production still requires external work that cannot be completed inside this repository alone:

- managed Postgres or an equivalent hosted database;
- real authentication and secure sessions;
- provider-backed billing and entitlement webhooks;
- approved data rights and trademark/media policies;
- deployment, secrets, monitoring, rate limits, backups, and restore drills;
- moderation and safety operations before public community or messaging.

Community and messaging should remain disabled until moderation, report queues, block/mute controls, and operator audit logs are production-ready.
