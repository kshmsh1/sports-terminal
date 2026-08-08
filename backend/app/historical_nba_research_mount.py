from __future__ import annotations

from .historical_nba_api import router as historical_router
from .historical_nba_entity_api import router as entity_router
from .historical_nba_entity_search_api import router as entity_search_router
from .historical_nba_research_api import router as research_router

# Historical routes are registered before generic NBA dataset routes. Append the
# concrete research/entity APIRoute objects to that same router so all canonical
# historical surfaces inherit the safe route order without changing main_launch.
# The optimized search router is composed before the broader entity router; the
# shared signature guard therefore keeps the bounded search implementation and
# suppresses the older multiplicative season-search route.
_existing = {
    (route.path, tuple(sorted(getattr(route, "methods", set()) or set())))
    for route in historical_router.routes
}
for composed_router in (research_router, entity_search_router, entity_router):
    for route in composed_router.routes:
        signature = (
            route.path,
            tuple(sorted(getattr(route, "methods", set()) or set())),
        )
        if signature not in _existing:
            historical_router.routes.append(route)
            _existing.add(signature)
