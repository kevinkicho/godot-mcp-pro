# Godot MCP Pro - Tool Surface Registry

Generated: 2026-07-29  
Plugin version: **1.64.0**  

## Honesty

Tracks workflow command surface growth - not 100% of ClassDB or every editor control.
See list_docs_coverage, docs/PRODUCTION_SURFACE_COMPLETE.md, GAPS_VS_GODOT_DOCS.md.
Modules live under addons/godot_mcp/commands/<domain>/ (recursive auto-discover).

## Totals

- **Registered plugin commands:** 1494
- **Command modules:** 193
- **Domains:** 15

## Commands by domain

- **2d** - 105 commands
- **3d** - 35 commands
- **agent** - 58 commands
- **animation** - 170 commands
- **assets** - 171 commands
- **audio** - 33 commands
- **core** - 413 commands
- **export** - 48 commands
- **navigation** - 15 commands
- **network** - 49 commands
- **physics** - 43 commands
- **qa_runtime** - 103 commands
- **shaders_vfx** - 66 commands
- **ui_gameplay** - 158 commands
- **xr** - 27 commands

## Commands by module

### 2d / astar_pathfinding_commands (4)

- `create_astar_grid_2d_script`
- `create_astar_point_graph_script`
- `setup_astar_grid_controller`
- `list_astar_pathfinding_tools`

### 2d / canvas_draw_recipe_commands (4)

- `list_canvas_draw_recipes`
- `create_canvas_draw_script`
- `setup_canvas_draw_node`
- `list_canvas_draw_tools`

### 2d / gridmap_commands (8)

- `gridmap_set_cell`
- `gridmap_fill_rect`
- `gridmap_get_cell`
- `gridmap_clear`
- `gridmap_get_used_cells`
- `gridmap_set_mesh_library`
- `gridmap_paint_line`
- `gridmap_get_info`

### 2d / level_design_commands (7)

- `greybox_room`
- `greybox_corridor`
- `place_prop_scatter`
- `stamp_scene_instances`
- `validate_level_playable`
- `level_playtest_route`
- `list_level_design_tools`

### 2d / light_2d_depth_commands (5)

- `setup_canvas_modulate`
- `setup_light_occluder_2d`
- `setup_point_light_2d_node`
- `set_point_light_2d_params`
- `list_light_2d_depth_tools`

### 2d / pixel_2d_preset_commands (6)

- `list_pixel_2d_presets`
- `apply_pixel_2d_project_preset`
- `get_pixel_2d_project_settings`
- `apply_pixel_texture_import_batch`
- `set_canvas_item_texture_filter`
- `list_pixel_2d_tools`

### 2d / tilemap_commands (13)

- `tilemap_set_cell`
- `tilemap_fill_rect`
- `tilemap_get_cell`
- `tilemap_clear`
- `tilemap_get_info`
- `tilemap_get_used_cells`
- `tilemap_set_cells_terrain_connect`
- `tilemap_set_cells_terrain_path`
- `tilemap_erase_rect`
- `tilemap_paint_line`
- `tilemap_paint_cells`
- `used_cells`
- `used_cells`

### 2d / tilemap_layer_stack_commands (6)

- `setup_tilemap_layer`
- `setup_tilemap_layer_stack`
- `list_tilemap_layers`
- `assign_tileset_to_layers`
- `set_tilemap_layer_props`
- `list_tilemap_layer_stack_tools`

### 2d / tileset_atlas_depth_commands (6)

- `tileset_get_atlas_info`
- `tileset_set_atlas_region_size`
- `tileset_create_tiles_in_region`
- `tileset_remove_tiles_in_region`
- `tileset_set_tile_texture_origin`
- `list_tileset_atlas_depth_tools`

### 2d / tileset_commands (19)

- `tileset_create`
- `tileset_add_atlas_source`
- `tileset_get_info`
- `tileset_assign_to_tilemap`
- `tileset_set_tile_collision`
- `tileset_set_tile_modulate`
- `tileset_remove_source`
- `tileset_add_terrain_set`
- `tileset_add_terrain`
- `tileset_set_tile_terrain`
- `tileset_get_terrains`
- `tileset_create_tile`
- `tileset_remove_tile`
- `tileset_list_atlas_tiles`
- `tileset_get_tile_data`
- `tileset_set_tile_z_index`
- `tileset_set_tile_probability`
- `tileset_set_atlas_margins`
- `tileset_create_alternative_tile`

### 2d / tileset_custom_data_commands (5)

- `tileset_add_custom_data_layer`
- `tileset_list_custom_data_layers`
- `tileset_set_tile_custom_data`
- `tileset_get_tile_custom_data`
- `list_tileset_custom_data_tools`

### 2d / tileset_physics_nav_commands (5)

- `tileset_add_physics_layer`
- `tileset_add_navigation_layer`
- `tileset_list_physics_layers`
- `tileset_set_tile_navigation_polygon`
- `list_tileset_physics_nav_tools`

### 2d / tileset_scenes_pattern_commands (11)

- `tileset_add_scenes_collection_source`
- `tileset_add_scene_tile`
- `tileset_list_scene_tiles`
- `tileset_remove_scene_tile`
- `tileset_set_scene_tile_placeholder`
- `tileset_add_pattern_from_cells`
- `tileset_add_pattern_from_rect`
- `tileset_list_patterns`
- `tileset_remove_pattern`
- `tilemap_stamp_pattern`
- `list_tileset_scenes_pattern_tools`

### 2d / tileset_terrain_depth_commands (6)

- `tileset_set_terrain_peering`
- `tileset_set_tiles_terrain_batch`
- `tileset_list_terrain_peering`
- `tilemap_fill_terrain_rect`
- `tilemap_paint_terrain_cells`
- `list_tileset_terrain_depth_tools`

### 3d / scene_3d_commands (23)

- `add_mesh_instance`
- `setup_lighting`
- `set_material_3d`
- `setup_environment`
- `setup_camera_3d`
- `add_gridmap`
- `add_reflection_probe`
- `add_decal`
- `add_voxel_gi`
- `add_lightmap_gi`
- `set_render_layers`
- `setup_csg_box`
- `bake_voxel_gi`
- `request_lightmap_bake`
- `setup_path_3d`
- `setup_csg_sphere`
- `setup_csg_cylinder`
- `add_fog_volume`
- `add_occluder_instance_3d`
- `set_environment_fog`
- `setup_world_environment`
- `setup_compositor`
- `add_compositor_effect`

### 3d / softbody_depth_commands (4)

- `set_soft_body_params`
- `soft_body_pin_point`
- `soft_body_get_info`
- `list_softbody_depth_tools`

### 3d / spring_arm_camera_commands (4)

- `setup_spring_arm_3d`
- `setup_third_person_camera_rig`
- `set_spring_arm_params`
- `list_spring_arm_camera_tools`

### 3d / vehicle_depth_commands (4)

- `setup_vehicle_body`
- `set_vehicle_wheel_params`
- `list_vehicle_wheels`
- `list_vehicle_depth_tools`

### agent / agent_commands (7)

- `health_check`
- `agent_workflow_guide`
- `list_docs_coverage`
- `list_surface_registry`
- `agent_ensure_ready`
- `batch_editor_calls`
- `agent_headless_status`

### agent / agent_pipeline_commands (15)

- `list_agent_pipelines`
- `pipeline_prepare_level_lighting`
- `pipeline_setup_prop_lods`
- `pipeline_nav_debug_route`
- `pipeline_character_locomotion`
- `pipeline_greybox_to_playable`
- `pipeline_2d_pixel_game`
- `pipeline_2d_tilemap_level`
- `pipeline_pre_ship_check`
- `pipeline_3d_character_tps`
- `pipeline_multiplayer_enet`
- `pipeline_game_loop_shell`
- `pipeline_multiplayer_lobby`
- `pipeline_xr_setup`
- `pipeline_export_ci`

### agent / batch_commands (7)

- `find_nodes_by_type`
- `find_signal_connections`
- `batch_set_property`
- `batch_add_nodes`
- `find_node_references`
- `get_scene_dependencies`
- `cross_scene_set_property`

### agent / best_practices_commands (5)

- `analyze_project_best_practices`
- `check_node_naming`
- `check_autoload_hygiene`
- `check_res_path_conventions`
- `list_best_practices_tools`

### agent / compat_commands (8)

- `get_godot_version`
- `get_uid`
- `update_project_uids`
- `load_sprite`
- `export_mesh_library`
- `list_projects`
- `launch_editor`
- `list_mcp_commands`

### agent / discovery_commands (8)

- `list_agent_domains`
- `list_tools_by_domain`
- `search_mcp_tools`
- `get_tool_examples`
- `get_agent_capability_map`
- `list_command_modules`
- `list_command_domains`
- `list_discovery_tools`

### agent / production_commands (5)

- `scaffold_project_defaults`
- `wire_signal_to_new_method`
- `playtest_report`
- `agent_production_status`
- `create_input_map_preset`

### agent / surface_closure_commands (3)

- `list_out_of_scope_surfaces`
- `get_production_surface_report`
- `list_surface_closure_tools`

### animation / animation_commands (36)

- `list_animations`
- `create_animation`
- `remove_animation`
- `rename_animation`
- `duplicate_animation`
- `get_animation_info`
- `set_animation_length`
- `set_animation_loop`
- `ensure_reset_animation`
- `list_animation_libraries`
- `add_animation_library`
- `remove_animation_library`
- `add_animation_track`
- `remove_animation_track`
- `set_animation_keyframe`
- `remove_animation_key`
- `insert_method_key`
- `insert_audio_key`
- `insert_animation_playback_key`
- `set_track_enabled`
- `set_track_interpolation`
- `animation_player_play`
- `animation_player_stop`
- `animation_player_seek`
- `animation_player_queue`
- `animation_player_get_current`
- `animation_player_set_autoplay`
- `animation_player_set_speed`
- `set_root_motion_track`
- `sprite_frames_create`
- `sprite_frames_add_animation`
- `sprite_frames_add_frame`
- `sprite_frames_assign`
- `set_bezier_key`
- `get_bezier_key_info`
- `apply_bone_map_to_skeleton`

### animation / animation_library_commands (9)

- `create_animation_library_resource`
- `animation_library_add_clip`
- `animation_library_list_clips`
- `animation_library_rename_clip`
- `animation_library_remove_clip`
- `animation_library_merge_from_player`
- `animation_library_assign_to_player`
- `animation_library_import_from_scene`
- `list_animation_library_tools`

### animation / animation_player_depth_commands (7)

- `set_animation_player_autoplay`
- `set_animation_player_speed`
- `list_animation_player_libraries`
- `assign_animation_library`
- `get_animation_player_status`
- `animation_player_stop`
- `list_animation_player_depth_tools`

### animation / animation_transfer_commands (24)

- `dump_animation`
- `list_animation_tracks`
- `get_track_keys`
- `sample_animation_at_time`
- `compare_animations`
- `copy_animation_to_player`
- `copy_animation_track`
- `remap_animation_track_paths`
- `set_animation_track_path`
- `scale_animation_time`
- `offset_animation_keys`
- `crop_animation`
- `clear_animation_track_keys`
- `save_animation_resource`
- `load_animation_resource`
- `extract_animations_from_scene`
- `apply_example_animation`
- `list_animation_fine_tune_tools`
- `type_name`
- `value`
- `track`
- `type_name`
- `type`
- `type`

### animation / animation_tree_commands (20)

- `create_animation_tree`
- `get_animation_tree_structure`
- `set_animation_tree_active`
- `set_animation_tree_player`
- `add_state_machine_state`
- `remove_state_machine_state`
- `add_state_machine_transition`
- `remove_state_machine_transition`
- `set_state_machine_transition`
- `set_state_machine_start`
- `travel_animation_state`
- `get_animation_tree_playback`
- `set_blend_tree_node`
- `remove_blend_tree_node`
- `connect_blend_tree_nodes`
- `add_blend_space_point`
- `remove_blend_space_point`
- `set_blend_space_point_position`
- `set_tree_parameter`
- `list_tree_parameters`

### animation / animation_tree_graph_commands (10)

- `set_state_machine_node_position`
- `set_state_animation`
- `list_state_machine_transitions`
- `get_blend_tree_connections`
- `disconnect_blend_tree_nodes`
- `create_simple_locomotion_tree`
- `create_blend_space_1d_locomotion`
- `export_animation_tree_graph`
- `list_animation_tree_graph_tools`
- `root`

### animation / humanoid_commands (6)

- `setup_humanoid_actor`
- `bind_interaction`
- `apply_locomotion_set`
- `validate_humanoid_rig`
- `create_bone_map_preset`
- `list_humanoid_recipes`

### animation / ragdoll_commands (5)

- `generate_ragdoll_from_skeleton`
- `list_physical_bones`
- `set_physical_bone_params`
- `create_ragdoll_control_script`
- `list_ragdoll_tools`

### animation / retarget_pipeline_commands (3)

- `pipeline_character_from_gltf`
- `pipeline_retarget_animations`
- `list_retarget_pipeline_tools`

### animation / skeleton_2d_commands (24)

- `find_skeletons_2d`
- `setup_skeleton_2d`
- `add_bone_2d`
- `list_bones_2d`
- `get_bone_2d_info`
- `set_bone_2d_rest`
- `apply_bone_2d_rest`
- `apply_all_bone_2d_rests`
- `set_bone_2d_pose`
- `set_bone_2d_length`
- `setup_modification_stack_2d`
- `setup_two_bone_ik_2d`
- `set_two_bone_ik_2d_target`
- `setup_fabrik_ik_2d`
- `list_modification_stack_2d`
- `set_bone_2d_local_pose_override`
- `list_skeleton_2d_tools`
- `rest`
- `rest`
- `rest`
- `skeleton_rest`
- `transform`
- `transform`
- `pose`

### animation / skeleton_commands (19)

- `find_skeletons`
- `list_skeleton_bones`
- `get_bone_info`
- `set_bone_pose`
- `reset_bone_pose`
- `reset_all_bone_poses`
- `find_bone`
- `get_skeleton_rest`
- `create_bone_map`
- `get_bone_map_info`
- `set_bone_map_mapping`
- `auto_map_bones_by_name`
- `add_bone_attachment`
- `list_skeleton_profile_bones`
- `rest`
- `pose`
- `global_pose`
- `rest`
- `mapped_count`

### animation / skeleton_ik_commands (4)

- `setup_skeleton_ik`
- `set_skeleton_ik_target`
- `setup_look_at_modifier`
- `list_skeleton_ik_tools`

### animation / spring_bone_commands (3)

- `setup_spring_bone_simulator`
- `spring_bone_add_chain`
- `list_spring_bone_tools`

### assets / compositor_depth_commands (4)

- `setup_compositor_on_environment`
- `compositor_list_effects`
- `compositor_clear_effects`
- `list_compositor_depth_tools`

### assets / csg_ops_commands (6)

- `csg_set_operation`
- `csg_set_use_collision`
- `csg_get_info`
- `csg_bake_to_mesh_instance`
- `csg_list_shapes`
- `list_csg_tools`

### assets / decal_depth_commands (3)

- `setup_decal_3d`
- `set_decal_params`
- `list_decal_depth_tools`

### assets / environment_sky_commands (7)

- `create_environment_resource`
- `create_procedural_sky`
- `create_panorama_sky`
- `assign_environment_to_world`
- `setup_fog_volume`
- `set_environment_fog_params`
- `list_environment_sky_tools`

### assets / font_label_settings_commands (5)

- `create_font_file_resource`
- `create_label_settings`
- `assign_label_settings`
- `set_label_font_size`
- `list_font_label_tools`

### assets / import_3d_commands (11)

- `list_imported_scene_contents`
- `extract_meshes_from_scene`
- `extract_materials_from_scene`
- `instance_scene_as_inherited`
- `pack_mesh_library_from_scene`
- `create_scene_from_gltf`
- `set_gltf_import_flags`
- `set_fbx_import_flags`
- `list_scene_import_options`
- `apply_scene_import_advanced`
- `list_3d_import_tools`

### assets / import_commands (15)

- `reimport_files`
- `wait_for_import`
- `get_import_info`
- `set_import_option`
- `set_import_options`
- `apply_texture_import_preset`
- `apply_scene_import_preset`
- `create_atlas_texture`
- `list_import_presets`
- `scan_filesystem`
- `is_filesystem_scanning`
- `get_filesystem_hash`
- `ensure_imported`
- `import_paths`
- `stage_files_into_res`

### assets / import_schema_commands (5)

- `list_import_option_schema`
- `list_import_types`
- `apply_import_schema_preset`
- `get_import_options_for_path`
- `list_import_schema_tools`

### assets / lightmap_uv_commands (5)

- `mesh_lightmap_unwrap`
- `mesh_has_uv2`
- `batch_prepare_lightmap_meshes`
- `lightmap_bake_prepare`
- `list_lightmap_uv_tools`

### assets / lod_commands (6)

- `mesh_generate_lods`
- `mesh_get_lod_info`
- `set_visibility_range`
- `setup_lod_mesh_instances`
- `create_shadow_mesh`
- `list_lod_tools`

### assets / material_2d_commands (12)

- `set_canvas_item_modulate`
- `set_canvas_item_self_modulate`
- `set_canvas_item_visibility`
- `set_sprite_texture`
- `set_sprite_region`
- `create_canvas_item_material`
- `assign_canvas_item_material`
- `set_label_text`
- `set_button_text`
- `setup_label`
- `setup_button`
- `setup_texture_rect`

### assets / material_3d_depth_commands (5)

- `create_standard_material_3d`
- `create_orm_material_3d`
- `set_standard_material_params`
- `assign_material_3d_to_mesh`
- `list_material_3d_depth_tools`

### assets / mesh_2d_commands (8)

- `setup_mesh_instance_2d`
- `create_quad_mesh_2d`
- `create_array_mesh_2d`
- `assign_mesh_2d`
- `set_mesh_instance_2d_texture`
- `convert_sprite_to_mesh_instance_2d`
- `setup_multimesh_instance_2d`
- `list_mesh_2d_tools`

### assets / mesh_collision_commands (7)

- `mesh_create_trimesh_collision`
- `mesh_create_convex_collision`
- `mesh_create_multiple_convex_collisions`
- `mesh_create_trimesh_static_body`
- `mesh_create_convex_static_body`
- `add_collision_shape_from_mesh`
- `list_mesh_collision_tools`

### assets / modern_render_commands (6)

- `apply_environment_preset`
- `setup_camera_follow_2d`
- `setup_third_person_camera`
- `setup_orbit_camera_3d`
- `create_minimap_viewport`
- `list_render_presets`

### assets / multimesh_commands (4)

- `setup_multimesh_instance`
- `multimesh_set_transforms`
- `multimesh_scatter`
- `multimesh_get_info`

### assets / occlusion_culling_commands (4)

- `setup_occluder_instance_3d`
- `set_occlusion_culling_project`
- `create_box_occluder_3d`
- `list_occlusion_culling_tools`

### assets / quality_preset_commands (5)

- `list_quality_presets`
- `apply_lod_distance_preset`
- `apply_lightmap_quality_preset`
- `configure_lightmap_gi`
- `apply_platform_render_pack`

### assets / render_gi_commands (7)

- `configure_sdfgi`
- `configure_ssao`
- `configure_ssr`
- `configure_glow`
- `configure_ssil`
- `set_mesh_lightmap_params`
- `list_gi_tools`

### assets / resource_commands (6)

- `read_resource`
- `edit_resource`
- `create_resource`
- `get_resource_preview`
- `create_custom_resource_script`
- `duplicate_resource`

### assets / resource_format_commands (5)

- `save_resource_as`
- `convert_resource_format`
- `duplicate_resource_to`
- `get_resource_info`
- `list_resource_format_tools`

### assets / resource_graph_commands (6)

- `list_resource_dependencies`
- `find_files_referencing`
- `remap_resource_references`
- `list_orphaned_resources`
- `validate_scene_dependencies`
- `list_resource_graph_tools`

### assets / resource_preload_commands (4)

- `create_resource_registry_script`
- `write_preload_manifest`
- `validate_preload_manifest`
- `list_resource_preload_tools`

### assets / resource_unique_commands (4)

- `make_resource_unique`
- `set_resource_local_to_scene`
- `duplicate_subresource_on_node`
- `list_resource_unique_tools`

### assets / shape_resource_commands (6)

- `create_shape_resource`
- `list_shape_resource_types`
- `assign_shape_to_collision`
- `setup_collision_from_shape_resource`
- `batch_create_shape_resources`
- `list_shape_resource_tools`

### assets / structure_3d_commands (7)

- `setup_visible_on_screen_notifier`
- `setup_visible_on_screen_enabler`
- `setup_remote_transform`
- `setup_world_boundary_body`
- `setup_occluder_instance`
- `setup_marker_3d`
- `list_structure_3d_tools`

### assets / terrain_mesh_commands (4)

- `create_heightmap_terrain`
- `create_plane_mesh_terrain`
- `terrain_apply_height_noise`
- `list_terrain_tools`

### assets / texture_commands (4)

- `create_gradient_texture`
- `create_noise_texture`
- `create_placeholder_texture`
- `create_curve_texture`

### audio / audio_bus_effect_depth_commands (6)

- `list_audio_bus_effect_types`
- `add_audio_bus_effect_typed`
- `set_audio_bus_effect_params`
- `list_audio_bus_effects`
- `remove_audio_bus_effect_at`
- `list_audio_bus_effect_depth_tools`

### audio / audio_commands (15)

- `get_audio_bus_layout`
- `add_audio_bus`
- `set_audio_bus`
- `add_audio_bus_effect`
- `add_audio_player`
- `get_audio_info`
- `remove_audio_bus`
- `save_audio_bus_layout`
- `load_audio_bus_layout`
- `set_audio_player_stream`
- `set_audio_player_props`
- `setup_audio_stream_player_2d`
- `setup_audio_stream_player_3d`
- `set_bus_volume_db`
- `remove_audio_bus_effect`

### audio / audio_generator_commands (4)

- `setup_audio_stream_generator`
- `create_tone_generator_script`
- `create_audio_bus_layout_preset`
- `list_audio_generator_tools`

### audio / audio_polyphony_commands (4)

- `setup_polyphonic_player`
- `set_audio_player_polyphony`
- `create_sfx_pool_script`
- `list_audio_polyphony_tools`

### audio / music_commands (4)

- `create_music_controller_script`
- `setup_music_player`
- `music_set_playlist`
- `list_music_tools`

### core / ai_system_commands (8)

- `setup_ai_agent_2d`
- `setup_ai_agent_3d`
- `create_chase_ai_script`
- `create_patrol_ai_script`
- `setup_detection_area`
- `create_gameplay_state_machine_script`
- `create_interactable_script`
- `list_ai_templates`

### core / async_resource_commands (5)

- `create_async_resource_loader_script`
- `resource_load_threaded_request`
- `resource_load_threaded_status`
- `resource_load_threaded_get`
- `list_async_resource_tools`

### core / autoload_depth_commands (5)

- `list_autoloads`
- `remove_autoload`
- `set_autoload`
- `rename_autoload`
- `list_autoload_depth_tools`

### core / behavior_tree_commands (6)

- `create_behavior_tree_runtime_script`
- `create_behavior_tree_resource`
- `create_behavior_tree_runner_script`
- `create_blackboard_script`
- `setup_behavior_tree_on_node`
- `list_behavior_tree_recipes`

### core / camera_depth_commands (6)

- `setup_camera_2d`
- `setup_camera_3d_node`
- `set_camera_2d_limits`
- `set_camera_3d_params`
- `camera_make_current`
- `list_camera_depth_tools`

### core / camera_level_bounds_commands (4)

- `set_camera_2d_limits_rect`
- `set_camera_2d_limits_from_tilemap`
- `set_camera_2d_limits_from_node_bounds`
- `list_camera_level_bounds_tools`

### core / character_system_commands (10)

- `setup_character_2d`
- `setup_character_3d`
- `create_platformer_controller_script`
- `create_topdown_controller_script`
- `create_fps_controller_script`
- `create_health_component_script`
- `setup_hitbox`
- `setup_hurtbox`
- `create_projectile_script`
- `list_character_templates`

### core / class_commands (17)

- `describe_class`
- `list_classes`
- `get_class_inheritance`
- `list_class_methods`
- `list_class_signals`
- `list_class_properties`
- `list_class_constants`
- `class_has_method`
- `get_global_class_list`
- `inheritance`
- `methods`
- `signals`
- `properties`
- `chain`
- `methods`
- `signals`
- `properties`

### core / classdb_examples_commands (4)

- `get_class_usage_examples`
- `list_instantiateable_classes`
- `suggest_class_for_task`
- `list_classdb_examples_tools`

### core / csharp_commands (16)

- `get_csharp_project_info`
- `create_csharp_script`
- `list_csharp_scripts`
- `ensure_csharp_csproj`
- `set_dotnet_project_settings`
- `attach_csharp_script`
- `run_dotnet_build`
- `run_godot_csharp_build`
- `get_last_build_log`
- `create_csharp_node_script`
- `check_dotnet_sdk`
- `list_csharp_partial_classes`
- `errors`
- `warnings`
- `errors`
- `warnings`

### core / curve_commands (21)

- `create_curve_resource`
- `curve_set_points`
- `curve_get_points`
- `curve_sample`
- `curve_sample_baked`
- `create_curve2d_resource`
- `create_curve3d_resource`
- `curve2d_set_points`
- `curve2d_get_points`
- `curve2d_sample_polyline`
- `curve3d_set_points`
- `curve3d_get_points`
- `curve3d_sample_polyline`
- `path_get_curve_points`
- `path_set_curve_points`
- `bezier_list_keys_cartesian`
- `bezier_set_keys_batch`
- `bezier_sample_dense`
- `bezier_remove_key`
- `bezier_set_handle_mode`
- `list_curve_sdk_tools`

### core / display_window_commands (5)

- `get_display_info`
- `set_window_project_settings`
- `set_window_mode_live`
- `list_screens`
- `list_display_window_tools`

### core / editor_clipboard_commands (5)

- `clipboard_set_text`
- `clipboard_get_text`
- `duplicate_nodes`
- `copy_node_path_to_clipboard`
- `list_editor_clipboard_tools`

### core / editor_commands (19)

- `get_editor_errors`
- `get_output_log`
- `get_editor_screenshot`
- `get_game_screenshot`
- `execute_editor_script`
- `clear_output`
- `reload_plugin`
- `reload_project`
- `get_signals`
- `compare_screenshots`
- `set_auto_dismiss`
- `get_editor_camera`
- `set_editor_camera`
- `open_path_in_filesystem`
- `edit_resource_path`
- `open_script_in_editor`
- `get_open_scripts_info`
- `set_main_screen`
- `distraction_free_mode`

### core / editor_workspace_commands (11)

- `play_main_scene`
- `play_current_scene`
- `play_custom_scene`
- `get_editor_workspace_info`
- `set_editor_3d_snap`
- `list_open_scenes`
- `close_scene`
- `save_all_scenes`
- `list_resources_by_type`
- `duplicate_scene_file`
- `list_editor_workspace_tools`

### core / engine_runtime_info_commands (6)

- `get_engine_info`
- `get_os_info`
- `get_time_info`
- `get_project_feature_tags`
- `get_agent_environment_report`
- `list_engine_runtime_info_tools`

### core / expression_eval_commands (3)

- `evaluate_expression`
- `evaluate_expression_on_node`
- `list_expression_eval_tools`

### core / filesystem_commands (8)

- `res_copy_file`
- `res_delete_path`
- `res_rename_path`
- `res_make_dir`
- `res_file_exists`
- `res_list_dir`
- `res_read_text`
- `res_write_text`

### core / group_layer_commands (8)

- `list_project_groups`
- `set_physics_layer_names`
- `get_physics_layer_names`
- `set_render_layer_names`
- `get_render_layer_names`
- `find_nodes_in_group`
- `batch_set_node_groups`
- `list_group_layer_tools`

### core / input_commands (5)

- `simulate_key`
- `simulate_mouse_click`
- `simulate_mouse_move`
- `simulate_action`
- `simulate_sequence`

### core / input_map_commands (6)

- `get_input_actions`
- `set_input_action`
- `remove_input_action`
- `list_input_action_events`
- `add_input_action_event`
- `clear_input_action_events`

### core / input_map_io_commands (5)

- `export_input_map_json`
- `import_input_map_json`
- `list_input_map_actions_detail`
- `clear_input_action_events`
- `list_input_map_io_tools`

### core / input_record_commands (3)

- `write_input_replay_manifest`
- `run_input_replay_manifest`
- `list_input_record_tools`

### core / interaction_zone_commands (5)

- `setup_interaction_zone`
- `setup_interaction_prompt_ui`
- `create_interaction_controller_script`
- `bind_interaction_action`
- `list_interaction_zone_tools`

### core / io_commands (8)

- `config_file_get`
- `config_file_set`
- `json_read`
- `json_write`
- `user_list_dir`
- `user_read_text`
- `user_write_text`
- `user_delete_path`

### core / joypad_commands (7)

- `list_joypads`
- `create_joypad_input_map_preset`
- `add_joypad_binding`
- `set_action_deadzone`
- `get_action_strength_info`
- `list_joypad_button_names`
- `event`

### core / migration_commands (4)

- `scan_godot3_patterns`
- `list_migration_replacements`
- `apply_migration_replacements`
- `get_migration_guide`

### core / migration_depth_commands (7)

- `list_migration_replacements_extended`
- `scan_project_migration_report`
- `scan_tscn_godot3_markers`
- `get_migration_out_of_scope`
- `list_migration_depth_tools`
- `replacements`
- `count`

### core / node_commands (35)

- `add_node`
- `delete_node`
- `duplicate_node`
- `move_node`
- `update_property`
- `update_properties`
- `get_property`
- `list_property_info`
- `search_properties`
- `reset_property`
- `inspect_node`
- `list_node_methods`
- `call_node_method`
- `clear_property`
- `get_node_properties`
- `add_resource`
- `remove_resource`
- `set_anchor_preset`
- `rename_node`
- `connect_signal`
- `disconnect_signal`
- `get_node_groups`
- `set_node_groups`
- `find_nodes_in_group`
- `get_editor_selection`
- `select_nodes`
- `clear_editor_selection`
- `get_meta`
- `set_meta`
- `remove_meta`
- `list_meta`
- `set_nodes_transform`
- `batch_update_property`
- `nodes`
- `selected`

### core / node_query_commands (6)

- `find_nodes_by_class`
- `find_nodes_by_script`
- `find_nodes_by_name_pattern`
- `count_nodes_by_class`
- `reorder_node`
- `list_node_query_tools`

### core / path_follow_commands (5)

- `setup_path_follow`
- `path_follow_set_progress`
- `path_follow_get_info`
- `path_follow_set_loop`
- `list_path_follow_tools`

### core / project_commands (24)

- `get_project_info`
- `get_filesystem_tree`
- `search_files`
- `search_in_files`
- `get_project_settings`
- `set_project_setting`
- `get_project_setting`
- `set_project_settings`
- `clear_project_setting`
- `has_project_setting`
- `search_project_settings`
- `get_project_feature_list`
- `set_project_feature`
- `uid_to_project_path`
- `project_path_to_uid`
- `add_autoload`
- `remove_autoload`
- `list_autoloads`
- `set_window_settings`
- `set_physics_ticks`
- `list_project_settings_keys`
- `set_layer_names`
- `get_layer_names`
- `value`

### core / project_settings_bulk_commands (4)

- `list_project_settings_by_prefix`
- `batch_set_project_settings`
- `get_project_settings_snapshot`
- `list_project_settings_bulk_tools`

### core / save_game_state_commands (8)

- `capture_node_state`
- `capture_scene_state`
- `apply_node_state`
- `create_game_state_serializer_script`
- `write_save_slot_json`
- `read_save_slot_json`
- `list_save_slots_json`
- `list_save_game_state_tools`

### core / scene_2d_commands (17)

- `setup_camera_2d`
- `setup_parallax_background`
- `add_parallax_layer`
- `add_light_occluder_2d`
- `setup_point_light_2d`
- `setup_canvas_modulate`
- `setup_world_environment_2d`
- `setup_line_2d`
- `setup_path_2d`
- `setup_polygon_2d`
- `set_y_sort_enabled`
- `setup_canvas_layer`
- `setup_directional_light_2d`
- `setup_timer`
- `setup_remote_transform_2d`
- `setup_visible_on_screen_notifier_2d`
- `add_camera_shake_to_camera2d`

### core / scene_audit_commands (5)

- `list_scene_signals`
- `list_missing_scripts`
- `validate_all_scenes`
- `audit_scene_tree`
- `list_scene_audit_tools`

### core / scene_commands (10)

- `get_scene_tree`
- `get_scene_file_content`
- `create_scene`
- `open_scene`
- `delete_scene`
- `add_scene_instance`
- `play_scene`
- `stop_scene`
- `save_scene`
- `get_scene_exports`

### core / scene_flow_commands (4)

- `create_scene_transition_script`
- `create_loading_screen_scene`
- `list_scene_flow_recipes`
- `set_main_scene`

### core / scene_flow_depth_commands (5)

- `set_scene_tree_paused_state`
- `create_game_flow_controller_script`
- `setup_main_menu_scene`
- `create_pause_menu_controller_script`
- `list_scene_flow_depth_tools`

### core / scene_instance_depth_commands (7)

- `set_editable_instance`
- `get_instance_info`
- `setup_instance_placeholder`
- `make_scene_instance_local`
- `instance_packed_scene`
- `batch_set_owners`
- `list_scene_instance_tools`

### core / scene_pack_commands (5)

- `pack_node_as_scene`
- `pack_selection_as_scene`
- `create_inherited_scene_from`
- `replace_node_with_scene_instance`
- `list_scene_pack_tools`

### core / scene_stream_commands (6)

- `create_stream_manager_script`
- `stream_load_chunk`
- `stream_unload_chunk`
- `stream_list_chunks`
- `stream_set_chunk_active`
- `list_stream_tools`

### core / scene_unique_commands (4)

- `set_scene_unique_name`
- `get_scene_unique_name`
- `find_node_by_unique_name`
- `list_scene_unique_names`

### core / scene_unique_depth_commands (4)

- `batch_set_scene_unique_names`
- `find_node_by_unique_name`
- `list_scene_unique_names`
- `list_scene_unique_depth_tools`

### core / script_commands (7)

- `list_scripts`
- `read_script`
- `create_script`
- `edit_script`
- `attach_script`
- `get_open_scripts`
- `validate_script`

### core / sprite_frames_depth_commands (7)

- `sprite_frames_get_info`
- `sprite_frames_set_animation_speed`
- `sprite_frames_set_animation_loop`
- `sprite_frames_remove_frame`
- `sprite_frames_clear_animation`
- `sprite_frames_rename_animation`
- `list_sprite_frames_depth_tools`

### core / subviewport_render_commands (7)

- `setup_subviewport_container`
- `setup_subviewport_2d_world`
- `setup_viewport_texture_rect`
- `setup_sprite_from_subviewport`
- `setup_back_buffer_copy`
- `set_subviewport_update_mode`
- `list_subviewport_render_tools`

### core / timer_tween_depth_commands (4)

- `setup_timer`
- `setup_scene_tree_timer_script`
- `create_tween_recipe_script`
- `list_timer_tween_tools`

### core / tween_commands (3)

- `create_tween_helper_script`
- `list_tween_recipes`
- `create_scene_tree_tween_snippet`

### core / utility_ai_commands (4)

- `create_utility_ai_script`
- `create_goap_planner_script`
- `create_blackboard_utility_script`
- `list_utility_ai_tools`

### core / utility_node_commands (10)

- `setup_spring_arm_3d`
- `setup_remote_transform_3d`
- `setup_visible_on_screen_notifier_3d`
- `setup_marker_2d`
- `setup_marker_3d`
- `setup_ray_cast_query_script`
- `list_groups_in_scene`
- `add_node_to_group`
- `remove_node_from_group`
- `create_state_machine_script`

### core / viewport_focus_commands (5)

- `editor_focus_node`
- `editor_frame_selection`
- `editor_get_3d_camera`
- `editor_set_3d_camera_transform`
- `list_viewport_focus_tools`

### export / android_commands (3)

- `list_android_devices`
- `get_android_preset_info`
- `deploy_to_android`

### export / export_ci_commands (6)

- `list_export_ci_templates`
- `create_github_actions_godot_export`
- `create_export_presets_pack`
- `create_headless_export_script`
- `write_export_ci_readme`
- `list_export_ci_tools`

### export / export_commands (16)

- `list_export_presets`
- `export_project`
- `run_export`
- `get_export_info`
- `create_export_preset`
- `set_export_preset_option`
- `remove_export_preset`
- `get_export_preset`
- `set_export_filters`
- `export_and_verify`
- `list_export_templates`
- `duplicate_export_preset`
- `verify_export_ready`
- `get_export_template_guide`
- `get_export_templates_path`
- `has_matching_template`

### export / export_signing_commands (5)

- `get_export_signing_checklist`
- `configure_android_keystore`
- `get_android_signing_status`
- `set_export_preset_signing_options`
- `list_export_signing_tools`

### export / gdextension_commands (6)

- `create_gdextension_project`
- `list_gdextension_files`
- `get_gdextension_info`
- `run_gdextension_scons_build`
- `clone_godot_cpp`
- `setup_gdextension_full`

### export / ios_platform_commands (5)

- `get_ios_export_checklist`
- `get_platform_export_matrix`
- `create_ios_export_notes`
- `ensure_ios_export_preset`
- `list_ios_platform_tools`

### export / plugin_packaging_commands (5)

- `validate_editor_plugin_cfg`
- `list_addon_folders`
- `package_addon_folder`
- `create_plugin_readme`
- `list_plugin_packaging_tools`

### export / plugin_scaffold_commands (2)

- `create_editor_plugin`
- `list_project_plugins`

### navigation / nav_debug_commands (7)

- `navigation_set_debug_enabled`
- `navigation_get_debug_settings`
- `navigation_query_path`
- `draw_debug_path`
- `navigation_get_map_info`
- `navigation_live_path`
- `list_nav_debug_tools`

### navigation / navigation_commands (8)

- `setup_navigation_region`
- `bake_navigation_mesh`
- `setup_navigation_agent`
- `set_navigation_layers`
- `get_navigation_info`
- `setup_navigation_link`
- `setup_navigation_obstacle`
- `set_navigation_agent_target`

### network / http_io_commands (6)

- `create_http_client_script`
- `setup_http_request_node`
- `create_encrypted_save_script`
- `encrypted_file_write`
- `encrypted_file_read`
- `list_http_io_tools`

### network / multiplayer_commands (10)

- `setup_multiplayer_spawner`
- `setup_multiplayer_synchronizer`
- `get_multiplayer_info`
- `set_multiplayer_authority`
- `add_spawnable_scene`
- `add_replication_property`
- `create_multiplayer_template_script`
- `set_multiplayer_project_settings`
- `setup_http_request`
- `list_rpc_config`

### network / multiplayer_interest_commands (5)

- `create_interest_manager_script`
- `setup_multiplayer_visibility_filter`
- `set_synchronizer_replication_interval`
- `configure_multiplayer_spawner_limits`
- `list_multiplayer_interest_tools`

### network / multiplayer_lobby_depth_commands (6)

- `create_multiplayer_lobby_script`
- `create_player_spawn_service_script`
- `setup_spawn_points`
- `list_spawn_points`
- `create_network_clock_script`
- `list_multiplayer_lobby_depth_tools`

### network / multiplayer_peer_commands (4)

- `create_enet_multiplayer_script`
- `create_multiplayer_bootstrap_script`
- `setup_multiplayer_spawner_basic`
- `list_multiplayer_peer_tools`

### network / multiplayer_runtime_commands (6)

- `create_multiplayer_lobby_ui`
- `create_multiplayer_game_manager_script`
- `create_websocket_multiplayer_template`
- `setup_multiplayer_player_scene`
- `setup_multiplayer_spawn_stack`
- `list_multiplayer_recipes`

### network / multiplayer_sync_depth_commands (5)

- `configure_multiplayer_synchronizer`
- `add_replication_properties_bulk`
- `list_replication_config`
- `set_rpc_config_on_node`
- `list_multiplayer_sync_depth_tools`

### network / webrtc_multiplayer_commands (7)

- `create_webrtc_multiplayer_template`
- `create_signaling_server_script`
- `create_matchmaking_client_script`
- `create_input_buffer_netcode_script`
- `create_lag_compensation_helper_script`
- `create_webrtc_ice_config_script`
- `list_webrtc_recipes`

### physics / character_body_depth_commands (4)

- `set_character_body_motion`
- `get_character_body_info`
- `apply_character_body_preset`
- `list_character_body_depth_tools`

### physics / collision_layer_bit_commands (5)

- `set_collision_layers_by_name`
- `set_collision_mask_by_name`
- `get_collision_layers_named`
- `resolve_layer_names_to_mask`
- `list_collision_layer_bit_tools`

### physics / joint_limit_commands (6)

- `set_pin_joint_params`
- `set_hinge_joint_limits`
- `set_slider_joint_limits`
- `set_generic_6dof_joint_limits`
- `get_joint_info`
- `list_joint_limit_tools`

### physics / physics_commands (18)

- `setup_collision`
- `set_physics_layers`
- `get_physics_layers`
- `add_raycast`
- `add_shape_cast`
- `setup_physics_body`
- `get_collision_info`
- `setup_area`
- `set_area_monitoring`
- `setup_joint`
- `set_physics_material`
- `create_physics_body`
- `add_vehicle_wheel`
- `setup_soft_body`
- `add_physical_bone`
- `setup_physical_bone_simulator`
- `collision_layer_info`
- `collision_mask_info`

### physics / physics_debug_commands (7)

- `set_collision_debug_visible`
- `get_physics_debug_settings`
- `editor_raycast`
- `list_physics_shapes_in_scene`
- `list_physics_debug_tools`
- `position`
- `normal`

### physics / physics_material_resource_commands (3)

- `create_physics_material`
- `assign_physics_material`
- `list_physics_material_tools`

### qa_runtime / analysis_commands (6)

- `find_unused_resources`
- `analyze_signal_flow`
- `analyze_scene_complexity`
- `find_script_references`
- `detect_circular_dependencies`
- `get_project_statistics`

### qa_runtime / debugger_commands (11)

- `debugger_get_status`
- `debugger_continue`
- `debugger_step_over`
- `debugger_step_into`
- `debugger_step_out`
- `list_source_breakpoints`
- `set_source_breakpoint`
- `remove_source_breakpoint`
- `open_script_at_line`
- `list_debugger_errors`
- `set_debug_project_settings`

### qa_runtime / debugger_intel_commands (5)

- `analyze_debugger_errors`
- `get_fix_plan_from_errors`
- `open_error_source`
- `list_debugger_intel_tools`
- `category`

### qa_runtime / media_commands (6)

- `media_find_ffmpeg`
- `media_frames_to_video`
- `media_extract_keyframes`
- `media_clip_video`
- `media_contact_sheet`
- `media_probe`

### qa_runtime / movie_maker_commands (6)

- `set_movie_maker_enabled`
- `get_movie_maker_settings`
- `set_movie_maker_output`
- `play_with_movie_maker`
- `capture_play_session`
- `list_movie_maker_tools`

### qa_runtime / performance_budget_commands (4)

- `analyze_performance_budget`
- `set_performance_budget_thresholds`
- `get_performance_budget_thresholds`
- `list_performance_budget_tools`

### qa_runtime / playtest_fix_commands (4)

- `playtest_fix_loop`
- `diagnose_playtest_failure`
- `assert_scene_playable`
- `list_playtest_fix_tools`

### qa_runtime / playtest_loop_commands (2)

- `playtest_sequence`
- `list_playtest_loop_tools`

### qa_runtime / profiling_commands (9)

- `get_performance_monitors`
- `get_editor_performance`
- `capture_performance_sample`
- `capture_performance_timeline`
- `get_render_info`
- `list_performance_monitor_names`
- `export_performance_report`
- `get_gpu_profiling_hints`
- `editor_snapshot`

### qa_runtime / run_session_commands (15)

- `run_session_start`
- `run_session_stop`
- `run_session_status`
- `run_record_start`
- `run_record_stop`
- `run_log_event`
- `run_get_events`
- `run_get_logs`
- `run_capture_timeline`
- `run_find_nodes`
- `run_probe_report`
- `run_ping_runtime`
- `ensure_runtime_autoloads`
- `set_runtime_token`
- `get_runtime_info`

### qa_runtime / runtime_commands (19)

- `get_game_scene_tree`
- `get_game_node_properties`
- `set_game_node_property`
- `capture_frames`
- `monitor_properties`
- `execute_game_script`
- `start_recording`
- `stop_recording`
- `replay_recording`
- `find_nodes_by_script`
- `get_autoload`
- `batch_get_properties`
- `find_ui_elements`
- `click_button_by_text`
- `wait_for_node`
- `find_nearby_nodes`
- `navigate_to`
- `move_to`
- `watch_signals`

### qa_runtime / runtime_systems_commands (7)

- `create_game_logger_script`
- `create_achievement_manager_script`
- `create_day_night_cycle_script`
- `create_feature_flags_script`
- `create_accessibility_settings_script`
- `create_websocket_client_script`
- `list_runtime_systems_tools`

### qa_runtime / test_commands (5)

- `run_test_scenario`
- `assert_node_state`
- `assert_screen_text`
- `run_stress_test`
- `get_test_report`

### qa_runtime / test_framework_commands (4)

- `detect_test_frameworks`
- `run_gut_tests`
- `run_gdunit_tests`
- `list_test_recipes`

### shaders_vfx / particle_commands (11)

- `create_particles`
- `set_particle_material`
- `set_particle_color_gradient`
- `apply_particle_preset`
- `get_particle_info`
- `set_particle_emitting`
- `set_particle_amount`
- `set_particle_trail`
- `set_particle_subemitter`
- `set_particle_collision`
- `add_gpu_particles_collision`

### shaders_vfx / particle_depth_commands (8)

- `set_particle_process_params`
- `set_particle_emission_shape`
- `set_particle_turbulence`
- `set_particle_draw_pass`
- `add_gpu_particles_attractor`
- `create_cpu_particles`
- `restart_particles`
- `list_particle_depth_tools`

### shaders_vfx / shader_commands (9)

- `create_shader`
- `read_shader`
- `edit_shader`
- `assign_shader_material`
- `set_shader_param`
- `get_shader_params`
- `set_shader_global`
- `get_shader_global`
- `list_shader_globals`

### shaders_vfx / shader_include_commands (5)

- `create_shader_include`
- `list_shader_includes`
- `shader_add_include`
- `create_shader_include_library_preset`
- `list_shader_include_tools`

### shaders_vfx / vfx_shader_commands (10)

- `create_shader_preset`
- `list_shader_presets`
- `apply_canvas_shader_to_node`
- `apply_spatial_shader_to_mesh`
- `setup_trail_vfx`
- `setup_flash_hurt_vfx`
- `setup_screen_fade_overlay`
- `create_dissolve_shader`
- `create_outline_shader`
- `create_hit_stop_script`

### shaders_vfx / visual_shader_catalog_commands (8)

- `list_visual_shader_node_catalog`
- `visual_shader_add_nodes_batch`
- `visual_shader_preset_toon`
- `visual_shader_preset_emission_pulse`
- `visual_shader_preset_scroll_uv`
- `visual_shader_preset_triplanar`
- `visual_shader_preset_outline_fresnel`
- `list_visual_shader_catalog_tools`

### shaders_vfx / visual_shader_commands (7)

- `create_visual_shader`
- `visual_shader_add_node`
- `visual_shader_connect`
- `visual_shader_set_node_property`
- `visual_shader_get_info`
- `assign_visual_shader_material`
- `visual_shader_add_preset_fresnel`

### shaders_vfx / visual_shader_preset_commands (8)

- `visual_shader_add_preset_pbr`
- `visual_shader_add_preset_unshaded_color`
- `visual_shader_add_preset_dissolve`
- `visual_shader_list_node_types`
- `list_visual_shader_preset_tools`
- `time`
- `threshold`
- `cmp`

### ui_gameplay / container_commands (8)

- `setup_vbox`
- `setup_hbox`
- `setup_grid_container`
- `setup_margin_container`
- `setup_scroll_container`
- `setup_panel_container`
- `apply_container_recipe`
- `list_container_recipes`

### ui_gameplay / control_extra_commands (15)

- `set_control_tooltip`
- `set_control_cursor`
- `set_control_clip_contents`
- `set_control_custom_minimum_size`
- `set_control_modulate`
- `setup_color_rect`
- `setup_nine_patch_rect`
- `setup_hseparator`
- `setup_vseparator`
- `setup_check_box`
- `setup_check_button`
- `setup_spin_box`
- `setup_hslider`
- `setup_line_edit`
- `setup_text_edit`

### ui_gameplay / dialogue_commands (5)

- `create_dialogue_resource`
- `create_cutscene_resource`
- `create_dialogue_runner_script`
- `create_cutscene_player_script`
- `list_dialogue_recipes`

### ui_gameplay / dialogue_graph_depth_commands (8)

- `dialogue_graph_load`
- `dialogue_graph_add_line`
- `dialogue_graph_set_line`
- `dialogue_graph_remove_line`
- `dialogue_graph_add_choice`
- `dialogue_graph_validate`
- `dialogue_graph_list_lines`
- `list_dialogue_graph_depth_tools`

### ui_gameplay / game_ui_system_commands (8)

- `setup_hud`
- `setup_pause_menu`
- `setup_inventory_ui`
- `setup_dialogue_box_ui`
- `create_game_state_script`
- `create_audio_manager_script`
- `set_scene_tree_paused`
- `list_game_ui_templates`

### ui_gameplay / gameplay_feedback_commands (4)

- `create_floating_text_script`
- `create_hit_flash_script`
- `setup_floating_text_spawner`
- `list_gameplay_feedback_tools`

### ui_gameplay / gameplay_template_commands (5)

- `create_save_manager_script`
- `create_signal_bus_script`
- `create_object_pool_script`
- `create_camera_shake_script`
- `list_gameplay_templates`

### ui_gameplay / i18n_commands (11)

- `get_locale`
- `set_locale`
- `get_translation_projects`
- `add_translation`
- `remove_translation`
- `translate_string`
- `load_csv_translations`
- `load_po_translation`
- `list_translations`
- `extract_translatable_strings`
- `export_pot_template`

### ui_gameplay / i18n_csv_commands (5)

- `extract_strings_from_open_scene`
- `export_translation_csv`
- `import_translation_csv`
- `wrap_script_strings_with_tr`
- `list_i18n_csv_tools`

### ui_gameplay / inventory_component_commands (4)

- `create_inventory_component_script`
- `create_item_resource_script`
- `create_item_resource`
- `list_inventory_component_tools`

### ui_gameplay / label_richtext_commands (5)

- `setup_label`
- `setup_richtext_label`
- `richtext_append_bbcode`
- `label_set_autowrap`
- `list_label_richtext_tools`

### ui_gameplay / quest_system_commands (12)

- `create_quest_resource`
- `create_quest_log_script`
- `create_dialogue_graph_resource`
- `validate_dialogue_graph`
- `merge_dialogue_lines`
- `create_quest_giver_script`
- `create_objective_tracker_script`
- `export_dialogue_graph_mermaid`
- `export_dialogue_graph_dot`
- `add_dialogue_graph_node`
- `list_dialogue_graph_nodes`
- `list_quest_recipes`

### ui_gameplay / settings_save_commands (7)

- `create_settings_resource_script`
- `create_settings_manager_script`
- `setup_settings_menu`
- `setup_save_slot_menu`
- `create_enhanced_save_manager_script`
- `create_encrypted_save_manager_script`
- `list_settings_save_recipes`

### ui_gameplay / stylebox_commands (4)

- `create_stylebox_flat`
- `theme_set_stylebox_flat`
- `apply_stylebox_to_panel`
- `list_stylebox_tools`

### ui_gameplay / theme_commands (18)

- `create_theme`
- `set_theme_color`
- `set_theme_constant`
- `set_theme_font_size`
- `set_theme_stylebox`
- `setup_control`
- `get_theme_info`
- `set_focus_neighbors`
- `set_control_size_flags`
- `set_control_mouse_filter`
- `theme_set_type_color`
- `theme_set_type_constant`
- `theme_set_type_font_size`
- `theme_set_type_stylebox`
- `theme_list_types`
- `theme_clear_type`
- `theme_get_type_info`
- `assign_theme_to_control`

### ui_gameplay / theme_io_commands (5)

- `export_theme_resource`
- `import_theme_to_project`
- `duplicate_theme_resource`
- `assign_theme_to_scene_root`
- `list_theme_io_tools`

### ui_gameplay / theme_type_depth_commands (6)

- `theme_set_type_font`
- `theme_set_type_icon`
- `theme_seed_default_types`
- `theme_list_type_items`
- `theme_copy_type`
- `list_theme_type_depth_tools`

### ui_gameplay / ui_container_depth_commands (8)

- `setup_tab_container`
- `setup_split_container`
- `setup_flow_container`
- `setup_center_container`
- `setup_aspect_ratio_container`
- `setup_subviewport_container`
- `tab_container_add_page`
- `list_ui_container_depth_tools`

### ui_gameplay / ui_editor_depth_commands (5)

- `setup_code_edit`
- `setup_richtext_effects_basic`
- `set_option_button_items`
- `setup_progress_bar_ranged`
- `list_ui_editor_depth_tools`

### ui_gameplay / ui_list_commands (15)

- `item_list_clear`
- `item_list_add_item`
- `item_list_set_items`
- `option_button_set_items`
- `tree_clear`
- `tree_add_item`
- `popup_menu_set_items`
- `richtext_set_bbcode`
- `setup_window`
- `setup_accept_dialog`
- `setup_file_dialog`
- `setup_subviewport`
- `setup_video_stream_player`
- `setup_progress_bar`
- `setup_texture_progress_bar`

### xr / xr_commands (15)

- `setup_xr_origin`
- `set_xr_project_settings`
- `get_xr_info`
- `add_xr_controller`
- `list_xr_interfaces`
- `create_openxr_action_map`
- `openxr_add_action_set`
- `openxr_add_action`
- `openxr_get_action_map_info`
- `set_openxr_action_map_path`
- `add_xr_hand_modifier`
- `list_openxr_interaction_profiles`
- `openxr_add_interaction_profile`
- `openxr_bind_action`
- `openxr_create_default_controller_bindings`

### xr / xr_passthrough_commands (5)

- `set_xr_passthrough_settings`
- `setup_xr_composition_layer_quad`
- `get_xr_passthrough_info`
- `create_xr_passthrough_controller_script`
- `list_xr_passthrough_tools`

### xr / xr_player_rig_depth_commands (7)

- `setup_xr_player_rig`
- `create_xr_movement_script`
- `create_xr_grabber_script`
- `create_xr_teleport_script`
- `setup_xr_pickup_area`
- `list_xr_tools_catalog`
- `list_xr_player_rig_tools`

## Refresh

```powershell
.\scripts\export-surface-registry.ps1
.\scripts\organize-command-modules.ps1  # optional re-bucket
```

## Live agent discovery

- list_mcp_commands / list_command_modules / list_command_domains
- list_docs_coverage / get_production_surface_report
- list_surface_registry

