from __future__ import annotations

from . import front_office_api as front_office_module
from . import launch_api as launch_module
from .auth_api import router as auth_router
from .auth_guard import enforce_launch_auth
from .authorization_guard import enforce_launch_authorization
from .automation_governance_api import router as automation_governance_router
from .completion_status_api import router as completion_status_router
from .customer_operations_api import router as customer_operations_router
from .front_office_api import router as front_office_router
from .front_office_hardened_routes import router as front_office_hardened_router
from .front_office_hardening import (
    hardened_reconciliation,
    hardened_upsert,
    record_dimensions,
)
from .historical_nba_api import router as historical_nba_router
from .historical_nba_compat_api import router as historical_nba_compat_router
from . import historical_nba_research_mount as _historical_nba_research_mount  # noqa: F401
from .launch_api import router as launch_router
from .launch_security import ensure_organization
from .main import app
from .nba_awards_api import router as nba_awards_router
from .nba_data_api import router as nba_data_router
from .nba_terminal_api import router as nba_terminal_router
from .operations import launch_operations_middleware
from .python_runtime_api import router as python_runtime_router
from .trust_safety_api import router as trust_safety_router
from .workspace_api import router as workspace_router

launch_module._ensure_organization = ensure_organization
front_office_module._record_dimensions = record_dimensions
front_office_module.upsert_front_office_record = hardened_upsert(
    front_office_module.upsert_front_office_record,
    front_office_module.init_front_office_db,
)
front_office_module.front_office_reconciliation = hardened_reconciliation(
    front_office_module.front_office_reconciliation,
    front_office_module.list_front_office_records,
)

app.title = "Sports Terminal Launch API"
app.version = "1.7.0"
app.description = (
    "Launch-oriented Sports Terminal API for authentication, certified and historical NBA data, "
    "canonical awards and voting, canonical contracts and draft assets, transaction ledgers, "
    "moderated community and messaging, isolated Python analysis, customer operations, launch "
    "automation, organization governance, versioned workspaces, saved sports objects, platform "
    "operations, and the unified NBA terminal."
)

app.middleware("http")(enforce_launch_auth)
app.middleware("http")(launch_operations_middleware)
app.middleware("http")(enforce_launch_authorization)


def _attach_router_routes(router) -> None:
    """Attach already-prefixed routes without route-snapshot loss.

    Historical, awards and terminal routes are composed before the generic
    /v2/nba/{season}/{dataset} route. Attaching their final APIRoute objects directly
    preserves dynamic composition and unambiguous route ordering.
    """
    existing = {
        (
            getattr(route, "path", ""),
            tuple(sorted(getattr(route, "methods", set()) or set())),
        )
        for route in app.router.routes
    }
    for route in router.routes:
        signature = (
            getattr(route, "path", ""),
            tuple(sorted(getattr(route, "methods", set()) or set())),
        )
        if signature in existing:
            continue
        app.router.routes.append(route)
        existing.add(signature)


app.include_router(auth_router)
app.include_router(launch_router)
app.include_router(workspace_router)
# Historical and awards routes must be registered before /v2/nba/{season}/{dataset};
# otherwise the dynamic certified-release route can interpret their path prefix as a season.
_attach_router_routes(historical_nba_router)
_attach_router_routes(historical_nba_compat_router)
_attach_router_routes(nba_awards_router)
# Terminal routes receive the same explicit ordering guarantee. This also avoids
# FastAPI route-snapshot behavior when the shared app object has been imported by a
# contract harness before launch composition finishes.
_attach_router_routes(nba_terminal_router)
app.include_router(nba_data_router)
app.include_router(front_office_hardened_router)
app.include_router(front_office_router)
app.include_router(trust_safety_router)
app.include_router(python_runtime_router)
app.include_router(customer_operations_router)
app.include_router(automation_governance_router)
app.include_router(completion_status_router)
