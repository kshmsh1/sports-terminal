from __future__ import annotations

from .page_store import SportsReferencePageStore


class SportsReferenceSchemaReview:
    """Separate actionable schema drift from expected cross-page variation."""

    def __init__(self, store: SportsReferencePageStore) -> None:
        self.store = store

    def build(self) -> dict[str, object]:
        with self.store.connect() as db:
            actionable = [
                dict(row)
                for row in db.execute(
                    """
                    SELECT table.table_id AS tableId,
                           page.page_family AS pageFamily,
                           COUNT(*) AS pageCount,
                           COUNT(DISTINCT table.schema_hash) AS schemaVariants,
                           GROUP_CONCAT(DISTINCT table.schema_hash) AS schemaHashes
                    FROM tables AS table
                    JOIN pages AS page ON page.url = table.page_url
                    WHERE table.table_id NOT LIKE 'anonymous_%'
                    GROUP BY table.table_id, page.page_family
                    HAVING COUNT(DISTINCT table.schema_hash) > 1
                    ORDER BY schemaVariants DESC, pageCount DESC, tableId
                    """
                )
            ]
            cross_family = [
                dict(row)
                for row in db.execute(
                    """
                    SELECT table.table_id AS tableId,
                           COUNT(DISTINCT page.page_family) AS pageFamilies,
                           COUNT(DISTINCT table.schema_hash) AS schemaVariants,
                           GROUP_CONCAT(DISTINCT page.page_family) AS families
                    FROM tables AS table
                    JOIN pages AS page ON page.url = table.page_url
                    WHERE table.table_id NOT LIKE 'anonymous_%'
                    GROUP BY table.table_id
                    HAVING COUNT(DISTINCT page.page_family) > 1
                       AND COUNT(DISTINCT table.schema_hash) > 1
                    ORDER BY schemaVariants DESC, tableId
                    """
                )
            ]
            anonymous = db.execute(
                """
                SELECT COUNT(*) AS tableInstances,
                       COUNT(DISTINCT table_id) AS ordinalLabels,
                       SUM(row_count) AS rows
                FROM tables WHERE table_id LIKE 'anonymous_%'
                """
            ).fetchone()
        return {
            "actionableWithinFamily": actionable,
            "expectedCrossFamilyVariation": cross_family,
            "anonymousTableSummary": dict(anonymous),
            "notes": [
                "Only within-family drift is treated as immediately actionable.",
                "The same provider table ID may legitimately differ between regular-season and playoff pages.",
                "anonymous_N labels are page-local ordinals and are not stable identities across pages.",
            ],
        }
