@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Environment / Sky / FogVolume resource authoring for agents (tutorials/3d + rendering).


func get_commands() -> Dictionary:
	return {
		"create_environment_resource": _create_env,
		"create_procedural_sky": _create_proc_sky,
		"create_panorama_sky": _create_pano_sky,
		"assign_environment_to_world": _assign_env,
		"setup_fog_volume": _setup_fog_volume,
		"set_environment_fog_params": _set_fog_params,
		"list_environment_sky_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_world_environment", "apply_environment_preset", "configure_sdfgi", "configure_glow"],
	})


func _parse_color(v: Variant, default: Color = Color.WHITE) -> Color:
	if v is String:
		return Color.html(v) if str(v).begins_with("#") else Color(str(v))
	if v is Dictionary:
		return Color(float(v.get("r", 1)), float(v.get("g", 1)), float(v.get("b", 1)), float(v.get("a", 1)))
	return default


func _create_env(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists", {"suggestion": "overwrite=true"})
	var env := Environment.new()
	var applied := {}
	if params.has("background_mode"):
		env.background_mode = int(params["background_mode"]) as Environment.BGMode
		applied["background_mode"] = env.background_mode
	elif optional_bool(params, "use_sky", true):
		env.background_mode = Environment.BG_SKY
		applied["background_mode"] = env.background_mode
	if params.has("bg_color"):
		env.background_mode = Environment.BG_COLOR
		env.background_color = _parse_color(params["bg_color"])
		applied["bg_color"] = env.background_color.to_html()
	if params.has("ambient_light_source"):
		env.ambient_light_source = int(params["ambient_light_source"]) as Environment.AmbientSource
	if params.has("ambient_light_color"):
		env.ambient_light_color = _parse_color(params["ambient_light_color"])
		applied["ambient_light_color"] = true
	if params.has("ambient_light_energy"):
		env.ambient_light_energy = float(params["ambient_light_energy"])
		applied["ambient_light_energy"] = env.ambient_light_energy
	if params.has("tonemap_mode"):
		env.tonemap_mode = int(params["tonemap_mode"]) as Environment.ToneMapper
	if params.has("glow_enabled"):
		env.glow_enabled = bool(params["glow_enabled"])
	if params.has("ssao_enabled"):
		env.ssao_enabled = bool(params["ssao_enabled"])
	if params.has("ssil_enabled"):
		env.ssil_enabled = bool(params["ssil_enabled"])
	if params.has("ssr_enabled"):
		env.ssr_enabled = bool(params["ssr_enabled"])
	if params.has("sdfgi_enabled"):
		env.sdfgi_enabled = bool(params["sdfgi_enabled"])
	if params.has("volumetric_fog_enabled"):
		env.volumetric_fog_enabled = bool(params["volumetric_fog_enabled"])
	if params.has("fog_enabled"):
		env.fog_enabled = bool(params["fog_enabled"])
	if params.has("sky_path") and ResourceLoader.exists(str(params["sky_path"])):
		var sky = load(str(params["sky_path"]))
		if sky is Sky:
			env.sky = sky
			env.background_mode = Environment.BG_SKY
			applied["sky_path"] = str(params["sky_path"])
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(env, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "applied": applied, "class": "Environment"})


func _create_proc_sky(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists", {"suggestion": "overwrite=true"})
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	if params.has("sky_top_color"):
		mat.sky_top_color = _parse_color(params["sky_top_color"], Color(0.4, 0.6, 1.0))
	if params.has("sky_horizon_color"):
		mat.sky_horizon_color = _parse_color(params["sky_horizon_color"], Color(0.7, 0.8, 0.9))
	if params.has("ground_bottom_color"):
		mat.ground_bottom_color = _parse_color(params["ground_bottom_color"], Color(0.2, 0.15, 0.1))
	if params.has("ground_horizon_color"):
		mat.ground_horizon_color = _parse_color(params["ground_horizon_color"], Color(0.6, 0.55, 0.5))
	if params.has("sun_angle_max"):
		mat.sun_angle_max = float(params["sun_angle_max"])
	if params.has("sky_energy") or params.has("sky_energy_multiplier"):
		mat.sky_energy_multiplier = float(params.get("sky_energy", params.get("sky_energy_multiplier", 1.0)))
	sky.sky_material = mat
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(sky, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "class": "Sky", "material": "ProceduralSkyMaterial"})


func _create_pano_sky(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var tex_r := require_res_path(params, "panorama_path")
	if tex_r[1] != null:
		return tex_r[1]
	if not ResourceLoader.exists(tex_r[0]):
		return error_not_found(tex_r[0])
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists", {"suggestion": "overwrite=true"})
	var sky := Sky.new()
	var mat := PanoramaSkyMaterial.new()
	var tex = load(tex_r[0])
	if tex is Texture2D:
		mat.panorama = tex
	else:
		return error_internal("panorama_path must be Texture2D")
	if params.has("energy_multiplier"):
		mat.energy_multiplier = float(params["energy_multiplier"])
	sky.sky_material = mat
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(sky, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "panorama_path": tex_r[0], "class": "Sky"})


func _assign_env(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var env_path: String = optional_string(params, "environment_path", optional_string(params, "path", ""))
	if env_path.is_empty():
		return error_invalid_params("environment_path required")
	var vr := validate_res_path(env_path)
	if vr[1] != null:
		return vr[1]
	if not ResourceLoader.exists(vr[0]):
		return error_not_found(vr[0])
	var env = load(vr[0])
	if not (env is Environment):
		return error_internal("Not an Environment")
	var we: WorldEnvironment = null
	var node_path: String = optional_string(params, "node_path", "")
	if not node_path.is_empty():
		var n := find_node_by_path(node_path)
		if n is WorldEnvironment:
			we = n as WorldEnvironment
	if we == null:
		# find or create
		we = _find_we(root)
	if we == null and optional_bool(params, "create_if_missing", true):
		we = WorldEnvironment.new()
		we.name = optional_string(params, "name", "WorldEnvironment")
		var parent := find_node_by_path(optional_string(params, "parent_path", "."))
		if parent == null:
			parent = root
		add_child_with_undo(parent, we, root, "MCP: WorldEnvironment")
	if we == null:
		return error_not_found("WorldEnvironment")
	we.environment = env
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(we)),
		"environment_path": vr[0],
	})


func _find_we(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node as WorldEnvironment
	for c in node.get_children():
		var f := _find_we(c)
		if f:
			return f
	return null


func _setup_fog_volume(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var fv := FogVolume.new()
	fv.name = optional_string(params, "name", "FogVolume")
	if params.has("size") and params["size"] is Dictionary:
		var s: Dictionary = params["size"]
		fv.size = Vector3(float(s.get("x", 10)), float(s.get("y", 5)), float(s.get("z", 10)))
	elif params.has("size") and (params["size"] is float or params["size"] is int):
		var f := float(params["size"])
		fv.size = Vector3(f, f, f)
	if params.has("shape"):
		fv.shape = int(params["shape"]) as RenderingServer.FogVolumeShape
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		fv.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
	# Optional material
	if ClassDB.class_exists("FogMaterial"):
		var fm: Material = ClassDB.instantiate("FogMaterial")
		if params.has("density") and "density" in fm:
			fm.set("density", float(params["density"]))
		if params.has("albedo") and "albedo" in fm:
			fm.set("albedo", _parse_color(params["albedo"], Color(0.8, 0.8, 0.8)))
		if params.has("emission") and "emission" in fm:
			fm.set("emission", _parse_color(params["emission"], Color.BLACK))
		fv.material = fm
	add_child_with_undo(parent, fv, root, "MCP: FogVolume")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(fv)),
		"size": {"x": fv.size.x, "y": fv.size.y, "z": fv.size.z},
	})


func _set_fog_params(params: Dictionary) -> Dictionary:
	## Tune Environment classic/volumetric fog on WorldEnvironment or resource path.
	var env: Environment = null
	var path: String = optional_string(params, "environment_path", "")
	var node_path: String = optional_string(params, "node_path", "")
	if not path.is_empty():
		var vr := validate_res_path(path)
		if vr[1] != null:
			return vr[1]
		var r = load(vr[0])
		if r is Environment:
			env = r
			path = vr[0]
	elif not node_path.is_empty():
		var n := find_node_by_path(node_path)
		if n is WorldEnvironment and (n as WorldEnvironment).environment:
			env = (n as WorldEnvironment).environment
	else:
		var root := get_edited_root()
		if root:
			var we := _find_we(root)
			if we and we.environment:
				env = we.environment
	if env == null:
		return error_not_found("Environment - pass environment_path or WorldEnvironment node_path")
	var applied := {}
	if params.has("fog_enabled"):
		env.fog_enabled = bool(params["fog_enabled"])
		applied["fog_enabled"] = env.fog_enabled
	if params.has("fog_light_color"):
		env.fog_light_color = _parse_color(params["fog_light_color"])
		applied["fog_light_color"] = true
	if params.has("fog_density"):
		env.fog_density = float(params["fog_density"])
		applied["fog_density"] = env.fog_density
	if params.has("fog_aerial_perspective"):
		env.fog_aerial_perspective = float(params["fog_aerial_perspective"])
	if params.has("fog_sky_affect"):
		env.fog_sky_affect = float(params["fog_sky_affect"])
	if params.has("volumetric_fog_enabled"):
		env.volumetric_fog_enabled = bool(params["volumetric_fog_enabled"])
		applied["volumetric_fog_enabled"] = env.volumetric_fog_enabled
	if params.has("volumetric_fog_density"):
		env.volumetric_fog_density = float(params["volumetric_fog_density"])
		applied["volumetric_fog_density"] = env.volumetric_fog_density
	if params.has("volumetric_fog_albedo"):
		env.volumetric_fog_albedo = _parse_color(params["volumetric_fog_albedo"])
	if params.has("volumetric_fog_emission"):
		env.volumetric_fog_emission = _parse_color(params["volumetric_fog_emission"])
	if params.has("volumetric_fog_anisotropy"):
		env.volumetric_fog_anisotropy = float(params["volumetric_fog_anisotropy"])
	if not path.is_empty():
		ResourceSaver.save(env, path)
	else:
		mark_current_scene_unsaved()
	return success({"environment_path": path, "applied": applied})
