import re
from pathlib import Path


def replace(path_str: str, old: str, new: str, expected: int = 1) -> None:
    path = Path(path_str)
    text = path.read_text()
    count = text.count(old)
    if count == 0 and new in text:
        return
    if count != expected:
        raise SystemExit(
            f"{path}: expected {expected} copies, found {count}: {old[:110]!r}"
        )
    path.write_text(text.replace(old, new))


# Research workspace futures. These may already be fixed by an earlier hotfix run.
research = Path("lib/screens/product_nba_research_command_center_screen.dart")
text = research.read_text()
old = "    setState(() => _workspaceFuture = Future.value(next));"
safe = """    setState(() {
      _workspaceFuture = Future.value(next);
    });"""
count = text.count(old)
if count == 2:
    text = text.replace(old, safe)
elif count != 0 or text.count(safe) < 2:
    raise SystemExit(
        f"{research}: unexpected workspace callback state; old={count}, safe={text.count(safe)}"
    )
pattern = re.compile(
    r"onPressed:\s*\(\)\s*=>\s*setState\(\s*\(\)\s*=>\s*"
    r"_workspaceFuture\s*=\s*_store\.load\(widget\.session\),?\s*\),"
)
text, refresh_count = pattern.subn(
    """onPressed: () => setState(() {
            _workspaceFuture = _store.load(widget.session);
          }),""",
    text,
)
if refresh_count == 0 and "_workspaceFuture = _store.load(widget.session);" not in text:
    raise SystemExit(f"{research}: workspace reload callback was neither old nor hardened")
research.write_text(text)

# Connected Community and Messages futures.
network = "lib/screens/product_connected_network_screens.dart"
replace(
    network,
    "    setState(() => future = _load());",
    """    setState(() {
      future = _load();
    });""",
)
replace(
    network,
    "    setState(() => conversationsFuture = service.conversations(widget.session));",
    """    setState(() {
      conversationsFuture = service.conversations(widget.session);
    });""",
)

# Launch/customer operations refresh.
replace(
    "lib/screens/product_launch_center_screen.dart",
    "    setState(() => future = service.load(widget.session));",
    """    setState(() {
      future = service.load(widget.session);
    });""",
)

# Organization workspace permissions refresh after grant/remove.
replace(
    "lib/screens/product_connected_workspace_screen.dart",
    "    setState(() => future = widget.service.permissions(widget.session));",
    """    setState(() {
      future = widget.service.permissions(widget.session);
    });""",
    expected=2,
)

# Front-office registry refresh.
replace(
    "lib/screens/product_front_office_registry_screen.dart",
    "    setState(() => future = _load());",
    """    setState(() {
      future = _load();
    });""",
)

# Entity Intelligence futures: season, context and watchlist.
entity = "lib/screens/product_nba_entity_command_center_screen.dart"
replace(
    entity,
    "  void _refreshSeason() => setState(() => _seasonFuture = _loadSeason());",
    """  void _refreshSeason() {
    setState(() {
      _seasonFuture = _loadSeason();
    });
  }""",
)
replace(
    entity,
    "    setState(() => _contextFuture = Future.value(active));",
    """    setState(() {
      _contextFuture = Future.value(active);
    });""",
)
replace(
    entity,
    "setState(() => _watchlistFuture = _watchlist.load());",
    """setState(() {
        _watchlistFuture = _watchlist.load();
      });""",
    expected=3,
)

# Historical Intelligence shared-context refresh.
replace(
    "lib/screens/product_nba_historical_intelligence_screen.dart",
    "    setState(() => _contextFuture = _contexts.load());",
    """    setState(() {
      _contextFuture = _contexts.load();
    });""",
)

# Shell launch-status refresh.
replace(
    "lib/widgets/launch_role_product_shell.dart",
    "    setState(() => _statusFuture = _loadStatus());",
    """    setState(() {
      _statusFuture = _loadStatus();
    });""",
)

# Report remaining likely async expression-bodied setState callbacks. Block-bodied
# callbacks that merely assign a Future are safe because they return void.
suspects: list[str] = []
arrow_assignment = re.compile(r"setState\(\s*\(\)\s*=>\s*([^\n;]+)")
for path in Path("lib").rglob("*.dart"):
    text = path.read_text()
    lines = text.splitlines()
    for match in narrow_assignment.finditer(text):
        expression = match.group(1).strip()
        if any(
            token in expression
            for token in (
                "Future",
                ".load(",
                "_load(",
                "service.",
                "_store.",
                "_contexts.",
                "_watchlist.",
            )
        ):
            line_no = text[: match.start()].count("\n") + 1
            context = "\n".join(lines[line_no - 1 : min(line_no + 2, len(lines))])
            suspects.append(f"{path}:{line_no}\n{context}")

if suspects:
    raise SystemExit(
        "ASYNC SETSTATE AUDIT FAILED — likely Future-returning arrow callbacks remain:\n"
        + "\n---\n".join(suspects)
    )
print("ASYNC SETSTATE AUDIT PASSED — no likely Future-returning arrow callbacks remain.")
