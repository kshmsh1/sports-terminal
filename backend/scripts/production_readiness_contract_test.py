from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


BACKEND = Path(__file__).resolve().parents[1]
SCRIPTS = BACKEND / "scripts"

CONTRACTS = (
    "runtime_config_contract_test.py",
    "database_contract_test.py",
    "migration_contract_test.py",
    "production_bootstrap_contract_test.py",
    "production_readiness_api_contract_test.py",
    "security_tokens_contract_test.py",
    "mfa_contract_test.py",
    "account_security_contract_test.py",
    "entitlements_contract_test.py",
    "billing_contract_test.py",
    "release_management_contract_test.py",
    "platform_audit_contract_test.py",
    "backup_manifest_contract_test.py",
    "rate_limit_contract_test.py",
    "deployment_contract_test.py",
)


def main() -> None:
    env = dict(os.environ)
    env["PYTHONPATH"] = str(BACKEND)
    results: list[dict[str, object]] = []
    failed = False

    for script_name in CONTRACTS:
        script = SCRIPTS / script_name
        if not script.exists():
            results.append(
                {
                    "contract": script_name,
                    "status": "missing",
                    "returncode": 127,
                    "output": "contract file not found",
                }
            )
            failed = True
            continue
        completed = subprocess.run(
            [sys.executable, str(script)],
            cwd=BACKEND,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        output = (completed.stdout + completed.stderr).strip()
        results.append(
            {
                "contract": script_name,
                "status": "pass" if completed.returncode == 0 else "fail",
                "returncode": completed.returncode,
                "output": output[-4000:],
            }
        )
        if completed.returncode != 0:
            failed = True

    payload = {
        "contract": "sports-terminal-production-readiness-v1",
        "contracts": len(CONTRACTS),
        "passed": sum(1 for item in results if item["status"] == "pass"),
        "failed": sum(1 for item in results if item["status"] != "pass"),
        "results": results,
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
