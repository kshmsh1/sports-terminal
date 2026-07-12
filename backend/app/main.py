from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(
    title="Sports Terminal API",
    version="0.1.0",
    description="Launch backend skeleton for users, profiles, favorites, workspace, community, messaging, CMS, billing, admin, and data operations.",
)

STORE: dict[str, Any] = {
    "users": {},
    "profiles": {},
    "settings": {},
    "favorite_teams": {},
    "favorite_players": {},
    "watchlists": {},
    "workbooks": {},
    "posts": {},
    "comments": {},
    "reports": {},
    "conversations": {},
    "messages": {},
    "articles": {},
    "plans": {
        "free": {"id": "free", "name": "Free", "price_cents": 0, "features": ["NBA hub", "community read", "local workspace"]},
        "pro": {"id": "pro", "name": "Pro", "price_cents": 999, "features": ["saved workspaces", "advanced fantasy", "alerts"]},
    },
    "subscriptions": {},
    "feature_flags": {"community_write": False, "messaging": False, "billing": False, "current_season": False},
    "pipeline_runs": [],
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class UserCreate(BaseModel):
    email: str
    display_name: str
    role: str = "user"


class UserOut(BaseModel):
    id: str
    email: str
    display_name: str
    role: str
    status: str
    created_at: str


class ProfileUpdate(BaseModel):
    handle: str | None = None
    bio: str | None = None
    avatar_url: str | None = None
    is_public: bool = True


class SettingsUpdate(BaseModel):
    dark_mode: bool = False
    email_digest: bool = False
    fantasy_alerts: bool = True
    notification_preferences: dict[str, Any] = Field(default_factory=dict)


class FavoriteUpdate(BaseModel):
    item_id: str


class WatchlistUpdate(BaseModel):
    player_id: str
    source: str = "manual"
    notes: str | None = None


class WorkbookCreate(BaseModel):
    owner_user_id: str
    title: str
    visibility: str = "private"


class CellUpdate(BaseModel):
    sheet: str = "Sheet 1"
    cell_ref: str
    raw_value: str


class PostCreate(BaseModel):
    author_user_id: str
    board: str
    title: str
    body: str
    entity_type: str | None = None
    entity_id: str | None = None


class CommentCreate(BaseModel):
    author_user_id: str
    body: str


class ReportCreate(BaseModel):
    reporter_user_id: str
    target_type: str
    target_id: str
    reason: str


class ConversationCreate(BaseModel):
    title: str
    member_user_ids: list[str]


class MessageCreate(BaseModel):
    sender_user_id: str
    body: str


class ArticleCreate(BaseModel):
    author_user_id: str
    title: str
    body: str
    status: str = "draft"
    tags: list[str] = Field(default_factory=list)


class SubscriptionUpdate(BaseModel):
    user_id: str
    plan_id: str
    status: str = "trialing"


class FeatureFlagUpdate(BaseModel):
    enabled: bool


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "service": "sports-terminal-api", "timestamp": now_iso()}


@app.get("/launch/readiness")
def launch_readiness() -> dict[str, Any]:
    return {
        "status": "prototype",
        "backend": "in-memory skeleton",
        "production_blockers": [
            "replace in-memory STORE with Postgres",
            "add real authentication and session management",
            "add authorization checks per role",
            "add moderation workflow persistence",
            "connect billing provider",
            "add deployment, monitoring, backups, and secrets management",
        ],
        "domains": list(STORE.keys()),
    }


@app.post("/users", response_model=UserOut)
def create_user(payload: UserCreate) -> dict[str, Any]:
    user_id = f"usr_{uuid4().hex[:12]}"
    user = {
        "id": user_id,
        "email": payload.email,
        "display_name": payload.display_name,
        "role": payload.role,
        "status": "active",
        "created_at": now_iso(),
    }
    STORE["users"][user_id] = user
    STORE["profiles"][user_id] = {"user_id": user_id, "handle": None, "bio": None, "avatar_url": None, "is_public": True}
    STORE["settings"][user_id] = {"user_id": user_id, "dark_mode": False, "email_digest": False, "fantasy_alerts": True, "notification_preferences": {}}
    STORE["favorite_teams"][user_id] = set()
    STORE["favorite_players"][user_id] = set()
    STORE["watchlists"][user_id] = {}
    return user


@app.get("/users/{user_id}")
def get_user(user_id: str) -> dict[str, Any]:
    return _get("users", user_id)


@app.get("/users/{user_id}/profile")
def get_profile(user_id: str) -> dict[str, Any]:
    _ensure_user(user_id)
    return STORE["profiles"][user_id]


@app.put("/users/{user_id}/profile")
def update_profile(user_id: str, payload: ProfileUpdate) -> dict[str, Any]:
    _ensure_user(user_id)
    profile = STORE["profiles"][user_id]
    profile.update(payload.model_dump())
    profile["updated_at"] = now_iso()
    return profile


@app.get("/users/{user_id}/settings")
def get_settings(user_id: str) -> dict[str, Any]:
    _ensure_user(user_id)
    return STORE["settings"][user_id]


@app.put("/users/{user_id}/settings")
def update_settings(user_id: str, payload: SettingsUpdate) -> dict[str, Any]:
    _ensure_user(user_id)
    settings = STORE["settings"][user_id]
    settings.update(payload.model_dump())
    settings["updated_at"] = now_iso()
    return settings


@app.get("/users/{user_id}/personalization")
def get_personalization(user_id: str) -> dict[str, Any]:
    _ensure_user(user_id)
    return {
        "favorite_teams": sorted(STORE["favorite_teams"].setdefault(user_id, set())),
        "favorite_players": sorted(STORE["favorite_players"].setdefault(user_id, set())),
        "watchlist": list(STORE["watchlists"].setdefault(user_id, {}).values()),
    }


@app.post("/users/{user_id}/favorite-teams")
def add_favorite_team(user_id: str, payload: FavoriteUpdate) -> dict[str, Any]:
    _ensure_user(user_id)
    STORE["favorite_teams"].setdefault(user_id, set()).add(payload.item_id)
    return get_personalization(user_id)


@app.delete("/users/{user_id}/favorite-teams/{team_id}")
def remove_favorite_team(user_id: str, team_id: str) -> dict[str, Any]:
    _ensure_user(user_id)
    STORE["favorite_teams"].setdefault(user_id, set()).discard(team_id)
    return get_personalization(user_id)


@app.post("/users/{user_id}/watchlist")
def add_watchlist_player(user_id: str, payload: WatchlistUpdate) -> dict[str, Any]:
    _ensure_user(user_id)
    STORE["watchlists"].setdefault(user_id, {})[payload.player_id] = payload.model_dump() | {"created_at": now_iso(), "updated_at": now_iso()}
    return get_personalization(user_id)


@app.delete("/users/{user_id}/watchlist/{player_id}")
def remove_watchlist_player(user_id: str, player_id: str) -> dict[str, Any]:
    _ensure_user(user_id)
    STORE["watchlists"].setdefault(user_id, {}).pop(player_id, None)
    return get_personalization(user_id)


@app.post("/workbooks")
def create_workbook(payload: WorkbookCreate) -> dict[str, Any]:
    _ensure_user(payload.owner_user_id)
    workbook_id = f"wb_{uuid4().hex[:12]}"
    workbook = payload.model_dump() | {"id": workbook_id, "sheets": {"Sheet 1": {}}, "created_at": now_iso(), "updated_at": now_iso()}
    STORE["workbooks"][workbook_id] = workbook
    return workbook


@app.get("/workbooks/{workbook_id}")
def get_workbook(workbook_id: str) -> dict[str, Any]:
    return _get("workbooks", workbook_id)


@app.put("/workbooks/{workbook_id}/cells")
def update_cell(workbook_id: str, payload: CellUpdate) -> dict[str, Any]:
    workbook = _get("workbooks", workbook_id)
    workbook.setdefault("sheets", {}).setdefault(payload.sheet, {})[payload.cell_ref.upper()] = payload.raw_value
    workbook["updated_at"] = now_iso()
    return workbook


@app.get("/community/boards")
def get_boards() -> list[str]:
    return ["NBA General", "Team Rooms", "Fantasy", "Product Feedback", "Data Issues"]


@app.post("/community/posts")
def create_post(payload: PostCreate) -> dict[str, Any]:
    _ensure_user(payload.author_user_id)
    post_id = f"post_{uuid4().hex[:12]}"
    post = payload.model_dump() | {"id": post_id, "likes": 0, "comments": [], "status": "published", "created_at": now_iso()}
    STORE["posts"][post_id] = post
    return post


@app.get("/community/posts")
def list_posts(board: str | None = None) -> list[dict[str, Any]]:
    posts = list(STORE["posts"].values())
    if board:
        posts = [post for post in posts if post["board"] == board]
    return posts


@app.post("/community/posts/{post_id}/comments")
def create_comment(post_id: str, payload: CommentCreate) -> dict[str, Any]:
    post = _get("posts", post_id)
    _ensure_user(payload.author_user_id)
    comment_id = f"cmt_{uuid4().hex[:12]}"
    comment = payload.model_dump() | {"id": comment_id, "post_id": post_id, "created_at": now_iso()}
    STORE["comments"][comment_id] = comment
    post.setdefault("comments", []).append(comment_id)
    return comment


@app.post("/moderation/reports")
def create_report(payload: ReportCreate) -> dict[str, Any]:
    _ensure_user(payload.reporter_user_id)
    report_id = f"rpt_{uuid4().hex[:12]}"
    report = payload.model_dump() | {"id": report_id, "status": "open", "created_at": now_iso()}
    STORE["reports"][report_id] = report
    return report


@app.get("/moderation/reports")
def list_reports(status: str | None = None) -> list[dict[str, Any]]:
    reports = list(STORE["reports"].values())
    if status:
        reports = [report for report in reports if report["status"] == status]
    return reports


@app.post("/messages/conversations")
def create_conversation(payload: ConversationCreate) -> dict[str, Any]:
    for user_id in payload.member_user_ids:
        _ensure_user(user_id)
    conversation_id = f"conv_{uuid4().hex[:12]}"
    conversation = payload.model_dump() | {"id": conversation_id, "created_at": now_iso(), "updated_at": now_iso()}
    STORE["conversations"][conversation_id] = conversation
    STORE["messages"][conversation_id] = []
    return conversation


@app.post("/messages/conversations/{conversation_id}/messages")
def send_message(conversation_id: str, payload: MessageCreate) -> dict[str, Any]:
    _get("conversations", conversation_id)
    _ensure_user(payload.sender_user_id)
    message = payload.model_dump() | {"id": f"msg_{uuid4().hex[:12]}", "conversation_id": conversation_id, "created_at": now_iso()}
    STORE["messages"].setdefault(conversation_id, []).append(message)
    return message


@app.get("/messages/conversations/{conversation_id}/messages")
def list_messages(conversation_id: str) -> list[dict[str, Any]]:
    _get("conversations", conversation_id)
    return STORE["messages"].setdefault(conversation_id, [])


@app.post("/cms/articles")
def create_article(payload: ArticleCreate) -> dict[str, Any]:
    _ensure_user(payload.author_user_id)
    article_id = f"art_{uuid4().hex[:12]}"
    article = payload.model_dump() | {"id": article_id, "created_at": now_iso(), "updated_at": now_iso()}
    STORE["articles"][article_id] = article
    return article


@app.get("/cms/articles")
def list_articles(status: str | None = None) -> list[dict[str, Any]]:
    articles = list(STORE["articles"].values())
    if status:
        articles = [article for article in articles if article["status"] == status]
    return articles


@app.get("/billing/plans")
def list_plans() -> list[dict[str, Any]]:
    return list(STORE["plans"].values())


@app.put("/billing/subscriptions/{subscription_id}")
def upsert_subscription(subscription_id: str, payload: SubscriptionUpdate) -> dict[str, Any]:
    _ensure_user(payload.user_id)
    if payload.plan_id not in STORE["plans"]:
        raise HTTPException(status_code=404, detail="Plan not found")
    subscription = payload.model_dump() | {"id": subscription_id, "updated_at": now_iso()}
    STORE["subscriptions"][subscription_id] = subscription
    return subscription


@app.get("/admin/feature-flags")
def list_feature_flags() -> dict[str, bool]:
    return STORE["feature_flags"]


@app.put("/admin/feature-flags/{flag}")
def update_feature_flag(flag: str, payload: FeatureFlagUpdate) -> dict[str, bool]:
    if flag not in STORE["feature_flags"]:
        raise HTTPException(status_code=404, detail="Feature flag not found")
    STORE["feature_flags"][flag] = payload.enabled
    return STORE["feature_flags"]


@app.get("/admin/data/pipeline-runs")
def list_pipeline_runs() -> list[dict[str, Any]]:
    return STORE["pipeline_runs"]


@app.post("/admin/data/pipeline-runs")
def record_pipeline_run(payload: dict[str, Any]) -> dict[str, Any]:
    run = payload | {"id": f"run_{uuid4().hex[:12]}", "recorded_at": now_iso()}
    STORE["pipeline_runs"].append(run)
    return run


def _get(collection: str, item_id: str) -> dict[str, Any]:
    item = STORE[collection].get(item_id)
    if item is None:
        raise HTTPException(status_code=404, detail=f"{collection} item not found")
    return item


def _ensure_user(user_id: str) -> None:
    if user_id not in STORE["users"]:
        raise HTTPException(status_code=404, detail="User not found")
