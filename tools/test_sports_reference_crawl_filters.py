from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from bs4 import BeautifulSoup

from sports_reference.crawler import BasketballReferenceCrawler
from sports_reference.page_store import SportsReferencePageStore
from sports_reference.url_scope import BasketballReferenceUrlScope


class FakeDetailClient:
    minimum_interval_seconds = 7.0

    def __init__(self, cache_dir: Path) -> None:
        self.cache_dir = cache_dir
        self.fetched_urls: list[str] = []

    def expanded_soup(self, html: str):
        return BeautifulSoup(html, "lxml")

    def fetch(self, url: str, *, force: bool = False):
        self.fetched_urls.append(url)
        game_id = "202504190OKC"
        html = f"""
        <html>
          <head><title>Play-by-Play</title><link rel="canonical" href="{url}"></head>
          <body>
            <a href="/boxscores/shot-chart/{game_id}.html">Shot Chart</a>
            <a href="/boxscores/plus-minus/{game_id}.html">Plus/Minus</a>
            <table id="pbp"><tbody>
              <tr><td data-stat="time">12:00.0</td></tr>
            </tbody></table>
          </body>
        </html>
        """
        cache_path = self.cache_dir / "detail.html"
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(html, encoding="utf-8")
        return SimpleNamespace(
            url=url,
            html=html,
            fetched_at="2026-06-14T00:00:00+00:00",
            cache_path=cache_path,
            from_cache=False,
            sha256=hashlib.sha256(html.encode("utf-8")).hexdigest(),
            status_code=200,
            content_type="text/html",
        )


class CrawlPathFilterTest(unittest.TestCase):
    def test_processes_and_discovers_only_matching_detail_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = SportsReferencePageStore(root / "catalog.sqlite")
            pbp_url = (
                "https://www.basketball-reference.com/boxscores/pbp/"
                "202504190OKC.html"
            )
            shot_url = (
                "https://www.basketball-reference.com/boxscores/shot-chart/"
                "202504190OKC.html"
            )
            plus_minus_url = (
                "https://www.basketball-reference.com/boxscores/plus-minus/"
                "202504190OKC.html"
            )
            store.enqueue(
                pbp_url,
                "boxscore_detail",
                depth=2,
                season_end_year=2025,
                priority=42,
            )
            store.enqueue(
                shot_url,
                "boxscore_detail",
                depth=2,
                season_end_year=2025,
                priority=42,
            )

            client = FakeDetailClient(root / "cache")
            crawler = BasketballReferenceCrawler(
                client=client,
                store=store,
                scope=BasketballReferenceUrlScope(),
            )
            summary = crawler.crawl(
                max_pages=1,
                max_depth=3,
                families={"boxscore_detail"},
                start_year=2025,
                end_year=2025,
                target_path_prefix="/boxscores/pbp/",
            )

            self.assertEqual(summary.completed, 1)
            self.assertEqual(summary.newly_queued, 0)
            self.assertEqual(client.fetched_urls, [pbp_url])
            with store.connect() as db:
                statuses = {
                    row["url"]: row["status"]
                    for row in db.execute(
                        "SELECT url, status FROM pages ORDER BY url"
                    )
                }
            self.assertEqual(statuses[pbp_url], "complete")
            self.assertEqual(statuses[shot_url], "queued")
            self.assertNotIn(plus_minus_url, statuses)


if __name__ == "__main__":
    unittest.main()
