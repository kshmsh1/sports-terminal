from __future__ import annotations

from . import front_office_api as front_office_module
from . import launch_api as launch_module
from .auth_api import router as auth_router
from .auth_guard import enforce_launch_auth
from .authorization_guard import enforce_launch_authorization
from .completion_status_api import router as completion_status_router
from .customer_ops_api import router as customer_ops_router
from .front_office_api import router as front_office_router
from .front_office_hardened_routes import router as front_office_hardened_router
from .front_office_hardening import (
    hardened_reconciliation,
    hardened_upsert,
    record_dimensions,
)
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
# fabricated operating season. Registry IDs remain bound to one object type and
# every ledger team participates in reconciliation.
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
app.version = "1.1.0"
app.description = (
    "Launch-oriented Sports Terminal API for authentication, certified NBA data, "
    "canonical contracts and draft assets, transaction ledgers, moderated community "
    "and messaging, isolated Python analysis, subscriptions and entitlements, "
    "customer support, privacy operations, provider outboxes, service reliability, "
    "organizations, versioned workspaces, saved sports objects, and platform operations."
)

# Middleware is intentionally registered before routers are included. Production
# environments enable SPORTS_TERMINAL_ENFORCE_AUTH=true; local development can
# remain permissive while still exercising the same request pipeline.
app.middleware("http")(enforce_launch_auth)
app.middleware("http")(launch_operations_middleware)
app.middleware("http")(enforce_launch_authorization)

# The hardened front-office router is registered before the compatibility router
# so the public HTTP boundary receives the same ID-binding and reconciliation
# guarantees as direct backend consumers.
app.include_router(auth_router)
app.include_router(launch_router)
app.include_router(workspace_router)
app.include_router(nba_data_router)
app.include_router(front_office_hardened_router)
app.include_router(front_office_router)
app.include_router(trust_safety_router)
app.include_router(python_runtime_router)
app.include_router(completion_status_router)
app.include_router(customer_ops_router)
