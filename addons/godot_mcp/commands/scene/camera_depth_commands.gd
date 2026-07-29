@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Camera2D/3D fine control — limits, current, FOV, cull, drag.


func get_commands() -> Dictionary:
	return {
		"setup_camera_2d": _setup_camera_2d,
		"setup_camera_3d_node": _setup_camera_3d,
		"set_camera_2d_limits": _set_camera_2d_limits,
		"set_camera_3d_params": _set_camera_3d_params,
		"camera_make_current": _camera_make_current,
		"set_camera_2d_limits_rect": _set_limits_rect,
		"set_camera_2d_limits_from_tilemap": _set_limits_tilemap,
		"set_camera_2d_limits_from_node_bounds": _set_limits_node,
		"list_camera_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_camera_follow_2d", "setup_third_person_camera", "setup_orbit_camera_3d",
		"create_camera_shake_script", "tilemap_get_used_cells",
	])


func _setup_camera_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var cam := Camera2D.new()
	cam.name = optional_string(params, "name", "Camera2D")
	cam.enabled = optional_bool(params, "enabled", true)
	if params.has("zoom"):
		var z = params["zoom"]
		if z is Dictionary:
			cam.zoom = Vector2(float(z.get("x", 1)), float(z.get("y", z.get("x", 1))))
		else:
			var f := float(z)
			cam.zoom = Vector2(f, f)
	if params.has("position_smoothing_enabled"):
		cam.position_smoothing_enabled = bool(params["position_smoothing_enabled"])
	if params.has("position_smoothing_speed"):
		cam.position_smoothing_speed = float(params["position_smoothing_speed"])
	if params.has("drag_horizontal_enabled"):
		cam.drag_horizontal_enabled = bool(params["drag_horizontal_enabled"])
	if params.has("drag_vertical_enabled"):
		cam.drag_vertical_enabled = bool(params["drag_vertical_enabled"])
	add_child_with_undo(parent, cam, root, "MCP: Camera2D")
	if optional_bool(params, "make_current", true):
		cam.make_current()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(cam)), "type": "Camera2D"})


func _setup_camera_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var cam := Camera3D.new()
	cam.name = optional_string(params, "name", "Camera3D")
	cam.fov = float(params.get("fov", 75.0))
	cam.near = float(params.get("near", 0.05))
	cam.far = float(params.get("far", 4000.0))
	if params.has("cull_mask"):
		cam.cull_mask = int(params["cull_mask"])
	if params.has("position"):
		var p = params["position"]
		if p is Dictionary:
			cam.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
	if params.has("projection"):
		match str(params["projection"]).to_lower():
			"orthogonal", "ortho":
				cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			"frustum":
				cam.projection = Camera3D.PROJECTION_FRUSTUM
			_:
				cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	add_child_with_undo(parent, cam, root, "MCP: Camera3D")
	if optional_bool(params, "make_current", true):
		cam.make_current()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(cam)), "fov": cam.fov})


func _set_camera_2d_limits(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Camera2D):
		return error_not_found("Camera2D")
	var cam := n as Camera2D
	cam.limit_enabled = optional_bool(params, "enabled", true)
	if params.has("left"):
		cam.limit_left = int(params["left"])
	if params.has("right"):
		cam.limit_right = int(params["right"])
	if params.has("top"):
		cam.limit_top = int(params["top"])
	if params.has("bottom"):
		cam.limit_bottom = int(params["bottom"])
	if params.has("smoothed"):
		cam.limit_smoothed = bool(params["smoothed"])
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"limits": {
			"left": cam.limit_left, "right": cam.limit_right,
			"top": cam.limit_top, "bottom": cam.limit_bottom,
			"enabled": cam.limit_enabled,
		},
	})


func _set_camera_3d_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Camera3D):
		return error_not_found("Camera3D")
	var cam := n as Camera3D
	var applied := {}
	for k in ["fov", "near", "far", "h_offset", "v_offset", "cull_mask", "keep_aspect"]:
		if params.has(k) and k in cam:
			cam.set(k, params[k])
			applied[k] = cam.get(k)
	if params.has("environment") and ResourceLoader.exists(str(params["environment"])):
		cam.environment = load(str(params["environment"]))
		applied["environment"] = str(params["environment"])
	if params.has("attributes") and ResourceLoader.exists(str(params["attributes"])):
		cam.attributes = load(str(params["attributes"]))
		applied["attributes"] = true
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _camera_make_current(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n is Camera2D:
		(n as Camera2D).make_current()
	elif n is Camera3D:
		(n as Camera3D).make_current()
	else:
		return error_invalid_params("Not a Camera2D/3D")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "current": true})


# --- merged from camera_level_bounds_commands ---

func _cam(path: String) -> Camera2D:
	var n := find_node_by_path(path)
	if n is Camera2D:
		return n as Camera2D
	return null


func _set_limits_rect(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var cam := _cam(r0[0])
	if cam == null:
		return error_not_found("Camera2D")
	if params.has("limit_left"):
		cam.limit_left = int(params["limit_left"])
	if params.has("limit_top"):
		cam.limit_top = int(params["limit_top"])
	if params.has("limit_right"):
		cam.limit_right = int(params["limit_right"])
	if params.has("limit_bottom"):
		cam.limit_bottom = int(params["limit_bottom"])
	if params.has("rect") and params["rect"] is Dictionary:
		var r: Dictionary = params["rect"]
		cam.limit_left = int(r.get("x", r.get("left", 0)))
		cam.limit_top = int(r.get("y", r.get("top", 0)))
		var w := int(r.get("w", r.get("width", 0)))
		var h := int(r.get("h", r.get("height", 0)))
		if w > 0:
			cam.limit_right = cam.limit_left + w
		if h > 0:
			cam.limit_bottom = cam.limit_top + h
		if r.has("right"):
			cam.limit_right = int(r["right"])
		if r.has("bottom"):
			cam.limit_bottom = int(r["bottom"])
	if params.has("limit_smoothed"):
		cam.limit_smoothed = bool(params["limit_smoothed"])
	if params.has("limit_enabled"):
		# Godot 4 uses per-side limits always; drag margins separate
		pass
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"limits": {
			"left": cam.limit_left,
			"top": cam.limit_top,
			"right": cam.limit_right,
			"bottom": cam.limit_bottom,
		},
	})


func _set_limits_tilemap(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "camera_path")
	if r0[1] != null:
		# allow node_path for camera
		r0 = require_string(params, "node_path")
		if r0[1] != null:
			return error_invalid_params("camera_path or node_path required")
	var cam := _cam(r0[0])
	if cam == null:
		return error_not_found("Camera2D")
	var tm_path: String = optional_string(params, "tilemap_path", "")
	if tm_path.is_empty():
		return error_invalid_params("tilemap_path required")
	var tm := find_node_by_path(tm_path)
	if tm == null:
		return error_not_found("TileMap")
	var margin: int = optional_int(params, "margin", 0)
	var rect: Rect2
	if tm is TileMapLayer:
		var layer: TileMapLayer = tm as TileMapLayer
		var used: Rect2i = layer.get_used_rect()
		var ts: TileSet = layer.tile_set
		var cell := Vector2(16, 16)
		if ts:
			cell = Vector2(ts.tile_size)
		var top_left := layer.map_to_local(used.position) - cell * 0.5
		var bottom_right := layer.map_to_local(used.position + used.size) + cell * 0.5
		# map_to_local is center of cell in Godot 4
		top_left = layer.to_global(top_left)
		bottom_right = layer.to_global(bottom_right)
		# Convert to camera parent space if needed â€” limits are in world/canvas
		rect = Rect2(top_left, bottom_right - top_left)
	elif tm.get_class() == "TileMap":
		var used2: Rect2i = tm.call("get_used_rect")
		var cell2: Vector2 = tm.call("get_tileset").tile_size if tm.get("tile_set") else Vector2(16, 16)
		if tm.get("tile_set"):
			cell2 = Vector2((tm.get("tile_set") as TileSet).tile_size)
		var tl: Vector2 = tm.call("map_to_local", used2.position)
		var br: Vector2 = tm.call("map_to_local", used2.position + used2.size)
		rect = Rect2(tl, br - tl)
	else:
		return error_invalid_params("tilemap_path must be TileMapLayer or TileMap")
	cam.limit_left = int(floor(rect.position.x)) - margin
	cam.limit_top = int(floor(rect.position.y)) - margin
	cam.limit_right = int(ceil(rect.end.x)) + margin
	cam.limit_bottom = int(ceil(rect.end.y)) + margin
	mark_current_scene_unsaved()
	return success({
		"camera_path": r0[0],
		"tilemap_path": tm_path,
		"limits": {
			"left": cam.limit_left,
			"top": cam.limit_top,
			"right": cam.limit_right,
			"bottom": cam.limit_bottom,
		},
		"margin": margin,
	})


func _set_limits_node(params: Dictionary) -> Dictionary:
	## Use a Control or CollisionShape/ReferenceRect bounds.
	var r0 := require_string(params, "camera_path")
	if r0[1] != null:
		r0 = require_string(params, "node_path")
		if r0[1] != null:
			return error_invalid_params("camera_path required")
	var cam := _cam(r0[0])
	if cam == null:
		return error_not_found("Camera2D")
	var bounds_path: String = optional_string(params, "bounds_path", "")
	if bounds_path.is_empty():
		return error_invalid_params("bounds_path required")
	var b := find_node_by_path(bounds_path)
	if b == null:
		return error_not_found("bounds node")
	var margin: int = optional_int(params, "margin", 0)
	var rect := Rect2()
	if b is Control:
		var c: Control = b as Control
		var tl := c.global_position
		rect = Rect2(tl, c.size)
	elif b is CollisionShape2D and (b as CollisionShape2D).shape is RectangleShape2D:
		var cs: CollisionShape2D = b as CollisionShape2D
		var rs: RectangleShape2D = cs.shape as RectangleShape2D
		var center := cs.global_position
		rect = Rect2(center - rs.size * 0.5, rs.size)
	elif b is Node2D and params.has("size"):
		var n2: Node2D = b as Node2D
		var sz = params["size"]
		var size := Vector2(float(sz.get("x", 100)), float(sz.get("y", 100))) if sz is Dictionary else Vector2(100, 100)
		rect = Rect2(n2.global_position - size * 0.5, size)
	else:
		return error_invalid_params("bounds_path needs Control, Rectangle CollisionShape2D, or Node2D+size")
	cam.limit_left = int(floor(rect.position.x)) - margin
	cam.limit_top = int(floor(rect.position.y)) - margin
	cam.limit_right = int(ceil(rect.end.x)) + margin
	cam.limit_bottom = int(ceil(rect.end.y)) + margin
	mark_current_scene_unsaved()
	return success({
		"camera_path": r0[0],
		"bounds_path": bounds_path,
		"limits": {
			"left": cam.limit_left,
			"top": cam.limit_top,
			"right": cam.limit_right,
			"bottom": cam.limit_bottom,
		},
	})

