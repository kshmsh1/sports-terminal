#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FORCE_STATIC=0
REFRESH_LIVE=0
for arg in "$@"; do
  case "$arg" in
    --rebuild-static) FORCE_STATIC=1 ;;
    --refresh-live) REFRESH_LIVE=1 ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: bash scripts/open_terminal.sh [--rebuild-static] [--refresh-live]" >&2
      exit 2
      ;;
  esac
done

find_history_db() {
  local candidates=(
    "$ROOT/data/warehouse/nba_history.sqlite"
    "$ROOT/nba_history.sqlite"
    "$(dirname "$ROOT")/data/warehouse/nba_history.sqlite"
    "$(dirname "$ROOT")/nba_history.sqlite"
  )
  local path
  for path in "${candidates[@]}"; do
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 1
}

NBA_HISTORY_DB="${SPORTS_TERMINAL_NBA_HISTORY_DB:-}"
if [[ -z "$NBA_HISTORY_DB" || ! -f "$NBA_HISTORY_DB" ]]; then
  if ! NBA_HISTORY_DB="$(find_history_db)"; then
    cat >&2 <<'EOF'
Sports Terminal could not find the local canonical NBA historical warehouse.
Expected one of:
  data/warehouse/nba_history.sqlite
  nba_history.sqlite
  the same paths in the immediately previous repository directory

Historical pages deliberately do not scrape or download immutable sports data at runtime.
Point SPORTS_TERMINAL_NBA_HISTORY_DB at your existing nba_history.sqlite and run again.
EOF
    exit 1
  fi
fi
export SPORTS_TERMINAL_NBA_HISTORY_DB="$NBA_HISTORY_DB"

PYTHON_BIN="${SPORTS_TERMINAL_PYTHON:-python3}"
if [[ -x "$ROOT/.historical-venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT/.historical-venv/bin/python"
elif ! "$PYTHON_BIN" -c 'import fastapi' >/dev/null 2>&1; then
  echo "Preparing one-time local Python environment for the static compiler..."
  python3 -m venv "$ROOT/.historical-venv"
  "$ROOT/.historical-venv/bin/python" -m pip install --upgrade pip >/dev/null
  "$ROOT/.historical-venv/bin/python" -m pip install -r "$ROOT/backend/requirements.txt"
  PYTHON_BIN="$ROOT/.historical-venv/bin/python"
fi

echo "NBA historical warehouse: $NBA_HISTORY_DB"
echo "Building/fingerprint-checking immutable NBA website data..."
STATIC_ARGS=(
  --database "$NBA_HISTORY_DB"
  --output "$ROOT/web/data/nba_static"
)
if [[ "$FORCE_STATIC" -eq 1 ]]; then
  STATIC_ARGS+=(--force)
fi
"$PYTHON_BIN" "$ROOT/tools/build_static_nba_website_data_v2_core.py" "${STATIC_ARGS[@]}"

# Basketball Reference regular-season totals label made threes as 3P and
# attempts as 3PA. Normalize those source-backed aliases (plus equivalent
# canonical import names) before dashboard generation so Stats and Advanced
# Stats consume one consistent three-point contract.
"$PYTHON_BIN" "$ROOT/tools/normalize_static_nba_three_point_fields.py" \
  --output "$ROOT/web/data/nba_static"

# Optional source-backed NBA.com fields such as deflections are read only from
# already-normalized local captures. This script performs no network requests.
"$PYTHON_BIN" "$ROOT/tools/nba_com_static_enrichment.py" \
  --output "$ROOT/web/data/nba_static"
"$PYTHON_BIN" "$ROOT/tools/rebuild_static_nba_dashboards.py" \
  --output "$ROOT/web/data/nba_static"

# User-provided regular-season totals fill the three documented 1946-49 gaps.
# The same static pass also rebuilds every dashboard player leaderboard with a
# 50-game qualification, including locally materialized tracking categories.
"$PYTHON_BIN" "$ROOT/tools/enrich_static_nba_pdf_early_totals.py" \
  --output "$ROOT/web/data/nba_static"

# Contracts/cap/draft records are also published as static read-only website
# files when the local mutable registry exists. Missing registry data produces
# explicit empty static files rather than a runtime API dependency.
"$PYTHON_BIN" "$ROOT/tools/build_static_front_office_snapshot.py" \
  --output "$ROOT/web/data/nba_static/front_office"

# Materialize detailed historical game/box-score files only when the canonical
# warehouse actually contains team/player game rows. This remains an entirely
# local static build; absent source rows stay explicitly unavailable.
GAME_DETAIL_ARGS=(
  --database "$NBA_HISTORY_DB"
  --output "$ROOT/web/data/nba_static"
)
if [[ "$FORCE_STATIC" -eq 1 ]]; then
  GAME_DETAIL_ARGS+=(--force)
fi
"$PYTHON_BIN" "$ROOT/tools/materialize_static_nba_game_details.py" \
  "${GAME_DETAIL_ARGS[@]}"

# The 2026-27 schedule is current-season fixture metadata, not historical stat
# data. Acquire it once from the official NBA CDN, then serve the local snapshot
# to the browser. Normal launches reuse the snapshot; --refresh-live explicitly
# refreshes it if the league changes a future game/date.
SCHEDULE_FILE="$ROOT/web/data/nba_live/schedule_2026_27.json"
if [[ ! -s "$SCHEDULE_FILE" || "$REFRESH_LIVE" -eq 1 ]]; then
  SCHEDULE_ARGS=(--output "$SCHEDULE_FILE")
  if [[ "$REFRESH_LIVE" -eq 1 ]]; then
    SCHEDULE_ARGS+=(--force)
  fi
  "$PYTHON_BIN" "$ROOT/tools/materialize_nba_2026_27_schedule.py" \
    "${SCHEDULE_ARGS[@]}" || true
fi

for required in \
  "$ROOT/web/data/nba_static/manifest.json" \
  "$ROOT/web/data/nba_static/seasons.json" \
  "$ROOT/web/data/nba_static/players/index.json" \
  "$ROOT/web/data/nba_static/teams/index.json"; do
  if [[ ! -s "$required" ]]; then
    echo "Static NBA corpus is incomplete: $required" >&2
    exit 1
  fi
done

LATEST_SEASON="$("$PYTHON_BIN" - <<'PY'
import json
from pathlib import Path
manifest = json.loads(Path('web/data/nba_static/manifest.json').read_text())
print(manifest.get('latest_season') or '')
PY
)"
if [[ -n "$LATEST_SEASON" && ! -s "$ROOT/web/data/nba_static/dashboard/$LATEST_SEASON.json" ]]; then
  echo "Static NBA dashboard is missing for $LATEST_SEASON" >&2
  exit 1
fi

echo "Static NBA website corpus ready${LATEST_SEASON:+ through $LATEST_SEASON}."
if [[ -s "$SCHEDULE_FILE" ]]; then
  echo "2026-27 schedule snapshot ready."
else
  echo "2026-27 schedule snapshot is not available yet; Live Games will show setup guidance." >&2
fi

echo "Resolving Flutter dependencies..."
flutter pub get

echo "Opening Sports Terminal in Chrome..."
exec flutter run -d chrome
