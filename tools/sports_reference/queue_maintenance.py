from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

from .page_store import SportsReferencePageStore


@dataclass(frozen=True)
class QueuePruneSummary:
    matched_count: int
    deleted_count: int
    statuses: dict[str, int]
    families: dict[str, int]
    dry_run: bool

    def to_dict(self) -> dict[str, object]:
        return {
            "matchedCount": self.matched_count,
            "deletedCount": self.deleted_count,
            "statuses": self.statuses,
            "families": self.families,
            "dryRun": self.dry_run,
        }


class QueueMaintenance:
    """Safe maintenance operations for pages that have not been fetched.

    Pruning never deletes completed pages, tables, snapshots, or raw HTML. It
    only removes queued, skipped, or failed page records whose known target
    season falls outside the requested range.
    """

    removable_statuses = ("queued", "skipped", "failed")

    def __init__(self, store: SportsReferencePageStore) -> None:
        self.store = store

    def prune_outside_season_range(
        self,
        *,
        families: set[str],
        start_year: int,
        end_year: int,
        dry_run: bool = False,
    ) -> QueuePruneSummary:
        if not families:
            raise ValueError("At least one page family is required")
        if start_year > end_year:
            raise ValueError("start_year must not exceed end_year")

        family_placeholders = ",".join("?" for _ in families)
        status_placeholders = ",".join("?" for _ in self.removable_statuses)
        params: list[object] = [
            *sorted(families),
            *self.removable_statuses,
            start_year,
            end_year,
        ]
        where = f"""
            page_family IN ({family_placeholders})
            AND status IN ({status_placeholders})
            AND season_end_year IS NOT NULL
            AND (season_end_year < ? OR season_end_year > ?)
        """

        with self.store.connect() as db:
            rows = list(
                db.execute(
                    f"""
                    SELECT url, page_family, status, season_end_year
                    FROM pages
                    WHERE {where}
                    ORDER BY page_family, season_end_year, url
                    """,
                    params,
                )
            )
            if not dry_run and rows:
                db.execute(f"DELETE FROM pages WHERE {where}", params)

        statuses = Counter(str(row["status"]) for row in rows)
        family_counts = Counter(str(row["page_family"]) for row in rows)
        return QueuePruneSummary(
            matched_count=len(rows),
            deleted_count=0 if dry_run else len(rows),
            statuses=dict(sorted(statuses.items())),
            families=dict(sorted(family_counts.items())),
            dry_run=dry_run,
        )
