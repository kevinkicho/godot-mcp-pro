@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## 2D lighting + occlusion depth - parity with 3D light wave for pixel/top-down games.


func get_commands() -> Dictionary:
	return {
		"setup_directional_light_2d_node": _setup_dir,
		"setup_point_light_2d_texture": _setup_point_tex,
		"set_light_2d_params": _set_light_params,
		"setup_light_occluder_polygon_2d": _setup_occluder_poly,
		"setup_light_occluder_from_rect": _occluder_rect,
		"batch_set_light_2d_params": _batch,
		"setup_2d_lighting_scene_pack": _scene_pack,
		"list_light_2d_occlusion_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_point_light_2d", "setup_point_light_2d_node", "setup_light_occluder_2d",
		"setup_canvas_modulate", "setup_directional_light_2d", "apply_pixel_2d_project_preset",
	])


func _parse_color(v: Variant, default: Color = Color.WHITE) -> Color:
	if v is String:
		return Color.html(v) if str(v).begins_with("#") else Color(str(v))
	if v is Dictionary:
		return Color(float(v.get("r", 1)), float(v.get("g", 1)), float(v.get("b", 1)), float(v.get("a", 1)))
	return default


func _setup_dir(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var light := DirectionalLight2D.new()
	light.name = optional_string(params, "name", "DirectionalLight2D")
	light.enabled = optional_bool(params, "enabled", true)
	light.energy = float(params.get("energy", 1.0))
	if params.has("color"):
		light.color = _parse_color(params["color"])
	if params.has("height"):
		light.height = float(params["height"])
	if params.has("max_distance"):
		light.max_distance = float(params["max_distance"])
	if params.has("shadow"):
		light.shadow_enabled = bool(params["shadow"])
	else:
		light.shadow_enabled = optional_bool(params, "shadow_enabled", true)
	if params.has("rotation_degrees"):
		light.rotation_degrees = float(params["rotation_degrees"])
	add_child_with_undo(parent, light, root, "MCP: DirectionalLight2D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(light)),
		"energy": light.energy,
		"shadow_enabled": light.shadow_enabled,
	})


func _setup_point_tex(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var light := PointLight2D.new()
	light.name = optional_string(params, "name", "PointLight2D")
	light.enabled = optional_bool(params, "enabled", true)
	light.energy = float(params.get("energy", 1.0))
	light.texture_scale = float(params.get("texture_scale", 1.0))
	if params.has("color"):
		light.color = _parse_color(params["color"])
	if params.has("texture"):
		var tp := str(params["texture"])
		if not tp.begins_with("res://"):
			tp = "res://" + tp.trim_prefix("/")
		if ResourceLoader.exists(tp):
			light.texture = load(tp)
	if params.has("shadow"):
		light.shadow_enabled = bool(params["shadow"])
	else:
		light.shadow_enabled = optional_bool(params, "shadow_enabled", true)
	if params.has("shadow_filter") and "shadow_filter" in light:
		light.set("shadow_filter", int(params["shadow_filter"]))
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		light.position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	add_child_with_undo(parent, light, root, "MCP: PointLight2D tex")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(light)),
		"has_texture": light.texture != null,
		"energy": light.energy,
	})


func _set_light_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Light2D):
		return error_not_found("Light2D")
	var light := n as Light2D
	var applied := {}
	if params.has("energy"):
		light.energy = float(params["energy"])
		applied["energy"] = light.energy
	if params.has("color"):
		light.color = _parse_color(params["color"])
		applied["color"] = light.color.to_html(true)
	if params.has("enabled"):
		light.enabled = bool(params["enabled"])
		applied["enabled"] = light.enabled
	if params.has("shadow") or params.has("shadow_enabled"):
		light.shadow_enabled = bool(params.get("shadow", params.get("shadow_enabled")))
		applied["shadow_enabled"] = light.shadow_enabled
	if params.has("z_range_min") and "range_item_cull_mask" in light:
		pass
	if light is PointLight2D:
		var pl := light as PointLight2D
		if params.has("texture_scale"):
			pl.texture_scale = float(params["texture_scale"])
			applied["texture_scale"] = pl.texture_scale
		if params.has("texture"):
			var tp := str(params["texture"])
			if not tp.begins_with("res://"):
				tp = "res://" + tp.trim_prefix("/")
			if ResourceLoader.exists(tp):
				pl.texture = load(tp)
				applied["texture"] = tp
	if light is DirectionalLight2D:
		var dl := light as DirectionalLight2D
		if params.has("height"):
			dl.height = float(params["height"])
			applied["height"] = dl.height
		if params.has("max_distance"):
			dl.max_distance = float(params["max_distance"])
			applied["max_distance"] = dl.max_distance
	if applied.is_empty():
		return error_invalid_params("No light params applied")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied, "class": light.get_class()})


func _setup_occluder_poly(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var oc := LightOccluder2D.new()
	oc.name = optional_string(params, "name", "LightOccluder2D")
	var poly := OccluderPolygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	if params.has("points") and params["points"] is Array:
		for p in params["points"]:
			if p is Dictionary:
				pts.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			elif p is Array and p.size() >= 2:
				pts.append(Vector2(float(p[0]), float(p[1])))
	if pts.is_empty():
		# unit square
		pts = PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
		])
	poly.polygon = pts
	poly.closed = optional_bool(params, "closed", true)
	if params.has("cull_mode"):
		poly.cull_mode = int(params["cull_mode"]) as OccluderPolygon2D.CullMode
	oc.occluder = poly
	add_child_with_undo(parent, oc, root, "MCP: LightOccluder2D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(oc)),
		"point_count": pts.size(),
	})


func _occluder_rect(params: Dictionary) -> Dictionary:
	var w := float(params.get("width", 32))
	var h := float(params.get("height", 32))
	var hw := w * 0.5
	var hh := h * 0.5
	var p := params.duplicate()
	p["points"] = [
		{"x": -hw, "y": -hh}, {"x": hw, "y": -hh}, {"x": hw, "y": hh}, {"x": -hw, "y": hh},
	]
	return _setup_occluder_poly(p)


func _batch(params: Dictionary) -> Dictionary:
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("items array required")
	var results: Array = []
	for item in params["items"]:
		if item is Dictionary:
			results.append(_set_light_params(item))
	return success({"results": results, "count": results.size()})


func _scene_pack(params: Dictionary) -> Dictionary:
	## One-shot: canvas modulate night + directional + point key light + sample occluder
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var steps: Array = []
	# Canvas modulate
	var cm_parent := find_node_by_path(parent_path)
	if cm_parent:
		var cm := CanvasModulate.new()
		cm.name = "CanvasModulate"
		cm.color = _parse_color(params.get("modulate", "#1a1a2e"))
		add_child_with_undo(cm_parent, cm, root, "MCP: night modulate")
		steps.append({"canvas_modulate": str(root.get_path_to(cm))})
	steps.append(_setup_dir({
		"parent_path": parent_path,
		"energy": float(params.get("dir_energy", 0.35)),
		"color": params.get("dir_color", "#8899cc"),
		"shadow": true,
		"rotation_degrees": float(params.get("dir_rotation", -40)),
	}))
	steps.append(_setup_point_tex({
		"parent_path": parent_path,
		"energy": float(params.get("point_energy", 1.2)),
		"color": params.get("point_color", "#ffcc88"),
		"texture_scale": float(params.get("texture_scale", 2.0)),
		"shadow": true,
		"position": params.get("point_position", {"x": 0, "y": 0}),
		"texture": params.get("texture", ""),
	}))
	if optional_bool(params, "sample_occluder", true):
		steps.append(_occluder_rect({
			"parent_path": parent_path,
			"width": float(params.get("occluder_width", 64)),
			"height": float(params.get("occluder_height", 32)),
			"name": "SampleOccluder",
		}))
	mark_current_scene_unsaved()
	return success({"steps": steps, "preset": "2d_lighting_pack"})
