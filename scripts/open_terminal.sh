#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

USE_POSTGRES=false
NO_BROWSER=false
FORCE_STATIC=false
MATERIALIZE_PBP=true
for arg in "$@"; do
  case "$arg" in
    --postgres) USE_POSTGRES=true ;;
    --no-browser) NO_BROWSER=true ;;
    --rebuild-static) FORCE_STATIC=true ;;
    --materialize-pbp) MATERIALIZE_PBP=true ;;
    --skip-pbp) MATERIALIZE_PBP=false ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/open_terminal.sh [--postgres] [--no-browser] [--rebuild-static] [--skip-pbp]

Starts Sports Terminal locally.

Historical NBA website data is compiled from the canonical warehouse into
versioned, sharded static JSON under web/data/nba_static before Flutter starts.
Home, Stats, Advanced Stats, player pages, team pages, awards, drafts,
contracts/cap snapshots, historical game details and source-backed historical
play-by-play read those files directly in the browser. FastAPI/SQLite are not
in the historical page-rendering path.

  --postgres         Use the loopback-only Postgres 17 app database.
  --no-browser       Do not automatically open http://127.0.0.1:8080.
  --rebuild-static   Force rebuilding static NBA files even when fingerprints match.
  --skip-pbp         Skip first-time historical PBP materialization. Existing PBP shards remain usable.

Static compilation is fingerprint-aware. The first launch after this migration
can take longer because player/team/game/PBP shards are published once; later
launches skip unchanged work. Only rows already exposed by the canonical
warehouse are materialized. Missing historical PBP coverage remains missing.

The launcher checks the current checkout and immediately previous repo root for
nba_history.sqlite. If no canonical warehouse exists but already-downloaded
raw/historical sources exist, it can rebuild locally. It never silently scrapes
or downloads sports data.
EOF
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "Flutter is required." >&2; exit 1; }

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

CURRENT_HISTORY_DB="$ROOT/data/warehouse/nba_history.sqlite"
PARENT_HISTORY_DB="$PARENT_ROOT/data/warehouse/nba_history.sqlite"
if [[ -s "$CURRENT_HISTORY_DB" ]]; then
  HISTORY_DB="$CURRENT_HISTORY_DB"
elif [[ -s "$PARENT_HISTORY_DB" ]]; then
  HISTORY_DB="$PARENT_HISTORY_DB"
  echo "==> Rediscovered NBA history warehouse: $HISTORY_DB"
else
  HISTORY_DB="$CURRENT_HISTORY_DB"
fi

CURRENT_SOURCE_ROOT="$ROOT/raw/historical"
PARENT_SOURCE_ROOT="$PARENT_ROOT/raw/historical"
if [[ -d "$CURRENT_SOURCE_ROOT" ]]; then
  HISTORICAL_SOURCE_ROOT="$CURRENT_SOURCE_ROOT"
elif [[ -d "$PARENT_SOURCE_ROOT" ]]; then
  HISTORICAL_SOURCE_ROOT="$PARENT_SOURCE_ROOT"
else
  HISTORICAL_SOURCE_ROOT="$CURRENT_SOURCE_ROOT"
fi

export SPORTS_TERMINAL_NBA_HISTORY_DB="$HISTORY_DB"

history_db_has_canonical_tables() {
  [[ -s "$HISTORY_DB" ]] || return 1
  "$PYTHON" - "$HISTORY_DB" <<'PY' >/dev/null 2>&1
import sqlite3, sys
with sqlite3.connect(sys.argv[1]) as db:
    names = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view')")}
required = {
    "canon_dim_player",
    "canon_dim_team",
    "canon_dim_season",
    "canon_dim_game",
    "canon_fact_player_season",
    "canon_fact_team_season",
}
raise SystemExit(0 if required.issubset(names) else 1)
PY
}

history_db_has_import_inventory() {
  [[ -s "$HISTORY_DB" ]] || return 1
  "$PYTHON" - "$HISTORY_DB" <<'PY' >/dev/null 2>&1
import sqlite3, sys
with sqlite3.connect(sys.argv[1]) as db:
    row = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='historical_table_inventory'").fetchone()
raise SystemExit(0 if row else 1)
PY
}

local_historical_sources_exist() {
  [[ -d "$HISTORICAL_SOURCE_ROOT" ]] || return 1
  find "$HISTORICAL_SOURCE_ROOT" -type f \
    \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' -o -name '*.csv' \) \
    -print -quit 2>/dev/null | grep -q .
}

prepare_nba_history() {
  mkdir -p "$(dirname "$HISTORY_DB")"
  if history_db_has_canonical_tables; then
    echo "==> Canonical NBA history warehouse ready: $HISTORY_DB"
    return 0
  fi
  if history_db_has_import_inventory; then
    echo "==> Canonicalizing existing historical NBA warehouse"
    "$PYTHON" tools/build_historical_nba_canonical.py --database "$HISTORY_DB" || true
    history_db_has_canonical_tables && return 0
  fi
  if local_historical_sources_exist; then
    echo "==> Importing already-downloaded historical NBA sources"
    "$PYTHON" tools/run_historical_nba_import.py \
      --source-root "$HISTORICAL_SOURCE_ROOT" \
      --output "$HISTORY_DB" \
      --report "$(dirname "$HISTORY_DB")/nba_history_import_report.json"
    "$PYTHON" tools/build_historical_nba_canonical.py --database "$HISTORY_DB"
    history_db_has_canonical_tables && return 0
  fi
  echo "Canonical NBA history warehouse is unavailable." >&2
  echo "Checked: $CURRENT_HISTORY_DB" >&2
  echo "Checked: $PARENT_HISTORY_DB" >&2
  return 1
}

STATIC_NBA_DIR="$ROOT/web/data/nba_static"

validate_static_nba_corpus() {
  "$PYTHON" - "$STATIC_NBA_DIR" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
manifest_path = root / "manifest.json"
if not manifest_path.is_file():
    raise SystemExit("Static NBA manifest is missing")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
latest = str(manifest.get("latest_season") or "")
required = [
    root / "seasons.json",
    root / "players/index.json",
    root / "teams/index.json",
    root / "games/index.json",
    root / "history/awards.json",
    root / "history/all_star.json",
    root / "history/draft.json",
]
if latest:
    required.extend([
        root / f"seasons/{latest}/regular.json",
        root / f"dashboard/{latest}.json",
    ])
missing = [str(path.relative_to(root)) for path in required if not path.is_file()]
if missing:
    raise SystemExit("Static NBA corpus is incomplete: " + ", ".join(missing))
runtime = manifest.get("runtime") or {}
if runtime.get("historical_http_api_required") is not False:
    raise SystemExit("Static NBA manifest does not declare API-independent historical runtime")
print(f"Static NBA corpus validated: {manifest.get('season_count', 0)} seasons; latest={latest or 'unknown'}")
PY
}

prepare_nba_history

STATIC_ARGS=(--database "$HISTORY_DB" --output "$STATIC_NBA_DIR")
GAME_ARGS=(--database "$HISTORY_DB" --output "$STATIC_NBA_DIR")
if $FORCE_STATIC; then
  STATIC_ARGS+=(--force)
  GAME_ARGS+=(--force)
fi
if $MATERIALIZE_PBP; then GAME_ARGS+=(--include-pbp); fi

echo "==> Preparing immutable static NBA website data"
"$PYTHON" tools/build_static_nba_website_data_v2.py "${STATIC_ARGS[@]}"

echo "==> Preparing static historical game detail${MATERIALIZE_PBP:+ and source-backed PBP}"
"$PYTHON" tools/build_static_nba_game_data.py "${GAME_ARGS[@]}"

validate_static_nba_corpus

echo "==> Resolving Flutter dependencies"
flutter pub get >/dev/null

mkdir -p "$ROOT/.data/logs" "$ROOT/.data/objects" "$ROOT/backend/.data"
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
  [[ -n "$FLUTTER_PID" ]] && kill "$FLUTTER_PID" >/dev/null 2>&1 || true
  [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" >/dev/null 2>&1 || true
  if $STARTED_POSTGRES; then
    docker compose -f backend/docker-compose.postgres.yml --profile local-postgres down >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_port() {
  local port="$1" label="$2"
  for _ in $(seq 1 60); do
    if "$PYTHON" - "$port" <<'PY' >/dev/null 2>&1
import socket, sys
with socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=0.5):
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
  "$PYTHON" backend/scripts/local_postgres_smoke.py
else
  unset SPORTS_TERMINAL_DATABASE_URL || true
  export SPORTS_TERMINAL_DB_PATH="$ROOT/backend/.data/sports_terminal.db"
fi

# Dynamic services still power accounts, saved work, community, mutable
# front-office edits and future active-season overlays. Historical basketball
# pages do not depend on them.
echo "==> Initializing application database"
"$PYTHON" backend/scripts/migrate.py >/dev/null

# Publish the last persisted contract/cap/draft registry after migrations. The
# static NBA compiler replaces its output directory atomically, so this must run
# after the core historical corpus has been finalized.
if ! $USE_POSTGRES; then
  echo "==> Publishing static front-office snapshot"
  "$PYTHON" tools/build_static_front_office_snapshot.py \
    --database "$SPORTS_TERMINAL_DB_PATH" \
    --output "$STATIC_NBA_DIR/front_office" >/dev/null
else
  echo "==> Postgres mode: keeping any previously published static front-office snapshot"
fi

echo "==> Starting dynamic Sports Terminal services at http://127.0.0.1:8000"
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

cat <<EOF

Sports Terminal is running locally.
  Website:         http://127.0.0.1:8080
  Dynamic API:     http://127.0.0.1:8000
  NBA warehouse:   $HISTORY_DB
  Static NBA:       $STATIC_NBA_DIR
  Front office:     $STATIC_NBA_DIR/front_office
  Backend log:      .data/logs/backend.log
  Flutter log:      .data/logs/flutter.log

Historical NBA pages are served from static files, not the API.
Press Ctrl-C to stop it.
EOF

wait "$FLUTTER_PID"
