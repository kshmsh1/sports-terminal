from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

EXPECTED_DIRECTORIES = ("schedule", "game_details", "pbp", "overrides")

def _count_files(root: Path) -> tuple[int, dict[str, int]]:
    counts: dict[str, int] = {}
    total = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        total += 1
        suffix = path.suffix.lower() or "<none>"
        counts[suffix] = counts.get(suffix, 0) + 1
    return total, dict(sorted(counts.items()))

def _sample_files(root: Path, limit: int = 12) -> list[str]:
    files = [
        str(path.relative_to(root))
        for path in sorted(root.rglob("*"))
        if path.is_file()
    ]
    return files[:limit]

def build_inventory(source: Path) -> dict[str, Any]:
    source = source.expanduser().resolve()
    if not source.is_dir():
        raise FileNotFoundError(f"pbpstats data directory does not exist: {source}")

    directories: dict[str, Any] = {}
    for name in EXPECTED_DIRECTORIES:
        folder = source / name
        total, extensions = _count_files(folder) if folder.is_dir() else (0, {})
        directories[name] = {
            "present": folder.is_dir(),
            "files": total,
            "extensions": extensions,
            "samples": _sample_files(folder) if folder.is_dir() else [],
        }

    all_files, all_extensions = _count_files(source)
    signature = hashlib.sha256(
        json.dumps(
            {
                "directories": {
                    key: {
                        "present": value["present"],
                        "files": value["files"],
                        "extensions": value["extensions"],
                    }
                    for key, value in directories.items()
                },
                "files": all_files,
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()

    return {
        "contract": "sports-terminal-pbpstats-cache-inventory-v1",
        "source": "pbpstats local file cache",
        "source_path": str(source),
        "network_requests_performed": False,
        "runtime_dependency": False,
        "expected_directories": list(EXPECTED_DIRECTORIES),
        "directories": directories,
        "total_files": all_files,
        "extensions": all_extensions,
        "fingerprint": signature,
        "readiness": {
            "schedule": directories["schedule"]["files"] > 0,
            "game_details": directories["game_details"]["files"] > 0,
            "pbp": directories["pbp"]["files"] > 0,
            "overrides_optional": True,
        },
    }

def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Inventory an already-downloaded pbpstats data directory without making "
            "any network requests. The resulting manifest can be placed under "
            "raw/pbpstats for Sports Terminal's static data-foundation catalogue."
        )
    )
    parser.add_argument("source", help="Path to the existing pbpstats data directory.")
    parser.add_argument(
        "--output",
        default="raw/pbpstats/inventory.json",
        help="Inventory JSON to write.",
    )
    args = parser.parse_args()

    inventory = build_inventory(Path(args.source))
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(inventory, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(
        "pbpstats cache inventory: "
        f"{inventory['total_files']} files; "
        f"pbp={inventory['directories']['pbp']['files']}; "
        f"game_details={inventory['directories']['game_details']['files']}; "
        f"schedule={inventory['directories']['schedule']['files']}"
    )
    print(f"Inventory: {output}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
