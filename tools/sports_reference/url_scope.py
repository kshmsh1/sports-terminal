from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin, urlparse, urlunparse

BASE_URL = "https://www.basketball-reference.com"


@dataclass(frozen=True)
class ScopedUrl:
    url: str
    page_family: str


class BasketballReferenceUrlScope:
    _patterns = (
        ("league", re.compile(r"^/leagues/NBA_\d{4}(?:_[a-z0-9_-]+)?\.html$")),
        ("team_season", re.compile(r"^/teams/[A-Z]{3}/\d{4}\.html$")),
        ("team_history", re.compile(r"^/teams/[A-Z]{3}/?$")),
        ("player", re.compile(r"^/players/[a-z]/[a-z0-9]+\.html$")),
        ("boxscore", re.compile(r"^/boxscores/[0-9A-Z]+\.html$")),
        ("playoff", re.compile(r"^/playoffs/(?:NBA_\d{4}|\d{4}-nba-[a-z0-9-]+)\.html$")),
        ("draft", re.compile(r"^/draft/NBA_\d{4}\.html$")),
        ("award", re.compile(r"^/awards/[a-zA-Z0-9_-]+\.html$")),
        ("coach", re.compile(r"^/coaches/[a-z0-9]+\.html$")),
        ("executive", re.compile(r"^/executives/[a-z0-9]+\.html$")),
        ("franchise", re.compile(r"^/teams/[A-Z]{3}/(?:stats|players|draft)\.html$")),
    )

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
        if parsed.path.startswith(self._ignored_prefixes):
            return None
        return urlunparse(
            (
                "https",
                "www.basketball-reference.com",
                parsed.path or "/",
                "",
                "",
                "",
            )
        )

    def classify(self, url: str) -> ScopedUrl | None:
        canonical = self.canonicalize(url)
        if canonical is None:
            return None
        path = urlparse(canonical).path
        for family, pattern in self._patterns:
            if pattern.fullmatch(path):
                return ScopedUrl(url=canonical, page_family=family)
        return None

    def is_allowed(self, url: str, families: set[str] | None = None) -> bool:
        scoped = self.classify(url)
        if scoped is None:
            return False
        return families is None or scoped.page_family in families

    def season_seeds(self, season_end_year: int, *, profile: str = "core") -> list[ScopedUrl]:
        if season_end_year < 1947 or season_end_year > 2100:
            raise ValueError("season_end_year must be between 1947 and 2100")
        suffixes = ["", "_per_game", "_totals", "_advanced"]
        if profile == "extended":
            suffixes.extend(
                [
                    "_per_minute",
                    "_per_poss",
                    "_shooting",
                    "_adj_shooting",
                    "_play-by-play",
                    "_rookies",
                ]
            )
        elif profile != "core":
            raise ValueError("profile must be core or extended")

        urls = [
            f"{BASE_URL}/leagues/NBA_{season_end_year}{suffix}.html"
            for suffix in suffixes
        ]
        urls.extend(
            [
                f"{BASE_URL}/playoffs/NBA_{season_end_year}.html",
                f"{BASE_URL}/draft/NBA_{season_end_year}.html",
            ]
        )
        return [
            scoped
            for url in urls
            if (scoped := self.classify(url)) is not None
        ]

    @property
    def families(self) -> tuple[str, ...]:
        return tuple(family for family, _ in self._patterns)
