from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from sports_reference.client import SportsReferenceClient
from sports_reference.crawler import BasketballReferenceCrawler
from sports_reference.page_store import SportsReferencePageStore
from sports_reference.url_scope import BasketballReferenceUrlScope

DEFAULT_DATABASE = "raw/basketball_reference/catalog.sqlite"
DEFAULT_CACHE = ".cache/sports_reference"
DEFAULT_SNAPSHOTS = "raw/basketball_reference/snapshots"
DEFAULT_REQUEST_INTERVAL_SECONDS = 7.0
DEFAULT_FAMILIES = (
    "league,team_season,team_history,player,playoff,draft,award,allstar,"
    "coach,executive,franchise,boxscore,boxscore_detail"
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Plan, seed, resume, inspect, and export the Basketball Reference "
            "historical table catalog."
        )
    )
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--cache-dir", default=DEFAULT_CACHE)
    parser.add_argument("--snapshot-root", default=DEFAULT_SNAPSHOTS)
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan = subparsers.add_parser(
        "plan",
        help="Preview deterministic season seeds without writing the queue or using the network.",
    )
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
        help="Seconds between requests; must remain between 6 and 8.",
    )
    plan.add_argument("--show-urls", action="store_true")

    seed = subparsers.add_parser(
        "seed",
        help="Queue deterministic season hub pages without making network requests.",
    )
    seed.add_argument("--from-season", type=int, required=True, dest="start_year")
    seed.add_argument("--to-season", type=int, required=True, dest="end_year")
    seed.add_argument(
        "--profile",
        choices=("core", "extended", "historical"),
        default="historical",
    )

    crawl = subparsers.add_parser(
        "crawl",
        help="Fetch queued pages, normalize every table, and discover linked data pages.",
    )
    crawl.add_argument("--max-pages", type=int, default=50)
    crawl.add_argument("--max-depth", type=int, default=2)
    crawl.add_argument(
        "--minimum-interval",
        type=float,
        default=DEFAULT_REQUEST_INTERVAL_SECONDS,
        help="Seconds between requests; must remain between 6 and 8.",
    )
    crawl.add_argument("--families", default=DEFAULT_FAMILIES)
    crawl.add_argument("--from-season", type=int, dest="start_year")
    crawl.add_argument("--to-season", type=int, dest="end_year")
    crawl.add_argument("--force", action="store_true")
    crawl.add_argument(
        "--continue-after-block",
        action="store_true",
        help="Not recommended. Continue to the next queued page after an access block.",
    )
    crawl.add_argument(
        "--acknowledge-site-rules",
        action="store_true",
        help="Required before network requests. Confirms the operator reviewed current access rules.",
    )

    subparsers.add_parser("status", help="Print queue, run, entity, and raw-table counts.")
    subparsers.add_parser("coverage", help="Print season coverage and the discovered table registry.")
    subparsers.add_parser("schema-drift", help="List table IDs whose column schema changed across pages.")

    queue = subparsers.add_parser("queue", help="Inspect a bounded sample of queue records.")
    queue.add_argument(
        "--status",
        choices=("queued", "fetching", "complete", "failed", "blocked", "skipped"),
        default="queued",
    )
    queue.add_argument("--limit", type=int, default=20)

    reset = subparsers.add_parser("reset-failed", help="Return failed pages to the queue.")
    reset.add_argument(
        "--include-blocked",
        action="store_true",
        help="Also reset access-blocked pages. Reconfirm site rules before crawling them.",
    )

    export = subparsers.add_parser("export", help="Export the SQLite catalog to JSONL files.")
    export.add_argument("--output", default="raw/basketball_reference/catalog_export")

    return parser


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
        plan = crawler.plan_seasons(
            args.start_year,
            args.end_year,
            profile=args.profile,
        )
        if not args.show_urls:
            plan.pop("seedUrls", None)
        print(json.dumps(plan, indent=2))
        return 0

    if args.command == "seed":
        plan = crawler.plan_seasons(
            args.start_year,
            args.end_year,
            profile=args.profile,
        )
        inserted = crawler.seed_seasons(
            args.start_year,
            args.end_year,
            profile=args.profile,
        )
        print(
            json.dumps(
                {
                    "queued": inserted,
                    "plan": {key: value for key, value in plan.items() if key != "seedUrls"},
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
            "Network crawl blocked. Review current Basketball Reference access rules, then pass "
            "--acknowledge-site-rules or set SPORTS_TERMINAL_BREF_NETWORK_ACK=1."
        )

    families = {value.strip() for value in args.families.split(",") if value.strip()}
    unknown = families.difference(scope.families)
    if unknown:
        raise SystemExit(f"Unknown page families: {sorted(unknown)}")

    summary = crawler.crawl(
        max_pages=args.max_pages,
        max_depth=args.max_depth,
        families=families,
        force=args.force,
        start_year=args.start_year,
        end_year=args.end_year,
        stop_on_block=not args.continue_after_block,
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
