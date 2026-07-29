@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Physics joint limit fine-tuning (tutorials/physics gap).


func get_commands() -> Dictionary:
	return {
		"set_pin_joint_params": _set_pin_joint_params,
		"set_hinge_joint_limits": _set_hinge_joint_limits,
		"set_slider_joint_limits": _set_slider_joint_limits,
		"set_generic_6dof_joint_limits": _set_generic_6dof_joint_limits,
		"get_joint_info": _get_joint_info,
		"list_joint_limit_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_joint", "create_physics_body", "get_collision_info"],
	})


func _set_pin_joint_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null:
		return error_not_found("Joint")
	var applied := {}
	if n is PinJoint3D:
		var j := n as PinJoint3D
		if params.has("bias"):
			j.set_param(PinJoint3D.PARAM_BIAS, float(params["bias"]))
			applied["bias"] = j.get_param(PinJoint3D.PARAM_BIAS)
		if params.has("damping"):
			j.set_param(PinJoint3D.PARAM_DAMPING, float(params["damping"]))
			applied["damping"] = j.get_param(PinJoint3D.PARAM_DAMPING)
		if params.has("impulse_clamp"):
			j.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, float(params["impulse_clamp"]))
			applied["impulse_clamp"] = j.get_param(PinJoint3D.PARAM_IMPULSE_CLAMP)
	elif n is PinJoint2D:
		var j2 := n as PinJoint2D
		if params.has("softness") and "softness" in j2:
			j2.softness = float(params["softness"])
			applied["softness"] = j2.softness
	else:
		return error_invalid_params("Not a PinJoint2D/3D")
	if params.has("node_a") and "node_a" in n:
		n.set("node_a", NodePath(str(params["node_a"])))
		applied["node_a"] = str(n.get("node_a"))
	if params.has("node_b") and "node_b" in n:
		n.set("node_b", NodePath(str(params["node_b"])))
		applied["node_b"] = str(n.get("node_b"))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _set_hinge_joint_limits(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is HingeJoint3D):
		return error_not_found("HingeJoint3D")
	var j := n as HingeJoint3D
	var applied := {}
	if params.has("limit_enabled") or params.has("angular_limit_enabled"):
		var en := bool(params.get("limit_enabled", params.get("angular_limit_enabled", true)))
		j.set_flag(HingeJoint3D.FLAG_USE_LIMIT, en)
		applied["limit_enabled"] = en
	if params.has("limit_upper") or params.has("upper"):
		var u := deg_to_rad(float(params.get("limit_upper", params.get("upper", 90))))
		if optional_bool(params, "radians", false):
			u = float(params.get("limit_upper", params.get("upper", 1.57)))
		j.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, u)
		applied["limit_upper"] = j.get_param(HingeJoint3D.PARAM_LIMIT_UPPER)
	if params.has("limit_lower") or params.has("lower"):
		var lo := deg_to_rad(float(params.get("limit_lower", params.get("lower", -90))))
		if optional_bool(params, "radians", false):
			lo = float(params.get("limit_lower", params.get("lower", -1.57)))
		j.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, lo)
		applied["limit_lower"] = j.get_param(HingeJoint3D.PARAM_LIMIT_LOWER)
	if params.has("bias"):
		j.set_param(HingeJoint3D.PARAM_LIMIT_BIAS, float(params["bias"]))
		applied["bias"] = j.get_param(HingeJoint3D.PARAM_LIMIT_BIAS)
	if params.has("softness"):
		j.set_param(HingeJoint3D.PARAM_LIMIT_SOFTNESS, float(params["softness"]))
		applied["softness"] = j.get_param(HingeJoint3D.PARAM_LIMIT_SOFTNESS)
	if params.has("relaxation"):
		j.set_param(HingeJoint3D.PARAM_LIMIT_RELAXATION, float(params["relaxation"]))
		applied["relaxation"] = j.get_param(HingeJoint3D.PARAM_LIMIT_RELAXATION)
	if params.has("motor_enabled"):
		j.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, bool(params["motor_enabled"]))
		applied["motor_enabled"] = bool(params["motor_enabled"])
	if params.has("motor_target_velocity"):
		j.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, float(params["motor_target_velocity"]))
		applied["motor_target_velocity"] = j.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied, "units": "radians stored; pass degrees unless radians=true"})


func _set_slider_joint_limits(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is SliderJoint3D):
		return error_not_found("SliderJoint3D")
	var j := n as SliderJoint3D
	var applied := {}
	if params.has("linear_limit_upper") or params.has("upper"):
		j.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, float(params.get("linear_limit_upper", params.get("upper", 1.0))))
		applied["linear_limit_upper"] = j.get_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER)
	if params.has("linear_limit_lower") or params.has("lower"):
		j.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, float(params.get("linear_limit_lower", params.get("lower", -1.0))))
		applied["linear_limit_lower"] = j.get_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER)
	if params.has("linear_limit_softness"):
		j.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, float(params["linear_limit_softness"]))
		applied["softness"] = true
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _set_generic_6dof_joint_limits(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Generic6DOFJoint3D):
		return error_not_found("Generic6DOFJoint3D")
	var j := n as Generic6DOFJoint3D
	var axis_name: String = optional_string(params, "axis", "x").to_lower()
	var axis := Vector3.AXIS_X
	match axis_name:
		"y":
			axis = Vector3.AXIS_Y
		"z":
			axis = Vector3.AXIS_Z
		_:
			axis = Vector3.AXIS_X
	var applied := {}
	if not j.has_method("set_flag") or not j.has_method("set_param"):
		return error_internal("Generic6DOFJoint3D flag/param API unavailable")
	if params.has("linear_limit_enabled"):
		j.set_flag(axis, Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, bool(params["linear_limit_enabled"]))
		applied["linear_limit_enabled"] = bool(params["linear_limit_enabled"])
	if params.has("angular_limit_enabled"):
		j.set_flag(axis, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, bool(params["angular_limit_enabled"]))
		applied["angular_limit_enabled"] = bool(params["angular_limit_enabled"])
	if params.has("linear_upper"):
		j.set_param(axis, Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, float(params["linear_upper"]))
		applied["linear_upper"] = float(params["linear_upper"])
	if params.has("linear_lower"):
		j.set_param(axis, Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, float(params["linear_lower"]))
		applied["linear_lower"] = float(params["linear_lower"])
	if params.has("angular_upper"):
		var au := float(params["angular_upper"])
		if not optional_bool(params, "radians", false):
			au = deg_to_rad(au)
		j.set_param(axis, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, au)
		applied["angular_upper"] = au
	if params.has("angular_lower"):
		var al := float(params["angular_lower"])
		if not optional_bool(params, "radians", false):
			al = deg_to_rad(al)
		j.set_param(axis, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, al)
		applied["angular_lower"] = al
	if applied.is_empty():
		return error_invalid_params("Provide linear_*/angular_* limit fields and axis=x|y|z")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "axis": axis_name, "applied": applied})


func _get_joint_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null:
		return error_not_found("Node")
	var info := {
		"class": n.get_class(),
		"node_path": r0[0],
	}
	if "node_a" in n:
		info["node_a"] = str(n.get("node_a"))
	if "node_b" in n:
		info["node_b"] = str(n.get("node_b"))
	if n is HingeJoint3D:
		var j := n as HingeJoint3D
		info["limit_enabled"] = j.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
		info["limit_upper"] = j.get_param(HingeJoint3D.PARAM_LIMIT_UPPER)
		info["limit_lower"] = j.get_param(HingeJoint3D.PARAM_LIMIT_LOWER)
		info["motor_enabled"] = j.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
	return success(info)
