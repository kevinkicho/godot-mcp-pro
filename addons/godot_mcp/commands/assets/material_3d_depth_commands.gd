@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## StandardMaterial3D / ORMMaterial3D authoring - shared PBR materials for agents.


func get_commands() -> Dictionary:
	return {
		"create_standard_material_3d": _create_standard,
		"create_orm_material_3d": _create_orm,
		"set_standard_material_params": _set_params,
		"assign_material_3d_to_mesh": _assign_to_mesh,
		"list_material_3d_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["set_material_3d", "assign_shader_material", "create_shader", "extract_materials_from_scene"],
	})


func _parse_color(v: Variant, default: Color = Color.WHITE) -> Color:
	if v is String:
		return Color.html(v) if str(v).begins_with("#") else Color(str(v))
	if v is Dictionary:
		return Color(float(v.get("r", 1)), float(v.get("g", 1)), float(v.get("b", 1)), float(v.get("a", 1)))
	return default


func _apply_common(mat: BaseMaterial3D, params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("albedo_color"):
		mat.albedo_color = _parse_color(params["albedo_color"])
		applied["albedo_color"] = mat.albedo_color.to_html(true)
	if params.has("albedo_texture") and ResourceLoader.exists(str(params["albedo_texture"])):
		mat.albedo_texture = load(str(params["albedo_texture"]))
		applied["albedo_texture"] = str(params["albedo_texture"])
	if params.has("metallic"):
		mat.metallic = float(params["metallic"])
		applied["metallic"] = mat.metallic
	if params.has("roughness"):
		mat.roughness = float(params["roughness"])
		applied["roughness"] = mat.roughness
	if params.has("emission_enabled"):
		mat.emission_enabled = bool(params["emission_enabled"])
		applied["emission_enabled"] = mat.emission_enabled
	if params.has("emission"):
		mat.emission_enabled = true
		mat.emission = _parse_color(params["emission"], Color.BLACK)
		applied["emission"] = mat.emission.to_html(true)
	if params.has("emission_energy") or params.has("emission_energy_multiplier"):
		mat.emission_enabled = true
		var e := float(params.get("emission_energy", params.get("emission_energy_multiplier", 1.0)))
		if "emission_energy_multiplier" in mat:
			mat.emission_energy_multiplier = e
		applied["emission_energy"] = e
	if params.has("transparency"):
		# 0 disabled, 1 alpha, 2 alpha scissor, ...
		mat.transparency = int(params["transparency"]) as BaseMaterial3D.Transparency
		applied["transparency"] = mat.transparency
	if params.has("cull_mode"):
		mat.cull_mode = int(params["cull_mode"]) as BaseMaterial3D.CullMode
		applied["cull_mode"] = mat.cull_mode
	if params.has("shading_mode"):
		mat.shading_mode = int(params["shading_mode"]) as BaseMaterial3D.ShadingMode
		applied["shading_mode"] = mat.shading_mode
	if params.has("normal_enabled"):
		mat.normal_enabled = bool(params["normal_enabled"])
	if params.has("normal_texture") and ResourceLoader.exists(str(params["normal_texture"])):
		mat.normal_enabled = true
		mat.normal_texture = load(str(params["normal_texture"]))
		applied["normal_texture"] = str(params["normal_texture"])
	if params.has("uv1_scale") and params["uv1_scale"] is Dictionary:
		var u: Dictionary = params["uv1_scale"]
		mat.uv1_scale = Vector3(float(u.get("x", 1)), float(u.get("y", 1)), float(u.get("z", 1)))
		applied["uv1_scale"] = true
	if params.has("texture_filter"):
		mat.texture_filter = int(params["texture_filter"]) as BaseMaterial3D.TextureFilter
		applied["texture_filter"] = mat.texture_filter
	return applied


func _create_standard(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var mat := StandardMaterial3D.new()
	var applied := _apply_common(mat, params)
	if params.has("specular"):
		mat.metallic_specular = float(params["specular"])
		applied["specular"] = mat.metallic_specular
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(mat, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "class": "StandardMaterial3D", "applied": applied})


func _create_orm(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	if not ClassDB.class_exists("ORMMaterial3D"):
		return error_internal("ORMMaterial3D not available")
	var mat: BaseMaterial3D = ClassDB.instantiate("ORMMaterial3D")
	var applied := _apply_common(mat, params)
	if params.has("orm_texture") and ResourceLoader.exists(str(params["orm_texture"])):
		mat.set("orm_texture", load(str(params["orm_texture"])))
		applied["orm_texture"] = str(params["orm_texture"])
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(mat, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "class": "ORMMaterial3D", "applied": applied})


func _set_params(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", optional_string(params, "material_path", ""))
	var mat: BaseMaterial3D = null
	if not path.is_empty():
		var vr := validate_res_path(path)
		if vr[1] != null:
			return vr[1]
		path = vr[0]
		if not ResourceLoader.exists(path):
			return error_not_found(path)
		var res = load(path)
		if not (res is BaseMaterial3D):
			return error_internal("Not a BaseMaterial3D")
		mat = res as BaseMaterial3D
	else:
		var r0 := require_string(params, "node_path")
		if r0[1] != null:
			return r0[1]
		var node := find_node_by_path(r0[0])
		if node == null:
			return error_not_found("Node")
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node as MeshInstance3D
			if mi.material_override is BaseMaterial3D:
				mat = mi.material_override as BaseMaterial3D
			elif mi.get_active_material(0) is BaseMaterial3D:
				mat = (mi.get_active_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
				mi.material_override = mat
		if mat == null:
			return error_invalid_params("No BaseMaterial3D on node - pass path= or create first")
	var applied := _apply_common(mat, params)
	if mat is StandardMaterial3D and params.has("specular"):
		(mat as StandardMaterial3D).metallic_specular = float(params["specular"])
		applied["specular"] = (mat as StandardMaterial3D).metallic_specular
	if not path.is_empty():
		var err := ResourceSaver.save(mat, path)
		if err != OK:
			return error_internal(error_string(err))
	else:
		mark_current_scene_unsaved()
	return success({"path": path, "applied": applied})


func _assign_to_mesh(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mat_r := require_res_path(params, "material_path")
	if mat_r[1] != null:
		return mat_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is MeshInstance3D):
		return error_not_found("MeshInstance3D")
	if not ResourceLoader.exists(mat_r[0]):
		return error_not_found(mat_r[0])
	var mat = load(mat_r[0])
	if not (mat is Material):
		return error_internal("Not a Material")
	var mi: MeshInstance3D = node as MeshInstance3D
	var surface: int = optional_int(params, "surface", -1)
	if surface < 0 or optional_bool(params, "as_override", true):
		mi.material_override = mat
	else:
		mi.set_surface_override_material(surface, mat)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"material_path": mat_r[0],
		"mode": "override" if surface < 0 or optional_bool(params, "as_override", true) else "surface_%d" % surface,
	})
