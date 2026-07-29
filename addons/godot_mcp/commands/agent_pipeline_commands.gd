@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Multi-step agent pipelines — compose existing tools into human production sequences.


func get_commands() -> Dictionary:
	return {
		"list_agent_pipelines": _list_pipelines,
		"pipeline_prepare_level_lighting": _pipeline_prepare_level_lighting,
		"pipeline_setup_prop_lods": _pipeline_setup_prop_lods,
		"pipeline_nav_debug_route": _pipeline_nav_debug_route,
		"pipeline_character_locomotion": _pipeline_character_locomotion,
		"pipeline_greybox_to_playable": _pipeline_greybox_to_playable,
	}


func _list_pipelines(_params: Dictionary) -> Dictionary:
	return success({
		"pipelines": {
			"pipeline_prepare_level_lighting": "UV2 batch + lightmap quality + optional bake",
			"pipeline_setup_prop_lods": "Generate LODs + distance preset on mesh",
			"pipeline_nav_debug_route": "Bake nav + query path + draw debug + enable debug",
			"pipeline_character_locomotion": "Humanoid or simple AnimationTree locomotion",
			"pipeline_greybox_to_playable": "Greybox room → collision → nav → playtest",
		},
		"hint": "Prefer pipelines for multi-dock human workflows; use atomic tools for fine control",
	})


func _router():
	return get_parent()


func _exec(method: String, params: Dictionary = {}) -> Dictionary:
	var r = _router()
	if r == null or not r.has_method("execute"):
		return {"error": {"message": "No router", "method": method}}
	var methods: Array = r.get_available_methods() if r.has_method("get_available_methods") else []
	if methods.size() > 0 and not method in methods:
		return {"error": {"message": "Command not registered: %s" % method}}
	return await r.execute(method, params)


func _pipeline_prepare_level_lighting(params: Dictionary) -> Dictionary:
	var steps: Array = []
	var quality: String = optional_string(params, "quality", "medium")
	var texel: float = float(params.get("texel_size", 0.2))

	steps.append({"batch_prepare": await _exec("batch_prepare_lightmap_meshes", {
		"node_path": optional_string(params, "node_path", "."),
		"texel_size": texel,
		"only_missing_uv2": optional_bool(params, "only_missing_uv2", true),
		"max": optional_int(params, "max", 50),
	})})
	steps.append({"quality": await _exec("apply_lightmap_quality_preset", {
		"preset": quality,
		"create_if_missing": true,
		"parent_path": optional_string(params, "parent_path", "."),
	})})
	if optional_bool(params, "request_bake", false):
		steps.append({"bake": await _exec("request_lightmap_bake", {
			"node_path": optional_string(params, "lightmap_path", ""),
		})})
	return success({
		"pipeline": "prepare_level_lighting",
		"quality": quality,
		"steps": steps,
		"next": ["playtest_report", "get_render_info"],
	})


func _pipeline_setup_prop_lods(params: Dictionary) -> Dictionary:
	var node_path_r := require_string(params, "node_path")
	if node_path_r[1] != null:
		return node_path_r[1]
	var preset: String = optional_string(params, "preset", "desktop")
	var steps: Array = []
	steps.append({"generate_lods": await _exec("mesh_generate_lods", {
		"node_path": node_path_r[0],
		"save_path": optional_string(params, "save_path", ""),
	})})
	steps.append({"distance_preset": await _exec("apply_lod_distance_preset", {
		"source_mesh_path": node_path_r[0],
		"preset": preset,
		"create_instances": optional_bool(params, "create_instances", true),
		"hide_source": optional_bool(params, "hide_source", true),
		"parent_path": optional_string(params, "parent_path", ""),
	})})
	if optional_bool(params, "shadow_mesh", false):
		steps.append({"shadow": await _exec("create_shadow_mesh", {"node_path": node_path_r[0]})})
	return success({
		"pipeline": "setup_prop_lods",
		"node_path": node_path_r[0],
		"preset": preset,
		"steps": steps,
	})


func _pipeline_nav_debug_route(params: Dictionary) -> Dictionary:
	var steps: Array = []
	var region: String = optional_string(params, "region_path", optional_string(params, "node_path", ""))
	if not region.is_empty():
		steps.append({"bake": await _exec("bake_navigation_mesh", {"node_path": region})})
	steps.append({"debug_on": await _exec("navigation_set_debug_enabled", {"enabled": true})})

	var from_v = params.get("from", null)
	var to_v = params.get("to", null)
	var path_points: Array = []
	if from_v != null and to_v != null:
		var q = await _exec("navigation_query_path", {
			"mode": optional_string(params, "mode", "3d"),
			"from": from_v,
			"to": to_v,
			"optimize": optional_bool(params, "optimize", true),
		})
		steps.append({"query": q})
		var payload = q.get("result", q)
		if payload is Dictionary and payload.has("result"):
			payload = payload["result"]
		if payload is Dictionary and payload.has("points"):
			path_points = payload["points"]
		elif payload is Dictionary and payload.has("points") == false and q is Dictionary:
			# unwrap double envelope
			var inner = q
			while inner is Dictionary and inner.has("result"):
				inner = inner["result"]
			if inner is Dictionary and inner.has("points"):
				path_points = inner["points"]

	if path_points.is_empty() and params.has("points") and params["points"] is Array:
		path_points = params["points"]

	if path_points.size() >= 2 and optional_bool(params, "draw", true):
		steps.append({"draw": await _exec("draw_debug_path", {
			"mode": optional_string(params, "mode", "3d"),
			"points": path_points,
			"parent_path": optional_string(params, "parent_path", "."),
			"name": optional_string(params, "name", "NavDebugRoute"),
		})})

	return success({
		"pipeline": "nav_debug_route",
		"point_count": path_points.size(),
		"steps": steps,
		"hint": "Play scene for accurate NavigationServer maps after bake",
	})


func _pipeline_character_locomotion(params: Dictionary) -> Dictionary:
	var steps: Array = []
	var parent_path: String = optional_string(params, "parent_path", ".")
	var anim_player: String = optional_string(params, "anim_player", "")
	var style: String = optional_string(params, "style", "state_machine")  # state_machine | blend1d

	if style == "blend1d" or style == "blend_space_1d":
		steps.append({"tree": await _exec("create_blend_space_1d_locomotion", {
			"parent_path": parent_path,
			"anim_player": anim_player,
			"idle": optional_string(params, "idle", "Idle"),
			"walk": optional_string(params, "walk", "Walk"),
			"run": optional_string(params, "run", "Run"),
			"active": optional_bool(params, "active", true),
		})})
	else:
		steps.append({"tree": await _exec("create_simple_locomotion_tree", {
			"parent_path": parent_path,
			"anim_player": anim_player,
			"idle": optional_string(params, "idle", "Idle"),
			"walk": optional_string(params, "walk", "Walk"),
			"run": optional_string(params, "run", "Run"),
			"jump": optional_string(params, "jump", ""),
			"xfade_time": float(params.get("xfade_time", 0.15)),
			"active": optional_bool(params, "active", true),
		})})

	if optional_bool(params, "export_graph", false):
		# Try to find tree path from last step — agent can re-export by path
		steps.append({"hint": "export_animation_tree_graph on the created tree path"})

	return success({
		"pipeline": "character_locomotion",
		"style": style,
		"steps": steps,
		"next": ["travel_animation_state", "playtest_sequence", "apply_example_animation"],
	})


func _pipeline_greybox_to_playable(params: Dictionary) -> Dictionary:
	## Greybox room → optional CSG bake → collision on meshes → nav bake → playtest.
	var steps: Array = []
	var parent_path: String = optional_string(params, "parent_path", ".")
	var size = params.get("size", {"x": 10, "y": 3, "z": 10})

	steps.append({"greybox": await _exec("greybox_room", {
		"parent_path": parent_path,
		"size": size,
		"name": optional_string(params, "name", "GreyboxRoom"),
	})})

	if optional_bool(params, "bake_csg", false):
		# Agent may pass csg_path; otherwise skip
		var csg_path: String = optional_string(params, "csg_path", "")
		if not csg_path.is_empty():
			steps.append({"csg_bake": await _exec("csg_bake_to_mesh_instance", {
				"node_path": csg_path,
				"add_collision": true,
			})})

	var mesh_path: String = optional_string(params, "mesh_path", "")
	if not mesh_path.is_empty() and optional_bool(params, "add_collision", true):
		steps.append({"collision": await _exec("mesh_create_trimesh_static_body", {
			"node_path": mesh_path,
		})})

	if optional_bool(params, "setup_nav", true):
		steps.append({"nav_region": await _exec("setup_navigation_region", {
			"node_path": parent_path,
			"mode": "3d",
		})})
		# bake if we can find region — best effort via optional path
		var region_path: String = optional_string(params, "region_path", "")
		if not region_path.is_empty():
			steps.append({"nav_bake": await _exec("bake_navigation_mesh", {"node_path": region_path})})

	if optional_bool(params, "playtest", true):
		steps.append({"playtest": await _exec("playtest_report", {
			"mode": optional_string(params, "play_mode", "current"),
			"settle_sec": float(params.get("settle_sec", 1.0)),
			"screenshot": optional_bool(params, "screenshot", true),
		})})

	return success({
		"pipeline": "greybox_to_playable",
		"steps": steps,
		"next": ["validate_level_playable", "pipeline_prepare_level_lighting", "pipeline_nav_debug_route"],
	})
