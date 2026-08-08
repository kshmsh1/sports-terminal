from pathlib import Path


def replace(path_str: str, old: str, new: str, expected: int = 1) -> None:
    path = Path(path_str)
    text = path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(
            f"{path}: expected {expected} copies, found {count}: {old[:100]!r}"
        )
    path.write_text(text.replace(old, new))


research = "lib/screens/product_nba_research_command_center_screen.dart"
replace(
    research,
    "    setState(() => _workspaceFuture = Future.value(next));",
    """    setState(() {
      _workspaceFuture = Future.value(next);
    });""",
    expected=2,
)
replace(
    research,
    """          onPressed: () => setState(
            () => _workspaceFuture = _store.load(widget.session),
          ),""",
    """          onPressed: () => setState(() {
            _workspaceFuture = _store.load(widget.session);
          }),""",
)

# Report any remaining expression-bodied setState callbacks that appear to
# assign asynchronous work. Flutter debug mode asserts when a setState callback
# returns a Future even if static analysis and release compilation accept it.
suspects: list[str] = []
for path in Path("lib").rglob("*.dart"):
    lines = path.read_text().splitlines()
    for index, line in enumerate(lines):
        if "setState(" not in line:
            continue
        context = "\n".join(lines[index : min(index + 5, len(lines))])
        if "=>" not in context:
            continue
        if "Future" in context or ".load(" in context or "_store." in context:
            suspects.append(f"{path}:{index + 1}\n{context}")

if suspects:
    print("ASYNC SETSTATE AUDIT — review remaining suspects:")
    print("\n---\n".join(suspects))
else:
    print("ASYNC SETSTATE AUDIT — no likely Future-returning arrow callbacks remain.")
