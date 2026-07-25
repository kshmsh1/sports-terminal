#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DATABASE="${SPORTS_TERMINAL_DB_PATH:-$ROOT/backend/.data/sports_terminal.db}"
PRIVACY_USER_ID=""
PRIVACY_REQUEST_ID=""
PROCESS_PROVIDERS=false
RECORD_BACKUP=false
PLATFORM_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --database)
      DATABASE="$2"
      shift 2
      ;;
    --privacy-user-id)
      PRIVACY_USER_ID="$2"
      shift 2
      ;;
    --privacy-request-id)
      PRIVACY_REQUEST_ID="$2"
      shift 2
      ;;
    --process-provider-outbox)
      PROCESS_PROVIDERS=true
      shift
      ;;
    --record-backup-evidence)
      RECORD_BACKUP=true
      shift
      ;;
    --catalog|--backend-url|--actor-user-id)
      PLATFORM_ARGS+=("$1" "$2")
      shift 2
      ;;
    --register-catalog|--require-verified|--with-nba-release|--skip-nba-release|--with-docker-build|--skip-docker-build)
      PLATFORM_ARGS+=("$1")
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="$ROOT/data/full_launch_reports/$TIMESTAMP"
mkdir -p "$REPORT_DIR"
SUMMARY="$REPORT_DIR/summary.tsv"
: > "$SUMMARY"

run_step() {
  local name="$1"
  shift
  local started
  started="$(date -u +%s)"
  echo
  echo "================================================================"
  echo "FULL LAUNCH STEP: $name"
  echo "================================================================"
  set +e
  "$@" 2>&1 | tee "$REPORT_DIR/${name}.log"
  local status=${PIPESTATUS[0]}
  set -e
  local finished
  finished="$(date -u +%s)"
  printf '%s\t%s\t%s\n' "$name" "$status" "$((finished - started))" >> "$SUMMARY"
  if [[ $status -ne 0 ]]; then
    build_report failed "$name"
    exit "$status"
  fi
}

build_report() {
  local status="$1"
  local failed_step="${2:-}"
  python3 - "$SUMMARY" "$REPORT_DIR/report.json" "$status" "$failed_step" "$DATABASE" <<'PY'
from __future__ import annotations
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

summary_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
steps = []
for line in summary_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    name, exit_code, duration = line.split("\t")
    steps.append({
        "name": name,
        "status": "pass" if int(exit_code) == 0 else "fail",
        "exit_code": int(exit_code),
        "duration_seconds": int(duration),
        "log": f"{name}.log",
    })
report = {
    "status": sys.argv[3],
    "failed_step": sys.argv[4],
    "database": sys.argv[5],
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "steps": steps,
    "total_duration_seconds": sum(item["duration_seconds"] for item in steps),
}
report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
PY
}

run_step platform_completion bash scripts/overnight_platform_completion.sh "${PLATFORM_ARGS[@]}"

VENV="$ROOT/.venv-platform-completion"
PYTHON="$VENV/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -r backend/requirements.txt
fi

run_step customer_ops_contract env PYTHONPATH=backend "$PYTHON" backend/scripts/run_customer_ops_contract_test.py
run_step compile_operations_tools "$PYTHON" -m compileall -q \
  tools/process_provider_outbox.py \
  tools/build_privacy_export.py \
  tools/backup_and_verify.py

if [[ -f "$DATABASE" ]]; then
  BACKUP_ARGS=(
    tools/backup_and_verify.py
    --database "$DATABASE"
    --output-dir "$REPORT_DIR/backups"
    --actor-user-id system
  )
  if [[ "$RECORD_BACKUP" == true ]]; then
    BACKUP_ARGS+=(--record-evidence)
  fi
  run_step backup_and_restore_verification "$PYTHON" "${BACKUP_ARGS[@]}"

  if [[ "$PROCESS_PROVIDERS" == true ]]; then
    run_step provider_outbox_delivery "$PYTHON" tools/process_provider_outbox.py \
      --database "$DATABASE" \
      --limit 250 \
      --report "$REPORT_DIR/provider_outbox.json"
  else
    run_step provider_outbox_dry_run "$PYTHON" tools/process_provider_outbox.py \
      --database "$DATABASE" \
      --limit 250 \
      --dry-run \
      --report "$REPORT_DIR/provider_outbox_dry_run.json"
  fi

  if [[ -n "$PRIVACY_USER_ID" ]]; then
    PRIVACY_ARGS=(
      tools/build_privacy_export.py
      --database "$DATABASE"
      --user-id "$PRIVACY_USER_ID"
      --output-dir "$REPORT_DIR/privacy_exports"
    )
    if [[ -n "$PRIVACY_REQUEST_ID" ]]; then
      PRIVACY_ARGS+=(--request-id "$PRIVACY_REQUEST_ID")
    fi
    run_step privacy_export "$PYTHON" "${PRIVACY_ARGS[@]}"
  fi
else
  echo "Operational database not present at $DATABASE. Backup, provider and privacy execution were skipped."
  printf '%s\t0\t0\n' operational_database_absent_skipped >> "$SUMMARY"
fi

build_report passed

echo
echo "Sports Terminal full launch overnight pipeline passed."
echo "Report: $REPORT_DIR/report.json"
