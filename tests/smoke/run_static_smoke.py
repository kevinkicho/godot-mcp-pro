#!/usr/bin/env python3
"""Static smoke matrix over all tool specs.

Without Godot: validates each tool's spec is well-formed and classifies
whether live smoke is allowed. Writes tests/reports/static_smoke_report.json.

This is the offline gate for 'every tool has a testable contract'.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

TESTS = Path(__file__).resolve().parents[1]
ROOT = TESTS.parent
SPECS = TESTS / "catalog" / "tool_specs.json"
SUMMARY = TESTS / "catalog" / "summary.json"
REPORTS = TESTS / "reports"


def main() -> int:
    # Ensure catalog
    import subprocess
    gen = TESTS / "generate_catalog.py"
    subprocess.run([sys.executable, str(gen)], cwd=str(ROOT), check=False)

    specs = json.loads(SPECS.read_text(encoding="utf-8"))
    summary = json.loads(SUMMARY.read_text(encoding="utf-8"))
    tools = specs["tools"]

    results = []
    counts = {
        "total": len(tools),
        "contract_ok": 0,
        "contract_fail": 0,
        "live_eligible_empty_params": 0,
        "live_eligible_scene": 0,
        "live_skip_runtime": 0,
        "live_skip_destructive": 0,
        "live_skip_mutate": 0,
    }

    required_keys = {
        "id", "module", "domain", "risk", "smoke_kind", "smoke_params",
        "expected", "assertions",
    }

    for name, spec in sorted(tools.items()):
        issues = []
        if not required_keys.issubset(spec.keys()):
            issues.append(f"missing keys: {sorted(required_keys - set(spec.keys()))}")
        if "returns_dict_envelope" not in spec.get("assertions", []):
            issues.append("missing returns_dict_envelope assertion")
        sk = spec.get("smoke_kind")
        params = spec.get("smoke_params") or {}
        if sk in ("empty_params", "list_empty"):
            counts["live_eligible_empty_params"] += 1
        elif sk == "scene_gated":
            counts["live_eligible_scene"] += 1
        elif sk == "runtime_gated":
            counts["live_skip_runtime"] += 1
        elif sk == "destructive_gated":
            counts["live_skip_destructive"] += 1
        elif sk == "mutate_minimal":
            counts["live_skip_mutate"] += 1

        ok = len(issues) == 0
        if ok:
            counts["contract_ok"] += 1
        else:
            counts["contract_fail"] += 1
        results.append({
            "tool": name,
            "ok": ok,
            "issues": issues,
            "smoke_kind": sk,
            "risk": spec.get("risk"),
            "domain": spec.get("domain"),
            "live_params": params,
        })

    report = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "plugin_version": summary.get("plugin_version"),
        "mode": "static_contract",
        "counts": counts,
        "pass": counts["contract_fail"] == 0,
        "note": (
            "Static smoke verifies every tool has a test contract. "
            "Full behavioral validation requires live Godot + plugin: "
            "run tests/live via validate_all_tools / run_tool_validation_suite."
        ),
        "results": results,
    }
    REPORTS.mkdir(parents=True, exist_ok=True)
    out = REPORTS / "static_smoke_report.json"
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")

    # Compact markdown
    md = [
        f"# Static smoke report",
        "",
        f"- Plugin: **{report['plugin_version']}**",
        f"- Tools: **{counts['total']}**",
        f"- Contract OK: **{counts['contract_ok']}**",
        f"- Contract FAIL: **{counts['contract_fail']}**",
        f"- Live-eligible empty-params: **{counts['live_eligible_empty_params']}**",
        f"- Scene-gated: **{counts['live_eligible_scene']}**",
        f"- Runtime-gated: **{counts['live_skip_runtime']}**",
        f"- Destructive-gated: **{counts['live_skip_destructive']}**",
        f"- Mutate-minimal: **{counts['live_skip_mutate']}**",
        "",
        f"**PASS:** {report['pass']}",
        "",
    ]
    (REPORTS / "static_smoke_report.md").write_text("\n".join(md), encoding="utf-8")
    print(json.dumps({"pass": report["pass"], "counts": counts}, indent=2))
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
