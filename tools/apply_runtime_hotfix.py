import re
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


research = Path("lib/screens/product_nba_research_command_center_screen.dart")
text = research.read_text()
old = "    setState(() => _workspaceFuture = Future.value(next));"
if text.count(old) != 2:
    raise SystemExit(
        f"{research}: expected 2 Future.value workspace callbacks, found {text.count(old)}"
    )
text = text.replace(
    old,
    """    setState(() {
      _workspaceFuture = Future.value(next);
    });""",
)

pattern = re.compile(
    r"onPressed:\s*\(\)\s*=>\s*setState\(\s*\(\)\s*=>\s*"
    r"_workspaceFuture\s*=\s*_store\.load\(widget\.session\),?\s*\),"
)
text, count = pattern.subn(
    """onPressed: () => setState(() {
            _workspaceFuture = _store.load(widget.session);
          }),""",
    text,
)
if count != 1:
    raise SystemExit(f"{research}: expected 1 reload callback, found {count}")
research.write_text(text)

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
