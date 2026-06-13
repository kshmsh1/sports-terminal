from __future__ import annotations

import hashlib
import json
import time
import urllib.robotparser
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup, Comment


@dataclass(frozen=True)
class FetchResult:
    url: str
    html: str
    fetched_at: str
    cache_path: Path
    from_cache: bool
    sha256: str


class SportsReferenceClient:
    """Small, respectful HTTP client for public Basketball Reference pages.

    The client never attempts to bypass access controls. It uses a descriptive
    user agent, honors robots.txt by default, enforces a minimum request delay,
    caches successful responses, and stops on access-denied or rate-limit
    responses.
    """

    allowed_hosts = {
        "basketball-reference.com",
        "www.basketball-reference.com",
    }

    def __init__(
        self,
        *,
        cache_dir: str | Path = ".cache/sports_reference",
        minimum_interval_seconds: float = 3.5,
        user_agent: str = "SportsTerminalResearch/0.1 (local research ingestion)",
        timeout_seconds: float = 30.0,
        respect_robots: bool = True,
    ) -> None:
        if minimum_interval_seconds < 3.0:
            raise ValueError("minimum_interval_seconds must be at least 3.0")
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.minimum_interval_seconds = minimum_interval_seconds
        self.user_agent = user_agent
        self.timeout_seconds = timeout_seconds
        self.respect_robots = respect_robots
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": self.user_agent,
                "Accept": "text/html,application/xhtml+xml",
                "Accept-Language": "en-US,en;q=0.9",
            }
        )
        self._last_request_at = 0.0
        self._robot_parsers: dict[str, urllib.robotparser.RobotFileParser] = {}

    def fetch(self, url: str, *, force: bool = False) -> FetchResult:
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.hostname not in self.allowed_hosts:
            raise ValueError(f"Unsupported Sports Reference URL: {url}")

        cache_path = self._cache_path(url)
        metadata_path = cache_path.with_suffix(".metadata.json")
        if cache_path.exists() and metadata_path.exists() and not force:
            html = cache_path.read_text(encoding="utf-8")
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            return FetchResult(
                url=url,
                html=html,
                fetched_at=metadata["fetchedAt"],
                cache_path=cache_path,
                from_cache=True,
                sha256=metadata["sha256"],
            )

        if self.respect_robots and not self._can_fetch(url):
            raise PermissionError(f"robots.txt does not allow this client to fetch {url}")

        self._wait_for_rate_limit()
        response = self.session.get(url, timeout=self.timeout_seconds)
        self._last_request_at = time.monotonic()
        if response.status_code in {403, 429}:
            raise RuntimeError(
                f"Sports Reference returned HTTP {response.status_code}. "
                "Stop the run and do not retry aggressively."
            )
        response.raise_for_status()
        html = response.text
        digest = hashlib.sha256(html.encode("utf-8")).hexdigest()
        fetched_at = datetime.now(timezone.utc).isoformat()
        cache_path.write_text(html, encoding="utf-8")
        metadata_path.write_text(
            json.dumps(
                {
                    "url": url,
                    "fetchedAt": fetched_at,
                    "sha256": digest,
                    "statusCode": response.status_code,
                    "userAgent": self.user_agent,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        return FetchResult(
            url=url,
            html=html,
            fetched_at=fetched_at,
            cache_path=cache_path,
            from_cache=False,
            sha256=digest,
        )

    def expanded_soup(self, html: str) -> BeautifulSoup:
        """Return a soup where HTML tables inside comments are also visible."""
        soup = BeautifulSoup(html, "lxml")
        for comment in list(soup.find_all(string=lambda text: isinstance(text, Comment))):
            comment_text = str(comment)
            if "<table" not in comment_text:
                continue
            fragment = BeautifulSoup(comment_text, "lxml")
            comment.replace_with(fragment)
        return soup

    def find_table(self, html: str, table_ids: Iterable[str]):
        soup = self.expanded_soup(html)
        for table_id in table_ids:
            table = soup.find("table", id=table_id)
            if table is not None:
                return table, table_id
        available = sorted(
            table.get("id")
            for table in soup.find_all("table")
            if table.get("id")
        )
        raise LookupError(
            f"None of the requested tables were found. Available table IDs: {available}"
        )

    def list_table_ids(self, html: str) -> list[str]:
        soup = self.expanded_soup(html)
        return sorted(
            table.get("id")
            for table in soup.find_all("table")
            if table.get("id")
        )

    def _wait_for_rate_limit(self) -> None:
        elapsed = time.monotonic() - self._last_request_at
        wait_seconds = self.minimum_interval_seconds - elapsed
        if wait_seconds > 0:
            time.sleep(wait_seconds)

    def _cache_path(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
        return self.cache_dir / f"{digest}.html"

    def _can_fetch(self, url: str) -> bool:
        parsed = urlparse(url)
        origin = f"{parsed.scheme}://{parsed.netloc}"
        parser = self._robot_parsers.get(origin)
        if parser is None:
            parser = urllib.robotparser.RobotFileParser()
            parser.set_url(f"{origin}/robots.txt")
            try:
                parser.read()
            except Exception as exc:  # fail closed
                raise RuntimeError(f"Unable to verify robots.txt for {origin}: {exc}") from exc
            self._robot_parsers[origin] = parser
        return parser.can_fetch(self.user_agent, url)
