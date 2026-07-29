@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Level design vertical - greybox, scatter, playability checks, route playtest hooks.


func get_commands() -> Dictionary:
	return {
		"greybox_room": _greybox_room,
		"greybox_corridor": _greybox_corridor,
		"place_prop_scatter": _place_prop_scatter,
		"stamp_scene_instances": _stamp_scene_instances,
		"validate_level_playable": _validate_level_playable,
		"level_playtest_route": _level_playtest_route,
		"list_level_design_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"flow": [
			"greybox_room / greybox_corridor",
			"tilemap_* or gridmap_* for detailed layout",
			"place_prop_scatter / stamp_scene_instances",
			"setup_navigation_region + bake_navigation_mesh",
			"validate_level_playable",
			"level_playtest_route + playtest_report",
		],
		"tools": get_commands().keys(),
	})


func _greybox_room(params: Dictionary) -> Dictionary:
	## CSGBox room: floor + 4 walls (optional ceiling).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var w: float = float(params.get("width", 10.0))
	var d: float = float(params.get("depth", 10.0))
	var h: float = float(params.get("height", 3.0))
	var wall_t: float = float(params.get("wall_thickness", 0.2))
	var name_s: String = optional_string(params, "name", "Room")
	var room := Node3D.new()
	room.name = name_s
	add_child_with_undo(parent, room, root, "MCP: greybox room")

	var floor := CSGBox3D.new()
	floor.name = "Floor"
	floor.size = Vector3(w, wall_t, d)
	floor.position = Vector3(0, -wall_t * 0.5, 0)
	floor.use_collision = true
	add_child_with_undo(room, floor, root, "MCP: floor")

	var walls: Array = [
		{"n": "WallN", "size": Vector3(w, h, wall_t), "pos": Vector3(0, h * 0.5, -d * 0.5)},
		{"n": "WallS", "size": Vector3(w, h, wall_t), "pos": Vector3(0, h * 0.5, d * 0.5)},
		{"n": "WallE", "size": Vector3(wall_t, h, d), "pos": Vector3(w * 0.5, h * 0.5, 0)},
		{"n": "WallW", "size": Vector3(wall_t, h, d), "pos": Vector3(-w * 0.5, h * 0.5, 0)},
	]
	var created: Array = [str(root.get_path_to(floor))]
	for wdef in walls:
		var wall := CSGBox3D.new()
		wall.name = wdef["n"]
		wall.size = wdef["size"]
		wall.position = wdef["pos"]
		wall.use_collision = true
		add_child_with_undo(room, wall, root, "MCP: wall")
		created.append(str(root.get_path_to(wall)))
	if optional_bool(params, "ceiling", false):
		var ceil := CSGBox3D.new()
		ceil.name = "Ceiling"
		ceil.size = Vector3(w, wall_t, d)
		ceil.position = Vector3(0, h + wall_t * 0.5, 0)
		ceil.use_collision = true
		add_child_with_undo(room, ceil, root, "MCP: ceiling")
		created.append(str(root.get_path_to(ceil)))
	# Optional spawn marker
	var spawn_path := ""
	if optional_bool(params, "with_spawn", true):
		var m := Marker3D.new()
		m.name = "Spawn"
		m.position = Vector3(0, 0.1, 0)
		add_child_with_undo(room, m, root, "MCP: spawn")
		spawn_path = str(root.get_path_to(m))
	mark_current_scene_unsaved()
	return success({
		"room_path": str(root.get_path_to(room)),
		"parts": created,
		"spawn": spawn_path,
		"size": {"width": w, "depth": d, "height": h},
	})


func _greybox_corridor(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var length: float = float(params.get("length", 12.0))
	var width: float = float(params.get("width", 3.0))
	var height: float = float(params.get("height", 3.0))
	var wall_t: float = float(params.get("wall_thickness", 0.2))
	var axis: String = optional_string(params, "axis", "z")  # z or x
	var name_s: String = optional_string(params, "name", "Corridor")
	var corr := Node3D.new()
	corr.name = name_s
	add_child_with_undo(parent, corr, root, "MCP: corridor")
	var floor := CSGBox3D.new()
	floor.name = "Floor"
	if axis == "x":
		floor.size = Vector3(length, wall_t, width)
	else:
		floor.size = Vector3(width, wall_t, length)
	floor.position = Vector3(0, -wall_t * 0.5, 0)
	floor.use_collision = true
	add_child_with_undo(corr, floor, root, "MCP: floor")
	# Two long walls
	for side in [-1, 1]:
		var wall := CSGBox3D.new()
		wall.name = "Wall_%d" % side
		if axis == "x":
			wall.size = Vector3(length, height, wall_t)
			wall.position = Vector3(0, height * 0.5, side * width * 0.5)
		else:
			wall.size = Vector3(wall_t, height, length)
			wall.position = Vector3(side * width * 0.5, height * 0.5, 0)
		wall.use_collision = true
		add_child_with_undo(corr, wall, root, "MCP: wall")
	mark_current_scene_unsaved()
	return success({"corridor_path": str(root.get_path_to(corr)), "axis": axis, "length": length})


func _place_prop_scatter(params: Dictionary) -> Dictionary:
	## Seeded scatter of a scene or MeshInstance primitive in a region.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var count: int = clampi(optional_int(params, "count", 10), 1, 500)
	var seed_v: int = optional_int(params, "seed", 42)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var min_p := Vector3(float(params.get("min_x", -5)), float(params.get("min_y", 0)), float(params.get("min_z", -5)))
	var max_p := Vector3(float(params.get("max_x", 5)), float(params.get("max_y", 0)), float(params.get("max_z", 5)))
	var scene_path: String = optional_string(params, "scene_path", "")
	var packed: PackedScene = null
	if not scene_path.is_empty():
		if not scene_path.begins_with("res://"):
			scene_path = "res://" + scene_path.trim_prefix("/")
		if ResourceLoader.exists(scene_path):
			packed = load(scene_path) as PackedScene
	var container := Node3D.new()
	container.name = optional_string(params, "name", "Scatter")
	add_child_with_undo(parent, container, root, "MCP: scatter")
	var placed: Array = []
	var min_dist: float = float(params.get("min_distance", 0.0))
	var positions: Array = []
	for i in count:
		var pos := Vector3(
			rng.randf_range(min_p.x, max_p.x),
			rng.randf_range(min_p.y, max_p.y),
			rng.randf_range(min_p.z, max_p.z)
		)
		if min_dist > 0.0:
			var ok := true
			for p in positions:
				if pos.distance_to(p) < min_dist:
					ok = false
					break
			if not ok:
				continue
		positions.append(pos)
		var inst: Node3D
		if packed:
			inst = packed.instantiate() as Node3D
			if inst == null:
				inst = Node3D.new()
				var mi := MeshInstance3D.new()
				mi.mesh = BoxMesh.new()
				inst.add_child(mi)
		else:
			inst = MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.5, 0.5)
			(inst as MeshInstance3D).mesh = box
		inst.name = "Prop_%d" % i
		inst.position = pos
		if optional_bool(params, "random_yaw", true):
			inst.rotation.y = rng.randf_range(0, TAU)
		add_child_with_undo(container, inst, root, "MCP: prop")
		placed.append(str(root.get_path_to(inst)))
	mark_current_scene_unsaved()
	return success({
		"container": str(root.get_path_to(container)),
		"placed_count": placed.size(),
		"seed": seed_v,
		"scene_path": scene_path,
	})


func _stamp_scene_instances(params: Dictionary) -> Dictionary:
	## Place multiple instances of a scene at given positions [{x,y,z}, ...].
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var scene_path: String = optional_string(params, "scene_path", "")
	if scene_path.is_empty():
		return error_invalid_params("scene_path required")
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path.trim_prefix("/")
	if not ResourceLoader.exists(scene_path):
		return error_not_found(scene_path)
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return error_internal("Not a PackedScene")
	var positions: Array = params.get("positions", [])
	if not positions is Array or positions.is_empty():
		return error_invalid_params("positions: Array of {x,y,z} or [x,y,z]")
	var placed: Array = []
	var i := 0
	for p in positions:
		var pos := Vector3.ZERO
		if p is Dictionary:
			pos = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
		elif p is Array and p.size() >= 3:
			pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var inst := packed.instantiate()
		inst.name = optional_string(params, "name_prefix", "Stamp") + str(i)
		if inst is Node3D:
			(inst as Node3D).position = pos
		add_child_with_undo(parent, inst, root, "MCP: stamp")
		placed.append(str(root.get_path_to(inst)))
		i += 1
	mark_current_scene_unsaved()
	return success({"placed": placed, "count": placed.size(), "scene_path": scene_path})


func _validate_level_playable(params: Dictionary) -> Dictionary:
	## Structural playability: spawn/goal markers, nav region, collision presence.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var issues: Array = []
	var spawn_name: String = optional_string(params, "spawn_name", "Spawn")
	var goal_name: String = optional_string(params, "goal_name", "Goal")
	var spawn := _find_named(root, spawn_name)
	var goal := _find_named(root, goal_name)
	if spawn == null:
		issues.append({"severity": "warning", "message": "No '%s' marker found" % spawn_name})
	if goal == null:
		issues.append({"severity": "info", "message": "No '%s' marker (optional)" % goal_name})
	var nav := _find_type(root, "NavigationRegion3D")
	var nav2 := _find_type(root, "NavigationRegion2D")
	if nav == null and nav2 == null:
		issues.append({"severity": "warning", "message": "No NavigationRegion - bake nav for AI/path checks"})
	var colliders := _count_type(root, "CollisionShape3D") + _count_type(root, "CollisionShape2D")
	if colliders == 0:
		issues.append({"severity": "warning", "message": "No collision shapes - level may not be solid"})
	var dist := -1.0
	if spawn is Node3D and goal is Node3D:
		dist = (spawn as Node3D).global_position.distance_to((goal as Node3D).global_position)
		if dist < 0.5:
			issues.append({"severity": "info", "message": "Spawn and Goal nearly coincide"})
	var ok := true
	for i in issues:
		if str(i.get("severity")) == "error":
			ok = false
	return success({
		"ok": ok,
		"spawn_found": spawn != null,
		"goal_found": goal != null,
		"spawn_goal_distance": dist,
		"has_navigation": nav != null or nav2 != null,
		"collision_shape_count": colliders,
		"issues": issues,
		"hint": "level_playtest_route after bake_navigation_mesh; playtest_report for full loop",
	})


func _level_playtest_route(params: Dictionary) -> Dictionary:
	## Prepare a route playtest: ensure runtime, return waypoints + suggested agent steps.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var spawn_name: String = optional_string(params, "spawn_name", "Spawn")
	var goal_name: String = optional_string(params, "goal_name", "Goal")
	var waypoints: Array = params.get("waypoints", [])
	var spawn := _find_named(root, spawn_name)
	var goal := _find_named(root, goal_name)
	var route: Array = []
	if spawn is Node3D:
		var p: Vector3 = (spawn as Node3D).global_position
		route.append({"name": "spawn", "x": p.x, "y": p.y, "z": p.z})
	if waypoints is Array:
		for w in waypoints:
			if w is Dictionary:
				route.append(w)
			elif w is String:
				var n := _find_named(root, str(w))
				if n is Node3D:
					var gp: Vector3 = (n as Node3D).global_position
					route.append({"name": str(w), "x": gp.x, "y": gp.y, "z": gp.z})
	if goal is Node3D:
		var g: Vector3 = (goal as Node3D).global_position
		route.append({"name": "goal", "x": g.x, "y": g.y, "z": g.z})
	return success({
		"route": route,
		"point_count": route.size(),
		"agent_steps": [
			"play_scene or run_session_start",
			"For each waypoint: move_to / navigate_to or set CharacterBody position",
			"assert_node_state on player",
			"run_record_start/stop optional video",
			"playtest_report",
		],
		"hint": "Use NavigationAgent + set_navigation_agent_target along route for AI path follow",
	})


func _find_named(node: Node, name_s: String) -> Node:
	if node.name == name_s:
		return node
	for c in node.get_children():
		var f := _find_named(c, name_s)
		if f:
			return f
	return null


func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for c in node.get_children():
		var f := _find_type(c, type_name)
		if f:
			return f
	return null


func _count_type(node: Node, type_name: String) -> int:
	var n := 1 if node.is_class(type_name) else 0
	for c in node.get_children():
		n += _count_type(c, type_name)
	return n
