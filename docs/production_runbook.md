# Sports Terminal Production Runbook

This runbook describes the production contract for the NBA-first Sports Terminal application. It intentionally does not select or provision a paid cloud provider. Infrastructure procurement remains a separate operator decision.

## Deployment invariants

Production must set `SPORTS_TERMINAL_ENV=production`, use PostgreSQL through `SPORTS_TERMINAL_DATABASE_URL`, provide explicit CORS origins and allowed hosts, enable first-party authentication and shared rate limits, and supply independent high-entropy secrets for sessions, MFA encryption, certified-release signing, and backup-manifest signing. `SPORTS_TERMINAL_BILLING_MODE` remains `disabled` until a payment provider is deliberately configured.

The application fails closed if production configuration is unsafe. It also refuses to serve against a schema older than the latest checked-in migration. Production does not silently fall back to SQLite.

## Database promotion

1. Take and verify a database backup before schema promotion.
2. Run `PYTHONPATH=. python scripts/migrate.py` from `backend/` against the target PostgreSQL database.
3. Confirm the reported schema version equals the latest migration version.
4. Start the application with `SPORTS_TERMINAL_AUTO_MIGRATE=false`.
5. Check `/v2/operations/production-readiness` and `/v2/operations/database` from an authenticated operator context.

`SPORTS_TERMINAL_RUN_MIGRATIONS_ON_START=true` is an explicit operator escape hatch for controlled environments; it is not the default production deployment path.

## Certified NBA release promotion

A dataset release moves through candidate → certified → active. Release manifests are canonical JSON, SHA-256 hashed, and HMAC signed. A release version cannot be reused with different manifest content. Activation records the prior release and the database schema version so rollback history is explicit.

Promote a release to staging first. Verify ingestion/source coverage, historical/current isolation, application contracts, and analyst workflows before production activation. Rollback means activating a previously certified release; never mutate an old certified manifest in place.

## Authentication and account security

Production requires a session pepper and MFA encryption key. TOTP secrets are authenticated-encrypted at rest. Recovery codes are returned once and stored only as purpose-separated hashes. Operators should investigate `auth_security_events` for unexpected session revocation, MFA enrollment, or account-security activity without storing raw client IP or user-agent strings there.

## Billing and entitlements

Entitlements are provider-neutral. `SPORTS_TERMINAL_BILLING_MODE=disabled` is the safe default and causes webhook ingress to fail closed. Enabling test/live billing requires an explicit webhook secret. Webhook event IDs are idempotent and cannot be replayed with changed payload contents.

## Rate limiting and proxy trust

Production defaults to the database-backed rate limiter so multiple API workers share one quota. A limiter-backend failure returns 503 instead of removing protection. `X-Forwarded-For` is ignored unless `SPORTS_TERMINAL_TRUST_PROXY_HEADERS=true`; only enable that setting behind a trusted reverse proxy that replaces untrusted forwarding headers.

## Backups and restore verification

The application records signed backup manifests containing database backend, schema version, release identity, object key, byte size, and SHA-256 digest. Actual database dump/storage execution belongs to the infrastructure layer. A restore should not be declared successful until the backup bytes match the recorded digest, the manifest signature verifies, migrations/schema are compatible, and smoke checks pass against the restored environment.

## Observability and incidents

Every request receives an `X-Request-ID`. API logs are structured JSON and include request duration, path, method, status, user ID when authenticated, and timestamp. Security responses include restrictive browser headers. Platform audit events form a hash chain; a failed audit-chain verification is an incident and must not be repaired by rewriting history.

For an incident: preserve logs and audit evidence, stop unsafe promotion/automation, rotate compromised secrets, revoke affected sessions, activate the last known-good certified data release when relevant, restore from a verified backup only when needed, and document the recovery action in the platform audit trail.

## GitHub / CI cost safety

Repository workflows are manual-only. A push or pull-request update must not automatically start GitHub-hosted Actions. Run CI only when an operator deliberately chooses to dispatch it and has independently confirmed account-level billing/budget settings. The repository does not enable paid runners or any paid external deployment service.
