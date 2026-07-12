# Sports Terminal Backend

This directory is the first executable backend skeleton for the launch product. It is intentionally simple and in-memory so the product contract can be shaped before choosing production hosting, auth, database, billing, and observability.

## What exists now

- FastAPI service entry point: `backend/app/main.py`
- Dependency list: `backend/requirements.txt`
- Database schema draft: `backend/schema_v1.sql`
- Product/backend architecture docs in `docs/`

## Local run

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Then open:

```text
http://127.0.0.1:8000/health
http://127.0.0.1:8000/docs
```

## API areas covered

| Area | Skeleton status |
| --- | --- |
| Health/readiness | `/health`, `/launch/readiness` |
| Users/profile/settings | create user, read user, read/update profile, read/update settings |
| Favorites/watchlists | favorite teams, favorite players/watchlist, personalization snapshot |
| Workspace | create workbook, read workbook, update cells |
| Community | boards, posts, comments |
| Moderation | reports and report listing |
| Messaging | conversations and messages |
| CMS/articles | draft/list articles |
| Billing | plans and subscription placeholder |
| Admin/data ops | feature flags and pipeline-run records |

## Production blockers

This backend is not production-ready yet. Before launch it needs:

- Replace in-memory store with Postgres or equivalent durable storage.
- Add real auth, sessions, password/provider handling, email verification, and account recovery.
- Add role-based authorization for user, moderator, admin, and operator actions.
- Add moderation workflows, block/mute/report safety, and audit trails before public community or messaging.
- Add billing provider integration and entitlement enforcement.
- Add logging, monitoring, backups, migrations, secrets management, rate limits, and deployment config.

## Product rule

Do not ship public community or messaging without moderation, report queues, block/mute controls, and operator audit logs.
