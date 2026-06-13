from __future__ import annotations

from dataclasses import dataclass

from .client import SportsReferenceClient
from .page_store import SportsReferencePageStore
from .table_parser import BasketballReferenceTableParser
from .url_scope import BasketballReferenceUrlScope


@dataclass(frozen=True)
class CrawlSummary:
    processed: int
    completed: int
    failed: int
    newly_queued: int


class BasketballReferenceCrawler:
    def __init__(
        self,
        *,
        client: SportsReferenceClient,
        store: SportsReferencePageStore,
        scope: BasketballReferenceUrlScope,
    ) -> None:
        self.client = client
        self.store = store
        self.scope = scope
        self.parser = BasketballReferenceTableParser(scope)

    def seed_seasons(
        self,
        start_year: int,
        end_year: int,
        *,
        profile: str,
    ) -> int:
        if start_year > end_year:
            raise ValueError("start_year must not exceed end_year")
        inserted = 0
        for season_end_year in range(start_year, end_year + 1):
            for scoped in self.scope.season_seeds(season_end_year, profile=profile):
                inserted += int(
                    self.store.enqueue(
                        scoped.url,
                        scoped.page_family,
                        depth=0,
                        discovered_from=None,
                    )
                )
        return inserted

    def crawl(
        self,
        *,
        max_pages: int,
        max_depth: int,
        families: set[str],
        force: bool = False,
    ) -> CrawlSummary:
        if max_pages < 1:
            raise ValueError("max_pages must be positive")
        self.store.reset_fetching()
        processed = completed = failed = newly_queued = 0

        while processed < max_pages:
            page = self.store.next_page(max_depth=max_depth, families=families)
            if page is None:
                break
            processed += 1
            url = page["url"]
            depth = int(page["depth"])
            try:
                fetch = self.client.fetch(url, force=force)
                soup = self.client.expanded_soup(fetch.html)
                parsed = self.parser.parse(
                    fetch.html,
                    source_url=url,
                    expanded_soup=soup,
                )
                self.store.save_page(
                    url=url,
                    parsed=parsed,
                    fetched_at=fetch.fetched_at,
                    source_sha256=fetch.sha256,
                    cache_path=str(fetch.cache_path),
                )
                completed += 1

                if depth < max_depth:
                    for link in parsed.discovered_links:
                        family = str(link["pageFamily"])
                        if family not in families:
                            continue
                        newly_queued += int(
                            self.store.enqueue(
                                str(link["url"]),
                                family,
                                depth=depth + 1,
                                discovered_from=url,
                            )
                        )
            except Exception as exc:
                failed += 1
                self.store.mark_failed(url, str(exc), terminal=True)
                if "HTTP 403" in str(exc) or "HTTP 429" in str(exc):
                    break

        return CrawlSummary(
            processed=processed,
            completed=completed,
            failed=failed,
            newly_queued=newly_queued,
        )
