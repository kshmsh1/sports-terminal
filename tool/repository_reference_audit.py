#!/usr/bin/env python3
"""Find tracked operational files that are never referenced by another text file.

This is a conservative signal only: command-line tools can be valid manual entrypoints even
when nothing in the repository calls them. The report therefore records both exact-path and
basename references and never labels a file automatically removable.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
OUT = ROOT / "audit_output"
OUT.mkdir(exist_ok=True)


def tracked_paths() -> list[str]:
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return sorted(item.decode("utf-8") for item in raw.split(b"\0") if item)


def text(path: Path) -> str:
    try:
        raw = path.read_bytes()
        if b"\0" in raw[:4096]:
            return ""
        return raw.decode("utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def main() -> None:
    paths = tracked_paths()
    corpus = {path: text(ROOT / path) for path in paths}
    corpus = {path: value for path, value in corpus.items() if value}

    candidates = [
        path
        for path in paths
        if path.startswith(("tools/", "scripts/", "backend/"))
        and Path(path).suffix.lower() in {".py", ".dart", ".sh", ".sql"}
    ]

    records = []
    for candidate in candidates:
        basename = Path(candidate).name
        exact_sources = []
        basename_sources = []
        for source, body in corpus.items():
            if source == candidate:
                continue
            if candidate in body:
                exact_sources.append(source)
            elif basename in body:
                basename_sources.append(source)
        records.append(
            {
                "path": candidate,
                "size_bytes": (ROOT / candidate).stat().st_size,
                "exact_path_reference_count": len(exact_sources),
                "basename_reference_count": len(basename_sources),
                "exact_path_sources": sorted(exact_sources),
                "basename_sources": sorted(basename_sources),
            }
        )

    records.sort(
        key=lambda item: (
            item["exact_path_reference_count"] + item["basename_reference_count"],
            -item["size_bytes"],
            item["path"],
        )
    )
    (OUT / "operational_reference_scan.json").write_text(
        json.dumps(records, indent=2), encoding="utf-8"
    )

    lines = [
        "# Operational file reference scan",
        "",
        "Files below have no exact-path or basename mention in another tracked text file.",
        "They may still be legitimate manual entrypoints and require purpose review.",
        "",
    ]
    orphaned = [
        item
        for item in records
        if item["exact_path_reference_count"] == 0
        and item["basename_reference_count"] == 0
    ]
    for item in orphaned:
        lines.append(f"- `{item['path']}` ({item['size_bytes']} bytes)")
    lines.extend(["", f"Total candidates scanned: {len(records)}", f"No-reference candidates: {len(orphaned)}", ""])
    (OUT / "operational_reference_scan.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
