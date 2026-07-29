@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## CharacterBody2D/3D motion surface — floor/wall/snap/up_direction (human CharacterBody inspector).


func get_commands() -> Dictionary:
	return {
		"set_character_body_motion": _set_motion,
		"get_character_body_info": _get_info,
		"apply_character_body_preset": _apply_preset,
		"list_character_body_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_character_2d", "setup_character_3d", "create_platformer_controller_script", "setup_collision"],
		"presets": ["platformer_2d", "topdown_2d", "fps_3d", "third_person_3d"],
	})


func _body(path: String) -> Node:
	var n := find_node_by_path(path)
	if n is CharacterBody2D or n is CharacterBody3D:
		return n
	return null


func _get_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var b := _body(r0[0])
	if b == null:
		return error_not_found("CharacterBody2D/3D")
	var info := {
		"node_path": r0[0],
		"class": b.get_class(),
		"motion_mode": b.get("motion_mode") if "motion_mode" in b else null,
		"up_direction": null,
		"floor_stop_on_slope": b.get("floor_stop_on_slope") if "floor_stop_on_slope" in b else null,
		"floor_constant_speed": b.get("floor_constant_speed") if "floor_constant_speed" in b else null,
		"floor_block_on_wall": b.get("floor_block_on_wall") if "floor_block_on_wall" in b else null,
		"floor_max_angle": b.get("floor_max_angle") if "floor_max_angle" in b else null,
		"floor_snap_length": b.get("floor_snap_length") if "floor_snap_length" in b else null,
		"wall_min_slide_angle": b.get("wall_min_slide_angle") if "wall_min_slide_angle" in b else null,
		"safe_margin": b.get("safe_margin") if "safe_margin" in b else null,
		"platform_on_leave": b.get("platform_on_leave") if "platform_on_leave" in b else null,
		"collision_layer": b.get("collision_layer"),
		"collision_mask": b.get("collision_mask"),
	}
	if "up_direction" in b:
		var u = b.get("up_direction")
		if u is Vector2:
			info["up_direction"] = {"x": u.x, "y": u.y}
		elif u is Vector3:
			info["up_direction"] = {"x": u.x, "y": u.y, "z": u.z}
	if b is CharacterBody2D:
		var b2: CharacterBody2D = b as CharacterBody2D
		info["velocity"] = {"x": b2.velocity.x, "y": b2.velocity.y}
		info["is_on_floor"] = b2.is_on_floor()
		info["is_on_wall"] = b2.is_on_wall()
		info["is_on_ceiling"] = b2.is_on_ceiling()
	elif b is CharacterBody3D:
		var b3: CharacterBody3D = b as CharacterBody3D
		info["velocity"] = {"x": b3.velocity.x, "y": b3.velocity.y, "z": b3.velocity.z}
		info["is_on_floor"] = b3.is_on_floor()
		info["is_on_wall"] = b3.is_on_wall()
		info["is_on_ceiling"] = b3.is_on_ceiling()
	return success(info)


func _set_motion(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var b := _body(r0[0])
	if b == null:
		return error_not_found("CharacterBody2D/3D")
	var applied := {}
	var keys := [
		"motion_mode", "floor_stop_on_slope", "floor_constant_speed", "floor_block_on_wall",
		"floor_max_angle", "floor_snap_length", "wall_min_slide_angle", "safe_margin",
		"platform_on_leave", "platform_floor_layers", "platform_wall_layers",
		"slide_on_ceiling", "max_slides",
	]
	for k in keys:
		if params.has(k) and k in b:
			b.set(k, params[k])
			applied[k] = params[k]
	if params.has("up_direction") and "up_direction" in b:
		var u = params["up_direction"]
		if b is CharacterBody2D:
			if u is Dictionary:
				b.set("up_direction", Vector2(float(u.get("x", 0)), float(u.get("y", -1))))
			applied["up_direction"] = {"x": (b as CharacterBody2D).up_direction.x, "y": (b as CharacterBody2D).up_direction.y}
		elif b is CharacterBody3D:
			if u is Dictionary:
				b.set("up_direction", Vector3(float(u.get("x", 0)), float(u.get("y", 1)), float(u.get("z", 0))))
			var ud: Vector3 = (b as CharacterBody3D).up_direction
			applied["up_direction"] = {"x": ud.x, "y": ud.y, "z": ud.z}
	if params.has("velocity"):
		var v = params["velocity"]
		if b is CharacterBody2D and v is Dictionary:
			(b as CharacterBody2D).velocity = Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
			applied["velocity"] = v
		elif b is CharacterBody3D and v is Dictionary:
			(b as CharacterBody3D).velocity = Vector3(float(v.get("x", 0)), float(v.get("y", 0)), float(v.get("z", 0)))
			applied["velocity"] = v
	if params.has("collision_layer"):
		b.set("collision_layer", int(params["collision_layer"]))
		applied["collision_layer"] = b.get("collision_layer")
	if params.has("collision_mask"):
		b.set("collision_mask", int(params["collision_mask"]))
		applied["collision_mask"] = b.get("collision_mask")
	if applied.is_empty():
		return error_invalid_params("Provide motion fields (floor_snap_length, up_direction, motion_mode, …)")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _apply_preset(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var b := _body(r0[0])
	if b == null:
		return error_not_found("CharacterBody2D/3D")
	var preset: String = optional_string(params, "preset", "platformer_2d").to_lower()
	var cfg := {}
	match preset:
		"platformer_2d", "platformer":
			if not (b is CharacterBody2D):
				return error_invalid_params("platformer_2d needs CharacterBody2D")
			cfg = {
				"motion_mode": 0,  # GROUNDED
				"up_direction": {"x": 0, "y": -1},
				"floor_stop_on_slope": true,
				"floor_constant_speed": false,
				"floor_block_on_wall": true,
				"floor_max_angle": deg_to_rad(45.0),
				"floor_snap_length": 4.0,
				"safe_margin": 0.08,
			}
		"topdown_2d", "topdown":
			if not (b is CharacterBody2D):
				return error_invalid_params("topdown_2d needs CharacterBody2D")
			cfg = {
				"motion_mode": 1,  # FLOATING
				"up_direction": {"x": 0, "y": -1},
				"floor_snap_length": 0.0,
				"safe_margin": 0.08,
			}
		"fps_3d", "fps":
			if not (b is CharacterBody3D):
				return error_invalid_params("fps_3d needs CharacterBody3D")
			cfg = {
				"motion_mode": 0,
				"up_direction": {"x": 0, "y": 1, "z": 0},
				"floor_stop_on_slope": true,
				"floor_max_angle": deg_to_rad(45.0),
				"floor_snap_length": 0.1,
				"safe_margin": 0.001,
			}
		"third_person_3d", "tps":
			if not (b is CharacterBody3D):
				return error_invalid_params("third_person_3d needs CharacterBody3D")
			cfg = {
				"motion_mode": 0,
				"up_direction": {"x": 0, "y": 1, "z": 0},
				"floor_stop_on_slope": true,
				"floor_constant_speed": true,
				"floor_max_angle": deg_to_rad(50.0),
				"floor_snap_length": 0.2,
				"safe_margin": 0.001,
			}
		_:
			return error_invalid_params("Unknown preset — platformer_2d|topdown_2d|fps_3d|third_person_3d")
	cfg["node_path"] = r0[0]
	return _set_motion(cfg)
