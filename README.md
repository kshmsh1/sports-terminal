# Sports Terminal

Sports Terminal is an NBA-first Flutter web terminal for professional research, structured analysis, cap and transaction modeling, personal work management, and organization review workflows.

The current product has three distinct experiences:

- **Individual Terminal** for personal research, workspaces, transaction cases, collaboration, and saved analysis.
- **Organization Terminal** for shared cases, assignments, approvals, members, activity, and organization operations.
- **Platform Admin Terminal** for internal product, data, and platform operations.

## Product foundation

The connected customer products include:

- NBA Stats Center;
- player, team, and game Hub;
- structured NBA Object Router;
- Workspace;
- Data & Code Studio;
- official Cap Lab;
- Trade Machine;
- Front Office contract, cap, draft, and transaction ledgers;
- personal and organization transaction command centers;
- comments, assignments, activity, notifications, and approval workflows;
- role-aware Home metrics and customer launch status.

The shared `RoutePayload` contract lets NBA datasets and modeled scenarios move between product surfaces without screen-specific copy logic.

## Data policy

Sports Terminal does not add fake production data to make screens appear complete.

- Connected data may be shown.
- Source-pending data remains blank or visibly modeled.
- Missing values remain null rather than invented zeroes.
- Every release preserves source state, validation, generation time, and blockers.
- Commercial data rights and attribution are external launch requirements and are never represented as complete without approval.

## Single-season launch profile

The first customer launch is scoped to the complete **2025–26 NBA season**.

The Flutter client is season-aware:

- candidate release: `assets/data/nba/terminal_seed/nba_2026`;
- validated development fallback: `assets/data/nba/terminal_seed/nba_2025`;
- activation config: `assets/data/nba/launch/season_config.json`.

The 2025–26 release is activated only after the warehouse, seed, complete player game logs, launch certification, backend smoke test, Flutter analysis, complete test suite, and release web build pass.

## Run the Flutter product

```bash
flutter pub get
flutter run -d chrome
```

## Run the launch backend

```bash
bash scripts/dev_backend.sh
```

The launch entrypoint extends the original FastAPI backend with:

- organizations and memberships;
- server-backed personal and shared transaction cases;
- activity and notifications;
- organization member records;
- saved structured sports objects;
- data-release certification;
- launch checks and readiness.

When the backend is reachable, the existing Flutter transaction repositories synchronize remotely across browser sessions. When it is unavailable, the product retains its local fallback.

## Build the complete 2025–26 launch release

```bash
bash scripts/overnight_launch_build.sh
```

The raw Basketball Reference catalog must already exist at:

```text
raw/basketball_reference/catalog.sqlite
```

A known local raw-catalog command can be supplied with:

```bash
bash scripts/overnight_launch_build.sh \
  --prepare-raw-command '<your existing raw-catalog command>'
```

The pipeline never activates a failed dataset. Timestamped logs and the machine-readable final report are written under `data/launch_reports/`.

## External launch requirements

The repository cannot fabricate or complete external commercial steps. Public launch still requires:

- a real authentication provider and secure sessions;
- managed Postgres or equivalent hosted storage;
- payment-provider credentials and billing webhooks;
- approved data-source rights and attribution policy;
- deployment, secrets, monitoring, backups, rate limits, and incident operations;
- moderation operations before public Community or Messages are enabled.

The `/v2/launch/readiness` endpoint reports these separately from code and data work so the application never labels itself launch-ready while an external blocker remains.
