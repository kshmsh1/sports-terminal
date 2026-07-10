from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

from .page_store import SportsReferencePageStore
from .url_scope import BASE_URL


@dataclass(frozen=True)
class LinkPromotionSummary:
    candidate_count: int
    inserted_count: int
    existing_count: int
    metadata_update_count: int
    limited: bool
    families: dict[str, int]

    def to_dict(self) -> dict[str, object]:
        return {
            "candidateCount": self.candidate_count,
            "insertedCount": self.inserted_count,
            "existingCount": self.existing_count,
            "metadataUpdateCount": self.metadata_update_count,
            "limited": self.limited,
            "families": self.families,
        }


class StoredLinkPromoter:
    """Promote links already captured from completed pages into the crawl queue.

    Promotion is deterministic and idempotent. Season bounds apply to the
    effective linked-page season. When a linked target lacks explicit season
    metadata, it inherits the completed source page's season. Existing pages may
    therefore receive missing metadata without being requeued or refetched.
    """

    def __init__(self, store: SportsReferencePageStore) -> None:
        self.store = store

    def promote(
        self,
        *,
        families: set[str],
        source_families: set[str] | None = None,
        target_path_prefix: str | None = None,
        start_year: int | None = None,
        end_year: int | None = None,
        source_depth: int | None = None,
        limit: int | None = None,
        dry_run: bool = False,
    ) -> LinkPromotionSummary:
        if not families:
            raise ValueError("At least one target page family is required")
        if source_families is not None and not source_families:
            raise ValueError("source_families must be omitted or non-empty")
        if target_path_prefix is not None and not target_path_prefix.startswith("/"):
            raise ValueError("target_path_prefix must begin with /")
        if start_year is not None and end_year is not None and start_year > end_year:
            raise ValueError("start_year must not exceed end_year")
        if source_depth is not None and source_depth < 0:
            raise ValueError("source_depth must be non-negative")
        if limit is not None and not 1 <= limit <= 100000:
            raise ValueError("limit must be between 1 and 100000")

        inherited_season = "COALESCE(link.season_end_year, source.season_end_year)"
        target_placeholders = ",".join("?" for _ in families)
        clauses = [
            "source.status = 'complete'",
            f"link.page_family IN ({target_placeholders})",
        ]
        params: list[object] = [*sorted(families)]
        if source_families is not None:
            source_placeholders = ",".join("?" for _ in source_families)
            clauses.append(f"source.page_family IN ({source_placeholders})")
            params.extend(sorted(source_families))
        if target_path_prefix is not None:
            clauses.append("link.target_url LIKE ?")
            params.append(f"{BASE_URL}{target_path_prefix}%")
        if start_year is not None:
            clauses.append(f"({inherited_season} IS NULL OR {inherited_season} >= ?)")
            params.append(start_year)
        if end_year is not None:
            clauses.append(f"({inherited_season} IS NULL OR {inherited_season} <= ?)")
            params.append(end_year)
        if source_depth is not None:
            clauses.append("source.depth = ?")
            params.append(source_depth)

        query = f"""
            SELECT
              link.target_url AS url,
              link.page_family AS page_family,
              link.source_key AS source_key,
              {inherited_season} AS season_end_year,
              link.team_abbreviation AS team_abbreviation,
              MIN(link.priority) AS priority,
              MIN(source.depth + 1) AS target_depth,
              MIN(link.source_url) AS discovered_from
            FROM discovered_links AS link
            JOIN pages AS source ON source.url = link.source_url
            WHERE {' AND '.join(clauses)}
            GROUP BY link.target_url, link.page_family, link.source_key,
                     {inherited_season}, link.team_abbreviation
            ORDER BY priority, target_depth, url
        """

        with self.store.connect() as db:
            rows = list(db.execute(query, params))
            existing_pages = {
                row["url"]: row["season_end_year"]
                for row in db.execute(
                    "SELECT url, season_end_year FROM pages "
                    "WHERE url IN (SELECT target_url FROM discovered_links)"
                )
            }

        total_candidates = len(rows)
        selected = rows[:limit] if limit is not None else rows
        counts = Counter(str(row["page_family"]) for row in selected)
        existing_count = sum(1 for row in selected if row["url"] in existing_pages)
        metadata_update_count = sum(
            1
            for row in selected
            if row["url"] in existing_pages
            and existing_pages[row["url"]] is None
            and row["season_end_year"] is not None
        )
        inserted_count = 0

        if not dry_run:
            for row in selected:
                inserted_count += int(
                    self.store.enqueue(
                        str(row["url"]),
                        str(row["page_family"]),
                        depth=int(row["target_depth"]),
                        discovered_from=str(row["discovered_from"]),
                        priority=int(row["priority"]),
                        source_key=row["source_key"],
                        season_end_year=row["season_end_year"],
                        team_abbreviation=row["team_abbreviation"],
                    )
                )

        return LinkPromotionSummary(
            candidate_count=len(selected),
            inserted_count=inserted_count,
            existing_count=existing_count,
            metadata_update_count=metadata_update_count,
            limited=limit is not None and total_candidates > len(selected),
            families=dict(sorted(counts.items())),
        )
