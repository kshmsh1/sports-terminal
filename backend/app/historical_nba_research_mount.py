from __future__ import annotations

from .historical_nba_api import router as historical_router
from .historical_nba_research_api import router as research_router

# The canonical historical router is already mounted ahead of generic NBA dataset
# routes in main_launch. Extend its concrete route collection so deep-research
# endpoints inherit that safe ordering without duplicating or rewriting main-launch
# composition. Research routes carry their full /v2/nba/history prefix.
_existing = {(route.path, tuple(sorted(getattr(route, "methods", set()) or set()))) for route in historical_router.routes}
for route in research_router.routes:
    signature = (route.path, tuple(sorted(getattr(route, "methods", set()) or set())))
    if signature not in _existing:
        historical_router.routes.append(route)
        _existing.add(signature)
