#!/usr/bin/env python3
"""Generate a conservative, evidence-based efficiency audit for this repository.

The script never deletes or edits product files. It inventories the complete checked-out
repository, builds import/reference graphs, profiles assets and dependencies, detects
exact duplicates and tracked build artifacts, and inspects Git history for large blobs.
"""

from __future__ import annotations

import ast
import csv
import hashlib
import json
import os
import re
import subprocess
from collections import Counter, defaultdict, deque
from dataclasses import asdict, dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Iterable

ROOT = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
OUT = ROOT / "audit_output"
OUT.mkdir(exist_ok=True)

TEXT_EXTENSIONS = {
    ".dart", ".py", ".md", ".txt", ".json", ".yaml", ".yml", ".xml", ".html",
    ".css", ".js", ".ts", ".sh", ".gradle", ".properties", ".plist", ".xcconfig",
    ".pbxproj", ".entitlements", ".swift", ".kt", ".java", ".c", ".cc", ".cpp",
    ".h", ".hpp", ".cmake", ".toml", ".lock", ".sql", ".csv", ".gitignore",
}

JUNK_PATTERNS = [
    re.compile(r"(^|/)\.DS_Store$"),
    re.compile(r"(^|/)Thumbs\.db$", re.I),
    re.compile(r"(^|/)(build|coverage|DerivedData|Pods|\.dart_tool|\.pytest_cache|__pycache__)(/|$)"),
    re.compile(r"\.(log|tmp|temp|bak|orig|rej|swp|swo)$", re.I),
    re.compile(r"(^|/)\.flutter-plugins(-dependencies)?$"),
]

VERSIONED_NAME_PATTERN = re.compile(
    r"(?:_v\d+|_fixed|_old|_legacy|_backup|_copy|_new|_final)(?=\.[^.]+$)", re.I
)

DART_DIRECTIVE_RE = re.compile(
    r"^\s*(?:import|export|part)\s+[\"']([^\"']+)[\"']",
    re.MULTILINE,
)
DART_PACKAGE_RE = re.compile(r"package:([^/]+)/")
ASSET_LITERAL_RE = re.compile(r"[\"'](assets/[^\"']+)[\"']")


def run(*args: str, check: bool = True, input_text: str | None = None) -> str:
    completed = subprocess.run(
        list(args),
        cwd=ROOT,
        text=True,
        input=input_text,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and completed.returncode != 0:
        raise RuntimeError(
            f"Command failed ({completed.returncode}): {' '.join(args)}\n{completed.stderr}"
        )
    return completed.stdout


def tracked_paths() -> list[str]:
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return sorted(item.decode("utf-8") for item in raw.split(b"\0") if item)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_probably_text(path: Path) -> bool:
    if path.suffix.lower() in TEXT_EXTENSIONS or path.name in {
        "Dockerfile", "Makefile", "Podfile", "Gemfile", "LICENSE", "README",
    }:
        return True
    try:
        sample = path.read_bytes()[:4096]
    except OSError:
        return False
    return b"\0" not in sample


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return ""


def human_bytes(value: int | float) -> str:
    units = ["B", "KB", "MB", "GB"]
    amount = float(value)
    for unit in units:
        if amount < 1024 or unit == units[-1]:
            return f"{amount:.1f} {unit}"
        amount /= 1024
    return f"{amount:.1f} GB"


@dataclass(frozen=True)
class FileRecord:
    path: str
    size_bytes: int
    extension: str
    top_level: str
    sha256: str
    is_text: bool


def inventory(paths: Iterable[str]) -> list[FileRecord]:
    records: list[FileRecord] = []
    for relative in paths:
        absolute = ROOT / relative
        if not absolute.is_file():
            continue
        records.append(
            FileRecord(
                path=relative,
                size_bytes=absolute.stat().st_size,
                extension=absolute.suffix.lower() or "[none]",
                top_level=PurePosixPath(relative).parts[0],
                sha256=sha256(absolute),
                is_text=is_probably_text(absolute),
            )
        )
    return records


def resolve_dart_uri(source: str, uri: str, package_name: str) -> str | None:
    if uri.startswith("dart:"):
        return None
    if uri.startswith("package:"):
        prefix = f"package:{package_name}/"
        if not uri.startswith(prefix):
            return None
        candidate = PurePosixPath("lib") / uri[len(prefix):]
    else:
        source_parent = PurePosixPath(source).parent
        candidate = source_parent / uri
    normalized = os.path.normpath(candidate.as_posix()).replace(os.sep, "/")
    if normalized.startswith("../"):
        return None
    return normalized


def parse_pubspec() -> tuple[str, dict[str, list[str]], list[str]]:
    pubspec = read_text(ROOT / "pubspec.yaml")
    package_match = re.search(r"^name:\s*([^\s#]+)", pubspec, re.MULTILINE)
    package_name = package_match.group(1) if package_match else "sports_terminal"

    dependencies: dict[str, list[str]] = {"dependencies": [], "dev_dependencies": []}
    section: str | None = None
    in_assets = False
    assets: list[str] = []
    for line in pubspec.splitlines():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*$", line):
            key = line.split(":", 1)[0]
            section = key if key in dependencies else None
            in_assets = False
            continue
        if re.match(r"^\s{2}assets:\s*$", line):
            in_assets = True
            section = None
            continue
        if in_assets:
            asset_match = re.match(r"^\s{4}-\s+(.+?)\s*$", line)
            if asset_match:
                assets.append(asset_match.group(1).strip("'\""))
                continue
            if line.strip() and not line.startswith("    "):
                in_assets = False
        if section:
            dep_match = re.match(r"^\s{2}([A-Za-z0-9_\-]+):", line)
            if dep_match:
                dependencies[section].append(dep_match.group(1))
    return package_name, dependencies, assets


def dart_graph(paths: list[str], package_name: str) -> dict[str, Any]:
    dart_files = {path for path in paths if path.endswith(".dart")}
    edges: dict[str, set[str]] = {path: set() for path in dart_files}
    external_imports: Counter[str] = Counter()
    unresolved_local: list[dict[str, str]] = []

    for source in sorted(dart_files):
        text = read_text(ROOT / source)
        for uri in DART_DIRECTIVE_RE.findall(text):
            package_match = DART_PACKAGE_RE.match(uri)
            if package_match and package_match.group(1) != package_name:
                external_imports[package_match.group(1)] += 1
            target = resolve_dart_uri(source, uri, package_name)
            if target is None:
                continue
            if target in dart_files:
                edges[source].add(target)
            else:
                unresolved_local.append({"source": source, "uri": uri, "resolved": target})

    reverse: dict[str, set[str]] = {path: set() for path in dart_files}
    for source, targets in edges.items():
        for target in targets:
            reverse[target].add(source)

    def reachable(roots: Iterable[str]) -> set[str]:
        seen: set[str] = set()
        queue = deque(root for root in roots if root in dart_files)
        while queue:
            node = queue.popleft()
            if node in seen:
                continue
            seen.add(node)
            queue.extend(edges.get(node, ()))
        return seen

    runtime_roots = ["lib/main.dart"]
    test_roots = [path for path in dart_files if path.startswith("test/")]
    tool_roots = [
        path for path in dart_files if path.startswith(("tool/", "bin/", "integration_test/"))
    ]
    runtime = reachable(runtime_roots)
    tests = reachable(test_roots)
    tools = reachable(tool_roots)
    lib_files = {path for path in dart_files if path.startswith("lib/")}
    unreferenced = sorted(lib_files - runtime - tests - tools)
    test_only = sorted((lib_files & tests) - runtime)
    tool_only = sorted((lib_files & tools) - runtime - tests)

    shims: list[dict[str, Any]] = []
    for path in sorted(lib_files):
        text = read_text(ROOT / path)
        meaningful = [
            line.strip()
            for line in text.splitlines()
            if line.strip() and not line.strip().startswith("//")
        ]
        directives = DART_DIRECTIVE_RE.findall(text)
        if len(meaningful) <= 3 and len(directives) == 1 and meaningful[0].startswith("export "):
            shims.append(
                {
                    "path": path,
                    "export_target": directives[0],
                    "reverse_reference_count": len(reverse[path]),
                }
            )

    return {
        "dart_file_count": len(dart_files),
        "lib_file_count": len(lib_files),
        "runtime_reachable": sorted(runtime & lib_files),
        "test_only": test_only,
        "tool_only": tool_only,
        "unreferenced_lib": unreferenced,
        "unresolved_local_directives": unresolved_local,
        "external_package_import_counts": dict(sorted(external_imports.items())),
        "export_shims": shims,
        "edges": {key: sorted(value) for key, value in sorted(edges.items())},
        "reverse_reference_counts": {
            key: len(value) for key, value in sorted(reverse.items())
        },
    }


def asset_audit(paths: list[str], declared_assets: list[str]) -> dict[str, Any]:
    asset_files = sorted(path for path in paths if path.startswith("assets/") and (ROOT / path).is_file())

    def covered(path: str) -> bool:
        for declaration in declared_assets:
            if declaration.endswith("/") and path.startswith(declaration):
                return True
            if path == declaration:
                return True
        return False

    missing_declarations = [item for item in declared_assets if not (ROOT / item).exists()]
    undeclared = [path for path in asset_files if not covered(path)]

    literal_references: Counter[str] = Counter()
    for path in paths:
        absolute = ROOT / path
        if not absolute.is_file() or not is_probably_text(absolute):
            continue
        for literal in ASSET_LITERAL_RE.findall(read_text(absolute)):
            literal_references[literal] += 1

    json_profiles: list[dict[str, Any]] = []
    for path in asset_files:
        if not path.endswith(".json"):
            continue
        absolute = ROOT / path
        profile: dict[str, Any] = {
            "path": path,
            "size_bytes": absolute.stat().st_size,
            "top_level_type": "invalid",
            "row_count": None,
            "sample_keys": [],
        }
        try:
            data = json.loads(read_text(absolute))
            if isinstance(data, list):
                profile["top_level_type"] = "list"
                profile["row_count"] = len(data)
                if data and isinstance(data[0], dict):
                    profile["sample_keys"] = sorted(data[0].keys())[:30]
            elif isinstance(data, dict):
                profile["top_level_type"] = "object"
                profile["row_count"] = len(data)
                profile["sample_keys"] = sorted(data.keys())[:30]
            else:
                profile["top_level_type"] = type(data).__name__
        except (json.JSONDecodeError, OSError):
            pass
        json_profiles.append(profile)

    return {
        "declared_entries": declared_assets,
        "asset_file_count": len(asset_files),
        "asset_total_bytes": sum((ROOT / path).stat().st_size for path in asset_files),
        "undeclared_asset_files": undeclared,
        "missing_declared_entries": missing_declarations,
        "literal_reference_counts": dict(sorted(literal_references.items())),
        "json_profiles": json_profiles,
    }


def dependency_audit(
    dependencies: dict[str, list[str]], dart_info: dict[str, Any]
) -> dict[str, Any]:
    imported = set(dart_info["external_package_import_counts"])
    ignored = {"flutter"}
    runtime_declared = set(dependencies["dependencies"]) - ignored
    dev_declared = set(dependencies["dev_dependencies"]) - {"flutter_test"}
    return {
        "declared": dependencies,
        "imported_packages": sorted(imported),
        "possibly_unused_runtime_dependencies": sorted(runtime_declared - imported),
        "possibly_unused_dev_dependencies": sorted(dev_declared - imported),
        "imported_but_undeclared": sorted(imported - runtime_declared - dev_declared - {"flutter_test"}),
    }


def python_audit(paths: list[str]) -> dict[str, Any]:
    py_files = sorted(path for path in paths if path.endswith(".py"))
    syntax_errors: list[dict[str, str]] = []
    imports: dict[str, list[str]] = {}
    for path in py_files:
        text = read_text(ROOT / path)
        try:
            tree = ast.parse(text, filename=path)
        except SyntaxError as exc:
            syntax_errors.append({"path": path, "error": str(exc)})
            continue
        names: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names.update(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom):
                if node.module:
                    names.add(node.module)
        imports[path] = sorted(names)
    return {
        "python_file_count": len(py_files),
        "files": py_files,
        "syntax_errors": syntax_errors,
        "imports": imports,
    }


def historical_blobs() -> list[dict[str, Any]]:
    object_lines = run("git", "rev-list", "--objects", "--all").splitlines()
    if not object_lines:
        return []
    object_input = "\n".join(line.split(" ", 1)[0] for line in object_lines) + "\n"
    metadata = run(
        "git",
        "cat-file",
        "--batch-check=%(objecttype) %(objectname) %(objectsize)",
        input_text=object_input,
    ).splitlines()
    path_by_sha: dict[str, str] = {}
    for line in object_lines:
        parts = line.split(" ", 1)
        if len(parts) == 2:
            path_by_sha.setdefault(parts[0], parts[1])
    blobs: list[dict[str, Any]] = []
    for line in metadata:
        parts = line.split()
        if len(parts) != 3 or parts[0] != "blob":
            continue
        sha, raw_size = parts[1], parts[2]
        blobs.append(
            {"sha": sha, "size_bytes": int(raw_size), "path": path_by_sha.get(sha, "")}
        )
    blobs.sort(key=lambda item: item["size_bytes"], reverse=True)
    return blobs[:200]


def workflow_audit(paths: list[str]) -> dict[str, Any]:
    workflows = sorted(
        path for path in paths if path.startswith(".github/workflows/") and path.endswith((".yml", ".yaml"))
    )
    details: list[dict[str, Any]] = []
    for path in workflows:
        text = read_text(ROOT / path)
        run_lines = [
            match.group(1).strip()
            for match in re.finditer(r"^\s*run:\s*(.+)$", text, re.MULTILINE)
        ]
        uses = [
            match.group(1).strip()
            for match in re.finditer(r"^\s*uses:\s*(.+)$", text, re.MULTILINE)
        ]
        details.append(
            {
                "path": path,
                "size_bytes": (ROOT / path).stat().st_size,
                "run_commands": run_lines,
                "actions": uses,
            }
        )
    return {"workflow_count": len(workflows), "workflows": details}


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({name: row.get(name, "") for name in fieldnames})


def build_report() -> dict[str, Any]:
    paths = tracked_paths()
    records = inventory(paths)
    package_name, dependencies, declared_assets = parse_pubspec()
    dart_info = dart_graph(paths, package_name)
    assets = asset_audit(paths, declared_assets)
    deps = dependency_audit(dependencies, dart_info)
    python_info = python_audit(paths)
    workflows = workflow_audit(paths)

    duplicates: list[dict[str, Any]] = []
    by_hash: dict[tuple[str, int], list[str]] = defaultdict(list)
    for record in records:
        if record.size_bytes > 0:
            by_hash[(record.sha256, record.size_bytes)].append(record.path)
    for (digest, size), group in by_hash.items():
        if len(group) > 1:
            duplicates.append(
                {
                    "sha256": digest,
                    "size_bytes": size,
                    "wasted_if_one_copy_bytes": size * (len(group) - 1),
                    "paths": sorted(group),
                }
            )
    duplicates.sort(key=lambda item: item["wasted_if_one_copy_bytes"], reverse=True)

    top_level: dict[str, dict[str, int]] = defaultdict(lambda: {"file_count": 0, "size_bytes": 0})
    extension_counts: dict[str, dict[str, int]] = defaultdict(lambda: {"file_count": 0, "size_bytes": 0})
    for record in records:
        top_level[record.top_level]["file_count"] += 1
        top_level[record.top_level]["size_bytes"] += record.size_bytes
        extension_counts[record.extension]["file_count"] += 1
        extension_counts[record.extension]["size_bytes"] += record.size_bytes

    tracked_junk = sorted(
        record.path
        for record in records
        if any(pattern.search(record.path) for pattern in JUNK_PATTERNS)
    )
    versioned_files = sorted(record.path for record in records if VERSIONED_NAME_PATTERN.search(record.path))

    build_web = ROOT / "build" / "web"
    web_build_files: list[dict[str, Any]] = []
    if build_web.exists():
        for absolute in sorted(path for path in build_web.rglob("*") if path.is_file()):
            web_build_files.append(
                {
                    "path": absolute.relative_to(ROOT).as_posix(),
                    "size_bytes": absolute.stat().st_size,
                }
            )
        web_build_files.sort(key=lambda item: item["size_bytes"], reverse=True)

    branch_lines = run(
        "git",
        "for-each-ref",
        "--format=%(refname:short)|%(objectname)|%(committerdate:iso8601)|%(authorname)",
        "refs/remotes",
        check=False,
    ).splitlines()
    branches = []
    for line in branch_lines:
        parts = line.split("|", 3)
        if len(parts) == 4:
            branches.append(
                {"name": parts[0], "sha": parts[1], "last_commit": parts[2], "author": parts[3]}
            )

    report = {
        "repository": {
            "package_name": package_name,
            "head_sha": run("git", "rev-parse", "HEAD").strip(),
            "tracked_file_count": len(records),
            "tracked_size_bytes": sum(record.size_bytes for record in records),
            "git_count_objects": run("git", "count-objects", "-vH", check=False).strip(),
            "remote_branches": branches,
        },
        "top_level_directories": dict(sorted(top_level.items())),
        "extensions": dict(sorted(extension_counts.items())),
        "largest_current_files": [asdict(item) for item in sorted(records, key=lambda r: r.size_bytes, reverse=True)[:200]],
        "exact_duplicate_groups": duplicates,
        "tracked_junk": tracked_junk,
        "versioned_or_backup_named_files": versioned_files,
        "dart": dart_info,
        "dependencies": deps,
        "assets": assets,
        "python": python_info,
        "workflows": workflows,
        "historical_largest_blobs": historical_blobs(),
        "web_release_build": {
            "file_count": len(web_build_files),
            "total_bytes": sum(item["size_bytes"] for item in web_build_files),
            "largest_files": web_build_files[:100],
        },
    }
    return report


def markdown(report: dict[str, Any]) -> str:
    repo = report["repository"]
    dart = report["dart"]
    deps = report["dependencies"]
    assets = report["assets"]
    duplicates = report["exact_duplicate_groups"]
    web = report["web_release_build"]

    lines = [
        "# Sports Terminal repository efficiency audit",
        "",
        "## Repository footprint",
        "",
        f"- Tracked files: **{repo['tracked_file_count']:,}**",
        f"- Current tracked-tree size: **{human_bytes(repo['tracked_size_bytes'])}**",
        f"- Dart files: **{dart['dart_file_count']:,}** ({dart['lib_file_count']:,} under `lib/`)",
        f"- Asset files: **{assets['asset_file_count']:,}** totaling **{human_bytes(assets['asset_total_bytes'])}**",
        f"- Release web bundle: **{human_bytes(web['total_bytes'])}** across **{web['file_count']:,}** files",
        "",
        "## High-confidence cleanup signals",
        "",
        f"- Tracked generated/junk files: **{len(report['tracked_junk'])}**",
        f"- Exact duplicate groups: **{len(duplicates)}**",
        f"- Unreferenced `lib/` Dart files: **{len(dart['unreferenced_lib'])}**",
        f"- Test-only `lib/` Dart files: **{len(dart['test_only'])}**",
        f"- Versioned/backup-style filenames: **{len(report['versioned_or_backup_named_files'])}**",
        f"- Possibly unused runtime dependencies: **{len(deps['possibly_unused_runtime_dependencies'])}**",
        f"- Undeclared asset files: **{len(assets['undeclared_asset_files'])}**",
        f"- Missing declared asset entries: **{len(assets['missing_declared_entries'])}**",
        "",
    ]

    def section(title: str, values: Iterable[str], limit: int = 100) -> None:
        items = list(values)
        lines.extend([f"## {title}", ""])
        if not items:
            lines.append("None detected.")
        else:
            for item in items[:limit]:
                lines.append(f"- `{item}`")
            if len(items) > limit:
                lines.append(f"- …and {len(items) - limit} more (see JSON/CSV output).")
        lines.append("")

    section("Tracked generated or junk paths", report["tracked_junk"])
    section("Unreferenced lib Dart files", dart["unreferenced_lib"])
    section("Test-only lib Dart files", dart["test_only"])
    section("Versioned or backup-style filenames", report["versioned_or_backup_named_files"])
    section("Possibly unused runtime dependencies", deps["possibly_unused_runtime_dependencies"])
    section("Possibly unused dev dependencies", deps["possibly_unused_dev_dependencies"])
    section("Undeclared asset files", assets["undeclared_asset_files"])
    section("Missing declared asset entries", assets["missing_declared_entries"])

    lines.extend(["## Largest exact duplicate groups", ""])
    if not duplicates:
        lines.append("None detected.")
    else:
        for group in duplicates[:30]:
            lines.append(
                f"- **{human_bytes(group['wasted_if_one_copy_bytes'])} potentially duplicated**: "
                + ", ".join(f"`{path}`" for path in group["paths"])
            )
    lines.append("")

    lines.extend(["## Largest current tracked files", ""])
    for item in report["largest_current_files"][:30]:
        lines.append(f"- **{human_bytes(item['size_bytes'])}** — `{item['path']}`")
    lines.append("")

    lines.extend(["## Largest historical blobs", ""])
    for item in report["historical_largest_blobs"][:30]:
        label = item["path"] or item["sha"]
        lines.append(f"- **{human_bytes(item['size_bytes'])}** — `{label}`")
    lines.append("")

    lines.extend(["## Top-level footprint", "", "| Path | Files | Size |", "|---|---:|---:|"])
    for name, values in sorted(
        report["top_level_directories"].items(),
        key=lambda item: item[1]["size_bytes"],
        reverse=True,
    ):
        lines.append(
            f"| `{name}` | {values['file_count']:,} | {human_bytes(values['size_bytes'])} |"
        )
    lines.append("")

    lines.extend([
        "## Interpretation guardrails",
        "",
        "- An unreferenced Dart file is a cleanup candidate, not automatic proof of waste; it may be a planned entrypoint or loaded dynamically.",
        "- Exact duplicate files may be intentional platform scaffolding, fixtures, icons, or independently versioned datasets.",
        "- A dependency is marked possibly unused only when no direct Dart package import was found; tooling or native-platform usage still requires review.",
        "- Asset literal-reference counts are incomplete for dynamically constructed paths. Pubspec declaration coverage is the stronger signal.",
        "- Historical blobs remain in Git history even after current-tree deletion; reclaiming that storage requires a deliberate history rewrite.",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    report = build_report()
    (OUT / "repository_audit.json").write_text(
        json.dumps(report, indent=2, sort_keys=True), encoding="utf-8"
    )
    (OUT / "repository_audit.md").write_text(markdown(report), encoding="utf-8")

    inventory_rows = report["largest_current_files"]
    # Recreate the full inventory rather than only the largest-file display slice.
    full_records = [asdict(item) for item in inventory(tracked_paths())]
    write_csv(
        OUT / "file_inventory.csv",
        full_records,
        ["path", "size_bytes", "extension", "top_level", "sha256", "is_text"],
    )

    edge_rows: list[dict[str, str]] = []
    for source, targets in report["dart"]["edges"].items():
        if not targets:
            edge_rows.append({"source": source, "target": ""})
        else:
            edge_rows.extend({"source": source, "target": target} for target in targets)
    write_csv(OUT / "dart_import_graph.csv", edge_rows, ["source", "target"])
    write_csv(
        OUT / "largest_historical_blobs.csv",
        report["historical_largest_blobs"],
        ["sha", "size_bytes", "path"],
    )

    print((OUT / "repository_audit.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
