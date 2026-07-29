@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SDFGI / SSAO / SSR / glow / lightmap mesh flags — rendering docs depth.


func get_commands() -> Dictionary:
	return {
		"configure_sdfgi": _configure_sdfgi,
		"configure_ssao": _configure_ssao,
		"configure_ssr": _configure_ssr,
		"configure_glow": _configure_glow,
		"configure_ssil": _configure_ssil,
		"set_mesh_lightmap_params": _set_mesh_lightmap_params,
		"list_gi_tools": _list_gi_tools,
	}


func _list_gi_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": [
			"configure_sdfgi", "configure_ssao", "configure_ssr", "configure_glow", "configure_ssil",
			"set_mesh_lightmap_params", "add_voxel_gi", "bake_voxel_gi", "add_lightmap_gi",
			"request_lightmap_bake", "setup_compositor", "add_compositor_effect",
			"apply_environment_preset",
		],
		"flow_sdfgi": ["setup_world_environment / apply_environment_preset", "configure_sdfgi enabled=true"],
		"flow_lightmap": ["set_mesh_lightmap_params on MeshInstance3D", "add_lightmap_gi", "request_lightmap_bake"],
	})


func _find_env(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return {"error": error_no_scene()}
	var path: String = optional_string(params, "node_path", "")
	var we: WorldEnvironment = null
	if not path.is_empty():
		var n := find_node_by_path(path)
		if n is WorldEnvironment:
			we = n
		elif n and "environment" in n and n.get("environment") is Environment:
			return {"root": root, "env": n.get("environment") as Environment, "owner": n}
	if we == null:
		we = _find_we(root)
	if we == null:
		return {"error": error_not_found("WorldEnvironment — use setup_world_environment or apply_environment_preset")}
	if we.environment == null:
		we.environment = Environment.new()
	return {"root": root, "env": we.environment, "owner": we, "we": we}


func _find_we(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for c in node.get_children():
		var f := _find_we(c)
		if f:
			return f
	return null


func _configure_sdfgi(params: Dictionary) -> Dictionary:
	var found := _find_env(params)
	if found.has("error"):
		return found["error"]
	var env: Environment = found["env"]
	env.sdfgi_enabled = optional_bool(params, "enabled", true)
	if params.has("use_occlusion"):
		env.sdfgi_use_occlusion = bool(params["use_occlusion"])
	if params.has("read_sky_light"):
		env.sdfgi_read_sky_light = bool(params["read_sky_light"])
	if params.has("bounce_feedback"):
		env.sdfgi_bounce_feedback = float(params["bounce_feedback"])
	if params.has("energy"):
		env.sdfgi_energy = float(params["energy"])
	if params.has("normal_bias"):
		env.sdfgi_normal_bias = float(params["normal_bias"])
	if params.has("probe_bias"):
		env.sdfgi_probe_bias = float(params["probe_bias"])
	# Cascades / min cell size when available
	for key in ["cascades", "min_cell_size", "cascade0_distance", "max_distance", "y_scale"]:
		var prop := "sdfgi_" + key
		if params.has(key) and prop in env:
			env.set(prop, params[key])
	mark_current_scene_unsaved()
	return success({
		"sdfgi_enabled": env.sdfgi_enabled,
		"owner": str(found["root"].get_path_to(found["owner"])),
		"hint": "SDFGI is real-time; works best Forward+/Mobile with suitable geometry scale",
	})


func _configure_ssao(params: Dictionary) -> Dictionary:
	var found := _find_env(params)
	if found.has("error"):
		return found["error"]
	var env: Environment = found["env"]
	env.ssao_enabled = optional_bool(params, "enabled", true)
	if params.has("radius"):
		env.ssao_radius = float(params["radius"])
	if params.has("intensity"):
		env.ssao_intensity = float(params["intensity"])
	if params.has("power"):
		env.ssao_power = float(params["power"])
	if params.has("detail"):
		env.ssao_detail = float(params["detail"])
	if params.has("horizon"):
		env.ssao_horizon = float(params["horizon"])
	if params.has("sharpness"):
		env.ssao_sharpness = float(params["sharpness"])
	mark_current_scene_unsaved()
	return success({"ssao_enabled": env.ssao_enabled, "intensity": env.ssao_intensity})


func _configure_ssr(params: Dictionary) -> Dictionary:
	var found := _find_env(params)
	if found.has("error"):
		return found["error"]
	var env: Environment = found["env"]
	env.ssr_enabled = optional_bool(params, "enabled", true)
	if params.has("max_steps"):
		env.ssr_max_steps = int(params["max_steps"])
	if params.has("fade_in"):
		env.ssr_fade_in = float(params["fade_in"])
	if params.has("fade_out"):
		env.ssr_fade_out = float(params["fade_out"])
	if params.has("depth_tolerance"):
		env.ssr_depth_tolerance = float(params["depth_tolerance"])
	mark_current_scene_unsaved()
	return success({"ssr_enabled": env.ssr_enabled})


func _configure_glow(params: Dictionary) -> Dictionary:
	var found := _find_env(params)
	if found.has("error"):
		return found["error"]
	var env: Environment = found["env"]
	env.glow_enabled = optional_bool(params, "enabled", true)
	for key in ["intensity", "strength", "bloom", "hdr_threshold", "hdr_scale", "hdr_luminance_cap", "mix"]:
		if params.has(key):
			var prop := "glow_" + key
			if prop in env:
				env.set(prop, float(params[key]))
	mark_current_scene_unsaved()
	return success({"glow_enabled": env.glow_enabled, "intensity": env.glow_intensity})


func _configure_ssil(params: Dictionary) -> Dictionary:
	var found := _find_env(params)
	if found.has("error"):
		return found["error"]
	var env: Environment = found["env"]
	if not ("ssil_enabled" in env):
		return error_internal("SSIL not available in this Godot build")
	env.ssil_enabled = optional_bool(params, "enabled", true)
	if params.has("radius") and "ssil_radius" in env:
		env.ssil_radius = float(params["radius"])
	if params.has("intensity") and "ssil_intensity" in env:
		env.ssil_intensity = float(params["intensity"])
	mark_current_scene_unsaved()
	return success({"ssil_enabled": env.ssil_enabled})


func _set_mesh_lightmap_params(params: Dictionary) -> Dictionary:
	## Set GI / lightmap-related flags on MeshInstance3D for bake readiness.
	var r := require_string(params, "node_path")
	if r[1] != null:
		return r[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r[0])
	if node == null or not (node is MeshInstance3D):
		return error_not_found("MeshInstance3D at '%s'" % r[0])
	var mi: MeshInstance3D = node
	var applied := {}
	if params.has("gi_mode"):
		# 0 disabled, 1 static, 2 dynamic — GeometryInstance3D.GIMode
		var mode = params["gi_mode"]
		if mode is String:
			match str(mode).to_lower():
				"disabled": mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				"static": mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
				"dynamic": mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
				_: pass
		else:
			mi.gi_mode = int(mode) as GeometryInstance3D.GIMode
		applied["gi_mode"] = mi.gi_mode
	if params.has("cast_shadow"):
		mi.cast_shadow = int(params["cast_shadow"]) as GeometryInstance3D.ShadowCastingSetting
		applied["cast_shadow"] = mi.cast_shadow
	if params.has("lightmap_scale") and "lightmap_scale" in mi:
		mi.set("lightmap_scale", int(params["lightmap_scale"]))
		applied["lightmap_scale"] = mi.get("lightmap_scale")
	# UV2 unwrap is editor-heavy; surface best-effort
	var unwrap: bool = optional_bool(params, "request_uv2_unwrap", false)
	var unwrap_note := ""
	if unwrap and mi.mesh:
		if mi.has_method("lightmap_unwrap"):
			# Some versions expose on MeshInstance
			mi.call("lightmap_unwrap", mi.global_transform, float(params.get("texel_size", 0.1)))
			unwrap_note = "called lightmap_unwrap"
		elif mi.mesh.has_method("lightmap_unwrap"):
			mi.mesh.call("lightmap_unwrap", mi.global_transform, float(params.get("texel_size", 0.1)))
			unwrap_note = "called mesh.lightmap_unwrap"
		else:
			unwrap_note = "UV2 unwrap not available via API — use Mesh menu Lightmap Unwrap in editor"
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(mi)),
		"applied": applied,
		"uv2": unwrap_note,
		"hint": "Then add_lightmap_gi + request_lightmap_bake",
	})
