from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "backend/migrations/0004_identity_delivery_assurance.sql": (
        "auth_delivery_tokens",
        "auth_login_challenges",
        "auth_session_security",
        "delivery_outbox",
    ),
    "backend/migrations/0005_organization_security_sso.sql": (
        "organization_security_policies",
        "sso_connections",
        "sso_login_states",
        "max_session_days",
    ),
    "backend/app/email_delivery.py": (
        "class SecurityEmailDelivery",
        "Console email delivery is forbidden in production",
        "destination_hash",
        "Idempotency-Key",
        "Security email delivery failed",
    ),
    "backend/app/auth_delivery.py": (
        "class AuthDeliveryTokenService",
        "superseded",
        "purpose",
        "consumed_at",
    ),
    "backend/app/auth_recovery_api.py": (
        "/email-verification/request",
        "/email-verification/confirm",
        "/password-reset/request",
        "/password-reset/confirm",
        "sessions_revoked",
    ),
    "backend/app/mfa_login.py": (
        "class MfaLoginService",
        "mfa-login-challenge",
        "totp-or-recovery",
        "auth_recovery_codes",
        "consumed_at",
    ),
    "backend/app/assured_auth_api.py": (
        '@router.post("/login")',
        '@router.post("/login/mfa")',
        '"mfa_required": True',
        'auth_level="mfa"',
        "auth_session_security",
    ),
    "backend/docker-compose.postgres.yml": (
        "postgres:17-alpine",
        'profiles: ["local-postgres"]',
        "127.0.0.1:54329:5432",
        'restart: "no"',
    ),
    "backend/scripts/local_postgres_smoke.py": (
        "bind_database_boundary()",
        "legacy_main.init_db()",
        "run_migrations()",
        "database.list_tables(connection)",
    ),
    "backend/app/object_store.py": (
        "class FilesystemObjectStore",
        "class HttpObjectStore",
        "production filesystem object storage is disabled",
        "X-Content-SHA256",
        "Idempotency-Key",
    ),
    "backend/app/backup_executor.py": (
        "source.raw.backup(destination)",
        "pg_dump",
        "object_store_from_env().put",
        "verify_manifest",
    ),
    "backend/app/restore_executor.py": (
        "verify_backup_object",
        "PRAGMA quick_check",
        "SPORTS_TERMINAL_ALLOW_DATABASE_RESTORE",
        "pg_restore",
        "mark_restored",
    ),
    "backend/app/environment_promotions.py": (
        "development → staging → production",
        "only certified releases can be promoted",
        "source environment schema is not current",
        "environment.promoted",
    ),
    "backend/app/environment_promotion_api.py": (
        'prefix="/v2/operations/environments"',
        '@router.post("/promote")',
        '@router.post("/{environment}/healthy")',
    ),
    "backend/app/service_health.py": (
        "class ServiceHealthEvaluator",
        "runtime_configuration",
        "audit_chain",
        "critical_failures",
    ),
    "backend/app/metrics_api.py": (
        "sports_terminal_health",
        "sports_terminal_backup_age_seconds",
        "sports_terminal_failed_billing_webhooks",
        "/prometheus",
    ),
    "backend/app/alerting.py": (
        "class AlertEvaluator",
        "backup-missing",
        "security-email-failures",
        "active-release-missing",
    ),
    "backend/app/sso.py": (
        "class SsoConnectionService",
        "OIDC issuer and endpoints must use HTTPS",
        "client_secret_ciphertext",
        "oidc-state",
        "consume_state",
    ),
    "backend/app/organization_security_api.py": (
        "require_mfa",
        "sso_required",
        "max_session_days",
        "Organization administrator access is required",
        "configure_oidc",
    ),
    "backend/app/auth_guard.py": (
        "/v2/auth/login/mfa",
        "/v2/auth/password-reset/confirm",
        "MFA is required by organization policy",
        "SSO is required by organization policy",
        "Session exceeds organization maximum lifetime",
        "request.state.auth_level",
    ),
    "backend/scripts/production_readiness_contract_test.py": (
        "sports-terminal-production-readiness-v1",
        "sports-terminal-production-readiness-v2",
        "email_delivery_contract_test.py",
        "assured_auth_contract_test.py",
        "restore_executor_contract_test.py",
        "auth_policy_enforcement_contract_test.py",
    ),
    "backend/scripts/local_postgres_orchestration_contract_test.py": (
        "local_postgres_orchestration_contract: PASS",
        "local-development-only",
    ),
    "backend/scripts/backup_executor_contract_test.py": (
        "backup_executor_contract: PASS",
        "verified_at",
    ),
    "backend/scripts/restore_executor_contract_test.py": (
        "restore_executor_contract: PASS",
        "restored-value",
        "explicit destructive opt-in",
    ),
    "backend/scripts/sso_contract_test.py": (
        "sso_contract: PASS",
        "never-store-plaintext",
        "response_type=code",
    ),
    "backend/scripts/auth_policy_enforcement_contract_test.py": (
        "MFA is required",
        "maximum lifetime",
        "/v2/auth/password-reset/request",
    ),
    "backend/app/main_launch.py": (
        "assured_auth_router",
        "auth_recovery_router",
        "environment_promotion_router",
        "metrics_router",
        "alerts_router",
        "organization_security_router",
    ),
    ".github/workflows/flutter_quality.yml": (
        "workflow_dispatch",
        "audit_production_platform_v1.py --check",
        "audit_production_platform_v2.py --check",
        "production_readiness_contract_test.py",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/production_platform_v2.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/production_platform_v1.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_production_platform_v1.py"),
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
                "path": "tools/audit_production_platform_v1.py",
                "missing": "legacy-production-v1-contract-pass",
            }
        )

    payload = {
        "contract": "production-identity-delivery-backup-promotion-observability-sso-v2",
        "legacy_contract": legacy_payload.get("contract", "production-v1-unavailable"),
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
