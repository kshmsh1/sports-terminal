from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATUS = ROOT / "docs" / "sports_terminal_convergence_status_v5.json"

ASSERTIONS: dict[str, tuple[str, ...]] = {
    "lib/models/research_object.dart": (
        "schemaVersion = 2",
        "artifactType",
        "contentFingerprint",
        "rightsEnvelopes",
        "previousRevisionKey",
    ),
    "lib/services/research_object_service.dart": (
        "saveIfNewFingerprint",
        "findByFingerprint",
        "latestAll",
        "lineage",
        "Research revisions are immutable",
        "previousRevisionKey: source.revisionKey",
        "exportJson",
    ),
    "lib/models/generated_terminal_report.dart": (
        "contentFingerprint",
        "_fnv1a32",
    ),
    "lib/services/generated_report_research_service.dart": (
        "artifactType: 'generated-report'",
        "route-payload-report-v1",
        "rightsEnvelopes",
    ),
    "lib/widgets/route_payload_generated_report_panel.dart": (
        "SAVE RESEARCH SNAPSHOT",
        "ADD TO RESEARCH BOARD",
        "generated-report-workflow-message",
    ),
    "lib/models/terminal_metric_definition.dart": (
        "TerminalMetricDefinition",
        "sourcePolicy",
        "releasePolicy",
        "coveragePolicy",
        "dependencies",
    ),
    "lib/services/terminal_metric_registry.dart": (
        "point_differential",
        "rolling_average",
        "integrityFailures",
        "dependency cycle",
    ),
    "lib/models/terminal_model_definition.dart": (
        "TerminalModelDefinition",
        "limitations",
        "dependencies",
    ),
    "lib/services/terminal_model_registry.dart": (
        "observed-score-flow-v1",
        "route-payload-report-v1",
        "rights-intersection-v1",
        "research-bundle-v1",
        "integrityFailures",
    ),
    "lib/models/terminal_watch_rule.dart": (
        "TerminalWatchOperator",
        "increaseBy",
        "absoluteChangeBy",
        "TerminalWatchEvaluationState",
        "unavailable",
    ),
    "lib/services/terminal_watch_rule_service.dart": (
        "Current numeric observation is unavailable; the rule fails closed.",
        "requires an explicit previous observation",
        "recordEvaluation",
        "evaluationHistoryKey",
    ),
    "lib/models/terminal_research_bundle.dart": (
        "TerminalResearchBundlePermissionState",
        "unverified",
        "exportState",
        "redistributionState",
        "fingerprint",
    ),
    "lib/services/terminal_research_bundle_service.dart": (
        "rights-unverified",
        "export-rights-denied",
        "redistribution-rights-denied",
        "TerminalResearchBundlePermissionState.unverified",
        "bundle fingerprint mismatch",
    ),
    "lib/services/terminal_board_store.dart": (
        "appendPanel",
        "replaceIfExists",
        "cloneBoard",
    ),
    "lib/services/terminal_research_workflow_service.dart": (
        "saveGeneratedReport",
        "addGeneratedReportToBoard",
        "institutional-research-board",
    ),
    "lib/screens/institutional_research_hub_screen.dart": (
        "Institutional Research OS",
        "RESEARCH LIBRARY",
        "METRIC REGISTRY",
        "MODEL REGISTRY",
        "WATCHES",
        "BUNDLES",
        "BUILD BUNDLE",
    ),
    "lib/widgets/blueprint_terminal_frame.dart": (
        "InstitutionalResearchHubScreen",
        "research-os",
        "TerminalActionKind.watch",
        "TerminalActionKind.board",
    ),
    "docs/sports_terminal_blueprint_status.json": (
        '"generated_report_persistence": "implemented"',
        '"metric_registry": "implemented"',
        '"model_registry": "implemented"',
        '"deterministic_watch_engine": "implemented"',
        '"portable_research_bundles": "implemented"',
        '"institutional_research_os": "implemented"',
        '"nba_commercial_data_rights": "business-development-blocked"',
    ),
    "docs/institutional_research_os_40_unit_convergence.md": (
        "40-Unit Convergence",
        "unknown rights stay unverified",
        "Portable Research Bundle",
    ),
}


def _run_v4() -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "audit_sports_terminal_platform_v4.py"), "--check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode, (result.stdout + result.stderr).strip()


def audit() -> dict[str, object]:
    failures: list[dict[str, str]] = []
    assertions = 0
    passed = 0

    for relative, tokens in ASSERTIONS.items():
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

    if not STATUS.exists():
        failures.append({"path": str(STATUS.relative_to(ROOT)), "missing": "<file>"})
        status: dict[str, object] = {}
    else:
        status = json.loads(STATUS.read_text(encoding="utf-8"))
        if status.get("contract") != "sports-terminal-institutional-research-platform-v5":
            failures.append({"path": str(STATUS.relative_to(ROOT)), "missing": "v5 contract"})
        if status.get("unitCount") != 40:
            failures.append({"path": str(STATUS.relative_to(ROOT)), "missing": "unitCount=40"})
        implemented = status.get("implemented")
        if not isinstance(implemented, list) or len(implemented) != 40:
            failures.append({"path": str(STATUS.relative_to(ROOT)), "missing": "exactly 40 implemented units"})
        external = status.get("externalStillRequired")
        if not isinstance(external, list) or not external:
            failures.append({"path": str(STATUS.relative_to(ROOT)), "missing": "explicit external requirements"})

    v4_code, v4_output = _run_v4()
    if v4_code != 0:
        failures.append({
            "path": "tools/audit_sports_terminal_platform_v4.py",
            "missing": "recursive-platform-v4-pass",
        })

    return {
        "contract": "sports-terminal-institutional-research-platform-v5",
        "composes": [
            "sports-terminal-blueprint-converged-platform-v4",
            "sports-terminal-master-blueprint-v1",
        ],
        "unitCount": status.get("unitCount", 0) if isinstance(status, dict) else 0,
        "surfaces": len(ASSERTIONS),
        "assertions": assertions,
        "passed": passed,
        "failures": failures,
        "v4Output": v4_output[-2000:],
        "status": "pass" if not failures else "fail",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/sports_terminal_platform_v5.json")
    args = parser.parse_args()

    payload = audit()
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 1 if args.check and payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
