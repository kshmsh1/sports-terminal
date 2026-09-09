#!/usr/bin/env python3
"""Multi-source NBA salary/contract ingestion for Sports Terminal.

Sources currently supported:
- Basketball-Reference league-wide current player contracts
- Basketball-Reference current team payrolls (including partial-guarantee markers)
- Basketball-Reference historical team-season salary tables
- Basketball-Reference historical transaction logs
- NBA.com transaction pages
- local 2023 CBA rule configuration + official cap-level seed data

The pipeline preserves source evidence and produces a conservative canonical view.
It deliberately separates reported cash salary, reported guarantee information,
and any future CBA-derived cap/team-salary calculations.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.parse import urljoin, urlparse
from urllib.robotparser import RobotFileParser

import requests
from bs4 import BeautifulSoup, Comment
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BREF_BASE = "https://www.basketball-reference.com"
BREF_CONTRACTS_URL = f"{BREF_BASE}/contracts/players.html"
BREF_CONTRACTS_SUMMARY_URL = f"{BREF_BASE}/contracts/"
BREF_LEAGUE_URL = f"{BREF_BASE}/leagues/NBA_{{end_year}}.html"
BREF_TX_URL = f"{BREF_BASE}/leagues/NBA_{{end_year}}_transactions.html"
NBA_TX_URL = "https://www.nba.com/players/transactions"
USER_AGENT = "SportsTerminalResearchBot/0.2 (+https://github.com/kshmsh1/sports-terminal)"
MONEY_RE = re.compile(r"-?\$?([0-9][0-9,]*)")
SEASON_RE = re.compile(r"^(20\d{2}|19\d{2})[-/]([0-9]{2}|20\d{2})$")
DATE_RE = re.compile(
    r"^(January|February|March|April|May|June|July|August|September|October|November|December)\s+"
    r"(\d{1,2}|\?),\s+(\d{4})$"
)
PLAYER_HREF_RE = re.compile(r"/players/[a-z]/([^/]+)\.html$")
TEAM_CONTRACT_HREF_RE = re.compile(r"^/contracts/([A-Z0-9]+)\.html$")
TEAM_SEASON_HREF_RE_TEMPLATE = r"^/teams/([A-Z0-9]+)/{end_year}\.html$"
POSITION_PREFIX_RE = re.compile(
    r"^(?:(?:point|shooting|small|power)\s+)?(?:guard|forward|center)(?:[-/]?(?:guard|forward|center))?\s+",
    re.I,
)
BREF_HISTORICAL_QUALITY_NOTE = (
    "Basketball-Reference describes historical NBA salary data as unofficial/inexact; "
    "some missing seasons are minimum-salary assignments or extrapolations."
)


@dataclass
class ContractSeasonRecord:
    player_name: str
    player_external_id: str | None
    team_abbr: str | None
    season: str
    reported_salary: int | None
    reported_cap_hit: int | None
    reported_contract_guaranteed_total: int | None
    reported_salary_fully_guaranteed: bool | None
    option_type: str | None
    signed_using: str | None
    source_name: str
    source_url: str
    source_authority: str
    source_retrieved_at: str
    source_quality_note: str | None
    raw_cell_text: str | None


@dataclass
class CanonicalContractSeason:
    player_name: str
    player_external_id: str | None
    team_abbr: str | None
    season: str
    reported_salary: int | None
    reported_cap_hit: int | None
    reported_contract_guaranteed_total: int | None
    reported_salary_fully_guaranteed: bool | None
    option_type: str | None
    signed_using: str | None
    salary_source_name: str | None
    guarantee_source_name: str | None
    option_source_name: str | None
    evidence_count: int
    source_urls: str


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


def season_from_end_year(end_year: int) -> str:
    return f"{end_year - 1}-{str(end_year)[-2:]}"


def player_id_from_cell(cell) -> str | None:
    link = cell.find("a", href=True)
    if not link:
        return None
    m = PLAYER_HREF_RE.search(link["href"])
    return m.group(1) if m else None


def option_marker(cell) -> str | None:
    classes = {str(x).lower() for x in cell.get("class", [])}
    attrs = " ".join(
        [
            cell.get_text(" ", strip=True),
            str(cell.get("title", "")),
            str(cell.get("data-tip", "")),
            str(cell.get("data-tooltip", "")),
            str(cell.get("aria-label", "")),
        ]
    ).lower()
    if "popt" in classes or "player option" in attrs or "player-option" in attrs:
        return "player_option"
    if "topt" in classes or "team option" in attrs or "team-option" in attrs:
        return "team_option"
    if "eto" in classes or "early termination option" in attrs:
        return "early_termination_option"
    return None


def is_not_fully_guaranteed(cell) -> bool:
    if cell.find(["em", "i"]):
        return True
    classes = " ".join(str(x).lower() for x in cell.get("class", []))
    style = str(cell.get("style", "")).lower()
    title = str(cell.get("title", "")).lower()
    return (
        "not fully guaranteed" in title
        or "partial" in classes
        or "non-guaranteed" in classes
        or "font-style: italic" in style
        or "font-style:italic" in style
    )


def expand_commented_tables(html: str) -> BeautifulSoup:
    soup = BeautifulSoup(html, "html.parser")
    for comment in list(soup.find_all(string=lambda s: isinstance(s, Comment))):
        text = str(comment)
        if "<table" in text.lower():
            fragment = BeautifulSoup(text, "html.parser")
            comment.replace_with(fragment)
    return soup


def _header_cells(table):
    thead = table.find("thead")
    if thead:
        rows = thead.find_all("tr")
        for row in reversed(rows):
            cells = row.find_all(["th", "td"], recursive=False)
            if any(c.get_text(" ", strip=True).lower() == "player" for c in cells):
                return cells
    for row in table.find_all("tr"):
        cells = row.find_all(["th", "td"], recursive=False)
        if any(c.get_text(" ", strip=True).lower() == "player" for c in cells):
            return cells
    raise ValueError("Could not identify table headers")


def _header_index(headers: list[str], *labels: str) -> int | None:
    wanted = {label.lower() for label in labels}
    for i, h in enumerate(headers):
        if h.strip().lower() in wanted:
            return i
    return None


def _find_table(soup: BeautifulSoup, required_headers: set[str], require_season: bool = False):
    required = {x.lower() for x in required_headers}
    for table in soup.find_all("table"):
        try:
            headers = [c.get_text(" ", strip=True) for c in _header_cells(table)]
        except ValueError:
            continue
        lowered = {h.lower() for h in headers}
        if not required.issubset(lowered):
            continue
        if require_season and not any(normalize_season(h) for h in headers):
            continue
        return table, headers
    raise ValueError(f"Could not find table with headers: {sorted(required_headers)}")


def parse_bref_contracts(html: str, source_url: str = BREF_CONTRACTS_URL) -> list[ContractSeasonRecord]:
    soup = expand_commented_tables(html)
    table, headers = _find_table(soup, {"Player", "Guaranteed"}, require_season=True)
    season_cols = {i: normalize_season(h) for i, h in enumerate(headers)}
    season_cols = {i: s for i, s in season_cols.items() if s}
    player_idx = _header_index(headers, "Player")
    team_idx = _header_index(headers, "Tm", "Team")
    guaranteed_idx = _header_index(headers, "Guaranteed")
    cap_hit_idx = _header_index(headers, "Cap Hit")
    signed_using_idx = _header_index(headers, "Signed Using")
    if player_idx is None:
        raise ValueError("Player column missing")

    retrieved = utc_now()
    out: list[ContractSeasonRecord] = []
    body = table.find("tbody") or table
    first_season_col = min(season_cols)
    for tr in body.find_all("tr"):
        cells = tr.find_all(["th", "td"], recursive=False)
        if not cells or player_idx >= len(cells):
            continue
        player_cell = cells[player_idx]
        player = player_cell.get_text(" ", strip=True)
        if not player or player.lower() in {"player", "team totals"}:
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
            option = option_marker(cell)
            out.append(
                ContractSeasonRecord(
                    player_name=player,
                    player_external_id=player_id,
                    team_abbr=team or None,
                    season=season,
                    reported_salary=salary,
                    reported_cap_hit=cap_hit if idx == first_season_col else None,
                    reported_contract_guaranteed_total=guaranteed,
                    reported_salary_fully_guaranteed=False if option else None,
                    option_type=option,
                    signed_using=signed_using or None,
                    source_name="basketball_reference_contracts",
                    source_url=source_url,
                    source_authority="secondary_reported",
                    source_retrieved_at=retrieved,
                    source_quality_note=None,
                    raw_cell_text=raw or None,
                )
            )
    if not out:
        raise ValueError("No player contract salary rows parsed")
    return out


def discover_bref_team_payroll_links(html: str, base_url: str = BREF_BASE) -> list[tuple[str, str]]:
    soup = expand_commented_tables(html)
    found: dict[str, str] = {}
    for link in soup.find_all("a", href=True):
        m = TEAM_CONTRACT_HREF_RE.match(link["href"])
        if m:
            team = m.group(1)
            found[team] = urljoin(base_url, link["href"])
    return sorted(found.items())


def parse_bref_team_payroll(html: str, team_abbr: str, source_url: str) -> list[ContractSeasonRecord]:
    soup = expand_commented_tables(html)
    table, headers = _find_table(soup, {"Player", "Guaranteed"}, require_season=True)
    season_cols = {i: normalize_season(h) for i, h in enumerate(headers)}
    season_cols = {i: s for i, s in season_cols.items() if s}
    player_idx = _header_index(headers, "Player")
    guaranteed_idx = _header_index(headers, "Guaranteed")
    cap_hit_idx = _header_index(headers, "Cap Hit")
    signed_using_idx = _header_index(headers, "Signed Using")
    if player_idx is None:
        raise ValueError("Player column missing")

    retrieved = utc_now()
    out: list[ContractSeasonRecord] = []
    body = table.find("tbody") or table
    first_season_col = min(season_cols)
    for tr in body.find_all("tr"):
        cells = tr.find_all(["th", "td"], recursive=False)
        if not cells or player_idx >= len(cells):
            continue
        player_cell = cells[player_idx]
        player = player_cell.get_text(" ", strip=True)
        if not player or player.lower() in {"player", "team totals"}:
            continue
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
            option = option_marker(cell)
            not_fully = is_not_fully_guaranteed(cell)
            guarantee_flag = False if not_fully or option else (True if salary is not None else None)
            out.append(
                ContractSeasonRecord(
                    player_name=player,
                    player_external_id=player_id,
                    team_abbr=team_abbr,
                    season=season,
                    reported_salary=salary,
                    reported_cap_hit=cap_hit if idx == first_season_col else None,
                    reported_contract_guaranteed_total=guaranteed,
                    reported_salary_fully_guaranteed=guarantee_flag,
                    option_type=option,
                    signed_using=signed_using or None,
                    source_name="basketball_reference_team_payroll",
                    source_url=source_url,
                    source_authority="secondary_reported",
                    source_retrieved_at=retrieved,
                    source_quality_note=None,
                    raw_cell_text=raw or None,
                )
            )
    if not out:
        raise ValueError(f"No payroll salary rows parsed for {team_abbr}")
    return out


def discover_bref_team_season_links(html: str, end_year: int, base_url: str = BREF_BASE) -> list[tuple[str, str]]:
    soup = expand_commented_tables(html)
    pattern = re.compile(TEAM_SEASON_HREF_RE_TEMPLATE.format(end_year=end_year))
    found: dict[str, str] = {}
    for link in soup.find_all("a", href=True):
        m = pattern.match(link["href"])
        if m:
            team = m.group(1)
            found[team] = urljoin(base_url, link["href"])
    return sorted(found.items())


def parse_bref_historical_team_salary(
    html: str,
    team_abbr: str,
    end_year: int,
    source_url: str,
) -> list[ContractSeasonRecord]:
    soup = expand_commented_tables(html)
    table, headers = _find_table(soup, {"Player", "Salary"}, require_season=False)
    player_idx = _header_index(headers, "Player")
    salary_idx = _header_index(headers, "Salary")
    if player_idx is None or salary_idx is None:
        raise ValueError("Historical salary table missing Player or Salary")

    retrieved = utc_now()
    season = season_from_end_year(end_year)
    out: list[ContractSeasonRecord] = []
    body = table.find("tbody") or table
    for tr in body.find_all("tr"):
        cells = tr.find_all(["th", "td"], recursive=False)
        if not cells or max(player_idx, salary_idx) >= len(cells):
            continue
        player_cell = cells[player_idx]
        player = player_cell.get_text(" ", strip=True)
        if not player or player.lower() in {"player", "team totals", "team total"}:
            continue
        salary_cell = cells[salary_idx]
        raw = salary_cell.get_text(" ", strip=True)
        salary = parse_money(raw)
        if salary is None:
            continue
        out.append(
            ContractSeasonRecord(
                player_name=player,
                player_external_id=player_id_from_cell(player_cell),
                team_abbr=team_abbr,
                season=season,
                reported_salary=salary,
                reported_cap_hit=None,
                reported_contract_guaranteed_total=None,
                reported_salary_fully_guaranteed=None,
                option_type=None,
                signed_using=None,
                source_name="basketball_reference_historical_team_salary",
                source_url=source_url,
                source_authority="secondary_reported",
                source_retrieved_at=retrieved,
                source_quality_note=BREF_HISTORICAL_QUALITY_NOTE,
                raw_cell_text=raw,
            )
        )
    if not out:
        raise ValueError(f"No historical salary rows parsed for {team_abbr} {season}")
    return out


TEAM_EVENT_RE = re.compile(
    r"^The (.+?) (signed|re-signed|waived|converted|traded|released|claimed) (.+?)(?:\.|$)",
    re.I,
)


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
    if "rest-of-season" in low or "rest of the season" in low:
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
    team, _verb, rest = m.groups()
    rest = POSITION_PREFIX_RE.sub("", rest.strip())
    player = re.split(
        r"\s+(?:to|as|from|for)\s+(?:(?:a|an|the)\s+)?",
        rest,
        maxsplit=1,
        flags=re.I,
    )[0]
    player = re.sub(
        r"\s+to\s+(?:a\s+)?(?:Two-Way|Rookie Scale|Rest-of-Season|10-Day|Veteran Extension|Contract).*",
        "",
        player,
        flags=re.I,
    )
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
    seen: set[tuple[str | None, str]] = set()
    for line in lines:
        dm = DATE_RE.match(line)
        if dm:
            month, day, year = dm.groups()
            current_date = None if day == "?" else datetime.strptime(f"{month} {day}, {year}", "%B %d, %Y").date().isoformat()
            continue
        low = f" {line.lower()} "
        if not any(token in low for token in (" signed ", " re-signed ", " waived ", " converted ", " traded ", " released ", " received ")):
            continue
        event_type, contract_type = classify_transaction(line)
        if event_type == "other":
            continue
        key = (current_date, line)
        if key in seen:
            continue
        seen.add(key)
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


def canonicalize_contract_evidence(records: list[ContractSeasonRecord]) -> list[CanonicalContractSeason]:
    """Create one conservative row per player/team/season while retaining evidence separately."""
    source_priority = {
        "basketball_reference_team_payroll": 30,
        "basketball_reference_contracts": 20,
        "basketball_reference_historical_team_salary": 10,
    }
    groups: dict[tuple[str, str | None, str], list[ContractSeasonRecord]] = {}
    for r in records:
        identity = r.player_external_id or re.sub(r"[^a-z0-9]+", "", r.player_name.lower())
        groups.setdefault((identity, r.team_abbr, r.season), []).append(r)

    out: list[CanonicalContractSeason] = []
    for (_identity, team, season), rows in groups.items():
        rows.sort(key=lambda r: source_priority.get(r.source_name, 0), reverse=True)

        def first_with(attr: str):
            for row in rows:
                value = getattr(row, attr)
                if value is not None and value != "":
                    return value, row.source_name
            return None, None

        salary, salary_source = first_with("reported_salary")
        cap_hit, _cap_source = first_with("reported_cap_hit")
        guaranteed, guarantee_source = first_with("reported_contract_guaranteed_total")
        guarantee_flag, guarantee_flag_source = first_with("reported_salary_fully_guaranteed")
        option, option_source = first_with("option_type")
        signed_using, _signed_source = first_with("signed_using")
        player_id, _ = first_with("player_external_id")
        player_name = rows[0].player_name
        if guarantee_source is None:
            guarantee_source = guarantee_flag_source
        urls = ";".join(dict.fromkeys(r.source_url for r in rows))
        out.append(
            CanonicalContractSeason(
                player_name=player_name,
                player_external_id=player_id,
                team_abbr=team,
                season=season,
                reported_salary=salary,
                reported_cap_hit=cap_hit,
                reported_contract_guaranteed_total=guaranteed,
                reported_salary_fully_guaranteed=guarantee_flag,
                option_type=option,
                signed_using=signed_using,
                salary_source_name=salary_source,
                guarantee_source_name=guarantee_source,
                option_source_name=option_source,
                evidence_count=len(rows),
                source_urls=urls,
            )
        )
    return sorted(out, key=lambda r: (r.season, r.team_abbr or "", r.player_name))


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


class RobotsGate:
    def __init__(self, session: requests.Session, timeout: float = 15.0):
        self.session = session
        self.timeout = timeout
        self._parsers: dict[str, RobotFileParser | None] = {}
        self._errors: dict[str, str] = {}

    def allows(self, url: str) -> tuple[bool, str]:
        parsed = urlparse(url)
        origin = f"{parsed.scheme}://{parsed.netloc}"
        robots_url = f"{origin}/robots.txt"
        if origin not in self._parsers:
            try:
                response = self.session.get(robots_url, timeout=self.timeout)
                response.raise_for_status()
                rp = RobotFileParser()
                rp.set_url(robots_url)
                rp.parse(response.text.splitlines())
                self._parsers[origin] = rp
            except Exception as exc:
                self._parsers[origin] = None
                self._errors[origin] = str(exc)
        rp = self._parsers[origin]
        if rp is None:
            return False, f"robots.txt unavailable: {self._errors.get(origin, 'unknown error')}"
        allowed = rp.can_fetch(USER_AGENT, url)
        return allowed, "allowed" if allowed else f"disallowed by {robots_url}"


def cache_path_for_url(cache_dir: Path, url: str) -> Path:
    parsed = urlparse(url)
    suffix = Path(parsed.path).suffix or ".html"
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
    return cache_dir / parsed.netloc / f"{digest}{suffix}"


def fetch_html(
    session: requests.Session,
    gate: RobotsGate,
    url: str,
    timeout: float,
    cache_dir: Path | None,
    refresh: bool,
) -> str:
    cache_path = cache_path_for_url(cache_dir, url) if cache_dir else None
    if cache_path and cache_path.exists() and not refresh:
        return cache_path.read_text(encoding="utf-8")
    allowed, reason = gate.allows(url)
    if not allowed:
        raise PermissionError(f"Refusing automated fetch for {url}: {reason}")
    response = session.get(url, timeout=timeout)
    response.raise_for_status()
    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(response.text, encoding="utf-8")
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


def validate_against_cba(records: list[CanonicalContractSeason], rules: dict) -> list[dict]:
    """Best-effort anomaly flags. Diagnostics only; not legal determinations."""
    issues: list[dict] = []
    options = rules["option_clauses"]
    by_player: dict[tuple[str, str | None], list[CanonicalContractSeason]] = {}
    for r in records:
        identity = r.player_external_id or r.player_name.lower()
        by_player.setdefault((identity, r.team_abbr), []).append(r)
    for (_identity, team), rows in by_player.items():
        rows.sort(key=lambda r: r.season)
        for prev, cur in zip(rows, rows[1:]):
            if cur.option_type in {"player_option", "team_option"} and prev.reported_salary and cur.reported_salary:
                if cur.reported_salary < prev.reported_salary * options["minimum_option_salary_ratio_to_prior_year"]:
                    issues.append(
                        {
                            "player_name": cur.player_name,
                            "team_abbr": team,
                            "season": cur.season,
                            "rule": "option_salary_floor",
                            "severity": "warning",
                            "detail": f"Reported option salary {cur.reported_salary} is below prior reported salary {prev.reported_salary}",
                            "cba_reference": options["reference"],
                        }
                    )
    return issues


def _fetch(
    session: requests.Session,
    gate: RobotsGate,
    args,
    url: str,
) -> str:
    return fetch_html(
        session,
        gate,
        url,
        args.timeout,
        Path(args.cache_dir) if args.cache_dir else None,
        args.refresh,
    )


def run_pipeline(args) -> int:
    output = Path(args.output_dir)
    rules = load_cba_rules(Path(args.cba_rules))
    session = build_session()
    gate = RobotsGate(session)
    manifest: list[dict] = []
    evidence: list[ContractSeasonRecord] = []
    transactions: list[TransactionRecord] = []

    if not args.skip_contracts:
        try:
            html = _fetch(session, gate, args, BREF_CONTRACTS_URL)
            batch = parse_bref_contracts(html)
            evidence.extend(batch)
            manifest.append({"source": "basketball_reference_contracts", "status": "ok", "records": len(batch)})
        except Exception as exc:
            manifest.append({"source": "basketball_reference_contracts", "status": "failed", "error": str(exc)})

    if not args.skip_team_payrolls:
        try:
            summary_html = _fetch(session, gate, args, BREF_CONTRACTS_SUMMARY_URL)
            team_links = discover_bref_team_payroll_links(summary_html)
            manifest.append({"source": "basketball_reference_team_payroll_index", "status": "ok", "teams": len(team_links)})
            for team, url in team_links:
                try:
                    batch = parse_bref_team_payroll(_fetch(session, gate, args, url), team, url)
                    evidence.extend(batch)
                    manifest.append({"source": "basketball_reference_team_payroll", "team": team, "status": "ok", "records": len(batch)})
                except Exception as exc:
                    manifest.append({"source": "basketball_reference_team_payroll", "team": team, "status": "failed", "error": str(exc)})
                time.sleep(max(args.delay, 0))
        except Exception as exc:
            manifest.append({"source": "basketball_reference_team_payroll_index", "status": "failed", "error": str(exc)})

    if not args.skip_historical_salaries:
        for end_year in range(args.historical_start_year + 1, args.historical_end_year + 2):
            season = season_from_end_year(end_year)
            league_url = BREF_LEAGUE_URL.format(end_year=end_year)
            try:
                league_html = _fetch(session, gate, args, league_url)
                team_links = discover_bref_team_season_links(league_html, end_year)
                manifest.append({"source": "basketball_reference_team_season_index", "season": season, "status": "ok", "teams": len(team_links)})
            except Exception as exc:
                manifest.append({"source": "basketball_reference_team_season_index", "season": season, "status": "failed", "error": str(exc)})
                continue
            for team, url in team_links:
                try:
                    batch = parse_bref_historical_team_salary(_fetch(session, gate, args, url), team, end_year, url)
                    evidence.extend(batch)
                    manifest.append({"source": "basketball_reference_historical_team_salary", "season": season, "team": team, "status": "ok", "records": len(batch)})
                except Exception as exc:
                    manifest.append({"source": "basketball_reference_historical_team_salary", "season": season, "team": team, "status": "failed", "error": str(exc)})
                time.sleep(max(args.delay, 0))

    if not args.skip_nba_transactions:
        try:
            html = _fetch(session, gate, args, NBA_TX_URL)
            batch = parse_transaction_page(html, NBA_TX_URL, "nba_official_transactions", "official")
            transactions.extend(batch)
            manifest.append({"source": "nba_official_transactions", "status": "ok", "records": len(batch)})
        except Exception as exc:
            manifest.append({"source": "nba_official_transactions", "status": "failed", "error": str(exc)})

    if not args.skip_historical_transactions:
        for end_year in range(args.transaction_start_year + 1, args.transaction_end_year + 2):
            url = BREF_TX_URL.format(end_year=end_year)
            season = season_from_end_year(end_year)
            try:
                html = _fetch(session, gate, args, url)
                batch = parse_transaction_page(html, url, "basketball_reference_transactions", "secondary_reported")
                transactions.extend(batch)
                manifest.append({"source": "basketball_reference_transactions", "season": season, "status": "ok", "records": len(batch)})
            except Exception as exc:
                manifest.append({"source": "basketball_reference_transactions", "season": season, "status": "failed", "error": str(exc)})
            time.sleep(max(args.delay, 0))

    canonical = canonicalize_contract_evidence(evidence)
    write_csv(output / "contract_evidence.csv", [asdict(x) for x in evidence])
    write_csv(output / "contracts_long.csv", [asdict(x) for x in canonical])
    write_csv(output / "transactions.csv", [asdict(x) for x in transactions])
    write_csv(output / "cba_validation_issues.csv", validate_against_cba(canonical, rules))
    output.mkdir(parents=True, exist_ok=True)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    success_count = sum(item.get("status") == "ok" for item in manifest)
    print(f"Contract evidence rows: {len(evidence)}")
    print(f"Canonical contract-season rows: {len(canonical)}")
    print(f"Transaction rows: {len(transactions)}")
    print(f"Successful source/page entries: {success_count}/{len(manifest)}")
    print(f"Output: {output.resolve()}")
    return 0 if success_count else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", default="raw/nba_contracts")
    parser.add_argument("--cache-dir", default="raw/nba_contracts/cache", help="HTML cache for resumable/polite runs")
    parser.add_argument("--cba-rules", default="backend/data/cba_2023_contract_rules.json")
    parser.add_argument("--historical-start-year", type=int, default=1984, help="First historical salary season start year")
    parser.add_argument("--historical-end-year", type=int, default=2025, help="Last historical salary season start year; current payroll handles later seasons")
    parser.add_argument("--transaction-start-year", type=int, default=1983, help="First transaction season start year")
    parser.add_argument("--transaction-end-year", type=int, default=2026, help="Last transaction season start year")
    parser.add_argument("--skip-contracts", action="store_true")
    parser.add_argument("--skip-team-payrolls", action="store_true")
    parser.add_argument("--skip-historical-salaries", action="store_true")
    parser.add_argument("--skip-nba-transactions", action="store_true")
    parser.add_argument("--skip-historical-transactions", action="store_true")
    parser.add_argument("--delay", type=float, default=2.0, help="Delay between page requests")
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--refresh", action="store_true", help="Ignore cached HTML and re-fetch")
    args = parser.parse_args()
    if args.historical_start_year > args.historical_end_year:
        parser.error("historical start year must not exceed historical end year")
    if args.transaction_start_year > args.transaction_end_year:
        parser.error("transaction start year must not exceed transaction end year")
    return run_pipeline(args)


if __name__ == "__main__":
    raise SystemExit(main())
