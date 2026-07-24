from __future__ import annotations

from . import launch_api as launch_module
from .auth_api import init_auth_db, router as auth_router
from .launch_api import init_launch_db, router as launch_router
from .launch_security import ensure_organization
from .main import app
from .workspace_api import init_workspace_db, router as workspace_router

# Harden the helper used by launch endpoints before the first request. Product
# writes may create a missing organization, but they cannot promote an existing
# case owner, commenter, or assignee to organization owner as a side effect.
launch_module._ensure_organization = ensure_organization

# Keep the existing prototype API intact while promoting the launch contracts to
# the default development entrypoint. This lets the Flutter client migrate
# endpoint-by-endpoint without duplicating the original service.
app.title = "Sports Terminal Launch API"
app.version = "0.5.0"
app.description = (
    "Launch-oriented Sports Terminal API for authentication, NBA data releases, "
    "users, organizations, transaction workflows, versioned sports workspaces, "
    "saved sports objects, content, messaging, billing placeholders, and "
    "platform operations."
)
app.include_router(auth_router)
app.include_router(launch_router)
app.include_router(workspace_router)
app.add_event_handler("startup", init_auth_db)
app.add_event_handler("startup", init_launch_db)
app.add_event_handler("startup", init_workspace_db)
