from __future__ import annotations

import runpy
from pathlib import Path

# Load the exact production launch entrypoint first so base-schema initialization,
# domain hardening, middleware registration and router imports match deployment.
from app import main_launch as _main_launch  # noqa: F401

runpy.run_path(
    str(Path(__file__).with_name("customer_ops_contract_test.py")),
    run_name="__main__",
)
