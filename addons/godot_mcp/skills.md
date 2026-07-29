> **Language:** English | [日本語](skills.ja.md) | [Português (BR)](skills.pt-br.md) | [Español](skills.es.md) | [Русский](skills.ru.md) | [简体中文](skills.zh.md) | [हिन्दी](skills.hi.md)

# Godot MCP Pro — Skills for AI Assistants

> Project-neutral. Works with any Godot 4 project that has the plugin enabled.
> Copy this file into your project (e.g. `.claude/skills.md` or Grok skill) to steer agents toward **agent-driven game production**.

## What is Godot MCP Pro?

This is the control plane for **agent-driven game production**: create scenes, write scripts, playtest, simulate input, inspect runtime state, and iterate—without the user leaving the conversation. When the editor plugin is connected, mutations go through UndoRedo (Ctrl+Z). Prefer MCP tools over raw filesystem edits of `.tscn` / `project.godot`.

**Start every session with `health_check`.** Use `agent_production_status` / `agent_workflow_guide` for the production loop.

**Headless principle:** work as if a human is using the Godot IDE. MCP surfaces the docks (FileSystem, Import, Inspector, Signals, Play, Mesh menu, CSG). Prefer tools over hand-editing `.tscn` / `project.godot`.

You have access to a large set of editor tools (900+) when connected, plus CLI tools when the editor is offline.

### Human workflow parity (v1.46+)

```
mesh_create_trimesh_static_body / mesh_create_convex_collision  → Mesh menu
playtest_sequence steps=[wait,action,assert,screenshot]         → play + press keys
remap_resource_references (dry_run first)                       → move/rename assets
editor_focus_node / editor_frame_selection                      → F-key frame
csg_set_operation + csg_bake_to_mesh_instance                   → greybox finalize
audit_scene_tree / list_scene_signals / validate_all_scenes     → scene health
```

## Essential Workflows

### 0. New project / first hour (human Project Settings)

```
scaffold_project_defaults  → folders, viewport, layers, input preset, main scene
create_input_map_preset    → platformer_2d | fps_basic | ui_menu (if not via scaffold)
```

### 0c. Modern game systems (prefer over raw add_node stacks)

```
setup_character_2d / setup_character_3d   → player with controller script
setup_ai_agent_2d / setup_ai_agent_3d     → nav + chase/patrol AI
setup_hitbox / setup_hurtbox / health     → combat
setup_hud / setup_pause_menu / inventory  → game UI
apply_environment_preset                  → cinematic/outdoor/horror look
setup_camera_follow_2d / third_person     → cameras
create_game_state_script / audio_manager  → autoloads
list_*_templates / list_render_presets    → discovery
```

### 0d. 3D import / quests / multiplayer

```
list_imported_scene_contents → extract_meshes_from_scene → instance_scene_as_inherited
set_gltf_import_flags / set_fbx_import_flags / list_scene_import_options
create_quest_resource + create_quest_log_script + create_dialogue_graph_resource
export_dialogue_graph_mermaid / add_dialogue_graph_node
create_multiplayer_game_manager_script + create_multiplayer_lobby_ui
setup_multiplayer_player_scene + setup_multiplayer_spawn_stack
```

### 0e. Advanced (WebRTC, BT, VFX, settings, export)

```
create_webrtc_multiplayer_template + create_signaling_server_script
create_input_buffer_netcode_script
setup_behavior_tree_on_node + create_behavior_tree_resource
create_shader_preset / apply_canvas_shader_to_node / setup_screen_fade_overlay
create_settings_manager_script + setup_settings_menu
create_enhanced_save_manager_script + setup_save_slot_menu
export_and_verify / list_export_templates
```

### 0f. Native run probe (structure first, video for motion)

```
run_session_start record=true
run_find_nodes / assert_node_state / get_game_node_properties
run_log_event  →  markers in events.jsonl
run_capture_timeline  →  property time series
run_record_stop  →  session.mp4 (FFmpeg)
media_extract_keyframes / media_clip_video / media_contact_sheet
run_session_stop

# Optional CI unit tests (wrappers, not reimplemented):
detect_test_frameworks → run_gut_tests | run_gdunit_tests

# One-shot:
run_probe_report

# TCP runtime (1.34) — preferred transport; works standalone:
ensure_runtime_autoloads
run_ping_runtime
runtime_call (server) when editor offline

# Web export only (optional Playwright):
web_serve_export → web_playwright_probe → web_serve_stop
```

### 0b. Asset intake (human FileSystem + Import)

```
stage_files_into_res  → copy OS files into res://assets (or dest_dir)
ensure_imported       → wait until ResourceLoader-ready
import_paths          → one-shot stage-or-ensure
```

### 1. Explore a Project

Always start by understanding the project before making changes:

```
agent_production_status   → dashboard: import idle, open scene, command count
get_project_info          → project name, Godot version, renderer, viewport size
get_filesystem_tree       → directory structure (use filter: "*.tscn" or "*.gd")
get_scene_tree            → node hierarchy of the currently open scene
read_script               → read any GDScript file
get_project_settings      → check project configuration
```

### 2. Build a 2D Scene

```
create_scene   → create .tscn file with root node type
add_node       → add child nodes with properties
create_script  → write GDScript for game logic
attach_script  → attach script to a node
update_property → set position, scale, modulate, etc.
save_scene     → save to disk
```

**Example — creating a player:**
1. `create_scene` with root_type `CharacterBody2D`, path `res://scenes/player.tscn`
2. `add_node` type `Sprite2D` with texture property
3. `add_node` type `CollisionShape2D`
4. `add_resource` to assign a shape (e.g., `RectangleShape2D`) to the CollisionShape2D
5. `create_script` with movement logic
6. `attach_script` to the root node
7. `save_scene`

### 3. Build a 3D Scene

```
create_scene         → root_type: Node3D
add_mesh_instance    → add primitives (box, sphere, cylinder, plane) or import .glb/.gltf
setup_lighting       → add DirectionalLight3D, OmniLight3D, or SpotLight3D
setup_environment    → sky, ambient light, fog, tonemap
setup_camera_3d      → camera with optional SpringArm3D for third-person
set_material_3d      → PBR materials (albedo, metallic, roughness, emission)
setup_collision      → add collision shapes to physics bodies
setup_physics_body   → configure mass, friction, gravity
```

### 4. Write & Edit Scripts

```
create_script  → create new .gd file (provide full content)
edit_script    → modify existing scripts
  - Use `replacements: [{search: "old code", replace: "new code"}]` for targeted edits
  - Use `content` for full file replacement
  - Use `insert_at_line` + `text` for inserting code
validate_script → check for syntax errors without running
read_script    → read current content before editing
```

### 5. Signals (human Signal dock)

```
wire_signal_to_new_method  → connect + create method on target script (preferred)
connect_signal             → connect existing method only
get_signals                → list signals + connections on a node
```

### 6. Playtest & Debug

```
playtest_report        → one-shot: play → settle → errors/tree/asserts/screenshot → stop
play_scene             → launch the game (mode: "current", "main", or file path)
get_game_screenshot    → see what the game looks like right now
capture_frames         → capture multiple frames to observe motion/animation
get_game_scene_tree    → inspect the live scene tree at runtime
get_game_node_properties → read runtime values (position, health, state, etc.)
set_game_node_property → modify values in the running game
simulate_key           → press keys (WASD, SPACE, etc.) with duration
simulate_mouse_click   → click at viewport coordinates
simulate_action        → trigger InputMap actions (move_left, jump, etc.)
get_editor_errors      → check for runtime errors
stop_scene             → stop the game
```

**Playtesting loop:**
1. `play_scene` → start the game
2. `get_game_screenshot` → see current state
3. `simulate_key` / `simulate_action` → interact with the game
4. `capture_frames` → observe behavior over time
5. `get_game_node_properties` → check specific values
6. `stop_scene` → stop when done
7. Fix issues in scripts → repeat

### 6. Animations (human Animation editor surface)

```
# AnimationPlayer library / clips
list_animations / create_animation / rename_animation / duplicate_animation
ensure_RESET via ensure_reset_animation
list_animation_libraries / add_animation_library

# Tracks & keys (value, method, audio, bezier, 3D, blend_shape, …)
add_animation_track / remove_animation_track
set_animation_keyframe / remove_animation_key
insert_method_key / insert_audio_key / insert_animation_playback_key

# Playback (like Play button)
animation_player_play / stop / seek / queue / set_autoplay / set_speed
set_root_motion_track

# 2D SpriteFrames
sprite_frames_create / add_animation / add_frame / assign

# Skeleton3D dock
find_skeletons / list_skeleton_bones / get_bone_info / set_bone_pose
```

**Example — bouncing sprite:**
1. `create_animation` name `bounce`, length `1.0`, loop_mode `1` (linear loop)
2. `add_animation_track` track_path `Sprite2D:position`, track_type `value`
3. `set_animation_keyframe` time `0.0`, value `Vector2(0, 0)`
4. `set_animation_keyframe` time `0.5`, value `Vector2(0, -50)`
5. `set_animation_keyframe` time `1.0`, value `Vector2(0, 0)`
6. `animation_player_play` to preview

### 7. UI / HUD

```
add_node          → Control, Label, Button, TextureRect, etc.
set_anchor_preset → position Controls (full_rect, center, bottom_wide, etc.)
set_theme_color   → change font_color, etc.
set_theme_font_size → adjust text size
set_theme_stylebox  → backgrounds, borders, rounded corners
connect_signal    → wire up button pressed, value_changed, etc.
```

### 8. TileMap

```
tilemap_get_info      → check tile set sources and atlas layout
tilemap_set_cell      → place individual tiles
tilemap_fill_rect     → fill rectangular regions
tilemap_get_used_cells → see what's already placed
tilemap_clear         → clear all cells
```

### 9. Audio

```
add_audio_bus        → create audio buses (SFX, Music, UI)
set_audio_bus        → adjust volume, solo, mute
add_audio_bus_effect → add reverb, delay, compressor, etc.
add_audio_player     → add AudioStreamPlayer(2D/3D) nodes
```

### 10. Project Configuration

```
set_project_setting  → change viewport size, physics settings, etc.
set_input_action     → define input mappings (move_left → KEY_A, etc.)
add_autoload         → register autoload singletons
set_physics_layers   → name collision layers (player, enemy, world, etc.)
```

## Important Rules & Pitfalls

### Prefer Inspector Properties Over Code
When changing visual properties (colors, sizes, theme overrides, transforms, etc.), use `update_property` to set them directly on the node. This keeps values visible in the Godot inspector and easy to tweak by hand. Only write GDScript when the property isn't available in the inspector or needs to be dynamic at runtime.

### Property Values
Properties are auto-parsed from strings. Use these formats:
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` or `"#ff0000"`
- Bool: `"true"` / `"false"`
- Numbers: `"42"`, `"3.14"`
- Enums: Use integer values (e.g., `0` for the first enum value)

### Never Edit project.godot Directly
Godot editor constantly overwrites `project.godot`. Always use `set_project_setting` to change project settings.

### GDScript Type Annotations
When writing GDScript with `for` loops over untyped arrays, use explicit type annotations:
```gdscript
# BAD — will cause errors
for item in some_untyped_array:
    var x := item.value  # type inference fails

# GOOD
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### Script Changes Need Reload
After creating or significantly modifying scripts, use `reload_project` to ensure Godot picks up the changes. This is especially important after `create_script`.

### simulate_key Tips
- Use **short durations** (0.3–0.5 seconds) for precise movement
- Long durations (1+ seconds) cause overshooting
- For gameplay testing, prefer `simulate_action` over `simulate_key` when InputMap actions are defined

### simulate_mouse_click
- Default `auto_release: true` sends both press and release — required for UI buttons
- UI buttons fire on release, so both events are needed

### execute_game_script Limitations
- No nested functions (`func` inside `func`) — causes compile error
- Use `.get("property")` instead of `.property` for dynamic access
- Runtime errors will pause the debugger (auto-continued, but avoid if possible)

### Collision & Pickup Areas
- For collectible items, use Area3D/Area2D with radius ≥ 1.5
- Smaller radii are nearly impossible to trigger with simulated input

### Save Frequently
Call `save_scene` after making significant changes. Unsaved changes can be lost if the editor reloads.

## Analysis & Debugging Tools

When something goes wrong, use these tools to investigate:

```
get_editor_errors          → check for script errors and runtime exceptions
get_output_log             → read print() output and warnings
analyze_scene_complexity   → find performance bottlenecks
analyze_signal_flow        → visualize signal connections
detect_circular_dependencies → find circular script/scene references
find_unused_resources      → clean up unused files
get_performance_monitors   → FPS, memory, draw calls, physics stats
```

## Testing & QA

```
run_test_scenario   → define and run automated test sequences
assert_node_state   → verify node properties match expected values
assert_screen_text  → verify text is displayed on screen
compare_screenshots → visual regression testing (use file paths, not base64)
run_stress_test     → spawn many nodes to test performance
```

## Advanced Patterns

### Cross-Scene Operations
```
cross_scene_set_property → modify nodes in scenes that aren't currently open
find_node_references     → find all files referencing a pattern
batch_set_property       → set a property on all nodes of a type
```

### Shader Workflow
```
create_shader        → write GLSL-like shader code
assign_shader_material → apply to a node
set_shader_param     → adjust uniforms at runtime
get_shader_params    → inspect current values
```

### Navigation (3D)
```
setup_navigation_region → define walkable area
bake_navigation_mesh   → generate navmesh
setup_navigation_agent → add pathfinding to characters
```

### AnimationTree & State Machines (human graph surface)
```
create_animation_tree / set_animation_tree_active / set_animation_tree_player
get_animation_tree_structure / list_tree_parameters
add_state_machine_state         → animation|blend_tree|state_machine|blend_space_1d|2d
add_state_machine_transition / set_state_machine_transition
travel_animation_state          → playback.travel like clicking a state
add_blend_space_point           → blend space editor points
set_blend_tree_node / connect_blend_tree_nodes
set_tree_parameter              → parameters/* blend positions, oneshots
```

### Coding-Solo parity (CLI + fork extras)

These tools match free `godot-mcp` (Coding-Solo) capabilities:

```
get_godot_version     → engine version (CLI or editor)
list_projects         → find project.godot under a directory
launch_editor         → open Godot editor for a project path
run_project           → run game as separate process (open server CLI)
get_debug_output      → capture that process stdout/stderr
stop_project          → kill CLI-run process / stop_scene
load_sprite           → assign texture to Sprite2D/Sprite3D/TextureRect
export_mesh_library   → scene → MeshLibrary for GridMap
get_uid               → resource UID (file_path)
update_project_uids   → resave resources to refresh UIDs
get_connection_status → is the editor plugin connected?
list_mcp_commands     → all plugin command names
call_editor           → invoke any plugin method by name
```

When the open MCP server is used: prefer the editor when connected; otherwise headless CLI.

### Code-to-Inspector Migration

Move hardcoded visual properties from GDScript to the inspector for easier tweaking:

```
read_script          → find hardcoded property assignments
get_node_properties  → check current inspector values
update_property      → set values as node properties
edit_script          → remove hardcoded lines from script
save_scene           → persist inspector changes
validate_script      → verify script still compiles
```

Example — a script sets `modulate = Color(1, 0, 0, 1)` in `_ready()`:
1. `read_script` to find the line
2. `update_property` with `node_path`, `property: "modulate"`, `value: "Color(1, 0, 0, 1)"`
3. `edit_script` to remove the `modulate = ...` line from `_ready()`
4. `save_scene` + `validate_script`

This applies to: colors, positions, sizes, theme overrides, material properties, visibility, margins, anchors, and any property that doesn't need to change at runtime.

## Recommended Workflow Order

When building a new game from scratch:

1. **Project setup** — `get_project_info`, `set_project_setting` (viewport, physics)
2. **Input mapping** — `set_input_action` for all player controls
3. **Main scene** — `create_scene`, set as main scene
4. **Player** — create player scene with sprite, collision, script
5. **Level/World** — build environment (TileMap, 3D meshes, etc.)
6. **Game logic** — scripts for enemies, items, UI
7. **Audio** — set up buses, add audio players
8. **Playtest** — `play_scene`, test with simulated input, fix bugs
9. **Polish** — animations, particles, shaders, themes
10. **Export** — `list_export_presets`, `export_project`
