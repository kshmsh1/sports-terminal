from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "backend/app/runtime_config.py": (
        "class RuntimeConfig",
        "production requires a PostgreSQL DATABASE_URL",
        "SPORTS_TERMINAL_MFA_ENCRYPTION_KEY must contain at least 32 characters",
        "SPORTS_TERMINAL_BILLING_MODE must be disabled, test, or live",
        "production CORS origins must be explicit",
    ),
    "backend/app/database.py": (
        "class DatabaseConnection",
        "class CompatRow",
        "import psycopg",
        "ON CONFLICT DO NOTHING",
        "information_schema.tables",
        "information_schema.columns",
        "PRAGMA\\s+table_info",
    ),
    "backend/app/migrations.py": (
        "class Migration",
        "schema_migrations",
        "checksum changed after application",
        "def current_schema_version",
    ),
    "backend/migrations/0001_platform_metadata.sql": (
        "platform_metadata",
        "deployment_environments",
        "database_schema_version",
    ),
    "backend/migrations/0002_identity_security.sql": (
        "auth_email_verifications",
        "auth_password_resets",
        "auth_mfa_factors",
        "auth_recovery_codes",
        "auth_security_events",
    ),
    "backend/migrations/0003_commercial_release_operations.sql": (
        "billing_webhook_events",
        "entitlement_grants",
        "certified_releases",
        "release_activations",
        "previous_event_sha256",
        "backup_manifests",
        "rate_limit_buckets",
    ),
    "backend/app/production_bootstrap.py": (
        "def bind_database_boundary",
        "config.assert_production_safe()",
        "production requires",
        "Database schema is",
    ),
    "backend/app/production_readiness_api.py": (
        "REQUIRED_PRODUCTION_TABLES",
        "managed_postgresql",
        "schema_current",
        "billing_fail_closed",
        "/production-readiness",
    ),
    "backend/app/auth_guard.py": (
        "PUBLIC_V2_PREFIXES",
        "/v2/billing/webhooks/",
        "Session is invalid or revoked",
    ),
    "backend/app/authorization_guard.py": (
        "/v2/billing/webhooks/",
        "/v2/releases",
        "/v2/entitlements/users/",
        "Platform administrator access is required",
    ),
    "backend/app/security_tokens.py": (
        "class SecurityTokenService",
        "purpose",
        "hmac.compare_digest",
        "class PasswordPolicy",
    ),
    "backend/app/mfa.py": (
        "class SecretVault",
        "AESGCM",
        "class TotpService",
        "mfa-recovery",
        "otpauth://totp/",
    ),
    "backend/app/account_security_api.py": (
        "@router.get(\"/sessions\")",
        "@router.post(\"/sessions/revoke-others\")",
        "@router.post(\"/mfa/totp/enroll\")",
        "@router.post(\"/mfa/totp/{factor_id}/verify\")",
        "recovery_codes_returned_once",
        "auth_security_events",
    ),
    "backend/app/entitlements.py": (
        "PLAN_ENTITLEMENTS",
        "enterprise.sso",
        "workspace.shared",
        "explicit_grants",
        "class EntitlementService",
    ),
    "backend/app/billing_api.py": (
        "billing is disabled",
        "invalid billing webhook signature",
        "provider event id was reused with different payload",
        "subscription.activated",
        "entitlement.granted",
    ),
    "backend/app/release_management_api.py": (
        "class ReleaseSigner",
        "release-v1:",
        "release version already exists with a different manifest",
        "only certified releases can be activated",
        "previous_release_id",
    ),
    "backend/app/platform_audit.py": (
        "previous_event_sha256",
        "event_sha256",
        "class PlatformAuditLog",
        "def verify",
    ),
    "backend/app/backup_manifests.py": (
        "backup-v1:",
        "backup sha256 must be a 64-character hexadecimal digest",
        "schema_version",
        "mark_restored",
    ),
    "backend/app/rate_limit.py": (
        "class DatabaseRateLimiter",
        "ON CONFLICT(bucket_key) DO UPDATE",
        "RETURNING window_started_at, request_count",
        "retry_after",
    ),
    "backend/app/operations.py": (
        "SPORTS_TERMINAL_RATE_LIMIT_BACKEND",
        "database rate limiter unavailable; using development memory fallback",
        "Request safety backend unavailable",
        "Content-Security-Policy",
        "trust_proxy_headers",
    ),
    "backend/Dockerfile": (
        "USER sports-terminal",
        "SPORTS_TERMINAL_ENV=production",
        "SPORTS_TERMINAL_AUTO_MIGRATE=false",
        "SPORTS_TERMINAL_RATE_LIMIT_BACKEND=database",
        "SPORTS_TERMINAL_BILLING_MODE=disabled",
        "CMD [\"/app/start_production.sh\"]",
    ),
    "backend/start_production.sh": (
        "config.assert_production_safe()",
        "SPORTS_TERMINAL_RUN_MIGRATIONS_ON_START",
        "--no-proxy-headers",
        "exec \"$@\"",
    ),
    ".env.production.example": (
        "SPORTS_TERMINAL_DATABASE_URL=postgresql://",
        "SPORTS_TERMINAL_AUTO_MIGRATE=false",
        "SPORTS_TERMINAL_MFA_ENCRYPTION_KEY=REPLACE_",
        "SPORTS_TERMINAL_BILLING_MODE=disabled",
    ),
    ".github/COST_GUARD.md": (
        "workflow_dispatch",
        "Pushes and pull-request updates do not automatically start",
        "does not provision a cloud vendor",
    ),
    "docs/production_runbook.md": (
        "Production does not silently fall back to SQLite",
        "candidate → certified → active",
        "Repository workflows are manual-only",
        "A failed audit-chain verification is an incident",
    ),
    "backend/scripts/deployment_contract_test.py": (
        "manual-only workflows",
        "reject(text, \"\\n  push:\"",
        "reject(text, \"\\n  pull_request:\"",
        "SPORTS_TERMINAL_BILLING_MODE=disabled",
        "TrustedHostMiddleware",
    ),
    "backend/scripts/production_authorization_contract_test.py": (
        "/v2/billing/webhooks/",
        "/v2/releases",
        "/v2/entitlements/users/",
        "platform_admin",
    ),
    "backend/scripts/production_readiness_contract_test.py": (
        "sports-terminal-production-readiness-v1",
        "deployment_contract_test.py",
        "production_authorization_contract_test.py",
        "billing_contract_test.py",
        "release_management_contract_test.py",
        "rate_limit_contract_test.py",
    ),
    "backend/app/main_launch.py": (
        "TrustedHostMiddleware",
        "allowed_hosts=list(_RUNTIME_CONFIG.allowed_hosts",
        "account_security_router",
        "entitlements_router",
        "billing_router",
        "release_management_router",
        "platform_audit_router",
        "backup_manifest_router",
        "production_readiness_router",
    ),
    ".github/workflows/flutter_quality.yml": (
        "workflow_dispatch",
        "production_readiness_contract_test.py",
        "audit_production_platform_v1.py --check",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/production_platform_v1.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v16.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v16.py"),
            "--check",
            "--json",
            str(legacy_output),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    failures: list[dict[str, str]] = []
    assertions = 0
    passed = 0
    for relative, required in EXTRA_CONTRACTS.items():
        path = ROOT / relative
        if not path.exists():
            failures.append({"path": relative, "missing": "<file>"})
            continue
        text = path.read_text(encoding="utf-8")
        for token in required:
            assertions += 1
            if token not in text:
                failures.append({"path": relative, "missing": token})
            else:
                passed += 1

    legacy_payload: dict[str, object] = {}
    if legacy_output.exists():
        legacy_payload = json.loads(legacy_output.read_text(encoding="utf-8"))
    if legacy.returncode != 0:
        failures.append(
            {
                "path": "tools/audit_nba_platform_graph_v16.py",
                "missing": "legacy-v16-contract-pass",
            }
        )

    payload = {
        "contract": "production-database-auth-billing-release-operations-v1",
        "legacy_contract": legacy_payload.get("contract", "v16-unavailable"),
        "legacy_assertions": legacy_payload.get("assertions", 0),
        "legacy_passed": legacy_payload.get("passed", 0),
        "surfaces": len(EXTRA_CONTRACTS),
        "assertions": assertions,
        "passed": passed,
        "failures": failures,
    }
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 1 if args.check and failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
