@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Editor viewport focus - human "F to frame selection" / orbit around node.


func get_commands() -> Dictionary:
	return {
		"editor_focus_node": _editor_focus_node,
		"editor_frame_selection": _editor_frame_selection,
		"editor_get_3d_camera": _editor_get_3d_camera,
		"editor_set_3d_camera_transform": _editor_set_3d_camera_transform,
		"list_viewport_focus_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"human": "F frames selection; middle-mouse orbits; this API positions numeric camera",
		"related": ["select_nodes", "set_nodes_transform", "set_main_screen"],
	})


func _editor_focus_node(params: Dictionary) -> Dictionary:
	## Select node and attempt to frame it in 2D/3D editor viewport.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node '%s'" % r0[0])
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	# Select in Scene dock
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)

	var info := {
		"node_path": str(root.get_path_to(node)),
		"class": node.get_class(),
		"selected": true,
	}

	# Switch main screen appropriately
	if node is Node3D or _has_ancestor_class(node, "Node3D"):
		if EditorInterface.has_method("set_main_screen_editor"):
			EditorInterface.set_main_screen_editor("3D")
		info["main_screen"] = "3D"
		var cam_info := _try_focus_3d(node as Node3D if node is Node3D else _find_node3d_ancestor(node))
		info.merge(cam_info)
	elif node is Node2D or node is Control or _has_ancestor_class(node, "Node2D"):
		if EditorInterface.has_method("set_main_screen_editor"):
			EditorInterface.set_main_screen_editor("2D")
		info["main_screen"] = "2D"
		info["hint"] = "2D editor frames selection when focused; use select_nodes + F in editor if needed"
	else:
		info["hint"] = "Node selected; open 2D/3D screen as needed"

	return success(info)


func _editor_frame_selection(params: Dictionary) -> Dictionary:
	var sel := EditorInterface.get_selection().get_selected_nodes()
	if sel.is_empty():
		# Optional paths
		if params.has("node_paths") and params["node_paths"] is Array:
			EditorInterface.get_selection().clear()
			for p in params["node_paths"]:
				var n := find_node_by_path(str(p))
				if n:
					EditorInterface.get_selection().add_node(n)
			sel = EditorInterface.get_selection().get_selected_nodes()
	if sel.is_empty():
		return error_invalid_params("No selection - pass node_paths or select_nodes first")

	var centers: Array = []
	var is_3d := false
	for n in sel:
		if n is Node3D:
			is_3d = true
			centers.append((n as Node3D).global_position)
		elif n is Node2D:
			centers.append((n as Node2D).global_position)
		elif n is Control:
			var c := n as Control
			centers.append(c.global_position + c.size * 0.5)

	if is_3d and centers.size() > 0:
		var avg := Vector3.ZERO
		for v in centers:
			if v is Vector3:
				avg += v
		avg /= float(centers.size())
		var cam_info := _set_editor_cam_look_at(avg, float(params.get("distance", 8.0)))
		if EditorInterface.has_method("set_main_screen_editor"):
			EditorInterface.set_main_screen_editor("3D")
		return success({
			"selected_count": sel.size(),
			"focus_point": {"x": avg.x, "y": avg.y, "z": avg.z},
			"camera": cam_info,
		})

	return success({
		"selected_count": sel.size(),
		"centers": centers,
		"hint": "2D: selection framed when 2D editor has focus; numeric pan via update_property on Camera2D",
	})


func _editor_get_3d_camera(_params: Dictionary) -> Dictionary:
	var cam := _get_editor_3d_camera()
	if cam == null:
		return success({
			"available": false,
			"hint": "Open 3D main screen with a scene root; editor camera may be version-specific",
		})
	var t: Transform3D = cam.global_transform if cam is Node3D else Transform3D.IDENTITY
	var o := t.origin
	var basis := t.basis
	return success({
		"available": true,
		"position": {"x": o.x, "y": o.y, "z": o.z},
		"basis": {
			"x": {"x": basis.x.x, "y": basis.x.y, "z": basis.x.z},
			"y": {"x": basis.y.x, "y": basis.y.y, "z": basis.y.z},
			"z": {"x": basis.z.x, "y": basis.z.y, "z": basis.z.z},
		},
		"fov": cam.fov if "fov" in cam else null,
		"class": cam.get_class(),
	})


func _editor_set_3d_camera_transform(params: Dictionary) -> Dictionary:
	var cam := _get_editor_3d_camera()
	if cam == null or not (cam is Node3D):
		return error_internal("Editor 3D camera not available")
	var node3d := cam as Node3D
	var pos := node3d.global_position
	if params.has("position") and params["position"] is Dictionary:
		var pd: Dictionary = params["position"]
		pos = Vector3(float(pd.get("x", pos.x)), float(pd.get("y", pos.y)), float(pd.get("z", pos.z)))
	else:
		if params.has("x"):
			pos.x = float(params["x"])
		if params.has("y"):
			pos.y = float(params["y"])
		if params.has("z"):
			pos.z = float(params["z"])
	if params.has("look_at"):
		var la = params["look_at"]
		var target := Vector3.ZERO
		if la is Dictionary:
			target = Vector3(float(la.get("x", 0)), float(la.get("y", 0)), float(la.get("z", 0)))
		elif la is Array and la.size() >= 3:
			target = Vector3(float(la[0]), float(la[1]), float(la[2]))
		node3d.look_at_from_position(pos, target, Vector3.UP)
	else:
		node3d.global_position = pos
	if params.has("fov") and "fov" in cam:
		cam.set("fov", float(params["fov"]))
	return success({
		"position": {"x": node3d.global_position.x, "y": node3d.global_position.y, "z": node3d.global_position.z},
		"set": true,
	})


func _try_focus_3d(node: Node3D) -> Dictionary:
	if node == null:
		return {"focus": false}
	var dist: float = 6.0
	# AABB estimate from MeshInstance
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var aabb: AABB = mi.get_aabb()
			var size: float = aabb.size.length()
			if size > 0.01:
				dist = clampf(size * 2.0, 2.0, 50.0)
	return _set_editor_cam_look_at(node.global_position, dist)


func _set_editor_cam_look_at(target: Vector3, distance: float) -> Dictionary:
	var cam := _get_editor_3d_camera()
	if cam == null or not (cam is Node3D):
		return {
			"focus": false,
			"target": {"x": target.x, "y": target.y, "z": target.z},
			"hint": "Could not access editor camera - node still selected",
		}
	var node3d := cam as Node3D
	var offset := Vector3(distance * 0.6, distance * 0.5, distance * 0.6)
	var pos := target + offset
	node3d.look_at_from_position(pos, target, Vector3.UP)
	return {
		"focus": true,
		"target": {"x": target.x, "y": target.y, "z": target.z},
		"camera_position": {"x": pos.x, "y": pos.y, "z": pos.z},
		"distance": distance,
	}


func _get_editor_3d_camera() -> Camera3D:
	# Godot 4: EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	if EditorInterface.has_method("get_editor_viewport_3d"):
		var vp = EditorInterface.get_editor_viewport_3d(0)
		if vp != null and vp.has_method("get_camera_3d"):
			var c = vp.get_camera_3d()
			if c is Camera3D:
				return c as Camera3D
	# Fallback: search editor scene tree
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	return _find_camera3d(base)


func _find_camera3d(n: Node) -> Camera3D:
	if n is Camera3D and n.name.to_lower().contains("camera"):
		return n as Camera3D
	for c in n.get_children():
		var f := _find_camera3d(c)
		if f:
			return f
	return null


func _has_ancestor_class(node: Node, cls: String) -> bool:
	var p := node.get_parent()
	while p:
		if p.is_class(cls):
			return true
		p = p.get_parent()
	return false


func _find_node3d_ancestor(node: Node) -> Node3D:
	var p := node
	while p:
		if p is Node3D:
			return p as Node3D
		p = p.get_parent()
	return null
