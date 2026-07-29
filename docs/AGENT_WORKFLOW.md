# Agent workflow

How coding agents should drive **game production** with Godot MCP Pro — not only edit files on disk.

## First actions every session

1. **`health_check`** — plugin version, WebSocket clients, open scene, play state, issues  
2. If not ready: ask user to open Godot with the plugin, or **`launch_editor`** + re-check  
3. **`agent_workflow_guide`** for non-trivial work (`topic`: production / 2d / 3d / ui / playtest / inspector)  
4. Unknown APIs: **`describe_class`** (ClassDB)  
5. Docs-area map: **`list_docs_coverage`**  
6. After dropping assets: **`scan_filesystem`** → **`wait_for_import`** → then scene work  

## Default production loop

```
health_check
  → get_project_info / get_filesystem_tree
  → get_scene_tree or open_scene
  → mutate (create_scene, add_node, update_property, create_script, attach_script, …)
  → save_scene / validate_script
  → play_scene / run_session_start
  → get_game_screenshot / get_game_scene_tree / assert_node_state / run_find_nodes
  → simulate_action / simulate_key as needed
  → optional: run_record_start → … → run_record_stop → media_extract_keyframes
  → stop_scene / run_session_stop → fix → repeat
```

## Human-like inspector work

1. **`select_nodes`** or **`get_scene_tree`**  
2. **`inspect_node`** / **`list_property_info`** — types, enums, ranges  
3. **`update_property`** / **`update_properties`** (nested paths e.g. `shape.radius`)  
4. Resources: **`add_resource`** → nest-tune; **`clear_property`** / **`remove_resource`**  
5. Signals: **`get_signals`** → **`connect_signal`** / **`disconnect_signal`** / **`wire_signal_to_new_method`**  
6. **`save_scene`**  

`@export` parameters: edit script → **`validate_script`** → **`reload_project`** if needed.

## Animation surface (summary)

- Clips: `list_animations`, `create_animation`, tracks/keyframes  
- Playback: `animation_player_play` / seek / stop  
- AnimationTree: state machines, blend spaces, `travel_animation_state`  
- Skeleton3D: `find_skeletons`, bones, poses  

Discover: `list_mcp_commands` with `surface: "animation"` or `"skeleton"`.

## Production macros (headless IDE parity)

| Tool | Human equivalent |
|------|------------------|
| `scaffold_project_defaults` | First-hour Project Settings + folders + main scene |
| `create_input_map_preset` | Project → Input Map |
| `stage_files_into_res` / `ensure_imported` | Drop assets + Import dock |
| `wire_signal_to_new_method` | Signal dock → connect + method |
| `playtest_report` | Play, glance Output/game, stop |
| `agent_production_status` | “Is the editor ready?” |

See [PRODUCTION_SYSTEMS.md](PRODUCTION_SYSTEMS.md) for characters, AI, quests, multiplayer, VFX.

## Rules

- Prefer **live editor tools** when connected (UndoRedo, screenshots, runtime).  
- Writes use **`res://`** paths — never absolute OS paths for create/edit.  
- Do **not** hand-edit `project.godot`; use `set_project_setting`, `add_autoload`, `set_input_action`.  
- After big script changes: `validate_script` and/or `reload_project`.  
- In **lite mode**, use **`call_editor`** for tools not in the reduced list.  
- Coverage is **workflow-strong**, not “100% of ClassDB” — see `list_docs_coverage` and [../GAPS_VS_GODOT_DOCS.md](../GAPS_VS_GODOT_DOCS.md).

## Offline / CLI fallback

Without the editor: `list_projects`, `launch_editor`, `run_project`, headless scene ops (need `project_path`).  
Production quality requires the **plugin connected**.

## Skill file

Grok / agent skill: [../skills/godot-mcp/SKILL.md](../skills/godot-mcp/SKILL.md).
