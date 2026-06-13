from __future__ import annotations

import hashlib
import sqlite3
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from bs4 import BeautifulSoup, Comment

from sports_reference.crawler import BasketballReferenceCrawler
from sports_reference.page_store import SportsReferencePageStore
from sports_reference.table_parser import BasketballReferenceTableParser
from sports_reference.url_scope import BasketballReferenceUrlScope


PAGE_HTML = """
<html>
<head>
  <title>2024-25 NBA Season Summary</title>
  <link rel="canonical" href="https://www.basketball-reference.com/leagues/NBA_2025.html">
</head>
<body>
<h1>2024-25 NBA Season Summary</h1>
<a href="/teams/BOS/2025.html">Boston Celtics</a>
<a href="/players/t/tatumja01.html">Jayson Tatum</a>
<!--
<table id="per_game-team">
<thead><tr>
  <th data-stat="ranker">Rk</th>
  <th data-stat="team_name">Team</th>
  <th data-stat="wins">W</th>
  <th data-stat="win_pct">W/L%</th>
</tr></thead>
<tbody>
  <tr><th colspan="4">Regular Season</th></tr>
  <tr>
    <th data-stat="ranker">1</th>
    <td data-stat="team_name"><a href="/teams/BOS/2025.html">Boston Celtics*</a></td>
    <td data-stat="wins">61</td>
    <td data-stat="win_pct">74.4%</td>
  </tr>
</tbody>
</table>
-->
</body>
</html>
"""


class FakeClient:
    minimum_interval_seconds = 4.0

    def __init__(self, cache_dir: Path, html: str = PAGE_HTML) -> None:
        self.cache_dir = cache_dir
        self.html = html
        self.fetch_count = 0

    def expanded_soup(self, html: str):
        soup = BeautifulSoup(html, "lxml")
        for comment in list(
            soup.find_all(string=lambda text: isinstance(text, Comment))
        ):
            if "<table" in str(comment):
                comment.replace_with(BeautifulSoup(str(comment), "lxml"))
        return soup

    def fetch(self, url: str, *, force: bool = False):
        self.fetch_count += 1
        cache_path = self.cache_dir / f"page-{self.fetch_count}.html"
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(self.html, encoding="utf-8")
        return SimpleNamespace(
            url=url,
            html=self.html,
            fetched_at="2026-06-13T00:00:00+00:00",
            cache_path=cache_path,
            from_cache=False,
            sha256=hashlib.sha256(self.html.encode("utf-8")).hexdigest(),
            status_code=200,
            content_type="text/html",
        )


class HistoricalUrlScopeTest(unittest.TestCase):
    def test_classifies_provider_routes_and_source_keys(self) -> None:
        scope = BasketballReferenceUrlScope()
        team = scope.classify(
            "http://basketball-reference.com/teams/BOS/2025.html?output=1#stats"
        )
        self.assertIsNotNone(team)
        self.assertEqual(
            team.url,
            "https://www.basketball-reference.com/teams/BOS/2025.html",
        )
        self.assertEqual(team.page_family, "team_season")
        self.assertEqual(team.team_abbreviation, "BOS")
        self.assertEqual(team.season_end_year, 2025)
        self.assertEqual(
            team.source_key,
            "basketball-reference:team-season:BOS:2025",
        )

        playoff = scope.classify(
            "https://www.basketball-reference.com/playoffs/NBA_2025_advanced.html"
        )
        self.assertIsNotNone(playoff)
        self.assertEqual(playoff.page_family, "playoff")
        self.assertEqual(playoff.season_end_year, 2025)

        detail = scope.classify(
            "https://www.basketball-reference.com/boxscores/pbp/202506010OKC.html"
        )
        self.assertIsNotNone(detail)
        self.assertEqual(detail.page_family, "boxscore_detail")

    def test_historical_seed_profile_is_deterministic_and_broad(self) -> None:
        scope = BasketballReferenceUrlScope()
        seeds = scope.season_seeds(2025, profile="historical")
        urls = [seed.url for seed in seeds]
        self.assertEqual(len(urls), len(set(urls)))
        self.assertGreaterEqual(len(urls), 20)
        self.assertIn(
            "https://www.basketball-reference.com/leagues/NBA_2025_games.html",
            urls,
        )
        self.assertIn(
            "https://www.basketball-reference.com/playoffs/NBA_2025_advanced.html",
            urls,
        )
        self.assertIn(
            "https://www.basketball-reference.com/awards/awards_2025.html",
            urls,
        )


class HistoricalTableParserTest(unittest.TestCase):
    def test_preserves_comment_table_sections_display_and_provider_links(self) -> None:
        scope = BasketballReferenceUrlScope()
        client = FakeClient(Path(".cache/test_historical_catalog"))
        parser = BasketballReferenceTableParser(scope)
        parsed = parser.parse(
            PAGE_HTML,
            source_url="https://www.basketball-reference.com/leagues/NBA_2025.html",
            expanded_soup=client.expanded_soup(PAGE_HTML),
        )

        self.assertEqual(parsed.title, "2024-25 NBA Season Summary")
        self.assertEqual(parsed.page_family, "league")
        self.assertEqual(parsed.season_end_year, 2025)
        self.assertEqual(len(parsed.tables), 1)
        table = parsed.tables[0]
        self.assertEqual(table.table_id, "per_game-team")
        self.assertEqual(len(table.rows), 1)
        self.assertEqual(table.rows[0]["section"], "Regular Season")
        self.assertEqual(table.rows[0]["values"]["wins"], 61)
        self.assertEqual(table.rows[0]["values"]["win_pct"], 0.744)
        self.assertEqual(table.rows[0]["display"]["win_pct"], "74.4%")
        self.assertEqual(
            table.rows[0]["links"][0]["sourceKey"],
            "basketball-reference:team-season:BOS:2025",
        )
        self.assertEqual(len(table.schema_hash), 64)


class HistoricalWarehouseTest(unittest.TestCase):
    def test_migrates_the_original_catalog_schema_without_data_loss(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "legacy.sqlite"
            db = sqlite3.connect(database)
            db.executescript(
                """
                CREATE TABLE pages (
                  url TEXT PRIMARY KEY,
                  page_family TEXT NOT NULL,
                  status TEXT NOT NULL DEFAULT 'queued',
                  depth INTEGER NOT NULL DEFAULT 0,
                  discovered_from TEXT,
                  attempts INTEGER NOT NULL DEFAULT 0,
                  title TEXT,
                  fetched_at TEXT,
                  source_sha256 TEXT,
                  cache_path TEXT,
                  table_count INTEGER NOT NULL DEFAULT 0,
                  link_count INTEGER NOT NULL DEFAULT 0,
                  last_error TEXT,
                  updated_at TEXT NOT NULL
                );
                CREATE TABLE tables (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  page_url TEXT NOT NULL,
                  table_id TEXT NOT NULL,
                  ordinal INTEGER NOT NULL,
                  caption TEXT,
                  columns_json TEXT NOT NULL,
                  row_count INTEGER NOT NULL
                );
                CREATE TABLE table_rows (
                  table_pk INTEGER NOT NULL,
                  row_index INTEGER NOT NULL,
                  source_row_index INTEGER,
                  row_class TEXT,
                  values_json TEXT NOT NULL,
                  links_json TEXT NOT NULL
                );
                CREATE TABLE discovered_links (
                  source_url TEXT NOT NULL,
                  target_url TEXT NOT NULL,
                  page_family TEXT NOT NULL,
                  anchor_text TEXT
                );
                CREATE TABLE runs (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  started_at TEXT NOT NULL,
                  finished_at TEXT,
                  mode TEXT NOT NULL,
                  configuration_json TEXT NOT NULL,
                  summary_json TEXT
                );
                INSERT INTO pages(
                  url, page_family, status, updated_at
                ) VALUES (
                  'https://www.basketball-reference.com/leagues/NBA_2025.html',
                  'league', 'queued', '2026-06-13T00:00:00+00:00'
                );
                """
            )
            db.commit()
            db.close()

            store = SportsReferencePageStore(database)
            status = store.status()
            self.assertEqual(status["pages"]["queued"], 1)
            with store.connect() as migrated:
                columns = {
                    row["name"] for row in migrated.execute("PRAGMA table_info(pages)")
                }
            self.assertIn("priority", columns)
            self.assertIn("source_key", columns)
            self.assertIn("snapshot_path", columns)

    def test_crawler_persists_tables_entities_snapshots_and_resumable_queue(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = SportsReferencePageStore(
                root / "catalog.sqlite",
                snapshot_root=root / "snapshots",
            )
            scope = BasketballReferenceUrlScope()
            client = FakeClient(root / "cache")
            crawler = BasketballReferenceCrawler(
                client=client,
                store=store,
                scope=scope,
            )
            queued = crawler.seed_seasons(2025, 2025, profile="historical")
            self.assertGreaterEqual(queued, 20)

            summary = crawler.crawl(
                max_pages=1,
                max_depth=1,
                families={"league", "team_season", "player"},
                start_year=2025,
                end_year=2025,
            )
            self.assertEqual(summary.completed, 1)
            self.assertEqual(summary.failed, 0)
            status = store.status()
            self.assertEqual(status["tables"], 1)
            self.assertEqual(status["rows"], 1)
            self.assertGreaterEqual(status["sourceEntities"], 2)
            self.assertIsNotNone(status["latestRun"])
            self.assertTrue(list((root / "snapshots").rglob("*.json.gz")))
            self.assertGreaterEqual(status["pages"].get("queued", 0), 1)

    def test_schema_drift_report_detects_changed_columns(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = SportsReferencePageStore(root / "catalog.sqlite")
            scope = BasketballReferenceUrlScope()
            parser = BasketballReferenceTableParser(scope)
            client = FakeClient(root / "cache")

            first_url = "https://www.basketball-reference.com/leagues/NBA_2025.html"
            first_scoped = scope.classify(first_url)
            store.enqueue(
                first_url,
                first_scoped.page_family,
                source_key=first_scoped.source_key,
                season_end_year=first_scoped.season_end_year,
                priority=first_scoped.priority,
            )
            parsed = parser.parse(
                PAGE_HTML,
                source_url=first_url,
                expanded_soup=client.expanded_soup(PAGE_HTML),
            )
            store.save_page(
                url=first_url,
                parsed=parsed,
                fetched_at="2026-06-13T00:00:00+00:00",
                source_sha256="a" * 64,
                cache_path="first.html",
            )

            second_html = PAGE_HTML.replace(
                '<th data-stat="win_pct">W/L%</th>',
                '<th data-stat="losses">L</th>',
            ).replace(
                '<td data-stat="win_pct">74.4%</td>',
                '<td data-stat="losses">21</td>',
            ).replace("NBA_2025.html", "NBA_2024.html")
            second_url = "https://www.basketball-reference.com/leagues/NBA_2024.html"
            second_scoped = scope.classify(second_url)
            store.enqueue(
                second_url,
                second_scoped.page_family,
                source_key=second_scoped.source_key,
                season_end_year=second_scoped.season_end_year,
                priority=second_scoped.priority,
            )
            parsed_second = parser.parse(
                second_html,
                source_url=second_url,
                expanded_soup=client.expanded_soup(second_html),
            )
            store.save_page(
                url=second_url,
                parsed=parsed_second,
                fetched_at="2026-06-13T00:00:00+00:00",
                source_sha256="b" * 64,
                cache_path="second.html",
            )

            drift = store.schema_drift()
            self.assertEqual(len(drift), 1)
            self.assertEqual(drift[0]["tableId"], "per_game-team")
            self.assertEqual(drift[0]["schemaVariants"], 2)


if __name__ == "__main__":
    unittest.main()
