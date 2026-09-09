#!/usr/bin/env python3
"""Scrape HoopsHype NBA player salary pages into normalized CSV/JSON files.

The scraper is intentionally conservative: it uses a browser-like User-Agent,
serial requests with a configurable delay, retries transient failures, and
writes both a wide source-shaped dataset and a normalized long-form dataset.

Examples:
  python backend/scripts/scrape_hoopshype_salaries.py
  python backend/scripts/scrape_hoopshype_salaries.py --start-season 1990 --end-season 2026
  python backend/scripts/scrape_hoopshype_salaries.py --output-dir raw/hoopshype/salaries
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BASE_URL = "https://hoopshype.com/salaries/players/"
DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/140.0.0.0 Safari/537.36"
)
MONEY_RE = re.compile(r"-?\$?([0-9][0-9,]*)")
SEASON_RE = re.compile(r"^(19|20)\d{2}/\d{2}$")
OPTION_PATTERNS = {
    "player_option": ("player option", "po"),
    "team_option": ("team option", "to"),
    "qualifying_offer": ("qualifying offer", "qo"),
    "two_way": ("two-way", "two way", "2-way"),
}


@dataclass
class SalaryRecord:
    source_season: str
    player_rank: int | None
    player_name: str
    salary_season: str
    salary: int | None
    contract_marker: str | None
    source_url: str


def season_label(start_year: int) -> str:
    return f"{start_year}/{str(start_year + 1)[-2:]}"


def season_slug(start_year: int) -> str:
    return f"{start_year}-{start_year + 1}"


def parse_money(value: str) -> int | None:
    value = value.strip()
    if not value or value in {"-", "—", "N/A", "n/a"}:
        return None
    match = MONEY_RE.search(value)
    return int(match.group(1).replace(",", "")) if match else None


def detect_marker(cell) -> str | None:
    """Best-effort extraction of HoopsHype salary-cell contract annotations."""
    haystacks = [cell.get_text(" ", strip=True)]
    for tag in cell.find_all(True):
        haystacks.extend(
            str(tag.get(attr, ""))
            for attr in ("class", "title", "aria-label", "data-tooltip", "data-original-title")
        )
    text = " ".join(haystacks).lower()
    found = []
    for canonical, needles in OPTION_PATTERNS.items():
        if any(needle in text for needle in needles):
            found.append(canonical)
    return ";".join(found) if found else None


def build_session(user_agent: str) -> requests.Session:
    session = requests.Session()
    retry = Retry(
        total=4,
        connect=4,
        read=4,
        status=4,
        backoff_factor=1.0,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("GET",),
    )
    session.mount("https://", HTTPAdapter(max_retries=retry))
    session.headers.update(
        {
            "User-Agent": user_agent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Cache-Control": "no-cache",
        }
    )
    return session


def fetch_html(session: requests.Session, url: str, timeout: float) -> str:
    response = session.get(url, timeout=timeout)
    response.raise_for_status()
    return response.text


def find_salary_table(soup: BeautifulSoup):
    candidates = soup.find_all("table")
    for table in candidates:
        headers = [th.get_text(" ", strip=True) for th in table.find_all("th")]
        normalized = " | ".join(headers).lower()
        if "player" in normalized and any(SEASON_RE.match(h) for h in headers):
            return table
    raise ValueError("Could not locate HoopsHype player salary table")


def parse_salary_page(html: str, source_url: str, fallback_source_season: str) -> tuple[list[dict], list[SalaryRecord]]:
    soup = BeautifulSoup(html, "html.parser")
    table = find_salary_table(soup)

    header_cells = table.find("thead").find_all(["th", "td"]) if table.find("thead") else table.find("tr").find_all(["th", "td"])
    headers = [cell.get_text(" ", strip=True) for cell in header_cells]
    season_columns = [(i, h) for i, h in enumerate(headers) if SEASON_RE.match(h)]
    if not season_columns:
        raise ValueError("Salary table did not contain recognizable season columns")

    source_season = season_columns[0][1] if season_columns else fallback_source_season
    wide_rows: list[dict] = []
    long_rows: list[SalaryRecord] = []

    body = table.find("tbody") or table
    for row in body.find_all("tr"):
        cells = row.find_all(["td", "th"])
        if len(cells) < 2:
            continue
        texts = [cell.get_text(" ", strip=True) for cell in cells]
        if any(SEASON_RE.match(t) for t in texts):
            continue

        player_idx = next((i for i, h in enumerate(headers) if h.strip().lower() == "player"), 1 if len(cells) > 1 else 0)
        if player_idx >= len(cells):
            continue
        player_name = cells[player_idx].get_text(" ", strip=True)
        if not player_name or player_name.lower() == "player":
            continue

        rank = None
        if player_idx > 0:
            rank_match = re.search(r"\d+", texts[player_idx - 1])
            rank = int(rank_match.group()) if rank_match else None

        wide = {
            "source_season": source_season,
            "player_rank": rank,
            "player_name": player_name,
            "source_url": source_url,
        }

        for col_idx, salary_season in season_columns:
            if col_idx >= len(cells):
                continue
            cell = cells[col_idx]
            raw_text = cell.get_text(" ", strip=True)
            amount = parse_money(raw_text)
            marker = detect_marker(cell)
            wide[f"salary_{salary_season.replace('/', '_')}"] = amount
            wide[f"marker_{salary_season.replace('/', '_')}"] = marker
            long_rows.append(
                SalaryRecord(
                    source_season=source_season,
                    player_rank=rank,
                    player_name=player_name,
                    salary_season=salary_season,
                    salary=amount,
                    contract_marker=marker,
                    source_url=source_url,
                )
            )

        wide_rows.append(wide)

    if not wide_rows:
        raise ValueError("No player salary rows parsed from page")
    return wide_rows, long_rows


def candidate_urls(start_year: int) -> list[str]:
    # Current season is exposed at the base path; historical seasons use a season slug.
    return [f"{BASE_URL}{season_slug(start_year)}/", f"{BASE_URL}?season={season_slug(start_year)}"]


def scrape_season(
    session: requests.Session,
    start_year: int,
    timeout: float,
) -> tuple[list[dict], list[SalaryRecord], str]:
    expected = season_label(start_year)
    errors = []
    for url in candidate_urls(start_year):
        try:
            html = fetch_html(session, url, timeout)
            wide, long_rows = parse_salary_page(html, url, expected)
            actual = wide[0]["source_season"]
            if actual != expected:
                errors.append(f"{url}: expected {expected}, got {actual}")
                continue
            return wide, long_rows, url
        except Exception as exc:  # continue through known URL variants
            errors.append(f"{url}: {exc}")
    raise RuntimeError("; ".join(errors))


def write_csv(path: Path, rows: Iterable[dict]) -> None:
    rows = list(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fieldnames = []
    seen = set()
    for row in rows:
        for key in row:
            if key not in seen:
                seen.add(key)
                fieldnames.append(key)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-season", type=int, default=1990, help="First season start year (default: 1990)")
    parser.add_argument("--end-season", type=int, default=2026, help="Last season start year, inclusive (default: 2026)")
    parser.add_argument("--delay", type=float, default=1.25, help="Seconds between successful page requests")
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--user-agent", default=DEFAULT_USER_AGENT)
    parser.add_argument("--output-dir", default="raw/hoopshype/salaries")
    args = parser.parse_args()

    if args.start_season > args.end_season:
        parser.error("--start-season must be <= --end-season")

    output_dir = Path(args.output_dir)
    session = build_session(args.user_agent)
    all_long: list[dict] = []
    manifest = []

    for start_year in range(args.start_season, args.end_season + 1):
        label = season_label(start_year)
        print(f"Scraping {label}...", flush=True)
        try:
            wide, long_rows, source_url = scrape_season(session, start_year, args.timeout)
        except Exception as exc:
            print(f"  FAILED: {exc}", flush=True)
            manifest.append({"season": label, "status": "failed", "error": str(exc)})
            continue

        season_key = season_slug(start_year)
        write_csv(output_dir / "wide" / f"players_{season_key}.csv", wide)
        normalized = [asdict(record) for record in long_rows]
        write_csv(output_dir / "long" / f"players_{season_key}.csv", normalized)
        all_long.extend(normalized)
        manifest.append(
            {
                "season": label,
                "status": "ok",
                "source_url": source_url,
                "players": len(wide),
                "salary_cells": len(long_rows),
            }
        )
        print(f"  {len(wide)} players, {len(long_rows)} salary cells", flush=True)
        time.sleep(max(args.delay, 0.0))

    write_csv(output_dir / "players_all_seasons_long.csv", all_long)
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    successes = sum(item["status"] == "ok" for item in manifest)
    print(f"Finished: {successes}/{len(manifest)} seasons scraped")
    print(f"Output: {output_dir.resolve()}")
    return 0 if successes else 1


if __name__ == "__main__":
    raise SystemExit(main())
