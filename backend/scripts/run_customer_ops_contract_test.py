from __future__ import annotations

import runpy
from pathlib import Path

# Load the exact production launch entrypoint first so base-schema initialization,
# domain hardening, middleware registration and router imports match deployment.
from app import main_launch as _main_launch  # noqa: F401

scripts = Path(__file__).parent
for script in (
    "customer_ops_contract_test.py",
    "customer_ops_tools_contract_test.py",
):
    runpy.run_path(str(scripts / script), run_name="__main__")
