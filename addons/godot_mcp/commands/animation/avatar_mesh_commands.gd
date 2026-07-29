@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Avatar mesh authorship - surfaces, blend shapes, skin bind info, material packs.


func get_commands() -> Dictionary:
	return {
		"list_mesh_surfaces": _list_surfaces,
		"set_surface_override_material": _set_surface_mat,
		"clear_surface_override_material": _clear_surface_mat,
		"list_blend_shapes": _list_blend_shapes,
		"set_blend_shape_value": _set_blend_shape,
		"batch_set_blend_shapes": _batch_blend_shapes,
		"apply_face_pose_preset": _face_pose,
		"list_face_pose_presets": _list_face_presets,
		"get_mesh_skin_info": _skin_info,
		"apply_avatar_material_pack": _material_pack,
		"apply_skin_tone": _skin_tone,
		"list_avatar_mesh_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"assign_material_3d_to_mesh", "create_standard_material_3d", "extract_materials_from_scene",
		"equip_avatar_item", "add_animation_track", "set_animation_keyframe",
	], {
		"flow": [
			"list_mesh_surfaces / list_blend_shapes on body MeshInstance3D",
			"apply_skin_tone or apply_avatar_material_pack",
			"batch_set_blend_shapes for face",
			"set_surface_override_material for clothes layers",
		],
	})


func _as_mesh_instance(path: String) -> MeshInstance3D:
	var n := find_node_by_path(path)
	if n is MeshInstance3D:
		return n as MeshInstance3D
	return null


func _list_surfaces(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var mesh := mi.mesh
	if mesh == null:
		return success({"node_path": r0[0], "surfaces": [], "count": 0, "note": "no mesh"})
	var surfaces: Array = []
	for i in mesh.get_surface_count():
		var mat: Material = mi.get_active_material(i)
		var override: Material = mi.get_surface_override_material(i)
		surfaces.append({
			"index": i,
			"name": mesh.surface_get_name(i),
			"material_class": mat.get_class() if mat else null,
			"has_override": override != null,
			"override_class": override.get_class() if override else null,
			"albedo": _mat_albedo_html(mat),
		})
	return success({
		"node_path": r0[0],
		"mesh_class": mesh.get_class(),
		"surface_count": mesh.get_surface_count(),
		"surfaces": surfaces,
		"material_override": mi.material_override.get_class() if mi.material_override else null,
		"skin": mi.skin != null,
		"skeleton_path": str(mi.get_skeleton_path()) if mi.has_method("get_skeleton_path") else str(mi.skeleton),
	})


func _mat_albedo_html(mat: Material) -> String:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_color.to_html(true)
	return ""


func _set_surface_mat(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("surface") and not params.has("surface_name"):
		return error_invalid_params("surface index or surface_name required")
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var surface := _resolve_surface(mi, params)
	if surface < 0:
		return error_not_found("Surface")
	var mat: Material = null
	if params.has("material_path"):
		var mp := str(params["material_path"])
		if not mp.begins_with("res://"):
			mp = "res://" + mp.trim_prefix("/")
		if not ResourceLoader.exists(mp):
			return error_not_found(mp)
		mat = load(mp) as Material
	elif params.has("albedo_color"):
		var m := StandardMaterial3D.new()
		m.albedo_color = _parse_color(params["albedo_color"])
		if params.has("roughness"):
			m.roughness = float(params["roughness"])
		if params.has("metallic"):
			m.metallic = float(params["metallic"])
		mat = m
	else:
		return error_invalid_params("material_path or albedo_color required")
	mi.set_surface_override_material(surface, mat)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"surface": surface,
		"surface_name": mi.mesh.surface_get_name(surface) if mi.mesh else "",
		"material_class": mat.get_class() if mat else null,
	})


func _clear_surface_mat(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var surface := _resolve_surface(mi, params)
	if surface < 0:
		return error_not_found("Surface")
	mi.set_surface_override_material(surface, null)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "surface": surface, "cleared": true})


func _resolve_surface(mi: MeshInstance3D, params: Dictionary) -> int:
	if params.has("surface"):
		return int(params["surface"])
	var sname := str(params.get("surface_name", ""))
	if sname.is_empty() or mi.mesh == null:
		return -1
	for i in mi.mesh.get_surface_count():
		if mi.mesh.surface_get_name(i) == sname or sname.to_lower() in mi.mesh.surface_get_name(i).to_lower():
			return i
	return -1


func _parse_color(v: Variant, default: Color = Color.WHITE) -> Color:
	if v is String:
		return Color.html(v) if str(v).begins_with("#") else Color(str(v))
	if v is Dictionary:
		return Color(float(v.get("r", 1)), float(v.get("g", 1)), float(v.get("b", 1)), float(v.get("a", 1)))
	return default


func _list_blend_shapes(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var mesh := mi.mesh
	if mesh == null:
		return success({"node_path": r0[0], "blend_shapes": [], "count": 0})
	var shapes: Array = []
	var count := mesh.get_blend_shape_count()
	for i in count:
		var name_s := str(mesh.get_blend_shape_name(i))
		var val := mi.get_blend_shape_value(i) if mi.has_method("get_blend_shape_value") else 0.0
		# Godot 4 uses blend_shape_values / find
		if mi.has_method("get") and "blend_shapes" in mi:
			pass
		shapes.append({
			"index": i,
			"name": name_s,
			"value": _get_bs_value(mi, i, name_s),
		})
	return success({"node_path": r0[0], "blend_shapes": shapes, "count": shapes.size()})


func _get_bs_value(mi: MeshInstance3D, index: int, name_s: String) -> float:
	if mi.has_method("get_blend_shape_value"):
		return float(mi.get_blend_shape_value(index))
	# Fallback property path used by AnimationPlayer
	var prop := "blend_shapes/%s" % name_s
	if prop in mi:
		return float(mi.get(prop))
	return 0.0


func _set_bs_value(mi: MeshInstance3D, index: int, name_s: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if mi.has_method("set_blend_shape_value"):
		mi.set_blend_shape_value(index, value)
		return
	var prop := "blend_shapes/%s" % name_s
	if prop in mi:
		mi.set(prop, value)


func _set_blend_shape(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("value"):
		return error_invalid_params("value float 0..1 required")
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	if mi.mesh == null:
		return error_invalid_params("No mesh")
	var idx := -1
	var name_s := ""
	if params.has("blend_shape") or params.has("name"):
		name_s = str(params.get("blend_shape", params.get("name")))
		idx = mi.mesh.find_blend_shape_by_name(StringName(name_s)) if mi.mesh.has_method("find_blend_shape_by_name") else -1
		if idx < 0:
			for i in mi.mesh.get_blend_shape_count():
				if str(mi.mesh.get_blend_shape_name(i)) == name_s:
					idx = i
					break
	elif params.has("index"):
		idx = int(params["index"])
		if idx >= 0 and idx < mi.mesh.get_blend_shape_count():
			name_s = str(mi.mesh.get_blend_shape_name(idx))
	if idx < 0:
		return error_not_found("Blend shape")
	var value := float(params["value"])
	_set_bs_value(mi, idx, name_s, value)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"index": idx,
		"name": name_s,
		"value": _get_bs_value(mi, idx, name_s),
	})


func _batch_blend_shapes(params: Dictionary) -> Dictionary:
	## shapes: {name: value} or [{name|index, value}]
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var results: Array = []
	if params.has("shapes") and params["shapes"] is Dictionary:
		for k in params["shapes"]:
			results.append(_set_blend_shape({
				"node_path": r0[0],
				"name": str(k),
				"value": float(params["shapes"][k]),
			}))
	elif params.has("shapes") and params["shapes"] is Array:
		for item in params["shapes"]:
			if not item is Dictionary:
				continue
			var p: Dictionary = item.duplicate()
			p["node_path"] = r0[0]
			results.append(_set_blend_shape(p))
	else:
		return error_invalid_params("shapes dict or array required")
	var ok := 0
	for r in results:
		if r is Dictionary and not r.has("error"):
			ok += 1
	return success({"node_path": r0[0], "results": results, "ok_count": ok})


func _list_face_presets(_params: Dictionary) -> Dictionary:
	return success({
		"presets": [
			{"id": "neutral", "shapes": {}},
			{"id": "smile", "shapes": {"mouthSmile": 1.0, "mouthSmileLeft": 0.8, "mouthSmileRight": 0.8}},
			{"id": "blink", "shapes": {"eyeBlinkLeft": 1.0, "eyeBlinkRight": 1.0}},
			{"id": "angry", "shapes": {"browDownLeft": 0.8, "browDownRight": 0.8, "mouthFrown": 0.5}},
			{"id": "surprised", "shapes": {"eyeWideLeft": 0.7, "eyeWideRight": 0.7, "jawOpen": 0.4}},
			{"id": "sad", "shapes": {"mouthFrown": 0.7, "browInnerUp": 0.5}},
		],
		"note": "Names vary by DCC (ARKit, VRM, Mixamo). list_blend_shapes first; unmatched names are skipped.",
	})


func _face_pose(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var preset: String = optional_string(params, "preset", "neutral")
	var catalog = _list_face_presets({})
	var presets: Array = catalog.get("result", {}).get("presets", [])
	var shapes: Dictionary = {}
	for p in presets:
		if p is Dictionary and str(p.get("id")) == preset:
			shapes = p.get("shapes", {})
			break
	if params.has("shapes") and params["shapes"] is Dictionary:
		for k in params["shapes"]:
			shapes[k] = params["shapes"][k]
	if optional_bool(params, "reset_others", true):
		var mi := _as_mesh_instance(r0[0])
		if mi and mi.mesh:
			for i in mi.mesh.get_blend_shape_count():
				var nm := str(mi.mesh.get_blend_shape_name(i))
				if not shapes.has(nm):
					_set_bs_value(mi, i, nm, 0.0)
	var applied: Array = []
	var skipped: Array = []
	var mi2 := _as_mesh_instance(r0[0])
	if mi2 == null or mi2.mesh == null:
		return error_not_found("MeshInstance3D with mesh")
	for k in shapes:
		var idx := -1
		var want := str(k).to_lower()
		for i in mi2.mesh.get_blend_shape_count():
			var nm := str(mi2.mesh.get_blend_shape_name(i))
			if nm == str(k) or nm.to_lower() == want or want in nm.to_lower():
				idx = i
				_set_bs_value(mi2, i, nm, float(shapes[k]))
				applied.append({"name": nm, "value": float(shapes[k])})
				break
		if idx < 0:
			skipped.append(str(k))
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"preset": preset,
		"applied": applied,
		"skipped": skipped,
	})


func _skin_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var skin: Skin = mi.skin
	var binds: Array = []
	if skin:
		var bc := skin.get_bind_count() if skin.has_method("get_bind_count") else 0
		for i in bc:
			binds.append({
				"index": i,
				"bone": str(skin.get_bind_name(i)) if skin.has_method("get_bind_name") else "",
				"bone_index": skin.get_bind_bone(i) if skin.has_method("get_bind_bone") else -1,
			})
	var sk_path := ""
	if "skeleton" in mi:
		sk_path = str(mi.skeleton)
	return success({
		"node_path": r0[0],
		"has_skin": skin != null,
		"bind_count": binds.size(),
		"binds_sample": binds.slice(0, mini(32, binds.size())),
		"skeleton": sk_path,
		"mesh": mi.mesh.resource_path if mi.mesh and not mi.mesh.resource_path.is_empty() else (mi.mesh.get_class() if mi.mesh else null),
	})


func _material_pack(params: Dictionary) -> Dictionary:
	## Apply texture pack: {albedo, normal, orm/roughness, metallic} to mesh surface or override
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _as_mesh_instance(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var mat := StandardMaterial3D.new()
	var applied := {}
	if params.has("albedo_color"):
		mat.albedo_color = _parse_color(params["albedo_color"])
		applied["albedo_color"] = mat.albedo_color.to_html(true)
	for key in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "emission_texture"]:
		if params.has(key):
			var tp := str(params[key])
			if not tp.begins_with("res://"):
				tp = "res://" + tp.trim_prefix("/")
			if ResourceLoader.exists(tp):
				var tex = load(tp)
				match key:
					"albedo_texture":
						mat.albedo_texture = tex
					"normal_texture":
						mat.normal_enabled = true
						mat.normal_texture = tex
					"roughness_texture":
						mat.roughness_texture = tex
					"metallic_texture":
						mat.metallic_texture = tex
					"emission_texture":
						mat.emission_enabled = true
						mat.emission_texture = tex
				applied[key] = tp
	if params.has("roughness"):
		mat.roughness = float(params["roughness"])
		applied["roughness"] = mat.roughness
	if params.has("metallic"):
		mat.metallic = float(params["metallic"])
		applied["metallic"] = mat.metallic
	var save_path: String = optional_string(params, "save_path", "")
	if not save_path.is_empty():
		var sr := save_resource_to_res(mat, save_path, optional_bool(params, "overwrite", true))
		if sr.has("error"):
			return sr
	var surface := optional_int(params, "surface", -1)
	if surface >= 0:
		mi.set_surface_override_material(surface, mat)
	else:
		mi.material_override = mat
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"surface": surface,
		"applied": applied,
		"save_path": save_path if not save_path.is_empty() else null,
	})


func _skin_tone(params: Dictionary) -> Dictionary:
	## Tint body material albedo toward a skin tone (or set absolute color).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tone_name: String = optional_string(params, "tone", "")
	var color := Color(0.86, 0.72, 0.62)
	match tone_name.to_lower():
		"light", "fair":
			color = Color(0.96, 0.82, 0.74)
		"medium", "tan":
			color = Color(0.86, 0.72, 0.62)
		"olive":
			color = Color(0.76, 0.62, 0.48)
		"brown", "deep":
			color = Color(0.55, 0.36, 0.25)
		"dark":
			color = Color(0.36, 0.22, 0.16)
		"":
			if params.has("color"):
				color = _parse_color(params["color"], color)
		_:
			if params.has("color"):
				color = _parse_color(params["color"], color)
	if params.has("color"):
		color = _parse_color(params["color"], color)
	return _material_pack({
		"node_path": r0[0],
		"albedo_color": color.to_html(true),
		"surface": params.get("surface", -1),
		"roughness": params.get("roughness", 0.65),
		"metallic": params.get("metallic", 0.0),
		"albedo_texture": params.get("albedo_texture", ""),
		"save_path": params.get("save_path", ""),
		"overwrite": params.get("overwrite", true),
	})
