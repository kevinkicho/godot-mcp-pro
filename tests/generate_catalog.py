#!/usr/bin/env python3
"""Generate tool catalog + base specs for every registered plugin command.

Parses addons/godot_mcp/commands/**/*_commands.gd and writes:
  tests/catalog/tool_catalog.json
  tests/catalog/tool_specs.json
  tests/catalog/summary.json
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMANDS = ROOT / "addons" / "godot_mcp" / "commands"
OUT = Path(__file__).resolve().parent / "catalog"
PLUGIN_CFG = ROOT / "addons" / "godot_mcp" / "plugin.cfg"

CMD_KEY_RE = re.compile(r'^\s*"([a-z0-9_]+)":\s*(_[a-zA-Z0-9_]+)\s*,?\s*$', re.M)
FUNC_RE = re.compile(r"^func\s+(_[a-zA-Z0-9_]+)\s*\(", re.M)
REQUIRE_STRING_RE = re.compile(r'require_string\s*\(\s*params\s*,\s*"([^"]+)"')
REQUIRE_RES_RE = re.compile(r'require_res_path\s*\(\s*params\s*,\s*"([^"]+)"')
OPTIONAL_RE = re.compile(r'optional_(?:string|bool|int)\s*\(\s*params\s*,\s*"([^"]+)"')
PARAMS_HAS_RE = re.compile(r'params\.has\s*\(\s*"([^"]+)"\s*\)')
PARAMS_GET_RE = re.compile(r'params\.get\s*\(\s*"([^"]+)"')

# Risk / runtime classification heuristics by name prefix/suffix
READISH = (
    "list_", "get_", "find_", "search_", "count_", "describe_", "inspect_",
    "detect_", "analyze_", "validate_", "suggest_", "export_", "dump_",
    "sample_", "compare_", "health_", "uid_", "project_path_to",
)
MUTATEISH = (
    "set_", "add_", "create_", "setup_", "apply_", "remove_", "delete_",
    "clear_", "batch_", "move_", "rename_", "write_", "save_", "import_",
    "bake_", "generate_", "pack_", "instance_", "equip_", "unequip_",
    "pipeline_", "autofix_", "bulk_", "assign_", "connect_", "duplicate_",
)
RUNTIMEISH = (
    "play", "playtest", "runtime", "game_", "screenshot", "simulate_",
    "assert_", "run_test", "stress", "watchdog", "movie",
)
DESTRUCTIVE = (
    "delete_", "remove_", "clear_", "bulk_delete", "delete_resource",
)


def plugin_version() -> str:
    text = PLUGIN_CFG.read_text(encoding="utf-8")
    m = re.search(r'version="([^"]+)"', text)
    return m.group(1) if m else "unknown"


def domain_from(path: Path) -> str:
    rel = path.relative_to(COMMANDS)
    parts = rel.parts
    if len(parts) > 1:
        return parts[0]
    return "root"


def extract_handler_body(text: str, handler: str) -> str:
    """Best-effort extract function body for param scanning."""
    m = re.search(rf"func\s+{re.escape(handler)}\s*\([^)]*\)[^\n]*\n", text)
    if not m:
        return ""
    start = m.end()
    # until next top-level func or end
    nxt = re.search(r"\nfunc\s+", text[start:])
    end = start + nxt.start() if nxt else len(text)
    return text[start:end]


def classify(name: str) -> dict:
    risk = "low"
    needs_scene = False
    needs_runtime = False
    is_list = name.startswith("list_") or name.endswith("_tools") or name.endswith("_recipes")
    is_pipeline = name.startswith("pipeline_")
    is_destructive = any(name.startswith(p) for p in DESTRUCTIVE) or "delete" in name
    is_read = any(name.startswith(p) for p in READISH) or is_list
    is_mutate = any(name.startswith(p) for p in MUTATEISH)
    is_runtime = any(k in name for k in RUNTIMEISH)

    if is_destructive:
        risk = "high"
    elif is_pipeline or is_mutate:
        risk = "medium"
    if is_read and not is_mutate:
        risk = "low"

    scene_hints = (
        "node", "scene", "camera", "mesh", "skeleton", "animation", "tilemap",
        "light", "physics", "character", "avatar", "canvas", "viewport",
        "navigation", "add_node", "update_property", "select_",
    )
    if any(h in name for h in scene_hints) and not is_list:
        needs_scene = True
    if is_runtime:
        needs_runtime = True
        if risk == "low":
            risk = "medium"

    # list/discovery tools typically don't need scene
    if is_list or name.startswith("describe_") or name.startswith("list_"):
        needs_scene = False

    smoke_kind = "list_empty"
    if is_list or name.endswith("_tools") or name.endswith("_recipes") or name.endswith("_catalog"):
        smoke_kind = "empty_params"
    elif needs_runtime:
        smoke_kind = "runtime_gated"
    elif needs_scene:
        smoke_kind = "scene_gated"
    elif is_destructive:
        smoke_kind = "destructive_gated"
    elif is_mutate:
        smoke_kind = "mutate_minimal"
    else:
        smoke_kind = "empty_params"

    return {
        "risk": risk,
        "needs_scene": needs_scene,
        "needs_runtime": needs_runtime,
        "is_list_like": is_list,
        "is_pipeline": is_pipeline,
        "is_destructive": is_destructive,
        "smoke_kind": smoke_kind,
    }


def smoke_params_for(name: str, required: list[str], smoke_kind: str) -> dict:
    """Default params for structural smoke / live dry attempts."""
    if smoke_kind in ("empty_params", "list_empty"):
        return {}
    if smoke_kind == "destructive_gated":
        return {"__skip__": True, "reason": "destructive"}
    if smoke_kind == "runtime_gated":
        return {"__skip__": True, "reason": "needs_runtime"}
    # mutate / scene: provide placeholders that should fail gracefully (missing scene)
    params: dict = {}
    for r in required:
        if r in ("path", "from", "to", "out_path", "script_path", "material_path", "gltf_path"):
            params[r] = f"res://__mcp_test__/{name}/{r}"
        elif r in ("node_path", "parent_path", "source_path", "target_path", "skeleton_path"):
            params[r] = "."
        elif r in ("type", "name", "method", "group", "property", "slot"):
            params[r] = "MCPTest"
        elif r in ("expression",):
            params[r] = "1+1"
        else:
            params[r] = "test"
    if not params and smoke_kind == "scene_gated":
        params = {"node_path": "."}
    return params


def expected_shape(smoke_kind: str) -> dict:
    return {
        "success_or_structured_error": True,
        "no_crash": True,
        "result_keys_any_of": ["result", "error"],
        "notes": {
            "empty_params": "Expect success with tools/list payload or structured invalid_params",
            "scene_gated": "Without open scene, error_no_scene / not_found is acceptable",
            "runtime_gated": "Skip unless game running",
            "destructive_gated": "Skip unless explicit LIVE_DESTRUCTIVE=1",
            "mutate_minimal": "May fail validation; must return MCP error envelope not exception",
        }.get(smoke_kind, ""),
    }


def parse_module(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8", errors="replace")
    funcs = set(FUNC_RE.findall(text))
    domain = domain_from(path)
    module = path.stem
    tools = []
    for m in CMD_KEY_RE.finditer(text):
        name, handler = m.group(1), m.group(2)
        body = extract_handler_body(text, handler)
        required = sorted(set(REQUIRE_STRING_RE.findall(body) + REQUIRE_RES_RE.findall(body)))
        optional = sorted(set(OPTIONAL_RE.findall(body) + PARAMS_HAS_RE.findall(body) + PARAMS_GET_RE.findall(body)))
        # optional shouldn't duplicate required
        optional = [o for o in optional if o not in required]
        cls = classify(name)
        tools.append({
            "name": name,
            "handler": handler,
            "handler_exists": handler in funcs,
            "module": module,
            "domain": domain,
            "path": str(path.relative_to(ROOT)).replace("\\", "/"),
            "required_params": required,
            "optional_params_detected": optional[:40],
            **cls,
            "smoke_params": smoke_params_for(name, required, cls["smoke_kind"]),
            "expected": expected_shape(cls["smoke_kind"]),
        })
    return tools


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    all_tools: list[dict] = []
    by_name: dict[str, list[dict]] = defaultdict(list)
    modules = sorted(COMMANDS.rglob("*_commands.gd"))
    for p in modules:
        for t in parse_module(p):
            all_tools.append(t)
            by_name[t["name"]].append(t)

    duplicates = {k: [x["path"] for x in v] for k, v in by_name.items() if len(v) > 1}
    missing_handlers = [t["name"] for t in all_tools if not t["handler_exists"]]

    domain_counts: dict[str, int] = defaultdict(int)
    risk_counts: dict[str, int] = defaultdict(int)
    smoke_counts: dict[str, int] = defaultdict(int)
    for t in all_tools:
        domain_counts[t["domain"]] += 1
        risk_counts[t["risk"]] += 1
        smoke_counts[t["smoke_kind"]] += 1

    catalog = {
        "generated": date.today().isoformat(),
        "plugin_version": plugin_version(),
        "totals": {
            "tools": len(all_tools),
            "unique_names": len(by_name),
            "modules": len(modules),
            "domains": len(domain_counts),
            "duplicates": len(duplicates),
            "missing_handlers": len(missing_handlers),
        },
        "domain_counts": dict(sorted(domain_counts.items())),
        "risk_counts": dict(sorted(risk_counts.items())),
        "smoke_kind_counts": dict(sorted(smoke_counts.items())),
        "duplicates": duplicates,
        "missing_handlers": missing_handlers,
        "tools": sorted(all_tools, key=lambda t: t["name"]),
    }

    # Specs: one entry per unique tool name (last registration wins for duplicates — flagged)
    specs = {
        "schema_version": 1,
        "description": "Auto-generated base specs for every MCP plugin command. Live runner uses these for smoke validation.",
        "plugin_version": catalog["plugin_version"],
        "tools": {},
    }
    for t in catalog["tools"]:
        specs["tools"][t["name"]] = {
            "id": t["name"],
            "module": t["module"],
            "domain": t["domain"],
            "risk": t["risk"],
            "needs_scene": t["needs_scene"],
            "needs_runtime": t["needs_runtime"],
            "smoke_kind": t["smoke_kind"],
            "required_params": t["required_params"],
            "smoke_params": t["smoke_params"],
            "expected": t["expected"],
            "assertions": [
                "returns_dict_envelope",
                "has_result_or_error",
                "error_has_code_and_message_if_error",
                "no_unhandled_exception",
            ],
            "status": "auto_generated",
            "manual_review": t["risk"] == "high" or t["is_pipeline"],
        }

    summary = {
        "generated": catalog["generated"],
        "plugin_version": catalog["plugin_version"],
        "tools": catalog["totals"]["tools"],
        "unique_names": catalog["totals"]["unique_names"],
        "modules": catalog["totals"]["modules"],
        "domains": catalog["totals"]["domains"],
        "duplicates": catalog["totals"]["duplicates"],
        "missing_handlers": catalog["totals"]["missing_handlers"],
        "by_risk": catalog["risk_counts"],
        "by_smoke_kind": catalog["smoke_kind_counts"],
        "integrity_ok": catalog["totals"]["duplicates"] == 0 and catalog["totals"]["missing_handlers"] == 0,
    }

    (OUT / "tool_catalog.json").write_text(json.dumps(catalog, indent=2), encoding="utf-8")
    (OUT / "tool_specs.json").write_text(json.dumps(specs, indent=2), encoding="utf-8")
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    # Human-readable index of all tools
    lines = [
        f"# Tool catalog ({catalog['plugin_version']})",
        "",
        f"Generated: {catalog['generated']}",
        f"Tools: **{summary['tools']}** | Unique: **{summary['unique_names']}** | Modules: **{summary['modules']}**",
        f"Integrity: **{'PASS' if summary['integrity_ok'] else 'FAIL'}**",
        "",
        "## By domain",
        "",
    ]
    for d, c in catalog["domain_counts"].items():
        lines.append(f"- **{d}**: {c}")
    lines += ["", "## All tools", ""]
    for t in catalog["tools"]:
        lines.append(
            f"- `{t['name']}` · {t['domain']}/{t['module']} · risk={t['risk']} · smoke={t['smoke_kind']}"
        )
    (OUT / "TOOL_CATALOG.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(json.dumps(summary, indent=2))
    return 0 if summary["integrity_ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
