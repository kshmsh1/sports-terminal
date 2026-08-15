from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise AssertionError(f"{label} is missing required token: {token}")


def reject(text: str, token: str, label: str) -> None:
    if token in text:
        raise AssertionError(f"{label} contains forbidden token: {token}")


def main() -> None:
    dockerfile = (BACKEND / "Dockerfile").read_text(encoding="utf-8")
    require(dockerfile, "USER sports-terminal", "Dockerfile")
    require(dockerfile, "postgresql-client", "Dockerfile")
    require(dockerfile, "SPORTS_TERMINAL_ENV=production", "Dockerfile")
    require(dockerfile, "SPORTS_TERMINAL_AUTO_MIGRATE=false", "Dockerfile")
    require(dockerfile, "SPORTS_TERMINAL_RATE_LIMIT_BACKEND=database", "Dockerfile")
    require(dockerfile, "SPORTS_TERMINAL_BILLING_MODE=disabled", "Dockerfile")
    require(dockerfile, "COPY migrations ./migrations", "Dockerfile")
    require(dockerfile, "socket.create_connection", "Dockerfile liveness")
    reject(dockerfile, "urllib.request.urlopen", "Dockerfile liveness")
    reject(dockerfile, "SPORTS_TERMINAL_DB_PATH=/data", "Dockerfile")

    startup = (BACKEND / "start_production.sh").read_text(encoding="utf-8")
    require(startup, "config.assert_production_safe()", "production startup")
    require(startup, "SPORTS_TERMINAL_RUN_MIGRATIONS_ON_START", "production startup")
    require(startup, "--proxy-headers", "production startup")
    require(startup, "--no-proxy-headers", "production startup")
    reject(
        startup,
        '--proxy-headers "${SPORTS_TERMINAL_TRUST_PROXY_HEADERS',
        "production startup",
    )

    assured_auth = (BACKEND / "app" / "assured_auth_api.py").read_text(encoding="utf-8")
    require(assured_auth, "production bootstrap verifies the schema", "assured auth")
    reject(assured_auth, "run_migrations()", "assured auth request path")

    migration_cli = (BACKEND / "scripts" / "migrate.py").read_text(encoding="utf-8")
    require(migration_cli, "bootstrap_core_schema()", "migration CLI")
    require(migration_cli, "bind_database_boundary()", "migration CLI")
    require(migration_cli, "auth_api.init_auth_db()", "migration CLI")

    production_env = (ROOT / ".env.production.example").read_text(encoding="utf-8")
    require(production_env, "SPORTS_TERMINAL_DATABASE_URL=postgresql://", "production env")
    require(production_env, "SPORTS_TERMINAL_BILLING_MODE=disabled", "production env")
    require(production_env, "SPORTS_TERMINAL_AUTO_MIGRATE=false", "production env")
    require(production_env, "SPORTS_TERMINAL_MFA_ENCRYPTION_KEY=REPLACE_", "production env")
    require(production_env, "SPORTS_TERMINAL_EMAIL_PROVIDER=http", "production env")
    require(production_env, "SPORTS_TERMINAL_OBJECT_STORE=http", "production env")
    require(production_env, "SPORTS_TERMINAL_ALLOW_DATABASE_RESTORE=false", "production env")

    dockerignore = (BACKEND / ".dockerignore").read_text(encoding="utf-8")
    for token in (".env", "*.db", ".data/", ".git/"):
        require(dockerignore, token, "dockerignore")

    launch = (BACKEND / "app" / "main_launch.py").read_text(encoding="utf-8")
    require(launch, "TrustedHostMiddleware", "launch API")
    require(launch, "allowed_hosts=list(_RUNTIME_CONFIG.allowed_hosts", "launch API")

    runbook = (ROOT / "docs" / "production_runbook.md").read_text(encoding="utf-8")
    require(runbook, "Production does not silently fall back to SQLite", "runbook")
    require(runbook, "candidate → certified → active", "runbook")
    require(runbook, "OIDC uses the authorization-code flow with PKCE S256", "runbook")
    require(runbook, "Sports Terminal does not silently provision accounts from an IdP", "runbook")
    require(runbook, "Repository workflows are manual-only", "runbook")

    cost_guard = (ROOT / ".github" / "COST_GUARD.md").read_text(encoding="utf-8")
    require(cost_guard, "workflow_dispatch", "GitHub cost guard")
    require(cost_guard, "Pushes and pull-request updates do not automatically start", "GitHub cost guard")

    workflows = sorted((ROOT / ".github" / "workflows").glob("*.yml"))
    if not workflows:
        raise AssertionError("at least one GitHub workflow must remain available for manual validation")
    for workflow in workflows:
        text = workflow.read_text(encoding="utf-8")
        require(text, "workflow_dispatch", workflow.name)
        reject(text, "\n  push:", workflow.name)
        reject(text, "\n  pull_request:", workflow.name)
        reject(text, "\n  schedule:", workflow.name)
        reject(text, "\n  workflow_run:", workflow.name)

    print(f"deployment_contract: PASS ({len(workflows)} manual-only workflows)")


if __name__ == "__main__":
    main()
