# Godot MCP Pro - Tool Surface Registry

Generated: 2026-07-28  
Plugin version: **1.38.0**  

## Honesty

Tracks workflow command surface growth - not 100% of ClassDB or every editor control.
See list_docs_coverage, DOCS_SURFACE_100.md, GAPS_VS_GODOT_DOCS.md.

## Totals

- **Registered plugin commands:** 692
- **Command modules:** 68

## Commands by module

### agent_commands (4)

- `health_check`
- `agent_workflow_guide`
- `list_docs_coverage`
- `list_surface_registry`

### ai_system_commands (8)

- `setup_ai_agent_2d`
- `setup_ai_agent_3d`
- `create_chase_ai_script`
- `create_patrol_ai_script`
- `setup_detection_area`
- `create_gameplay_state_machine_script`
- `create_interactable_script`
- `list_ai_templates`

### analysis_commands (6)

- `find_unused_resources`
- `analyze_signal_flow`
- `analyze_scene_complexity`
- `find_script_references`
- `detect_circular_dependencies`
- `get_project_statistics`

### android_commands (3)

- `list_android_devices`
- `get_android_preset_info`
- `deploy_to_android`

### animation_commands (33)

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

### animation_tree_commands (20)

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

### audio_commands (15)

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

### batch_commands (7)

- `find_nodes_by_type`
- `find_signal_connections`
- `batch_set_property`
- `batch_add_nodes`
- `find_node_references`
- `get_scene_dependencies`
- `cross_scene_set_property`

### behavior_tree_commands (6)

- `create_behavior_tree_runtime_script`
- `create_behavior_tree_resource`
- `create_behavior_tree_runner_script`
- `create_blackboard_script`
- `setup_behavior_tree_on_node`
- `list_behavior_tree_recipes`

### character_system_commands (10)

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

### class_commands (17)

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

### compat_commands (8)

- `get_godot_version`
- `get_uid`
- `update_project_uids`
- `load_sprite`
- `export_mesh_library`
- `list_projects`
- `launch_editor`
- `list_mcp_commands`

### container_commands (8)

- `setup_vbox`
- `setup_hbox`
- `setup_grid_container`
- `setup_margin_container`
- `setup_scroll_container`
- `setup_panel_container`
- `apply_container_recipe`
- `list_container_recipes`

### control_extra_commands (15)

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

### csharp_commands (13)

- `get_csharp_project_info`
- `create_csharp_script`
- `list_csharp_scripts`
- `ensure_csharp_csproj`
- `set_dotnet_project_settings`
- `attach_csharp_script`
- `run_dotnet_build`
- `run_godot_csharp_build`
- `get_last_build_log`
- `errors`
- `warnings`
- `errors`
- `warnings`

### debugger_commands (11)

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

### dialogue_commands (5)

- `create_dialogue_resource`
- `create_cutscene_resource`
- `create_dialogue_runner_script`
- `create_cutscene_player_script`
- `list_dialogue_recipes`

### editor_commands (13)

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

### export_commands (13)

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
- `has_matching_template`

### filesystem_commands (8)

- `res_copy_file`
- `res_delete_path`
- `res_rename_path`
- `res_make_dir`
- `res_file_exists`
- `res_list_dir`
- `res_read_text`
- `res_write_text`

### game_ui_system_commands (8)

- `setup_hud`
- `setup_pause_menu`
- `setup_inventory_ui`
- `setup_dialogue_box_ui`
- `create_game_state_script`
- `create_audio_manager_script`
- `set_scene_tree_paused`
- `list_game_ui_templates`

### gameplay_template_commands (5)

- `create_save_manager_script`
- `create_signal_bus_script`
- `create_object_pool_script`
- `create_camera_shake_script`
- `list_gameplay_templates`

### gdextension_commands (4)

- `create_gdextension_project`
- `list_gdextension_files`
- `get_gdextension_info`
- `run_gdextension_scons_build`

### i18n_commands (9)

- `get_locale`
- `set_locale`
- `get_translation_projects`
- `add_translation`
- `remove_translation`
- `translate_string`
- `load_csv_translations`
- `load_po_translation`
- `list_translations`

### import_3d_commands (11)

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

### import_commands (15)

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

### input_commands (5)

- `simulate_key`
- `simulate_mouse_click`
- `simulate_mouse_move`
- `simulate_action`
- `simulate_sequence`

### input_map_commands (6)

- `get_input_actions`
- `set_input_action`
- `remove_input_action`
- `list_input_action_events`
- `add_input_action_event`
- `clear_input_action_events`

### io_commands (8)

- `config_file_get`
- `config_file_set`
- `json_read`
- `json_write`
- `user_list_dir`
- `user_read_text`
- `user_write_text`
- `user_delete_path`

### material_2d_commands (12)

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

### media_commands (6)

- `media_find_ffmpeg`
- `media_frames_to_video`
- `media_extract_keyframes`
- `media_clip_video`
- `media_contact_sheet`
- `media_probe`

### modern_render_commands (6)

- `apply_environment_preset`
- `setup_camera_follow_2d`
- `setup_third_person_camera`
- `setup_orbit_camera_3d`
- `create_minimap_viewport`
- `list_render_presets`

### multiplayer_commands (10)

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

### multiplayer_runtime_commands (6)

- `create_multiplayer_lobby_ui`
- `create_multiplayer_game_manager_script`
- `create_websocket_multiplayer_template`
- `setup_multiplayer_player_scene`
- `setup_multiplayer_spawn_stack`
- `list_multiplayer_recipes`

### navigation_commands (8)

- `setup_navigation_region`
- `bake_navigation_mesh`
- `setup_navigation_agent`
- `set_navigation_layers`
- `get_navigation_info`
- `setup_navigation_link`
- `setup_navigation_obstacle`
- `set_navigation_agent_target`

### node_commands (28)

- `add_node`
- `delete_node`
- `duplicate_node`
- `move_node`
- `update_property`
- `update_properties`
- `list_property_info`
- `inspect_node`
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
- `nodes`
- `selected`

### particle_commands (11)

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

### physics_commands (18)

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

### plugin_scaffold_commands (2)

- `create_editor_plugin`
- `list_project_plugins`

### production_commands (5)

- `scaffold_project_defaults`
- `wire_signal_to_new_method`
- `playtest_report`
- `agent_production_status`
- `create_input_map_preset`

### profiling_commands (6)

- `get_performance_monitors`
- `get_editor_performance`
- `capture_performance_sample`
- `capture_performance_timeline`
- `get_render_info`
- `list_performance_monitor_names`

### project_commands (16)

- `get_project_info`
- `get_filesystem_tree`
- `search_files`
- `search_in_files`
- `get_project_settings`
- `set_project_setting`
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

### quest_system_commands (12)

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

### resource_commands (6)

- `read_resource`
- `edit_resource`
- `create_resource`
- `get_resource_preview`
- `create_custom_resource_script`
- `duplicate_resource`

### run_session_commands (15)

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

### runtime_commands (19)

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

### scene_2d_commands (17)

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

### scene_3d_commands (23)

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

### scene_commands (10)

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

### scene_flow_commands (4)

- `create_scene_transition_script`
- `create_loading_screen_scene`
- `list_scene_flow_recipes`
- `set_main_scene`

### scene_unique_commands (4)

- `set_scene_unique_name`
- `get_scene_unique_name`
- `find_node_by_unique_name`
- `list_scene_unique_names`

### script_commands (7)

- `list_scripts`
- `read_script`
- `create_script`
- `edit_script`
- `attach_script`
- `get_open_scripts`
- `validate_script`

### settings_save_commands (6)

- `create_settings_resource_script`
- `create_settings_manager_script`
- `setup_settings_menu`
- `setup_save_slot_menu`
- `create_enhanced_save_manager_script`
- `list_settings_save_recipes`

### shader_commands (9)

- `create_shader`
- `read_shader`
- `edit_shader`
- `assign_shader_material`
- `set_shader_param`
- `get_shader_params`
- `set_shader_global`
- `get_shader_global`
- `list_shader_globals`

### skeleton_commands (19)

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

### test_commands (5)

- `run_test_scenario`
- `assert_node_state`
- `assert_screen_text`
- `run_stress_test`
- `get_test_report`

### test_framework_commands (4)

- `detect_test_frameworks`
- `run_gut_tests`
- `run_gdunit_tests`
- `list_test_recipes`

### texture_commands (4)

- `create_gradient_texture`
- `create_noise_texture`
- `create_placeholder_texture`
- `create_curve_texture`

### theme_commands (10)

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

### tilemap_commands (13)

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

### tileset_commands (11)

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

### tween_commands (3)

- `create_tween_helper_script`
- `list_tween_recipes`
- `create_scene_tree_tween_snippet`

### ui_list_commands (15)

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

### utility_node_commands (10)

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

### vfx_shader_commands (10)

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

### visual_shader_commands (7)

- `create_visual_shader`
- `visual_shader_add_node`
- `visual_shader_connect`
- `visual_shader_set_node_property`
- `visual_shader_get_info`
- `assign_visual_shader_material`
- `visual_shader_add_preset_fresnel`

### webrtc_multiplayer_commands (6)

- `create_webrtc_multiplayer_template`
- `create_signaling_server_script`
- `create_matchmaking_client_script`
- `create_input_buffer_netcode_script`
- `create_lag_compensation_helper_script`
- `list_webrtc_recipes`

### xr_commands (15)

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

## Refresh

```powershell
.\scripts\export-surface-registry.ps1
```

## Live agent discovery

- list_mcp_commands
- list_docs_coverage
- list_surface_registry

