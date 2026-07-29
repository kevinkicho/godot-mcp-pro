@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## PathFollow2D/3D control — progress, offsets, rotation modes.


func get_commands() -> Dictionary:
	return {
		"setup_path_follow": _setup_path_follow,
		"path_follow_set_progress": _path_follow_set_progress,
		"path_follow_get_info": _path_follow_get_info,
		"path_follow_set_loop": _path_follow_set_loop,
		"list_path_follow_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_path_3d", "setup_path_2d", "path_set_curve_points", "curve3d_set_points"],
	})


func _setup_path_follow(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", "")
	var path_node_path: String = optional_string(params, "path_node", parent_path)
	if path_node_path.is_empty():
		return error_invalid_params("parent_path or path_node (Path2D/Path3D) required")
	var path_n := find_node_by_path(path_node_path)
	if path_n == null:
		return error_not_found("Path node")
	var is_3d := path_n is Path3D
	var follow: Node
	if is_3d:
		var f := PathFollow3D.new()
		f.name = optional_string(params, "name", "PathFollow3D")
		f.progress_ratio = float(params.get("progress_ratio", 0.0))
		if params.has("progress"):
			f.progress = float(params["progress"])
		f.loop = optional_bool(params, "loop", true)
		if params.has("rotation_mode"):
			var rm := str(params["rotation_mode"]).to_lower()
			match rm:
				"none":
					f.rotation_mode = PathFollow3D.ROTATION_NONE
				"y", "y_fixed":
					f.rotation_mode = PathFollow3D.ROTATION_Y
				"xy":
					f.rotation_mode = PathFollow3D.ROTATION_XY
				"xyz":
					f.rotation_mode = PathFollow3D.ROTATION_XYZ
				"oriented":
					f.rotation_mode = PathFollow3D.ROTATION_ORIENTED
		follow = f
	else:
		if not (path_n is Path2D):
			return error_invalid_params("Parent must be Path2D or Path3D")
		var f2 := PathFollow2D.new()
		f2.name = optional_string(params, "name", "PathFollow2D")
		f2.progress_ratio = float(params.get("progress_ratio", 0.0))
		if params.has("progress"):
			f2.progress = float(params["progress"])
		f2.loop = optional_bool(params, "loop", true)
		f2.rotates = optional_bool(params, "rotates", true)
		follow = f2
	add_child_with_undo(path_n, follow, root, "MCP: PathFollow")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(follow)),
		"path_node": path_node_path,
		"is_3d": is_3d,
	})


func _path_follow_set_progress(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null:
		return error_not_found("PathFollow")
	if n is PathFollow3D:
		var f := n as PathFollow3D
		if params.has("progress_ratio"):
			f.progress_ratio = clampf(float(params["progress_ratio"]), 0.0, 1.0)
		if params.has("progress"):
			f.progress = float(params["progress"])
		if params.has("h_offset"):
			f.h_offset = float(params["h_offset"])
		if params.has("v_offset"):
			f.v_offset = float(params["v_offset"])
		mark_current_scene_unsaved()
		return success({
			"progress": f.progress,
			"progress_ratio": f.progress_ratio,
			"position": {"x": f.global_position.x, "y": f.global_position.y, "z": f.global_position.z},
		})
	if n is PathFollow2D:
		var f2 := n as PathFollow2D
		if params.has("progress_ratio"):
			f2.progress_ratio = clampf(float(params["progress_ratio"]), 0.0, 1.0)
		if params.has("progress"):
			f2.progress = float(params["progress"])
		if params.has("h_offset"):
			f2.h_offset = float(params["h_offset"])
		if params.has("v_offset"):
			f2.v_offset = float(params["v_offset"])
		mark_current_scene_unsaved()
		return success({
			"progress": f2.progress,
			"progress_ratio": f2.progress_ratio,
			"position": {"x": f2.global_position.x, "y": f2.global_position.y},
		})
	return error_invalid_params("Node is not PathFollow2D/3D")


func _path_follow_get_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n is PathFollow3D:
		var f := n as PathFollow3D
		return success({
			"class": "PathFollow3D",
			"progress": f.progress,
			"progress_ratio": f.progress_ratio,
			"loop": f.loop,
			"rotation_mode": f.rotation_mode,
			"h_offset": f.h_offset,
			"v_offset": f.v_offset,
		})
	if n is PathFollow2D:
		var f2 := n as PathFollow2D
		return success({
			"class": "PathFollow2D",
			"progress": f2.progress,
			"progress_ratio": f2.progress_ratio,
			"loop": f2.loop,
			"rotates": f2.rotates,
		})
	return error_not_found("PathFollow")


func _path_follow_set_loop(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	var loop: bool = optional_bool(params, "loop", true)
	if n is PathFollow3D:
		(n as PathFollow3D).loop = loop
	elif n is PathFollow2D:
		(n as PathFollow2D).loop = loop
	else:
		return error_not_found("PathFollow")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "loop": loop})
