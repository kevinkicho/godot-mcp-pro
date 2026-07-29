@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## CameraAttributes + DOF/exposure - critical cinematic / FPS look surface.


func get_commands() -> Dictionary:
	return {
		"create_camera_attributes_practical": _create_practical,
		"create_camera_attributes_physical": _create_physical,
		"assign_camera_attributes": _assign,
		"set_camera_attributes_params": _set_params,
		"set_camera_dof": _set_dof,
		"set_camera_exposure": _set_exposure,
		"list_camera_attributes_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_camera_3d", "setup_first_person_camera", "setup_cinematic_path_camera",
		"configure_glow", "apply_environment_preset",
	], {
		"flow": [
			"create_camera_attributes_practical path=res://cam_attrs.tres",
			"assign_camera_attributes node_path=Camera3D attributes_path=...",
			"set_camera_dof / set_camera_exposure for polish",
		],
	})


func _create_practical(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://resources/camera_attributes_practical.tres")
	if not ClassDB.class_exists("CameraAttributesPractical"):
		return error_internal("CameraAttributesPractical unavailable")
	var attrs: Resource = ClassDB.instantiate("CameraAttributesPractical")
	_apply_common(attrs, params)
	if params.has("dof_blur_amount") and "dof_blur_amount" in attrs:
		attrs.set("dof_blur_amount", float(params["dof_blur_amount"]))
	if params.has("dof_blur_far_enabled") and "dof_blur_far_distance" in attrs:
		attrs.set("dof_blur_far_enabled", bool(params.get("dof_blur_far_enabled", true)))
	if params.has("dof_blur_far_distance"):
		attrs.set("dof_blur_far_distance", float(params["dof_blur_far_distance"]))
	if params.has("dof_blur_near_enabled"):
		attrs.set("dof_blur_near_enabled", bool(params["dof_blur_near_enabled"]))
	if params.has("dof_blur_near_distance"):
		attrs.set("dof_blur_near_distance", float(params["dof_blur_near_distance"]))
	return save_resource_to_res(attrs, path, optional_bool(params, "overwrite", false))


func _create_physical(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://resources/camera_attributes_physical.tres")
	if not ClassDB.class_exists("CameraAttributesPhysical"):
		return error_internal("CameraAttributesPhysical unavailable")
	var attrs: Resource = ClassDB.instantiate("CameraAttributesPhysical")
	_apply_common(attrs, params)
	if params.has("frustum_focal_length") and "frustum_focal_length" in attrs:
		attrs.set("frustum_focal_length", float(params["frustum_focal_length"]))
	if params.has("frustum_focus_distance") and "frustum_focus_distance" in attrs:
		attrs.set("frustum_focus_distance", float(params["frustum_focus_distance"]))
	if params.has("exposure_aperture") and "exposure_aperture" in attrs:
		attrs.set("exposure_aperture", float(params["exposure_aperture"]))
	if params.has("exposure_shutter_speed") and "exposure_shutter_speed" in attrs:
		attrs.set("exposure_shutter_speed", float(params["exposure_shutter_speed"]))
	return save_resource_to_res(attrs, path, optional_bool(params, "overwrite", false))


func _apply_common(attrs: Resource, params: Dictionary) -> void:
	if params.has("exposure_multiplier") and "exposure_multiplier" in attrs:
		attrs.set("exposure_multiplier", float(params["exposure_multiplier"]))
	if params.has("exposure_sensitivity") and "exposure_sensitivity" in attrs:
		attrs.set("exposure_sensitivity", float(params["exposure_sensitivity"]))
	if params.has("auto_exposure_enabled") and "auto_exposure_enabled" in attrs:
		attrs.set("auto_exposure_enabled", bool(params["auto_exposure_enabled"]))
	if params.has("auto_exposure_scale") and "auto_exposure_scale" in attrs:
		attrs.set("auto_exposure_scale", float(params["auto_exposure_scale"]))
	if params.has("auto_exposure_speed") and "auto_exposure_speed" in attrs:
		attrs.set("auto_exposure_speed", float(params["auto_exposure_speed"]))
	if params.has("auto_exposure_min_sensitivity") and "auto_exposure_min_sensitivity" in attrs:
		attrs.set("auto_exposure_min_sensitivity", float(params["auto_exposure_min_sensitivity"]))
	if params.has("auto_exposure_max_sensitivity") and "auto_exposure_max_sensitivity" in attrs:
		attrs.set("auto_exposure_max_sensitivity", float(params["auto_exposure_max_sensitivity"]))


func _assign(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var attrs: Resource = null
	if params.has("attributes_path"):
		var p := str(params["attributes_path"])
		if not p.begins_with("res://"):
			p = "res://" + p.trim_prefix("/")
		if not ResourceLoader.exists(p):
			return error_not_found(p)
		attrs = load(p)
	elif optional_bool(params, "create_practical", true):
		attrs = ClassDB.instantiate("CameraAttributesPractical") if ClassDB.class_exists("CameraAttributesPractical") else null
	if attrs == null:
		return error_invalid_params("attributes_path or create_practical required")
	if node is Camera3D and "attributes" in node:
		(node as Camera3D).attributes = attrs
	elif node is WorldEnvironment and "camera_attributes" in node:
		node.set("camera_attributes", attrs)
	elif "attributes" in node:
		node.set("attributes", attrs)
	else:
		return error_invalid_params("Node has no attributes/camera_attributes property")
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"class": attrs.get_class(),
		"assigned": true,
	})


func _set_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var attrs: Resource = null
	if node is Camera3D:
		attrs = (node as Camera3D).attributes
	elif "attributes" in node:
		attrs = node.get("attributes")
	elif "camera_attributes" in node:
		attrs = node.get("camera_attributes")
	if attrs == null:
		return error_invalid_params("No CameraAttributes on node - assign first")
	_apply_common(attrs, params)
	for k in ["dof_blur_amount", "dof_blur_far_distance", "dof_blur_near_distance",
			"dof_blur_far_enabled", "dof_blur_near_enabled",
			"frustum_focal_length", "frustum_focus_distance",
			"exposure_aperture", "exposure_shutter_speed"]:
		if params.has(k) and k in attrs:
			attrs.set(k, params[k])
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "updated": true, "class": attrs.get_class()})


func _set_dof(params: Dictionary) -> Dictionary:
	var p := params.duplicate()
	if not p.has("dof_blur_amount"):
		p["dof_blur_amount"] = float(params.get("amount", 0.1))
	if params.has("far_distance"):
		p["dof_blur_far_enabled"] = true
		p["dof_blur_far_distance"] = float(params["far_distance"])
	if params.has("near_distance"):
		p["dof_blur_near_enabled"] = true
		p["dof_blur_near_distance"] = float(params["near_distance"])
	return _set_params(p)


func _set_exposure(params: Dictionary) -> Dictionary:
	var p := params.duplicate()
	if params.has("multiplier"):
		p["exposure_multiplier"] = float(params["multiplier"])
	if params.has("auto"):
		p["auto_exposure_enabled"] = bool(params["auto"])
	return _set_params(p)
