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
    require(dockerfile, "SPORTS_TERMINAL_ENV=production", "Dockerfile")
    require(dockerfile, "SPORTS_TERMINAL_AUTO_MIGRATE=false", "Dockerfile")
    require(dockerfile, "SPORTS_TERMINAL_RATE_LIMIT_BACKEND=database", "Dockerfile")
    require(dockerfile, "SPORTS_TERMINAL_BILLING_MODE=disabled", "Dockerfile")
    require(dockerfile, "COPY migrations ./migrations", "Dockerfile")
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

    production_env = (ROOT / ".env.production.example").read_text(encoding="utf-8")
    require(production_env, "SPORTS_TERMINAL_DATABASE_URL=postgresql://", "production env")
    require(production_env, "SPORTS_TERMINAL_BILLING_MODE=disabled", "production env")
    require(production_env, "SPORTS_TERMINAL_AUTO_MIGRATE=false", "production env")
    require(production_env, "SPORTS_TERMINAL_MFA_ENCRYPTION_KEY=REPLACE_", "production env")

    dockerignore = (BACKEND / ".dockerignore").read_text(encoding="utf-8")
    for token in (".env", "*.db", ".data/", ".git/"):
        require(dockerignore, token, "dockerignore")

    runbook = (ROOT / "docs" / "production_runbook.md").read_text(encoding="utf-8")
    require(runbook, "Production does not silently fall back to SQLite", "runbook")
    require(runbook, "candidate → certified → active", "runbook")
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
