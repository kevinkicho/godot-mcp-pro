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

## v1.55+

- Groups/layers: `set_physics_layer_names`, `find_nodes_in_group`, `batch_set_node_groups`
- Autoloads: `list_autoloads`, `set_autoload`, `remove_autoload`
- Unique names: `batch_set_scene_unique_names`, `find_node_by_unique_name`
- Preload registry + manifest; TileSet physics/nav layers; compositor stack
- Clipboard/duplicate nodes; input replay manifests; spring bone scaffold

## v1.56+ — 2D masterpiece surface

Full agent path for production 2D games (pixel + skeletal + tiles + mesh):

- **Pixel project:** **`apply_pixel_2d_project_preset`** `preset=classic_pixel|hd_pixel|pixel_canvas_items|smooth_2d` (stretch, integer scale, nearest, snap, AA off)
- **Textures:** `apply_pixel_texture_import_batch` / `apply_texture_import_preset 2d_pixel` / `set_canvas_item_texture_filter`
- **Skeleton2D:** `setup_skeleton_2d` → `add_bone_2d` → `set_bone_2d_rest` → **`setup_two_bone_ik_2d`** / `list_bones_2d`
- **Mesh2D:** `setup_mesh_instance_2d`, `create_quad_mesh_2d`, **`convert_sprite_to_mesh_instance_2d`**, `setup_multimesh_instance_2d`
- **Tile scenes/patterns:** `tileset_add_scenes_collection_source`, `tileset_add_scene_tile`, `tileset_add_pattern_from_rect`, **`tilemap_stamp_pattern`**
- Discovery domain: **`list_tools_by_domain domain=2d`** · `agent_workflow_guide topic=2d`

## v1.57+ — structural production surface

- **Shapes:** `create_shape_resource` / `setup_collision_from_shape_resource` (shared Circle/Capsule/Box… `.tres`)
- **Custom draw:** `list_canvas_draw_recipes` → **`setup_canvas_draw_node`** (grid, health_bar, FOV cone, …)
- **SubViewport:** minimap/portal via `setup_subviewport_2d_world` + `setup_viewport_texture_rect` / BackBufferCopy
- **Instances:** `instance_packed_scene`, `set_editable_instance`, `make_scene_instance_local`, placeholders
- **Tile layers:** **`setup_tilemap_layer_stack`** (Ground/Walls/Decor) + assign tileset
- **SFX:** `setup_polyphonic_player`, `create_sfx_pool_script`
- **Pipelines:** **`pipeline_2d_pixel_game`**, **`pipeline_2d_tilemap_level`**
- **FABRIK 2D:** `setup_fabrik_ik_2d` when available

## v1.58+ — pathfinding, PBR materials, fonts, diagnostics

- **AStar:** `setup_astar_grid_controller` / grid + point-graph scripts (tile/grid games)
- **PBR:** `create_standard_material_3d` / `assign_material_3d_to_mesh`
- **UI type:** `create_label_settings` / `create_font_file_resource` / `set_label_font_size`
- **Env dump:** `get_agent_environment_report` (engine/OS/project/scene)
- **Resources:** `save_resource_as` / `convert_resource_format` (.tres↔.res)
- **Ship gate:** **`pipeline_pre_ship_check`**
- **Coverage %:** see `docs/COVERAGE_SCORECARD.md` · live `list_docs_coverage`

## v1.59+ — character, environment, TPS, net, audio FX

- **Motion:** **`apply_character_body_preset`** platformer_2d|topdown_2d|fps_3d|third_person_3d
- **TPS camera:** **`setup_third_person_camera_rig`** / `setup_spring_arm_3d`
- **World look:** `create_procedural_sky` → `create_environment_resource` → `assign_environment_to_world` / FogVolume
- **Audio FX:** `add_audio_bus_effect_typed type=reverb|compressor|eq6|…`
- **ENet:** `create_enet_multiplayer_script` + **`pipeline_multiplayer_enet`**
- **Pipelines:** **`pipeline_3d_character_tps`**, `pipeline_pre_ship_check`
- **Settings bulk:** `batch_set_project_settings` / `list_project_settings_by_prefix`
- **AnimPlayer:** autoplay, libraries, speed, status
- **PhysicsMaterial + occlusion culling** helpers

## v1.60+ — highest-gain agent workflows

- **Pack props:** **`pack_node_as_scene`** path=res://props/x.tscn (optional replace_with_instance)
- **InputMap portability:** `export_input_map_json` / `import_input_map_json`
- **Layers by name:** `set_collision_layers_by_name layers=[player]` / mask by name
- **Net sync bulk:** `add_replication_properties_bulk properties=[position,velocity]`
- **Make unique:** `make_resource_unique property=material_override`
- **Find in tree:** `find_nodes_by_class class_name=CharacterBody2D` / name pattern / reorder_node
- **Camera limits:** **`set_camera_2d_limits_from_tilemap`**
- **Juice:** `setup_floating_text_spawner` / hit flash script

## v1.61+ — multiplayer lobby + full game loop (recommended)

Ship-loop depth for agents:

- **`pipeline_game_loop_shell`** — main menu + GameFlow + SceneTransition + save serializer
- **`pipeline_multiplayer_lobby`** — ENet + lobby ready-up + spawn points + spawn service
- Lobby: `create_multiplayer_lobby_script` → `set_ready` / `start_match`
- Spawns: `setup_spawn_points` + `create_player_spawn_service_script`
- Saves: `capture_scene_state` → `write_save_slot_json` / `create_game_state_serializer_script`
- Inventory: `create_item_resource` + `create_inventory_component_script`

## v1.62+ — XR + VisualShader catalog + Export CI

- **XR:** **`pipeline_xr_setup`** / `setup_xr_player_rig` / movement · grab · teleport · pickup
- **VisualShader:** `list_visual_shader_node_catalog` · batch nodes · presets (toon, pulse, scroll UV, triplanar, fresnel outline)
- **Export CI:** **`pipeline_export_ci`** — preset pack + GitHub Actions + headless `.ps1`/`.sh`

## v1.63+ — remaining surface closure

Production surface is **complete for agent shipping** (workflows + discovery + ClassDB escapes):

- **`get_production_surface_report`** / **`list_out_of_scope_surfaces`** — honesty map
- Migration: `scan_project_migration_report` · `scan_tscn_godot3_markers`
- iOS: `get_ios_export_checklist` · `get_platform_export_matrix`
- Theme I/O · ClassDB `get_class_usage_examples` / `suggest_class_for_task`
- Runtime: logger · achievements · day/night · feature flags · a11y · WebSocket client
- Plugin: `package_addon_folder` · `validate_editor_plugin_cfg`

**Not goals:** console SDKs, 1 tool per ClassDB method, hosted backends, pure visual graph UIs.

## v1.64+ — structural refactor

- Modules in **`commands/<domain>/`** (recursive discover) — `list_command_domains` / `list_command_modules`
- Shared parsers: prefer base `parse_vec2` / `parse_color` / `save_resource_to_res`
- Registry groups by domain; no tool renames (API stable)

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
