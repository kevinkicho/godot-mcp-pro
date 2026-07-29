@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Agent-facing diagnostics and production workflow guidance (project-neutral).


func get_commands() -> Dictionary:
	return {
		"health_check": _health_check,
		"agent_workflow_guide": _agent_workflow_guide,
		"list_docs_coverage": _list_docs_coverage,
		"list_surface_registry": _list_surface_registry,
		"agent_ensure_ready": _agent_ensure_ready,
		"batch_editor_calls": _batch_editor_calls,
		"agent_headless_status": _agent_headless_status,
	}


func _health_check(_params: Dictionary) -> Dictionary:
	var cfg := ConfigFile.new()
	var plugin_version := "unknown"
	if cfg.load("res://addons/godot_mcp/plugin.cfg") == OK:
		plugin_version = str(cfg.get_value("plugin", "version", "unknown"))

	var ws = null
	var connected_ports: Array = []
	var client_count := 0
	if editor_plugin != null and editor_plugin.get("websocket_server") != null:
		ws = editor_plugin.websocket_server
	# Walk siblings under plugin for websocket server
	if editor_plugin != null:
		for child in editor_plugin.get_children():
			if child.has_method("get_connected_ports"):
				ws = child
				break

	if ws != null:
		if ws.has_method("get_connected_ports"):
			connected_ports = ws.get_connected_ports()
		if ws.has_method("get_client_count"):
			client_count = ws.get_client_count()

	var root := get_edited_root()
	var playing := false
	var ei := get_editor()
	if ei:
		playing = ei.is_playing_scene()

	var router = get_parent()
	var command_count := 0
	if router != null and router.has_method("get_available_methods"):
		command_count = router.get_available_methods().size()

	var ready_for_agents := client_count > 0 and command_count > 0
	var issues: Array = []
	if client_count == 0:
		issues.append({
			"severity": "warning",
			"message": "No MCP client connected on WebSocket ports 6505-6509",
			"suggestion": "Start the open MCP server (Grok/Claude mcp_servers.godot) and keep this editor open.",
		})
	if command_count == 0:
		issues.append({
			"severity": "error",
			"message": "No commands registered — plugin failed to load command modules",
		})
	if root == null:
		issues.append({
			"severity": "info",
			"message": "No scene open in editor — open or create a scene before node tools",
		})

	var has_hard_error := false
	for issue in issues:
		if issue is Dictionary and str(issue.get("severity", "")) == "error":
			has_hard_error = true
			break

	return success({
		"ok": ready_for_agents and not has_hard_error,
		"ready_for_agent_production": ready_for_agents and not has_hard_error,
		"plugin_version": plugin_version,
		"godot_version": Engine.get_version_info(),
		"project_name": ProjectSettings.get_setting("application/config/name", ""),
		"project_path": ProjectSettings.globalize_path("res://"),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"command_count": command_count,
		"websocket": {
			"connected_ports": connected_ports,
			"client_count": client_count,
			"port_range": "6505-6509",
		},
		"editor": {
			"has_open_scene": root != null,
			"open_scene": root.scene_file_path if root else "",
			"open_scenes": get_open_scene_paths(),
			"playing": playing,
		},
		"headless_parity": {
			"principle": "When plugin is connected, agents have human-IDE control plane (scenes, inspector, play, import, export).",
			"fine_tune": "list_property_info recurse_resources + update_property covers every inspector field",
			"methods": "call_node_method / execute_editor_script for ClassDB long-tail",
			"offline_cli": "launch_editor, run_project, headless create_scene/add_node via GODOT_PATH",
		},
		"issues": issues,
		"agent_hint": "Call agent_ensure_ready then agent_workflow_guide for the production loop.",
	})


func _agent_ensure_ready(params: Dictionary) -> Dictionary:
	## One-shot readiness: health + optional autoloads + open main scene shell.
	var health := _health_check({})
	var h: Dictionary = health.get("result", health)
	var actions: Array = []
	var router = get_parent()
	if optional_bool(params, "ensure_runtime_autoloads", true) and router and router.has_method("execute"):
		var methods: Array = router.get_available_methods() if router.has_method("get_available_methods") else []
		if "ensure_runtime_autoloads" in methods:
			var r = await router.execute("ensure_runtime_autoloads", {})
			actions.append({"ensure_runtime_autoloads": r})
		else:
			actions.append({
				"ensure_runtime_autoloads": "command not registered — enable run_session module",
			})
	if optional_bool(params, "open_main_if_empty", true):
		var root := get_edited_root()
		if root == null:
			var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
			if not main_scene.is_empty() and ResourceLoader.exists(main_scene):
				EditorInterface.open_scene_from_path(main_scene)
				actions.append({"opened_main_scene": main_scene})
			else:
				actions.append({"open_scene": "none — create_scene or set main scene"})
	health = _health_check({})
	h = health.get("result", health)
	return success({
		"ready": bool(h.get("ready_for_agent_production", false)),
		"health": h,
		"actions": actions,
		"next": [
			"agent_workflow_guide",
			"list_property_info / get_scene_tree",
			"playtest_report when content ready",
		],
	})


func _batch_editor_calls(params: Dictionary) -> Dictionary:
	## Run multiple plugin commands in order (reduces round-trips for agents).
	if not params.has("calls") or not params["calls"] is Array:
		return error_invalid_params("calls: Array of {method, params}")
	var calls: Array = params["calls"]
	var stop_on_error: bool = optional_bool(params, "stop_on_error", true)
	var router = get_parent()
	if router == null or not router.has_method("execute"):
		return error_internal("No command router with execute()")
	var results: Array = []
	for i in range(mini(calls.size(), 50)):
		var c = calls[i]
		if not c is Dictionary:
			results.append({"index": i, "error": "call must be Dictionary"})
			if stop_on_error:
				break
			continue
		var method: String = str(c.get("method", c.get("command", "")))
		var cparams: Dictionary = c.get("params", {})
		if cparams == null:
			cparams = {}
		if method.is_empty():
			results.append({"index": i, "error": "method required"})
			if stop_on_error:
				break
			continue
		if method == "batch_editor_calls":
			results.append({"index": i, "error": "nested batch_editor_calls not allowed"})
			if stop_on_error:
				break
			continue
		var one: Dictionary = await router.execute(method, cparams)
		results.append({"index": i, "method": method, "result": one})
		if stop_on_error and one is Dictionary and one.has("error"):
			break
	return success({
		"results": results,
		"count": results.size(),
		"hint": "Prefer typed MCP tools when available; batch for multi-step dock workflows",
	})


func _agent_headless_status(_params: Dictionary) -> Dictionary:
	## What works without UI clicks vs needs Play / import.
	return success({
		"with_plugin_connected": {
			"full_ide_parity": true,
			"scenes_nodes_scripts": true,
			"inspector_fine_tune": true,
			"import_wait": true,
			"playtest_screenshots": true,
			"export": true,
		},
		"without_plugin_mcp_server_only": {
			"launch_editor": true,
			"run_project_cli": true,
			"headless_create_scene_add_node": true,
			"runtime_tcp_if_game_running": true,
			"undo_redo_inspector": false,
		},
		"recommended": [
			"Start Godot with project + plugin enabled",
			"agent_ensure_ready",
			"Never hand-edit project.godot when tools exist",
			"use call_editor for any registered plugin method in lite mode",
		],
	})


func _agent_workflow_guide(params: Dictionary) -> Dictionary:
	var topic: String = optional_string(params, "topic", "production")
	# Project-neutral loops for agent-driven game production
	var guide := {
		"purpose": "Use Godot MCP as the primary control plane for agent-driven game production.",
		"principles": [
			"Prefer live editor tools (UndoRedo) when the plugin is connected.",
			"Explore before mutate: get_project_info → get_filesystem_tree / get_scene_tree → read_script.",
			"Mutate via MCP tools, not raw project.godot edits.",
			"After significant script/scene work: save_scene, validate_script, play_scene, inspect errors.",
			"Keep paths under res:// for all writes.",
			"Use health_check first when anything looks offline.",
		],
		"production_loop": [
			{"step": 1, "action": "health_check / agent_production_status", "why": "Confirm editor + MCP link + import idle"},
			{"step": 2, "action": "scaffold_project_defaults (once per new project)", "why": "Folders, viewport, layers, input preset, main scene — human first-hour setup"},
			{"step": 3, "action": "stage_files_into_res / ensure_imported / import_paths", "why": "Drop assets + wait until loadable (Import dock)"},
			{"step": 4, "action": "get_project_info + get_filesystem_tree + get_scene_tree / open_scene", "why": "Orient before mutate"},
			{"step": 5, "action": "create_scene / add_node / update_property / create_script / attach_script", "why": "Build content like the Scene/Inspector docks"},
			{"step": 6, "action": "wire_signal_to_new_method (or connect_signal)", "why": "Signal dock: create method + persistent connect"},
			{"step": 7, "action": "save_scene + validate_script", "why": "Persist and check compile"},
			{"step": 8, "action": "playtest_report or playtest_sequence (inputs+asserts)", "why": "Hit Play, interact like a human, inspect Output"},
			{"step": 9, "action": "simulate_action / get_game_node_properties / audit_scene_tree", "why": "Interact, assert runtime, audit wiring"},
			{"step": 10, "action": "stop_scene → fix → repeat", "why": "Close the feedback loop"},
		],
		"headless_principle": "Agents work as if a human uses the Godot IDE. Prefer MCP tools over raw filesystem edits of .tscn / project.godot. Full import/playtest needs editor + plugin; file scaffolding works when plugin is up.",
		"when_editor_offline": [
			"launch_editor with project_path",
			"CLI: run_project / get_debug_output / create_scene (headless) as fallback",
			"Prefer reconnecting the plugin for production quality (UndoRedo, screenshots, runtime, ensure_imported)",
		],
		"topic": topic,
	}

	match topic:
		"2d":
			guide["focus"] = [
				"scaffold_project_defaults genre=2d",
				"create_scene root CharacterBody2D/Node2D",
				"add_node Sprite2D/CollisionShape2D",
				"load_sprite / ensure_imported",
				"create_input_map_preset platformer_2d|topdown_2d",
				"tilemap_*",
			]
		"3d":
			guide["focus"] = [
				"scaffold_project_defaults genre=3d",
				"create_scene root Node3D/CharacterBody3D",
				"stage_files_into_res for .glb → ensure_imported",
				"add_mesh_instance", "setup_lighting", "setup_camera_3d", "setup_collision",
			]
		"humanoid", "character_interaction":
			guide["focus"] = [
				"list_humanoid_recipes",
				"setup_humanoid_actor model_scene=…",
				"validate_humanoid_rig",
				"create_bone_map_preset profile=mixamo|rpm|humanoid",
				"apply_locomotion_set + apply_example_animation",
				"bind_interaction kind=talk|use",
				"dialogue/quest tools as needed",
				"playtest_report",
			]
		"level", "level_design", "greybox":
			guide["focus"] = [
				"list_level_design_tools",
				"greybox_room / greybox_corridor / csg_*",
				"csg_set_operation + csg_bake_to_mesh_instance",
				"mesh_create_trimesh_static_body on level meshes",
				"create_heightmap_terrain / gridmap_* / tilemap_*",
				"stream_load_chunk for large worlds",
				"place_prop_scatter / multimesh_scatter / stamp_scene_instances",
				"setup_navigation_region + bake",
				"validate_level_playable / audit_scene_tree",
				"level_playtest_route + playtest_sequence",
			]
		"playtest", "play", "qa":
			guide["focus"] = [
				"list_playtest_loop_tools",
				"playtest_report (one-shot play + errors + optional asserts)",
				"playtest_sequence steps=[wait,action,assert,screenshot]",
				"simulate_action / simulate_sequence for finer control",
				"run_session_start + run_capture_timeline for long sessions",
			]
		"collision", "mesh_collision":
			guide["focus"] = [
				"list_mesh_collision_tools",
				"mesh_create_trimesh_static_body (Mesh menu parity)",
				"mesh_create_convex_collision / mesh_create_multiple_convex_collisions",
				"add_collision_shape_from_mesh body_path=… mesh_path=…",
				"get_collision_info / playtest_report",
			]
		"resources", "dependencies", "remap":
			guide["focus"] = [
				"list_resource_graph_tools",
				"list_resource_dependencies path=…",
				"find_files_referencing path=…",
				"remap_resource_references from=… to=… dry_run=true then false",
				"validate_scene_dependencies / list_orphaned_resources",
				"validate_all_scenes before export",
			]
		"audit", "signals_audit":
			guide["focus"] = [
				"list_scene_audit_tools",
				"audit_scene_tree",
				"list_scene_signals only_connected=true",
				"list_missing_scripts",
				"validate_all_scenes",
			]
		"audio", "music":
			guide["focus"] = [
				"list_music_tools",
				"create_music_controller_script add_autoload=true",
				"music_set_playlist states={explore,combat}",
				"add_audio_bus / set_bus_volume_db",
				"setup_audio_stream_player_2d/3d",
			]
		"editor", "workspace":
			guide["focus"] = [
				"get_editor_workspace_info",
				"play_main_scene / play_current_scene / play_custom_scene",
				"list_open_scenes / save_all_scenes",
				"list_resources_by_type",
				"editor_focus_node / editor_frame_selection (F-key parity)",
				"editor_get_3d_camera / editor_set_3d_camera_transform",
				"set_nodes_transform / select_nodes",
				"open_path_in_filesystem / set_main_screen",
			]
		"animation", "animations", "anim":
			guide["focus"] = [
				"list_animation_fine_tune_tools",
				"EXAMPLE → TARGET: extract_animations_from_scene OR list_animations on example player",
				"dump_animation / get_animation_info include_keys=true (read example tracks+keys)",
				"apply_example_animation example_scene_path=… source_animation=Walk target_node_path=Player/Anim",
				"OR copy_animation_to_player source_node_path=… target_node_path=…",
				"remap_animation_track_paths from_prefix=… to_prefix=… (hierarchy mismatch)",
				"compare_animations source_* vs target_*",
				"scale_animation_time / offset_animation_keys / crop_animation",
				"set_animation_keyframe / set_bezier_key / bezier_set_keys_batch for key fine-tune",
				"bezier_list_keys_cartesian + bezier_sample_dense (time×value plane, control points)",
				"curve2d/3d_get_points + path_set_curve_points for Path curves",
				"sample_animation_at_time to match example pose",
				"animation_player_play + playtest_report / get_game_screenshot",
			]
			guide["human_parity"] = {
				"copy_example": "apply_example_animation or copy_animation_to_player",
				"inspect": "dump_animation include_keys=true; bezier_list_keys_cartesian for plane data",
				"retarget_paths": "remap_animation_track_paths",
				"timing": "scale_animation_time scale=0.5 (2x speed) or offset_animation_keys",
				"tweak_key": "set_animation_keyframe / bezier_set_keys_batch with Cartesian {x:time,y:value,in,out}",
				"curve_shape": "bezier_sample_dense polyline → identify extrema → set handles",
				"tree": "create_animation_tree + travel_animation_state",
			}
			guide["guarantee"] = "Full numerical access to animation keys, Bezier control points, and Curve/Curve2D/Curve3D resources — agents map focal points on the Cartesian plane and write them via MCP."
		"ui":
			guide["focus"] = [
				"scaffold_project_defaults genre=ui",
				"Control roots", "set_anchor_preset", "set_theme_*",
				"wire_signal_to_new_method for Button.pressed",
				"click_button_by_text",
			]
		"assets", "import":
			guide["focus"] = [
				"stage_files_into_res files=[{from,to}] dest_dir=res://assets",
				"ensure_imported paths=[…] / import_paths",
				"wait_for_import / reimport_files",
				"apply_texture_import_preset / apply_scene_import_preset",
				"get_import_info / set_import_options",
			]
		"inspector", "tune", "properties":
			guide["focus"] = [
				"select_nodes / get_editor_selection",
				"inspect_node deep=true OR list_property_info (enums/ranges/usage)",
				"list_property_info recurse_resources=true — expand shape.*, material.*, etc.",
				"search_properties query=radius|albedo|collision",
				"get_property → update_property / update_properties (batch)",
				"reset_property when can_revert",
				"describe_class class_name=CharacterBody3D for full ClassDB surface",
				"list_node_methods → call_node_method for non-property API",
				"Nested resources: add_resource then update_property property='shape.radius'",
				"wire_signal_to_new_method / connect_signal / get_signals",
				"set_meta / list_meta / save_scene",
			]
			guide["human_parity"] = {
				"tune_transform": "update_properties node_path=Player properties={position, rotation, scale}",
				"tune_collision": "add_resource property=shape resource_type=CircleShape2D → update_property property=shape.radius value=16",
				"tune_material": "add_resource property=material_override resource_type=StandardMaterial3D resource_properties={albedo_color:'#ff0000'} → update_property property=material_override.roughness value=0.4",
				"enum_by_name": "update_property property=process_mode value=PROCESS_MODE_ALWAYS (or list_property_info enum_options)",
				"discover_every_field": "list_property_info recurse_resources=true include_headers=true",
				"unknown_type": "describe_class + list_class_properties include_inherited=true",
				"call_api": "list_node_methods filter=play → call_node_method method=play args=[]",
				"wire_button": "wire_signal_to_new_method source_path=UI/Button signal_name=pressed target_path=.",
				"script_exports": "list_property_info shows @export; edit_script to add/remove @export then reload_project",
			}
			guide["guarantee"] = "Any editor-visible property on a node or nested Resource is readable via list_property_info/get_property and writable via update_property (UndoRedo). Methods via call_node_method. ClassDB via describe_class."
		_:
			guide["focus"] = [
				"Full production_loop above",
				"Macros: scaffold_project_defaults, ensure_imported, wire_signal_to_new_method, playtest_report",
				"topic=inspector|assets|playtest for specialized human docks",
			]

	return success(guide)


func _list_docs_coverage(_params: Dictionary) -> Dictionary:
	## Honest map of docs areas → MCP depth. Status values:
	## strong | partial | thin | classdb_only
	## NOTE: This is NOT "100% of the SDK". ClassDB lookup ≠ workflow tools.
	var areas := {
		"getting_started": {
			"status": "strong",
			"tools": [
				"health_check", "agent_production_status", "scaffold_project_defaults",
				"launch_editor", "get_project_info", "create_scene", "add_node", "create_script",
				"play_scene", "playtest_report",
				"create_scene_transition_script", "create_loading_screen_scene", "set_main_scene",
			],
			"gaps": [],
		},
		"tutorials/editor": {
			"status": "strong",
			"tools": [
				"inspect_node", "list_property_info", "get_property", "search_properties", "reset_property",
				"update_property", "update_properties", "list_node_methods", "call_node_method",
				"select_nodes", "get_scene_tree", "get_editor_errors",
				"reload_project", "scan_filesystem",
				"debugger_get_status", "debugger_continue", "debugger_step_over/into/out",
				"set_source_breakpoint", "list_source_breakpoints", "open_script_at_line",
			],
			"gaps": ["native editor gutter breakpoint list (engine-limited)", "full call stack variables UI"],
		},
		"tutorials/scripting": {
			"status": "strong",
			"tools": [
				"create_script", "edit_script", "attach_script", "validate_script", "describe_class",
				"get_global_class_list", "set_scene_unique_name", "add_autoload",
				"get_csharp_project_info", "create_csharp_script", "ensure_csharp_csproj", "attach_csharp_script", "list_csharp_scripts",
			],
			"gaps": ["visual script N/A", "IDE-integrated debugger for C++"],
		},
		"tutorials/2d": {
			"status": "strong",
			"tools": [
				"setup_character_2d", "create_platformer_controller_script", "create_topdown_controller_script",
				"setup_camera_follow_2d", "setup_camera_2d", "setup_parallax_background", "add_parallax_layer",
				"add_light_occluder_2d", "setup_point_light_2d", "setup_line_2d", "setup_path_2d", "setup_polygon_2d",
				"set_y_sort_enabled", "tilemap_* incl paint_line/erase_rect/paint_cells", "tileset_* incl terrains",
				"sprite_frames_*", "setup_ai_agent_2d", "setup_hitbox/hurtbox",
			],
			"gaps": ["advanced tile atlas region tools", "full TileMap editor terrain painting GUI"],
		},
		"tutorials/3d": {
			"status": "strong",
			"tools": [
				"setup_character_3d", "create_fps_controller_script", "setup_third_person_camera", "setup_orbit_camera_3d",
				"apply_environment_preset", "add_mesh_instance", "setup_lighting", "setup_camera_3d",
				"setup_environment", "setup_world_environment", "set_material_3d", "add_gridmap", "export_mesh_library",
				"add_reflection_probe", "add_decal", "add_voxel_gi", "bake_voxel_gi", "add_lightmap_gi",
				"request_lightmap_bake", "setup_csg_box/sphere/cylinder", "csg_set_operation", "csg_bake_to_mesh_instance",
				"mesh_create_trimesh_static_body", "mesh_create_convex_collision",
				"setup_path_3d", "set_render_layers",
				"add_fog_volume", "set_environment_fog", "add_occluder_instance_3d",
				"find_skeletons", "list_skeleton_bones", "create_bone_map", "add_bone_attachment", "setup_ai_agent_3d",
				"editor_focus_node", "editor_frame_selection",
			],
			"gaps": ["full lightmap UV2 auto-unwrap", "auto LOD generation"],
		},
		"gameplay_systems": {
			"status": "strong",
			"tools": [
				"setup_character_2d/3d", "create_*_controller_script", "create_health_component_script",
				"setup_hitbox", "setup_hurtbox", "create_projectile_script",
				"setup_ai_agent_2d/3d", "create_chase_ai_script", "create_patrol_ai_script",
				"create_gameplay_state_machine_script", "create_interactable_script",
				"setup_hud", "setup_pause_menu", "setup_inventory_ui", "setup_dialogue_box_ui",
				"create_game_state_script", "create_audio_manager_script",
				"create_save_manager_script", "create_signal_bus_script", "create_object_pool_script",
				"apply_environment_preset", "create_minimap_viewport",
			],
			"gaps": ["full quest graph editor", "dialogue tree visual editor", "behavior tree designer UI"],
		},
		"tutorials/animation": {
			"status": "strong",
			"tools": [
				"list_animations", "create_animation", "add_animation_track", "set_animation_keyframe",
				"insert_method_key", "insert_audio_key", "animation_player_play", "ensure_reset_animation",
				"create_animation_tree", "travel_animation_state", "add_blend_space_point", "sprite_frames_*",
				"set_bezier_key", "get_bezier_key_info", "bezier_list_keys_cartesian", "bezier_set_keys_batch",
				"bezier_sample_dense", "bezier_set_handle_mode", "create_bone_map", "apply_bone_map_to_skeleton",
				"apply_example_animation", "dump_animation", "compare_animations",
			],
			"gaps": ["importer auto-retarget for every DCC pipeline variant"],
		},
		"tutorials/assets_pipeline": {
			"status": "strong",
			"tools": [
				"stage_files_into_res", "ensure_imported", "import_paths",
				"reimport_files", "wait_for_import", "get_import_info", "set_import_option", "set_import_options",
				"apply_texture_import_preset", "apply_scene_import_preset", "set_gltf_import_flags",
				"list_imported_scene_contents", "extract_meshes_from_scene", "extract_materials_from_scene",
				"instance_scene_as_inherited", "create_scene_from_gltf", "pack_mesh_library_from_scene",
				"create_atlas_texture", "create_gradient_texture", "create_noise_texture", "create_placeholder_texture",
				"create_custom_resource_script", "duplicate_resource",
				"list_resource_dependencies", "find_files_referencing", "remap_resource_references",
				"list_orphaned_resources", "validate_scene_dependencies",
				"create_bone_map", "auto_map_bones_by_name", "scan_filesystem", "res_copy_file",
			],
			"gaps": ["per-importer full option schemas", "FBX-specific advanced dialog parity"],
		},
		"tutorials/audio": {
			"status": "strong",
			"tools": [
				"create_audio_manager_script", "add_audio_player", "set_audio_player_stream",
				"add_audio_bus", "remove_audio_bus", "set_audio_bus",
				"add_audio_bus_effect", "get_audio_bus_layout", "save_audio_bus_layout", "load_audio_bus_layout",
				"create_music_controller_script", "setup_music_player", "music_set_playlist",
			],
			"gaps": ["AudioStreamGenerator procedural waveform designer"],
		},
		"tutorials/inputs": {
			"status": "strong",
			"tools": [
				"create_input_map_preset", "get_input_actions", "set_input_action", "remove_input_action",
				"list_input_action_events", "add_input_action_event", "simulate_*",
				"create_joypad_input_map_preset", "add_joypad_binding", "list_joypads",
				"set_action_deadzone", "get_action_strength_info", "list_joypad_button_names",
			],
			"gaps": ["OS-level controller remapping UI outside Godot"],
		},
		"tutorials/io": {
			"status": "strong",
			"tools": [
				"res_*", "config_file_get/set", "json_read/write", "user_list_dir", "user_read_text", "user_write_text",
				"create_encrypted_save_manager_script", "create_enhanced_save_manager_script",
			],
			"gaps": ["cloud save backends", "HTTPRequest as dedicated IO surface"],
		},
		"tutorials/i18n": {
			"status": "strong",
			"tools": [
				"get_locale", "set_locale", "add_translation", "translate_string",
				"load_csv_translations", "load_po_translation", "list_translations",
				"extract_translatable_strings", "export_pot_template",
			],
			"gaps": ["auto-submit to translation platforms"],
		},
		"tutorials/navigation": {
			"status": "strong",
			"tools": [
				"setup_navigation_region", "bake_navigation_mesh", "setup_navigation_agent",
				"setup_navigation_link", "setup_navigation_obstacle", "set_navigation_agent_target", "set_navigation_layers",
				"setup_ai_agent_2d/3d", "create_chase_ai_script", "create_patrol_ai_script",
			],
			"gaps": ["path debug draw overlay", "NavigationServer query helpers"],
		},
		"tutorials/networking": {
			"status": "strong",
			"tools": [
				"create_multiplayer_game_manager_script", "create_multiplayer_lobby_ui",
				"setup_multiplayer_player_scene", "setup_multiplayer_spawn_stack",
				"create_websocket_multiplayer_template", "create_multiplayer_template_script",
				"setup_multiplayer_spawner/synchronizer", "add_spawnable_scene", "add_replication_property",
				"setup_http_request", "list_rpc_config", "set_multiplayer_authority", "list_multiplayer_recipes",
			],
			"gaps": ["WebRTC peer tools", "full matchmaking/relay services", "rollback netcode"],
		},
		"narrative_quests": {
			"status": "strong",
			"tools": [
				"create_quest_resource", "create_quest_log_script", "create_quest_giver_script",
				"create_objective_tracker_script", "create_dialogue_graph_resource",
				"validate_dialogue_graph", "merge_dialogue_lines", "add_dialogue_graph_node",
				"list_dialogue_graph_nodes", "export_dialogue_graph_mermaid", "export_dialogue_graph_dot",
				"setup_dialogue_box_ui", "create_dialogue_resource", "create_dialogue_runner_script",
				"list_quest_recipes",
			],
			"gaps": ["in-editor visual graph canvas widget", "localization-aware dialogue tables"],
		},
		"ai_behavior_trees": {
			"status": "strong",
			"tools": [
				"create_behavior_tree_runtime_script", "create_blackboard_script",
				"create_behavior_tree_resource", "create_behavior_tree_runner_script",
				"setup_behavior_tree_on_node", "list_behavior_tree_recipes",
				"create_gameplay_state_machine_script", "setup_ai_agent_2d/3d",
			],
			"gaps": ["visual BT editor UI", "full utility AI / GOAP planner"],
		},
		"networking_webrtc": {
			"status": "strong",
			"tools": [
				"create_webrtc_multiplayer_template", "create_signaling_server_script",
				"create_matchmaking_client_script", "create_input_buffer_netcode_script",
				"create_lag_compensation_helper_script", "create_webrtc_ice_config_script",
				"list_webrtc_recipes",
			],
			"gaps": ["hosted commercial matchmaking service", "full GGPO rollback simulation"],
		},
		"shaders_vfx": {
			"status": "strong",
			"tools": [
				"create_shader_preset", "list_shader_presets", "apply_canvas_shader_to_node",
				"apply_spatial_shader_to_mesh", "setup_trail_vfx", "setup_flash_hurt_vfx",
				"setup_screen_fade_overlay", "create_hit_stop_script", "create_particles",
				"create_shader", "visual_shader_*",
			],
			"gaps": ["full visual shader graph parity for every node type"],
		},
		"settings_save_menus": {
			"status": "strong",
			"tools": [
				"create_settings_manager_script", "setup_settings_menu",
				"create_enhanced_save_manager_script", "setup_save_slot_menu",
				"create_save_manager_script", "create_game_state_script",
			],
			"gaps": ["cloud save backends"],
		},
		"export_pipeline": {
			"status": "strong",
			"tools": [
				"list_export_presets", "create_export_preset", "run_export", "export_and_verify",
				"set_export_filters", "list_export_templates", "duplicate_export_preset",
				"set_export_preset_option", "deploy_to_android",
			],
			"gaps": ["iOS code signing automation", "store upload APIs"],
		},
		"runtime_probe": {
			"status": "strong",
			"tools": [
				"run_session_start/stop/status", "run_probe_report",
				"run_record_start/stop", "run_log_event", "run_get_events", "run_get_logs",
				"run_capture_timeline", "run_find_nodes",
				"get_game_scene_tree", "get_game_node_properties", "assert_node_state",
				"simulate_*", "capture_frames", "playtest_report", "playtest_sequence",
				"media_find_ffmpeg", "media_frames_to_video", "media_extract_keyframes",
				"media_clip_video", "media_contact_sheet",
				"detect_test_frameworks", "run_gut_tests", "run_gdunit_tests",
				"audit_scene_tree", "list_scene_signals", "validate_all_scenes",
			],
			"gaps": [
				"standalone CLI run without editor Play (TCP needs running game/autoloads)",
				"Playwright only for web exports (not desktop Play)",
				"deep GPU frame debugger export",
			],
		},

		"tutorials/performance": {
			"status": "strong",
			"tools": [
				"get_performance_monitors", "get_editor_performance", "capture_performance_sample",
				"capture_performance_timeline", "get_render_info", "list_performance_monitor_names",
				"export_performance_report", "get_gpu_profiling_hints",
				"analyze_scene_complexity", "run_stress_test",
				"debugger_get_status", "list_debugger_errors", "set_debug_project_settings",
			],
			"gaps": ["native GPU frame debugger graph (engine UI only)", "CPU flame chart PNG export"],
		},
		"tutorials/physics": {
			"status": "strong",
			"tools": [
				"setup_physics_body", "create_physics_body", "setup_collision", "setup_area", "set_area_monitoring",
				"setup_joint", "add_raycast", "add_shape_cast", "set_physics_material", "add_vehicle_wheel",
				"setup_soft_body", "add_physical_bone", "setup_physical_bone_simulator",
				"mesh_create_trimesh_static_body", "mesh_create_convex_collision", "mesh_create_multiple_convex_collisions",
				"add_collision_shape_from_mesh",
			],
			"gaps": ["joint limit fine UI", "test_move debug viz", "full ragdoll auto-generate from skeleton"],
		},
		"tutorials/export": {
			"status": "strong",
			"tools": [
				"list_export_presets", "create_export_preset", "set_export_preset_option", "remove_export_preset",
				"get_export_preset", "export_project", "run_export", "deploy_to_android", "get_export_info",
			],
			"gaps": ["signing/notarization wizards", "export template install automation"],
		},
		"tutorials/platform": {
			"status": "partial",
			"tools": ["deploy_to_android", "list_android_devices", "create_export_preset platform=Web|iOS|Android", "run_export"],
			"gaps": ["console platforms", "full iOS Xcode pipeline"],
		},
		"tutorials/rendering": {
			"status": "strong",
			"tools": [
				"setup_environment", "setup_lighting", "set_material_3d", "add_reflection_probe", "add_decal",
				"add_voxel_gi", "bake_voxel_gi", "set_render_layers",
				"configure_sdfgi", "configure_ssao", "configure_ssr", "configure_glow", "configure_ssil",
				"set_mesh_lightmap_params", "add_lightmap_gi", "request_lightmap_bake",
				"setup_compositor", "add_compositor_effect", "apply_environment_preset",
			],
			"gaps": ["full automatic UV2 unwrap for all mesh importers", "vendor GPU captures"],
		},
		"tutorials/shaders": {
			"status": "strong",
			"tools": [
				"create_shader", "edit_shader", "assign_shader_material", "set_shader_param", "get_shader_params",
				"set_shader_global", "get_shader_global", "list_shader_globals",
				"create_visual_shader", "visual_shader_add_node", "visual_shader_connect", "visual_shader_get_info",
				"assign_visual_shader_material", "visual_shader_add_preset_fresnel",
			],
			"gaps": ["full VisualShader node catalog UI parity", "shader include libraries"],
		},
		"tutorials/ui": {
			"status": "strong",
			"tools": [
				"set_anchor_preset", "set_theme_*", "create_theme", "setup_control", "set_focus_neighbors",
				"set_control_size_flags", "item_list_*", "tree_*", "option_button_set_items", "popup_menu_set_items",
				"richtext_set_bbcode", "setup_window", "setup_accept_dialog", "setup_file_dialog",
				"setup_subviewport", "setup_video_stream_player", "setup_progress_bar", "setup_texture_progress_bar",
				"theme_set_type_*", "theme_list_types", "theme_get_type_info", "assign_theme_to_control",
				"connect_signal",
			],
			"gaps": ["Theme editor visual stylebox graph UI"],
		},
		"tutorials/plugins": {
			"status": "strong",
			"tools": [
				"create_editor_plugin", "list_project_plugins", "create_gdextension_project",
				"clone_godot_cpp", "run_gdextension_scons_build", "setup_gdextension_full",
				"list_gdextension_files", "execute_editor_script", "describe_class EditorPlugin",
			],
			"gaps": ["plugin marketplace packaging", "CI matrix for all target platforms"],
		},
		"tutorials/xr": {
			"status": "strong",
			"tools": [
				"setup_xr_origin", "add_xr_controller", "set_xr_project_settings", "get_xr_info", "list_xr_interfaces",
				"create_openxr_action_map", "openxr_add_action_set", "openxr_add_action", "openxr_get_action_map_info",
				"set_openxr_action_map_path", "add_xr_hand_modifier",
				"list_openxr_interaction_profiles", "openxr_add_interaction_profile", "openxr_bind_action",
				"openxr_create_default_controller_bindings",
			],
			"gaps": ["passthrough", "composition layers", "vendor-specific profile verification"],
		},
		"tutorials/math": {
			"status": "strong",
			"tools": [
				"create_curve_resource", "curve_set_points", "curve_get_points", "curve_sample", "curve_sample_baked",
				"create_curve2d_resource", "curve2d_set_points", "curve2d_get_points", "curve2d_sample_polyline",
				"create_curve3d_resource", "curve3d_set_points", "curve3d_get_points", "curve3d_sample_polyline",
				"path_get_curve_points", "path_set_curve_points",
				"bezier_list_keys_cartesian", "bezier_set_keys_batch", "bezier_sample_dense", "bezier_set_handle_mode",
				"update_property Vector*/Transform*", "describe_class",
			],
			"gaps": ["symbolic CAS — use scripts for pure math"],
		},
		"tutorials/best_practices": {
			"status": "partial",
			"tools": ["agent_workflow_guide", "analyze_*", "health_check"],
			"gaps": [],
		},
		"tutorials/migrating": {
			"status": "partial",
			"tools": [
				"get_godot_version", "search_in_files", "edit_script",
				"scan_godot3_patterns", "list_migration_replacements",
				"apply_migration_replacements", "get_migration_guide",
			],
			"gaps": ["full scene format auto-convert (use Godot project converter)"],
		},
		"classes/* (class reference)": {
			"status": "strong",
			"tools": ["describe_class", "list_classes", "list_class_methods", "list_class_signals", "list_class_properties", "list_class_constants", "get_class_inheritance"],
			"note": "Lookup of any ClassDB type — NOT a dedicated tool per method of every class",
			"gaps": ["offline docs RST text", "example snippets from docs"],
		},
	}
	var counts := {"strong": 0, "partial": 0, "thin": 0, "classdb_only": 0}
	for k in areas:
		var st: String = str(areas[k].get("status", "thin"))
		if counts.has(st):
			counts[st] = int(counts[st]) + 1
	var weighted := float(counts["strong"]) * 1.0 + float(counts["partial"]) * 0.55 + float(counts["thin"]) * 0.25 + float(counts["classdb_only"]) * 0.35
	var max_w := float(areas.size())
	return success({
		"docs_source": "https://github.com/godotengine/godot-docs",
		"areas": areas,
		"area_count": areas.size(),
		"status_counts": counts,
		"honest_depth_score_percent": round((weighted / max_w) * 1000.0) / 10.0,
		"claim": "HONEST: docs-area workflow depth is improved (many strong/partial). This is still NOT 100% of ClassDB methods, every editor dock pixel, or VisualShader/C#/console SDKs. See gaps.",
		"previous_false_claim": "Older builds reported coverage_percent:100 by counting any tool path as 'covered'. That metric is retired.",
		"sdk_note": "Full ClassDB *lookup* via describe_class; dedicated *workflow tools* track human docks, not every engine method.",
	})


func _list_surface_registry(_params: Dictionary) -> Dictionary:
	## Live inventory of registered plugin commands by module (progress registry).
	var router = get_parent()
	var all_methods: Array = []
	if router != null and router.has_method("get_available_methods"):
		all_methods = router.get_available_methods()
	all_methods.sort()
	# Group by heuristic prefixes / known modules
	var by_module := {}
	var cmd_dir := "res://addons/godot_mcp/commands"
	var dir := DirAccess.open(cmd_dir)
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while not fname.is_empty():
			if fname.ends_with(".gd") and not dir.current_is_dir():
				var path := cmd_dir.path_join(fname)
				# Count registrations by loading script is heavy; report file presence
				by_module[fname.get_basename()] = {"source": path}
			fname = dir.get_next()
		dir.list_dir_end()
	var cfg := ConfigFile.new()
	var plugin_version := "unknown"
	if cfg.load("res://addons/godot_mcp/plugin.cfg") == OK:
		plugin_version = str(cfg.get_value("plugin", "version", "unknown"))
	return success({
		"plugin_version": plugin_version,
		"command_count": all_methods.size(),
		"commands": all_methods,
		"module_files": by_module.keys(),
		"module_file_count": by_module.size(),
		"registry_doc": "SURFACE_REGISTRY.md (repo root) — regenerate via scripts/export-surface-registry.ps1",
		"honest_note": "Workflow surface inventory — not 100% ClassDB. Use list_docs_coverage for area depth/gaps.",
	})
