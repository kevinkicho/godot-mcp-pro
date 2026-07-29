# Tool surface test suite

Validates the **full Godot MCP Pro command surface** (**1628** unique registered tools after integrity cleanup; older “1686” registry totals included false-positive key matches).

## Honest scope

| Layer | What it proves | Needs Godot? | Covers all tools? |
|-------|----------------|:------------:|:-----------------:|
| **L1 Structural** | Every tool is registered, unique, has a handler, has a spec | No | **Yes** |
| **L2 Static smoke contracts** | Every tool has a testable smoke contract + risk class | No | **Yes** |
| **L3 Critical path** | Discovery / list / expression paths return success | Editor optional | Hand-picked |
| **L4 Live suite** | Each tool returns MCP envelope (success **or** structured error) | **Yes** | **Yes (smoke)** |
| **L5 Semantic** | Tool does the *right* game/editor thing | Editor + fixtures | **Partial** (critical paths + future domain fixtures) |

**Important:** L4 proves *stability and contract*, not full product correctness of every mutate tool. Semantic “works as intended” for bake/export/playtest needs domain fixtures and human/agent review. High-risk tools are flagged `manual_review` in specs.

## Quick start (offline)

```powershell
cd godot-mcp-pro
python tests/run_all_static.py
# or
.\tests\run_all_static.ps1
```

Expected output: **ALL STATIC TOOL SURFACE TESTS PASSED**

Artifacts:

| Path | Purpose |
|------|---------|
| `tests/catalog/tool_catalog.json` | Full inventory of every tool |
| `tests/catalog/tool_specs.json` | Per-tool smoke specs (all tools) |
| `tests/catalog/summary.json` | Counts + integrity flag |
| `tests/catalog/TOOL_CATALOG.md` | Human-readable index |
| `tests/reports/static_smoke_report.json` | Contract pass/fail |

Regenerate catalog only:

```powershell
python tests/generate_catalog.py
```

## Live suite (Godot editor + plugin)

With a project that has the MCP plugin enabled and a scene optionally open:

### Via MCP / agent

```
run_critical_path_validation
run_tool_validation_suite mode=all_safe write_report=true
# optional: mode=empty_params | scene_gated | all
# optional: limit=100 for a sample run
export_tool_validation_report report_path=res://mcp_validation_report.json
```

### Modes

| Mode | Behavior |
|------|----------|
| `empty_params` | Only list/discovery-style tools (`{}`) — should mostly **succeed** |
| `all_safe` | empty + scene-gated + light mutate (default) — success **or** structured error |
| `scene_gated` | Tools that need a scene tree |
| `all` | Everything except destructive unless `include_destructive=true` |

Report written to `res://mcp_validation_report.json` (or path you pass).

### Pass criteria (live smoke)

A tool **passes** if the router returns either:

1. `{ "result": ... }` success envelope, or  
2. `{ "error": { "code", "message" } }` structured MCP error  

A tool **fails** if the call throws, hangs, or returns a malformed payload.

## Critical path specs

Hand-authored high-value flows:

`tests/integration/critical_path_specs.json`

Mirror built into `run_critical_path_validation`.

## Spec schema

`tests/specs/tool_spec.schema.json` — JSON Schema for each tool entry in `tool_specs.json`.

## CI recommendation

```yaml
# example
- run: python tests/run_all_static.py
```

Add live suite as a nightly job when a Godot runner with the plugin is available.

## Extending semantic tests

1. Add fixtures under `tests/fixtures/` (scenes, glTF, tilesets).  
2. Add domain cases under `tests/integration/<domain>_specs.json`.  
3. Call tools via `validate_tools_batch` with exact params and assert on `result` fields.  

## Files

```
tests/
  README.md
  generate_catalog.py
  run_all_static.py
  run_all_static.ps1
  catalog/                 # generated
  structural/
    test_surface_integrity.py
  smoke/
    run_static_smoke.py
  integration/
    critical_path_specs.json
  specs/
    tool_spec.schema.json
  reports/                 # generated
```

Live runner lives in the plugin:

`addons/godot_mcp/commands/qa_runtime/tool_validation_commands.gd`
