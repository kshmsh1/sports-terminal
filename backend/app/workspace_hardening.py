from __future__ import annotations

from collections.abc import Callable

from .main import init_db


def hardened_workspace_initializer(
    original_initializer: Callable[[], None],
) -> Callable[[], None]:
    def initialize() -> None:
        # A workspace may be the first launch service touched in a clean database.
        # Initialize the base users/content schema before creating workspace tables
        # with foreign keys into users.
        init_db()
        original_initializer()

    return initialize
