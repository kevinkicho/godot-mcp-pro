@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Utility nodes - SpringArm, RemoteTransform3D, notifiers, markers, groups helpers.


func get_commands() -> Dictionary:
	return {
		# setup_spring_arm_3d canonical in spring_arm_camera_commands
		"setup_remote_transform_3d": _setup_remote_transform_3d,
		"setup_visible_on_screen_notifier_3d": _setup_visible_on_screen_notifier_3d,
		"setup_marker_2d": _setup_marker_2d,
		# setup_marker_3d canonical in structure_3d_commands
		"setup_ray_cast_query_script": _setup_ray_cast_query_script,
		"list_groups_in_scene": _list_groups_in_scene,
		"add_node_to_group": _add_node_to_group,
		"remove_node_from_group": _remove_node_from_group,
		"create_state_machine_script": _create_state_machine_script,
	}


func _setup_spring_arm_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var arm := SpringArm3D.new()
	arm.name = optional_string(params, "name", "SpringArm3D")
	arm.spring_length = float(params.get("spring_length", 4.0))
	arm.margin = float(params.get("margin", 0.01))
	if params.has("collision_mask"):
		arm.collision_mask = int(params["collision_mask"])
	add_child_with_undo(parent, arm, root, "MCP: Add SpringArm3D")
	# Optional camera child
	if optional_bool(params, "with_camera", false):
		var cam := Camera3D.new()
		cam.name = "Camera3D"
		arm.add_child(cam)
		cam.owner = root
	return success({"node_path": str(root.get_path_to(arm)), "spring_length": arm.spring_length})


func _setup_remote_transform_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var rt := RemoteTransform3D.new()
	rt.name = optional_string(params, "name", "RemoteTransform3D")
	var remote: String = optional_string(params, "remote_path", "")
	if not remote.is_empty():
		rt.remote_path = NodePath(remote)
	rt.update_position = optional_bool(params, "update_position", true)
	rt.update_rotation = optional_bool(params, "update_rotation", true)
	rt.update_scale = optional_bool(params, "update_scale", false)
	add_child_with_undo(parent, rt, root, "MCP: Add RemoteTransform3D")
	return success({"node_path": str(root.get_path_to(rt)), "remote_path": str(rt.remote_path)})


func _setup_visible_on_screen_notifier_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var n := VisibleOnScreenNotifier3D.new()
	n.name = optional_string(params, "name", "VisibleOnScreenNotifier3D")
	if params.has("aabb"):
		var a = params["aabb"]
		if a is Dictionary:
			n.aabb = AABB(
				Vector3(float(a.get("x", -0.5)), float(a.get("y", -0.5)), float(a.get("z", -0.5))),
				Vector3(float(a.get("sx", 1)), float(a.get("sy", 1)), float(a.get("sz", 1)))
			)
	add_child_with_undo(parent, n, root, "MCP: Add VisibleOnScreenNotifier3D")
	return success({"node_path": str(root.get_path_to(n))})


func _setup_marker_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var m := Marker2D.new()
	m.name = optional_string(params, "name", "Marker2D")
	if params.has("gizmo_extents"):
		m.gizmo_extents = float(params["gizmo_extents"])
	add_child_with_undo(parent, m, root, "MCP: Add Marker2D")
	return success({"node_path": str(root.get_path_to(m))})


func _setup_marker_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var m := Marker3D.new()
	m.name = optional_string(params, "name", "Marker3D")
	if params.has("gizmo_extents"):
		m.gizmo_extents = float(params["gizmo_extents"])
	add_child_with_undo(parent, m, root, "MCP: Add Marker3D")
	return success({"node_path": str(root.get_path_to(m))})


func _setup_ray_cast_query_script(params: Dictionary) -> Dictionary:
	## Helper script for one-shot PhysicsDirectSpaceState ray queries (2D/3D).
	var path: String = optional_string(params, "path", "res://scripts/raycast_util.gd")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var content := """extends RefCounted
## MCP raycast utilities - call from any node with get_world_2d/3d().

static func ray_3d(world: World3D, from: Vector3, to: Vector3, mask: int = 0xFFFFFFFF, collide_areas := false) -> Dictionary:
	var space := world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = mask
	q.collide_with_areas = collide_areas
	return space.intersect_ray(q)

static func ray_2d(world: World2D, from: Vector2, to: Vector2, mask: int = 0xFFFFFFFF, collide_areas := false) -> Dictionary:
	var space := world.direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = mask
	q.collide_with_areas = collide_areas
	return space.intersect_ray(q)
"""
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "created": true})


func _list_groups_in_scene(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var groups := {}
	var q: Array = [root]
	while not q.is_empty():
		var n: Node = q.pop_front()
		for g in n.get_groups():
			var gs := str(g)
			if gs.begins_with("_"):
				continue  # skip internal
			if not groups.has(gs):
				groups[gs] = []
			groups[gs].append(str(root.get_path_to(n)))
		for c in n.get_children():
			q.append(c)
	var out: Array = []
	for gname in groups.keys():
		out.append({"group": gname, "nodes": groups[gname], "count": groups[gname].size()})
	out.sort_custom(func(a, b): return str(a["group"]) < str(b["group"]))
	return success({"groups": out, "group_count": out.size()})


func _add_node_to_group(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var g_r := require_string(params, "group")
	if g_r[1] != null:
		return g_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var persistent: bool = optional_bool(params, "persistent", true)
	node.add_to_group(g_r[0], persistent)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "group": g_r[0], "groups": node.get_groups()})


func _remove_node_from_group(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var g_r := require_string(params, "group")
	if g_r[1] != null:
		return g_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	node.remove_from_group(g_r[0])
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "group": g_r[0], "groups": node.get_groups()})


func _create_state_machine_script(params: Dictionary) -> Dictionary:
	## Lightweight non-animation FSM template (gameplay states).
	var path: String = optional_string(params, "path", "res://scripts/state_machine.gd")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var content := """extends Node
## MCP generic state machine - assign state Node children or register callables.
signal state_changed(from_state: StringName, to_state: StringName)

@export var initial_state: StringName = &""
var _state: StringName = &""
var _states: Dictionary = {}  # StringName -> Node (optional child states)

func _ready() -> void:
	for c in get_children():
		_states[StringName(c.name)] = c
		if c.has_method("exit"):
			pass
	if initial_state != &"":
		change_state(initial_state)
	elif not _states.is_empty():
		change_state(_states.keys()[0])

func get_state() -> StringName:
	return _state

func change_state(to: StringName) -> void:
	if to == _state:
		return
	var from := _state
	if _states.has(from) and _states[from].has_method("exit"):
		_states[from].exit()
	_state = to
	if _states.has(to) and _states[to].has_method("enter"):
		_states[to].enter()
	state_changed.emit(from, to)

func _physics_process(delta: float) -> void:
	if _states.has(_state) and _states[_state].has_method("physics_update"):
		_states[_state].physics_update(delta)

func _process(delta: float) -> void:
	if _states.has(_state) and _states[_state].has_method("update"):
		_states[_state].update(delta)
"""
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "hint": "Add state child nodes with enter/exit/update methods."})
