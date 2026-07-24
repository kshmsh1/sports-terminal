from __future__ import annotations

import os
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="sports-terminal-http-") as temp_dir:
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(temp_dir) / "http_test.sqlite")
    os.environ["SPORTS_TERMINAL_ENFORCE_AUTH"] = "true"
    os.environ["SPORTS_TERMINAL_RATE_LIMITS"] = "true"
    os.environ["SPORTS_TERMINAL_AUTH_REQUESTS_PER_MINUTE"] = "100"
    os.environ["SPORTS_TERMINAL_API_REQUESTS_PER_MINUTE"] = "100"

    from fastapi.testclient import TestClient

    from app.main_launch import app

    with TestClient(app) as client:
        readiness = client.get("/v2/launch/readiness")
        assert readiness.status_code == 200
        assert readiness.headers["x-request-id"]
        assert readiness.headers["x-content-type-options"] == "nosniff"

        signup = client.post(
            "/v2/auth/signup",
            json={
                "email": "http-analyst@example.com",
                "password": "HttpLaunch123",
                "display_name": "HTTP Analyst",
                "account_type": "individual",
            },
        )
        assert signup.status_code == 200, signup.text
        session = signup.json()
        token = session["token"]
        user_id = session["user"]["id"]

        anonymous = client.get(
            "/v2/workspaces/primary",
            params={"owner_user_id": user_id},
        )
        assert anonymous.status_code == 401

        headers = {"Authorization": f"Bearer {token}"}
        saved = client.put(
            "/v2/workspaces/primary",
            headers=headers,
            json={
                "actor_user_id": user_id,
                "scope": "personal",
                "owner_user_id": user_id,
                "organization_id": "",
                "title": "HTTP Workbook",
                "active_sheet": "Sheet 1",
                "sheets": {"Sheet 1": {"A1": "Sports Terminal", "B1": "2025-26"}},
            },
        )
        assert saved.status_code == 200, saved.text
        assert saved.json()["version"] == 1

        loaded = client.get(
            "/v2/workspaces/primary",
            headers=headers,
            params={"owner_user_id": user_id},
        )
        assert loaded.status_code == 200, loaded.text
        assert loaded.json()["sheets"]["Sheet 1"]["B1"] == "2025-26"

        session_check = client.get("/v2/auth/session", headers=headers)
        assert session_check.status_code == 200
        assert session_check.json()["user"]["id"] == user_id

        invalid = client.get(
            "/v2/workspaces/primary",
            headers={"Authorization": "Bearer invalid-token"},
            params={"owner_user_id": user_id},
        )
        assert invalid.status_code == 401

print("Sports Terminal launch HTTP contract test passed.")
