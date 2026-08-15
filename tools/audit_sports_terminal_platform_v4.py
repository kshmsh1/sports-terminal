from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CONVERGENCE_ASSERTIONS: dict[str, tuple[str, ...]] = {
    # The Bloomberg-inspired primitives remain implemented, but the customer
    # experience is intentionally website-first. The blueprint is an
    # underlying capability contract rather than a requirement to surround
    # every page with terminal chrome.
    "lib/widgets/app_entry_gate.dart": (
        "TraditionalWebsiteShell",
        "conventional",
        "responsive website",
    ),
    "lib/widgets/traditional_website_shell.dart": (
        "Home",
        "NBA",
        "Stats",
        "Analytics",
        "Trade Machine",
        "Front Office",
        "deliberately detached from the primary customer navigation",
    ),
    "lib/widgets/blueprint_terminal_frame.dart": (
        "TerminalCommandBar",
        "TerminalStatusBar",
        "TerminalDensityService",
        "ProductNbaTerminalScreen",
        "ProductTradeMachineScreen",
        "ProductPythonDevLabScreen",
        "ExcelLikeWorkspaceScreen",
    ),
    "lib/widgets/sports_terminal_operating_shell.dart": (
        "TerminalContextRail",
        "TerminalIntelligenceRail",
        "TerminalDensitySelector",
    ),
    "docs/traditional_website_ux_reset.md": (
        "conventional responsive website",
        "Python Lab and spreadsheet/Excel-style Workspace are deliberately detached",
        "Missing source data must never be hidden by fabricated statistics",
    ),
    "docs/sports_terminal_blueprint_status.json": (
        '"sports-terminal-master-blueprint-v1"',
        '"official_live_nba_feed": "rights-blocked"',
        '"nba_commercial_data_rights": "business-development-blocked"',
    ),
    ".github/workflows/flutter_quality.yml": (
        "workflow_dispatch",
        "audit_sports_terminal_platform_v4.py --check",
    ),
}


def _run(script: str) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(ROOT / script), "--check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode, (result.stdout + result.stderr).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/sports_terminal_platform_v4.json")
    args = parser.parse_args()

    failures: list[dict[str, str]] = []
    assertions = 0
    passed = 0

    for relative, tokens in CONVERGENCE_ASSERTIONS.items():
        path = ROOT / relative
        if not path.exists():
            failures.append({"path": relative, "missing": "<file>"})
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            assertions += 1
            if token in text:
                passed += 1
            else:
                failures.append({"path": relative, "missing": token})

    # Guard the core simplification explicitly. These systems may remain in the
    # codebase, but they must not be mounted by the authenticated entry gate.
    entry_text = (ROOT / "lib/widgets/app_entry_gate.dart").read_text(encoding="utf-8")
    for forbidden in (
        "BlueprintTerminalFrame(",
        "RoleResearchAugmentedShell(",
        "LaunchRoleProductShell(",
        "AdminNbaTerminalOverlay(",
    ):
        assertions += 1
        if forbidden not in entry_text:
            passed += 1
        else:
            failures.append({"path": "lib/widgets/app_entry_gate.dart", "missing": f"must not mount {forbidden}"})

    website_text = (ROOT / "lib/widgets/traditional_website_shell.dart").read_text(encoding="utf-8")
    for forbidden in (
        "label: 'Workspace'",
        "label: 'Python Lab'",
        "Checking launch status",
        "Quick research",
        "NBA Universe",
    ):
        assertions += 1
        if forbidden not in website_text:
            passed += 1
        else:
            failures.append({"path": "lib/widgets/traditional_website_shell.dart", "missing": f"primary website must not expose {forbidden}"})

    legacy_code, legacy_output = _run("tools/audit_production_platform_v3.py")
    blueprint_code, blueprint_output = _run("tools/audit_sports_terminal_blueprint_v1.py")
    if legacy_code != 0:
        failures.append({
            "path": "tools/audit_production_platform_v3.py",
            "missing": "recursive-production-v3-pass",
        })
    if blueprint_code != 0:
        failures.append({
            "path": "tools/audit_sports_terminal_blueprint_v1.py",
            "missing": "master-blueprint-v1-pass",
        })

    payload = {
        "contract": "sports-terminal-blueprint-converged-platform-v4",
        "presentation": "traditional-responsive-website",
        "composes": [
            "sports-terminal-code-complete-local-review-v3",
            "sports-terminal-master-blueprint-v1",
        ],
        "surfaces": len(CONVERGENCE_ASSERTIONS),
        "assertions": assertions,
        "passed": passed,
        "failures": failures,
        "legacy_output": legacy_output[-2000:],
        "blueprint_output": blueprint_output[-2000:],
        "external_non_code_requirements": [
            "commercial NBA data rights / authoritative live production feed",
            "licensed tracking and video where required",
            "operator-selected hosted/vendor accounts",
            "regulated-product legal programs before real-money execution",
        ],
    }
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 1 if args.check and failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
