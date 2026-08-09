#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SEASON="${NBA_SEASON:-2025-26}"
SEASON_TYPES="${NBA_SEASON_TYPES:-regular,playoffs}"
VENV="${NBA_API_VENV:-$ROOT/.nba-api-venv}"
REPLACE=0
PLAN=0
STRICT=0
TIERS=()
ENDPOINTS=()
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --season)
      SEASON="$2"; shift 2 ;;
    --season-types)
      SEASON_TYPES="$2"; shift 2 ;;
    --replace)
      REPLACE=1; shift ;;
    --plan)
      PLAN=1; shift ;;
    --strict)
      STRICT=1; shift ;;
    --tier)
      TIERS+=("$2"); shift 2 ;;
    --endpoint)
      ENDPOINTS+=("$2"); shift 2 ;;
    --)
      shift; EXTRA+=("$@"); break ;;
    *)
      EXTRA+=("$1"); shift ;;
  esac
done

if [[ "$PLAN" -eq 1 ]]; then
  python3 tools/collect_nba_api_metrics.py \
    --season "$SEASON" \
    --season-types "$SEASON_TYPES" \
    --plan \
    "${EXTRA[@]}"
  exit 0
fi

if [[ ! -x "$VENV/bin/python" ]]; then
  echo "Creating NBA API environment: $VENV"
  python3 -m venv "$VENV"
fi

PYTHON="$VENV/bin/python"
PIP="$VENV/bin/pip"

if ! "$PYTHON" - <<'PY' >/dev/null 2>&1
import importlib.metadata
raise SystemExit(0 if importlib.metadata.version('nba_api') == '1.11.4' else 1)
PY
then
  echo "Installing pinned nba_api==1.11.4"
  "$PIP" install --quiet --upgrade pip
  "$PIP" install --quiet 'nba_api==1.11.4'
fi

COLLECT_ARGS=(
  --season "$SEASON"
  --season-types "$SEASON_TYPES"
)
[[ "$REPLACE" -eq 1 ]] && COLLECT_ARGS+=(--replace)
[[ "$STRICT" -eq 1 ]] && COLLECT_ARGS+=(--strict)
for tier in "${TIERS[@]}"; do COLLECT_ARGS+=(--tier "$tier"); done
for endpoint in "${ENDPOINTS[@]}"; do COLLECT_ARGS+=(--endpoint "$endpoint"); done
COLLECT_ARGS+=("${EXTRA[@]}")

echo ""
echo "=== SPORTS TERMINAL NBA API COLLECTION ==="
echo "Season:       $SEASON"
echo "Season types: $SEASON_TYPES"
echo "Environment:  $VENV"
echo ""

"$PYTHON" tools/collect_nba_api_metrics.py "${COLLECT_ARGS[@]}"

echo ""
echo "=== MATERIALIZING SPORTS TERMINAL METRICS ==="
MATERIALIZE_ARGS=(--check)
[[ "$REPLACE" -eq 1 ]] && MATERIALIZE_ARGS+=(--replace)
"$PYTHON" tools/materialize_nba_api_metrics.py "${MATERIALIZE_ARGS[@]}"

echo ""
echo "=== MATERIALIZED COVERAGE ==="
"$PYTHON" tools/summarize_nba_api_metrics.py

echo ""
echo "NBA API metric pipeline complete."
echo "Raw cache:  data/warehouse/nba_api_raw/$SEASON/"
echo "Overlay DB: data/warehouse/nba_api_metrics.sqlite"
echo "Report:     data/warehouse/nba_api_metric_materialization_report.json"
