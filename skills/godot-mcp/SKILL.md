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
4. Call **`list_agent_domains`** / **`get_agent_capability_map`** to discover domains (v1.54+).
5. Call **`agent_workflow_guide`** for non-trivial production.
6. Unknown APIs: **`describe_class`**; full command list: **`list_mcp_commands`** / **`search_mcp_tools`** / **`call_editor`**.
7. Docs map: **`list_docs_coverage`**.
8. After assets: **`scan_filesystem`** → **`wait_for_import`** / **`ensure_imported`**.
9. On play failures: **`playtest_fix_loop`** or **`get_fix_plan_from_errors`**.

**IDE parity:** With the plugin connected, prefer MCP for everything a human does in Godot (scenes, inspector numbers, animation/curves, humanoid, levels, GridMap, mesh collision, CSG bake, resource remaps, viewport focus, streaming, music, interactive playtest). Use **`call_editor`** for any registered method not typed in the client. Batch with **`batch_call_editor`**. Offline: `write_project_file`, headless scene ops, `run_project`. Docs: `docs/IDE_PARITY.md`, `docs/HEADLESS_AGENT.md`, `docs/HUMANOID_AND_LEVELS.md`.

## Production loop (default)

```
health_check
  → get_project_info / get_filesystem_tree
  → get_scene_tree or open_scene
  → mutate (create_scene, add_node, update_property, create_script, attach_script, …)
  → mesh_create_trimesh_static_body / csg_bake as needed
  → save_scene / validate_script / audit_scene_tree
  → playtest_report OR playtest_sequence (wait/action/assert/screenshot)
  → stop_scene → fix → repeat
```

## Closed-loop playtest (human “play and press keys”)

Prefer **`playtest_sequence`** when you need interaction, not just a boot check:

```
playtest_sequence mode=main steps=[
  {type:action, action:ui_right, pressed:true, auto_release:true, hold_sec:0.4},
  {type:wait, sec:0.3},
  {type:assert, node_path:Player, property:position},
  {type:screenshot}
]
```

Also: `playtest_report` (errors + optional asserts), `simulate_*`, `run_session_*` for long captures.

## Mesh collision & level finalization

- Mesh menu: **`mesh_create_trimesh_static_body`**, `mesh_create_convex_collision`, multi-convex
- CSG: `csg_set_operation` → **`csg_bake_to_mesh_instance`** (+ collision)
- Resource move: `find_files_referencing` → **`remap_resource_references`** (dry_run first)
- Focus viewport: **`editor_focus_node`** / `editor_frame_selection`

## LOD, lightmaps, movie, nav debug, AnimationTree (v1.47+)

- LODs: **`mesh_generate_lods`**, `set_visibility_range`, `setup_lod_mesh_instances`
- Lightmap: **`mesh_lightmap_unwrap`**, `batch_prepare_lightmap_meshes`, **`lightmap_bake_prepare`**
- Movie: `play_with_movie_maker` or portable **`capture_play_session`**
- Nav: `navigation_query_path` → `draw_debug_path`; `navigation_set_debug_enabled`
- Anim graph: **`create_simple_locomotion_tree`**, `create_blend_space_1d_locomotion`, `export_animation_tree_graph`

## Pipelines & quality packs (v1.48+)

Prefer composed pipelines for multi-step human docks:

- **`list_agent_pipelines`**
- `pipeline_prepare_level_lighting`, `pipeline_setup_prop_lods`
- `pipeline_nav_debug_route`, `pipeline_character_locomotion`, `pipeline_greybox_to_playable`
- `apply_platform_render_pack pack=mobile|desktop|high_end`
- `navigation_live_path from=… to=…`

## Structural systems (v1.49+ / docs audit)

- Particles: `set_particle_process_params`, attractors, turbulence, CPU particles  
- Interaction: **`setup_interaction_zone`**, prompt UI, controller script, `bind_interaction_action`  
- Export: **`get_export_signing_checklist`**, Android keystore helpers  
- IO: `create_http_client_script`, **`encrypted_file_write`/`read`**  
- Physics debug: `editor_raycast`, `set_collision_debug_visible`  
- Structure: VisibleOnScreen*, RemoteTransform, WorldBoundary, Occluder, Marker  
- Hygiene: **`analyze_project_best_practices`**  
- Map: `docs/SDK_STRUCTURE_EXPANSION.md`

## v1.50+ surface growth

- i18n: `extract_strings_from_open_scene`, `export_translation_csv`, `import_translation_csv`  
- Terrain tiles: `tileset_set_terrain_peering`, `tilemap_fill_terrain_rect`  
- Import: `list_import_option_schema`, `apply_import_schema_preset`  
- PathFollow / AudioStreamGenerator / DisplayServer window tools  
- Joint limits: hinge / slider / 6DOF / pin

## v1.51+

- Ragdoll: **`generate_ragdoll_from_skeleton`**, `create_ragdoll_control_script`  
- XR: `set_xr_passthrough_settings`, composition layer quad, passthrough controller script  
- TileSet atlas: region size, create/remove tile regions, texture origin  
- SoftBody params/pin, **`setup_vehicle_body`**, SpriteFrames speed/loop/frame edit

## v1.52+

- Shader includes: `create_shader_include_library_preset`, `shader_add_include`  
- UI: Tab/Split/Flow/Center/AspectRatio/SubViewport containers  
- Multiplayer interest manager + synchronizer bandwidth helpers  
- Timer, tween recipes, SkeletonIK, Label/RichText setup

## v1.53+

- Cameras: `setup_camera_2d`/`3d`, limits, FOV, make current  
- 2D lights: CanvasModulate, LightOccluder2D, PointLight2D  
- Async `ResourceLoader` helpers; StyleBoxFlat theme tools  
- Utility AI / GOAP recipes; `evaluate_expression`; Decal3D depth

## v1.54+ (100% production surfacing roadmap)

- **Discovery:** `list_agent_domains`, `list_tools_by_domain`, `search_mcp_tools`, `get_tool_examples`, `get_agent_capability_map`
- **Fix loop:** `playtest_fix_loop`, `diagnose_playtest_failure`, `assert_scene_playable`
- **Character:** `pipeline_character_from_gltf`, `pipeline_retarget_animations`
- **Theme:** `theme_seed_default_types`, fonts/icons/list/copy type
- **Dialogue graph:** add/set/remove lines & choices, validate
- **Debugger:** `analyze_debugger_errors`, `get_fix_plan_from_errors`
- **Perf:** `analyze_performance_budget`
- **VisualShader presets + tile custom data layers**

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
5. **Keys / Bezier plane:** `set_animation_keyframe`, `bezier_list_keys_cartesian`, `bezier_set_keys_batch`, `bezier_sample_dense`
6. **Curve/Path resources:** `curve2d_*`, `curve3d_*`, `path_set_curve_points` (Cartesian control points)
7. **Verify:** `compare_animations`, `sample_animation_at_time`, `animation_player_play` + playtest

Map focal points as plane coordinates — full numerical SDK access.  
`list_animation_fine_tune_tools` · `list_curve_sdk_tools` · `docs/ANIMATION_FINE_TUNE.md` · `docs/CURVES_AND_BEZIER.md`.

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
