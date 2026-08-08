from __future__ import annotations

import os
import tempfile
from pathlib import Path


with tempfile.TemporaryDirectory(prefix="sports-terminal-profile-") as temp_dir:
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(temp_dir) / "profile.sqlite")

    from app import main_launch
    from app.profile_api import ProfileUpdate, get_profile_v2, init_profile_api, update_profile_v2

    init_profile_api()
    payload = update_profile_v2(
        "profile-user",
        ProfileUpdate(
            actor_user_id="profile-user",
            display_name="Profile User",
            handle="profile.user",
            bio="Basketball research, team-building and historical analysis.",
            avatar_url="https://example.com/avatar.png",
            is_public=True,
            favorite_teams=["BOS", "NYK"],
            favorite_players=["player-one", "player-two"],
            email_digest=True,
            fantasy_alerts=False,
            trade_alerts=True,
            editorial_newsletter=True,
        ),
    )
    assert payload["display_name"] == "Profile User"
    assert payload["handle"] == "profile.user"
    assert payload["favorite_teams"] == ["BOS", "NYK"]
    assert set(payload["favorite_players"]) == {"player-one", "player-two"}
    assert payload["preferences"]["email_digest"] is True
    assert payload["preferences"]["fantasy_alerts"] is False
    assert payload["preferences"]["trade_alerts"] is True
    assert payload["preferences"]["editorial_newsletter"] is True

    loaded = get_profile_v2("profile-user", viewer_user_id="profile-user")
    assert loaded["handle"] == "profile.user"
    assert loaded["email"] is not None
    assert loaded["reputation"]["reputation"] >= 0

    public = get_profile_v2("profile-user", viewer_user_id="someone-else")
    assert public["email"] is None
    assert public["preferences"] == {}

    paths = {getattr(route, "path", "") for route in main_launch.app.routes}
    assert "/v2/profile/{user_id}" in paths, sorted(paths)

print("Sports Terminal durable profile contract test passed.")
