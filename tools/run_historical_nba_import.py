from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType
from typing import Callable


MAX_SQL_IDENTIFIER_LENGTH = 180


def load_importer() -> ModuleType:
    path = Path(__file__).with_name("import_historical_nba_sources.py")
    spec = importlib.util.spec_from_file_location("sports_terminal_historical_importer", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load historical importer: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def robust_unique_columns(
    headers: list[str],
    safe_identifier: Callable[..., str],
) -> list[str]:
    """Return SQLite-safe column names with collision-free deterministic suffixes.

    The original importer counted duplicate *base* identifiers. That still allowed a
    collision when a generated suffix matched another source header, e.g.
    `n_3p_2`, duplicate `n_3p_2` -> `n_3p_2_2`, followed by a source header that
    itself normalized to `n_3p_2_2`. SQLite identifiers are case-insensitive, so we
    reserve every emitted final name using casefold() and retry suffixes until the
    candidate is globally unique.
    """

    emitted: set[str] = set()
    next_suffix: dict[str, int] = {}
    result: list[str] = []

    for index, header in enumerate(headers):
        fallback = f"column_{index + 1}"
        base = safe_identifier(header or fallback, fallback=fallback)
        candidate = base
        suffix = next_suffix.get(base.casefold(), 2)

        while candidate.casefold() in emitted:
            suffix_text = f"_{suffix}"
            prefix_limit = max(1, MAX_SQL_IDENTIFIER_LENGTH - len(suffix_text))
            candidate = f"{base[:prefix_limit]}{suffix_text}"
            suffix += 1

        emitted.add(candidate.casefold())
        next_suffix[base.casefold()] = suffix
        result.append(candidate)

    return result


def main() -> int:
    importer = load_importer()
    original_safe_identifier = importer.safe_identifier
    importer.unique_columns = lambda headers: robust_unique_columns(
        headers,
        original_safe_identifier,
    )
    return int(importer.main())


if __name__ == "__main__":
    raise SystemExit(main())
