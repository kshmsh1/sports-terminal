# Sports Terminal

Sports Terminal is an NBA-first Flutter web terminal for professional sports research, structured analysis, historical intelligence, cap and transaction modeling, personal work management, and organization review workflows.

The repository now contains the connected NBA product graph plus its production-oriented control plane: Player, Team, Game, Event, Schedule, Season, Franchise, historical Player Career, Player Career Comparison, Workspace/Python/Compare/Source Audit routing, front-office workflows, authentication/MFA/OIDC, entitlements, signed releases, migrations, backups/restores, audit integrity, environment promotion, metrics and operational alerts.

## Open Sports Terminal locally

The fastest review path uses SQLite and the repository's checked-in NBA assets. It does **not** dispatch GitHub Actions or provision a hosted service.

```bash
bash scripts/open_terminal.sh
```

The launcher creates a local Python virtual environment when needed, installs backend dependencies, resolves Flutter packages, initializes the local database schema, starts the FastAPI backend, starts Flutter Web and opens the terminal in your browser.

- Terminal: `http://127.0.0.1:8080`
- API: `http://127.0.0.1:8000`
- Backend log: `.data/logs/backend.log`
- Flutter log: `.data/logs/flutter.log`

Stop the session with `Ctrl-C`.

To exercise the PostgreSQL compatibility path as part of the session, with Docker installed:

```bash
bash scripts/open_terminal.sh --postgres
```

This starts only the repository's loopback-bound Postgres 17 development container and tears the container down when the session ends. It does not create a hosted database.

## Validate locally without GitHub Actions

Run the complete local deterministic gate:

```bash
bash scripts/validate_local.sh
```

That runs the backend/production contracts, recursive NBA/production audits, Flutter analyzer, Flutter tests and a release web build. For backend-only validation:

```bash
bash scripts/validate_local.sh --backend-only
```

To add the loopback PostgreSQL smoke path:

```bash
bash scripts/validate_local.sh --postgres
```

Repository GitHub workflows remain manual-only (`workflow_dispatch`) so pushes and pull-request updates do not automatically consume Actions minutes.

## Product foundation

The connected customer products include the NBA Hub and Terminal, permanent Player/Team/Game/Season/Franchise objects, historical Player Careers and Career Comparison research, searchable play-by-play/event intelligence, schedules, trends and season analytics, Workspace, Data & Code Studio, Cap Lab, Trade Machine, front-office contract/cap/draft/transaction ledgers, personal and organization transaction command centers, comments/assignments/activity/notifications/approvals, saved structured sports objects, research/watch state, and organization/platform operations.

The shared `RoutePayload` contract lets canonical NBA objects, datasets and modeled scenarios move between Workspace, Python Lab, Compare and Source Audit without screen-specific copy logic.

## Data policy

Sports Terminal does not add fake production data to make screens appear complete.

- Connected/source-backed data may be shown.
- Source-pending data remains blank, unavailable, or explicitly modeled.
- Missing values remain null rather than invented zeroes.
- Historical multi-team Player seasons are not reconstructed into fake traded-team stints.
- Scheduled games do not affect performance standings/trends.
- Advanced derived analytics stay unavailable until their source/model boundary is defensible.
- Every release preserves source state, validation, generation time and blockers.
- Commercial data rights and attribution are external launch requirements and are never represented as complete without approval.

## NBA release profile

The Flutter client is season-aware and currently uses the checked-in NBA terminal seed/release system, with current candidate and validated fallback assets under `assets/data/nba/`. Missing production source population remains a data-coverage state rather than being filled with synthetic sports records.

## Production control plane

The backend includes:

- SQLite development plus PostgreSQL production compatibility and versioned migrations through schema `0006`;
- password authentication, email verification/recovery, encrypted TOTP MFA and recovery codes;
- full OIDC authorization-code + PKCE S256 login with JWKS signature verification, issuer/audience/time/nonce checks, verified-email/domain enforcement, existing-account membership linking, and `sso` / `sso_mfa` session assurance;
- organization MFA/SSO/session-lifetime security policy;
- provider-neutral Free/Pro/Organization/Enterprise entitlements and fail-closed billing ingress;
- immutable signed/certified release activation and rollback history;
- tamper-evident audit events;
- executable SQLite/PostgreSQL backups, signed manifests and verified restore drills;
- development → staging → production promotion contracts;
- shared database-backed rate limiting, production security headers, metrics, health and alerts;
- zero-automatic-spend GitHub workflow policy.

The final recursive code-completion audit is:

```bash
python tools/audit_production_platform_v3.py --check
```

It composes production v2, which composes production v1, which recursively composes the NBA v16 platform graph.

## External launch requirements

The codebase cannot manufacture business agreements or vendor accounts. A public commercial deployment still requires an operator to provide:

- approved authoritative NBA data access, commercial data rights and attribution terms;
- chosen hosted PostgreSQL/application infrastructure and secrets;
- a chosen security-email gateway;
- a chosen durable object-storage endpoint;
- an OIDC client registration at the organization's chosen identity provider when enterprise SSO is used;
- a monitoring/log delivery destination if external observability is desired;
- payment-provider credentials only if paid billing is deliberately enabled;
- operational moderation/support staffing where public community functionality requires it.

Those are intentionally separated from code completion and remain unprovisioned by repository code so no external service is purchased implicitly.
