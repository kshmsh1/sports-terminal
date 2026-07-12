# Sports Terminal Backend

This directory is the first executable backend for the launch product. It now uses FastAPI with a local durable SQLite database so backend state can survive server restarts while the product contract is shaped before production hosting, auth, billing, observability, and a managed database are chosen.

## What exists now

- FastAPI service entry point: `backend/app/main.py`
- Local durable SQLite database: `backend/.data/sports_terminal.db` by default
- Dependency list: `backend/requirements.txt`
- One-command dev runner: `backend/scripts/dev.sh`
- Database schema draft: `backend/schema_v1.sql`
- Product/backend architecture docs in `docs/`

## Local run on macOS

Your shell may not have `python` or `pip` aliases. Use `python3` / `python -m pip`, or use the helper script.

```bash
bash backend/scripts/dev.sh
```

Manual version:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Then open:

```text
http://127.0.0.1:8000/health
http://127.0.0.1:8000/docs
http://127.0.0.1:8000/launch/readiness
```

## Useful environment variables

```bash
export SPORTS_TERMINAL_DB_PATH="/absolute/path/to/sports_terminal.db"
export SPORTS_TERMINAL_CORS_ORIGINS="http://localhost:3000,http://localhost:8000,http://localhost:5000"
```

If `SPORTS_TERMINAL_DB_PATH` is omitted, the API writes to `backend/.data/sports_terminal.db`.

## API areas covered

| Area | Skeleton status |
| --- | --- |
| Health/readiness | `/health`, `/launch/readiness` |
| Users/profile/settings | create user, list/read users, read/update profile, read/update settings |
| Favorites/watchlists | favorite teams, favorite players, player watchlists, personalization snapshot |
| Workspace | create workbook, read workbook, update cells |
| Community | boards, posts, comments, post reactions |
| Moderation | reports and report listing |
| Messaging | conversations, user conversation list, messages |
| CMS/articles | draft/list/get/publish/archive articles |
| Billing | plans and subscription placeholder |
| Admin/data ops | feature flags, data sources, pipeline-run records |

## Production blockers

This backend is more useful than the earlier in-memory skeleton, but it is still not production-ready. Before launch it needs:

- Replace local SQLite with managed Postgres or equivalent durable hosted storage.
- Add migrations instead of relying only on startup schema creation.
- Add real auth, sessions/JWTs, password/provider handling, email verification, and account recovery.
- Add role-based authorization for user, moderator, admin, and operator actions.
- Add moderation workflows, block/mute/report safety, and audit trails before public community or messaging.
- Add billing provider integration and entitlement enforcement.
- Add logging, monitoring, backups, secrets management, rate limits, and deployment config.

## Product rule

Do not ship public community or messaging without moderation, report queues, block/mute controls, and operator audit logs.
