from __future__ import annotations

import os
import tempfile
from pathlib import Path

from fastapi import HTTPException
from starlette.requests import Request

from app import database
from app.organization_security_api import (
    OrganizationSecurityPolicyUpdate,
    security_policy,
    update_security_policy,
)


def request(*, user_id: str, role: str, organization_id: str) -> Request:
    value = Request({"type": "http", "method": "PUT", "path": "/", "headers": []})
    value.state.user_id = user_id
    value.state.user_role = role
    value.state.organization_id = organization_id
    return value


def main() -> None:
    original = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "org-security.db"
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (id TEXT PRIMARY KEY);
                    INSERT INTO users VALUES ('usr_admin');
                    CREATE TABLE organizations (id TEXT PRIMARY KEY);
                    INSERT INTO organizations VALUES ('org_1');
                    CREATE TABLE organization_security_policies (
                      organization_id TEXT PRIMARY KEY REFERENCES organizations(id),
                      require_mfa INTEGER NOT NULL DEFAULT 0,
                      sso_required INTEGER NOT NULL DEFAULT 0,
                      max_session_days INTEGER NOT NULL DEFAULT 30,
                      allowed_email_domains TEXT NOT NULL DEFAULT '[]',
                      updated_by_user_id TEXT REFERENCES users(id),
                      created_at TEXT NOT NULL,
                      updated_at TEXT NOT NULL
                    );
                    """
                )
            admin = request(user_id="usr_admin", role="organization_admin", organization_id="org_1")
            updated = update_security_policy(
                "org_1",
                OrganizationSecurityPolicyUpdate(
                    require_mfa=True,
                    sso_required=False,
                    max_session_days=14,
                    allowed_email_domains=["Example.com"],
                ),
                admin,
            )
            assert updated["require_mfa"] is True
            assert updated["max_session_days"] == 14
            assert updated["allowed_email_domains"] == ["example.com"]
            assert security_policy("org_1", admin)["require_mfa"] is True

            wrong_org = request(user_id="usr_admin", role="organization_admin", organization_id="org_2")
            try:
                security_policy("org_1", wrong_org)
            except HTTPException as error:
                assert error.status_code == 403
            else:
                raise AssertionError("organization admin must not cross organization boundary")

            platform = request(user_id="usr_platform", role="platform_admin", organization_id="")
            assert security_policy("org_1", platform)["max_session_days"] == 14

        print("organization_security_contract: PASS")
    finally:
        if original is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original


if __name__ == "__main__":
    main()
