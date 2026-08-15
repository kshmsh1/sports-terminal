from __future__ import annotations

from app import auth_guard, authorization_guard


def main() -> None:
    assert "/v2/billing/webhooks/" in auth_guard.PUBLIC_V2_PREFIXES
    assert "/v2/billing/webhooks/" in authorization_guard._PUBLIC_PREFIXES
    assert "/v2/releases" in authorization_guard._PLATFORM_PREFIXES

    claim = authorization_guard._path_claim("/v2/entitlements/users/user_123")
    assert claim == ("/v2/entitlements/users/", "user_123")
    assert authorization_guard._platform("platform_admin") is True
    assert authorization_guard._platform("organization_admin") is False

    print("production_authorization_contract: PASS")


if __name__ == "__main__":
    main()
