from __future__ import annotations

from .historical_nba_api import router as historical_router
from .historical_nba_research_api import router as research_router

# Historical routes are already registered before generic NBA dataset routes.
# Append the concrete deep-research routes to that same router so they inherit
# the existing safe order without changing main_launch composition.
_existing = {
    (route.path, tuple(sorted(getattr(route, "methods", set()) or set())))
    for route in historical_router.routes
}
for route in research_router.routes:
    signature = (
        route.path,
        tuple(sorted(getattr(route, "methods", set()) or set())),
    )
    if signature not in _existing:
        historical_router.routes.append(route)
        _existing.add(signature)
