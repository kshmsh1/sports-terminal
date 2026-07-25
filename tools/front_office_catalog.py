from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))


SECTION_TYPES = {
    "contracts": "contract",
    "team_positions": "team_position",
    "draft_assets": "draft_asset",
    "ledger": "ledger",
}
ENDPOINTS = {
    "contracts": "/v2/front-office/contracts/{id}",
    "team_positions": "/v2/front-office/team-positions/{id}",
    "draft_assets": "/v2/front-office/draft-assets/{id}",
    "ledger": "/v2/front-office/ledger/{id}",
}


def load_catalog(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise SystemExit(f"Catalog does not exist: {path}") from error
    except json.JSONDecodeError as error:
        raise SystemExit(
            f"Catalog JSON is invalid at line {error.lineno}, column {error.colno}: {error.msg}"
        ) from error
    if not isinstance(value, dict):
        raise SystemExit("Catalog root must be a JSON object")
    return value


def validate_catalog(
    catalog: dict[str, Any],
    *,
    require_verified: bool = False,
    minimum_contracts: int = 0,
    minimum_team_positions: int = 0,
    minimum_draft_assets: int = 0,
) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="sports-terminal-catalog-") as temp_dir:
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(
            Path(temp_dir) / "catalog_validation.sqlite"
        )
        from app import main_launch as _main_launch  # noqa: F401
        from app.front_office_api import _parse, _validate

        season = str(catalog.get("season") or "")
        generated_at = str(catalog.get("generated_at") or "")
        blocking: list[str] = []
        warnings: list[str] = []
        if not season:
            blocking.append("Catalog season is missing.")
        if not generated_at:
            blocking.append("Catalog generated_at timestamp is missing.")

        ids: dict[str, str] = {}
        section_reports: dict[str, Any] = {}
        verified_counts: dict[str, int] = {}
        records_by_section: dict[str, list[dict[str, Any]]] = {}

        for section, record_type in SECTION_TYPES.items():
            raw_rows = catalog.get(section, [])
            if not isinstance(raw_rows, list):
                blocking.append(f"{section} must be an array.")
                raw_rows = []
            rows = [row for row in raw_rows if isinstance(row, dict)]
            records_by_section[section] = rows
            item_reports: list[dict[str, Any]] = []
            verified = 0
            for index, row in enumerate(rows):
                record_id = str(row.get("id") or "").strip()
                item_errors: list[str] = []
                item_warnings: list[str] = []
                if not record_id:
                    item_errors.append("Record ID is missing.")
                    record_id = f"{section}[{index}]"
                existing_type = ids.get(record_id)
                if existing_type is not None:
                    item_errors.append(
                        f"Record ID duplicates {existing_type}: {record_id}"
                    )
                else:
                    ids[record_id] = section
                source_status = str(row.get("source_status") or "modeled")
                if source_status == "verified":
                    verified += 1
                if require_verified and source_status != "verified":
                    item_errors.append(
                        "Production catalog requires source_status=verified."
                    )
                try:
                    parsed = _parse(record_type, row)
                    validation = _validate(record_type, parsed)
                    item_errors.extend(
                        str(value) for value in validation.get("errors", [])
                    )
                    item_warnings.extend(
                        str(value) for value in validation.get("warnings", [])
                    )
                except Exception as error:
                    item_errors.append(str(error))
                item_reports.append(
                    {
                        "id": record_id,
                        "source_status": source_status,
                        "status": "fail"
                        if item_errors
                        else "warning"
                        if item_warnings
                        else "pass",
                        "errors": item_errors,
                        "warnings": item_warnings,
                    }
                )
                blocking.extend(
                    f"{section}:{record_id}: {message}"
                    for message in item_errors
                )
                warnings.extend(
                    f"{section}:{record_id}: {message}"
                    for message in item_warnings
                )
            verified_counts[section] = verified
            section_reports[section] = {
                "count": len(rows),
                "verified": verified,
                "failed": sum(1 for item in item_reports if item["status"] == "fail"),
                "warnings": sum(
                    1 for item in item_reports if item["status"] == "warning"
                ),
                "items": item_reports,
            }

        contract_ids = {
            str(row.get("id")) for row in records_by_section["contracts"]
        }
        draft_asset_ids = {
            str(row.get("id")) for row in records_by_section["draft_assets"]
        }
        for row in records_by_section["ledger"]:
            record_id = str(row.get("id") or "unknown")
            missing_contracts = [
                value
                for value in row.get("contract_ids", [])
                if str(value) not in contract_ids
            ]
            missing_assets = [
                value
                for value in row.get("draft_asset_ids", [])
                if str(value) not in draft_asset_ids
            ]
            if missing_contracts:
                blocking.append(
                    f"ledger:{record_id}: missing contract references {missing_contracts}"
                )
            if missing_assets:
                blocking.append(
                    f"ledger:{record_id}: missing draft asset references {missing_assets}"
                )

        contract_players = {
            str(row.get("player_id"))
            for row in records_by_section["contracts"]
            if row.get("player_id")
        }
        position_teams = {
            str(row.get("team_id")).upper()
            for row in records_by_section["team_positions"]
            if row.get("team_id")
        }
        contract_teams = {
            str(row.get("team_id")).upper()
            for row in records_by_section["contracts"]
            if row.get("team_id")
        }
        missing_positions = sorted(contract_teams - position_teams)
        if missing_positions:
            warnings.append(
                "Contract teams without a team financial position: "
                + ", ".join(missing_positions)
            )

        thresholds = {
            "contracts": minimum_contracts,
            "team_positions": minimum_team_positions,
            "draft_assets": minimum_draft_assets,
        }
        for section, minimum in thresholds.items():
            if len(records_by_section[section]) < minimum:
                blocking.append(
                    f"{section} count {len(records_by_section[section])} is below required minimum {minimum}."
                )

        source_notes = catalog.get("source_notes", [])
        if require_verified and not source_notes:
            warnings.append(
                "Production catalog does not include top-level source_notes."
            )

        return {
            "status": "pass" if not blocking else "fail",
            "season": season,
            "generated_at": generated_at,
            "require_verified": require_verified,
            "counts": {
                section: len(records_by_section[section])
                for section in SECTION_TYPES
            },
            "verified_counts": verified_counts,
            "unique_player_ids": len(contract_players),
            "unique_team_positions": len(position_teams),
            "blocking_failures": blocking,
            "warnings": warnings,
            "sections": section_reports,
        }


def register_catalog(
    catalog: dict[str, Any],
    *,
    backend_url: str,
    token: str,
    actor_user_id: str,
    dry_run: bool,
) -> dict[str, Any]:
    base = backend_url.rstrip("/")
    results: list[dict[str, Any]] = []
    for section, endpoint_template in ENDPOINTS.items():
        rows = catalog.get(section, [])
        if not isinstance(rows, list):
            continue
        for row in rows:
            if not isinstance(row, dict):
                continue
            record_id = str(row.get("id") or "").strip()
            if not record_id:
                results.append(
                    {
                        "section": section,
                        "id": "",
                        "status": "skipped",
                        "error": "missing ID",
                    }
                )
                continue
            if dry_run:
                results.append(
                    {
                        "section": section,
                        "id": record_id,
                        "status": "dry_run",
                    }
                )
                continue
            endpoint = endpoint_template.format(
                id=urllib.parse.quote(record_id, safe="")
            )
            request = urllib.request.Request(
                f"{base}{endpoint}",
                data=json.dumps(
                    {
                        "actor_user_id": actor_user_id,
                        "record_status": "active",
                        "record": row,
                    },
                    separators=(",", ":"),
                ).encode("utf-8"),
                method="PUT",
                headers={
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                    **(
                        {"Authorization": f"Bearer {token}"}
                        if token
                        else {}
                    ),
                },
            )
            try:
                with urllib.request.urlopen(request, timeout=15) as response:
                    payload = json.loads(response.read().decode("utf-8"))
                    results.append(
                        {
                            "section": section,
                            "id": record_id,
                            "status": "registered",
                            "version": payload.get("version"),
                            "validation": payload.get("validation"),
                        }
                    )
            except urllib.error.HTTPError as error:
                detail = error.read().decode("utf-8", errors="replace")
                results.append(
                    {
                        "section": section,
                        "id": record_id,
                        "status": "failed",
                        "http_status": error.code,
                        "error": detail,
                    }
                )
            except Exception as error:
                results.append(
                    {
                        "section": section,
                        "id": record_id,
                        "status": "failed",
                        "error": str(error),
                    }
                )
    failed = [item for item in results if item["status"] == "failed"]
    return {
        "status": "pass" if not failed else "fail",
        "backend_url": base,
        "dry_run": dry_run,
        "registered": sum(
            1 for item in results if item["status"] == "registered"
        ),
        "dry_run_records": sum(
            1 for item in results if item["status"] == "dry_run"
        ),
        "failed": len(failed),
        "results": results,
    }


def write_report(report: dict[str, Any], path: Path | None) -> None:
    encoded = json.dumps(report, indent=2, sort_keys=True)
    print(encoded)
    if path is not None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(encoded + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Validate and optionally register a Sports Terminal front-office "
            "catalog. This command never collects or fabricates source data."
        )
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate")
    validate.add_argument("catalog", type=Path)
    validate.add_argument("--report", type=Path)
    validate.add_argument("--require-verified", action="store_true")
    validate.add_argument("--minimum-contracts", type=int, default=0)
    validate.add_argument("--minimum-team-positions", type=int, default=0)
    validate.add_argument("--minimum-draft-assets", type=int, default=0)

    register = subparsers.add_parser("register")
    register.add_argument("catalog", type=Path)
    register.add_argument("--backend-url", default="http://127.0.0.1:8000")
    register.add_argument("--token", default=os.getenv("SPORTS_TERMINAL_TOKEN", ""))
    register.add_argument("--actor-user-id", required=True)
    register.add_argument("--report", type=Path)
    register.add_argument("--require-verified", action="store_true")
    register.add_argument("--minimum-contracts", type=int, default=0)
    register.add_argument("--minimum-team-positions", type=int, default=0)
    register.add_argument("--minimum-draft-assets", type=int, default=0)
    register.add_argument("--dry-run", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    catalog = load_catalog(args.catalog)
    validation = validate_catalog(
        catalog,
        require_verified=args.require_verified,
        minimum_contracts=args.minimum_contracts,
        minimum_team_positions=args.minimum_team_positions,
        minimum_draft_assets=args.minimum_draft_assets,
    )
    if args.command == "validate":
        write_report(validation, args.report)
        return 0 if validation["status"] == "pass" else 1

    if validation["status"] != "pass":
        report = {
            "status": "fail",
            "stage": "validation",
            "validation": validation,
        }
        write_report(report, args.report)
        return 1
    registration = register_catalog(
        catalog,
        backend_url=args.backend_url,
        token=args.token,
        actor_user_id=args.actor_user_id,
        dry_run=args.dry_run,
    )
    report = {
        "status": registration["status"],
        "validation": validation,
        "registration": registration,
    }
    write_report(report, args.report)
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
