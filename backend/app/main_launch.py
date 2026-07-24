from __future__ import annotations

from . import launch_api as launch_module
from .auth_api import router as auth_router
from .auth_guard import enforce_launch_auth
from .launch_api import router as launch_router
from .launch_security import ensure_organization
from .main import app
from .nba_data_api import router as nba_data_router
from .operations import launch_operations_middleware
from .workspace_api import router as workspace_router

# Harden the helper used by launch endpoints before the first request. Product
# writes may create a missing organization, but they cannot promote an existing
# case owner, commenter, or assignee to organization owner as a side effect.
launch_module._ensure_organization = ensure_organization

# Keep the existing prototype API intact while promoting the launch contracts to
# the default development entrypoint. This lets the Flutter client migrate
# endpoint-by-endpoint without duplicating the original service.
app.title = "Sports Terminal Launch API"
app.version = "0.8.0"
app.description = (
    "Launch-oriented Sports Terminal API for authentication, certified NBA data, "
    "users, organizations, transaction workflows, versioned sports workspaces, "
    "saved sports objects, content, messaging, billing placeholders, and "
    "platform operations."
)

# Local development remains permissive by default. Staging and public services
# enable SPORTS_TERMINAL_ENFORCE_AUTH=true; the Flutter client already sends its
# stored bearer token to every remote-first product repository. Rate limiting,
# HSTS, and structured request logging can be enabled through environment flags.
app.middleware("http")(enforce_launch_auth)
app.middleware("http")(launch_operations_middleware)

# Each router owns its startup database initialization through its registered
# lifespan hooks. Including the routers is sufficient across current FastAPI
# versions and avoids relying on the removed app.add_event_handler method.
app.include_router(auth_router)
app.include_router(launch_router)
app.include_router(workspace_router)
app.include_router(nba_data_router)
