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
		"list_camera_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_camera_follow_2d", "setup_third_person_camera", "setup_orbit_camera_3d", "create_camera_shake_script"],
	})


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
