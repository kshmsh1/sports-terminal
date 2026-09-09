#!/usr/bin/env python3
"""Multi-source NBA salary/contract ingestion for Sports Terminal.

Primary sources:
- Basketball-Reference player contract table (reported salary + guarantee + options)
- Basketball-Reference transaction logs (historical contract/waiver/extension events)
- NBA.com transaction pages / official cap releases (official event/system-level evidence)
- 2023 NBA CBA rules (local rule configuration; not scraped)

Every canonical field carries source/provenance metadata. The pipeline deliberately
separates reported cash salary, reported guaranteed money, and cap-derived values.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

import requests
from bs4 import BeautifulSoup, Comment
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BREF_CONTRACTS_URL = "https://www.basketball-reference.com/contracts/players.html"
BREF_TX_URL = "https://www.basketball-reference.com/leagues/NBA_{end_year}_transactions.html"
NBA_TX_URL = "https://www.nba.com/players/transactions"
USER_AGENT = "SportsTerminalResearchBot/0.1 (+https://github.com/kshmsh1/sports-terminal)"
MONEY_RE = re.compile(r"-?\$?([0-9][0-9,]*)")
SEASON_RE = re.compile(r"^(20\d{2}|19\d{2})[-/]([0-9]{2}|20\d{2})$")
DATE_RE = re.compile(
    r"^(January|February|March|April|May|June|July|August|September|October|November|December)\s+"
    r"(\d{1,2}|\?),\s+(\d{4})$"
)
PLAYER_HREF_RE = re.compile(r"/players/[a-z]/([^/]+)\.html$")


@dataclass
class ContractSeasonRecord:
    player_name: str
    player_external_id: str | None
    team_abbr: str | None
    season: str
    reported_salary: int | None
    reported_cap_hit: int | None
    reported_contract_guaranteed_total: int | None
    option_type: str | None
    signed_using: str | None
    source_name: str
    source_url: str
    source_authority: str
    source_retrieved_at: str
    raw_cell_text: str | None


@dataclass
class TransactionRecord:
    event_date: str | None
    player_name: str | None
    team_name: str | None
    event_type: str
    contract_type: str | None
    raw_text: str
    source_name: str
    source_url: str
    source_authority: str
    source_retrieved_at: str


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def parse_money(value: str | None) -> int | None:
    if value is None:
        return None
    value = value.strip()
    if not value or value in {"-", "—", "N/A", "n/a"}:
        return None
    match = MONEY_RE.search(value)
    return int(match.group(1).replace(",", "")) if match else None


def normalize_season(value: str) -> str | None:
    value = value.strip().replace("–", "-")
    m = SEASON_RE.match(value)
    if not m:
        return None
    start = int(m.group(1))
    second = m.group(2)
    end = int(second) if len(second) == 4 else (start // 100) * 100 + int(second)
    if end < start:
        end += 100
    return f"{start}-{str(end)[-2:]}"


def player_id_from_cell(cell) -> str | None:
    link = cell.find("a", href=True)
    if not link:
        return None
    m = PLAYER_HREF_RE.search(link["href"])
    return m.group(1) if m else None


def option_marker(cell) -> str | None:
    haystack = " ".join(
        [
            cell.get_text(" ", strip=True),
            " ".join(cell.get("class", [])),
            str(cell.get("title", "")),
            str(cell.get("data-tip", "")),
            str(cell.get("aria-label", "")),
        ]
    ).lower()
    if any(x in haystack for x in ("player option", "player-option", "popt", "po")):
        return "player_option"
    if any(x in haystack for x in ("team option", "team-option", "topt", "to")):
        return "team_option"
    if any(x in haystack for x in ("early termination", "eto")):
        return "early_termination_option"
    return None


def expand_commented_tables(html: str) -> BeautifulSoup:
    soup = BeautifulSoup(html, "html.parser")
    for comment in soup.find_all(string=lambda s: isinstance(s, Comment)):
        if "<table" in comment.lower():
            fragment = BeautifulSoup(comment, "html.parser")
            comment.replace_with(fragment)
    return soup


def find_contract_table(soup: BeautifulSoup):
    for table in soup.find_all("table"):
        header_text = " | ".join(th.get_text(" ", strip=True) for th in table.find_all("th"))
        if "Player" in header_text and "Guaranteed" in header_text and re.search(r"20\d{2}-\d{2}", header_text):
            return table
    raise ValueError("Could not find a player contracts table")


def _header_cells(table):
    thead = table.find("thead")
    if thead:
        rows = thead.find_all("tr")
        for row in reversed(rows):
            cells = row.find_all(["th", "td"])
            if any(c.get_text(" ", strip=True) == "Player" for c in cells):
                return cells
    for row in table.find_all("tr"):
        cells = row.find_all(["th", "td"])
        if any(c.get_text(" ", strip=True) == "Player" for c in cells):
            return cells
    raise ValueError("Could not identify contract table headers")


def parse_bref_contracts(html: str, source_url: str = BREF_CONTRACTS_URL) -> list[ContractSeasonRecord]:
    soup = expand_commented_tables(html)
    table = find_contract_table(soup)
    headers = [c.get_text(" ", strip=True) for c in _header_cells(table)]
    season_cols = {i: normalize_season(h) for i, h in enumerate(headers)}
    season_cols = {i: s for i, s in season_cols.items() if s}
    if not season_cols:
        raise ValueError("No salary-season columns found")

    def idx_of(label: str) -> int | None:
        for i, h in enumerate(headers):
            if h.strip().lower() == label.lower():
                return i
        return None

    player_idx = idx_of("Player")
    team_idx = idx_of("Tm")
    guaranteed_idx = idx_of("Guaranteed")
    cap_hit_idx = idx_of("Cap Hit")
    signed_using_idx = idx_of("Signed Using")
    if player_idx is None:
        raise ValueError("Player column missing")

    retrieved = utc_now()
    out: list[ContractSeasonRecord] = []
    body = table.find("tbody") or table
    for tr in body.find_all("tr"):
        cells = tr.find_all(["th", "td"], recursive=False)
        if not cells or player_idx >= len(cells):
            continue
        player_cell = cells[player_idx]
        player = player_cell.get_text(" ", strip=True)
        if not player or player.lower() == "player":
            continue
        team = cells[team_idx].get_text(" ", strip=True) if team_idx is not None and team_idx < len(cells) else None
        guaranteed = parse_money(cells[guaranteed_idx].get_text(" ", strip=True)) if guaranteed_idx is not None and guaranteed_idx < len(cells) else None
        cap_hit = parse_money(cells[cap_hit_idx].get_text(" ", strip=True)) if cap_hit_idx is not None and cap_hit_idx < len(cells) else None
        signed_using = cells[signed_using_idx].get_text(" ", strip=True) if signed_using_idx is not None and signed_using_idx < len(cells) else None
        player_id = player_id_from_cell(player_cell)
        for idx, season in season_cols.items():
            if idx >= len(cells):
                continue
            cell = cells[idx]
            raw = cell.get_text(" ", strip=True)
            salary = parse_money(raw)
            if salary is None and not raw:
                continue
            out.append(
                ContractSeasonRecord(
                    player_name=player,
                    player_external_id=player_id,
                    team_abbr=team or None,
                    season=season,
                    reported_salary=salary,
                    reported_cap_hit=cap_hit if idx == min(season_cols) else None,
                    reported_contract_guaranteed_total=guaranteed,
                    option_type=option_marker(cell),
                    signed_using=signed_using or None,
                    source_name="basketball_reference_contracts",
                    source_url=source_url,
                    source_authority="secondary_reported",
                    source_retrieved_at=retrieved,
                    raw_cell_text=raw or None,
                )
            )
    if not out:
        raise ValueError("No contract salary rows parsed")
    return out


TEAM_EVENT_RE = re.compile(r"^The (.+?) (signed|re-signed|waived|converted|traded|released|claimed) (.+?)(?:\.|$)", re.I)


def classify_transaction(text: str) -> tuple[str, str | None]:
    low = text.lower()
    if "waived" in low or "released" in low:
        return "waived", None
    if "converted" in low and "two-way" in low:
        return "converted_two_way_to_standard", "standard"
    if "traded" in low or "received" in low:
        return "trade", None
    if "extension" in low:
        if "rookie scale" in low:
            return "extension", "rookie_scale_extension"
        if "veteran" in low:
            return "extension", "veteran_extension"
        return "extension", "extension"
    if "two-way" in low or "two way" in low:
        return "signed", "two_way"
    if "10-day" in low or "10 day" in low:
        return "signed", "10_day"
    if "rest-of-season" in low or "rest of the season" in low or "rest-of-season" in low:
        return "signed", "rest_of_season"
    if "exhibit 10" in low:
        return "signed", "exhibit_10"
    if "rookie scale" in low:
        return "signed", "rookie_scale"
    if "re-signed" in low:
        return "re_signed", "standard"
    if "signed" in low:
        return "signed", "standard"
    return "other", None


def _extract_team_player(text: str) -> tuple[str | None, str | None]:
    m = TEAM_EVENT_RE.match(text)
    if not m:
        return None, None
    team, verb, rest = m.groups()
    player = re.split(r"\s+(?:to|as|from|for)\s+(?:a|an|the)\s+", rest, maxsplit=1, flags=re.I)[0]
    player = re.sub(r"\s+to\s+(?:a\s+)?(?:Two-Way|Rookie Scale|Rest-of-Season|10-Day|Veteran Extension|Contract).*", "", player, flags=re.I)
    return team.strip(), player.strip(" .") or None


def parse_transaction_page(
    html: str,
    source_url: str,
    source_name: str,
    authority: str,
) -> list[TransactionRecord]:
    soup = expand_commented_tables(html)
    lines = [x.strip() for x in soup.stripped_strings if x.strip()]
    current_date: str | None = None
    retrieved = utc_now()
    out: list[TransactionRecord] = []
    for line in lines:
        dm = DATE_RE.match(line)
        if dm:
            month, day, year = dm.groups()
            current_date = None if day == "?" else datetime.strptime(f"{month} {day}, {year}", "%B %d, %Y").date().isoformat()
            continue
        low = line.lower()
        if not any(token in low for token in (" signed ", " re-signed ", " waived ", " converted ", " traded ", " released ", " received ")):
            continue
        event_type, contract_type = classify_transaction(line)
        if event_type == "other":
            continue
        team, player = _extract_team_player(line)
        out.append(
            TransactionRecord(
                event_date=current_date,
                player_name=player,
                team_name=team,
                event_type=event_type,
                contract_type=contract_type,
                raw_text=line,
                source_name=source_name,
                source_url=source_url,
                source_authority=authority,
                source_retrieved_at=retrieved,
            )
        )
    return out


def build_session() -> requests.Session:
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
    session.headers.update({"User-Agent": USER_AGENT, "Accept-Language": "en-US,en;q=0.9"})
    return session


def robots_allows(session: requests.Session, url: str, timeout: float = 15) -> tuple[bool, str]:
    parsed = urlparse(url)
    robots_url = f"{parsed.scheme}://{parsed.netloc}/robots.txt"
    try:
        r = session.get(robots_url, timeout=timeout)
        r.raise_for_status()
    except Exception as exc:
        return False, f"robots.txt unavailable: {exc}"
    rp = RobotFileParser()
    rp.set_url(robots_url)
    rp.parse(r.text.splitlines())
    allowed = rp.can_fetch(USER_AGENT, url)
    return allowed, "allowed" if allowed else f"disallowed by {robots_url}"


def fetch_html(session: requests.Session, url: str, timeout: float = 30) -> str:
    allowed, reason = robots_allows(session, url)
    if not allowed:
        raise PermissionError(f"Refusing automated fetch for {url}: {reason}")
    response = session.get(url, timeout=timeout)
    response.raise_for_status()
    return response.text


def write_csv(path: Path, rows: Iterable[dict]) -> None:
    rows = list(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    keys: list[str] = []
    seen = set()
    for row in rows:
        for key in row:
            if key not in seen:
                seen.add(key)
                keys.append(key)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=keys)
        writer.writeheader()
        writer.writerows(rows)


def load_cba_rules(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_against_cba(records: list[ContractSeasonRecord], rules: dict) -> list[dict]:
    """Best-effort anomaly flags. These are diagnostics, not legal determinations."""
    issues: list[dict] = []
    options = rules["option_clauses"]
    by_player: dict[tuple[str, str | None], list[ContractSeasonRecord]] = {}
    for r in records:
        by_player.setdefault((r.player_name, r.team_abbr), []).append(r)
    for (player, team), rows in by_player.items():
        rows.sort(key=lambda r: r.season)
        for prev, cur in zip(rows, rows[1:]):
            if cur.option_type in {"player_option", "team_option"} and prev.reported_salary and cur.reported_salary:
                if cur.reported_salary < prev.reported_salary * options["minimum_option_salary_ratio_to_prior_year"]:
                    issues.append({
                        "player_name": player,
                        "team_abbr": team,
                        "season": cur.season,
                        "rule": "option_salary_floor",
                        "severity": "warning",
                        "detail": f"Reported option salary {cur.reported_salary} is below prior reported salary {prev.reported_salary}",
                        "cba_reference": options["reference"],
                    })
    return issues


def run_pipeline(args) -> int:
    output = Path(args.output_dir)
    rules = load_cba_rules(Path(args.cba_rules))
    session = build_session()
    manifest: list[dict] = []
    contracts: list[ContractSeasonRecord] = []
    transactions: list[TransactionRecord] = []

    if not args.skip_contracts:
        try:
            html = fetch_html(session, BREF_CONTRACTS_URL, args.timeout)
            contracts = parse_bref_contracts(html)
            manifest.append({"source": "basketball_reference_contracts", "status": "ok", "records": len(contracts)})
        except Exception as exc:
            manifest.append({"source": "basketball_reference_contracts", "status": "failed", "error": str(exc)})

    if not args.skip_nba_transactions:
        try:
            html = fetch_html(session, NBA_TX_URL, args.timeout)
            batch = parse_transaction_page(html, NBA_TX_URL, "nba_official_transactions", "official")
            transactions.extend(batch)
            manifest.append({"source": "nba_official_transactions", "status": "ok", "records": len(batch)})
        except Exception as exc:
            manifest.append({"source": "nba_official_transactions", "status": "failed", "error": str(exc)})

    if args.transaction_start_year and args.transaction_end_year:
        for end_year in range(args.transaction_start_year + 1, args.transaction_end_year + 2):
            url = BREF_TX_URL.format(end_year=end_year)
            try:
                html = fetch_html(session, url, args.timeout)
                batch = parse_transaction_page(html, url, "basketball_reference_transactions", "secondary_reported")
                transactions.extend(batch)
                manifest.append({"source": "basketball_reference_transactions", "season_end_year": end_year, "status": "ok", "records": len(batch)})
            except Exception as exc:
                manifest.append({"source": "basketball_reference_transactions", "season_end_year": end_year, "status": "failed", "error": str(exc)})
            time.sleep(max(args.delay, 0))

    write_csv(output / "contracts_long.csv", [asdict(x) for x in contracts])
    write_csv(output / "transactions.csv", [asdict(x) for x in transactions])
    write_csv(output / "cba_validation_issues.csv", validate_against_cba(contracts, rules))
    output.mkdir(parents=True, exist_ok=True)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return 0 if any(x["status"] == "ok" for x in manifest) else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", default="raw/nba_contracts")
    parser.add_argument("--cba-rules", default="backend/data/cba_2023_contract_rules.json")
    parser.add_argument("--transaction-start-year", type=int, default=1983, help="First season start year")
    parser.add_argument("--transaction-end-year", type=int, default=2026, help="Last season start year")
    parser.add_argument("--skip-contracts", action="store_true")
    parser.add_argument("--skip-nba-transactions", action="store_true")
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--timeout", type=float, default=30.0)
    args = parser.parse_args()
    if args.transaction_start_year > args.transaction_end_year:
        parser.error("transaction start year must not exceed end year")
    return run_pipeline(args)


if __name__ == "__main__":
    raise SystemExit(main())
