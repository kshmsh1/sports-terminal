from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database, release_management_api
from app.migrations import run_migrations
from app.release_management_api import ReleaseCreateRequest, ReleaseService


def main() -> None:
    keys = ["SPORTS_TERMINAL_DATABASE_URL", "SPORTS_TERMINAL_RELEASE_SIGNING_SECRET"]
    previous = {key: os.environ.get(key) for key in keys}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_RELEASE_SIGNING_SECRET"] = "release-secret-" + "x" * 40
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "release.db"
            release_management_api.connect = database.connect
            with database.connect() as connection:
                connection.execute(
                    "CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL)"
                )
            run_migrations()

            service = ReleaseService()
            candidate = service.create_candidate(
                ReleaseCreateRequest(
                    league="NBA",
                    season="2025-26",
                    release_version="2026.08.15.1",
                    manifest={
                        "season": "2025-26",
                        "datasets": {"games": {"rows": 1230}, "players": {"rows": 600}},
                        "source_snapshot": "warehouse://nba/2025-26/2026-08-15",
                    },
                    source_snapshot="warehouse://nba/2025-26/2026-08-15",
                )
            )
            assert candidate["status"] == "candidate"
            certified = service.certify(candidate["id"])
            assert certified["status"] == "certified"
            activated = service.activate(
                candidate["id"],
                environment="staging",
                actor="contract-test",
                reason="release verification",
            )
            assert activated["previous_release_id"] is None
            active = service.active("staging")
            assert active is not None
            assert active["release_version"] == "2026.08.15.1"
            assert active["database_schema_version"] == "0003"
            history = service.history("staging")
            assert len(history) == 1
            assert history[0]["release_id"] == candidate["id"]

            same = service.create_candidate(
                ReleaseCreateRequest(
                    league="NBA",
                    season="2025-26",
                    release_version="2026.08.15.1",
                    manifest={
                        "season": "2025-26",
                        "datasets": {"games": {"rows": 1230}, "players": {"rows": 600}},
                        "source_snapshot": "warehouse://nba/2025-26/2026-08-15",
                    },
                    source_snapshot="warehouse://nba/2025-26/2026-08-15",
                )
            )
            assert same["id"] == candidate["id"]

        print("release_management_contract: PASS")
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
