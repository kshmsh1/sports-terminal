# Sports Terminal Production Runbook

This runbook describes the production contract for the NBA-first Sports Terminal application. It intentionally does not select or provision a paid cloud provider. Infrastructure procurement remains a separate operator decision.

## Deployment invariants

Production must set `SPORTS_TERMINAL_ENV=production`, use PostgreSQL through `SPORTS_TERMINAL_DATABASE_URL`, provide explicit CORS origins and allowed hosts, enable first-party authentication and shared rate limits, and supply independent high-entropy secrets for sessions, MFA encryption, certified-release signing, backup-manifest signing, and any configured SSO client-secret encryption. `SPORTS_TERMINAL_BILLING_MODE` remains `disabled` until a payment provider is deliberately configured.

The application fails closed if production configuration is unsafe. It also refuses to serve against a schema older than the latest checked-in migration. Production does not silently fall back to SQLite.

## Database bootstrap and promotion

For local PostgreSQL verification, use the repository's `backend/docker-compose.postgres.yml` `local-postgres` profile and `backend/scripts/local_postgres_smoke.py`. It binds only to loopback and does not provision a hosted database.

For a target production database:

1. Take and verify a database backup before schema promotion when upgrading an existing database.
2. Run `PYTHONPATH=. python scripts/migrate.py` from `backend/` against the target PostgreSQL database. On a brand-new database, the migration command first creates the legacy core schema that numbered migrations extend, then applies all numbered migrations.
3. Confirm the reported schema version equals the latest migration version.
4. Start the application with `SPORTS_TERMINAL_AUTO_MIGRATE=false`.
5. Check `/v2/operations/production-readiness` and `/v2/operations/database` from an authenticated operator context.

`SPORTS_TERMINAL_RUN_MIGRATIONS_ON_START=true` is an explicit operator escape hatch for controlled environments; it is not the default production deployment path. Authentication requests never run the versioned migration runner.

## Environment and certified-release promotion

A dataset release moves through candidate → certified → active. Release manifests are canonical JSON, SHA-256 hashed, and HMAC signed. A release version cannot be reused with different manifest content. Activation records the prior release and the database schema version so rollback history is explicit.

Application/environment promotion follows development → staging → production. Direct development-to-production promotion is rejected. The source environment must have a current schema, healthy status, and a certified/active release. Promotion and health transitions are written to the tamper-evident platform audit trail.

Rollback means activating a previously certified release; never mutate an old certified manifest in place.

## Authentication, recovery, and account security

Production requires a session pepper and MFA encryption key. TOTP secrets are authenticated-encrypted at rest. Recovery codes are returned once and stored only as purpose-separated hashes. A user with a verified MFA factor does not receive a bearer session after password-only authentication; a short-lived MFA challenge must complete first.

Email-verification and password-reset tokens are purpose-bound, short-lived, single-use, and stored only as peppered hashes. Request endpoints use anti-enumeration responses. Security mail goes through the provider-neutral HTTPS gateway configured by `SPORTS_TERMINAL_EMAIL_*`; console mail is forbidden in production, and raw addresses/tokens are not written to the delivery ledger.

A successful password reset revokes existing sessions. Operators should investigate `auth_security_events` for unexpected session revocation, MFA enrollment, or account-security activity without storing raw client IP or user-agent strings there.

## Organization security and SSO

Organization policy can require MFA or SSO, constrain maximum session lifetime, and restrict allowed email domains. OIDC uses the authorization-code flow with PKCE S256. Login state and nonce are purpose-separated and single-use; the PKCE verifier and client secret are authenticated-encrypted at rest.

The callback exchanges the authorization code at the configured HTTPS token endpoint, verifies the signed ID token using the configured HTTPS JWKS endpoint, restricts accepted signing algorithms, checks issuer, audience, expiry, issued-at time, nonce and verified-email state, and enforces connection and organization email-domain policy. JWKS data is cached briefly and refreshed for key rotation.

Sports Terminal does not silently provision accounts from an IdP. A verified provider identity must map to an existing active Sports Terminal account with the same verified email and an active membership in the target organization. Provider subject links are durable and collision-protected. Successful sessions are marked `sso` or `sso_mfa`; an organization requiring MFA only accepts an SSO login when the IdP's `amr` claim supplies recognized MFA evidence.

Set `SPORTS_TERMINAL_PUBLIC_API_ORIGIN` to the externally reachable HTTPS API origin and register the resulting `/v2/auth/sso/{organization_id}/callback` URI with the chosen IdP. Repository code does not purchase or create an IdP tenant.

## Billing and entitlements

Entitlements are provider-neutral. `SPORTS_TERMINAL_BILLING_MODE=disabled` is the safe default and causes webhook ingress to fail closed. Enabling test/live billing requires an explicit webhook secret. Webhook event IDs are idempotent and cannot be replayed with changed payload contents. No billing provider is provisioned by repository code.

## Rate limiting and proxy trust

Production defaults to the database-backed rate limiter so multiple API workers share one quota. A limiter-backend failure returns 503 instead of removing protection. `X-Forwarded-For` is ignored unless `SPORTS_TERMINAL_TRUST_PROXY_HEADERS=true`; only enable that setting behind a trusted reverse proxy that replaces untrusted forwarding headers.

## Backups, object storage, and restore drills

Production readiness requires the provider-neutral HTTPS object-store gateway; local filesystem object storage is a development-only default. The application can execute SQLite backups directly and PostgreSQL backups through `pg_dump`; the production image includes PostgreSQL client tools. Stored backup bytes are SHA-256 bound to signed manifests immediately after upload.

Restore verification re-fetches the stored object, verifies the object digest and signed manifest, and runs SQLite integrity checks for local restore drills. PostgreSQL restore uses `pg_restore` and is blocked unless both the caller explicitly opts into destructive restore and `SPORTS_TERMINAL_ALLOW_DATABASE_RESTORE=true`. A restore is never marked successful before integrity verification completes.

## Observability, health, and incidents

Every request receives an `X-Request-ID`. API logs are structured JSON and include request duration, path, method, status, user ID when authenticated, and timestamp. Security responses include restrictive browser headers. Platform audit events form a hash chain. A failed audit-chain verification is an incident and must not be repaired by rewriting history.

`/v2/operations/metrics` exposes vendor-neutral JSON metrics and `/v2/operations/metrics/prometheus` exposes Prometheus-compatible text. `/v2/operations/alerts` evaluates health failure, stale/missing backups, security-email failures, billing-webhook failures, and missing active releases without requiring an external monitoring vendor.

For an incident: preserve logs and audit evidence, stop unsafe promotion/automation, rotate compromised secrets, revoke affected sessions, activate the last known-good certified data release when relevant, restore from a verified backup only when needed, and document the recovery action in the platform audit trail.

## Local validation and review session

GitHub Actions are not required to review or validate the application. From the repository root, `./scripts/validate_local.sh` runs the deterministic backend/production contracts and recursive platform audits locally, then runs Flutter dependency resolution, analysis, tests and a release web build when Flutter is installed. `./scripts/validate_local.sh --backend-only` skips Flutter.

`./scripts/open_terminal.sh` starts a zero-cost local development session using SQLite, the checked-in NBA data/assets and a loopback backend. It opens the Flutter web application at `http://127.0.0.1:8080` and the API at `http://127.0.0.1:8000`. `./scripts/open_terminal.sh --postgres` instead starts the repository's loopback-only local PostgreSQL container and runs the PostgreSQL smoke check before launching.

Neither local command dispatches GitHub Actions or provisions a hosted service.

## GitHub / CI cost safety

The repository is public, so normal validation uses standard GitHub-hosted runners with automatic `push` and `pull_request` triggers plus optional `workflow_dispatch`. CI remains read-only (`contents: read`) and must not deploy infrastructure, publish packages/releases, invoke paid hosting providers, or use larger/self-hosted paid runner capacity without an explicit operator decision. Local validation remains independent of GitHub Actions.
