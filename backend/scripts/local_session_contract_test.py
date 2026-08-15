from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise AssertionError(f"{label} is missing required token: {token}")


def reject(text: str, token: str, label: str) -> None:
    if token in text:
        raise AssertionError(f"{label} contains forbidden token: {token}")


def main() -> None:
    launcher = (ROOT / "scripts" / "open_terminal.sh").read_text(encoding="utf-8")
    validator = (ROOT / "scripts" / "validate_local.sh").read_text(encoding="utf-8")

    for label, text in (("local launcher", launcher), ("local validator", validator)):
        require(text, "set -euo pipefail", label)
        require(text, ".venv", label)
        require(text, "backend/requirements.txt", label)
        reject(text, "gh workflow", label)
        reject(text, "gh run", label)
        reject(text, "workflow_dispatch", label)
        reject(text, "api.github.com", label)
        reject(text, "flyctl", label)
        reject(text, "railway", label)
        reject(text, "vercel", label)
        reject(text, "heroku", label)

    require(launcher, "SPORTS_TERMINAL_BILLING_MODE=disabled", "local launcher")
    require(launcher, "SPORTS_TERMINAL_ENFORCE_AUTH=false", "local launcher")
    require(launcher, "SPORTS_TERMINAL_OBJECT_STORE=filesystem", "local launcher")
    require(launcher, "127.0.0.1:8000", "local launcher")
    require(launcher, "127.0.0.1:8080", "local launcher")
    require(launcher, "flutter run -d web-server", "local launcher")
    require(launcher, "backend/scripts/migrate.py", "local launcher")
    require(launcher, "local_postgres_smoke.py", "local launcher")
    require(launcher, "docker-compose.postgres.yml", "local launcher")

    require(validator, "production_readiness_contract_test.py", "local validator")
    require(validator, "audit_production_platform_v1.py --check", "local validator")
    require(validator, "audit_production_platform_v2.py --check", "local validator")
    require(validator, "flutter analyze", "local validator")
    require(validator, "flutter test", "local validator")
    require(validator, "flutter build web --release", "local validator")

    workflows = list((ROOT / ".github" / "workflows").glob("*.yml"))
    for workflow in workflows:
        text = workflow.read_text(encoding="utf-8")
        require(text, "workflow_dispatch", workflow.name)
        reject(text, "\n  push:", workflow.name)
        reject(text, "\n  pull_request:", workflow.name)
        reject(text, "\n  schedule:", workflow.name)

    print(f"local_session_contract: PASS ({len(workflows)} manual-only workflows)")


if __name__ == "__main__":
    main()
