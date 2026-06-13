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
    status_code: int = 200
    content_type: str = "text/html"


class SportsReferenceClient:
    """Respectful HTTP client for public Basketball Reference pages.

    It does not bypass access controls. Network requests use a descriptive user
    agent, a strict host allowlist, robots.txt checks, a minimum interval,
    bounded retries for transient server failures, and an on-disk cache.
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
        user_agent: str = "SportsTerminalResearch/0.2 (local research ingestion)",
        timeout_seconds: float = 30.0,
        respect_robots: bool = True,
        max_transient_retries: int = 2,
    ) -> None:
        if minimum_interval_seconds < 3.0:
            raise ValueError("minimum_interval_seconds must be at least 3.0")
        if max_transient_retries < 0 or max_transient_retries > 3:
            raise ValueError("max_transient_retries must be between 0 and 3")
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.minimum_interval_seconds = minimum_interval_seconds
        self.user_agent = user_agent
        self.timeout_seconds = timeout_seconds
        self.respect_robots = respect_robots
        self.max_transient_retries = max_transient_retries
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": self.user_agent,
                "Accept": "text/html,application/xhtml+xml",
                "Accept-Language": "en-US,en;q=0.9",
                "Connection": "keep-alive",
            }
        )
        self._last_request_at = 0.0
        self._robot_parsers: dict[str, urllib.robotparser.RobotFileParser] = {}

    def fetch(self, url: str, *, force: bool = False) -> FetchResult:
        normalized_url = self._validate_url(url)
        cache_path = self._cache_path(normalized_url)
        metadata_path = cache_path.with_suffix(".metadata.json")
        if cache_path.exists() and metadata_path.exists() and not force:
            html = cache_path.read_text(encoding="utf-8")
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            return FetchResult(
                url=normalized_url,
                html=html,
                fetched_at=metadata["fetchedAt"],
                cache_path=cache_path,
                from_cache=True,
                sha256=metadata["sha256"],
                status_code=int(metadata.get("statusCode", 200)),
                content_type=str(metadata.get("contentType", "text/html")),
            )

        if self.respect_robots and not self._can_fetch(normalized_url):
            raise PermissionError(
                f"robots.txt does not allow this client to fetch {normalized_url}"
            )

        response = self._request_with_bounded_retry(normalized_url)
        content_type = response.headers.get("Content-Type", "").split(";", 1)[0].strip()
        if content_type and content_type not in {
            "text/html",
            "application/xhtml+xml",
        }:
            raise RuntimeError(
                f"Expected HTML from {normalized_url}, received {content_type}"
            )
        html = response.text
        digest = hashlib.sha256(html.encode("utf-8")).hexdigest()
        fetched_at = datetime.now(timezone.utc).isoformat()
        self._atomic_write(cache_path, html)
        self._atomic_write(
            metadata_path,
            json.dumps(
                {
                    "url": normalized_url,
                    "fetchedAt": fetched_at,
                    "sha256": digest,
                    "statusCode": response.status_code,
                    "contentType": content_type or "text/html",
                    "userAgent": self.user_agent,
                },
                indent=2,
            )
            + "\n",
        )
        return FetchResult(
            url=normalized_url,
            html=html,
            fetched_at=fetched_at,
            cache_path=cache_path,
            from_cache=False,
            sha256=digest,
            status_code=response.status_code,
            content_type=content_type or "text/html",
        )

    def expanded_soup(self, html: str) -> BeautifulSoup:
        """Return a soup where tables wrapped in HTML comments are visible."""
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

    def _request_with_bounded_retry(self, url: str) -> requests.Response:
        transient = {500, 502, 503, 504}
        for attempt in range(self.max_transient_retries + 1):
            self._wait_for_rate_limit()
            response = self.session.get(url, timeout=self.timeout_seconds)
            self._last_request_at = time.monotonic()
            if response.status_code in {403, 429}:
                raise RuntimeError(
                    f"Sports Reference returned HTTP {response.status_code}. "
                    "The run has stopped and should not be retried aggressively."
                )
            if response.status_code not in transient or attempt == self.max_transient_retries:
                response.raise_for_status()
                return response
            time.sleep(min(2 ** attempt, 4))
        raise RuntimeError(f"Unable to fetch {url}")

    def _validate_url(self, url: str) -> str:
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.hostname not in self.allowed_hosts:
            raise ValueError(f"Unsupported Sports Reference URL: {url}")
        return url

    def _wait_for_rate_limit(self) -> None:
        elapsed = time.monotonic() - self._last_request_at
        wait_seconds = self.minimum_interval_seconds - elapsed
        if wait_seconds > 0:
            time.sleep(wait_seconds)

    def _cache_path(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
        return self.cache_dir / f"{digest}.html"

    def _robots_cache_path(self, origin: str) -> Path:
        digest = hashlib.sha256(origin.encode("utf-8")).hexdigest()
        path = self.cache_dir / "robots"
        path.mkdir(parents=True, exist_ok=True)
        return path / f"{digest}.txt"

    def _can_fetch(self, url: str) -> bool:
        parsed = urlparse(url)
        origin = f"{parsed.scheme}://{parsed.netloc}"
        parser = self._robot_parsers.get(origin)
        if parser is None:
            robots_url = f"{origin}/robots.txt"
            cache_path = self._robots_cache_path(origin)
            if cache_path.exists():
                robots_text = cache_path.read_text(encoding="utf-8")
            else:
                self._wait_for_rate_limit()
                response = self.session.get(robots_url, timeout=self.timeout_seconds)
                self._last_request_at = time.monotonic()
                if response.status_code in {403, 429}:
                    raise RuntimeError(
                        f"Unable to verify robots.txt: HTTP {response.status_code}. "
                        "The client fails closed."
                    )
                response.raise_for_status()
                robots_text = response.text
                self._atomic_write(cache_path, robots_text)
            parser = urllib.robotparser.RobotFileParser()
            parser.set_url(robots_url)
            parser.parse(robots_text.splitlines())
            self._robot_parsers[origin] = parser
        return parser.can_fetch(self.user_agent, url)

    def _atomic_write(self, path: Path, content: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(content, encoding="utf-8")
        temporary.replace(path)
