#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CATALOG=""
BACKEND_URL="http://127.0.0.1:8000"
ACTOR_USER_ID=""
REGISTER_CATALOG=false
REQUIRE_VERIFIED=false
RUN_NBA_RELEASE=auto
RUN_DOCKER=auto

while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog)
      CATALOG="$2"
      shift 2
      ;;
    --backend-url)
      BACKEND_URL="$2"
      shift 2
      ;;
    --actor-user-id)
      ACTOR_USER_ID="$2"
      shift 2
      ;;
    --register-catalog)
      REGISTER_CATALOG=true
      shift
      ;;
    --require-verified)
      REQUIRE_VERIFIED=true
      shift
      ;;
    --with-nba-release)
      RUN_NBA_RELEASE=true
      shift
      ;;
    --skip-nba-release)
      RUN_NBA_RELEASE=false
      shift
      ;;
    --with-docker-build)
      RUN_DOCKER=true
      shift
      ;;
    --skip-docker-build)
      RUN_DOCKER=false
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="$ROOT/data/completion_reports/$TIMESTAMP"
mkdir -p "$REPORT_DIR"
SUMMARY="$REPORT_DIR/summary.tsv"
: > "$SUMMARY"

log_step() {
  local name="$1"
  shift
  local started
  started="$(date -u +%s)"
  echo
  echo "================================================================"
  echo "SPORTS TERMINAL STEP: $name"
  echo "================================================================"
  set +e
  "$@" 2>&1 | tee "$REPORT_DIR/${name}.log"
  local status=${PIPESTATUS[0]}
  set -e
  local finished
  finished="$(date -u +%s)"
  printf '%s\t%s\t%s\n' "$name" "$status" "$((finished - started))" >> "$SUMMARY"
  if [[ $status -ne 0 ]]; then
    echo "Step failed: $name" >&2
    build_report failed "$name"
    exit "$status"
  fi
}

build_report() {
  local overall="$1"
  local failed_step="${2:-}"
  python3 - "$SUMMARY" "$REPORT_DIR/report.json" "$overall" "$failed_step" <<'PY'
from __future__ import annotations
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

summary_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
overall = sys.argv[3]
failed_step = sys.argv[4]
steps = []
for line in summary_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    name, status, duration = line.split("\t")
    steps.append({
        "name": name,
        "status": "pass" if int(status) == 0 else "fail",
        "exit_code": int(status),
        "duration_seconds": int(duration),
        "log": f"{name}.log",
    })
report = {
    "status": overall,
    "failed_step": failed_step,
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "steps": steps,
    "total_duration_seconds": sum(item["duration_seconds"] for item in steps),
}
report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
PY
}

VENV="$ROOT/.venv-platform-completion"
if [[ ! -x "$VENV/bin/python" ]]; then
  python3 -m venv "$VENV"
fi
PYTHON="$VENV/bin/python"
PIP="$VENV/bin/pip"

log_step install_backend_dependencies "$PIP" install -r backend/requirements.txt
log_step compile_backend_and_tools "$PYTHON" -m compileall -q backend/app backend/scripts tools
log_step launch_backend_contract env PYTHONPATH=backend "$PYTHON" backend/scripts/launch_contract_test.py
log_step platform_completion_contract env PYTHONPATH=backend "$PYTHON" backend/scripts/run_platform_completion_contract_test.py
log_step workspace_completion_contract env PYTHONPATH=backend "$PYTHON" backend/scripts/workspace_completion_contract_test.py
log_step launch_http_contract env PYTHONPATH=backend "$PYTHON" backend/scripts/http_contract_test.py

if [[ -n "$CATALOG" ]]; then
  VALIDATE_ARGS=(
    tools/front_office_catalog.py validate "$CATALOG"
    --report "$REPORT_DIR/front_office_catalog_validation.json"
  )
  if [[ "$REQUIRE_VERIFIED" == true ]]; then
    VALIDATE_ARGS+=(
      --require-verified
      --minimum-contracts 400
      --minimum-team-positions 30
      --minimum-draft-assets 1
    )
  fi
  log_step front_office_catalog_validation env PYTHONPATH=backend "$PYTHON" "${VALIDATE_ARGS[@]}"

  if [[ "$REGISTER_CATALOG" == true ]]; then
    if [[ -z "$ACTOR_USER_ID" ]]; then
      echo "--register-catalog requires --actor-user-id" >&2
      build_report failed front_office_catalog_registration
      exit 2
    fi
    REGISTER_ARGS=(
      tools/front_office_catalog.py register "$CATALOG"
      --backend-url "$BACKEND_URL"
      --actor-user-id "$ACTOR_USER_ID"
      --report "$REPORT_DIR/front_office_catalog_registration.json"
    )
    if [[ "$REQUIRE_VERIFIED" == true ]]; then
      REGISTER_ARGS+=(
        --require-verified
        --minimum-contracts 400
        --minimum-team-positions 30
        --minimum-draft-assets 1
      )
    fi
    log_step front_office_catalog_registration env PYTHONPATH=backend "$PYTHON" "${REGISTER_ARGS[@]}"
  fi
fi

log_step flutter_dependencies flutter pub get
log_step pre_data_gate bash tools/check_pre_import_state.sh
log_step flutter_analysis flutter analyze
log_step flutter_tests flutter test
log_step flutter_release_build flutter build web --release

RAW_NBA_CATALOG="$ROOT/raw/basketball_reference/catalog.sqlite"
if [[ "$RUN_NBA_RELEASE" == true ]] || \
   { [[ "$RUN_NBA_RELEASE" == auto ]] && [[ -f "$RAW_NBA_CATALOG" ]]; }; then
  log_step nba_2025_26_release bash scripts/overnight_launch_build.sh
else
  echo "Skipping NBA release pipeline because $RAW_NBA_CATALOG is not present or it was explicitly disabled."
  printf '%s\t%s\t%s\n' "nba_2025_26_release_skipped" "0" "0" >> "$SUMMARY"
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  log_step docker_compose_config docker compose config
  if [[ "$RUN_DOCKER" == true ]]; then
    log_step docker_backend_build docker compose build backend
  elif [[ "$RUN_DOCKER" == auto ]]; then
    echo "Docker is available. Configuration was validated; image build skipped unless --with-docker-build is supplied."
  fi
else
  echo "Docker is unavailable; container configuration checks were skipped."
  printf '%s\t%s\t%s\n' "docker_unavailable_skipped" "0" "0" >> "$SUMMARY"
fi

build_report passed

echo
echo "Sports Terminal overnight completion pipeline passed."
echo "Report: $REPORT_DIR/report.json"
