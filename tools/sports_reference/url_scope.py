from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin, urlparse, urlunparse

BASE_URL = "https://www.basketball-reference.com"


@dataclass(frozen=True)
class ScopedUrl:
    url: str
    page_family: str
    source_key: str | None = None
    season_end_year: int | None = None
    team_abbreviation: str | None = None
    entity_id: str | None = None
    priority: int = 100


class BasketballReferenceUrlScope:
    """Canonical URL catalog for bounded Basketball Reference collection."""

    _patterns = (
        ("league", re.compile(r"^/leagues/NBA_(\d{4})(?:_([a-z0-9_-]+))?\.html$"), 10),
        ("playoff", re.compile(r"^/playoffs/NBA_(\d{4})(?:_([a-z0-9_-]+))?\.html$"), 20),
        ("playoff", re.compile(r"^/playoffs/(\d{4})-nba-([a-z0-9-]+)\.html$"), 25),
        ("team_season", re.compile(r"^/teams/([A-Z0-9]{2,3})/(\d{4})\.html$"), 30),
        (
            "boxscore_detail",
            re.compile(
                r"^/boxscores/(pbp|shot-chart|plus-minus)/([0-9A-Z]+)\.html$",
                re.IGNORECASE,
            ),
            42,
        ),
        ("boxscore", re.compile(r"^/boxscores/([0-9A-Z]+)\.html$", re.IGNORECASE), 40),
        ("player", re.compile(r"^/players/[a-z]/([a-z0-9]+)\.html$"), 50),
        ("draft", re.compile(r"^/draft/NBA_(\d{4})\.html$"), 35),
        ("award", re.compile(r"^/awards/(?:awards_)?([a-zA-Z0-9_-]+)\.html$"), 35),
        ("allstar", re.compile(r"^/allstar/NBA_(\d{4})\.html$"), 35),
        ("team_history", re.compile(r"^/teams/([A-Z0-9]{2,3})/?$"), 70),
        (
            "franchise",
            re.compile(r"^/teams/([A-Z0-9]{2,3})/(stats|players|draft|coaches|executives)\.html$"),
            75,
        ),
        ("coach", re.compile(r"^/coaches/([a-z0-9]+)\.html$"), 80),
        ("executive", re.compile(r"^/executives/([a-z0-9]+)\.html$"), 85),
    )

    _source_prefixes = {
        "league": "season-page",
        "playoff": "playoff",
        "team_season": "team-season",
        "team_history": "team",
        "franchise": "franchise",
        "player": "player",
        "boxscore": "game",
        "boxscore_detail": "game-detail",
        "draft": "draft",
        "award": "award",
        "allstar": "allstar",
        "coach": "coach",
        "executive": "executive",
    }

    _ignored_prefixes = (
        "/about/",
        "/blog/",
        "/email/",
        "/friv/",
        "/linker/",
        "/my/",
        "/search/",
        "/short/",
        "/stathead/",
    )

    _extended_league_suffixes = (
        "per_minute",
        "per_poss",
        "shooting",
        "adj_shooting",
        "play-by-play",
        "rookies",
        "ratings",
        "leaders",
    )

    _historical_playoff_suffixes = (
        "per_game",
        "totals",
        "per_minute",
        "per_poss",
        "advanced",
        "shooting",
        "play-by-play",
    )

    def canonicalize(self, href: str, *, source_url: str = BASE_URL) -> str | None:
        if not href or href.startswith(("#", "mailto:", "javascript:")):
            return None
        absolute = urljoin(source_url, href)
        parsed = urlparse(absolute)
        host = (parsed.hostname or "").lower()
        if host not in {"basketball-reference.com", "www.basketball-reference.com"}:
            return None
        if parsed.scheme not in {"http", "https"}:
            return None
        path = re.sub(r"/{2,}", "/", parsed.path or "/")
        if path.startswith(self._ignored_prefixes):
            return None
        return urlunparse(("https", "www.basketball-reference.com", path, "", "", ""))

    def classify(self, url: str) -> ScopedUrl | None:
        canonical = self.canonicalize(url)
        if canonical is None:
            return None
        path = urlparse(canonical).path
        for family, pattern, priority in self._patterns:
            match = pattern.fullmatch(path)
            if match is not None:
                return self._scoped_url(
                    canonical=canonical,
                    family=family,
                    groups=match.groups(),
                    priority=priority,
                )
        return None

    def is_allowed(self, url: str, families: set[str] | None = None) -> bool:
        scoped = self.classify(url)
        if scoped is None:
            return False
        return families is None or scoped.page_family in families

    def season_seeds(self, season_end_year: int, *, profile: str = "core") -> list[ScopedUrl]:
        if season_end_year < 1947 or season_end_year > 2100:
            raise ValueError("season_end_year must be between 1947 and 2100")
        if profile not in {"core", "extended", "historical"}:
            raise ValueError("profile must be core, extended, or historical")

        league_suffixes = ["", "per_game", "totals", "advanced", "games"]
        if profile in {"extended", "historical"}:
            league_suffixes.extend(self._extended_league_suffixes)

        urls = [
            f"{BASE_URL}/leagues/NBA_{season_end_year}{'_' + suffix if suffix else ''}.html"
            for suffix in league_suffixes
        ]
        urls.extend(
            [
                f"{BASE_URL}/playoffs/NBA_{season_end_year}.html",
                f"{BASE_URL}/draft/NBA_{season_end_year}.html",
            ]
        )
        if profile == "historical":
            urls.extend(
                f"{BASE_URL}/playoffs/NBA_{season_end_year}_{suffix}.html"
                for suffix in self._historical_playoff_suffixes
            )
            urls.extend(
                [
                    f"{BASE_URL}/awards/awards_{season_end_year}.html",
                    f"{BASE_URL}/allstar/NBA_{season_end_year}.html",
                ]
            )

        output: list[ScopedUrl] = []
        seen: set[str] = set()
        for url in urls:
            scoped = self.classify(url)
            if scoped is None or scoped.url in seen:
                continue
            seen.add(scoped.url)
            output.append(scoped)
        return output

    def season_range_seeds(
        self,
        start_year: int,
        end_year: int,
        *,
        profile: str = "historical",
    ) -> list[ScopedUrl]:
        if start_year > end_year:
            raise ValueError("start_year must not exceed end_year")
        output: list[ScopedUrl] = []
        for season_end_year in range(start_year, end_year + 1):
            output.extend(self.season_seeds(season_end_year, profile=profile))
        return output

    def within_season_range(
        self,
        scoped: ScopedUrl,
        start_year: int | None,
        end_year: int | None,
    ) -> bool:
        season = scoped.season_end_year
        if season is None:
            return True
        if start_year is not None and season < start_year:
            return False
        if end_year is not None and season > end_year:
            return False
        return True

    @property
    def families(self) -> tuple[str, ...]:
        return tuple(dict.fromkeys(family for family, _, _ in self._patterns))

    def _scoped_url(
        self,
        *,
        canonical: str,
        family: str,
        groups: tuple[str, ...],
        priority: int,
    ) -> ScopedUrl:
        season_end_year: int | None = None
        team_abbreviation: str | None = None
        entity_id = ":".join(group for group in groups if group is not None)

        if family in {"league", "playoff", "draft", "allstar"}:
            if groups and groups[0].isdigit():
                season_end_year = int(groups[0])
        elif family == "award":
            match = re.search(r"(\d{4})", entity_id)
            if match:
                season_end_year = int(match.group(1))
        elif family == "team_season":
            team_abbreviation = groups[0]
            season_end_year = int(groups[1])
        elif family in {"team_history", "franchise"}:
            team_abbreviation = groups[0]

        prefix = self._source_prefixes[family]
        source_key = f"basketball-reference:{prefix}:{entity_id}" if entity_id else None
        return ScopedUrl(
            url=canonical,
            page_family=family,
            source_key=source_key,
            season_end_year=season_end_year,
            team_abbreviation=team_abbreviation,
            entity_id=entity_id or None,
            priority=priority,
        )
