#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKEND_ONLY=false
WITH_POSTGRES=false
for arg in "$@"; do
  case "$arg" in
    --backend-only) BACKEND_ONLY=true ;;
    --postgres) WITH_POSTGRES=true ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/validate_local.sh [--backend-only] [--postgres]

Runs Sports Terminal validation locally without GitHub Actions.
  --backend-only  Skip Flutter analyze/test/build.
  --postgres      Also start loopback Postgres 17 and run the Postgres smoke contract.
EOF
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 1; }

VENV="$ROOT/.venv"
if [[ ! -x "$VENV/bin/python" ]]; then
  echo "==> Creating local Python virtual environment"
  python3 -m venv "$VENV"
fi
PYTHON="$VENV/bin/python"
PIP="$VENV/bin/pip"

if [[ "${SPORTS_TERMINAL_SKIP_DEP_INSTALL:-false}" != "true" ]]; then
  echo "==> Resolving backend dependencies locally"
  "$PYTHON" -m pip install --disable-pip-version-check -q -r backend/requirements.txt
fi

export PYTHONPATH="$ROOT/backend"
export SPORTS_TERMINAL_ENV=development
export SPORTS_TERMINAL_BILLING_MODE=disabled
export SPORTS_TERMINAL_SESSION_PEPPER="local-validation-session-pepper-0123456789abcdef"
export SPORTS_TERMINAL_MFA_ENCRYPTION_KEY="local-validation-mfa-encryption-key-0123456789abcdef"
export SPORTS_TERMINAL_SSO_ENCRYPTION_KEY="local-validation-sso-encryption-key-0123456789abcdef"
export SPORTS_TERMINAL_RELEASE_SIGNING_SECRET="local-validation-release-signing-secret-0123456789abcdef"
export SPORTS_TERMINAL_BACKUP_SIGNING_SECRET="local-validation-backup-signing-secret-0123456789abcdef"
export SPORTS_TERMINAL_EMAIL_PROVIDER=disabled
export SPORTS_TERMINAL_OBJECT_STORE=filesystem
export SPORTS_TERMINAL_OBJECT_STORE_ROOT="$ROOT/.data/validation-objects"

mkdir -p "$ROOT/.data"

if $WITH_POSTGRES; then
  command -v docker >/dev/null 2>&1 || { echo "Docker is required for --postgres." >&2; exit 1; }
  echo "==> Starting loopback-only Postgres 17"
  docker compose -f backend/docker-compose.postgres.yml --profile local-postgres up -d postgres
  cleanup_postgres() {
    docker compose -f backend/docker-compose.postgres.yml --profile local-postgres down >/dev/null 2>&1 || true
  }
  trap cleanup_postgres EXIT
  export SPORTS_TERMINAL_DATABASE_URL="postgresql://sports_terminal:local-development-only@127.0.0.1:54329/sports_terminal"
  for _ in $(seq 1 40); do
    if "$PYTHON" - <<'PY' >/dev/null 2>&1
import socket
with socket.create_connection(("127.0.0.1", 54329), timeout=1):
    pass
PY
    then break; fi
    sleep 1
  done
  echo "==> Running PostgreSQL compatibility smoke check"
  "$PYTHON" backend/scripts/local_postgres_smoke.py
  unset SPORTS_TERMINAL_DATABASE_URL
fi

echo "==> Compiling Python source"
"$PYTHON" -m compileall -q backend/app backend/scripts tools

echo "==> Running aggregate production readiness contracts"
"$PYTHON" backend/scripts/production_readiness_contract_test.py

echo "==> Running recursive production platform v1"
"$PYTHON" tools/audit_production_platform_v1.py --check

echo "==> Running recursive production platform v2"
"$PYTHON" tools/audit_production_platform_v2.py --check

if [[ -f tools/audit_production_platform_v3.py ]]; then
  echo "==> Running final local-launch/SSO completion graph"
  "$PYTHON" tools/audit_production_platform_v3.py --check
fi

if $BACKEND_ONLY; then
  echo "==> Backend-only validation complete"
  exit 0
fi

command -v flutter >/dev/null 2>&1 || {
  echo "Flutter is required for full validation. Re-run with --backend-only to skip Flutter." >&2
  exit 1
}

echo "==> Resolving Flutter dependencies"
flutter pub get

echo "==> Running Flutter analyzer"
flutter analyze

echo "==> Running Flutter test suite"
flutter test

echo "==> Building release web application"
flutter build web --release

echo "==> Sports Terminal local validation complete"
