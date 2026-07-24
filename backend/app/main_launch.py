from __future__ import annotations

from .auth_api import init_auth_db, router as auth_router
from .launch_api import init_launch_db, router as launch_router
from .main import app

# Keep the existing prototype API intact while promoting the launch contracts to
# the default development entrypoint. This lets the Flutter client migrate
# endpoint-by-endpoint without duplicating the original service.
app.title = "Sports Terminal Launch API"
app.version = "0.4.0"
app.description = (
    "Launch-oriented Sports Terminal API for authentication, NBA data releases, "
    "users, organizations, transaction workflows, saved sports objects, "
    "workspaces, content, messaging, billing placeholders, and platform operations."
)
app.include_router(auth_router)
app.include_router(launch_router)
app.add_event_handler("startup", init_auth_db)
app.add_event_handler("startup", init_launch_db)
