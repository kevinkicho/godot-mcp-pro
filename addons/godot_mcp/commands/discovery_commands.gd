@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Agent discovery plane — domain index, search, examples (Wave 1).


func get_commands() -> Dictionary:
	return {
		"list_agent_domains": _list_agent_domains,
		"list_tools_by_domain": _list_tools_by_domain,
		"search_mcp_tools": _search_mcp_tools,
		"get_tool_examples": _get_tool_examples,
		"get_agent_capability_map": _get_agent_capability_map,
		"list_discovery_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"purpose": "Make 1000+ plugin commands discoverable for agents",
		"flow": [
			"list_agent_domains",
			"list_tools_by_domain domain=playtest",
			"get_tool_examples tool=playtest_sequence",
			"search_mcp_tools query=collision",
		],
	})


func _domains() -> Dictionary:
	## domain -> {description, example_tools, workflow}
	return {
		"agent": {
			"description": "Session readiness, workflows, coverage",
			"examples": ["health_check", "agent_ensure_ready", "agent_workflow_guide", "list_docs_coverage", "batch_call_editor"],
			"workflow": "agent_ensure_ready → agent_workflow_guide → work → playtest",
		},
		"inspector": {
			"description": "Full numerical inspector / properties / signals",
			"examples": ["list_property_info", "update_property", "update_properties", "inspect_node", "call_node_method"],
			"workflow": "select_nodes → list_property_info recurse_resources → update_property → save_scene",
		},
		"scene": {
			"description": "Scene tree, nodes, open/save",
			"examples": ["create_scene", "add_node", "get_scene_tree", "open_scene", "save_scene"],
			"workflow": "create_scene → add_node → update_property → save_scene",
		},
		"script": {
			"description": "GDScript/C# create edit validate",
			"examples": ["create_script", "edit_script", "attach_script", "validate_script"],
			"workflow": "create_script → attach_script → validate_script → reload if needed",
		},
		"assets": {
			"description": "Import, stage files, reimport",
			"examples": ["stage_files_into_res", "ensure_imported", "list_import_option_schema", "apply_import_schema_preset"],
			"workflow": "stage_files_into_res → ensure_imported → apply_import_schema_preset → reimport",
		},
		"animation": {
			"description": "AnimationPlayer, Tree, Bezier, transfer, libraries",
			"examples": ["apply_example_animation", "create_simple_locomotion_tree", "bezier_set_keys_batch", "dump_animation"],
			"workflow": "extract/dump example → apply_example_animation → remap paths → playtest",
		},
		"humanoid": {
			"description": "Characters, bone maps, retarget, interaction",
			"examples": ["setup_humanoid_actor", "create_bone_map_preset", "pipeline_character_from_gltf", "generate_ragdoll_from_skeleton"],
			"workflow": "import glTF → bone map → locomotion tree → interact zones → playtest",
		},
		"level": {
			"description": "Greybox, GridMap, terrain, streaming, CSG",
			"examples": ["greybox_room", "gridmap_fill_rect", "create_heightmap_terrain", "csg_bake_to_mesh_instance"],
			"workflow": "greybox → collision → nav bake → lighting → playtest",
		},
		"physics": {
			"description": "Bodies, collision, joints, raycast, ragdoll, vehicle",
			"examples": ["mesh_create_trimesh_static_body", "setup_collision", "set_hinge_joint_limits", "editor_raycast"],
			"workflow": "setup body → collision shapes → layers → playtest_report",
		},
		"playtest": {
			"description": "Play, input, screenshots, asserts, fix loops",
			"examples": ["playtest_report", "playtest_sequence", "playtest_fix_loop", "simulate_action", "get_game_screenshot"],
			"workflow": "playtest_report → on fail playtest_fix_loop or sequence asserts → fix → repeat",
		},
		"rendering": {
			"description": "GI, lightmaps, LOD, environment, decals",
			"examples": ["pipeline_prepare_level_lighting", "mesh_generate_lods", "apply_environment_preset", "configure_sdfgi"],
			"workflow": "UV2 unwrap → lightmap quality → bake / SDFGI → LOD",
		},
		"ui": {
			"description": "Controls, theme, StyleBox, containers, lists",
			"examples": ["setup_tab_container", "create_stylebox_flat", "theme_set_type_color", "setup_label"],
			"workflow": "create_theme → styleboxes → assign_theme → layout containers",
		},
		"audio": {
			"description": "Buses, players, music, generator",
			"examples": ["create_music_controller_script", "setup_audio_stream_generator", "add_audio_bus"],
			"workflow": "buses → players → music controller",
		},
		"navigation": {
			"description": "Navmesh bake, agents, path debug",
			"examples": ["bake_navigation_mesh", "navigation_live_path", "setup_navigation_agent"],
			"workflow": "region → bake → agent → query path → draw debug",
		},
		"multiplayer": {
			"description": "Spawn, sync, RPC, interest, WebRTC recipes",
			"examples": ["setup_multiplayer_spawner", "create_interest_manager_script", "list_webrtc_recipes"],
			"workflow": "templates → spawner/sync → interest → playtest host/join",
		},
		"export": {
			"description": "Presets, run export, signing checklist",
			"examples": ["verify_export_ready", "get_export_signing_checklist", "run_export"],
			"workflow": "verify_export_ready → signing checklist → run_export",
		},
		"i18n": {
			"description": "Extract strings, CSV/POT, locale",
			"examples": ["extract_strings_from_open_scene", "export_translation_csv", "set_locale"],
			"workflow": "extract → CSV → translate → import → set_locale",
		},
		"shaders": {
			"description": "Text shaders, includes, VisualShader, VFX",
			"examples": ["create_shader", "create_shader_include_library_preset", "visual_shader_add_preset_pbr"],
			"workflow": "include library → create_shader → assign_shader_material",
		},
		"classdb": {
			"description": "Full engine API lookup escape hatch",
			"examples": ["describe_class", "list_class_methods", "list_class_properties", "execute_editor_script"],
			"workflow": "describe_class → call_node_method or execute_editor_script",
		},
		"discovery": {
			"description": "Find tools and examples",
			"examples": ["list_agent_domains", "search_mcp_tools", "list_mcp_commands", "get_tool_examples"],
			"workflow": "list_agent_domains → list_tools_by_domain → get_tool_examples",
		},
		"project_structure": {
			"description": "Autoloads, groups, layer names, unique names, preload registry",
			"examples": ["list_autoloads", "set_physics_layer_names", "find_nodes_in_group", "batch_set_scene_unique_names", "create_resource_registry_script"],
			"workflow": "scaffold_project_defaults → layer names → groups → autoloads → unique names",
		},
		"2d": {
			"description": "2D masterpiece production: cameras, lights, tiles, pixel presets, Skeleton2D, MeshInstance2D",
			"examples": [
				"pipeline_2d_pixel_game",
				"pipeline_2d_tilemap_level",
				"apply_pixel_2d_project_preset",
				"setup_skeleton_2d",
				"setup_two_bone_ik_2d",
				"setup_mesh_instance_2d",
				"setup_tilemap_layer_stack",
				"tileset_add_scenes_collection_source",
				"tilemap_stamp_pattern",
				"setup_canvas_draw_node",
				"setup_camera_2d",
				"setup_canvas_modulate",
			],
			"workflow": "pipeline_2d_pixel_game → tilemap stack → character/shapes → skeleton2d IK → lights/draw → playtest",
		},
		"shapes": {
			"description": "Shape2D/Shape3D resources and collision assignment",
			"examples": ["create_shape_resource", "setup_collision_from_shape_resource", "assign_shape_to_collision"],
			"workflow": "create_shape_resource → setup_collision_from_shape_resource / assign_shape_to_collision",
		},
		"viewports": {
			"description": "SubViewport minimaps, ViewportTexture, BackBufferCopy",
			"examples": ["setup_subviewport_2d_world", "setup_viewport_texture_rect", "setup_back_buffer_copy"],
			"workflow": "setup_subviewport_2d_world → setup_viewport_texture_rect on HUD",
		},
		"pathfinding": {
			"description": "AStarGrid2D / AStar2D/3D point graphs (grid games)",
			"examples": ["setup_astar_grid_controller", "create_astar_grid_2d_script", "create_astar_point_graph_script"],
			"workflow": "setup_astar_grid_controller → set_solid from tiles → find_path_world",
		},
		"materials": {
			"description": "StandardMaterial3D / ORM PBR authoring",
			"examples": ["create_standard_material_3d", "set_standard_material_params", "assign_material_3d_to_mesh"],
			"workflow": "create_standard_material_3d → assign_material_3d_to_mesh",
		},
		"character": {
			"description": "CharacterBody2D/3D motion presets and TPS camera rigs",
			"examples": ["apply_character_body_preset", "set_character_body_motion", "setup_third_person_camera_rig", "pipeline_3d_character_tps"],
			"workflow": "setup_character_3d → apply_character_body_preset → setup_third_person_camera_rig",
		},
		"environment": {
			"description": "Environment, Sky, FogVolume resources",
			"examples": ["create_environment_resource", "create_procedural_sky", "setup_fog_volume", "assign_environment_to_world"],
			"workflow": "create_procedural_sky → create_environment_resource → assign_environment_to_world",
		},
		"scene_pack": {
			"description": "Pack branch as scene, inherited scenes, replace with instance",
			"examples": ["pack_node_as_scene", "pack_selection_as_scene", "create_inherited_scene_from"],
			"workflow": "build under open scene → pack_node_as_scene → instance elsewhere",
		},
		"collision_layers": {
			"description": "Named physics layer bits (human layer names)",
			"examples": ["set_collision_layers_by_name", "set_collision_mask_by_name", "get_collision_layers_named"],
			"workflow": "set_physics_layer_names → set_collision_layers_by_name layers=[player]",
		},
		"game_loop": {
			"description": "Main menu, pause, scene flow, save slots",
			"examples": ["pipeline_game_loop_shell", "setup_main_menu_scene", "create_game_flow_controller_script", "write_save_slot_json"],
			"workflow": "pipeline_game_loop_shell → wire pause menu → save/load slots",
		},
		"save": {
			"description": "Capture/apply node state and JSON save slots",
			"examples": ["capture_scene_state", "write_save_slot_json", "create_game_state_serializer_script", "read_save_slot_json"],
			"workflow": "capture_scene_state → write_save_slot_json → read → apply_node_state",
		},
		"inventory": {
			"description": "ItemData + InventoryComponent recipes",
			"examples": ["create_inventory_component_script", "create_item_resource", "setup_inventory_ui"],
			"workflow": "create_item_resource → create_inventory_component_script → attach to player",
		},
		"xr": {
			"description": "OpenXR rig, movement, grab, teleport, passthrough",
			"examples": ["pipeline_xr_setup", "setup_xr_player_rig", "create_xr_movement_script", "list_xr_tools_catalog"],
			"workflow": "pipeline_xr_setup → openxr bindings → play on device",
		},
		"visual_shader": {
			"description": "VisualShader catalog + graph presets",
			"examples": ["list_visual_shader_node_catalog", "visual_shader_preset_toon", "visual_shader_add_nodes_batch"],
			"workflow": "create_visual_shader → preset or batch nodes → assign_visual_shader_material",
		},
		"export_ci": {
			"description": "Export presets + GitHub Actions + headless scripts",
			"examples": ["pipeline_export_ci", "create_github_actions_godot_export", "create_export_presets_pack"],
			"workflow": "pipeline_export_ci → verify templates → run_export",
		},
		"migration": {
			"description": "Godot 3→4 scan/report (not full scene converter)",
			"examples": ["scan_project_migration_report", "scan_tscn_godot3_markers", "apply_migration_replacements"],
			"workflow": "scan_project_migration_report → apply_migration_replacements dry_run → playtest",
		},
		"closure": {
			"description": "Production surface completeness and out-of-scope honesty",
			"examples": ["get_production_surface_report", "list_out_of_scope_surfaces", "list_docs_coverage"],
			"workflow": "get_production_surface_report → list_out_of_scope_surfaces",
		},
	}


func _list_agent_domains(_params: Dictionary) -> Dictionary:
	var d := _domains()
	var out: Array = []
	for k in d.keys():
		out.append({
			"domain": k,
			"description": d[k].get("description", ""),
			"workflow": d[k].get("workflow", ""),
			"example_count": (d[k].get("examples", []) as Array).size(),
		})
	out.sort_custom(func(a, b): return str(a.get("domain")) < str(b.get("domain")))
	return success({
		"domains": out,
		"count": out.size(),
		"hint": "list_tools_by_domain domain=<name>; get_agent_capability_map for full matrix",
	})


func _list_tools_by_domain(params: Dictionary) -> Dictionary:
	var domain: String = optional_string(params, "domain", "").to_lower()
	if domain.is_empty():
		return error_invalid_params("domain required — list_agent_domains")
	var d := _domains()
	if not d.has(domain):
		# fuzzy
		for k in d.keys():
			if str(k).contains(domain) or domain.contains(str(k)):
				domain = k
				break
	if not d.has(domain):
		return error_not_found("domain '%s'" % domain)
	var router = get_parent()
	var registered: Array = []
	if router and router.has_method("get_available_methods"):
		registered = router.get_available_methods()
	var examples: Array = d[domain].get("examples", [])
	# Also scan registered by keywords
	var keywords: Array = [domain]
	match domain:
		"playtest":
			keywords = ["playtest", "simulate", "screenshot", "assert", "run_session", "play_"]
		"inspector":
			keywords = ["property", "inspect", "meta", "signal", "select_node"]
		"humanoid":
			keywords = ["humanoid", "bone_map", "ragdoll", "locomotion", "skeleton"]
		"level":
			keywords = ["greybox", "gridmap", "terrain", "stream_", "csg_", "level_"]
		"assets":
			keywords = ["import", "stage_files", "ensure_imported", "reimport"]
		"rendering":
			keywords = ["lightmap", "sdfgi", "lod", "environment", "decal", "gi_"]
		"discovery":
			keywords = ["list_agent", "search_mcp", "list_mcp", "get_tool", "list_docs"]
		"2d":
			keywords = [
				"skeleton_2d", "bone_2d", "two_bone_ik", "mesh_instance_2d", "mesh_2d",
				"pixel_2d", "tilemap", "tileset", "camera_2d", "light_2d", "parallax",
				"sprite_frames", "canvas_modulate", "polygon_2d",
			]
	var matched: Array = []
	for m in registered:
		var n := str(m).to_lower()
		for kw in keywords:
			if n.contains(str(kw).to_lower()):
				matched.append(str(m))
				break
	matched.sort()
	return success({
		"domain": domain,
		"description": d[domain].get("description", ""),
		"workflow": d[domain].get("workflow", ""),
		"canonical_examples": examples,
		"matched_commands": matched.slice(0, mini(80, matched.size())),
		"matched_count": matched.size(),
		"truncated": matched.size() > 80,
	})


func _search_mcp_tools(params: Dictionary) -> Dictionary:
	var q: String = optional_string(params, "query", "").to_lower()
	if q.is_empty():
		return error_invalid_params("query required")
	var router = get_parent()
	if router == null or not router.has_method("get_available_methods"):
		return error_internal("No command router")
	var methods: Array = router.get_available_methods()
	var hits: Array = []
	var max_n: int = clampi(optional_int(params, "max", 40), 1, 200)
	var terms := q.split(" ", false)
	for m in methods:
		var n := str(m).to_lower()
		var ok := true
		for t in terms:
			if not n.contains(str(t)):
				ok = false
				break
		if ok:
			hits.append(str(m))
		if hits.size() >= max_n:
			break
	return success({"query": q, "matches": hits, "count": hits.size()})


func _get_tool_examples(params: Dictionary) -> Dictionary:
	var tool: String = optional_string(params, "tool", optional_string(params, "name", ""))
	if tool.is_empty():
		return error_invalid_params("tool name required")
	var catalog := _example_catalog()
	if catalog.has(tool):
		return success({"tool": tool, "examples": catalog[tool]})
	# Partial match
	var partial: Array = []
	for k in catalog.keys():
		if str(k).contains(tool) or tool.contains(str(k)):
			partial.append({"tool": k, "examples": catalog[k]})
	if partial.size() > 0:
		return success({"tool": tool, "partial_matches": partial.slice(0, 10)})
	return success({
		"tool": tool,
		"examples": [{
			"params": {},
			"note": "No curated example — use call_editor method=%s with params from list_mcp_commands / describe usage in skill" % tool,
		}],
		"hint": "call_editor method='%s' params={...}" % tool,
	})


func _example_catalog() -> Dictionary:
	return {
		"health_check": [{"params": {}, "why": "Confirm plugin + MCP link"}],
		"agent_ensure_ready": [{"params": {"project_path": "C:/game", "ensure_runtime_autoloads": true}, "why": "Session start"}],
		"playtest_report": [{"params": {"mode": "main", "settle_sec": 1.5, "screenshot": true}, "why": "Hit Play + errors"}],
		"playtest_sequence": [{"params": {
			"mode": "main",
			"steps": [
				{"type": "wait", "sec": 0.5},
				{"type": "action", "action": "ui_accept", "pressed": true, "auto_release": true},
				{"type": "assert", "node_path": "Player", "property": "visible"},
			],
		}, "why": "Interactive playtest"}],
		"playtest_fix_loop": [{"params": {"max_attempts": 3, "mode": "main"}, "why": "Play → fail → report for agent fix"}],
		"update_property": [{"params": {"node_path": "Player", "property": "position", "value": {"x": 0, "y": 1, "z": 0}}, "why": "Inspector number write"}],
		"list_property_info": [{"params": {"node_path": "Player", "recurse_resources": true}, "why": "Discover all tunable fields"}],
		"mesh_create_trimesh_static_body": [{"params": {"node_path": "Level/MeshInstance3D"}, "why": "Mesh menu collision"}],
		"pipeline_prepare_level_lighting": [{"params": {"quality": "medium", "request_bake": false}, "why": "UV2 + LightmapGI pack"}],
		"generate_ragdoll_from_skeleton": [{"params": {"node_path": "Player/Skeleton3D"}, "why": "Auto PhysicalBones"}],
		"setup_interaction_zone": [{"params": {"kind": "talk", "radius": 1.5, "is_3d": true}, "why": "NPC interact"}],
		"extract_strings_from_open_scene": [{"params": {}, "why": "i18n extract"}],
		"create_shader_include_library_preset": [{"params": {}, "why": "Shared shader includes"}],
		"call_editor": [{"params": {"method": "list_mcp_commands", "params": {"surface": "animation"}}, "why": "Invoke any registered method in lite mode"}],
		"batch_call_editor": [{"params": {"calls": [{"method": "get_scene_tree", "params": {}}, {"method": "save_scene", "params": {}}]}, "why": "Multi-step dock work"}],
		"pipeline_character_from_gltf": [{"params": {"gltf_path": "res://models/hero.glb", "parent_path": "."}, "why": "Import → humanoid → locomotion"}],
		"analyze_performance_budget": [{"params": {"max_nodes": 5000, "max_draw_calls_hint": 500}, "why": "Perf budget report"}],
	}


func _get_agent_capability_map(_params: Dictionary) -> Dictionary:
	var d := _domains()
	var router = get_parent()
	var total := 0
	if router and router.has_method("get_available_methods"):
		total = router.get_available_methods().size()
	return success({
		"principle": "100% agent production surfacing = workflows + discovery + ClassDB escape hatches — not one tool per ClassDB method",
		"registered_commands": total,
		"domains": d,
		"universal_escape_hatches": [
			"call_editor / batch_call_editor",
			"describe_class / list_class_*",
			"call_node_method / list_node_methods",
			"list_property_info / update_property",
			"execute_editor_script",
		],
		"start_here": ["list_agent_domains", "agent_workflow_guide", "health_check"],
	})
