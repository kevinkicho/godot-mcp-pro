@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Named LOD distance bands + LightmapGI quality packs for agent one-shots.


func get_commands() -> Dictionary:
	return {
		"list_quality_presets": _list_quality_presets,
		"apply_lod_distance_preset": _apply_lod_distance_preset,
		"apply_lightmap_quality_preset": _apply_lightmap_quality_preset,
		"configure_lightmap_gi": _configure_lightmap_gi,
		"apply_platform_render_pack": _apply_platform_render_pack,
	}


func _list_quality_presets(_params: Dictionary) -> Dictionary:
	return success({
		"lod_distance_presets": {
			"mobile": [0.0, 8.0, 20.0, 40.0],
			"desktop": [0.0, 15.0, 40.0, 80.0],
			"cinematic": [0.0, 25.0, 60.0, 120.0],
			"dense_city": [0.0, 10.0, 25.0, 50.0, 100.0],
		},
		"lightmap_quality_presets": ["draft", "medium", "high", "ultra", "mobile"],
		"platform_packs": ["mobile", "desktop", "high_end"],
		"tools": get_commands().keys(),
		"related": ["mesh_generate_lods", "setup_lod_mesh_instances", "lightmap_bake_prepare", "configure_sdfgi"],
	})


func _preset_distances(name: String) -> Array:
	match name.to_lower():
		"mobile":
			return [0.0, 8.0, 20.0, 40.0]
		"cinematic":
			return [0.0, 25.0, 60.0, 120.0]
		"dense_city", "city":
			return [0.0, 10.0, 25.0, 50.0, 100.0]
		_:
			return [0.0, 15.0, 40.0, 80.0]  # desktop default


func _apply_lod_distance_preset(params: Dictionary) -> Dictionary:
	## Apply named distance bands via setup_lod_mesh_instances or set_visibility_range on existing LODs.
	var preset: String = optional_string(params, "preset", "desktop")
	var distances: Array = params.get("distances", _preset_distances(preset))
	var source: String = optional_string(params, "source_mesh_path", optional_string(params, "node_path", ""))
	var parent_path: String = optional_string(params, "parent_path", "")

	if source.is_empty():
		return error_invalid_params("source_mesh_path or node_path required")

	var router = get_parent()
	if router == null or not router.has_method("execute"):
		return error_internal("No command router")

	# Prefer discrete LOD instances
	if optional_bool(params, "create_instances", true):
		if parent_path.is_empty():
			var mi := find_node_by_path(source)
			parent_path = str(get_edited_root().get_path_to(mi.get_parent())) if mi and mi.get_parent() else "."
		var res = await router.execute("setup_lod_mesh_instances", {
			"parent_path": parent_path,
			"source_mesh_path": source,
			"distances": distances,
			"hide_source": optional_bool(params, "hide_source", true),
		})
		return success({
			"preset": preset,
			"distances": distances,
			"mode": "lod_instances",
			"result": res,
		})

	# Single mesh: set end range to last band (cull far)
	var end_d: float = float(distances[distances.size() - 1]) if distances.size() > 0 else 80.0
	var res2 = await router.execute("set_visibility_range", {
		"node_path": source,
		"begin": 0.0,
		"end": end_d,
		"begin_margin": 1.0,
		"end_margin": 2.0,
	})
	# Also try generate_lods
	var lod_gen = await router.execute("mesh_generate_lods", {"node_path": source})
	return success({
		"preset": preset,
		"distances": distances,
		"mode": "single_mesh",
		"visibility": res2,
		"generate_lods": lod_gen,
	})


func _apply_lightmap_quality_preset(params: Dictionary) -> Dictionary:
	var preset: String = optional_string(params, "preset", "medium").to_lower()
	var node_path: String = optional_string(params, "node_path", "")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var gi: LightmapGI = null
	if not node_path.is_empty():
		var n := find_node_by_path(node_path)
		if n is LightmapGI:
			gi = n as LightmapGI
	if gi == null:
		gi = _find_gi(root)
	if gi == null and optional_bool(params, "create_if_missing", true):
		gi = LightmapGI.new()
		gi.name = optional_string(params, "name", "LightmapGI")
		var parent := find_node_by_path(optional_string(params, "parent_path", "."))
		if parent == null:
			parent = root
		add_child_with_undo(parent, gi, root, "MCP: LightmapGI quality preset")
	if gi == null:
		return error_not_found("LightmapGI — pass create_if_missing or add_lightmap_gi first")

	var applied := _apply_gi_preset(gi, preset)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(gi)),
		"preset": preset,
		"applied": applied,
		"hint": "lightmap_bake_prepare then request_lightmap_bake",
	})


func _apply_gi_preset(gi: LightmapGI, preset: String) -> Dictionary:
	var applied := {}
	# Quality enum: LOW=0 MEDIUM=1 HIGH=2 ULTRA=3 (Godot 4)
	var quality := 1
	var bounces := 3
	var denoiser := true
	var directional := false
	var bias := 0.0005
	var max_tex := 16384
	match preset:
		"draft", "low", "preview":
			quality = 0
			bounces = 1
			denoiser = false
			max_tex = 2048
		"mobile":
			quality = 0
			bounces = 2
			denoiser = true
			max_tex = 4096
		"high":
			quality = 2
			bounces = 3
			denoiser = true
			directional = true
			max_tex = 16384
		"ultra", "cinematic":
			quality = 3
			bounces = 4
			denoiser = true
			directional = true
			max_tex = 16384
		_:  # medium
			quality = 1
			bounces = 3
			denoiser = true
			max_tex = 8192

	if "quality" in gi:
		gi.set("quality", quality)
		applied["quality"] = quality
	if "bounces" in gi:
		gi.set("bounces", bounces)
		applied["bounces"] = bounces
	if "use_denoiser" in gi:
		gi.set("use_denoiser", denoiser)
		applied["use_denoiser"] = denoiser
	if "directional" in gi:
		gi.set("directional", directional)
		applied["directional"] = directional
	if "bias" in gi:
		gi.set("bias", bias)
		applied["bias"] = bias
	if "max_texture_size" in gi:
		gi.set("max_texture_size", max_tex)
		applied["max_texture_size"] = max_tex
	return applied


func _configure_lightmap_gi(params: Dictionary) -> Dictionary:
	## Fine-grained LightmapGI property setter.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var path: String = optional_string(params, "node_path", "")
	var gi: LightmapGI = null
	if not path.is_empty():
		var n := find_node_by_path(path)
		if n is LightmapGI:
			gi = n as LightmapGI
	else:
		gi = _find_gi(root)
	if gi == null:
		return error_not_found("LightmapGI")
	var applied := {}
	for key in ["quality", "bounces", "bounce_indirect_energy", "directional", "use_denoiser",
			"bias", "max_texture_size", "interior", "use_texture_for_bounces", "denoiser_strength",
			"denoiser_range", "environment_mode"]:
		if params.has(key) and key in gi:
			gi.set(key, params[key])
			applied[key] = gi.get(key)
	if applied.is_empty() and params.has("preset"):
		applied = _apply_gi_preset(gi, str(params["preset"]))
	if applied.is_empty():
		return error_invalid_params("Provide LightmapGI properties or preset=")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(gi)), "applied": applied})


func _apply_platform_render_pack(params: Dictionary) -> Dictionary:
	## Combined pack: LOD distances + lightmap quality + optional SDFGI off for mobile.
	var pack: String = optional_string(params, "pack", "desktop").to_lower()
	var router = get_parent()
	var steps: Array = []
	var lod_preset := "desktop"
	var lm_preset := "medium"
	var sdfgi := true
	match pack:
		"mobile":
			lod_preset = "mobile"
			lm_preset = "mobile"
			sdfgi = false
		"high_end", "ultra":
			lod_preset = "cinematic"
			lm_preset = "ultra"
			sdfgi = true
		_:
			lod_preset = "desktop"
			lm_preset = "medium"
			sdfgi = true

	if params.has("source_mesh_path") or params.has("node_path"):
		var lod_params := params.duplicate()
		lod_params["preset"] = lod_preset
		var lod_res := await _apply_lod_distance_preset(lod_params)
		steps.append({"lod": lod_res.get("result", lod_res)})

	var lm_res := await _apply_lightmap_quality_preset({
		"preset": lm_preset,
		"create_if_missing": optional_bool(params, "create_if_missing", true),
		"parent_path": optional_string(params, "parent_path", "."),
	})
	steps.append({"lightmap": lm_res.get("result", lm_res)})

	if router and router.has_method("execute") and optional_bool(params, "configure_sdfgi", true):
		var sres = await router.execute("configure_sdfgi", {"enabled": sdfgi})
		steps.append({"sdfgi": sres})

	return success({
		"pack": pack,
		"lod_preset": lod_preset,
		"lightmap_preset": lm_preset,
		"sdfgi_enabled": sdfgi,
		"steps": steps,
	})


func _find_gi(n: Node) -> LightmapGI:
	if n is LightmapGI:
		return n as LightmapGI
	for c in n.get_children():
		var f := _find_gi(c)
		if f:
			return f
	return null
