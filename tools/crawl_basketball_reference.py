from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from sports_reference.client import SportsReferenceClient
from sports_reference.crawler import BasketballReferenceCrawler
from sports_reference.link_promoter import StoredLinkPromoter
from sports_reference.page_store import SportsReferencePageStore
from sports_reference.queue_maintenance import QueueMaintenance
from sports_reference.schema_review import SportsReferenceSchemaReview
from sports_reference.url_scope import BasketballReferenceUrlScope

DEFAULT_DATABASE = "raw/basketball_reference/catalog.sqlite"
DEFAULT_CACHE = ".cache/sports_reference"
DEFAULT_SNAPSHOTS = "raw/basketball_reference/snapshots"
DEFAULT_REQUEST_INTERVAL_SECONDS = 7.0
DEFAULT_FAMILIES = ",".join(BasketballReferenceUrlScope().families)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Plan, seed, expand, resume, inspect, and export the Basketball "
            "Reference historical table catalog."
        )
    )
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--cache-dir", default=DEFAULT_CACHE)
    parser.add_argument("--snapshot-root", default=DEFAULT_SNAPSHOTS)
    commands = parser.add_subparsers(dest="command", required=True)

    plan = commands.add_parser("plan")
    plan.add_argument("--from-season", type=int, required=True, dest="start_year")
    plan.add_argument("--to-season", type=int, required=True, dest="end_year")
    plan.add_argument(
        "--profile",
        choices=("core", "extended", "historical"),
        default="historical",
    )
    plan.add_argument(
        "--minimum-interval",
        type=float,
        default=DEFAULT_REQUEST_INTERVAL_SECONDS,
    )
    plan.add_argument("--show-urls", action="store_true")

    seed = commands.add_parser("seed")
    seed.add_argument("--from-season", type=int, required=True, dest="start_year")
    seed.add_argument("--to-season", type=int, required=True, dest="end_year")
    seed.add_argument(
        "--profile",
        choices=("core", "extended", "historical"),
        default="historical",
    )

    promote = commands.add_parser(
        "promote-links",
        help="Queue links already stored from completed pages without refetching them.",
    )
    promote.add_argument("--families", required=True)
    promote.add_argument(
        "--source-families",
        help="Optional comma-separated completed source page families to use.",
    )
    promote.add_argument(
        "--target-path-prefix",
        help="Optional canonical target path prefix, such as /boxscores/pbp/.",
    )
    promote.add_argument("--from-season", type=int, dest="start_year")
    promote.add_argument("--to-season", type=int, dest="end_year")
    promote.add_argument("--source-depth", type=int, default=0)
    promote.add_argument("--limit", type=int)
    promote.add_argument("--dry-run", action="store_true")

    prune = commands.add_parser(
        "prune-queue",
        help=(
            "Remove only unfetched queued, skipped, or failed pages whose known "
            "target season is outside a requested range."
        ),
    )
    prune.add_argument("--families", required=True)
    prune.add_argument("--from-season", type=int, required=True, dest="start_year")
    prune.add_argument("--to-season", type=int, required=True, dest="end_year")
    prune.add_argument("--dry-run", action="store_true")

    crawl = commands.add_parser("crawl")
    crawl.add_argument("--max-pages", type=int, default=50)
    crawl.add_argument("--max-depth", type=int, default=2)
    crawl.add_argument(
        "--minimum-interval",
        type=float,
        default=DEFAULT_REQUEST_INTERVAL_SECONDS,
    )
    crawl.add_argument("--families", default=DEFAULT_FAMILIES)
    crawl.add_argument("--from-season", type=int, dest="start_year")
    crawl.add_argument("--to-season", type=int, dest="end_year")
    crawl.add_argument("--force", action="store_true")
    crawl.add_argument("--acknowledge-site-rules", action="store_true")

    commands.add_parser("status")
    commands.add_parser("coverage")
    commands.add_parser("schema-drift")
    commands.add_parser("schema-review")

    queue = commands.add_parser("queue")
    queue.add_argument(
        "--status",
        choices=("queued", "fetching", "complete", "failed", "blocked", "skipped"),
        default="queued",
    )
    queue.add_argument("--limit", type=int, default=20)

    reset = commands.add_parser("reset-failed")
    reset.add_argument("--include-blocked", action="store_true")

    export = commands.add_parser("export")
    export.add_argument("--output", default="raw/basketball_reference/catalog_export")
    return parser


def parse_families(raw: str, scope: BasketballReferenceUrlScope) -> set[str]:
    families = {value.strip() for value in raw.split(",") if value.strip()}
    unknown = families.difference(scope.families)
    if unknown:
        raise SystemExit(f"Unknown page families: {sorted(unknown)}")
    return families


def main() -> int:
    args = build_parser().parse_args()
    store = SportsReferencePageStore(
        args.database,
        snapshot_root=args.snapshot_root,
    )
    scope = BasketballReferenceUrlScope()

    if args.command == "status":
        print(json.dumps(store.status(), indent=2, default=str))
        return 0
    if args.command == "coverage":
        print(json.dumps(store.coverage(), indent=2, default=str))
        return 0
    if args.command == "schema-drift":
        print(json.dumps({"schemaDrift": store.schema_drift()}, indent=2))
        return 0
    if args.command == "schema-review":
        print(json.dumps(SportsReferenceSchemaReview(store).build(), indent=2))
        return 0
    if args.command == "queue":
        print(
            json.dumps(
                {
                    "status": args.status,
                    "rows": store.queue_sample(args.status, args.limit),
                },
                indent=2,
                default=str,
            )
        )
        return 0
    if args.command == "reset-failed":
        count = store.reset_failed(include_blocked=args.include_blocked)
        print(
            json.dumps(
                {
                    "reset": count,
                    "includedBlocked": args.include_blocked,
                    "status": store.status(),
                },
                indent=2,
                default=str,
            )
        )
        return 0
    if args.command == "export":
        counts = store.export_jsonl(Path(args.output))
        print(json.dumps({"output": args.output, "counts": counts}, indent=2))
        return 0
    if args.command == "promote-links":
        families = parse_families(args.families, scope)
        source_families = (
            parse_families(args.source_families, scope)
            if args.source_families
            else None
        )
        summary = StoredLinkPromoter(store).promote(
            families=families,
            source_families=source_families,
            target_path_prefix=args.target_path_prefix,
            start_year=args.start_year,
            end_year=args.end_year,
            source_depth=args.source_depth,
            limit=args.limit,
            dry_run=args.dry_run,
        )
        print(
            json.dumps(
                {
                    **summary.to_dict(),
                    "dryRun": args.dry_run,
                    "status": store.status(),
                },
                indent=2,
                default=str,
            )
        )
        return 0
    if args.command == "prune-queue":
        families = parse_families(args.families, scope)
        summary = QueueMaintenance(store).prune_outside_season_range(
            families=families,
            start_year=args.start_year,
            end_year=args.end_year,
            dry_run=args.dry_run,
        )
        print(
            json.dumps(
                {
                    **summary.to_dict(),
                    "status": store.status(),
                },
                indent=2,
                default=str,
            )
        )
        return 0

    interval = getattr(
        args,
        "minimum_interval",
        DEFAULT_REQUEST_INTERVAL_SECONDS,
    )
    crawler = BasketballReferenceCrawler(
        client=SportsReferenceClient(
            cache_dir=args.cache_dir,
            minimum_interval_seconds=interval,
        ),
        store=store,
        scope=scope,
    )

    if args.command == "plan":
        document = crawler.plan_seasons(
            args.start_year,
            args.end_year,
            profile=args.profile,
        )
        if not args.show_urls:
            document.pop("seedUrls", None)
        print(json.dumps(document, indent=2))
        return 0

    if args.command == "seed":
        document = crawler.plan_seasons(
            args.start_year,
            args.end_year,
            profile=args.profile,
        )
        queued = crawler.seed_seasons(
            args.start_year,
            args.end_year,
            profile=args.profile,
        )
        print(
            json.dumps(
                {
                    "queued": queued,
                    "plan": {
                        key: value
                        for key, value in document.items()
                        if key != "seedUrls"
                    },
                    "status": store.status(),
                },
                indent=2,
                default=str,
            )
        )
        return 0

    acknowledged = args.acknowledge_site_rules or os.environ.get(
        "SPORTS_TERMINAL_BREF_NETWORK_ACK"
    ) == "1"
    if not acknowledged:
        raise SystemExit(
            "Network crawl blocked. Pass --acknowledge-site-rules before requests."
        )

    families = parse_families(args.families, scope)
    summary = crawler.crawl(
        max_pages=args.max_pages,
        max_depth=args.max_depth,
        families=families,
        force=args.force,
        start_year=args.start_year,
        end_year=args.end_year,
        stop_on_block=True,
    )
    print(
        json.dumps(
            {
                **summary.to_dict(),
                "statusSnapshot": store.status(),
            },
            indent=2,
            default=str,
        )
    )
    return 0 if summary.failed == 0 and summary.blocked == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
