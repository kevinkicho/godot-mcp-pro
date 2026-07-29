@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Structural 3D nodes agents need constantly - notifiers, remote transform, world boundary.


func get_commands() -> Dictionary:
	return {
		"setup_visible_on_screen_notifier": _setup_visible_on_screen_notifier,
		"setup_visible_on_screen_enabler": _setup_visible_on_screen_enabler,
		"setup_remote_transform": _setup_remote_transform,
		"setup_world_boundary_body": _setup_world_boundary_body,
		"setup_occluder_instance": _setup_occluder_instance,
		"setup_marker_3d": _setup_marker_3d,
		"list_structure_3d_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_orbit_camera_3d", "add_occluder_instance_3d", "set_visibility_range", "create_stream_manager_script"],
		"docs": "Visibility notifiers, RemoteTransform, WorldBoundaryShape - core scene structure",
	})


func _setup_visible_on_screen_notifier(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var is_3d: bool = optional_bool(params, "is_3d", parent is Node3D or not (parent is Node2D))
	var node: Node
	if is_3d:
		var n := VisibleOnScreenNotifier3D.new()
		n.name = optional_string(params, "name", "VisibleOnScreenNotifier3D")
		if params.has("aabb"):
			var a = params["aabb"]
			if a is Dictionary:
				n.aabb = AABB(
					Vector3(float(a.get("x", -1)), float(a.get("y", -1)), float(a.get("z", -1))),
					Vector3(float(a.get("sx", 2)), float(a.get("sy", 2)), float(a.get("sz", 2)))
				)
		node = n
	else:
		var n2 := VisibleOnScreenNotifier2D.new()
		n2.name = optional_string(params, "name", "VisibleOnScreenNotifier2D")
		node = n2
	add_child_with_undo(parent, node, root, "MCP: VisibleOnScreenNotifier")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class()})


func _setup_visible_on_screen_enabler(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var is_3d: bool = optional_bool(params, "is_3d", parent is Node3D or not (parent is Node2D))
	var node: Node
	if is_3d:
		var n := VisibleOnScreenEnabler3D.new()
		n.name = optional_string(params, "name", "VisibleOnScreenEnabler3D")
		if params.has("enable_mode") and "enable_mode" in n:
			n.set("enable_mode", int(params["enable_mode"]))
		node = n
	else:
		var n2 := VisibleOnScreenEnabler2D.new()
		n2.name = optional_string(params, "name", "VisibleOnScreenEnabler2D")
		node = n2
	add_child_with_undo(parent, node, root, "MCP: VisibleOnScreenEnabler")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class(),
		"hint": "Disables process/visibility when off-screen - pairs with streaming/LOD"})


func _setup_remote_transform(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var is_3d: bool = optional_bool(params, "is_3d", parent is Node3D or not (parent is Node2D))
	var remote_path: String = optional_string(params, "remote_path", "")
	var node: Node
	if is_3d:
		var rt := RemoteTransform3D.new()
		rt.name = optional_string(params, "name", "RemoteTransform3D")
		if not remote_path.is_empty():
			rt.remote_path = NodePath(remote_path)
		if params.has("update_position"):
			rt.update_position = bool(params["update_position"])
		if params.has("update_rotation"):
			rt.update_rotation = bool(params["update_rotation"])
		if params.has("update_scale"):
			rt.update_scale = bool(params["update_scale"])
		node = rt
	else:
		var rt2 := RemoteTransform2D.new()
		rt2.name = optional_string(params, "name", "RemoteTransform2D")
		if not remote_path.is_empty():
			rt2.remote_path = NodePath(remote_path)
		node = rt2
	add_child_with_undo(parent, node, root, "MCP: RemoteTransform")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "remote_path": remote_path})


func _setup_world_boundary_body(params: Dictionary) -> Dictionary:
	## Infinite plane collider - floors/kill planes.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var is_3d: bool = optional_bool(params, "is_3d", true)
	if is_3d:
		var body := StaticBody3D.new()
		body.name = optional_string(params, "name", "WorldBoundary")
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sh := WorldBoundaryShape3D.new()
		col.shape = sh
		add_child_with_undo(parent, body, root, "MCP: WorldBoundary body")
		add_child_with_undo(body, col, root, "MCP: WorldBoundary shape")
		if params.has("position"):
			var p = params["position"]
			if p is Dictionary:
				body.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
		mark_current_scene_unsaved()
		return success({"node_path": str(root.get_path_to(body)), "type": "StaticBody3D+WorldBoundaryShape3D"})
	var body2 := StaticBody2D.new()
	body2.name = optional_string(params, "name", "WorldBoundary2D")
	var col2 := CollisionShape2D.new()
	col2.name = "CollisionShape2D"
	var sh2 := WorldBoundaryShape2D.new()
	col2.shape = sh2
	add_child_with_undo(parent, body2, root, "MCP: WorldBoundary2D")
	add_child_with_undo(body2, col2, root, "MCP: WorldBoundary2D shape")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(body2)), "type": "StaticBody2D+WorldBoundaryShape2D"})


func _setup_occluder_instance(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var occ := OccluderInstance3D.new()
	occ.name = optional_string(params, "name", "OccluderInstance3D")
	var kind: String = optional_string(params, "shape", "box").to_lower()
	match kind:
		"sphere":
			if ClassDB.class_exists("SphereOccluder3D"):
				occ.occluder = ClassDB.instantiate("SphereOccluder3D")
		"quad":
			if ClassDB.class_exists("QuadOccluder3D"):
				occ.occluder = ClassDB.instantiate("QuadOccluder3D")
		_:
			if ClassDB.class_exists("BoxOccluder3D"):
				var box = ClassDB.instantiate("BoxOccluder3D")
				if params.has("size") and box and "size" in box:
					var s = params["size"]
					if s is Dictionary:
						box.set("size", Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1))))
				occ.occluder = box
	add_child_with_undo(parent, occ, root, "MCP: OccluderInstance3D")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(occ)), "shape": kind})


func _setup_marker_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var is_3d: bool = optional_bool(params, "is_3d", true)
	var node: Node
	if is_3d:
		var m := Marker3D.new()
		m.name = optional_string(params, "name", "Marker3D")
		if params.has("position"):
			var p = params["position"]
			if p is Dictionary:
				m.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
		if params.has("gizmo_extents") and "gizmo_extents" in m:
			m.gizmo_extents = float(params["gizmo_extents"])
		node = m
	else:
		var m2 := Marker2D.new()
		m2.name = optional_string(params, "name", "Marker2D")
		node = m2
	add_child_with_undo(parent, node, root, "MCP: Marker")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class(),
		"hint": "Use for spawns, cameras, dialogue anchors"})
