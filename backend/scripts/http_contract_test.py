from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

PORT = 8012
BASE_URL = f"http://127.0.0.1:{PORT}"


def request(
    method: str,
    path: str,
    *,
    body: dict[str, Any] | None = None,
    token: str = "",
    query: dict[str, str] | None = None,
) -> tuple[int, dict[str, str], Any]:
    url = f"{BASE_URL}{path}"
    if query:
        url = f"{url}?{urllib.parse.urlencode(query)}"
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    call = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode("utf-8"),
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(call, timeout=5) as response:
            raw = response.read().decode("utf-8")
            payload = json.loads(raw) if raw else None
            return response.status, dict(response.headers.items()), payload
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8")
        payload = json.loads(raw) if raw else None
        return error.code, dict(error.headers.items()), payload


with tempfile.TemporaryDirectory(prefix="sports-terminal-http-") as temp_dir:
    environment = os.environ.copy()
    environment["SPORTS_TERMINAL_DB_PATH"] = str(
        Path(temp_dir) / "http_test.sqlite"
    )
    environment["SPORTS_TERMINAL_ENFORCE_AUTH"] = "true"
    environment["SPORTS_TERMINAL_RATE_LIMITS"] = "true"
    environment["SPORTS_TERMINAL_AUTH_REQUESTS_PER_MINUTE"] = "100"
    environment["SPORTS_TERMINAL_API_REQUESTS_PER_MINUTE"] = "100"
    environment["PYTHONPATH"] = "."

    log_path = Path(temp_dir) / "uvicorn.log"
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            [
                sys.executable,
                "-m",
                "uvicorn",
                "app.main_launch:app",
                "--host",
                "127.0.0.1",
                "--port",
                str(PORT),
                "--log-level",
                "warning",
            ],
            env=environment,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
        try:
            deadline = time.time() + 30
            last_error = ""
            while time.time() < deadline:
                try:
                    status, _, _ = request("GET", "/v2/launch/readiness")
                    if status == 200:
                        break
                except Exception as error:
                    last_error = str(error)
                time.sleep(0.35)
            else:
                process.terminate()
                process.wait(timeout=10)
                raise RuntimeError(
                    f"Launch service did not become ready: {last_error}\n"
                    f"{log_path.read_text(encoding='utf-8')}"
                )

            status, headers, readiness = request(
                "GET",
                "/v2/launch/readiness",
            )
            assert status == 200, readiness
            assert headers.get("X-Request-ID") or headers.get("x-request-id")
            assert (
                headers.get("X-Content-Type-Options")
                or headers.get("x-content-type-options")
            ) == "nosniff"

            status, _, session = request(
                "POST",
                "/v2/auth/signup",
                body={
                    "email": "http-analyst@example.com",
                    "password": "HttpLaunch123",
                    "display_name": "HTTP Analyst",
                    "account_type": "individual",
                },
            )
            assert status == 200, session
            token = session["token"]
            user_id = session["user"]["id"]

            status, _, anonymous = request(
                "GET",
                "/v2/workspaces/primary",
                query={"owner_user_id": user_id},
            )
            assert status == 401, anonymous

            status, _, saved = request(
                "PUT",
                "/v2/workspaces/primary",
                token=token,
                body={
                    "actor_user_id": user_id,
                    "scope": "personal",
                    "owner_user_id": user_id,
                    "organization_id": "",
                    "title": "HTTP Workbook",
                    "active_sheet": "Sheet 1",
                    "sheets": {
                        "Sheet 1": {
                            "A1": "Sports Terminal",
                            "B1": "2025-26",
                        }
                    },
                },
            )
            assert status == 200, saved
            assert saved["version"] == 1

            status, _, loaded = request(
                "GET",
                "/v2/workspaces/primary",
                token=token,
                query={"owner_user_id": user_id},
            )
            assert status == 200, loaded
            assert loaded["sheets"]["Sheet 1"]["B1"] == "2025-26"

            status, _, session_check = request(
                "GET",
                "/v2/auth/session",
                token=token,
            )
            assert status == 200, session_check
            assert session_check["user"]["id"] == user_id

            status, _, invalid = request(
                "GET",
                "/v2/workspaces/primary",
                token="invalid-token",
                query={"owner_user_id": user_id},
            )
            assert status == 401, invalid
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()

print("Sports Terminal launch HTTP contract test passed.")
