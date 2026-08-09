from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

with tempfile.TemporaryDirectory(prefix="sports-terminal-legal-consent-") as temp_dir:
    root = Path(temp_dir)
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(root / "launch.sqlite")

    from app import auth_api

    auth_api.init_auth_db()

    def expect_rejected(payload: auth_api.SignUpRequest, status: int) -> None:
        try:
            auth_api.sign_up(payload)
        except HTTPException as exc:
            assert exc.status_code == status, (exc.status_code, exc.detail)
            return
        raise AssertionError("signup unexpectedly succeeded without current legal consent")

    common = {
        "password": "TerminalPass123",
        "display_name": "Consent Test User",
        "account_type": "individual",
    }

    expect_rejected(
        auth_api.SignUpRequest(
            email="missing-terms@example.com",
            accepted_terms=False,
            accepted_privacy=True,
            **common,
        ),
        400,
    )
    expect_rejected(
        auth_api.SignUpRequest(
            email="missing-privacy@example.com",
            accepted_terms=True,
            accepted_privacy=False,
            **common,
        ),
        400,
    )
    expect_rejected(
        auth_api.SignUpRequest(
            email="stale-policy@example.com",
            accepted_terms=True,
            accepted_privacy=True,
            legal_document_version="stale-version",
            **common,
        ),
        409,
    )

    accepted_at = "2026-08-08T17:00:00-05:00"
    response = auth_api.sign_up(
        auth_api.SignUpRequest(
            email="accepted@example.com",
            accepted_terms=True,
            accepted_privacy=True,
            legal_document_version=auth_api.LEGAL_DOCUMENT_VERSION,
            legal_accepted_at=accepted_at,
            **common,
        )
    )
    user_id = response["user"]["id"]
    legal = response["legal_acceptances"]
    assert legal["current"] is True
    assert legal["current_version"] == auth_api.LEGAL_DOCUMENT_VERSION
    assert set(legal["documents"]) == {"terms", "privacy"}

    with auth_api.connect() as connection:
        rows = connection.execute(
            """
            SELECT document_key, document_version, client_accepted_at
            FROM legal_acceptances
            WHERE user_id = ?
            ORDER BY document_key
            """,
            (user_id,),
        ).fetchall()
    assert len(rows) == 2
    assert {row["document_key"] for row in rows} == {"terms", "privacy"}
    assert all(row["document_version"] == auth_api.LEGAL_DOCUMENT_VERSION for row in rows)
    assert all(row["client_accepted_at"] == accepted_at for row in rows)

print("Mandatory legal consent contract test passed.")