@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Camera2D limits from TileMap / rect — huge level-setup gain for 2D agents.


func get_commands() -> Dictionary:
	return {
		"set_camera_2d_limits_rect": _set_limits_rect,
		"set_camera_2d_limits_from_tilemap": _set_limits_tilemap,
		"set_camera_2d_limits_from_node_bounds": _set_limits_node,
		"list_camera_level_bounds_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_camera_2d", "tilemap_get_used_cells", "setup_tilemap_layer_stack"],
	})


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
		# Convert to camera parent space if needed — limits are in world/canvas
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
