from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlsplit

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.nba_com_stats_registry import surface_for_referer  # noqa: E402

SENSITIVE_TOKENS = ("authorization", "cookie", "token", "secret", "session", "key")
NBA_HOST_SUFFIX = ".nba.com"


def _is_sensitive(name: str) -> bool:
    lowered = name.strip().lower()
    return any(token in lowered for token in SENSITIVE_TOKENS)


def _header_map(headers: list[dict[str, Any]] | None) -> dict[str, str]:
    result: dict[str, str] = {}
    for header in headers or []:
        name = str(header.get("name") or "").strip()
        if not name or _is_sensitive(name):
            continue
        lowered = name.lower()
        if lowered in {"accept", "content-type", "origin", "referer", "user-agent"}:
            result[lowered] = str(header.get("value") or "")
    return result


def _safe_query(url: str) -> dict[str, list[str]]:
    values: dict[str, list[str]] = defaultdict(list)
    for name, value in parse_qsl(urlsplit(url).query, keep_blank_values=True):
        if _is_sensitive(name):
            continue
        if value not in values[name] and len(values[name]) < 25:
            values[name].append(value)
    return dict(values)


def _is_candidate(entry: dict[str, Any]) -> bool:
    request = entry.get("request") or {}
    url = str(request.get("url") or "")
    if not url:
        return False
    parsed = urlsplit(url)
    host = parsed.hostname or ""
    if host != "nba.com" and not host.endswith(NBA_HOST_SUFFIX):
        return False
    resource_type = str(entry.get("_resourceType") or "").lower()
    if resource_type in {"xhr", "fetch"}:
        return "/stats" in parsed.path or "stats" in host
    return "stats" in host and "/stats" in parsed.path


def inventory_har(payload: dict[str, Any]) -> dict[str, Any]:
    entries = ((payload.get("log") or {}).get("entries") or [])
    grouped: dict[tuple[str, str, str], dict[str, Any]] = {}

    for entry in entries:
        if not isinstance(entry, dict) or not _is_candidate(entry):
            continue
        request = entry.get("request") or {}
        response = entry.get("response") or {}
        url = str(request.get("url") or "")
        parsed = urlsplit(url)
        method = str(request.get("method") or "GET").upper()
        key = (method, parsed.hostname or "", parsed.path)
        request_headers = _header_map(request.get("headers"))
        referer = request_headers.get("referer")
        surface = surface_for_referer(referer)

        row = grouped.setdefault(
            key,
            {
                "method": method,
                "host": parsed.hostname,
                "path": parsed.path,
                "surface_keys": set(),
                "referers": set(),
                "query_parameters": defaultdict(list),
                "statuses": set(),
                "mime_types": set(),
                "observations": 0,
            },
        )
        row["observations"] += 1
        if surface:
            row["surface_keys"].add(surface.key)
        if referer:
            row["referers"].add(referer.split("?", 1)[0])
        for name, observed_values in _safe_query(url).items():
            values = row["query_parameters"][name]
            for value in observed_values:
                if value not in values and len(values) < 25:
                    values.append(value)
        status = response.get("status")
        if isinstance(status, int):
            row["statuses"].add(status)
        mime = str(((response.get("content") or {}).get("mimeType") or "")).strip()
        if mime:
            row["mime_types"].add(mime)

    endpoints: list[dict[str, Any]] = []
    for row in grouped.values():
        endpoints.append(
            {
                "method": row["method"],
                "host": row["host"],
                "path": row["path"],
                "surface_keys": sorted(row["surface_keys"]),
                "referers": sorted(row["referers"]),
                "query_parameters": {name: values for name, values in sorted(row["query_parameters"].items())},
                "statuses": sorted(row["statuses"]),
                "mime_types": sorted(row["mime_types"]),
                "observations": row["observations"],
            }
        )
    endpoints.sort(key=lambda row: (str(row["host"]), str(row["path"]), str(row["method"])))
    return {
        "contract": "sports-terminal-nba-com-har-inventory-v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "endpoint_count": len(endpoints),
        "endpoints": endpoints,
        "privacy": {
            "cookies_persisted": False,
            "authorization_headers_persisted": False,
            "sensitive_query_parameters_persisted": False,
        },
    }


def _markdown(inventory: dict[str, Any]) -> str:
    lines = [
        "# NBA.com Stats HAR Endpoint Inventory",
        "",
        "Generated from a local browser HAR. Sensitive request headers and token-like query parameters are intentionally omitted.",
        "",
        "| Method | Host | Path | Surfaces | Parameters | Statuses | Observations |",
        "|---|---|---|---|---|---|---|",
    ]
    for endpoint in inventory.get("endpoints", []):
        params = ", ".join(endpoint.get("query_parameters", {}).keys())
        surfaces = ", ".join(endpoint.get("surface_keys", []))
        statuses = ", ".join(str(value) for value in endpoint.get("statuses", []))
        lines.append(
            f"| {endpoint.get('method', '')} | {endpoint.get('host', '')} | `{endpoint.get('path', '')}` | {surfaces} | {params} | {statuses} | {endpoint.get('observations', 0)} |"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract an NBA.com Stats endpoint/parameter inventory from a Chrome/Edge HAR without persisting cookies or authorization headers."
    )
    parser.add_argument("har", help="Path to a HAR exported from browser DevTools.")
    parser.add_argument("--output", default="artifacts/nba_com_stats_endpoint_inventory.json")
    parser.add_argument("--markdown-output", default="artifacts/nba_com_stats_endpoint_inventory.md")
    args = parser.parse_args()

    har_path = Path(args.har).expanduser().resolve()
    raw = har_path.read_bytes()
    payload = json.loads(raw.decode("utf-8"))
    inventory = inventory_har(payload)
    inventory["source_har"] = {
        "filename": har_path.name,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "bytes": len(raw),
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    markdown_output = Path(args.markdown_output)
    markdown_output.parent.mkdir(parents=True, exist_ok=True)
    markdown_output.write_text(_markdown(inventory), encoding="utf-8")

    print(f"NBA.com Stats endpoint inventory: {len(inventory['endpoints'])} endpoints")
    print(f"JSON: {output}")
    print(f"Markdown: {markdown_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
