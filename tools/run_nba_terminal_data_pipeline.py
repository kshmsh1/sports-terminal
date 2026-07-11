from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_RAW_DATABASE = "raw/basketball_reference/catalog.sqlite"
DEFAULT_WAREHOUSE = "data/warehouse/nba_2025.sqlite"
DEFAULT_SEED = "data/terminal_seed/nba_2025"
DEFAULT_ASSET_OUTPUT = "assets/data/nba/terminal_seed/nba_2025"
DEFAULT_REPORT = "data/terminal_seed/nba_2025/pipeline_report.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run the local NBA data pipeline end-to-end: build warehouse, export terminal seed, "
            "repair text, validate outputs, and mirror validated JSON into Flutter assets. "
            "This makes no network requests."
        )
    )
    parser.add_argument("--season", type=int, default=2025)
    parser.add_argument("--raw-database", default=DEFAULT_RAW_DATABASE)
    parser.add_argument("--warehouse", default=DEFAULT_WAREHOUSE)
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--asset-output", default=DEFAULT_ASSET_OUTPUT)
    parser.add_argument("--report", default=DEFAULT_REPORT)
    parser.add_argument("--skip-warehouse-build", action="store_true")
    parser.add_argument("--skip-seed-export", action="store_true")
    parser.add_argument("--skip-asset-sync", action="store_true")
    return parser.parse_args()


def run_step(name: str, command: list[str]) -> dict[str, Any]:
    print(f"\n==> {name}")
    print(" ".join(command))
    result = subprocess.run(command, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout.rstrip())
    if result.stderr:
        print(result.stderr.rstrip(), file=sys.stderr)
    step = {
        "name": name,
        "command": command,
        "returnCode": result.returncode,
        "stdoutTail": result.stdout[-4000:],
        "stderrTail": result.stderr[-4000:],
    }
    if result.returncode != 0:
        raise PipelineError(step)
    return step


class PipelineError(RuntimeError):
    def __init__(self, step: dict[str, Any]) -> None:
        super().__init__(f"Pipeline step failed: {step['name']}")
        self.step = step


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False, default=str) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    python = sys.executable
    steps: list[dict[str, Any]] = []
    status = "pass"
    failure: dict[str, Any] | None = None

    commands: list[tuple[str, list[str]]] = []
    if not args.skip_warehouse_build:
        commands.append(
            (
                "build_warehouse",
                [
                    python,
                    str(root / "tools" / "build_nba_warehouse.py"),
                    "--database",
                    args.raw_database,
                    "--season",
                    str(args.season),
                    "--output",
                    args.warehouse,
                ],
            )
        )
    if not args.skip_seed_export:
        commands.append(
            (
                "export_terminal_seed",
                [
                    python,
                    str(root / "tools" / "export_nba_terminal_seed.py"),
                    "--database",
                    args.warehouse,
                    "--output",
                    args.seed,
                ],
            )
        )
    commands.append(
        (
            "finalize_and_validate_seed",
            [
                python,
                str(root / "tools" / "finalize_nba_terminal_seed.py"),
                "--warehouse",
                args.warehouse,
                "--seed",
                args.seed,
                "--season",
                str(args.season),
            ],
        )
    )
    if not args.skip_asset_sync:
        commands.append(
            (
                "sync_flutter_assets",
                [
                    python,
                    str(root / "tools" / "sync_nba_terminal_assets.py"),
                    "--seed",
                    args.seed,
                    "--asset-output",
                    args.asset_output,
                    "--clean",
                ],
            )
        )

    try:
        for name, command in commands:
            steps.append(run_step(name, command))
    except PipelineError as error:
        status = "fail"
        failure = error.step
        steps.append(error.step)

    report = {
        "status": status,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "seasonEndYear": args.season,
        "rawDatabase": args.raw_database,
        "warehouse": args.warehouse,
        "seed": args.seed,
        "assetOutput": args.asset_output,
        "steps": steps,
        "failure": failure,
    }
    write_report(Path(args.report), report)
    print(json.dumps({"status": status, "report": args.report}, indent=2))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
