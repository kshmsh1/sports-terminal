from __future__ import annotations

import runpy
from pathlib import Path

# Load the exact production launch entrypoint first so every hardening patch,
# middleware registration and router import is applied before direct contract
# functions are exercised.
from app import main_launch as _main_launch  # noqa: F401

runpy.run_path(
    str(Path(__file__).with_name("platform_completion_contract_test.py")),
    run_name="__main__",
)
