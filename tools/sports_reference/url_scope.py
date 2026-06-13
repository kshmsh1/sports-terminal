from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import parse_qsl, urlencode, urljoin, urlparse, urlunparse

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
    """Canonical catalog for public Basketball Reference NBA data pages.

    Precise patterns assign stable entity metadata to known page families. A
    final, tightly prefix-scoped data-page fallback lets the crawler retain new
    table-bearing HTML routes without accepting arbitrary website surfaces.
    """

    _patterns = (
        ("site_index", re.compile(r"^/$"), 0),
        ("player_index", re.compile(r"^/players/?$"), 4),
        ("player_index", re.compile(r"^/players/([a-z])/?$"), 4),
        ("team_index", re.compile(r"^/teams/?$"), 4),
        ("league_index", re.compile(r"^/leagues/?$"), 4),
        ("playoff_index", re.compile(r"^/playoffs/?$"), 4),
        ("boxscore_index", re.compile(r"^/boxscores/?$"), 4),
        ("draft_index", re.compile(r"^/draft/?$"), 4),
        ("award_index", re.compile(r"^/awards/?$"), 4),
        ("allstar_index", re.compile(r"^/allstar/?$"), 4),
        ("coach_index", re.compile(r"^/coaches/?$"), 4),
        ("executive_index", re.compile(r"^/executives/?$"), 4),
        ("contract_index", re.compile(r"^/contracts/?$"), 4),
        ("referee_index", re.compile(r"^/referees/?$"), 4),
        (
            "league",
            re.compile(r"^/leagues/NBA_(\d{4})(?:_([a-z0-9_-]+))?\.html$"),
            10,
        ),
        (
            "playoff",
            re.compile(r"^/playoffs/NBA_(\d{4})(?:_([a-z0-9_-]+))?\.html$"),
            20,
        ),
        (
            "playoff",
            re.compile(r"^/playoffs/(\d{4})-nba-([a-z0-9-]+)\.html$"),
            25,
        ),
        (
            "team_season_detail",
            re.compile(
                r"^/teams/([A-Z0-9]{2,3})/(\d{4})/"
                r"(gamelog|gamelog-advanced|splits|lineups|on-off)/?$"
            ),
            34,
        ),
        (
            "team_season",
            re.compile(r"^/teams/([A-Z0-9]{2,3})/(\d{4})\.html$"),
            30,
        ),
        (
            "boxscore_detail",
            re.compile(
                r"^/boxscores/(pbp|shot-chart|plus-minus)/([0-9A-Z]+)\.html$",
                re.IGNORECASE,
            ),
            42,
        ),
        (
            "boxscore",
            re.compile(r"^/boxscores/([0-9A-Z]+)\.html$", re.IGNORECASE),
            40,
        ),
        (
            "player_detail",
            re.compile(
                r"^/players/[a-z]/([a-z0-9]+)/"
                r"(gamelog|gamelog-advanced|gamelog-playoffs|splits|shooting|"
                r"on-off|lineups|playoffs)/(\d{4})/?$"
            ),
            54,
        ),
        ("player", re.compile(r"^/players/[a-z]/([a-z0-9]+)\.html$"), 50),
        ("draft", re.compile(r"^/draft/NBA_(\d{4})\.html$"), 35),
        (
            "award",
            re.compile(r"^/awards/(?:awards_)?([a-zA-Z0-9_-]+)\.html$"),
            35,
        ),
        ("allstar", re.compile(r"^/allstar/NBA_(\d{4})\.html$"), 35),
        ("contract", re.compile(r"^/contracts/([A-Za-z0-9_-]+)\.html$"), 60),
        ("referee", re.compile(r"^/referees/([a-z0-9]+)\.html$"), 70),
        ("team_history", re.compile(r"^/teams/([A-Z0-9]{2,3})/?$"), 70),
        (
            "franchise",
            re.compile(
                r"^/teams/([A-Z0-9]{2,3})/"
                r"(stats|players|draft|coaches|executives|transactions|head2head|seasons)\.html$"
            ),
            75,
        ),
        ("coach", re.compile(r"^/coaches/([a-z0-9]+)\.html$"), 80),
        ("executive", re.compile(r"^/executives/([a-z0-9]+)\.html$"), 85),
    )

    _source_prefixes = {
        "site_index": "site-index",
        "player_index": "player-index",
        "team_index": "team-index",
        "league_index": "league-index",
        "playoff_index": "playoff-index",
        "boxscore_index": "boxscore-index",
        "draft_index": "draft-index",
        "award_index": "award-index",
        "allstar_index": "allstar-index",
        "coach_index": "coach-index",
        "executive_index": "executive-index",
        "contract_index": "contract-index",
        "referee_index": "referee-index",
        "league": "season-page",
        "playoff": "playoff",
        "team_season": "team-season",
        "team_season_detail": "team-season-detail",
        "team_history": "team",
        "franchise": "franchise",
        "player": "player",
        "player_detail": "player-detail",
        "boxscore": "game",
        "boxscore_detail": "game-detail",
        "draft": "draft",
        "award": "award",
        "allstar": "allstar",
        "contract": "contract",
        "referee": "referee",
        "coach": "coach",
        "executive": "executive",
        "data_page": "data-page",
    }

    _ignored_prefixes = (
        "/about/",
        "/blog/",
        "/email/",
        "/linker/",
        "/my/",
        "/search/",
        "/short/",
        "/stathead/",
    )

    _fallback_data_prefixes = (
        "/players/",
        "/teams/",
        "/leagues/",
        "/playoffs/",
        "/boxscores/",
        "/draft/",
        "/awards/",
        "/allstar/",
        "/coaches/",
        "/executives/",
        "/contracts/",
        "/referees/",
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

    _site_index_paths = (
        "/",
        "/players/",
        "/teams/",
        "/leagues/",
        "/playoffs/",
        "/boxscores/",
        "/draft/",
        "/awards/",
        "/allstar/",
        "/coaches/",
        "/executives/",
        "/contracts/",
        "/referees/",
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
        query = self._canonical_query(path, parsed.query)
        return urlunparse(
            ("https", "www.basketball-reference.com", path, "", query, "")
        )

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
        if path.endswith(".html") and path.startswith(self._fallback_data_prefixes):
            entity_id = path.strip("/").removesuffix(".html").replace("/", ":")
            return ScopedUrl(
                url=canonical,
                page_family="data_page",
                source_key=f"basketball-reference:data-page:{entity_id}",
                entity_id=entity_id,
                priority=95,
            )
        return None

    def is_allowed(self, url: str, families: set[str] | None = None) -> bool:
        scoped = self.classify(url)
        if scoped is None:
            return False
        return families is None or scoped.page_family in families

    def site_index_seeds(self) -> list[ScopedUrl]:
        urls = [f"{BASE_URL}{path}" for path in self._site_index_paths]
        urls.extend(f"{BASE_URL}/players/{letter}/" for letter in "abcdefghijklmnopqrstuvwxyz")
        return self._classify_unique(urls)

    def season_seeds(self, season_end_year: int, *, profile: str = "core") -> list[ScopedUrl]:
        if season_end_year < 1947 or season_end_year > 2100:
            raise ValueError("season_end_year must be between 1947 and 2100")
        if profile not in {"core", "extended", "historical"}:
            raise ValueError("profile must be core, extended, or historical")

        league_suffixes = ["", "per_game", "totals", "advanced", "games"]
        if profile in {"extended", "historical"}:
            league_suffixes.extend(self._extended_league_suffixes)

        urls = [
            f"{BASE_URL}/leagues/NBA_{season_end_year}"
            f"{'_' + suffix if suffix else ''}.html"
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
        return self._classify_unique(urls)

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

    def site_seeds(
        self,
        start_year: int,
        end_year: int,
        *,
        profile: str = "historical",
    ) -> list[ScopedUrl]:
        return self._dedupe_scoped(
            [
                *self.site_index_seeds(),
                *self.season_range_seeds(start_year, end_year, profile=profile),
            ]
        )

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
        values = [family for family, _, _ in self._patterns]
        values.append("data_page")
        return tuple(dict.fromkeys(values))

    def _classify_unique(self, urls: list[str]) -> list[ScopedUrl]:
        return self._dedupe_scoped(
            [scoped for url in urls if (scoped := self.classify(url)) is not None]
        )

    def _dedupe_scoped(self, values: list[ScopedUrl]) -> list[ScopedUrl]:
        output: list[ScopedUrl] = []
        seen: set[str] = set()
        for scoped in values:
            if scoped.url in seen:
                continue
            seen.add(scoped.url)
            output.append(scoped)
        return output

    def _canonical_query(self, path: str, query: str) -> str:
        if path.rstrip("/") != "/boxscores" or not query:
            return ""
        allowed = {"month", "day", "year"}
        values = [
            (key, value)
            for key, value in parse_qsl(query, keep_blank_values=False)
            if key in allowed and value.isdigit()
        ]
        return urlencode(sorted(values))

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
        elif family in {"team_season", "team_season_detail"}:
            team_abbreviation = groups[0]
            season_end_year = int(groups[1])
        elif family in {"team_history", "franchise"}:
            team_abbreviation = groups[0]
        elif family == "player_detail" and len(groups) >= 3:
            season_end_year = int(groups[2])

        prefix = self._source_prefixes[family]
        source_id = entity_id or "root"
        source_key = f"basketball-reference:{prefix}:{source_id}"
        return ScopedUrl(
            url=canonical,
            page_family=family,
            source_key=source_key,
            season_end_year=season_end_year,
            team_abbreviation=team_abbreviation,
            entity_id=entity_id or None,
            priority=priority,
        )
