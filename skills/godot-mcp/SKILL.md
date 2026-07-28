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

1. Call **`health_check`** (or `get_connection_status`).
2. If `editor_connected` / `ready_for_agent_production` is false:
   - Ask the user to open their Godot 4 project with **Godot MCP Pro** plugin enabled, **or**
   - Call `launch_editor` with their `project_path`, then wait and re-check.
3. Call **`agent_workflow_guide`** when starting a non-trivial production task.
4. For API unknowns: **`describe_class`** (full ClassDB / class-reference surface).
5. For docs-area map: **`list_docs_coverage`** (every official tutorials/* topic → tools).
6. After copying assets: **`scan_filesystem`** → **`wait_for_import`** → then scene work.

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

## Human-like inspector fine-tuning

Work like a person in the Inspector / Scene dock:

1. **`select_nodes`** or navigate with **`get_scene_tree`**
2. **`inspect_node`** or **`list_property_info`** — see types, enums, ranges, current values
3. **`update_property`** / **`update_properties`** — fine-tune fields (supports nested `shape.radius`)
4. **Resources:** `add_resource` (e.g. shape, material) → then nest-tune; **`clear_property`** / **`remove_resource`** to empty a slot
5. **Signals:** `get_signals` → `connect_signal` / `disconnect_signal`
6. **Meshes:** `add_mesh_instance`, `set_material_3d`, `update_property` on `mesh`
7. **Meta / groups:** `set_meta`, `list_meta`, `set_node_groups`
8. **`save_scene`**

To **add/remove script parameters** (`@export` vars): `read_script` → `edit_script` (add/remove export lines) → `validate_script` → `reload_project` if needed. Inspector then shows new exports via `list_property_info`.

Topic guide: `agent_workflow_guide` with `topic: "inspector"`.

## Human animation surface

Work like a person in the Animation / AnimationTree / Skeleton docks:

1. **Clips:** `list_animations` → `create_animation` / `rename_animation` / `duplicate_animation` / `ensure_reset_animation`
2. **Tracks & keys:** `add_animation_track` (value|method|audio|bezier|…) → `set_animation_keyframe` / `insert_method_key` / `insert_audio_key`
3. **Playback:** `animation_player_play` / `seek` / `stop` / `queue` / `set_autoplay` / `set_root_motion_track`
4. **Libraries:** `list_animation_libraries` / `add_animation_library`
5. **AnimationTree:** `create_animation_tree` → `add_state_machine_state` → `add_state_machine_transition` → `travel_animation_state` / `set_tree_parameter`
6. **Blend spaces:** state_type `blend_space_1d|2d` → `add_blend_space_point`
7. **2D frames:** `sprite_frames_*` + assign to AnimatedSprite2D
8. **Skeleton3D:** `find_skeletons` → `list_skeleton_bones` → `get_bone_info` / `set_bone_pose`

Discover by surface: `list_mcp_commands` with `surface: "animation"` or `"skeleton"`.

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
