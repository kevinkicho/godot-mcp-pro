# Changelog

All notable changes to Godot MCP Pro will be documented in this file.

---

## v1.69.1 — 2026-07-29

**Tool surface test suite** - structural + smoke contracts for every registered command + live validation harness.

### Offline (no Godot)
- `tests/generate_catalog.py` - inventory all tools → `tool_catalog.json` / `tool_specs.json`
- `tests/structural/test_surface_integrity.py` - uniqueness, handlers, registry coverage
- `tests/smoke/run_static_smoke.py` - per-tool contract checks
- `python tests/run_all_static.py` / `.\scripts\run-tool-tests.ps1`

### Live (editor plugin)
- `list_tool_validation_plan`, `validate_tool_contract`, `validate_tools_batch`
- `run_tool_validation_suite` (all_safe / empty_params / scene_gated)
- `run_critical_path_validation`, `export_tool_validation_report`

### Docs
- `tests/README.md` - layered L1–L5 strategy and honesty about semantic coverage

---

## v1.69.0 — 2026-07-29

**All remaining critical maps** - dialogue/cinematic, cloud/settings/a11y, net prediction, 2D lights, filesystem bulk, perf autofix.

### Dialogue runtime + cinematic timeline
- Validate/merge dialogue JSON graphs
- Typewriter RichText + dialogue balloon UI
- Cinematic timeline script/JSON/player (cuts, camera, dialogue, signals)

### Cloud save / settings / accessibility
- CloudSaveProvider (stub + HTTP template) + SaveCloudSync
- Settings menu controller + UI
- AccessibilitySettings autoload + project stretch defaults

### Multiplayer prediction
- Client prediction, server reconciliation, input buffer, network interpolator
- `setup_prediction_pipeline` + NETWORK_PREDICTION.md notes

### 2D lighting / occlusion depth
- DirectionalLight2D, textured PointLight2D, polygon/rect occluders
- Batch light params + full `setup_2d_lighting_scene_pack`

### Filesystem bulk
- Move/rename/duplicate/delete with optional reference remap
- Bulk move/rename, list directory resources

### Performance autofix
- `suggest_performance_fixes`, packs mobile/balanced/aggressive
- Autofix shadows, LOD visibility, particles, GI mode
- Runtime performance watchdog script

### Discovery domains
- `dialogue_runtime`, `cloud_settings`, `net_prediction`, `light_2d`, `filesystem_bulk`, `perf_autofix`

---

## v1.68.0 — 2026-07-29

**Critical production maps wave** - cameras, combat, crafting, touch, lights, geometry, shaders, steering, audio zones.

### Cameras / cinematic
- `CameraAttributes` practical/physical create + assign + DOF/exposure
- `setup_first_person_camera`, `setup_cinematic_path_camera`, track-to-target, look-at, rail script

### Combat / status
- DamageInfo resource, HealthComponent v2, StatusEffectData + controller
- `setup_damage_pipeline_scripts` one-shot wiring pack

### Crafting / hotbar
- CraftingRecipe + CraftingSystem scripts, recipe JSON
- Hotbar logic + UI, crafting panel UI

### 3D lights + mesh geometry
- Omni/Spot/Directional depth setup + batch params
- GeometryInstance3D: cast_shadow, gi_mode, material_overlay, render layers, batch

### Input / UI / AI / audio / shaders
- Virtual joystick + mobile touch pack + swipe gestures
- Reticle/crosshair, drag-drop slots, control focus neighbors
- Steering behaviors + flock + steering agent
- Reverb zone Area3D + AudioListener3D
- Global shader parameter list/set/add/batch

### Discovery domains
- `cinematic`, `combat`, `crafting`, `touch`, `steering`, `shader_globals`

---

## v1.67.0 — 2026-07-29

**Humanoid avatar gaps closed** - identity, mesh/skin/materials, deep retarget/import, modifiers, anim filters.

### Avatar identity
- `setup_avatar_slot_rig`, `equip_avatar_item`, `unequip_avatar_slot`, `list_avatar_slots`
- `set_avatar_body_scale`, `apply_avatar_loadout`, `export_avatar_loadout`
- `create_avatar_config_resource` / script, `hide_avatar_mesh_surfaces`

### Mesh / skin / materials / face
- `list_mesh_surfaces`, `set_surface_override_material`, `clear_surface_override_material`
- `list_blend_shapes`, `set_blend_shape_value`, `batch_set_blend_shapes`
- `apply_face_pose_preset`, `list_face_pose_presets`
- `get_mesh_skin_info`, `apply_avatar_material_pack`, `apply_skin_tone`

### Skeleton rest authorship
- `set_bone_rest`, `apply_pose_as_rest`, `copy_skeleton_rest`, `scale_bone_rest`
- `tag_skeleton_body_parts`, `get_skeleton_body_part_map`, `validate_skeleton_for_humanoid`

### Deep retarget / import
- `apply_humanoid_import_preset`, `set_import_retarget_options`, `list_humanoid_import_options`
- `prepare_mixamo_character_import`, `prepare_rpm_character_import`
- `build_bone_map_from_skeleton`, `validate_bone_map_coverage`
- `get_skeleton_profile_humanoid_info`, `list_animation_clips_on_import`
- `retarget_report_for_character`

### Modifier stack + anim filters
- `list_skeleton_modifiers`, `set_skeleton_modifier_active`, `reorder_skeleton_modifiers`
- `apply_humanoid_modifier_preset` (look_at / hand_ik / hair_spring / full stack)
- `setup_upper_body_mask_tree`, `setup_aim_offset_blend_space`
- `create_foot_ik_helper_script`, bone filter presets

### Discovery
- Domains: `avatar`, `avatar_mesh`, `retarget_import`, `skeleton_rest`

---

## v1.66.0 — 2026-07-29

**Split oversized modules + surface expansion** — finish v1.65 refactor follow-ups and add high-gain agent tools.

### Refactor / split
- Merged `scene_flow_depth` into `scene_flow_commands` (game loop + pause + main menu)
- Split `node_commands` into:
  - `node_commands` (tree/select)
  - `node_property_commands` (inspector/resources)
  - `node_signal_meta_commands` (signals/meta/groups)
- Split `animation_commands` into:
  - `animation_commands` (clips/libraries)
  - `animation_track_commands` (tracks/keys/Bezier)
  - `animation_playback_commands` (play/stop/seek)
  - `animation_sprite_frames_commands`
- Fixed `PropertyParser` preloads on split node modules
- Normalized mojibake em-dashes/ellipsis across command modules
- De-duplicated overlapping registrations (`find_nodes_in_group`, `setup_timer`, `setup_camera_2d` dual sources)

### Surface expansion
- **process**: `set_process_mode`, `batch_set_process_mode`, priorities, `call_group_in_scene`
- **canvas layers**: stack recipe, order, follow viewport, custom viewport, list/reorder
- **cutscene**: player script, JSON sequence, setup node
- **expression apply**: `set_property_from_expression`, `batch_set_from_expressions`
- **resource UID**: resolve/list/stats for `uid://` sidecars
- Discovery domains: `process`, `canvas_layers`, `cutscene`

---

## v1.65.0 — 2026-07-29

**Continue refactor** — split oversized domains, merge thin siblings, rebalance for management.

### Domain rebalance (21 domains)
- Split former `core` into: `scene`, `editor`, `project`, `input`, `scripting`, `ai`
- Split rendering out of `assets` → `rendering/`
- Moved `mesh_2d`/`scene_2d`/`sprite_frames` → `2d`; CSG/terrain/multimesh → `3d`
- Target size: roughly 3–22 modules per domain (no 50+ dumping ground)

### Module merges (fewer files, same tools)
- `scene_unique_depth` → `scene_unique_commands`
- `project_settings_bulk` → `project_commands`
- `camera_level_bounds` → `camera_depth_commands`
- `migration_depth` → `migration_commands`

### Tooling
- `organize-command-modules.ps1` now rebalances recursively
- README documents domain map + merge policy

---

## v1.64.0 — 2026-07-29

**Structural refactor** — domain folders, recursive discovery, shared param utils, richer module index.

### Layout
- Command modules moved under `commands/<domain>/` (15 domains: agent, animation, 2d, 3d, core, …)
- `command_router` recursive auto-discover; tracks method → module source + domain
- `scripts/organize-command-modules.ps1` + updated `export-surface-registry.ps1`
- `commands/README.md` layout guide

### Shared helpers
- `utils/mcp_params.gd` — Vector2/3/Color/Rect parsers
- `base_command`: `parse_vec2/3`, `parse_color`, `list_tools_payload`, `save_resource_to_res`, `write_text_res`

### Discovery
- `list_command_domains`, `list_command_modules`
- `list_surface_registry` returns live domain/module inventory from router

---

## v1.63.0 — 2026-07-29

**Remaining production surface closure** — migration depth, iOS/platform matrix, theme I/O, ClassDB examples, runtime systems, plugin packaging, UI leftovers, honesty report.

### Migration
- Extended replacements, `scan_project_migration_report`, `scan_tscn_godot3_markers`, `get_migration_out_of_scope`

### Platform / iOS
- `get_ios_export_checklist`, `get_platform_export_matrix`, `ensure_ios_export_preset`, `create_ios_export_notes`

### Theme I/O + ClassDB examples
- Theme export/import/assign; `get_class_usage_examples`, `suggest_class_for_task`, `list_instantiateable_classes`

### Runtime systems
- Logger, achievements, day/night, feature flags, accessibility, WebSocket client

### Plugin packaging + UI
- Validate/package addon folders; CodeEdit, RichText BBCode demo, OptionButton items, ProgressBar

### Closure honesty
- **`list_out_of_scope_surfaces`**, **`get_production_surface_report`**
- Docs areas platform + migrating elevated to **strong** (with honest residual gaps)

---

## v1.62.0 — 2026-07-29

**All recommended remaining waves** — XR player rig depth, VisualShader node catalog + presets, export/CI templates.

### XR
- `setup_xr_player_rig` (origin + camera + controllers + movement/grab)
- `create_xr_movement_script`, `create_xr_grabber_script`, `create_xr_teleport_script`
- `setup_xr_pickup_area`, `list_xr_tools_catalog`
- **`pipeline_xr_setup`**

### VisualShader catalog
- `list_visual_shader_node_catalog` (friendly map + ClassDB VisualShaderNode* list)
- `visual_shader_add_nodes_batch` + connections
- Presets: toon, emission_pulse, scroll_uv, triplanar scaffold, outline_fresnel

### Export / CI
- `create_github_actions_godot_export`, `create_export_presets_pack`
- `create_headless_export_script` (.ps1 + .sh)
- `write_export_ci_readme`, `list_export_ci_templates`
- **`pipeline_export_ci`**

---

## v1.61.0 — 2026-07-29

**Recommended deep wave: multiplayer lobby + game loop shell + save state + inventory** — closes host→play and menu↔game↔save ship loops.

### Multiplayer lobby
- `create_multiplayer_lobby_script` (ready-up, roster, start_match)
- `create_player_spawn_service_script`, `setup_spawn_points`, `list_spawn_points`
- `create_network_clock_script` (RTT / server time estimate)
- **`pipeline_multiplayer_lobby`**

### Game loop / scene flow
- `create_game_flow_controller_script` (menu/game/pause/quit)
- `setup_main_menu_scene`, `create_pause_menu_controller_script`
- **`pipeline_game_loop_shell`**

### Save / load state
- `capture_node_state`, `capture_scene_state`, `apply_node_state`
- `create_game_state_serializer_script`, `write_save_slot_json`, `read_save_slot_json`, `list_save_slots_json`

### Inventory
- `create_item_resource_script`, `create_item_resource`, `create_inventory_component_script`

---

## v1.60.0 — 2026-07-29

**Biggest-gain production tools** — pack-as-scene, input map I/O, named collision layers, multiplayer sync bulk, resource make-unique, node queries, camera limits from tilemap, floating combat text.

### Scene pack (Scene dock)
- `pack_node_as_scene`, `pack_selection_as_scene`, `create_inherited_scene_from`
- `replace_node_with_scene_instance`

### InputMap I/O
- `export_input_map_json`, `import_input_map_json`, `list_input_map_actions_detail`, `clear_input_action_events`

### Named collision layers
- `set_collision_layers_by_name`, `set_collision_mask_by_name`, `get_collision_layers_named`, `resolve_layer_names_to_mask`

### Multiplayer sync depth
- `configure_multiplayer_synchronizer`, `add_replication_properties_bulk`, `list_replication_config`, `set_rpc_config_on_node`

### Resources / tree navigation
- `make_resource_unique`, `set_resource_local_to_scene`
- `find_nodes_by_class`, `find_nodes_by_script`, `find_nodes_by_name_pattern`, `count_nodes_by_class`, `reorder_node`

### Camera + combat juice
- `set_camera_2d_limits_from_tilemap`, `set_camera_2d_limits_rect`, `set_camera_2d_limits_from_node_bounds`
- Floating damage text + hit flash scripts + spawner

---

## v1.59.0 — 2026-07-29

**Full production push** — CharacterBody motion, Environment/Sky/Fog, SpringArm TPS, audio bus effects, ENet multiplayer peers, project settings bulk, AnimationPlayer depth, PhysicsMaterial, occlusion culling, TPS/multiplayer pipelines.

### Character motion
- `set_character_body_motion`, `get_character_body_info`, `apply_character_body_preset` (platformer_2d|topdown_2d|fps_3d|third_person_3d)

### Environment / sky / fog
- `create_environment_resource`, `create_procedural_sky`, `create_panorama_sky`
- `assign_environment_to_world`, `setup_fog_volume`, `set_environment_fog_params`

### Camera TPS
- `setup_spring_arm_3d`, `setup_third_person_camera_rig`, `set_spring_arm_params`

### Audio effects
- `list_audio_bus_effect_types`, `add_audio_bus_effect_typed`, `set_audio_bus_effect_params`, `list_audio_bus_effects`

### Multiplayer peers
- `create_enet_multiplayer_script`, `create_multiplayer_bootstrap_script`, `setup_multiplayer_spawner_basic`

### Project / animation / physics / occlusion
- Bulk project settings list/set/snapshot
- AnimationPlayer autoplay/speed/libraries/status/stop
- `create_physics_material` / `assign_physics_material`
- OccluderInstance3D + project occlusion toggle

### Pipelines
- `pipeline_3d_character_tps`, `pipeline_multiplayer_enet`

---

## v1.58.0 — 2026-07-29

**Coverage scorecard + pathfinding/materials/fonts/engine info/resource format + pre-ship pipeline.**

### Pathfinding
- `create_astar_grid_2d_script`, `create_astar_point_graph_script`, `setup_astar_grid_controller`

### Materials 3D
- `create_standard_material_3d`, `create_orm_material_3d`, `set_standard_material_params`, `assign_material_3d_to_mesh`

### Fonts / LabelSettings
- `create_font_file_resource`, `create_label_settings`, `assign_label_settings`, `set_label_font_size`

### Engine / OS diagnostics
- `get_engine_info`, `get_os_info`, `get_time_info`, `get_project_feature_tags`, `get_agent_environment_report`

### Resource format
- `save_resource_as`, `convert_resource_format`, `duplicate_resource_to`, `get_resource_info`

### Pipelines / docs
- `pipeline_pre_ship_check`
- **docs/COVERAGE_SCORECARD.md** — honest % estimates per surface
- Discovery domains: `pathfinding`, `materials`

---

## v1.57.0 — 2026-07-29

**Structural expansion** — shape resources, canvas `_draw` recipes, SubViewport render targets, scene-instance depth, TileMapLayer stacks, audio polyphony, 2D pipelines, FABRIK 2D IK.

### Shapes
- `create_shape_resource`, `batch_create_shape_resources`, `list_shape_resource_types`
- `assign_shape_to_collision`, `setup_collision_from_shape_resource`

### Canvas draw recipes
- `list_canvas_draw_recipes`, `create_canvas_draw_script`, `setup_canvas_draw_node`
- Recipes: grid, crosshair, circle_ring, rect_border, polyline, health_bar, debug_bounds, radial_sector, dashed_line

### SubViewport / screen
- `setup_subviewport_container`, `setup_subviewport_2d_world`
- `setup_viewport_texture_rect`, `setup_sprite_from_subviewport`
- `setup_back_buffer_copy`, `set_subviewport_update_mode`

### Scene instances
- `instance_packed_scene`, `set_editable_instance`, `get_instance_info`
- `setup_instance_placeholder`, `make_scene_instance_local`, `batch_set_owners`

### TileMapLayer stacks
- `setup_tilemap_layer`, `setup_tilemap_layer_stack`, `list_tilemap_layers`
- `assign_tileset_to_layers`, `set_tilemap_layer_props`

### Audio polyphony
- `setup_polyphonic_player`, `set_audio_player_polyphony`, `create_sfx_pool_script`

### Pipelines + 2D IK
- `pipeline_2d_pixel_game`, `pipeline_2d_tilemap_level`
- `setup_fabrik_ik_2d` (when ClassDB has SkeletonModification2DFABRIK)

---

## v1.56.0 — 2026-07-29

**2D masterpiece stretch** — Skeleton2D/Bone2D/rest/2D IK, MeshInstance2D, pixel-game presets, TileSet scenes-as-tiles + patterns. Aimed at full agent 2D production surface (docs tutorials/2d + 2d_skeletons).

### Skeleton2D
- `find_skeletons_2d`, `setup_skeleton_2d`, `add_bone_2d`, `list_bones_2d`, `get_bone_2d_info`
- Rest/pose: `set_bone_2d_rest`, `apply_bone_2d_rest`, `apply_all_bone_2d_rests`, `set_bone_2d_pose`, `set_bone_2d_length`
- IK: `setup_modification_stack_2d`, `setup_two_bone_ik_2d`, `set_two_bone_ik_2d_target`, `list_modification_stack_2d`
- `set_bone_2d_local_pose_override`

### Mesh 2D
- `setup_mesh_instance_2d`, `create_quad_mesh_2d`, `create_array_mesh_2d`, `assign_mesh_2d`
- `set_mesh_instance_2d_texture`, `convert_sprite_to_mesh_instance_2d`, `setup_multimesh_instance_2d`

### Pixel presets
- `list_pixel_2d_presets`, `apply_pixel_2d_project_preset` (classic_pixel / pixel_canvas_items / hd_pixel / smooth_2d)
- Stretch mode/aspect/integer scale, nearest filter, 2D snap, AA off
- `get_pixel_2d_project_settings`, `apply_pixel_texture_import_batch`, `set_canvas_item_texture_filter`

### TileSet scenes + patterns
- `tileset_add_scenes_collection_source`, `tileset_add_scene_tile`, `tileset_list_scene_tiles`
- `tileset_remove_scene_tile`, `tileset_set_scene_tile_placeholder`
- Patterns: `tileset_add_pattern_from_cells`, `tileset_add_pattern_from_rect`, `tileset_list_patterns`, `tileset_remove_pattern`
- Stamp: `tilemap_stamp_pattern`

### Discovery
- New domain **`2d`** in `list_agent_domains` / `list_tools_by_domain`
- Expanded `agent_workflow_guide topic=2d`

---

## v1.55.0 — 2026-07-29

**Stretch tool surface** — groups/layers, autoloads, unique names, preload registry, tile physics/nav, compositor, clipboard, input replay, spring bones.

### Project structure
- `list_project_groups`, `batch_set_node_groups`, `find_nodes_in_group`
- Physics/render layer name get/set
- Autoload list/set/remove/rename
- Scene unique names batch + find/list

### Assets / tiles / render
- Resource preload manifest + registry script + validate
- TileSet physics/navigation layers + tile nav polygon
- Compositor setup/list/clear on WorldEnvironment

### Agent ergonomics
- Clipboard get/set, duplicate_nodes, copy path
- Input replay manifest write/run via playtest_sequence
- SpringBoneSimulator3D scaffold (version-dependent)

---

## v1.54.0 — 2026-07-29

**100% agent production surfacing roadmap** — discovery plane, playtest fix loops, retarget pipeline, theme/dialogue depth, debugger intel, perf budgets, VisualShader presets, tile custom data.

### Wave 1 — Discovery
- `list_agent_domains`, `list_tools_by_domain`, `search_mcp_tools`
- `get_tool_examples`, `get_agent_capability_map`

### Wave 2 — Playtest fix loop
- `playtest_fix_loop`, `diagnose_playtest_failure`, `assert_scene_playable`

### Wave 3 — Character / import pipeline
- `pipeline_character_from_gltf`, `pipeline_retarget_animations`
- Import schemas: fbx, ogg_vorbis expansions

### Wave 4 — Theme + dialogue graphs
- Theme fonts/icons/seed types/list items/copy type
- Dialogue graph load/add/set/remove/choice/validate

### Wave 5 — Debugger + performance
- `analyze_debugger_errors`, `get_fix_plan_from_errors`, `open_error_source`
- `analyze_performance_budget` + threshold settings

### Wave 6 — VisualShader + tiles
- VisualShader presets: PBR, unshaded color, dissolve scaffold
- TileSet custom data layers + per-tile values

---

## v1.53.0 — 2026-07-28

**Agent surface expansion** — cameras, 2D lights/occluders, async resources, StyleBox, utility AI/GOAP, Expression eval, Decals.

### Camera
- `setup_camera_2d` / `setup_camera_3d_node`, limits, FOV/cull, `camera_make_current`

### 2D lighting
- CanvasModulate, LightOccluder2D, PointLight2D setup/params

### Resources / theme / AI / math / decals
- Threaded ResourceLoader request/status/get + async loader script
- StyleBoxFlat create/theme assign/panel override
- Utility AI, tiny GOAP planner, AI blackboard
- `evaluate_expression` / on-node Expression
- Decal3D setup + params

---

## v1.52.0 — 2026-07-28

**Agent surface expansion** — shader includes, UI containers depth, multiplayer interest, Timer/Tween recipes, SkeletonIK, Label/RichText.

### Shader includes
- `create_shader_include`, `list_shader_includes`, `shader_add_include`
- `create_shader_include_library_preset` (common/math/noise/tonemap)

### UI containers
- TabContainer, H/VSplit, Flow, Center, AspectRatio, SubViewportContainer
- `tab_container_add_page`

### Multiplayer interest
- `create_interest_manager_script`, visibility filter helper
- synchronizer interval / spawner limits

### Timer / Tween / IK / Labels
- `setup_timer`, delay helper, tween recipe script
- `setup_skeleton_ik`, LookAtModifier fallback
- `setup_label`, `setup_richtext_label`, append BBCode, autowrap

---

## v1.51.0 — 2026-07-28

**Agent surface expansion** — ragdoll auto-gen, XR passthrough, TileSet atlas polish, SoftBody/vehicle/SpriteFrames depth.

### Ragdoll
- `generate_ragdoll_from_skeleton`, `list_physical_bones`, `set_physical_bone_params`
- `create_ragdoll_control_script`

### XR passthrough
- `set_xr_passthrough_settings`, `get_xr_passthrough_info`
- `setup_xr_composition_layer_quad`, `create_xr_passthrough_controller_script`

### TileSet atlas
- `tileset_get_atlas_info`, `tileset_set_atlas_region_size`
- `tileset_create_tiles_in_region`, `tileset_remove_tiles_in_region`, `tileset_set_tile_texture_origin`

### SoftBody / vehicle / SpriteFrames
- `set_soft_body_params`, `soft_body_pin_point`, `soft_body_get_info`
- `setup_vehicle_body`, `set_vehicle_wheel_params`, `list_vehicle_wheels`
- `sprite_frames_get_info`, speed/loop/remove/clear/rename

---

## v1.50.0 — 2026-07-28

**Agent surface expansion** — i18n CSV/open-scene, TileSet terrain depth, import schemas, PathFollow, audio generator, display/window, joint limits.

### i18n
- `extract_strings_from_open_scene`, `export_translation_csv`, `import_translation_csv`
- `wrap_script_strings_with_tr` (dry_run by default)

### TileSet / TileMap terrain
- `tileset_set_terrain_peering`, `tileset_set_tiles_terrain_batch`, `tileset_list_terrain_peering`
- `tilemap_fill_terrain_rect`, `tilemap_paint_terrain_cells`

### Import schemas
- `list_import_types`, `list_import_option_schema`, `get_import_options_for_path`
- `apply_import_schema_preset` (texture/scene_3d/audio presets)

### PathFollow / audio / display / joints
- `setup_path_follow`, `path_follow_set_progress`, `path_follow_get_info`
- `setup_audio_stream_generator`, `create_tone_generator_script`, `create_audio_bus_layout_preset`
- `get_display_info`, `set_window_project_settings`, `set_window_mode_live`, `list_screens`
- `set_hinge_joint_limits`, `set_slider_joint_limits`, `set_generic_6dof_joint_limits`, `set_pin_joint_params`, `get_joint_info`

---

## v1.49.0 — 2026-07-28

**SDK structure expansion** — particles depth, interaction zones, export signing, HTTP/encrypted IO, physics debug, 3D structure nodes, best-practices checks. Docs audit: `docs/SDK_STRUCTURE_EXPANSION.md`.

### Particles depth
- `set_particle_process_params`, `set_particle_emission_shape`, `set_particle_turbulence`
- `set_particle_draw_pass`, `add_gpu_particles_attractor`, `create_cpu_particles`, `restart_particles`

### Interaction zones
- `setup_interaction_zone`, `setup_interaction_prompt_ui`
- `create_interaction_controller_script`, `bind_interaction_action`

### Export signing
- `get_export_signing_checklist`, `configure_android_keystore`
- `get_android_signing_status`, `set_export_preset_signing_options`

### HTTP + encrypted IO
- `create_http_client_script`, `setup_http_request_node`
- `create_encrypted_save_script`, `encrypted_file_write` / `encrypted_file_read`

### Physics debug + structure
- `set_collision_debug_visible`, `editor_raycast`, `list_physics_shapes_in_scene`
- Runtime `physics_raycast`
- `setup_visible_on_screen_notifier/enabler`, `setup_remote_transform`
- `setup_world_boundary_body`, `setup_occluder_instance`, `setup_marker_3d`

### Best practices
- `analyze_project_best_practices`, `check_node_naming`, `check_autoload_hygiene`, `check_res_path_conventions`

---

## v1.48.0 — 2026-07-28

**Quality presets + agent pipelines + live nav path** — composed human workflows and fork docs.

### Quality presets
- `list_quality_presets`, `apply_lod_distance_preset` (mobile/desktop/cinematic/city)
- `apply_lightmap_quality_preset` (draft/medium/high/ultra/mobile)
- `configure_lightmap_gi`, `apply_platform_render_pack`

### Agent pipelines (multi-tool recipes)
- `pipeline_prepare_level_lighting`, `pipeline_setup_prop_lods`
- `pipeline_nav_debug_route`, `pipeline_character_locomotion`
- `pipeline_greybox_to_playable`, `list_agent_pipelines`

### Nav live path
- `navigation_live_path` — optional auto-play, query, draw debug path, stop

### Docs
- `FORK.md` — GitHub fork notification etiquette (pushes to origin do not spam upstream)

---

## v1.47.0 — 2026-07-28

**Suggested parity wave** — LOD, UV2 lightmap unwrap, movie capture, nav path debug, AnimationTree graph recipes.

### LOD
- `mesh_generate_lods`, `mesh_get_lod_info`, `set_visibility_range`
- `setup_lod_mesh_instances`, `create_shadow_mesh`, `list_lod_tools`

### UV2 / lightmap bake prep
- `mesh_lightmap_unwrap`, `mesh_has_uv2`, `batch_prepare_lightmap_meshes`
- `lightmap_bake_prepare` (batch + LightmapGI + optional bake)
- Runtime-ready path to `request_lightmap_bake`

### Movie Maker / capture
- `set_movie_maker_enabled`, `get_movie_maker_settings`, `set_movie_maker_output`
- `play_with_movie_maker`, `capture_play_session` (frames → optional FFmpeg video)

### Navigation debug
- `navigation_set_debug_enabled`, `navigation_get_debug_settings`
- `navigation_query_path` (editor + runtime TCP), `draw_debug_path`, `navigation_get_map_info`
- Runtime: `get_screenshot`, `navigation_query_path` on game inspector

### AnimationTree graph depth
- `set_state_machine_node_position`, `set_state_animation`, `list_state_machine_transitions`
- `get_blend_tree_connections`, `disconnect_blend_tree_nodes`
- `create_simple_locomotion_tree`, `create_blend_space_1d_locomotion`
- `export_animation_tree_graph` (+ mermaid)

---

## v1.46.0 — 2026-07-28

**Human workflow parity** — mesh collision menu, interactive playtest loops, resource graph remaps, viewport focus, CSG bake, scene audits.

### Mesh → collision (MeshInstance menu parity)
- `mesh_create_trimesh_static_body`, `mesh_create_convex_static_body`
- `mesh_create_trimesh_collision`, `mesh_create_convex_collision`, `mesh_create_multiple_convex_collisions`
- `add_collision_shape_from_mesh`, `list_mesh_collision_tools`

### Closed-loop playtest
- `playtest_sequence` — ordered steps: wait, action, key, mouse, assert, screenshot, get_tree
- `list_playtest_loop_tools`

### Resource dependency graph
- `list_resource_dependencies`, `find_files_referencing`, `remap_resource_references`
- `list_orphaned_resources`, `validate_scene_dependencies`, `list_resource_graph_tools`

### Editor viewport focus
- `editor_focus_node`, `editor_frame_selection` (F-key parity)
- `editor_get_3d_camera`, `editor_set_3d_camera_transform`

### CSG composition
- `csg_set_operation`, `csg_set_use_collision`, `csg_get_info`
- `csg_bake_to_mesh_instance`, `csg_list_shapes`, `list_csg_tools`

### Scene audit
- `list_scene_signals`, `list_missing_scripts`, `validate_all_scenes`, `audit_scene_tree`

### Docs / discovery
- Agent topics: `playtest`, `collision`, `resources`, `audit`
- IDE_PARITY updated for new planes

---

## v1.45.0 — 2026-07-28

**IDE parity expansion** — streaming chunks, heightmap terrain, interactive music, editor workspace play/browse.

### Scene streaming
- `create_stream_manager_script`, `stream_load_chunk`, `stream_unload_chunk`, `stream_list_chunks`, `stream_set_chunk_active`

### Terrain (native heightfield)
- `create_heightmap_terrain`, `create_plane_mesh_terrain`, `terrain_apply_height_noise`, `list_terrain_tools`

### Interactive music
- `create_music_controller_script`, `setup_music_player`, `music_set_playlist`, `list_music_tools`

### Editor workspace
- `play_main_scene`, `play_current_scene`, `play_custom_scene`
- `get_editor_workspace_info`, `list_open_scenes`, `save_all_scenes`, `close_scene`
- `list_resources_by_type`, `duplicate_scene_file`, `set_editor_3d_snap`

### Docs
- `docs/IDE_PARITY.md`; agent topics audio/editor/level streaming

---

## v1.44.0 — 2026-07-28

**Humanoid + level design verticals** — agent recipes for characters, interaction, greybox levels, GridMap paint, MultiMesh, animation libraries.

### Humanoid (`humanoid_commands`)
- `setup_humanoid_actor`, `validate_humanoid_rig`, `create_bone_map_preset` (mixamo/rpm/humanoid)
- `apply_locomotion_set`, `bind_interaction`, `list_humanoid_recipes`

### Level design (`level_design_commands`)
- `greybox_room`, `greybox_corridor`, `place_prop_scatter`, `stamp_scene_instances`
- `validate_level_playable`, `level_playtest_route`, `list_level_design_tools`

### GridMap + MultiMesh
- `gridmap_set_cell`, `fill_rect`, `paint_line`, `get_cell`, `clear`, `get_used_cells`, `set_mesh_library`, `get_info`
- `setup_multimesh_instance`, `multimesh_set_transforms`, `multimesh_scatter`, `multimesh_get_info`

### Animation libraries
- create/list/rename/remove/merge/assign/import library packs

### Multi-select transforms
- `set_nodes_transform`, `batch_update_property`

### Docs
- `docs/HUMANOID_AND_LEVELS.md`; agent_workflow topics `humanoid` / `level`

---

## v1.43.0 — 2026-07-28

**Curves & Bezier as full numerical SDK surface** — agents map control points on the Cartesian plane (time×value / 2D / 3D), not limited by GUI drag metaphors.

### New module `curve_commands`
- Curve: `create_curve_resource`, `curve_set/get_points`, `curve_sample`, `curve_sample_baked`
- Curve2D/3D: create, set/get points (in/out + world endpoints), sample polylines
- Path2D/3D: `path_get_curve_points`, `path_set_curve_points`
- Animation Bezier: `bezier_list_keys_cartesian`, `bezier_set_keys_batch`, `bezier_sample_dense`, `bezier_remove_key`, `bezier_set_handle_mode`
- `list_curve_sdk_tools`

### Coverage / docs
- `tutorials/math` → **strong** in `list_docs_coverage`
- `docs/CURVES_AND_BEZIER.md`; animation docs reframed for agent plane fine-tune

---

## v1.42.0 — 2026-07-28

**Animation example → fine-tune pipeline** — agents can copy example clips and retarget/tune them like the Animation dock.

### New module `animation_transfer_commands`
- `dump_animation`, `list_animation_tracks`, `get_track_keys`, `sample_animation_at_time`
- `compare_animations`, `copy_animation_to_player`, `copy_animation_track`
- `remap_animation_track_paths`, `set_animation_track_path`
- `scale_animation_time`, `offset_animation_keys`, `crop_animation`, `clear_animation_track_keys`
- `save_animation_resource`, `load_animation_resource`
- `extract_animations_from_scene`, **`apply_example_animation`** (one-shot)
- `list_animation_fine_tune_tools`

### Other
- `get_animation_info` serializes key values properly; optional key caps
- Lite schemas + `agent_workflow_guide topic=animation`
- Doc: `docs/ANIMATION_FINE_TUNE.md`

---

## v1.41.0 — 2026-07-28

**Headless IDE parity + remaining tool surfaces** — agents can operate like a human in the editor with fewer round-trips and offline fallbacks.

### Agent readiness (no friction)
- `agent_ensure_ready` — launch editor + wait, `ensure_runtime_autoloads`, open main scene
- `batch_editor_calls` / `batch_call_editor` — multi-command dock workflows in one request
- `agent_headless_status` — what works with/without plugin
- Server: `write_project_file`, `headless_set_project_setting` via `godot_operations.gd`
- Headless ops: `write_file`, `set_project_setting`, `get_project_info`, `create_script`

### Project Settings surface
- `get_project_setting`, `set_project_settings` (bulk), `clear_project_setting`, `has_project_setting`
- `search_project_settings`, `get_project_feature_list`, `set_project_feature`

### TileSet atlas depth
- `tileset_create_tile`, `tileset_remove_tile`, `tileset_list_atlas_tiles`, `tileset_get_tile_data`
- `tileset_set_tile_z_index`, `tileset_set_tile_probability`, `tileset_set_atlas_margins`
- `tileset_create_alternative_tile`

### C# / export / editor docks
- `create_csharp_node_script`, `check_dotnet_sdk`, `list_csharp_partial_classes`
- `verify_export_ready`, `get_export_template_guide`, `get_export_templates_path`
- `open_path_in_filesystem`, `edit_resource_path`, `open_script_in_editor`, `get_open_scripts_info`
- `set_main_screen`, `distraction_free_mode`

### Docs
- Headless principle reinforced in health_check / agent_headless_status

---

## v1.40.0 — 2026-07-28

**Surface expansion** — close remaining docs-area gaps so agents can operate more of the Godot SDK tutorial surface.

### Rendering / GI
- `configure_sdfgi`, `configure_ssao`, `configure_ssr`, `configure_glow`, `configure_ssil`
- `set_mesh_lightmap_params` (+ optional UV2 unwrap request)
- `list_gi_tools` (module `render_gi_commands`)

### Input / joypad
- `create_joypad_input_map_preset` (platformer, twin_stick, racing, xbox_ui)
- `add_joypad_binding`, `list_joypads`, `list_joypad_button_names`
- `set_action_deadzone`, `get_action_strength_info`

### I18n
- `extract_translatable_strings` (scan `tr()`, `text=`, etc.)
- `export_pot_template`

### Theme resource editor
- `theme_set_type_color/constant/font_size/stylebox`, `theme_list_types`, `theme_get_type_info`, `theme_clear_type`, `assign_theme_to_control`

### Saves / IO
- `create_encrypted_save_manager_script` (`FileAccess.open_encrypted_with_pass`)

### Animation / retarget
- `set_bezier_key`, `get_bezier_key_info`, `apply_bone_map_to_skeleton`

### GDExtension
- `clone_godot_cpp`, `setup_gdextension_full` (scaffold + clone + optional scons)

### Migration (3→4 aids)
- `scan_godot3_patterns`, `list_migration_replacements`, `apply_migration_replacements`, `get_migration_guide`

### Performance / WebRTC
- `export_performance_report`, `get_gpu_profiling_hints`
- `create_webrtc_ice_config_script` (STUN/TURN project settings)

### Coverage map
- `list_docs_coverage` statuses updated (rendering/io/i18n/inputs/plugins/webrtc/migrating)

---

## v1.39.0 — 2026-07-28

**Inspector fine-tune** — agents can discover and set every editor-visible node/resource parameter.

### Node / property control
- `get_property` — single field + full metadata (type, enum, range, can_revert)
- `search_properties` — find fields by name (recurses resources)
- `reset_property` — inspector Revert when available
- `list_node_methods` / `call_node_method` — structured method access
- `list_property_info` — `recurse_resources`, `property_path`, `filter`, headers, usage flags
- `inspect_node` — `deep` nested catalog, optional methods sample
- `update_property` — enum-by-name, declared types when value is null, richer parse
- `add_resource` — nested property paths + `resource_properties` on create

### Types (`utils/property_parser.gd`)
- Vector4, Transform2D/3D, Quaternion, Basis, AABB, Plane, packed arrays
- Enum options as `{name,value}`; range min/max/step
- Stronger serialize for nested resources

### Runtime
- Nested property paths on `set_node_property` / filtered `get_node_properties`
- Optional `with_info` on game property dump

### Docs / discovery
- `docs/INSPECTOR_FINE_TUNE.md`, skill + agent_workflow `topic=inspector` updated
- Lite schemas for new fine-tune tools + `describe_class`

---

## v1.38.0 — 2026-07-28

**Refactor** — extract runtime capture; command modules use shared script writers only.

### Plugin
- `utils/runtime_capture.gd` — video record, property timeline, event/log ring extracted from `mcp_game_inspector_service.gd`
- Inspector delegates `start/stop_video_record`, `capture_timeline`, `log_run_event`, `get_run_events`/`logs`, status extras
- Abort of non-concurrent commands finalizes video (`meta.json`) via `abort_to_idle`
- Command modules call `write_script_file` directly (thin `_write_script` wrappers removed)
- `plugin_scaffold` uses local `_write_raw` for always-overwrite template files

### Docs
- ARCHITECTURE lists `runtime_capture.gd`

---

## v1.37.0 — 2026-07-28

**Refactor continued** — auto-discover commands, split tool schemas, shared autoload API.

### Plugin
- `command_router.gd` **auto-discovers** `commands/*_commands.gd` (no manual preload list)
- `base_command.ensure_autoload` / `maybe_add_autoload` — shared singleton registration
- Call sites use shared helpers (settings, quest, multiplayer, game_ui, vfx, run_session)

### Server
- Split `tools.ts` → `tool-types.ts` + `tools-cli.ts` + `tools-lite.ts` (+ hub re-exports)
- `scripts/split-tools.mjs` for future regeneration

### Docs
- ARCHITECTURE notes auto-discovery

---

## v1.36.0 — 2026-07-28

**Refactor** — structure after the 1.29–1.35 feature sprint (behavior unchanged).

### GDScript
- `utils/runtime_tcp_server.gd` — TCP listen/queue/auth extracted from `mcp_game_inspector_service.gd`
- `utils/runtime_tcp_client.gd` — editor TCP client used by `base_command.send_game_command`
- `utils/script_io.gd` + `base_command.write_script_file` / `write_json_file`
- Command modules delegate `_write_script` / `_write_json` to shared helpers
- Inspector ~200 lines thinner; base_command TCP client simplified

### Server
- `tool-groups.ts` — category map for LITE/CLI tool surface
- Re-export from `tools.ts`

---

## v1.35.0 — 2026-07-28

**Runtime TCP hardening + Playwright video path fix.**

### Multi-client queue
- Serialize TCP command dispatch with a request queue (max 48)
- Cap concurrent sockets (max 8); reject with `max_clients` / `queue_full`
- Drain queue after each response; clients get `queue_depth` on replies
- Editor/server retry on `queue_full`

### Optional runtime auth
- `MCP_RUNTIME_TOKEN` env or project setting `mcp/runtime_token`
- Requests pass `token` field; unauthorized → `auth_required`
- `set_runtime_token` / `get_runtime_info` / `ping` reports `auth_required`
- Still bind **127.0.0.1 only**; meta in `user://mcp_runtime_meta.json`

### Playwright web probe
- Correct `page.video().path()` after `page.close()` then `context.close()`
- Fallback: newest `.webm`/`.mp4` in record dir
- Separate `page_errors` vs console errors

---

## v1.34.0 — 2026-07-28

**Runtime TCP transport + standalone attach + optional Playwright web probe.**

### Game runtime TCP (preferred over file IPC)
- `MCPGameInspector` listens on `127.0.0.1:6510-6514` (writes `user://mcp_runtime_port`)
- JSON-lines protocol: `{"id", "command", "params"}` → `{"id", "ok", "data"|"error"}`
- Editor `send_game_command` tries TCP first, falls back to file IPC
- `ping_runtime` game command; `run_ping_runtime` / server `runtime_ping`

### Standalone / permanent autoloads
- `ensure_runtime_autoloads` — keep inspector autoloads in project for CLI/export runs
- Open MCP server `runtime_call` — direct TCP when editor offline
- Offline fallback maps `get_game_*` / `run_*` probe tools to TCP

### Web export (optional Playwright)
- `web_serve_export` / `web_serve_stop` — static server for HTML5 build
- `web_playwright_probe` — screenshot/console (requires optional `playwright` package)

### Philosophy
- Native desktop: TCP runtime + structure/video (1.33)
- Web product only: Playwright adapter (do not use for desktop Play)

---

## v1.33.0 — 2026-07-28

**Native run probe plane** — session lifecycle, in-engine video + event log, FFmpeg media tools, GUT/GdUnit adapters (no reinvention).

### Game inspector (`mcp_game_inspector_service`)
- `start_video_record` / `stop_video_record` — PNG sequence + `events.jsonl` + `meta.json` under `user://mcp_recordings/`
- `log_run_event`, `get_run_events`, `get_run_logs`, `get_run_status`
- `capture_timeline` — property time series (+ optional frames)
- `find_nodes` — by group|type|name|path|script
- Concurrent probes during video (status/tree/assert without aborting record)

### Run session (`run_session_commands`)
- `run_session_start` / `stop` / `status`
- `run_record_start` / `stop` (optional FFmpeg encode)
- `run_log_event`, `run_get_events`, `run_get_logs`
- `run_capture_timeline`, `run_find_nodes`
- `run_probe_report` — one-shot play → status/tree/asserts/screenshot/record

### Media (FFmpeg — system dependency)
- `media_find_ffmpeg`, `media_frames_to_video`, `media_extract_keyframes`
- `media_clip_video`, `media_contact_sheet`, `media_probe`

### Test framework adapters
- `detect_test_frameworks`, `run_gut_tests`, `run_gdunit_tests`, `list_test_recipes`

### Philosophy
- Structure first (tree/properties/assert); video for motion/juice
- Wrap GUT/GdUnit/FFmpeg — do not reimplement them

---

## v1.32.0 — 2026-07-28

**Full remaining slice pack:** WebRTC/matchmaking/netcode, dialogue graph viz, FBX import depth, behavior trees, export polish, VFX/shaders, settings/save menus.

### WebRTC / netcode (`webrtc_multiplayer_commands`)
- `create_webrtc_multiplayer_template`, `create_signaling_server_script`, `create_matchmaking_client_script`
- `create_input_buffer_netcode_script` (delay-based, not full GGPO)
- `create_lag_compensation_helper_script`, `list_webrtc_recipes`

### Dialogue graph tooling (`quest_system_commands` expand)
- `export_dialogue_graph_mermaid`, `export_dialogue_graph_dot`
- `add_dialogue_graph_node`, `list_dialogue_graph_nodes`

### FBX / scene import (`import_3d_commands` expand)
- `list_scene_import_options`, `set_fbx_import_flags`, `apply_scene_import_advanced`

### Behavior trees (`behavior_tree_commands`)
- Runtime + blackboard + JSON trees + runner + `setup_behavior_tree_on_node`

### Export polish (`export_commands` expand)
- `set_export_filters`, `export_and_verify`, `list_export_templates`, `duplicate_export_preset`

### VFX / shaders (`vfx_shader_commands`)
- Shader presets (flash, outline, dissolve, hologram, fresnel, toon…)
- `apply_canvas_shader_to_node`, `apply_spatial_shader_to_mesh`
- Trail VFX, hurt flash, screen fade, hit-stop

### Settings / save (`settings_save_commands`)
- SettingsManager + settings menu UI
- Enhanced multi-slot SaveManager + save slot menu

---

## v1.31.0 — 2026-07-28

**3D import depth + quest graphs + multiplayer host/join runtime.**

### 3D import (`import_3d_commands`)
- `list_imported_scene_contents` — inventory meshes/skeletons/anims in .glb/.tscn
- `extract_meshes_from_scene` / `extract_materials_from_scene`
- `instance_scene_as_inherited` — New Inherited Scene workflow
- `create_scene_from_gltf` — inherited or editable pack
- `pack_mesh_library_from_scene` — GridMap MeshLibrary
- `set_gltf_import_flags` — animations/lods/tangents/root_type + reimport
- `list_3d_import_tools`

### Quest / dialogue graphs (`quest_system_commands`)
- `create_quest_resource`, `create_quest_log_script` (autoload)
- `create_dialogue_graph_resource`, `validate_dialogue_graph`, `merge_dialogue_lines`
- `create_quest_giver_script`, `create_objective_tracker_script`
- `list_quest_recipes`

### Multiplayer runtime (`multiplayer_runtime_commands`)
- `create_multiplayer_game_manager_script` — ENet host/join + roster + start_game RPC
- `create_multiplayer_lobby_ui` — name/address/port/host/join/start + player list
- `create_websocket_multiplayer_template`
- `setup_multiplayer_player_scene` — networked pawn + MultiplayerSynchronizer
- `setup_multiplayer_spawn_stack` — spawner + spawn points + host spawn script
- `list_multiplayer_recipes`

---

## v1.30.0 — 2026-07-28

**Modern game systems** — composed tools agents need for sophisticated 2D/3D games (not only raw node CRUD).

### Character & combat (`character_system_commands`)
- `setup_character_2d` / `setup_character_3d` — body + collision + controller script (+ camera/mesh)
- Controllers: `create_platformer_controller_script`, `create_topdown_controller_script`, `create_fps_controller_script`
- Combat: `create_health_component_script`, `setup_hitbox`, `setup_hurtbox`, `create_projectile_script`
- `list_character_templates`

### AI (`ai_system_commands`)
- `setup_ai_agent_2d` / `setup_ai_agent_3d` — nav agent + chase|patrol + detection
- `create_chase_ai_script`, `create_patrol_ai_script`, `create_gameplay_state_machine_script`
- `setup_detection_area`, `create_interactable_script`, `list_ai_templates`

### Game UI & systems (`game_ui_system_commands`)
- `setup_hud`, `setup_pause_menu`, `setup_inventory_ui`, `setup_dialogue_box_ui`
- `create_game_state_script`, `create_audio_manager_script`, `set_scene_tree_paused`
- `list_game_ui_templates`

### Modern render / camera (`modern_render_commands`)
- `apply_environment_preset` — cinematic|outdoor_day|night|indoor|stylized|horror|clean
- `setup_camera_follow_2d`, `setup_third_person_camera`, `setup_orbit_camera_3d`
- `create_minimap_viewport`, `list_render_presets`

### TileMap paint depth
- `tilemap_erase_rect`, `tilemap_paint_line`, `tilemap_paint_cells`

### Server
- LITE schemas for all high-level modern-game tools (always discoverable)

---

## v1.29.0 — 2026-07-28

**Headless production macros** — MCP surfaces high-frequency human IDE actions so agents can build end-to-end without a person in the docks.

### Added (production_commands)
- `scaffold_project_defaults` — folders, viewport/stretch, physics layers, input preset, main scene shell
- `create_input_map_preset` — platformer_2d / fps_basic / ui_menu (+ live InputMap sync)
- `wire_signal_to_new_method` — Signal dock: create method + persistent connect (infers signal args)
- `playtest_report` — play → settle → debugger errors / tree / asserts / screenshot → stop
- `agent_production_status` — single dashboard + recommended loop

### Added (import_commands)
- `ensure_imported` — scan/wait until paths are ResourceLoader-ready
- `stage_files_into_res` — batch copy OS files into res:// (+ optional import wait)
- `import_paths` — one-shot stage-or-ensure alias for agents

### Server / discovery
- LITE schemas for all production + import macros (always listed)
- `agent_workflow_guide` loop updated (scaffold → import → build → wire → playtest)
- docs coverage: assets_pipeline / inputs / getting_started upgraded with macros

### Philosophy
- Prefer editor+plugin automation (not raw CLI-only) for human-parity import and playtest.
- Agents should treat MCP as the full IDE control plane for content work.

---

## v1.28.0 — 2026-07-28

**Surface expansion** — Control polish widgets, audio 2D/3D players + polyphony, layer names.

### Added
- `control_extra_commands`: tooltip, cursor, clip, min size, ColorRect, NinePatch, separators, CheckBox/Button, SpinBox, HSlider, LineEdit, TextEdit
- Audio: `set_audio_player_props`, `setup_audio_stream_player_2d/3d`, `set_bus_volume_db`, `remove_audio_bus_effect`
- Project: `get_layer_names` / `set_layer_names` (physics/render/navigation 2D+3D)

---

## v1.27.0 — 2026-07-28

**Surface expansion** — CanvasItem materials / sprites / Label-Button, utility nodes, project settings helpers.

### Added
- `material_2d_commands`: modulate, sprite texture/region, CanvasItemMaterial, Label/Button/TextureRect setup
- `utility_node_commands`: SpringArm3D, RemoteTransform3D, screen notifiers, markers, groups list/add/remove, FSM script, raycast util
- Project: `list_autoloads`, `set_window_settings`, `set_physics_ticks`, `list_project_settings_keys`

### Registry
- Regenerate with `scripts/export-surface-registry.ps1` → `SURFACE_REGISTRY.md`

---

## v1.26.0 — 2026-07-28 (fork: agent production surface)

**Major fork expansion** toward human-worker tool surfaces + open MCP server.  
**~514** registered plugin commands across **51** modules. Progress registry: `SURFACE_REGISTRY.md`.

### Honesty
- Docs coverage is **strong/partial/thin/classdb_only** with explicit **gaps** (`list_docs_coverage`).
- **Not** claimed: 100% of ClassDB methods or every editor dock control.
- Class reference lookup remains `describe_class` / `list_class_*`.

### Open MCP server (this fork)
- Machine-wide Node stdio server under `server/` + install scripts (`scripts/update-install.ps1`).
- Lite vs full tool discovery; `call_editor` escape hatch.

### Surfaces added / deepened (1.16–1.26)
- Agent: `health_check`, `agent_workflow_guide`, `list_docs_coverage`, `list_surface_registry`
- ClassDB / import / filesystem / i18n / multiplayer / tileset
- AnimationPlayer + AnimationTree + SpriteFrames + Skeleton + BoneMap
- Physics joints/areas/shape cast/vehicle/soft body/physical bone
- Animation playback, method/audio tracks, blend spaces, travel
- 2D: camera, parallax, lights, Line2D/Path2D, CanvasLayer, Timer
- 3D: probes, GI, CSG, fog, occluders, compositor, path
- Export preset CRUD, run export
- XR / OpenXR action maps + bindings
- Debugger continue/step + source breakpoints
- VisualShader scaffolding
- C# project helpers + `dotnet` / Godot build logs
- GDExtension scaffold + scons build helper
- Dialogue/cutscene JSON + runners
- UI lists, windows/dialogs, container recipes
- Tween, plugin scaffold, textures, custom Resource scripts
- Scene transitions, loading screen, SaveManager, EventBus, ObjectPool, CameraShake

### Docs / registry
- `SURFACE_REGISTRY.md` + `scripts/export-surface-registry.ps1`
- `DOCS_SURFACE_100.md`, `GAPS_VS_GODOT_DOCS.md`, `FORK.md`

---

## v1.15.1 — 2026-07-19

**Patch** — 15 fixes from an external user's full-toolset audit (all 174 tools tested against a live editor). Huge thanks to the reporter.

### Fixed — Critical
- **`set_particle_color_gradient` infinite loop / editor hang**: clearing a fresh `Gradient` point-by-point never terminates because `Gradient.remove_point` refuses to drop below 2 points. Gradients are now built by assigning `offsets` / `colors` wholesale. The same root cause also produced a spurious opaque-black stop at offset 0 in every `apply_particle_preset` color ramp — both fixed via the same change.
- **`connect_signal` connections were never saved to the `.tscn`**: `Object.connect()` was called without `CONNECT_PERSIST`, so `PackedScene.pack()` dropped the connection on save. Connections are now persistent; new optional `deferred` / `one_shot` parameters, and the response echoes `flags` / `persistent`.
- **`update_property` destroyed Resource-typed properties**: assigning e.g. `texture` by `"res://..."` path passed the raw String through, which the engine coerced to `null` — silently wiping the existing value. `PropertyParser` now loads `res://` / `uid://` paths into Resources (also fixes `batch_add_nodes` properties), and `update_property` fails loudly when a string cannot be resolved instead of committing a `null`.

### Fixed — High
- **`create_theme` returned `{}` and never wrote the file**: a `!= null` check on a `Dictionary` guard made the guard branch unconditional. Now uses `is_empty()` like every other call site. Also creates parent directories.
- **`get_performance_monitors` reported the editor process's metrics as the game's**: `Performance` is per-process. The tool now routes through the game IPC channel (requires a playing scene) and returns `"process": "game"`; use `get_editor_performance` for editor metrics.
- **`get_test_report` counted passing assertions as failures**: non-assertion steps (input/wait/screenshot) were scored as failed, and game replies were stored still double-wrapped so their `passed` key was never found. Only assertion results are stored now, and the envelope is unwrapped defensively. Empty reports return `no_results: true` instead of a misleading `all_passed: false`.
- **`run_test_scenario` reported `all_passed: false` on green runs**: same double-wrapped envelope, unwrapped one level too few in `_execute_assert_step`. Assertion results now surface `passed` at the top level with a consistent shape.

### Fixed — Medium
- **`get_scene_tree` returned editor-internal absolute paths** (`/root/@EditorNode@.../...`): paths are now scene-relative (root = `"."`), directly usable as `node_path` input for other tools, and ~10× smaller.
- **`analyze_signal_flow` dumped editor-internal connections** (~8k tokens of dock bookkeeping): now filters to persistent connections targeting nodes inside the edited scene.
- **`find_unused_resources` ignored `uid://` references**: `preload("uid://…")` and `uid=` references are now resolved back to their `res://` paths (self-referencing file-header uids excluded). References held via `ProjectSettings` defaults (main scene, audio bus layout, icon, autoloads) are also seeded, so `default_bus_layout.tres` and friends are no longer reported deletable.
- **`get_input_actions(include_builtin: false)` leaked 16 editor actions** (`spatial_editor/*`): actions not declared in the project's `ProjectSettings` are now excluded.
- **`create_resource` failed on missing parent directories**: directories are created recursively; the error message now includes the path.
- **`run_test_scenario` `keycode` input steps never released the key**, corrupting later assertions: keycode steps now auto-release like `action` steps (disable with `auto_release: false`).

### Fixed — Minor
- **`set_particle_material`**: emission sub-parameters (`emission_sphere_radius`, box extents, ring radii/height) are now listed in `changes[]`.
- `run_test_scenario` screen-text assertions no longer lose their result type to a key collision (`assert_type` field).

---

## v1.14.1 — 2026-05-24

**Patch** — `assert_node_state` regression fix

### Fixed
- **`assert_node_state` "Unknown command" regression**: The game-side handler in `mcp_game_inspector_service.gd` had been removed during the v1.7.0 refactor (`4ea3989`, 2026-03-29) that introduced `batch_add_nodes` / `watch_signals` / `setup_control`. The TypeScript server and editor-side GDScript still routed the call, but the runtime match statement no longer recognized it — so `assert_node_state` (and any `type:"assert"` step inside `run_test_scenario`) returned `Unknown command: assert_node_state` on every call from v1.7.0 through v1.14.0. Restored the handler with all 8 operators (`eq`, `neq`, `gt`, `lt`, `gte`, `lte`, `contains`, `type_is`) and sub-property access via `get_indexed()` (e.g. `position:y`). Reported by **Z_runner [CRWN]** on Discord.

---

## v1.14.0 — 2026-05-18

**Feature / Safety** — File-conflict safety overhaul (community contribution)

This release is a coordinated overhaul of how the addon interacts with editor-owned resources. It prevents the "external change" dialog and silent in-memory/disk divergence that could occur when MCP commands wrote scenes, scripts, shaders, or resources while Godot still had them open. Contributed by **[@aallnneess](https://github.com/aallnneess)** (PR #31), with the design and patch reviewed and tested locally with GitHub Copilot using GPT-5.5 xhigh. Reported and validated against the previous v1.13.x behavior.

### Added — safety primitives in `base_command.gd`
- `guard_offline_scene_save(path)`: blocks `ResourceSaver.save(...)` to a `.tscn`/`.scn` path when that scene is currently open in the editor. Returns a structured conflict error (JSON-RPC code `-32009`) including the path, open-scenes list, and a recovery suggestion.
- `guard_text_resource_write(path, force)`: blocks writes to a script/shader file that is currently open in Godot's script editor (or, for shaders, currently loaded/cached in `ResourceLoader`). Override with `force=true`.
- `add_child_with_undo(...)` / `set_property_with_undo(...)`: register live scene mutations through `EditorUndoRedoManager` with correct `add_do_reference` / `add_undo_reference` retention for `Resource` values so they survive GC across the undo history.
- `get_open_scene_paths()` / `is_scene_path_open()` / `is_active_scene_path()` / `is_text_resource_open_in_script_editor()`: shared checks so per-command code never re-implements the same logic.
- `normalize_project_path()`: consistent comparison key for `res://`, project-relative, and absolute paths.

### Changed — scene saves go through `EditorInterface`
- `save_scene`: when the target path matches the active edited scene, calls `EditorInterface.save_scene()`; when the target differs or the active scene has no path yet, calls `EditorInterface.save_scene_as(path)`. Refuses to save an inactive open scene tab. No more silent `ResourceSaver.save` to an open path.
- `create_scene` / `create_theme` / `edit_resource`: all guarded against accidentally targeting an open scene path.

### Changed — broad cross-scene edits are opt-in
- **`cross_scene_set_property` defaults to `dry_run=true`** (breaking change). Real writes now require `dry_run=false` **and** `force=true`. The response includes a per-scene `mode` field (`dry_run` / `offline_saved` / `live_open_scene`) and a `skipped_open_scenes` list so callers can see exactly what happened.
- The active open scene is live-edited via `EditorUndoRedoManager` instead of being offline-overwritten, so changes are visible in the editor and undoable.
- Inactive open scenes are skipped and reported rather than silently overwritten.

### Changed — live scene mutations participate in UndoRedo
- `batch_add_nodes`, `batch_set_property`: routed through the shared UndoRedo helpers.
- `node_commands`: node creation, `set_anchor_preset` (computed on a duplicate Control before applying), signal connect/disconnect, group add/remove — all undoable.
- `animation_commands`: animation create/remove, track add, and keyframe edits. `_upsert_animation_key` / `_restore_animation_key` give round-trip undo for keyframe edits (including the previously-present-key replacement case) using `is_equal_approx` time matching.
- `animation_tree_commands`: AnimationTree create, state machine state/transition edits, blend tree node changes, tree parameter edits.
- `tilemap_commands`: single-cell set, rect fill, and clear capture the affected cells' old state and apply via UndoRedo. Round-trip undoable.
- `theme_commands`: color, constant, font-size, and stylebox theme overrides; `setup_control` computes target state on a duplicate Control before applying.
- `audio_commands`, `navigation_commands`, `particle_commands`: node creation and resource assignment go through UndoRedo. Navigation bake also marks the active scene unsaved.
- `shader_commands`: shader material assignment via `set_property_with_undo`.

### Fixed — open script/shader writes
- `create_script` / `edit_script`: refuse to write when the target is open in the script editor, unless `force=true` is explicitly passed. Also restricted to `.gd` / `.cs` extensions — scene and shader paths are rejected with a clear suggestion (added in `6d8d650`).
- `edit_script` now actually implements the 1-based inclusive `start_line` / `end_line` range replacement that the CLI had been advertising. The TypeScript `edit_script` schema and CLI `script edit` both expose the new parameters.
- `create_shader` / `edit_shader`: same open-file guard, with `force=true` to override.
- Shader cache refresh fixed: `_refresh_loaded_shader` uses `take_over_path()` + `emit_changed()` to update any cached/live `Shader` resource, replacing the unreliable `Shader.reload_from_file()` call. Live materials referencing the shader now pick up edits immediately.

### Fixed — `execute_editor_script` escape hatch
- Submitted code is scanned for direct file/resource write APIs (`ResourceSaver.save`, `FileAccess WRITE`, `ProjectSettings.save`, `ConfigFile.save`, `DirAccess` filesystem mutations). If present, the call is refused with a structured conflict error unless `allow_unsafe_editor_io=true` is explicitly passed. Closes the obvious workaround where an AI client could route around the per-command guards by submitting raw script.

### Changed — server schemas
- `create_script` / `edit_script` / `create_shader` / `edit_shader`: added optional `force` parameter and updated tool descriptions.
- `cross_scene_set_property`: added optional `dry_run` / `force` parameters and a description that reflects the new dry-run-by-default semantics.
- `execute_editor_script`: added optional `allow_unsafe_editor_io` parameter.
- `cli.ts`: `script create` and `script edit` accept `--force` flag.

### Migration notes
- **Breaking**: scripts/agents that previously relied on `cross_scene_set_property` writing on first call now need to add `dry_run=false force=true` to perform writes. Without those, the call returns a dry-run preview. This is intentional — silent project-wide writes were a footgun.
- **Soft-breaking**: scripts/agents that previously overwrote open files (scenes, scripts, shaders) without checking now hit a `-32009` conflict error. The fix is to either close the file in the editor first, save through the editor (for scenes), or pass `force=true` (for scripts/shaders, when you've verified no buffer holds unsaved changes).
- Existing wire-compatible calls that did *not* target open resources continue to work unchanged.

---

## v1.13.2 — 2026-05-13

**Bug Fix** — Port allocation race when multiple Claude Code sessions start at the same time

### Fixed
- **Parallel-session port collision** (Discord report by CrusherEAGLE): Two Claude Code sessions starting nearly simultaneously could both pre-check port 6505 as free, both attempt to bind, the loser would get `EADDRINUSE` and give up without retrying the next port. The session that lost the race had a server that never started, so every tool call failed for the remainder of that session with no way to recover short of restart. The fallback path in `index.ts` claimed it would "retry on first command" but no such retry existed.
- The fix replaces the racy pre-check + single bind with a proper bind-retry loop: each port in `6505–6509` is tried in turn, and `EADDRINUSE` triggers a fall-through to the next port. Only when the entire range is exhausted does `connect()` reject, with a clear error message and remediation hint.
- Cleaned up the misleading "will retry on first command" log line in `index.ts`.

### Tests
- New `tests/godot-connection.test.ts` covers: first-port allocation, sequential fall-through, **simultaneous parallel connects** (the exact regression scenario), range exhaustion, and `fixedPort=true` fail-fast behavior. 5 new tests, 62 total.

---

## v1.13.1 — 2026-05-12

**Bug Fix** — Silent disconnect / dead-connection recovery

### Fixed
- **Heartbeat now actually detects dead connections** (Discord report by CrusherEAGLE): The `ping`/`pong` heartbeat was being sent every 10s but neither side tracked whether responses were arriving, so a half-open TCP connection (common on Windows after sleep/wake, VPN toggle, or a brief editor hang) left both sides holding a dead socket. `isConnected()` continued to return `true`, every command timed out at 30s, and the only way back was to restart Claude Code **and** the Godot editor. Fixed on both sides:
  - **Server**: tracks the last `pong` timestamp; if 30s passes with no pong, forcibly destroys the socket (`terminate()`, vs `close()` which waits for a FIN ack that never comes on a dead link). Pending requests are rejected immediately rather than hanging for 30s.
  - **Editor**: sends its own `ping` every 5s, tracks per-port inactivity, and after 30s of inbound silence force-closes the peer so the existing 3s reconnect cycle takes over.
  - **OS-level TCP keepalive** enabled on the server socket (5s initial delay), surfacing half-open links faster than Windows' ~2-hour default.
- **Status panel surfaces stale state**: New yellow ⚠ indicator when a port is reconnecting from a stale state, plus per-port idle time (seconds since last received message) in the Clients tab. No more "looks fine while everything is broken" UI.

### Notes
- Recovery is automatic within ~30s after the connection dies. Watch the Output panel for `[MCP] Port NNNN silent for X.Xs — forcing reconnect` if you want to see it happen.
- No API or tool changes — same 172 tools, same behavior in the healthy path.

---

## v1.13.0 — 2026-05-05

**Bug Fixes & Polish** — Mouse motion dispatch, setup config, site pricing

### Fixed
- **`simulate_mouse_move` honors explicit `unhandled: false`** (#24, #25): Drag motions (`button_mask > 0`) auto-promote to `push_input` so camera-pan use cases bypass GUI consumption. But callers writing UI drag-and-drop tests need events to reach the GUI dispatcher (so `_get_drag_data` / `_drop_data` fire). Now: if the caller explicitly passes `unhandled: false`, that wins; auto-promotion only happens when `unhandled` was omitted. Default behavior preserved.
- **v1.12.0 build blocker**: Restored missing `mcp/server/src/utils/load-instructions.ts` referenced by `index.ts` since v1.12.0. Fresh clones of v1.12.0 failed `npm run build` with `Cannot find module './utils/load-instructions.js'`. v1.13.0 now builds clean.

### Changed
- **`setup` no longer pins `GODOT_MCP_PORT`** (#27): Generated MCP client config (Claude Desktop, Cursor, etc.) omits the `GODOT_MCP_PORT` env var so the server can auto-scan ports `6505–6509`. Pinning a fixed port caused silent failures when a stale process held the port. Users who need a fixed port can still set it manually.
- **Site JSON-LD price → $15** (#26): Structured data on the landing page now reflects the current price.

### Improved
- **README clarity** (issue #7 follow-up): More prominent note that the public repo ships the addon only — the MCP server is distributed via Buy Me a Coffee / itch.io.
- **`build-release.sh` portability**: Falls back to system `zip` and `python3` when 7-Zip is not on PATH.

---

## v1.12.0 — 2026-04-19

**Feature** — Android Remote Deploy · **Bug Fix** — Runtime IPC on custom user dirs

### Added
- **Android Remote Deploy** (3 tools, Full mode only — #20):
  - `list_android_devices` — wraps `adb devices -l`, returns serial/state/model/product. Resolves adb from Editor Settings > Export > Android > Adb, falling back to `adb` on PATH.
  - `get_android_preset_info` — reads metadata (package name, export path, runnable) from an Android preset in `export_presets.cfg`.
  - `deploy_to_android` — one-shot pipeline: Godot CLI export → `adb install -r` → `adb shell monkey` launch. Options: `preset_name`, `device_serial`, `debug`, `launch`, `skip_export`. Synchronous; export step can take tens of seconds.
- Full mode tool count: **169 → 172**. LITE / 3D / MINIMAL modes are unchanged.

### Fixed
- **`get_game_user_dir()`** (`commands/base_command.gd`) — #21: Runtime IPC commands (`get_game_scene_tree`, `get_game_node_properties`, `simulate_*`, etc.) failed with `Could not create game request file` when the project used `application/config/use_custom_user_dir=true`, or when `application/config/name` contained characters illegal on the host OS (e.g. `:` on Windows). Editor and game now resolve to the same dir: early-return `OS.get_user_data_dir()` for custom user dirs, and sanitize `config/name` via `xml_unescape().validate_filename().replace(".", "_")` — matching Godot's own logic in `ProjectSettings::_init`. Thanks @asim9834 for the detailed repro + patch.

---

## v1.11.0 — 2026-04-15

**Feature** — New `--3d` mode for 100-tool-limit clients

### Added
- **`--3d` mode**: Registers exactly 100 tools — the 81 core LITE tools plus Physics (6), AnimationTree (8), and Navigation (5). Designed for clients with a 100-tool cap (e.g. Google Antigravity with Claude Code proxy) that need full 3D game development capabilities. Usage: `node build/index.js --3d`

### Improved
- **Troubleshooting docs**: Clarified port conflict advice in INSTALL.md — recommends letting the server auto-scan ports 6505–6509 instead of setting a fixed `GODOT_MCP_PORT`, which can cause silent failures with stale processes

### Mode comparison

| Flag | Tools | Use case |
|------|-------|----------|
| *(none)* | 169 | Full mode — all tools |
| `--3d` | 100 | 3D game dev under 100-tool limit |
| `--lite` | 81 | Tight tool limits (Cursor, etc.) |
| `--minimal` | 35 | Ultra-tight limits (local LLMs) |

---

## v1.10.3 — 2026-04-11

**Bug Fixes** — Autoload preservation, Windows build, port conflict warning

### Fixed
- **Autoload deletion on `--import` / shutdown**: Plugin no longer removes pre-existing MCP autoloads from `project.godot`. Previously, `_remove_autoloads()` deleted all managed autoload keys unconditionally — even if they were project-owned. Now only autoloads injected by the current plugin session are removed. (#17)
- **Windows build failure**: Removed Unix-only `chmod -R a+x build || true` from the `build` script in `package.json`. The `chmod` and `true` commands don't exist on Windows cmd/PowerShell, causing `node build/setup.js install` to fail with "Build failed" even though TypeScript compilation succeeded. The fix is simply `"build": "tsc"` — execute permissions are not needed since the server runs via `node`. (#Discord)

### Improved
- **Port conflict warning for explicit port**: When `GODOT_MCP_PORT` is set and the port is already occupied (e.g. by a stale process), the server now logs a clear warning with remediation steps instead of silently failing to bind. (#15)

---

## v1.10.2 — 2026-04-11

**Fix** — Linux permission issue for build files

### Fixed
- **Linux permission denied**: Added `chmod -R a+x` to build process so that `build/index.js` and other compiled files have execute permission out of the box on Linux/macOS. Previously, users had to manually run `chmod -R a+x build` after installation. (Thanks to kflamsted for reporting!)

---

## v1.10.1 — 2026-04-08

**UX Improvement** — Bottom panel renamed, INSTALL.md rewritten

### Improved
- **Bottom panel renamed**: "MCP Server" → "MCP Pro" for consistency with the product name. Status label also updated.
- **INSTALL.md rewritten**: Added zip structure diagram, clear separation of addon vs server, Claude Desktop config paths, and better troubleshooting. Clarified that `configure` must be run from the Godot project directory.

---

## v1.10.0 — 2026-04-07

**New Tools & Quality Sweep** — Editor camera control, 169 tools, comprehensive audit fixes

### New Tools
- **`get_editor_camera`**: Get the 3D editor viewport camera position, rotation, and FOV. Useful for understanding the current view before taking screenshots.
- **`set_editor_camera`**: Move the 3D editor viewport camera to a specific position and orientation. Supports position, rotation, look_at target, and FOV. Use this to frame a view before screenshots to validate changes visually.

### Fixed
- **`plugin.gd` version display**: Was hardcoded to "v1.6.0" since initial release. Now dynamically reads from `plugin.cfg` — always shows the correct version.
- **Tool count inconsistency**: Was showing 162/163/167 across different files. All references now correctly say 169.
- **`node setup.js` path**: All docs and help text now correctly say `node build/setup.js`.
- **`configure` cwd issue**: INSTALL.md now clearly separates `install` (run from server/) and `configure` (run from Godot project root) to avoid `.mcp.json` being placed in the wrong directory.
- **INSTALL.md**: Fixed step numbering skip, stale tool count (49→169), port range (6505-6514).
- **README.md**: Replaced hardcoded dev paths with `/path/to/` placeholders.

### Improved
- **"v1.x" wording removed**: All pricing and marketing text now says "lifetime updates" without version scope.
- **Plugin port range**: WebSocket comment and connection range expanded to 6505-6514 (6510-6514 reserved for CLI).
- **Pre-built JS in release zip**: `build/setup.js` and `build/cli.js` work immediately after extract + `npm install`.
- **Claude Desktop support**: Confirmed working, added to configure auto-detection.

---

## v1.9.4 — 2026-04-06

**Bug Fixes** — State enum type regression, zip plugin version

### Fixed
- **`mcp_game_inspector_service.gd` State enum type error (regression)**: `var _state: State = State.IDLE` caused "Cannot assign a value of type mcp_game_inspector_service.gd.State to variable with specified type State" in some Godot versions. Changed back to `var _state := State.IDLE` (type inference). This was originally fixed in v1.6.4 but regressed. (Thanks @kalish)
- **Release zip contained wrong plugin version**: v1.9.3 zip shipped with plugin.cfg showing v1.9.2 due to a build order issue. Fixed build pipeline to ensure public repo is synced before zip creation.

---

## v1.9.3 — 2026-04-06

**Improvement** — Pre-built JS in release zip, docs cleanup

### Improved
- **Pre-built JS files included in release zip**: `build/setup.js`, `build/cli.js`, and all other compiled files are now included. Users can run `node build/setup.js install` immediately after extracting — no need to manually run `npm run build` first.
- **CLI naming unified in docs**: Removed `godot-cli` shorthand. All docs consistently use `node build/cli.js`. Added note that server must be built before CLI use.
- **CLI help port range fixed**: `--help` output now correctly shows 6510-6514 (CLI range), not 6505-6509 (MCP server range).

---

## v1.9.2 — 2026-04-06

**New Features** — Setup CLI, code-to-inspector workflow, CLI click fix

### New Features
- **Setup CLI (`setup.js`)**: One-command server setup and management. Commands: `install` (npm install + build), `check-update` (GitHub release check with semver comparison), `configure` (auto-detect AI client and generate .mcp.json), `doctor` (environment diagnostics).
- **Code-to-inspector migration workflow**: New guideline in AGENTS.md and skills.md instructing AI to prefer `update_property` over hardcoded GDScript for visual properties (colors, sizes, theme overrides). Includes step-by-step migration pattern.

### Fixed
- **CLI `input click --button` mapping**: The CLI sent string values ("left", "right", "middle") but the plugin expects numeric indices (1, 2, 3). Now correctly maps `left`→1, `right`→2, `middle`→3. (Thanks @Gogomy)

### Improved
- **INSTALL.md**: Added quick setup flow using `setup.js` for both fresh install and updates.
- **Instruction files**: All 12 client instruction files updated with new workflow patterns.

---

## v1.9.1 — 2026-04-05

**Bug Fix** — GODOT_MCP_PORT env var now respected + Cursor Full mode

### Fixed
- **`GODOT_MCP_PORT` env var ignored**: The server always scanned ports 6505-6509 for the first free port, ignoring the explicitly configured port. Now when `GODOT_MCP_PORT` is set, the server uses that port directly without scanning. (Fixes #13)

### Changed
- **Cursor moved to Full mode**: Cursor removed its 40-tool limit with Dynamic Context Discovery — all 167 tools now work in Full mode. (Thanks to @CrossBread for PR #14)

---

## v1.9.0 — 2026-04-05

**Universal Compatibility** — Minimal mode, CLI tool, and test suite

### New Features
- **Minimal mode (`--minimal`)**: Registers only 35 essential tools for clients with tight tool limits (Cursor ~40, OpenCode, local LLMs with small context windows). Covers project info, scene management, node CRUD, script editing, editor errors, input simulation, and runtime inspection.
- **CLI tool (`godot-cli`)**: Command-line interface for controlling Godot directly from a terminal. LLMs discover capabilities progressively via `--help` instead of loading all tool definitions upfront — zero context overhead, works with any client that has bash/terminal access. 7 command groups: project, scene, node, script, editor, input, runtime.
- **Test suite**: Added vitest with 47 unit tests covering tool-filter, error utilities, zod coercion, and CLI help/error handling.

### Improved
- **Client compatibility guide**: README and landing page now include a compatibility matrix for 12+ MCP clients with recommended mode for each (Full/Lite/Minimal/CLI).
- **Landing page**: Added "Choose Your Mode" setup step, CLI documentation, and new FAQ entry for tool count limits.
- **`print_verbose` for connect/disconnect**: WebSocket connect/disconnect messages in the Godot plugin now use `print_verbose()` instead of `print()`, eliminating terminal spam during normal operation.
- **Per-client instruction files**: `instructions/` folder with ready-to-copy instruction files for 12 AI clients (Claude Code, Cursor, Cline, Windsurf, Gemini CLI, Codex CLI, OpenCode, Roo Code, JetBrains/Junie, Amazon Q, Continue, Augment). Includes CLI usage documentation.

---

## v1.8.1 — 2026-04-04

**Bug Fix** — @export node reference support in update_property

### Fixed
- **`update_property` @export node references**: Setting `@export var` node references (e.g. `@export var hud: HUD`) via `update_property` now correctly resolves string paths to actual node references. Previously, `typeof(old_value)` returned `TYPE_NIL` for unset exports and `TYPE_OBJECT` for set ones, neither of which resolved the path string to a node. The fix checks `PROPERTY_HINT_NODE_TYPE` from the property's metadata to detect node reference exports and resolve accordingly. (Fixes #12)

---

## v1.8.0 — 2026-04-02

**New Features** — HTTP transport, screenshot file saving, custom class support

### New Features
- **Streamable HTTP transport**: New `--http` and `--http-port` flags for MCP clients that need HTTP instead of stdio. Starts an HTTP server at `http://127.0.0.1:8001/mcp` (default port).
- **Screenshot `save_path` option**: `get_editor_screenshot` and `get_game_screenshot` now accept an optional `save_path` parameter (e.g. `res://screenshot.png`) to save directly to disk instead of returning base64, avoiding MCP response cache bloat.
- **`add_node` custom class support**: `add_node` now resolves script-defined classes (`class_name`) in addition to built-in ClassDB types via `ProjectSettings.get_global_class_list()`.

### Improved
- **INSTALL.md**: Added "Updating to a New Version" section with step-by-step upgrade instructions.

---

## v1.7.2 — 2026-03-31

**Bug Fixes & Improvements** — execute_game_script robustness + auto-dismiss control

### Fixed
- **`execute_game_script` mixed indentation error**: User code with space indentation was prepended with tabs, causing "Mixed use of tabs and spaces" parse errors. Now auto-detects indent width and normalizes all leading spaces to tabs before wrapping.
- **`execute_game_script` standalone lambda error**: Top-level `func` definitions in user code were nested inside the wrapper's `run()` function, triggering "Standalone lambdas cannot be accessed" parse errors. Now extracts top-level functions to class level.
- **`command_router` crash on missing config section**: `_load_tool_config()` called `get_section_keys("disabled_tools")` without checking if the section exists, causing "Cannot get keys from nonexistent section" errors on fresh installs.

### Changed
- **Auto-dismiss dialogs now opt-in**: Previously auto-dismissed blocking editor dialogs whenever an MCP client was connected. Now disabled by default — AI must explicitly enable via the new `set_auto_dismiss` tool before operations that trigger reload/save dialogs.

### New Tools
- **`set_auto_dismiss`**: Enable or disable automatic dismissal of blocking editor dialogs (e.g., "Reload from disk?", "Save changes?"). Use before external file modifications, disable when done.

---

## v1.7.1 — 2026-03-30

**Bug Fixes** — Scene transition crash fix and deprecated API cleanup

### Fixed
- **`click_button_by_text` crash on scene transition**: Clicking a button that triggers a scene change (e.g., navigating from main menu to options) caused "Cannot get path of node as it is not in a scene tree" errors. Now caches button info before emitting the pressed signal and guards with `is_instance_valid()` / `is_inside_tree()` after the click.
- **Deprecated `push_unhandled_input()` warning**: Replaced with `push_input()` in `mcp_input_service.gd` per Godot 4.x API updates.

---

## v1.7.0 — 2026-03-29

**New Tools & Multi-Client Support** — 3 new tools for faster scene building, runtime signal debugging, and UI layout + instructions for non-Claude AI clients

### New Tools
- **`batch_add_nodes`**: Add multiple nodes in a single call. Nodes are processed in order so earlier nodes can be referenced as parents — build entire node trees in one shot instead of calling `add_node` repeatedly.
- **`watch_signals`**: Monitor signal emissions on specified nodes in the running game for a set duration. Returns a timestamped log of every signal fired with arguments — great for debugging event flow and verifying signal connections.
- **`setup_control`**: Configure a Control/Container node's layout in one call: anchor preset, min size, size flags, margins (MarginContainer), separation (VBox/HBoxContainer), and grow direction. Replaces 5+ `update_property` calls.

### New
- **`AGENTS.md` template**: Custom instructions for non-Claude AI clients (OpenAI Codex, opencode/ollama, Cursor, etc.). Includes editor vs runtime tool categorization, workflow patterns, formatting rules, and common pitfalls. Included in release zip.

---

## v1.6.5 — 2026-03-27

**assert_node_state Fix** — Game-side handler was missing, causing "Unknown command" error

### Fixed
- **`assert_node_state` missing game-side handler**: The command was registered in the TypeScript server and editor-side GDScript, but `mcp_game_inspector_service.gd` had no handler — returning "Unknown command" at runtime. This also broke node assertions within `run_test_scenario`. All 8 operators (eq, neq, gt, lt, gte, lte, contains, type_is) now work correctly.
- **Sub-property access in assertions**: Properties like `position:y` now use `get_indexed()` instead of `get()`, enabling assertions on vector components and nested properties.

---

## v1.6.4 — 2026-03-25

**Enum Type Fix** — Fixes script error on play in certain Godot versions

### Fixed
- **`mcp_game_inspector_service.gd` State enum type error**: Explicit `State` type annotation on `_state` variable caused "Cannot assign a value of type mcp_game_inspector_service.gd.State to variable with specified type State" errors in some Godot versions. Changed to type inference (`:=`) which resolves the mismatch.

---

## v1.6.3 — 2026-03-24

**Camera Pan Fix** — Mouse drag events now bypass GUI layer to reach `_unhandled_input()`

### Fixed
- **Mouse drag not reaching `_unhandled_input()`**: `simulate_mouse_move` with `button_mask` (drag simulation) was consumed by GUI Controls (`mouse_filter=STOP`) before reaching `_unhandled_input()`. Camera pan, drag-to-select, and other drag-based mechanics that rely on `_unhandled_input()` now work correctly. Events with `button_mask > 0` automatically use `push_unhandled_input()` to bypass the GUI layer.

### New
- **`simulate_mouse_move` `unhandled` parameter**: Optional `unhandled` flag to force any mouse motion event to bypass GUI and go directly to `_unhandled_input()`. Auto-enabled when `button_mask > 0`.
- **`simulate_sequence` `unhandled` support**: Sequence `mouse_motion` events also support the `unhandled` flag.

---

## v1.6.2 — 2026-03-24

**Animation Easing & Mouse Drag Simulation** — Community-requested fixes

### New
- **`set_animation_keyframe` easing parameter**: Optional `easing` param (default 1.0) to control keyframe transition curves. Values: 1.0=linear, <1.0=ease-in, >1.0=ease-out, negative=in-out variants.
- **`get_animation_info` easing field**: Each keyframe now returns its `easing` value.
- **`simulate_mouse_move` button_mask**: New `button_mask` parameter (1=left, 2=right, 4=middle) enables drag simulation. Required for games that check `InputEventMouseMotion.button_mask` (e.g. camera pan with mouse drag).
- **`simulate_sequence` button_mask**: Sequence events also support `button_mask` for drag operations.

### Fixed
- **Mouse sequence events**: `simulate_sequence` now correctly handles flat key format (`relative_x`, `relative_y`, `x`, `y`) in addition to nested format. Previously, mouse motion events in sequences had `relative=(0,0)` because the flat-to-nested conversion was missing.

---

## v1.6.1 — 2026-03-21

**Permission Presets** — Auto-approve tool permissions for Claude Code

### New
- **`settings.local.json`** (conservative): Pre-configured permission file that auto-approves 152 of 163 tools. Destructive tools (`delete_node`, `delete_scene`, `execute_editor_script`, etc.) still require manual approval.
- **`settings.local.permissive.json`**: Allows all 163 tools and all Bash commands, with an explicit deny list for dangerous shell commands (`rm -rf`, `git push --force`, `git reset --hard`, etc.) and destructive MCP tools.
- Copy either file to `~/.claude/settings.local.json` to skip per-tool permission prompts.

---

## v1.6.0 — 2026-03-21

**Enhanced Editor Panel** — Activity log with response details, client monitor, and tool management

### New
- **Activity tab**: Full command log showing method name, status, port, and timestamp. Toggle "Show Response Details" to inspect the JSON responses sent back to AI clients. Clear button to reset the log.
- **Clients tab**: Real-time view of all 5 WebSocket ports (6505-6509) with connection status and elapsed time since connection.
- **Tools tab**: Searchable list of all 163 tools with individual enable/disable checkboxes. Bulk "Enable All" / "Disable All" buttons. Disabled tools are persisted across sessions (`user://mcp_tool_config.cfg`) and return a clear error message to AI clients.

### Changed
- Status panel rebuilt with TabContainer (Activity / Clients / Tools)
- WebSocket server now emits `command_completed` signal with full response data and source port
- Connection time tracking per port for uptime display

---

## v1.5.3 — 2026-03-15

**New tool** — `record_frames` for long-running debug observation

### New
- **`record_frames`**: Capture up to 600 screenshots saved as PNG files to `user://mcp_recorded_frames/`. Unlike `capture_frames` (which returns base64 images directly, max 30), this tool saves to disk and returns file paths — ideal for long-running debug sessions without flooding the AI context with image data. Supports optional `node_data` tracking for per-frame property snapshots (position, velocity, etc.).

---

## v1.5.2 — 2026-03-13

**Bugfix** — Screenshot capture now works when the SceneTree is paused

### Fixed
- **`mcp_screenshot_service.gd`**: Added `process_mode = Node.PROCESS_MODE_ALWAYS` so the file-polling loop in `_process()` keeps running during pause. The other two autoloads (`mcp_input_service.gd`, `mcp_game_inspector_service.gd`) already had this — screenshot service was the only one missing it.
- **`mcp_screenshot_service.gd`**: Replaced `await get_tree().process_frame` with `await get_tree().create_timer(0.05).timeout` — `process_frame` never fires when the tree is paused, but `create_timer()` with default `process_always=true` does.

Thanks to **mrkielbasa** for reporting this bug!

---

## v1.5.1 — 2026-03-08

**Patch release** — AI Skills file for better out-of-the-box experience

### New
- **`skills.md`**: Added `addons/godot_mcp/skills.md` — a comprehensive guide for AI assistants covering all 162 tools, 10 practical workflows, best practices, and common pitfalls. Users can copy this to `.claude/skills.md` in their project root so Claude Code knows how to use the MCP tools effectively from the start.
- **README**: Added setup step for copying `skills.md` to `.claude/skills.md`.

---

## v1.5.0 — 2026-03-04

**Feature** — Lite mode for MCP clients with tool count limits

### New Features
- **Lite mode (`--lite`)**: Launch with `--lite` flag to register only 76 core tools instead of 162. Designed for MCP clients with tool count limits (Windsurf: 100, Cursor: ~40, Antigravity: 100).
  - Core categories (always loaded): project, scene, node, script, editor, input, runtime, input_map
  - Extended categories (Full mode only): animation, animation_tree, audio, batch, export, navigation, particle, physics, profiling, resource, scene_3d, shader, test, theme, tilemap, analysis
  - Usage: Add `"--lite"` to args in your MCP config

---

## v1.4.5 — 2026-03-04

**Patch release** — Godot 4.3 compatibility fix

### Bug Fixes
- **Godot 4.3 compatibility**: Fixed `scene_3d_commands.gd` parse error caused by `Environment.TONE_MAPPER_AGX` enum (added in Godot 4.4). Now uses integer value for backward compatibility. This was a blocking error that prevented the entire plugin from loading on Godot 4.3.

---

## v1.4.4 — 2026-03-04

**Patch release** — Revert Output panel filter expansion

### Bug Fixes
- **`get_editor_errors`**: Removed `W `, `WARN`, `GDScript` Output panel filters added in v1.4.3 — these patterns don't actually appear in Godot's Output panel (`push_warning` uses `WARNING:` prefix) and caused false positives on normal text.

---

## v1.4.3 — 2026-03-04

**Patch release** — Comprehensive error/warning detection

### Improvements
- **`get_editor_errors`**: Now reads runtime errors from the debugger Errors tab (ScriptEditorDebugger), returned with `DEBUGGER:` prefix including stack traces. Previously only static analysis and Output panel errors were captured.

### Bug Fixes
- **`get_editor_errors`**: Fixed debugger Errors tab not being found because the tab name includes a count suffix (e.g. "Errors (1)") — now uses prefix matching.

---

## v1.4.2 — 2026-03-04

**Patch release** — Improved error detection in script editor

### Improvements
- **`get_editor_errors`**: Now reads GDScript analyzer errors and warnings from the script editor's error/warning panels (VSplitContainer RichTextLabels), in addition to the Output panel and CodeEdit line highlights. Catches static analysis messages like type mismatches and autoload name conflicts that were previously missed.

---

## v1.4.1 — 2026-03-02

**Patch release** — Bug fixes found during comprehensive tool audit

### Bug Fixes
- **`replay_recording`**: Fixed false crash recovery error (`_pending_command` flag not cleared for async replay loop)
- **`wait_for_node`**: Fixed false crash recovery error when polling for node appearance
- **`apply_particle_preset`**: Fixed editor crash in `gl_compatibility` renderer caused by immediate `GradientTexture1D` assignment — now uses `set_deferred` and reduced texture width

---

## v1.4.0 — 2026-03-01

**162 tools** across 23 categories (+15 new tools)

### New Tools
- **`move_to`** — Autopilot: automatically walk a character to target coordinates using pathfinding
- **`navigate_to`** — High-level navigation command for AI-driven movement
- **`find_nearby_nodes`** — Find nodes within a radius of a given position
- **`get_node_groups`** / **`set_node_groups`** — Read and write node group memberships
- **`find_nodes_in_group`** — Query all nodes belonging to a specific group
- **`get_output_log`** — Retrieve Godot's Output panel contents
- **`get_input_actions`** / **`set_input_action`** — Read and configure Input Map actions
- **`search_in_files`** — Full-text search across project files
- **`validate_script`** — Check GDScript for errors without running
- **`get_resource_preview`** — Get thumbnail previews of resources
- **`get_scene_exports`** — List exported variables in a scene's root script
- **`add_autoload`** / **`remove_autoload`** — Manage autoload singletons

### Bug Fixes & Improvements
- **Crash recovery**: `capture_frames` no longer triggers false crash recovery (`_pending_command` flag fix)
- **`capture_frames` node_data**: Optional per-frame property snapshots via `node_data` parameter
- **Debugger auto-continue**: Automatically presses Continue when runtime errors pause the debugger
- **`simulate_key` duration**: Now accepts fractional seconds (e.g., 0.3s) for precise movement
- **Command router fix**: All 8 command classes now properly registered (~47 tools were previously unreachable)

---

## v1.3.1 — 2026-02-27

**Patch release**

### Bug Fixes
- **`get_editor_errors`**: Now reads from Output panel and CodeEdit error gutter (previously returned empty results)
- **Tonemap enum**: Fixed environment tonemap mode enum name mapping

---

## v1.3.0 — 2026-02-26

**147 tools** across 23 categories (+63 new tools)

### New Tool Categories

#### AnimationTree & State Machine (8 tools)
- `create_animation_tree`, `get_animation_tree_structure`, `set_tree_parameter`
- `add_state_machine_state`, `remove_state_machine_state`
- `add_state_machine_transition`, `remove_state_machine_transition`
- `set_blend_tree_node`

#### Physics & Collision (6 tools)
- `setup_collision`, `setup_physics_body`, `get_collision_info`
- `get_physics_layers`, `set_physics_layers`, `add_raycast`

#### 3D Scene (6 tools)
- `add_mesh_instance`, `setup_lighting`, `set_material_3d`
- `setup_environment`, `setup_camera_3d`, `add_gridmap`

#### Particles (5 tools)
- `create_particles`, `set_particle_material`, `set_particle_color_gradient`
- `get_particle_info`, `apply_particle_preset` (8 built-in presets: fire, smoke, sparks, rain, snow, explosion, magic, dust)

#### Navigation (5 tools)
- `setup_navigation_region`, `bake_navigation_mesh`, `setup_navigation_agent`
- `set_navigation_layers`, `get_navigation_info`

#### Audio (6 tools)
- `get_audio_bus_layout`, `add_audio_bus`, `set_audio_bus`
- `add_audio_bus_effect`, `add_audio_player`, `get_audio_info`

#### Testing & QA (5 tools)
- `run_test_scenario`, `assert_node_state`, `assert_screen_text`
- `run_stress_test`, `get_test_report`

#### Project Analysis (6 tools)
- `find_unused_resources`, `analyze_signal_flow`, `analyze_scene_complexity`
- `detect_circular_dependencies`, `get_scene_dependencies`, `get_project_statistics`

### Expanded: Runtime Analysis
- `find_ui_elements`, `click_button_by_text`, `wait_for_node`
- Runtime tools expanded from 4 to 15 tools

### Other Additions
- `add_resource`, `create_resource`, `edit_resource`, `read_resource` — Resource management tools

---

## v1.2.0 — 2026-02-24

**84 tools** across 14 categories (+34 new tools)

### New Tool Categories

#### Animation (6 tools)
- `list_animations`, `create_animation`, `add_animation_track`
- `set_animation_keyframe`, `get_animation_info`, `remove_animation`

#### TileMap (6 tools)
- `tilemap_set_cell`, `tilemap_fill_rect`, `tilemap_get_cell`
- `tilemap_clear`, `tilemap_get_info`, `tilemap_get_used_cells`

#### Theme & UI (6 tools)
- `create_theme`, `set_theme_color`, `set_theme_constant`
- `set_theme_font_size`, `set_theme_stylebox`, `get_theme_info`

#### Profiling (2 tools)
- `get_performance_monitors`, `get_editor_performance`

#### Batch Operations & Refactoring (5 tools)
- `find_nodes_by_type`, `find_signal_connections`, `batch_set_property`
- `find_node_references`, `get_scene_dependencies`

#### Shader (6 tools)
- `create_shader`, `read_shader`, `edit_shader`
- `assign_shader_material`, `set_shader_param`, `get_shader_params`

#### Export (3 tools)
- `list_export_presets`, `export_project`, `get_export_info`

### Bug Fixes
- Fixed game IPC connection when project name changes
- Added `set_project_setting` tool for safe project.godot modifications via EditorSettings API
- Fixed script reload behavior

---

## v1.1.0 — 2026-02-23

**49 tools** across 8 categories (+16 new tools)

### New Tool Categories

#### Input Simulation (4 tools)
- `simulate_key`, `simulate_mouse_click`, `simulate_mouse_move`, `simulate_sequence`

#### Runtime Analysis (4 tools)
- `play_scene`, `stop_scene`, `get_game_scene_tree`, `get_game_screenshot`
- `execute_game_script`, `get_game_node_properties`, `set_game_node_property`
- `monitor_properties`, `capture_frames`

### Other
- Added `build-release.sh` for reproducible release packaging
- `start_recording` / `stop_recording` / `replay_recording` for input recording

---

## v1.0.0 — 2026-02-22

**~33 tools** across 6 categories — Initial release

### Tool Categories
- **Scene Management**: `create_scene`, `open_scene`, `save_scene`, `get_scene_tree`, `delete_scene`, `get_scene_file_content`, `add_scene_instance`
- **Node Operations**: `add_node`, `delete_node`, `rename_node`, `move_node`, `duplicate_node`, `update_property`, `get_node_properties`, `batch_get_properties`, `connect_signal`, `disconnect_signal`, `get_signals`
- **Script**: `create_script`, `read_script`, `edit_script`, `attach_script`, `list_scripts`, `find_nodes_by_script`, `find_script_references`, `get_open_scripts`
- **Editor**: `get_editor_screenshot`, `get_editor_errors`, `clear_output`, `execute_editor_script`, `reload_plugin`
- **Project**: `get_project_info`, `get_project_settings`, `get_filesystem_tree`, `search_files`
- **UI**: Anchor presets (`set_anchor_preset`)

### Architecture
- WebSocket-based communication between Godot editor plugin and MCP TypeScript server
- Supports Claude Code, Cursor, Windsurf, and any MCP-compatible AI coding tool
- Screenshot capture from both editor and game viewports
