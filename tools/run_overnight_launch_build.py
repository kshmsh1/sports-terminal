from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build and certify the complete single-season Sports Terminal launch package. "
            "The command is designed to run unattended and never activates a failed dataset."
        )
    )
    parser.add_argument("--season", type=int, default=2026)
    parser.add_argument("--raw-database", default="raw/basketball_reference/catalog.sqlite")
    parser.add_argument("--skip-warehouse-build", action="store_true")
    parser.add_argument("--skip-flutter", action="store_true")
    parser.add_argument("--skip-backend-smoke", action="store_true")
    parser.add_argument("--skip-backend-registration", action="store_true")
    parser.add_argument("--backend-url", default="http://127.0.0.1:8000")
    parser.add_argument(
        "--prepare-raw-command",
        help=(
            "Optional shell command to run before the warehouse build. Use this only for a known local "
            "scraper/import command that populates the raw catalog."
        ),
    )
    return parser.parse_args()


def season_label(season_end_year: int) -> str:
    return f"{season_end_year - 1}-{str(season_end_year)[-2:]}"


def timestamp_key() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False, default=str) + "\n",
        encoding="utf-8",
    )


def run_step(
    name: str,
    command: list[str],
    *,
    root: Path,
    log_dir: Path,
    environment: dict[str, str] | None = None,
) -> dict[str, Any]:
    started = datetime.now(timezone.utc)
    log_path = log_dir / f"{name}.log"
    print(f"\n==> {name}")
    print(" ".join(command))
    merged_environment = os.environ.copy()
    if environment:
        merged_environment.update(environment)
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            command,
            cwd=root,
            env=merged_environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        assert process.stdout is not None
        for line in process.stdout:
            print(line, end="")
            log.write(line)
        return_code = process.wait()
    finished = datetime.now(timezone.utc)
    result = {
        "name": name,
        "command": command,
        "returnCode": return_code,
        "startedAt": started.isoformat(),
        "finishedAt": finished.isoformat(),
        "durationSeconds": round((finished - started).total_seconds(), 3),
        "log": str(log_path),
    }
    if return_code != 0:
        raise RuntimeError(f"Launch build step failed: {name}. See {log_path}")
    return result


def run_shell_step(name: str, command: str, *, root: Path, log_dir: Path) -> dict[str, Any]:
    return run_step(name, ["bash", "-lc", command], root=root, log_dir=log_dir)


def copy_validated_seed(seed: Path, asset_output: Path) -> int:
    if asset_output.exists():
        shutil.rmtree(asset_output)
    shutil.copytree(seed, asset_output)
    return sum(1 for path in asset_output.rglob("*") if path.is_file())


def activate_config(root: Path, season_end_year: int, release: dict[str, Any]) -> Path:
    config_path = root / "assets/data/nba/launch/season_config.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    config.update(
        {
            "launchProfile": f"nba-{season_label(season_end_year)}-professional",
            "supportedSeason": season_label(season_end_year),
            "seasonEndYear": season_end_year,
            "candidateAssetPath": f"assets/data/nba/terminal_seed/nba_{season_end_year}",
            "datasetStatus": release.get("status", "validated"),
            "allowFallback": False,
            "activeReleaseId": release.get("id"),
            "activeReleaseVersion": release.get("version"),
            "updatedAt": datetime.now(timezone.utc).isoformat(),
        }
    )
    write_json(config_path, config)
    return config_path


def smoke_backend(root: Path, log_dir: Path, python: str) -> dict[str, Any]:
    port = 8011
    log_path = log_dir / "backend_smoke_server.log"
    environment = os.environ.copy()
    environment["SPORTS_TERMINAL_DB_PATH"] = str(log_dir / "backend_smoke.sqlite")
    environment["SPORTS_TERMINAL_CORS_ORIGINS"] = "http://127.0.0.1:5000"
    started = datetime.now(timezone.utc)
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            [python, "-m", "uvicorn", "app.main_launch:app", "--port", str(port)],
            cwd=root / "backend",
            env=environment,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
        try:
            deadline = time.time() + 30
            response: dict[str, Any] | None = None
            last_error = ""
            while time.time() < deadline:
                try:
                    with urllib.request.urlopen(
                        f"http://127.0.0.1:{port}/v2/launch/readiness",
                        timeout=2,
                    ) as request:
                        response = json.loads(request.read().decode("utf-8"))
                    break
                except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
                    last_error = str(error)
                    time.sleep(0.5)
            if response is None:
                raise RuntimeError(f"Launch backend did not become ready: {last_error}")
            return {
                "name": "backend_smoke",
                "returnCode": 0,
                "startedAt": started.isoformat(),
                "finishedAt": datetime.now(timezone.utc).isoformat(),
                "log": str(log_path),
                "readinessStatus": response.get("status"),
                "tables": len(response.get("tables", [])),
            }
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()


def register_release(backend_url: str, release: dict[str, Any], validation: dict[str, Any]) -> dict[str, Any]:
    release_id = str(release.get("id") or f"nba-{release.get('season', '2025-26')}-release")
    payload = dict(release)
    payload["validation"] = validation
    request = urllib.request.Request(
        f"{backend_url.rstrip('/')}/v2/data-releases/{release_id}",
        data=json.dumps({"actor_user_id": "overnight-pipeline", "release": payload}).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="PUT",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return {
                "registered": True,
                "statusCode": response.status,
                "response": json.loads(response.read().decode("utf-8")),
            }
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        return {"registered": False, "error": str(error)}


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    python = sys.executable
    season = season_label(args.season)
    warehouse = root / f"data/warehouse/nba_{args.season}.sqlite"
    seed = root / f"data/terminal_seed/nba_{args.season}"
    asset_output = root / f"assets/data/nba/terminal_seed/nba_{args.season}"
    report_root = root / "data/launch_reports" / f"{season}_{timestamp_key()}"
    report_root.mkdir(parents=True, exist_ok=True)
    steps: list[dict[str, Any]] = []
    report: dict[str, Any] = {
        "status": "running",
        "season": season,
        "seasonEndYear": args.season,
        "startedAt": datetime.now(timezone.utc).isoformat(),
        "rawDatabase": args.raw_database,
        "warehouse": str(warehouse),
        "seed": str(seed),
        "assetOutput": str(asset_output),
        "steps": steps,
    }
    report_path = report_root / "overnight_launch_report.json"
    write_json(report_path, report)

    try:
        if args.prepare_raw_command:
            steps.append(
                run_shell_step(
                    "prepare_raw_catalog",
                    args.prepare_raw_command,
                    root=root,
                    log_dir=report_root,
                )
            )
        raw_database = root / args.raw_database
        if not raw_database.exists():
            raise FileNotFoundError(
                f"Raw catalog does not exist: {raw_database}. Populate it first or pass --prepare-raw-command."
            )

        pipeline_command = [
            python,
            str(root / "tools/run_nba_terminal_data_pipeline.py"),
            "--season",
            str(args.season),
            "--raw-database",
            str(raw_database),
            "--warehouse",
            str(warehouse),
            "--seed",
            str(seed),
            "--asset-output",
            str(asset_output),
            "--report",
            str(report_root / "base_pipeline_report.json"),
        ]
        if args.skip_warehouse_build:
            pipeline_command.append("--skip-warehouse-build")
        steps.append(
            run_step(
                "base_nba_pipeline",
                pipeline_command,
                root=root,
                log_dir=report_root,
            )
        )
        steps.append(
            run_step(
                "export_launch_supplements",
                [
                    python,
                    str(root / "tools/export_launch_supplements.py"),
                    "--warehouse",
                    str(warehouse),
                    "--seed",
                    str(seed),
                    "--season",
                    str(args.season),
                ],
                root=root,
                log_dir=report_root,
            )
        )
        validation_path = seed / "launch_validation.json"
        steps.append(
            run_step(
                "validate_launch_dataset",
                [
                    python,
                    str(root / "tools/validate_launch_dataset.py"),
                    "--seed",
                    str(seed),
                    "--season",
                    str(args.season),
                    "--output",
                    str(validation_path),
                ],
                root=root,
                log_dir=report_root,
            )
        )
        validation = json.loads(validation_path.read_text(encoding="utf-8"))
        release_path = seed / "release_manifest.json"
        release = json.loads(release_path.read_text(encoding="utf-8"))
        release["status"] = "published-local"
        release["publishedAt"] = datetime.now(timezone.utc).isoformat()
        release["validation"] = validation
        write_json(release_path, release)

        copied_files = copy_validated_seed(seed, asset_output)
        config_path = activate_config(root, args.season, release)
        steps.append(
            {
                "name": "activate_validated_assets",
                "returnCode": 0,
                "copiedFiles": copied_files,
                "config": str(config_path),
                "release": str(release_path),
            }
        )

        if not args.skip_backend_smoke:
            steps.append(
                run_step(
                    "backend_compile",
                    [python, "-m", "compileall", "-q", "backend/app"],
                    root=root,
                    log_dir=report_root,
                )
            )
            steps.append(smoke_backend(root, report_root, python))

        if not args.skip_flutter:
            if shutil.which("flutter") is None:
                raise RuntimeError("Flutter is not available on PATH. Use --skip-flutter only when intentionally separating validation.")
            steps.append(run_step("flutter_pub_get", ["flutter", "pub", "get"], root=root, log_dir=report_root))
            steps.append(run_step("flutter_analyze", ["flutter", "analyze"], root=root, log_dir=report_root))
            steps.append(run_step("flutter_test", ["flutter", "test"], root=root, log_dir=report_root))
            steps.append(
                run_step(
                    "flutter_build_web",
                    ["flutter", "build", "web", "--release"],
                    root=root,
                    log_dir=report_root,
                )
            )

        if not args.skip_backend_registration:
            report["backendRegistration"] = register_release(args.backend_url, release, validation)

        report["status"] = "pass"
        report["finishedAt"] = datetime.now(timezone.utc).isoformat()
        report["activeRelease"] = release
        report["validation"] = validation
        write_json(report_path, report)
        print(json.dumps({"status": "pass", "report": str(report_path)}, indent=2))
        return 0
    except Exception as error:
        report["status"] = "fail"
        report["finishedAt"] = datetime.now(timezone.utc).isoformat()
        report["error"] = str(error)
        write_json(report_path, report)
        print(json.dumps({"status": "fail", "report": str(report_path), "error": str(error)}, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
