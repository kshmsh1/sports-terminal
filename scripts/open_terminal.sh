#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

USE_POSTGRES=false
NO_BROWSER=false
for arg in "$@"; do
  case "$arg" in
    --postgres) USE_POSTGRES=true ;;
    --no-browser) NO_BROWSER=true ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/open_terminal.sh [--postgres] [--no-browser]

Starts a local Sports Terminal review session without hosted services.
Default: SQLite + locally available NBA data.
  --postgres    Use the repository's loopback-only Postgres 17 container.
  --no-browser  Do not automatically open http://127.0.0.1:8080.

When the Flutter NBA seed is missing, the launcher automatically rebuilds or
syncs it when an existing local raw catalog, warehouse, or exported seed is
available. It never invents sports data and never downloads a source silently.

Stop the session with Ctrl-C.
EOF
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "Flutter is required. Install Flutter stable and ensure 'flutter' is on PATH." >&2; exit 1; }

VENV="$ROOT/.venv"
if [[ ! -x "$VENV/bin/python" ]]; then
  echo "==> Creating .venv"
  python3 -m venv "$VENV"
fi
PYTHON="$VENV/bin/python"

if [[ "${SPORTS_TERMINAL_SKIP_DEP_INSTALL:-false}" != "true" ]]; then
  echo "==> Resolving backend dependencies"
  "$PYTHON" -m pip install --disable-pip-version-check -q -r backend/requirements.txt
fi

prepare_nba_seed() {
  local asset_dir="$ROOT/assets/data/nba/terminal_seed/nba_2025"
  local asset_manifest="$asset_dir/manifest.json"
  local exported_seed="$ROOT/data/terminal_seed/nba_2025"
  local warehouse="$ROOT/data/warehouse/nba_2025.sqlite"
  local raw_catalog="$ROOT/raw/basketball_reference/catalog.sqlite"

  if [[ -s "$asset_manifest" ]]; then
    echo "==> NBA website data is ready"
    return 0
  fi

  if [[ -s "$exported_seed/manifest.json" ]]; then
    echo "==> Syncing existing NBA seed into Flutter assets"
    if "$PYTHON" tools/sync_nba_terminal_assets.py \
      --seed "$exported_seed" \
      --asset-output "$asset_dir" \
      --clean; then
      return 0
    fi
    echo "    NBA seed sync failed; the website will show a clean data-setup state." >&2
    return 0
  fi

  if [[ -s "$warehouse" ]]; then
    echo "==> Exporting NBA website data from the existing local warehouse"
    if "$PYTHON" tools/run_nba_terminal_data_pipeline.py \
      --skip-warehouse-build; then
      return 0
    fi
    echo "    NBA seed export failed; the website will show a clean data-setup state." >&2
    return 0
  fi

  if [[ -s "$raw_catalog" ]]; then
    echo "==> Building NBA website data from the existing local source catalog"
    if "$PYTHON" tools/run_nba_terminal_data_pipeline.py; then
      return 0
    fi
    echo "    NBA data preparation failed; the website will show a clean data-setup state." >&2
    return 0
  fi

  cat <<'EOF'
==> NBA source data is not installed on this checkout
    The website will still launch, but NBA data-dependent pages will show a
    friendly setup state instead of an asset exception. Sports Terminal will
    never synthesize player statistics to hide a missing source dataset.
EOF
}

prepare_nba_seed

echo "==> Resolving Flutter dependencies"
flutter pub get >/dev/null

mkdir -p "$ROOT/.data/logs" "$ROOT/.data/objects"
export PYTHONPATH="$ROOT/backend"
export SPORTS_TERMINAL_ENV=development
export SPORTS_TERMINAL_AUTO_MIGRATE=true
export SPORTS_TERMINAL_ENFORCE_AUTH=false
export SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION=false
export SPORTS_TERMINAL_BILLING_MODE=disabled
export SPORTS_TERMINAL_RATE_LIMITS=false
export SPORTS_TERMINAL_EMAIL_PROVIDER=console
export SPORTS_TERMINAL_OBJECT_STORE=filesystem
export SPORTS_TERMINAL_OBJECT_STORE_ROOT="$ROOT/.data/objects"
export SPORTS_TERMINAL_PUBLIC_API_ORIGIN="http://127.0.0.1:8000"
export SPORTS_TERMINAL_SESSION_PEPPER="local-session-pepper-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_MFA_ENCRYPTION_KEY="local-mfa-encryption-key-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_SSO_ENCRYPTION_KEY="local-sso-encryption-key-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_RELEASE_SIGNING_SECRET="local-release-signing-secret-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_BACKUP_SIGNING_SECRET="local-backup-signing-secret-0123456789abcdef0123456789abcdef"

STARTED_POSTGRES=false
BACKEND_PID=""
FLUTTER_PID=""
cleanup() {
  echo
  echo "==> Stopping Sports Terminal local session"
  if [[ -n "$FLUTTER_PID" ]]; then kill "$FLUTTER_PID" >/dev/null 2>&1 || true; fi
  if [[ -n "$BACKEND_PID" ]]; then kill "$BACKEND_PID" >/dev/null 2>&1 || true; fi
  if $STARTED_POSTGRES; then
    docker compose -f backend/docker-compose.postgres.yml --profile local-postgres down >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_port() {
  local port="$1"
  local label="$2"
  for _ in $(seq 1 60); do
    if "$PYTHON" - "$port" <<'PY' >/dev/null 2>&1
import socket, sys
port = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", port), timeout=0.5):
    pass
PY
    then return 0; fi
    sleep 1
  done
  echo "$label did not start on port $port." >&2
  return 1
}

if $USE_POSTGRES; then
  command -v docker >/dev/null 2>&1 || { echo "Docker is required for --postgres." >&2; exit 1; }
  echo "==> Starting loopback-only Postgres 17"
  docker compose -f backend/docker-compose.postgres.yml --profile local-postgres up -d postgres
  STARTED_POSTGRES=true
  export SPORTS_TERMINAL_DATABASE_URL="postgresql://sports_terminal:local-development-only@127.0.0.1:54329/sports_terminal"
  wait_for_port 54329 "Postgres"
  echo "==> Verifying PostgreSQL compatibility"
  "$PYTHON" backend/scripts/local_postgres_smoke.py
else
  unset SPORTS_TERMINAL_DATABASE_URL || true
fi

echo "==> Initializing local database schema"
"$PYTHON" backend/scripts/migrate.py >/dev/null

echo "==> Starting Sports Terminal API at http://127.0.0.1:8000"
"$PYTHON" -m uvicorn app.main_launch:app --host 127.0.0.1 --port 8000 \
  >"$ROOT/.data/logs/backend.log" 2>&1 &
BACKEND_PID=$!
wait_for_port 8000 "Sports Terminal API"

if ! kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
  echo "Backend exited during startup. See .data/logs/backend.log" >&2
  exit 1
fi

echo "==> Starting Sports Terminal website at http://127.0.0.1:8080"
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
  >"$ROOT/.data/logs/flutter.log" 2>&1 &
FLUTTER_PID=$!
wait_for_port 8080 "Flutter web server"

if ! kill -0 "$FLUTTER_PID" >/dev/null 2>&1; then
  echo "Flutter exited during startup. See .data/logs/flutter.log" >&2
  exit 1
fi

if ! $NO_BROWSER; then
  if command -v open >/dev/null 2>&1; then
    open "http://127.0.0.1:8080" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:8080" >/dev/null 2>&1 || true
  fi
fi

cat <<'EOF'

Sports Terminal is running locally.
  Website:  http://127.0.0.1:8080
  API:      http://127.0.0.1:8000
  Backend:  .data/logs/backend.log
  Flutter:  .data/logs/flutter.log

Press Ctrl-C to stop it.
EOF

wait "$FLUTTER_PID"
