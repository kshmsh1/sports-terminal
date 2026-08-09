from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

with tempfile.TemporaryDirectory(prefix="sports-terminal-community-") as temp_dir:
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(temp_dir) / "community.sqlite")

    from app import main_launch
    from app.community_api import (
        CommunityFollowUpdate,
        CommunityReplyCreate,
        CommunitySaveUpdate,
        CommunityThreadCreate,
        CommunityVoteUpdate,
        community_feed,
        community_user_profile,
        create_thread,
        create_threaded_comment,
        follow_board,
        init_community_db,
        list_boards,
        save_post,
        threaded_comments,
        vote_post,
    )

    init_community_db()
    boards = list_boards("user-a")
    assert len(boards) >= 36
    assert any(item["slug"] == "nba" for item in boards)
    assert any(item["slug"] == "team-bos" for item in boards)

    followed = follow_board(
        "nba",
        CommunityFollowUpdate(actor_user_id="user-a", followed=True),
    )
    assert followed["following"] is True

    first = create_thread(
        CommunityThreadCreate(
            actor_user_id="user-a",
            community_slug="nba",
            title="A data-backed playoff discussion",
            body="Use the canonical player and team data to compare these rotations.",
            flair="Analysis",
        )
    )
    second = create_thread(
        CommunityThreadCreate(
            actor_user_id="user-b",
            community_slug="nba",
            title="Another league-wide discussion",
            body="A second thread gives the ranking contract something to compare.",
            flair="Discussion",
        )
    )
    assert first["status"] == "published"
    assert second["status"] == "published"

    voted = vote_post(
        first["id"],
        CommunityVoteUpdate(actor_user_id="user-b", direction=1),
    )
    assert voted["score"] >= 1
    assert voted["viewer_vote"] == 1

    downvoted = vote_post(
        second["id"],
        CommunityVoteUpdate(actor_user_id="user-a", direction=-1),
    )
    assert downvoted["viewer_vote"] == -1

    save = save_post(
        first["id"],
        CommunitySaveUpdate(actor_user_id="user-a", saved=True),
    )
    assert save["saved"] is True

    top = community_feed(viewer_user_id="user-a", community_slug="nba", sort="top")
    assert top["rows"][0]["id"] == first["id"]
    saved_feed = community_feed(viewer_user_id="user-a", sort="new", saved_only=True)
    assert [item["id"] for item in saved_feed["rows"]] == [first["id"]]
    followed_feed = community_feed(viewer_user_id="user-a", sort="hot", followed_only=True)
    assert len(followed_feed["rows"]) == 2

    root_comment = create_threaded_comment(
        first["id"],
        CommunityReplyCreate(actor_user_id="user-b", body="Root-level response."),
    )
    nested = create_threaded_comment(
        first["id"],
        CommunityReplyCreate(
            actor_user_id="user-a",
            body="Nested response with supporting context.",
            parent_comment_id=root_comment["id"],
        ),
    )
    assert nested["depth"] == 1
    comments = threaded_comments(first["id"], viewer_user_id="user-a")
    assert len(comments) == 2
    assert comments[1]["parent_comment_id"] == root_comment["id"]

    profile = community_user_profile("user-a")
    assert profile["reputation"]["posts"] == 1
    assert "Contributor" in profile["reputation"]["badges"]
    assert any(item["slug"] == "nba" for item in profile["communities"])

    paths = {getattr(route, "path", "") for route in main_launch.app.routes}
    expected = {
        "/v2/community/boards",
        "/v2/community/feed",
        "/v2/community/posts",
        "/v2/community/posts/{post_id}/vote",
        "/v2/community/posts/{post_id}/save",
        "/v2/community/posts/{post_id}/comments",
        "/v2/community/users/{user_id}",
    }
    assert expected <= paths, (expected - paths, sorted(paths))

print("Sports Terminal community network contract test passed.")