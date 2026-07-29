@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## 2D lighting structure — CanvasModulate, LightOccluder2D, PointLight2D tune.


func get_commands() -> Dictionary:
	return {
		"setup_canvas_modulate": _setup_canvas_modulate,
		"setup_light_occluder_2d": _setup_light_occluder_2d,
		"setup_point_light_2d_node": _setup_point_light_2d,
		"set_point_light_2d_params": _set_point_light_2d_params,
		"list_light_2d_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_point_light_2d", "add_light_occluder_2d", "setup_directional_light"],
	})


func _setup_canvas_modulate(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var cm := CanvasModulate.new()
	cm.name = optional_string(params, "name", "CanvasModulate")
	var col: String = optional_string(params, "color", "#808080")
	cm.color = Color.html(col) if col.begins_with("#") else Color(col)
	add_child_with_undo(parent, cm, root, "MCP: CanvasModulate")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(cm)), "color": cm.color.to_html()})


func _setup_light_occluder_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var occ := LightOccluder2D.new()
	occ.name = optional_string(params, "name", "LightOccluder2D")
	var poly := OccluderPolygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	if params.has("points") and params["points"] is Array:
		for p in params["points"]:
			if p is Dictionary:
				points.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			elif p is Array and p.size() >= 2:
				points.append(Vector2(float(p[0]), float(p[1])))
	else:
		# Default box
		var w := float(params.get("width", 32))
		var h := float(params.get("height", 32))
		var hw := w * 0.5
		var hh := h * 0.5
		points = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	poly.polygon = points
	if params.has("closed"):
		poly.closed = bool(params["closed"])
	if params.has("cull_mode"):
		poly.cull_mode = int(params["cull_mode"]) as OccluderPolygon2D.CullMode
	occ.occluder = poly
	add_child_with_undo(parent, occ, root, "MCP: LightOccluder2D")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(occ)), "point_count": points.size()})


func _setup_point_light_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var light := PointLight2D.new()
	light.name = optional_string(params, "name", "PointLight2D")
	light.energy = float(params.get("energy", 1.0))
	light.texture_scale = float(params.get("texture_scale", 1.0))
	if params.has("color"):
		var c := str(params["color"])
		light.color = Color.html(c) if c.begins_with("#") else Color(c)
	if params.has("texture_path") and ResourceLoader.exists(str(params["texture_path"])):
		light.texture = load(str(params["texture_path"]))
	if params.has("shadow_enabled"):
		light.shadow_enabled = bool(params["shadow_enabled"])
	add_child_with_undo(parent, light, root, "MCP: PointLight2D")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(light)), "energy": light.energy})


func _set_point_light_2d_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is PointLight2D):
		return error_not_found("PointLight2D")
	var light := n as PointLight2D
	var applied := {}
	for k in ["energy", "texture_scale", "shadow_enabled", "shadow_filter", "shadow_color", "range_item_cull_mask"]:
		if params.has(k) and k in light:
			light.set(k, params[k])
			applied[k] = light.get(k)
	if params.has("color"):
		var c := str(params["color"])
		light.color = Color.html(c) if c.begins_with("#") else Color(c)
		applied["color"] = light.color.to_html()
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})
