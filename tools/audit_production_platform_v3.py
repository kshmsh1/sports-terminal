from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FINAL_CONTRACTS: dict[str, tuple[str, ...]] = {
    "backend/migrations/0006_oidc_identity.sql": (
        "pkce_verifier_ciphertext",
        "sso_identities",
        "provider_subject",
        "UNIQUE(connection_id, user_id)",
    ),
    "backend/requirements.txt": (
        "PyJWT[crypto]",
        "cryptography",
        "psycopg",
    ),
    "backend/app/sso.py": (
        "code_challenge_method",
        "S256",
        "exchange_authorization_code",
        "verify_id_token",
        "jwt.PyJWK.from_dict",
        "email_verified",
        "link_existing_identity",
        "OIDC ID token nonce does not match",
        "SSO sign-in requires an existing active Sports Terminal account",
    ),
    "backend/app/sso_auth_api.py": (
        'prefix="/v2/auth/sso"',
        '@router.get("/{organization_id}/start")',
        '@router.get("/{organization_id}/callback"',
        "exchange_authorization_code",
        "verify_id_token",
        'auth_level = "sso_mfa" if identity.mfa_authenticated else "sso"',
        "Organization policy requires the identity provider to assert MFA",
    ),
    "backend/app/auth_guard.py": (
        '"/v2/auth/sso/"',
        "state/PKCE/JWT protocol",
        'assurance not in {"sso", "sso_mfa"}',
    ),
    "backend/app/organization_security_api.py": (
        "SSO_LOGIN_ENFORCEMENT_READY = True",
        "enabled OIDC connection",
        "sso_required",
    ),
    "backend/app/main_launch.py": (
        "sso_auth_router",
        'app.version = "2.2.0"',
        "verified OIDC/PKCE authentication",
    ),
    "backend/scripts/oidc_login_contract_test.py": (
        "oidc_login_contract: PASS",
        "code_challenge_method",
        "provider-subject-123",
        "nonce mismatch must be rejected",
    ),
    "backend/scripts/migration_contract_test.py": (
        '"0006"',
        "sso_identities",
        "pkce_verifier_ciphertext",
    ),
    "backend/scripts/local_session_contract_test.py": (
        "local_session_contract: PASS",
        "reject(text, \"gh workflow\"",
        "127.0.0.1:8080",
    ),
    "scripts/open_terminal.sh": (
        "SPORTS_TERMINAL_BILLING_MODE=disabled",
        "backend/scripts/migrate.py",
        "flutter run -d web-server",
        "127.0.0.1:8000",
        "127.0.0.1:8080",
        "local_postgres_smoke.py",
    ),
    "scripts/validate_local.sh": (
        "production_readiness_contract_test.py",
        "audit_production_platform_v2.py --check",
        "flutter analyze",
        "flutter test",
        "flutter build web --release",
    ),
    "docs/production_runbook.md": (
        "authorization-code flow with PKCE S256",
        "does not silently provision accounts from an IdP",
        "./scripts/open_terminal.sh",
        "Neither local command dispatches GitHub Actions",
    ),
    ".env.production.example": (
        "SPORTS_TERMINAL_PUBLIC_API_ORIGIN=https://YOUR_API_HOST",
        "SPORTS_TERMINAL_SSO_ENCRYPTION_KEY",
        "authorization-code",
        "PKCE S256",
    ),
    "README.md": (
        "scripts/open_terminal.sh",
        "scripts/validate_local.sh",
        "127.0.0.1:8080",
    ),
    ".github/workflows/flutter_quality.yml": (
        "workflow_dispatch",
        "audit_production_platform_v2.py --check",
        "audit_production_platform_v3.py --check",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/production_platform_v3.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/production_platform_v2.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_production_platform_v2.py"),
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
    for relative, required in FINAL_CONTRACTS.items():
        path = ROOT / relative
        if not path.exists():
            failures.append({"path": relative, "missing": "<file>"})
            continue
        text = path.read_text(encoding="utf-8")
        for token in required:
            assertions += 1
            if token in text:
                passed += 1
            else:
                failures.append({"path": relative, "missing": token})

    legacy_payload: dict[str, object] = {}
    if legacy_output.exists():
        legacy_payload = json.loads(legacy_output.read_text(encoding="utf-8"))
    if legacy.returncode != 0:
        failures.append(
            {
                "path": "tools/audit_production_platform_v2.py",
                "missing": "legacy-production-v2-contract-pass",
            }
        )

    payload = {
        "contract": "sports-terminal-code-complete-local-review-v3",
        "legacy_contract": legacy_payload.get("contract", "production-v2-unavailable"),
        "legacy_assertions": legacy_payload.get("assertions", 0),
        "legacy_passed": legacy_payload.get("passed", 0),
        "surfaces": len(FINAL_CONTRACTS),
        "assertions": assertions,
        "passed": passed,
        "failures": failures,
        "external_non_code_requirements": [
            "commercial NBA data rights and authoritative production feed",
            "operator-selected hosted infrastructure and vendor accounts",
        ],
    }
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 1 if args.check and failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
