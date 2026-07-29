# Headless agentic Godot (IDE parity)

Goal: agents use MCP to do **everything a human can do in the Godot IDE**, without fighting connection friction or missing tools.

## Table of contents

1. [Session start](#session-start)
2. [Two planes](#two-planes)
3. [Full surface access](#full-surface-access)
4. [Fine-tune every parameter](#fine-tune-every-parameter)
5. [Offline / CLI fallbacks](#offline--cli-fallbacks)
6. [Batching](#batching)
7. [Restrictions that remain](#restrictions-that-remain)

---

## Session start

```
agent_ensure_ready project_path=D:/games/MyGame
  → launches Godot if MCP not connected (wait_ms default 45s)
  → ensure_runtime_autoloads
  → opens main scene if empty
health_check
agent_workflow_guide
```

Always keep:

1. Godot 4 project with **Godot MCP Pro** plugin enabled  
2. MCP server process (`~/.grok/mcp/godot/build/index.js`)  
3. `GODOT_PATH` set for CLI/headless ops  

---

## Two planes

| Plane | When | Capability |
|-------|------|------------|
| **Edit (WebSocket)** | Plugin connected | Full IDE: UndoRedo, inspector, import, play, export |
| **Run (TCP)** | Game playing / autoloads | Live tree, asserts, video, set nested properties |
| **CLI headless** | Offline scaffolding | create_scene, add_node, write_file, set settings |

Prefer **Edit plane** for production quality.

---

## Full surface access

| Mechanism | Use |
|-----------|-----|
| Typed MCP tools | Common workflows (schemas in lite/cli lists) |
| **`call_editor`** | **Any** of 700+ plugin commands by name |
| **`list_mcp_commands`** | Discover methods (`surface` filter when available) |
| **`list_docs_coverage`** | Docs folder → tools map |
| **`batch_call_editor`** | Multi-step dock work in one RPC |

There is **no intentional lockout** of registered plugin commands for agents when the editor is connected.

---

## Fine-tune every parameter

```
list_property_info node_path=… recurse_resources=true
get_property / update_property / update_properties
search_properties
call_node_method / describe_class
```

See [INSPECTOR_FINE_TUNE.md](INSPECTOR_FINE_TUNE.md).

---

## Offline / CLI fallbacks

| Tool | Needs |
|------|--------|
| `launch_editor` | GODOT_PATH + project_path |
| `run_project` / `get_debug_output` | CLI process |
| `create_scene` / `add_node` | headless `godot_operations.gd` |
| `write_project_file` | project_path + path + content |
| `headless_set_project_setting` | project_path + key + value |
| `runtime_call` | Running game with inspector autoloads |

---

## Batching

```
batch_call_editor calls=[
  {method: "open_scene", params: {path: "res://…"}},
  {method: "add_node", params: {…}},
  {method: "update_properties", params: {…}},
  {method: "save_scene", params: {}}
]
```

---

## Restrictions that remain

These are **engine/API limits**, not MCP policy:

- GPU frame debugger graph (editor UI only)  
- Export template **download** (Manage Export Templates UI / manual install)  
- Some importer dialogs without ClassDB entry points  
- OS-level joypad remapping outside Godot  

Workarounds: `get_export_template_guide`, `get_gpu_profiling_hints`, `execute_editor_script`, `describe_class`.

---

## Related

- [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md)  
- [SURFACE_EXPANSION.md](SURFACE_EXPANSION.md)  
- [INSTALL.md](INSTALL.md)  
