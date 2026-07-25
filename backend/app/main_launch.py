from __future__ import annotations

from . import front_office_api as front_office_module
from . import launch_api as launch_module
from .auth_api import router as auth_router
from .auth_guard import enforce_launch_auth
from .front_office_api import router as front_office_router
from .front_office_hardening import record_dimensions
from .launch_api import router as launch_router
from .launch_security import ensure_organization
from .main import app
from .nba_data_api import router as nba_data_router
from .operations import launch_operations_middleware
from .python_runtime_api import router as python_runtime_router
from .trust_safety_api import router as trust_safety_router
from .workspace_api import router as workspace_router

# Harden launch helpers before the first request. Product writes may create a
# missing organization, but they cannot promote an existing case owner,
# commenter, or assignee to organization owner as a side effect. Draft assets
# use a deterministic draft-year storage dimension instead of requiring a
# fabricated operating season.
launch_module._ensure_organization = ensure_organization
front_office_module._record_dimensions = record_dimensions

# Keep the existing prototype API intact while promoting the launch contracts to
# the default development entrypoint. This lets the Flutter client migrate
# endpoint-by-endpoint without duplicating the original service.
app.title = "Sports Terminal Launch API"
app.version = "1.0.0"
app.description = (
    "Launch-oriented Sports Terminal API for authentication, certified NBA data, "
    "canonical contracts and draft assets, transaction ledgers, moderated community "
    "and messaging, isolated Python analysis, organizations, versioned workspaces, "
    "saved sports objects, content, and platform operations."
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
app.include_router(front_office_router)
app.include_router(trust_safety_router)
app.include_router(python_runtime_router)
