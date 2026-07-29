---
name: godot-mcp
description: >
  Use Godot MCP for agent-driven game production in any Godot 4 project.
  Triggers: Godot, GDScript, scenes, playtest, MCP godot tools, game production loop,
  create scene, editor plugin, health_check.
---

# Godot MCP — Agent-driven game production

You control Godot through the **godot** MCP server (open Pro bridge). This is the primary path for building and verifying game content—not only editing files on disk.

## First actions every session

1. Call **`agent_ensure_ready`** with `project_path` when known (launches editor, waits, ensures runtime autoloads, opens main scene).
2. Call **`health_check`** if ensure is unavailable; confirm `ready_for_agent_production`.
3. If still offline: user enables plugin, or `launch_editor` + wait + re-check.
4. Call **`agent_workflow_guide`** for non-trivial production.
5. Unknown APIs: **`describe_class`**; full command list: **`list_mcp_commands`** / **`call_editor`**.
6. Docs map: **`list_docs_coverage`**.
7. After assets: **`scan_filesystem`** → **`wait_for_import`** / **`ensure_imported`**.

**Headless IDE parity:** With the plugin connected you have the full human editor surface (inspector fine-tune, import, play, export). Use **`call_editor`** for any registered method not in the typed tool list. Batch with **`batch_call_editor`**. Offline scaffolding: `write_project_file`, headless `create_scene`/`add_node`, `run_project`. See `docs/HEADLESS_AGENT.md`.

## Production loop (default)

```
health_check
  → get_project_info / get_filesystem_tree
  → get_scene_tree or open_scene
  → mutate (create_scene, add_node, update_property, create_script, attach_script, …)
  → save_scene / validate_script
  → play_scene → get_game_screenshot / get_editor_errors / get_game_node_properties
  → simulate_action or simulate_key as needed
  → stop_scene → fix → repeat
```

## Human-like inspector fine-tuning (full parameter control)

Work like a person in the Inspector / Scene dock. **Every editor-visible property** on a node or nested Resource is readable and writable:

1. **`select_nodes`** or **`get_scene_tree`**
2. **Discover:** `inspect_node deep=true` · `list_property_info recurse_resources=true` · `search_properties` · `get_property`
3. **Unknown types:** `describe_class` / `list_class_properties` (full ClassDB surface)
4. **Tune:** `update_property` / `update_properties` (nested paths, enum **names**, Vector/Color/Transform dicts)
5. **Revert / clear:** `reset_property` · `clear_property`
6. **Resources:** `add_resource` (+ `resource_properties`) → nest-tune `shape.radius`, `material_override.albedo_color`
7. **Methods:** `list_node_methods` → `call_node_method` (or `execute_editor_script`)
8. **Signals / meta / groups:** `connect_signal`, `set_meta`, `set_node_groups`
9. **`save_scene`**

Script `@export` vars appear in `list_property_info` after attach; add/remove via `edit_script` → `validate_script` → `reload_project` if needed.

Topic: `agent_workflow_guide` with `topic: "inspector"`. Doc: `docs/INSPECTOR_FINE_TUNE.md`.

## Human animation surface (including example → fine-tune)

Work like a person in the Animation / AnimationTree / Skeleton docks.

**Yes — if the user asks to edit animations based on examples, use MCP to copy and fine-tune:**

1. **Inspect example:** `extract_animations_from_scene` or `list_animations` + **`dump_animation`**
2. **Copy:** **`apply_example_animation`** (from `.tscn` or open player) or `copy_animation_to_player`
3. **Retarget paths:** `remap_animation_track_paths`
4. **Timing:** `scale_animation_time`, `offset_animation_keys`, `crop_animation`
5. **Keys:** `set_animation_keyframe`, `set_bezier_key`
6. **Verify:** `compare_animations`, `sample_animation_at_time`, `animation_player_play` + playtest

Also: clips create/rename/duplicate, tracks, AnimationTree, Skeleton, SpriteFrames.  
`list_animation_fine_tune_tools` · `agent_workflow_guide topic=animation` · `docs/ANIMATION_FINE_TUNE.md`.

## Coverage honesty

`list_docs_coverage` reports **strong | partial | thin | classdb_only** per docs area — **not** “100% of ClassDB / every dock.”  
v1.26: scene transitions/loading, SaveManager/EventBus/ObjectPool/CameraShake, CanvasLayer/Timer/2D lights, scons GDExtension build.  
Escape hatches: `describe_class`, `execute_editor_script`, `call_editor`.

## Rules

- Prefer **live editor tools** when connected (UndoRedo, screenshots, runtime inspect).
- All **writes** must use **`res://`** paths—never absolute OS paths for create/edit.
- Do **not** hand-edit `project.godot`; use `set_project_setting`, `add_autoload`, `set_input_action`.
- Prefer `update_property` / `update_properties` for inspector-visible values; use scripts for runtime logic only.
- After big script changes: `validate_script` and/or `reload_project` when needed.
- In **lite mode**, core tools are listed; anything else goes through **`call_editor`** with `method` + `params`.
- Use `list_mcp_commands` to discover the full plugin surface when connected.

## Offline / CLI fallback

If the editor is not connected, CLI still supports: `list_projects`, `launch_editor`, `run_project`, `get_debug_output`, headless `create_scene` / `add_node` (need `project_path`). Production quality requires the editor plugin.

## Project neutrality

This skill applies to **any** Godot 4 project. Do not assume a specific game name, folder layout, or content registry unless the user or that project's AGENTS.md says so.
