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
                    SELECT tbl.table_id AS tableId,
                           pg.page_family AS pageFamily,
                           COUNT(*) AS pageCount,
                           COUNT(DISTINCT tbl.schema_hash) AS schemaVariants,
                           GROUP_CONCAT(DISTINCT tbl.schema_hash) AS schemaHashes
                    FROM tables AS tbl
                    JOIN pages AS pg ON pg.url = tbl.page_url
                    WHERE tbl.table_id NOT LIKE 'anonymous_%'
                    GROUP BY tbl.table_id, pg.page_family
                    HAVING COUNT(DISTINCT tbl.schema_hash) > 1
                    ORDER BY schemaVariants DESC, pageCount DESC, tableId
                    """
                )
            ]
            cross_family = [
                dict(row)
                for row in db.execute(
                    """
                    SELECT tbl.table_id AS tableId,
                           COUNT(DISTINCT pg.page_family) AS pageFamilies,
                           COUNT(DISTINCT tbl.schema_hash) AS schemaVariants,
                           GROUP_CONCAT(DISTINCT pg.page_family) AS families
                    FROM tables AS tbl
                    JOIN pages AS pg ON pg.url = tbl.page_url
                    WHERE tbl.table_id NOT LIKE 'anonymous_%'
                    GROUP BY tbl.table_id
                    HAVING COUNT(DISTINCT pg.page_family) > 1
                       AND COUNT(DISTINCT tbl.schema_hash) > 1
                    ORDER BY schemaVariants DESC, tableId
                    """
                )
            ]
            anonymous = db.execute(
                """
                SELECT COUNT(*) AS tableInstances,
                       COUNT(DISTINCT table_id) AS ordinalLabels,
                       COALESCE(SUM(row_count), 0) AS rows
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
