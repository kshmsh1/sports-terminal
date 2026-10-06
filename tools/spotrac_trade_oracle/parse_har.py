#!/usr/bin/env python3
"""Extract sanitized Spotrac Trade Machine states from a browser HAR.

This tool is intentionally offline. It never contacts Spotrac and never replays
CSRF / Turnstile credentials. Raw HARs can contain short-lived security tokens,
so keep them local and commit only the normalized JSON output after review.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

RUN_RE = re.compile(
    r"/nba/trade-machine/run/_/year/(?P<year>\d+)"
    r"(?P<teams>(?:/team\d+/[a-z0-9-]+)+)$",
    re.I,
)
TEAM_RE = re.compile(r"/team(?P<slot>\d+)/(?P<slug>[a-z0-9-]+)", re.I)
SELECTED_RE = re.compile(
    r"^selected_(?P<kind>players|draft|draft_players|cash)"
    r"\[(?P<origin>\d+)\]\[\]$"
)
HOLD_RE = re.compile(
    r"^selected_hold_players\[(?P<origin>\d+)\]\[(?P<asset>\d+)\]$"
)


@dataclass(frozen=True)
class RoutedAsset:
    kind: str
    origin_team_id: str
    asset_id: str
    destination_team_id: str | None
    raw_value: str


@dataclass(frozen=True)
class TradeState:
    sequence: int
    started_at: str | None
    operating_year: int
    teams: list[dict[str, Any]]
    assets: list[RoutedAsset]
    trade_reviewed: bool
    trade_restore_incomplete: bool
    http_status: int | None
    response_mime_type: str | None
    response_text: str | None


def _params(entry: dict[str, Any]) -> list[dict[str, str]]:
    post = entry.get("request", {}).get("postData", {})
    params = post.get("params")
    if isinstance(params, list):
        return [
            {"name": str(item.get("name", "")), "value": str(item.get("value", ""))}
            for item in params
        ]

    # Fallback for HAR exporters that preserve only multipart text.
    text = post.get("text")
    if not isinstance(text, str):
        return []
    result: list[dict[str, str]] = []
    for block in re.split(r"------WebKitFormBoundary[^\r\n]+\r\n", text):
        name_match = re.search(r'name="([^"]+)"', block)
        if not name_match:
            continue
        value_match = re.search(r"\r\n\r\n(.*?)\r\n?$", block, re.S)
        result.append(
            {
                "name": name_match.group(1),
                "value": value_match.group(1) if value_match else "",
            }
        )
    return result


def _parse_asset(name: str, value: str) -> RoutedAsset | None:
    value = value.strip()
    selected = SELECTED_RE.match(name)
    if selected:
        if not value:
            return None
        asset_id, sep, destination = value.partition(":")
        return RoutedAsset(
            kind=selected.group("kind"),
            origin_team_id=selected.group("origin"),
            asset_id=asset_id,
            destination_team_id=destination if sep and destination else None,
            raw_value=value,
        )

    hold = HOLD_RE.match(name)
    if hold and value:
        return RoutedAsset(
            kind="hold_players",
            origin_team_id=hold.group("origin"),
            asset_id=hold.group("asset"),
            destination_team_id=value or None,
            raw_value=value,
        )
    return None


def extract_states(har: dict[str, Any], include_response_text: bool = True) -> list[TradeState]:
    states: list[TradeState] = []
    entries = har.get("log", {}).get("entries", [])
    for entry in entries:
        request = entry.get("request", {})
        if str(request.get("method", "")).upper() != "POST":
            continue
        url = str(request.get("url", ""))
        path = urlparse(url).path
        match = RUN_RE.search(path)
        if not match:
            continue

        teams = [
            {"slot": int(item.group("slot")), "slug": item.group("slug").lower()}
            for item in TEAM_RE.finditer(match.group("teams"))
        ]
        params = _params(entry)
        by_name: dict[str, list[str]] = {}
        assets: list[RoutedAsset] = []
        for item in params:
            name, value = item["name"], item["value"]
            by_name.setdefault(name, []).append(value)
            asset = _parse_asset(name, value)
            if asset is not None:
                assets.append(asset)

        response = entry.get("response", {})
        content = response.get("content", {}) if isinstance(response, dict) else {}
        response_text = content.get("text") if include_response_text else None
        if not isinstance(response_text, str):
            response_text = None

        states.append(
            TradeState(
                sequence=len(states),
                started_at=entry.get("startedDateTime"),
                operating_year=int(match.group("year")),
                teams=teams,
                assets=assets,
                trade_reviewed=(by_name.get("trade_reviewed", ["0"])[-1] == "1"),
                trade_restore_incomplete=(
                    by_name.get("trade_restore_incomplete", ["0"])[-1] == "1"
                ),
                http_status=response.get("status") if isinstance(response, dict) else None,
                response_mime_type=content.get("mimeType") if isinstance(content, dict) else None,
                response_text=response_text,
            )
        )
    return states


def to_jsonable(states: list[TradeState]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "source": "spotrac_trade_machine_har",
        "security_note": (
            "Sanitized offline derivative. CSRF, Turnstile, cookies and request headers "
            "are intentionally excluded."
        ),
        "state_count": len(states),
        "states": [
            {
                **{k: v for k, v in asdict(state).items() if k != "assets"},
                "assets": [asdict(asset) for asset in state.assets],
            }
            for state in states
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("har", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument(
        "--omit-response-text",
        action="store_true",
        help="Do not preserve response bodies even when the HAR contains them.",
    )
    args = parser.parse_args()

    raw = json.loads(args.har.read_text(encoding="utf-8"))
    states = extract_states(raw, include_response_text=not args.omit_response_text)
    payload = to_jsonable(states)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    print(f"wrote {len(states)} trade-machine states to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
