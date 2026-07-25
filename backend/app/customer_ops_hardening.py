from __future__ import annotations

from collections.abc import Callable

from .main import init_db


def hardened_customer_ops_initializer(
    original_initializer: Callable[[], None],
) -> Callable[[], None]:
    if getattr(original_initializer, "_sports_terminal_customer_ops_hardened", False):
        return original_initializer

    def initialize() -> None:
        # Customer operations references users and the seeded plan catalog. It
        # must therefore be safe as the first product domain touched in a clean
        # database, independent of router startup order.
        init_db()
        original_initializer()

    setattr(initialize, "_sports_terminal_customer_ops_hardened", True)
    return initialize
