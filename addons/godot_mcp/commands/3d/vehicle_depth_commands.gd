@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## VehicleBody3D stack setup - body + wheels recipe.


func get_commands() -> Dictionary:
	return {
		"setup_vehicle_body": _setup_vehicle_body,
		"set_vehicle_wheel_params": _set_vehicle_wheel_params,
		"list_vehicle_wheels": _list_vehicle_wheels,
		"list_vehicle_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["add_vehicle_wheel", "create_physics_body", "setup_camera_3d"],
	})


func _setup_vehicle_body(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var body := VehicleBody3D.new()
	body.name = optional_string(params, "name", "VehicleBody3D")
	body.mass = float(params.get("mass", 80.0))
	if params.has("position"):
		var p = params["position"]
		if p is Dictionary:
			body.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
	add_child_with_undo(parent, body, root, "MCP: VehicleBody3D")
	# Chassis collision
	var col := CollisionShape3D.new()
	col.name = "ChassisCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(
		float(params.get("size_x", 2.0)),
		float(params.get("size_y", 0.6)),
		float(params.get("size_z", 4.0))
	)
	col.shape = box
	col.position = Vector3(0, 0.3, 0)
	add_child_with_undo(body, col, root, "MCP: Vehicle chassis")
	# Optional mesh
	if optional_bool(params, "add_mesh", true):
		var mi := MeshInstance3D.new()
		mi.name = "ChassisMesh"
		var bm := BoxMesh.new()
		bm.size = box.size
		mi.mesh = bm
		mi.position = col.position
		add_child_with_undo(body, mi, root, "MCP: Vehicle mesh")
	# Four wheels
	var wheel_paths: Array = []
	if optional_bool(params, "add_wheels", true):
		var track: float = float(params.get("track", 0.8))
		var wheelbase: float = float(params.get("wheelbase", 1.4))
		var y: float = float(params.get("wheel_y", 0.35))
		var positions := [
			{"name": "WheelFL", "x": -track, "z": wheelbase, "steer": true, "traction": true},
			{"name": "WheelFR", "x": track, "z": wheelbase, "steer": true, "traction": true},
			{"name": "WheelRL", "x": -track, "z": -wheelbase, "steer": false, "traction": true},
			{"name": "WheelRR", "x": track, "z": -wheelbase, "steer": false, "traction": true},
		]
		for wp in positions:
			var w := VehicleWheel3D.new()
			w.name = str(wp["name"])
			w.position = Vector3(float(wp["x"]), y, float(wp["z"]))
			w.use_as_steering = bool(wp["steer"])
			w.use_as_traction = bool(wp["traction"])
			w.wheel_radius = float(params.get("wheel_radius", 0.35))
			w.wheel_rest_length = float(params.get("wheel_rest_length", 0.15))
			w.suspension_stiffness = float(params.get("suspension_stiffness", 50.0))
			w.suspension_max_force = float(params.get("suspension_max_force", 6000.0))
			w.damping_compression = float(params.get("damping_compression", 0.88))
			w.damping_relaxation = float(params.get("damping_relaxation", 0.88))
			add_child_with_undo(body, w, root, "MCP: Vehicle wheel")
			wheel_paths.append(str(root.get_path_to(w)))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(body)),
		"wheels": wheel_paths,
		"hint": "Drive via engine_force / steering on VehicleBody3D at runtime",
	})


func _set_vehicle_wheel_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is VehicleWheel3D):
		return error_not_found("VehicleWheel3D")
	var w := n as VehicleWheel3D
	var applied := {}
	for k in [
		"wheel_radius", "wheel_rest_length", "wheel_friction_slip", "suspension_travel",
		"suspension_stiffness", "suspension_max_force", "damping_compression", "damping_relaxation",
		"use_as_traction", "use_as_steering", "brake", "engine_force", "steering",
	]:
		if params.has(k) and k in w:
			w.set(k, params[k])
			applied[k] = w.get(k)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _list_vehicle_wheels(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var body := find_node_by_path(r0[0])
	if body == null:
		return error_not_found("Node")
	var root := get_edited_root()
	var wheels: Array = []
	for c in body.get_children():
		if c is VehicleWheel3D:
			var w := c as VehicleWheel3D
			wheels.append({
				"path": str(root.get_path_to(w)),
				"name": w.name,
				"steering": w.use_as_steering,
				"traction": w.use_as_traction,
				"radius": w.wheel_radius,
			})
	return success({"wheels": wheels, "count": wheels.size()})
