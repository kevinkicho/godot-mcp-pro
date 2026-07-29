@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Omni / Spot / Directional light depth - production lighting agents need often.


func get_commands() -> Dictionary:
	return {
		"setup_omni_light_3d": _setup_omni,
		"setup_spot_light_3d": _setup_spot,
		"setup_directional_light_3d": _setup_dir,
		"set_light_3d_params": _set_params,
		"batch_set_light_3d_params": _batch,
		"list_light_3d_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_lighting", "setup_world_environment", "configure_sdfgi",
		"setup_decal_3d", "apply_environment_preset",
	])


func _parse_color(v: Variant, default: Color = Color.WHITE) -> Color:
	if v is String:
		return Color.html(v) if str(v).begins_with("#") else Color(str(v))
	if v is Dictionary:
		return Color(float(v.get("r", 1)), float(v.get("g", 1)), float(v.get("b", 1)), float(v.get("a", 1)))
	return default


func _apply_light_common(light: Light3D, params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("color"):
		light.light_color = _parse_color(params["color"])
		applied["color"] = light.light_color.to_html(true)
	if params.has("energy"):
		light.light_energy = float(params["energy"])
		applied["energy"] = light.light_energy
	if params.has("indirect_energy"):
		light.light_indirect_energy = float(params["indirect_energy"])
		applied["indirect_energy"] = light.light_indirect_energy
	if params.has("specular"):
		light.light_specular = float(params["specular"])
		applied["specular"] = light.light_specular
	if params.has("size"):
		light.light_size = float(params["size"])
		applied["size"] = light.light_size
	if params.has("shadow"):
		light.shadow_enabled = bool(params["shadow"])
		applied["shadow"] = light.shadow_enabled
	if params.has("shadow_opacity") and "shadow_opacity" in light:
		light.shadow_opacity = float(params["shadow_opacity"])
	if params.has("shadow_blur"):
		light.shadow_blur = float(params["shadow_blur"])
	if params.has("layers"):
		light.light_cull_mask = int(params["layers"])
		applied["layers"] = light.light_cull_mask
	if params.has("negative"):
		light.light_negative = bool(params["negative"])
	if params.has("temperature") and "light_temperature" in light:
		light.set("light_temperature", float(params["temperature"]))
	return applied


func _setup_omni(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var light := OmniLight3D.new()
	light.name = optional_string(params, "name", "OmniLight3D")
	light.omni_range = float(params.get("range", 10.0))
	light.omni_attenuation = float(params.get("attenuation", 1.0))
	if params.has("shadow_mode"):
		# 0 dual paraboloid, 1 cube
		pass
	var applied := _apply_light_common(light, params)
	if not params.has("energy"):
		light.light_energy = 1.0
	if not params.has("shadow"):
		light.shadow_enabled = optional_bool(params, "shadow", true)
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		light.position = Vector3(float(p.get("x", 0)), float(p.get("y", 3)), float(p.get("z", 0)))
	add_child_with_undo(parent, light, root, "MCP: OmniLight3D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(light)),
		"type": "OmniLight3D",
		"range": light.omni_range,
		"applied": applied,
	})


func _setup_spot(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var light := SpotLight3D.new()
	light.name = optional_string(params, "name", "SpotLight3D")
	light.spot_range = float(params.get("range", 12.0))
	light.spot_angle = float(params.get("angle", 45.0))
	light.spot_attenuation = float(params.get("attenuation", 1.0))
	light.spot_angle_attenuation = float(params.get("angle_attenuation", 1.0))
	var applied := _apply_light_common(light, params)
	if not params.has("shadow"):
		light.shadow_enabled = optional_bool(params, "shadow", true)
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		light.position = Vector3(float(p.get("x", 0)), float(p.get("y", 4)), float(p.get("z", 2)))
	if params.has("rotation_degrees") and params["rotation_degrees"] is Dictionary:
		var r: Dictionary = params["rotation_degrees"]
		light.rotation_degrees = Vector3(float(r.get("x", -45)), float(r.get("y", 0)), float(r.get("z", 0)))
	add_child_with_undo(parent, light, root, "MCP: SpotLight3D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(light)),
		"type": "SpotLight3D",
		"range": light.spot_range,
		"angle": light.spot_angle,
		"applied": applied,
	})


func _setup_dir(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var light := DirectionalLight3D.new()
	light.name = optional_string(params, "name", "DirectionalLight3D")
	var applied := _apply_light_common(light, params)
	if not params.has("shadow"):
		light.shadow_enabled = optional_bool(params, "shadow", true)
	if params.has("rotation_degrees") and params["rotation_degrees"] is Dictionary:
		var r: Dictionary = params["rotation_degrees"]
		light.rotation_degrees = Vector3(float(r.get("x", -50)), float(r.get("y", 30)), float(r.get("z", 0)))
	else:
		light.rotation_degrees = Vector3(-50, 30, 0)
	if params.has("sky_mode") and "sky_mode" in light:
		light.set("sky_mode", int(params["sky_mode"]))
	add_child_with_undo(parent, light, root, "MCP: DirectionalLight3D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(light)),
		"type": "DirectionalLight3D",
		"applied": applied,
	})


func _set_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Light3D):
		return error_not_found("Light3D")
	var light := n as Light3D
	var applied := _apply_light_common(light, params)
	if light is OmniLight3D:
		var o := light as OmniLight3D
		if params.has("range"):
			o.omni_range = float(params["range"])
			applied["range"] = o.omni_range
		if params.has("attenuation"):
			o.omni_attenuation = float(params["attenuation"])
	elif light is SpotLight3D:
		var s := light as SpotLight3D
		if params.has("range"):
			s.spot_range = float(params["range"])
			applied["range"] = s.spot_range
		if params.has("angle"):
			s.spot_angle = float(params["angle"])
			applied["angle"] = s.spot_angle
	if applied.is_empty():
		return error_invalid_params("No light params applied")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied, "class": light.get_class()})


func _batch(params: Dictionary) -> Dictionary:
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("items array required")
	var results: Array = []
	for item in params["items"]:
		if item is Dictionary:
			results.append(_set_params(item))
	return success({"results": results, "count": results.size()})
