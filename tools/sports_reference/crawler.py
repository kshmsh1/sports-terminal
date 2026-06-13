from __future__ import annotations

import uuid
from dataclasses import asdict, dataclass
from datetime import datetime, timezone

from .client import SportsReferenceClient
from .page_store import SportsReferencePageStore
from .table_parser import BasketballReferenceTableParser
from .url_scope import BasketballReferenceUrlScope, ScopedUrl


@dataclass(frozen=True)
class CrawlSummary:
    processed: int
    completed: int
    failed: int
    newly_queued: int
    blocked: int = 0
    skipped: int = 0
    run_key: str | None = None
    status: str = "completed"

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


class BasketballReferenceCrawler:
    """Single-worker, resumable crawler with explicit depth and page budgets."""

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

    def plan_seasons(
        self,
        start_year: int,
        end_year: int,
        *,
        profile: str,
    ) -> dict[str, object]:
        seeds = self.scope.season_range_seeds(
            start_year,
            end_year,
            profile=profile,
        )
        return self._plan_document(
            seeds,
            start_year=start_year,
            end_year=end_year,
            profile=profile,
            mode="season-range",
        )

    def plan_site(
        self,
        start_year: int,
        end_year: int,
        *,
        profile: str,
    ) -> dict[str, object]:
        seeds = self.scope.site_seeds(
            start_year,
            end_year,
            profile=profile,
        )
        document = self._plan_document(
            seeds,
            start_year=start_year,
            end_year=end_year,
            profile=profile,
            mode="site-wide",
        )
        document["siteIndexSeedCount"] = len(self.scope.site_index_seeds())
        document["discoveryStrategy"] = (
            "Seed public NBA data indexes and season hubs, then recursively "
            "discover recognized and prefix-scoped linked data pages."
        )
        return document

    def seed_seasons(
        self,
        start_year: int,
        end_year: int,
        *,
        profile: str,
    ) -> int:
        return self._enqueue_many(
            self.scope.season_range_seeds(
                start_year,
                end_year,
                profile=profile,
            )
        )

    def seed_site(
        self,
        start_year: int,
        end_year: int,
        *,
        profile: str,
    ) -> int:
        return self._enqueue_many(
            self.scope.site_seeds(
                start_year,
                end_year,
                profile=profile,
            )
        )

    def _plan_document(
        self,
        seeds: list[ScopedUrl],
        *,
        start_year: int,
        end_year: int,
        profile: str,
        mode: str,
    ) -> dict[str, object]:
        by_family: dict[str, int] = {}
        for scoped in seeds:
            by_family[scoped.page_family] = by_family.get(scoped.page_family, 0) + 1
        return {
            "mode": mode,
            "fromSeason": start_year,
            "toSeason": end_year,
            "profile": profile,
            "seasonCount": end_year - start_year + 1,
            "seedCount": len(seeds),
            "seedCountsByFamily": dict(sorted(by_family.items())),
            "supportedPageFamilies": list(self.scope.families),
            "estimatedMinimumSeconds": round(
                len(seeds) * self.client.minimum_interval_seconds,
                1,
            ),
            "estimateScope": "deterministic seed requests only",
            "seedUrls": [scoped.url for scoped in seeds],
        }

    def _enqueue_many(self, seeds: list[ScopedUrl]) -> int:
        inserted = 0
        for scoped in seeds:
            inserted += int(
                self.store.enqueue(
                    scoped.url,
                    scoped.page_family,
                    depth=0,
                    discovered_from=None,
                    priority=scoped.priority,
                    source_key=scoped.source_key,
                    season_end_year=scoped.season_end_year,
                    team_abbreviation=scoped.team_abbreviation,
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
        start_year: int | None = None,
        end_year: int | None = None,
        stop_on_block: bool = True,
    ) -> CrawlSummary:
        if max_pages < 1 or max_pages > 5000:
            raise ValueError("max_pages must be between 1 and 5000")
        if max_depth < 0 or max_depth > 8:
            raise ValueError("max_depth must be between 0 and 8")
        if start_year is not None and end_year is not None and start_year > end_year:
            raise ValueError("start_year must not exceed end_year")
        unknown = families.difference(self.scope.families)
        if unknown:
            raise ValueError(f"Unknown page families: {sorted(unknown)}")

        self.store.reset_fetching()
        run_key = (
            f"crawl-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-"
            f"{uuid.uuid4().hex[:8]}"
        )
        configuration = {
            "maxPages": max_pages,
            "maxDepth": max_depth,
            "families": sorted(families),
            "force": force,
            "fromSeason": start_year,
            "toSeason": end_year,
            "minimumIntervalSeconds": self.client.minimum_interval_seconds,
            "stopOnBlock": stop_on_block,
        }
        self.store.start_run(run_key, "crawl", configuration)

        processed = completed = failed = newly_queued = blocked = skipped = 0
        status = "completed"
        try:
            while processed < max_pages:
                page = self.store.next_page(max_depth=max_depth, families=families)
                if page is None:
                    break
                processed += 1
                url = str(page["url"])
                depth = int(page["depth"])
                scoped_page = self.scope.classify(url)
                if scoped_page is not None and not self.scope.within_season_range(
                    scoped_page,
                    start_year,
                    end_year,
                ):
                    self.store.mark_skipped(url, "outside requested season range")
                    skipped += 1
                    continue

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
                        status_code=fetch.status_code,
                        content_type=fetch.content_type,
                        html_bytes=len(fetch.html.encode("utf-8")),
                    )
                    completed += 1

                    if depth < max_depth:
                        for link in parsed.discovered_links:
                            scoped = self.scope.classify(str(link["url"]))
                            if scoped is None or scoped.page_family not in families:
                                continue
                            if not self.scope.within_season_range(
                                scoped,
                                start_year,
                                end_year,
                            ):
                                continue
                            newly_queued += int(
                                self.store.enqueue(
                                    scoped.url,
                                    scoped.page_family,
                                    depth=depth + 1,
                                    discovered_from=url,
                                    priority=scoped.priority,
                                    source_key=scoped.source_key,
                                    season_end_year=scoped.season_end_year,
                                    team_abbreviation=scoped.team_abbreviation,
                                )
                            )
                except PermissionError as exc:
                    blocked += 1
                    status = "blocked"
                    self.store.mark_blocked(url, str(exc))
                    if stop_on_block:
                        break
                except RuntimeError as exc:
                    message = str(exc)
                    access_block = any(
                        marker in message
                        for marker in ("HTTP 403", "HTTP 429", "robots.txt")
                    )
                    if access_block:
                        blocked += 1
                        status = "blocked"
                        self.store.mark_blocked(url, message)
                        if stop_on_block:
                            break
                    else:
                        failed += 1
                        status = "completed_with_errors"
                        self.store.mark_failed(url, message, terminal=True)
                except Exception as exc:
                    failed += 1
                    status = "completed_with_errors"
                    self.store.mark_failed(url, str(exc), terminal=True)
        except KeyboardInterrupt:
            status = "interrupted"
        finally:
            summary = CrawlSummary(
                processed=processed,
                completed=completed,
                failed=failed,
                newly_queued=newly_queued,
                blocked=blocked,
                skipped=skipped,
                run_key=run_key,
                status=status,
            )
            self.store.finish_run(run_key, status, summary.to_dict())

        return summary
