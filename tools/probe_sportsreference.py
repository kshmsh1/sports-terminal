from __future__ import annotations

import argparse
import json
import sys


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check whether the legacy sportsreference package still works locally."
    )
    parser.add_argument("--season", type=int, default=2026)
    args = parser.parse_args()

    try:
        from sportsreference.nba.teams import Teams
    except Exception as exc:
        print(
            "sportsreference could not be imported. Install it only for this compatibility probe: "
            "python3 -m pip install sportsreference==0.5.2",
            file=sys.stderr,
        )
        print(f"Import error: {exc}", file=sys.stderr)
        return 1

    try:
        teams = Teams(args.season)
        rows = [
            {
                "name": getattr(team, "name", None),
                "abbreviation": getattr(team, "abbreviation", None),
            }
            for team in teams
        ]
    except Exception as exc:
        print(
            "The legacy package imported but could not retrieve current data. "
            "Use tools/import_basketball_reference.py instead.",
            file=sys.stderr,
        )
        print(f"Runtime error: {exc}", file=sys.stderr)
        return 1

    print(json.dumps({"season": args.season, "teamCount": len(rows), "teams": rows}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
