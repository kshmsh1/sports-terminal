from __future__ import annotations

import argparse
import json
import sqlite3
from collections import defaultdict
from pathlib import Path
from typing import Any

DEFAULT_DATABASE = "raw/basketball_reference/catalog.sqlite"
DEFAULT_OUTPUT = "raw/basketball_reference/catalog_audit"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Inspect the completed Basketball Reference raw catalog and write "
            "season/page/table inventory reports without making network requests."
        )
    )
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--season", type=int, default=2025)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--sample-limit", type=int, default=3)
    return parser.parse_args()


def connect(path: str | Path) -> sqlite3.Connection:
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    return db


def fetch_all(db: sqlite3.Connection, query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    return [dict(row) for row in db.execute(query, params)]


def page_status_summary(db: sqlite3.Connection) -> list[dict[str, Any]]:
    return fetch_all(
        db,
        """
        SELECT page_family AS pageFamily,
               status,
               depth,
               season_end_year AS seasonEndYear,
               COUNT(*) AS pageCount,
               COALESCE(SUM(table_count), 0) AS tableCount,
               COALESCE(SUM(link_count), 0) AS linkCount,
               COALESCE(SUM(html_bytes), 0) AS htmlBytes
        FROM pages
        GROUP BY page_family, status, depth, season_end_year
        ORDER BY page_family, status, depth, season_end_year
        """,
    )


def season_completion_summary(db: sqlite3.Connection, season: int) -> dict[str, Any]:
    season_rows = fetch_all(
        db,
        """
        SELECT page_family AS pageFamily,
               status,
               COUNT(*) AS pageCount,
               COALESCE(SUM(table_count), 0) AS tableCount,
               COALESCE(SUM(link_count), 0) AS linkCount,
               COALESCE(SUM(html_bytes), 0) AS htmlBytes
        FROM pages
        WHERE season_end_year = ?
        GROUP BY page_family, status
        ORDER BY page_family, status
        """,
        (season,),
    )
    incomplete_rows = fetch_all(
        db,
        """
        SELECT page_family AS pageFamily,
               status,
               depth,
               season_end_year AS seasonEndYear,
               COUNT(*) AS pageCount
        FROM pages
        WHERE status <> 'complete'
          AND season_end_year = ?
        GROUP BY page_family, status, depth, season_end_year
        ORDER BY page_family, status, depth, season_end_year
        """,
        (season,),
    )
    seasonless_incomplete = fetch_all(
        db,
        """
        SELECT page_family AS pageFamily,
               status,
               depth,
               COUNT(*) AS pageCount
        FROM pages
        WHERE status <> 'complete'
          AND season_end_year IS NULL
        GROUP BY page_family, status, depth
        ORDER BY page_family, status, depth
        """,
    )
    return {
        "seasonEndYear": season,
        "seasonScopedPages": season_rows,
        "incompleteSeasonScopedPages": incomplete_rows,
        "incompleteSeasonlessPages": seasonless_incomplete,
        "seasonScopedComplete": len(incomplete_rows) == 0,
    }


def table_inventory(db: sqlite3.Connection, sample_limit: int) -> list[dict[str, Any]]:
    rows = fetch_all(
        db,
        """
        SELECT t.table_id AS tableId,
               p.page_family AS pageFamily,
               p.season_end_year AS seasonEndYear,
               COUNT(*) AS tableInstances,
               COUNT(DISTINCT t.page_url) AS pageCount,
               COALESCE(SUM(t.row_count), 0) AS rowCount,
               COUNT(DISTINCT t.schema_hash) AS schemaVariants,
               MIN(t.ordinal) AS minOrdinal,
               MAX(t.ordinal) AS maxOrdinal
        FROM tables AS t
        JOIN pages AS p ON p.url = t.page_url
        GROUP BY t.table_id, p.page_family, p.season_end_year
        ORDER BY rowCount DESC, tableInstances DESC, tableId, pageFamily
        """,
    )

    samples_by_key: dict[tuple[str, str, Any], list[str]] = defaultdict(list)
    sample_rows = fetch_all(
        db,
        """
        SELECT t.table_id AS tableId,
               p.page_family AS pageFamily,
               p.season_end_year AS seasonEndYear,
               t.page_url AS pageUrl
        FROM tables AS t
        JOIN pages AS p ON p.url = t.page_url
        ORDER BY t.table_id, p.page_family, p.season_end_year, t.page_url
        """,
    )
    for row in sample_rows:
        key = (row["tableId"], row["pageFamily"], row["seasonEndYear"])
        if len(samples_by_key[key]) < sample_limit and row["pageUrl"] not in samples_by_key[key]:
            samples_by_key[key].append(row["pageUrl"])

    columns_by_key: dict[tuple[str, str, Any], list[str]] = {}
    column_rows = fetch_all(
        db,
        """
        SELECT t.table_id AS tableId,
               p.page_family AS pageFamily,
               p.season_end_year AS seasonEndYear,
               t.columns_json AS columnsJson
        FROM tables AS t
        JOIN pages AS p ON p.url = t.page_url
        ORDER BY t.table_id, p.page_family, p.season_end_year, t.page_url, t.ordinal
        """,
    )
    for row in column_rows:
        key = (row["tableId"], row["pageFamily"], row["seasonEndYear"])
        if key in columns_by_key:
            continue
        try:
            columns = json.loads(row["columnsJson"] or "[]")
        except json.JSONDecodeError:
            columns = []
        columns_by_key[key] = columns

    for row in rows:
        key = (row["tableId"], row["pageFamily"], row["seasonEndYear"])
        row["samplePageUrls"] = samples_by_key.get(key, [])
        row["sampleColumns"] = columns_by_key.get(key, [])
        row["canonicalBucket"] = canonical_bucket(str(row["tableId"]), str(row["pageFamily"]))
    return rows


def canonical_bucket(table_id: str, page_family: str) -> str:
    normalized = table_id.lower()
    if page_family == "boxscore" and normalized == "line_score":
        return "games_line_score"
    if page_family == "boxscore" and normalized == "four_factors":
        return "games_four_factors"
    if page_family == "boxscore" and "game-basic" in normalized:
        return "player_game_basic_box_scores"
    if page_family == "boxscore" and "game-advanced" in normalized:
        return "player_game_advanced_box_scores"
    if page_family == "boxscore_detail":
        if "pbp" in normalized or normalized == "play-by-play":
            return "play_by_play_events"
        if "shot" in normalized:
            return "shot_charts"
        if "plus" in normalized or "minus" in normalized:
            return "plus_minus"
        return "game_detail"
    if page_family == "team_season":
        return "team_season_summary"
    if page_family == "team_season_detail":
        return "team_detail"
    if page_family == "player":
        return "player_profile"
    if page_family == "player_detail":
        return "player_detail"
    if page_family == "league":
        return "league_aggregate"
    if page_family == "playoff":
        return "playoff_aggregate_or_series"
    if page_family in {"draft", "award", "allstar"}:
        return page_family
    return "raw_review"


def bucket_summary(inventory: list[dict[str, Any]]) -> list[dict[str, Any]]:
    buckets: dict[str, dict[str, Any]] = {}
    for row in inventory:
        bucket = row["canonicalBucket"]
        current = buckets.setdefault(
            bucket,
            {
                "canonicalBucket": bucket,
                "tableInstances": 0,
                "pageCount": 0,
                "rowCount": 0,
                "tableIds": set(),
                "pageFamilies": set(),
            },
        )
        current["tableInstances"] += int(row["tableInstances"] or 0)
        current["pageCount"] += int(row["pageCount"] or 0)
        current["rowCount"] += int(row["rowCount"] or 0)
        current["tableIds"].add(row["tableId"])
        current["pageFamilies"].add(row["pageFamily"])

    output = []
    for value in buckets.values():
        output.append(
            {
                **{k: v for k, v in value.items() if k not in {"tableIds", "pageFamilies"}},
                "tableIdCount": len(value["tableIds"]),
                "pageFamilies": sorted(value["pageFamilies"]),
                "sampleTableIds": sorted(value["tableIds"])[:20],
            }
        )
    return sorted(output, key=lambda item: (-int(item["rowCount"]), str(item["canonicalBucket"])))


def write_markdown(path: Path, summary: dict[str, Any], buckets: list[dict[str, Any]], inventory: list[dict[str, Any]]) -> None:
    lines = [
        "# Basketball Reference Raw Catalog Audit",
        "",
        f"Season end year: {summary['seasonEndYear']}",
        f"Season-scoped complete: {summary['seasonScopedComplete']}",
        "",
        "## Incomplete season-scoped pages",
        "",
    ]
    if summary["incompleteSeasonScopedPages"]:
        for row in summary["incompleteSeasonScopedPages"]:
            lines.append(f"- {row}")
    else:
        lines.append("None.")
    lines.extend(["", "## Incomplete seasonless pages", ""])
    if summary["incompleteSeasonlessPages"]:
        for row in summary["incompleteSeasonlessPages"]:
            lines.append(f"- {row}")
    else:
        lines.append("None.")

    lines.extend([
        "",
        "## Canonical bucket summary",
        "",
        "| Bucket | Rows | Table instances | Page families | Sample table IDs |",
        "| --- | ---: | ---: | --- | --- |",
    ])
    for row in buckets:
        lines.append(
            "| {bucket} | {rows} | {instances} | {families} | {table_ids} |".format(
                bucket=row["canonicalBucket"],
                rows=row["rowCount"],
                instances=row["tableInstances"],
                families=", ".join(row["pageFamilies"]),
                table_ids=", ".join(row["sampleTableIds"][:8]),
            )
        )

    lines.extend([
        "",
        "## Largest raw table groups",
        "",
        "| Table ID | Page family | Season | Rows | Pages | Schema variants | Bucket |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ])
    for row in inventory[:75]:
        lines.append(
            "| {table_id} | {family} | {season} | {rows} | {pages} | {schemas} | {bucket} |".format(
                table_id=row["tableId"],
                family=row["pageFamily"],
                season=row["seasonEndYear"] or "",
                rows=row["rowCount"],
                pages=row["pageCount"],
                schemas=row["schemaVariants"],
                bucket=row["canonicalBucket"],
            )
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    with connect(args.database) as db:
        summary = season_completion_summary(db, args.season)
        pages = page_status_summary(db)
        inventory = table_inventory(db, max(1, args.sample_limit))
        buckets = bucket_summary(inventory)

    documents = {
        "season_summary.json": summary,
        "page_status_summary.json": pages,
        "table_inventory.json": inventory,
        "canonical_bucket_summary.json": buckets,
    }
    for filename, document in documents.items():
        (output_dir / filename).write_text(
            json.dumps(document, indent=2, ensure_ascii=False, default=str) + "\n",
            encoding="utf-8",
        )
    write_markdown(output_dir / "catalog_audit.md", summary, buckets, inventory)

    print(
        json.dumps(
            {
                "output": str(output_dir),
                "seasonEndYear": args.season,
                "seasonScopedComplete": summary["seasonScopedComplete"],
                "incompleteSeasonScopedGroups": len(summary["incompleteSeasonScopedPages"]),
                "incompleteSeasonlessGroups": len(summary["incompleteSeasonlessPages"]),
                "tableInventoryRows": len(inventory),
                "canonicalBuckets": len(buckets),
                "files": sorted(documents.keys()) + ["catalog_audit.md"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
