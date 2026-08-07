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
from .nba_data_api import router as nba_data_router
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
app.version = "1.5.0"
app.description = (
    "Launch-oriented Sports Terminal API for authentication, certified and historical NBA data, "
    "canonical contracts and draft assets, transaction ledgers, moderated community and messaging, "
    "isolated Python analysis, customer operations, launch automation, organization governance, "
    "versioned workspaces, saved sports objects, and platform operations."
)

app.middleware("http")(enforce_launch_auth)
app.middleware("http")(launch_operations_middleware)
app.middleware("http")(enforce_launch_authorization)

app.include_router(auth_router)
app.include_router(launch_router)
app.include_router(workspace_router)
# Historical routes must be registered before /v2/nba/{season}/{dataset}; otherwise
# the dynamic certified-release route can interpret "history" as a season value.
app.include_router(historical_nba_router)
app.include_router(historical_nba_compat_router)
app.include_router(nba_data_router)
app.include_router(front_office_hardened_router)
app.include_router(front_office_router)
app.include_router(trust_safety_router)
app.include_router(python_runtime_router)
app.include_router(customer_operations_router)
app.include_router(automation_governance_router)
app.include_router(completion_status_router)
