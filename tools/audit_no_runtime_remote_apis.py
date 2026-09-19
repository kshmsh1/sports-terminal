#!/usr/bin/env python3
"""Reject remote runtime network dependencies in customer-facing Dart code.

Same-origin static JSON loaders are explicitly allowed because a Flutter web app
must retrieve its own immutable asset files from the application host.
"""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
ALLOWED_STATIC_LOADERS = {
    LIB / "services" / "website_nba_static_repository.dart",
    LIB / "services" / "nba_live_game_service.dart",
}
REMOTE_URL = re.compile(r"https?://", re.IGNORECASE)
HTTP_IMPORT = "package:http/http.dart"

violations: list[str] = []

for path in sorted(LIB.rglob("*.dart")):
    text = path.read_text(encoding="utf-8")
    relative = path.relative_to(ROOT)

    for match in REMOTE_URL.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        violations.append(f"{relative}:{line}: explicit remote URL")

    if HTTP_IMPORT in text and path not in ALLOWED_STATIC_LOADERS:
        line = text[: text.index(HTTP_IMPORT)].count("\n") + 1
        violations.append(
            f"{relative}:{line}: HTTP client import outside approved same-origin static loader"
        )

# The approved loaders may only resolve same-origin static paths. They may not
# contain explicit remote URLs, which the check above enforces for every file.

if violations:
    print("Remote runtime network policy violations:")
    for item in violations:
        print(f" - {item}")
    sys.exit(1)

print("Runtime network audit passed: no explicit remote URLs or unapproved HTTP clients in lib/.")
