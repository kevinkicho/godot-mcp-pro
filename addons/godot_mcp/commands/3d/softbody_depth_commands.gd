@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SoftBody3D parameter depth + pinning helpers.


func get_commands() -> Dictionary:
	return {
		"set_soft_body_params": _set_soft_body_params,
		"soft_body_pin_point": _soft_body_pin_point,
		"soft_body_get_info": _soft_body_get_info,
		"list_softbody_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_soft_body", "create_physics_body", "add_mesh_instance"],
	})


func _set_soft_body_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is SoftBody3D):
		return error_not_found("SoftBody3D")
	var sb := n as SoftBody3D
	var applied := {}
	for k in [
		"simulation_precision", "total_mass", "linear_stiffness", "pressure_coefficient",
		"damping_coefficient", "drag_coefficient", "pose_matching_coefficient",
		"parent_collision_ignore", "ray_pickable", "disable_mode",
	]:
		if params.has(k) and k in sb:
			sb.set(k, params[k])
			applied[k] = sb.get(k)
	# aliases
	if params.has("mass") and "total_mass" in sb:
		sb.total_mass = float(params["mass"])
		applied["total_mass"] = sb.total_mass
	if params.has("stiffness") and "linear_stiffness" in sb:
		sb.linear_stiffness = float(params["stiffness"])
		applied["linear_stiffness"] = sb.linear_stiffness
	if params.has("mesh_path") and ResourceLoader.exists(str(params["mesh_path"])):
		var mesh = load(str(params["mesh_path"]))
		if mesh is Mesh:
			sb.mesh = mesh
			applied["mesh"] = str(params["mesh_path"])
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _soft_body_pin_point(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is SoftBody3D):
		return error_not_found("SoftBody3D")
	var sb := n as SoftBody3D
	var point_index: int = int(params.get("point_index", params.get("index", 0)))
	var pinned: bool = optional_bool(params, "pinned", true)
	if sb.has_method("set_point_pinned"):
		var attachment: NodePath = NodePath(optional_string(params, "attachment_path", ""))
		if attachment.is_empty():
			sb.set_point_pinned(point_index, pinned)
		else:
			sb.set_point_pinned(point_index, pinned, attachment)
		mark_current_scene_unsaved()
		return success({"point_index": point_index, "pinned": pinned, "attachment": str(attachment)})
	return error_internal("set_point_pinned unavailable")


func _soft_body_get_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is SoftBody3D):
		return error_not_found("SoftBody3D")
	var sb := n as SoftBody3D
	return success({
		"node_path": r0[0],
		"total_mass": sb.total_mass if "total_mass" in sb else null,
		"linear_stiffness": sb.linear_stiffness if "linear_stiffness" in sb else null,
		"simulation_precision": sb.simulation_precision if "simulation_precision" in sb else null,
		"has_mesh": sb.mesh != null,
		"mesh_path": sb.mesh.resource_path if sb.mesh else "",
	})
