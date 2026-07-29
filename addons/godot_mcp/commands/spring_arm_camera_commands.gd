@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SpringArm3D third-person camera stack — human TPS camera setup.


func get_commands() -> Dictionary:
	return {
		"setup_spring_arm_3d": _setup_spring_arm,
		"setup_third_person_camera_rig": _setup_tps_rig,
		"set_spring_arm_params": _set_params,
		"list_spring_arm_camera_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_camera_3d_node", "setup_third_person_camera", "setup_orbit_camera_3d", "apply_character_body_preset"],
	})


func _setup_spring_arm(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var arm := SpringArm3D.new()
	arm.name = optional_string(params, "name", "SpringArm3D")
	arm.spring_length = float(params.get("spring_length", params.get("length", 4.0)))
	if params.has("margin"):
		arm.margin = float(params["margin"])
	if params.has("collision_mask"):
		arm.collision_mask = int(params["collision_mask"])
	if optional_bool(params, "use_sphere_shape", true):
		var sh := SphereShape3D.new()
		sh.radius = float(params.get("shape_radius", 0.2))
		arm.shape = sh
	if params.has("rotation_degrees") and params["rotation_degrees"] is Dictionary:
		var r: Dictionary = params["rotation_degrees"]
		arm.rotation_degrees = Vector3(float(r.get("x", -20)), float(r.get("y", 0)), float(r.get("z", 0)))
	elif params.has("pitch_degrees"):
		arm.rotation_degrees = Vector3(float(params["pitch_degrees"]), float(params.get("yaw_degrees", 0)), 0)
	add_child_with_undo(parent, arm, root, "MCP: SpringArm3D")
	var cam_path := ""
	if optional_bool(params, "add_camera", true):
		var cam := Camera3D.new()
		cam.name = optional_string(params, "camera_name", "Camera3D")
		if params.has("fov"):
			cam.fov = float(params["fov"])
		add_child_with_undo(arm, cam, root, "MCP: Camera on SpringArm")
		if optional_bool(params, "make_current", true):
			cam.current = true
		cam_path = str(root.get_path_to(cam))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(arm)),
		"camera_path": cam_path,
		"spring_length": arm.spring_length,
	})


func _setup_tps_rig(params: Dictionary) -> Dictionary:
	## Pivot (yaw) → SpringArm (pitch+length) → Camera3D under character.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var pivot := Node3D.new()
	pivot.name = optional_string(params, "pivot_name", "CameraPivot")
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		pivot.position = Vector3(float(p.get("x", 0)), float(p.get("y", 1.6)), float(p.get("z", 0)))
	else:
		pivot.position = Vector3(0, float(params.get("height", 1.6)), 0)
	add_child_with_undo(parent, pivot, root, "MCP: TPS CameraPivot")
	var arm_res := _setup_spring_arm({
		"parent_path": str(root.get_path_to(pivot)),
		"name": "SpringArm3D",
		"spring_length": float(params.get("spring_length", 4.0)),
		"pitch_degrees": float(params.get("pitch_degrees", -20)),
		"yaw_degrees": 0,
		"add_camera": true,
		"make_current": optional_bool(params, "make_current", true),
		"fov": params.get("fov", 75),
		"collision_mask": params.get("collision_mask", 1),
		"shape_radius": params.get("shape_radius", 0.2),
	})
	return success({
		"pivot_path": str(root.get_path_to(pivot)),
		"spring_arm": arm_res.get("result", arm_res),
		"hint": "Rotate CameraPivot.y for yaw; SpringArm.rotation.x for pitch",
	})


func _set_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is SpringArm3D):
		return error_not_found("SpringArm3D")
	var arm: SpringArm3D = n as SpringArm3D
	var applied := {}
	if params.has("spring_length") or params.has("length"):
		arm.spring_length = float(params.get("spring_length", params.get("length", arm.spring_length)))
		applied["spring_length"] = arm.spring_length
	if params.has("margin"):
		arm.margin = float(params["margin"])
		applied["margin"] = arm.margin
	if params.has("collision_mask"):
		arm.collision_mask = int(params["collision_mask"])
		applied["collision_mask"] = arm.collision_mask
	if params.has("pitch_degrees"):
		arm.rotation_degrees.x = float(params["pitch_degrees"])
		applied["pitch_degrees"] = arm.rotation_degrees.x
	if params.has("yaw_degrees"):
		arm.rotation_degrees.y = float(params["yaw_degrees"])
		applied["yaw_degrees"] = arm.rotation_degrees.y
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})
