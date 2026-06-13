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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Seed, resume, inspect, and export the Basketball Reference historical table catalog."
    )
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--cache-dir", default=DEFAULT_CACHE)
    subparsers = parser.add_subparsers(dest="command", required=True)

    seed = subparsers.add_parser("seed", help="Queue season hub pages without making network requests.")
    seed.add_argument("--from-season", type=int, required=True, dest="start_year")
    seed.add_argument("--to-season", type=int, required=True, dest="end_year")
    seed.add_argument("--profile", choices=("core", "extended"), default="extended")

    crawl = subparsers.add_parser("crawl", help="Fetch queued pages and discover linked data pages.")
    crawl.add_argument("--max-pages", type=int, default=25)
    crawl.add_argument("--max-depth", type=int, default=1)
    crawl.add_argument("--minimum-interval", type=float, default=4.0)
    crawl.add_argument("--families", default="league,team_season,team_history,player,playoff,draft,award,coach,executive,franchise,boxscore")
    crawl.add_argument("--force", action="store_true")
    crawl.add_argument(
        "--acknowledge-site-rules",
        action="store_true",
        help="Required before network requests. Confirms the operator reviewed current access rules.",
    )

    subparsers.add_parser("status", help="Print queue and normalized table counts.")

    export = subparsers.add_parser("export", help="Export the SQLite catalog to JSONL files.")
    export.add_argument("--output", default="raw/basketball_reference/catalog_export")

    return parser


def main() -> int:
    args = build_parser().parse_args()
    store = SportsReferencePageStore(args.database)
    scope = BasketballReferenceUrlScope()

    if args.command == "seed":
        crawler = BasketballReferenceCrawler(
            client=SportsReferenceClient(cache_dir=args.cache_dir),
            store=store,
            scope=scope,
        )
        inserted = crawler.seed_seasons(
            args.start_year,
            args.end_year,
            profile=args.profile,
        )
        print(json.dumps({"queued": inserted, "status": store.status()}, indent=2))
        return 0

    if args.command == "status":
        print(json.dumps(store.status(), indent=2))
        return 0

    if args.command == "export":
        counts = store.export_jsonl(Path(args.output))
        print(json.dumps({"output": args.output, "counts": counts}, indent=2))
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

    client = SportsReferenceClient(
        cache_dir=args.cache_dir,
        minimum_interval_seconds=args.minimum_interval,
    )
    crawler = BasketballReferenceCrawler(client=client, store=store, scope=scope)
    summary = crawler.crawl(
        max_pages=args.max_pages,
        max_depth=args.max_depth,
        families=families,
        force=args.force,
    )
    print(
        json.dumps(
            {
                "processed": summary.processed,
                "completed": summary.completed,
                "failed": summary.failed,
                "newlyQueued": summary.newly_queued,
                "status": store.status(),
            },
            indent=2,
        )
    )
    return 0 if summary.failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
