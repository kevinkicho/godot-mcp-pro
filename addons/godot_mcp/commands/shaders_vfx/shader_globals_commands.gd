@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Global shader parameters - project-wide shader uniforms (weather, time of day, outlines).


func get_commands() -> Dictionary:
	return {
		"list_shader_global_parameters": _list,
		"set_shader_global_parameter": _set,
		"add_shader_global_parameter": _add,
		"remove_shader_global_parameter": _remove,
		"set_shader_globals_batch": _batch,
		"list_shader_globals_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"create_shader", "assign_shader_material", "create_shader_include_library_preset",
		"apply_environment_preset",
	], {
		"hint": "RenderingServer.global_shader_parameter_* - shared by all shaders using global uniform",
	})


func _list(_params: Dictionary) -> Dictionary:
	var names: Array = []
	# Godot 4: ProjectSettings shader globals live under shader_globals/
	for k in ProjectSettings.get_property_list():
		var n := str(k.get("name", ""))
		if n.begins_with("shader_globals/"):
			var id := n.trim_prefix("shader_globals/")
			var val = ProjectSettings.get_setting(n)
			names.append({"name": id, "setting": n, "value": str(val)})
	# Also try RenderingServer list if available
	if RenderingServer.has_method("global_shader_parameter_get_list"):
		var rs_list = RenderingServer.call("global_shader_parameter_get_list")
		return success({
			"project_settings": names,
			"rendering_server": rs_list,
			"count": names.size(),
		})
	return success({"parameters": names, "count": names.size()})


func _set(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "name")
	if r0[1] != null:
		return r0[1]
	if not params.has("value"):
		return error_invalid_params("value required")
	var name_s: String = r0[0]
	var value: Variant = params["value"]
	# Coerce common types
	if value is Dictionary:
		var d: Dictionary = value
		if d.has("r") and d.has("g") and d.has("b"):
			value = Color(float(d.get("r", 1)), float(d.get("g", 1)), float(d.get("b", 1)), float(d.get("a", 1)))
		elif d.has("x") and d.has("y") and d.has("z") and d.has("w"):
			value = Vector4(float(d["x"]), float(d["y"]), float(d["z"]), float(d["w"]))
		elif d.has("x") and d.has("y") and d.has("z"):
			value = Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
		elif d.has("x") and d.has("y"):
			value = Vector2(float(d["x"]), float(d["y"]))
	if RenderingServer.has_method("global_shader_parameter_set"):
		RenderingServer.global_shader_parameter_set(StringName(name_s), value)
	# Persist when possible via ProjectSettings
	var key := "shader_globals/%s" % name_s
	if ProjectSettings.has_setting(key) or optional_bool(params, "persist", true):
		# Godot stores type+value; best-effort dict form
		if value is float or value is int:
			ProjectSettings.set_setting(key, {"type": "float", "value": float(value)})
		elif value is bool:
			ProjectSettings.set_setting(key, {"type": "bool", "value": value})
		elif value is Color:
			ProjectSettings.set_setting(key, {"type": "color", "value": value})
		elif value is Vector2:
			ProjectSettings.set_setting(key, {"type": "vec2", "value": value})
		elif value is Vector3:
			ProjectSettings.set_setting(key, {"type": "vec3", "value": value})
		else:
			ProjectSettings.set_setting(key, value)
		if optional_bool(params, "save", true):
			ProjectSettings.save()
	return success({"name": name_s, "value": str(value), "set": true})


func _add(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "name")
	if r0[1] != null:
		return r0[1]
	var type_s: String = optional_string(params, "type", "float")
	var value: Variant = params.get("value", 0.0)
	var name_s: String = r0[0]
	if RenderingServer.has_method("global_shader_parameter_add"):
		var type_enum := 0
		match type_s.to_lower():
			"bool":
				type_enum = 1
			"int":
				type_enum = 2
			"float":
				type_enum = 3
			"vec2", "vector2":
				type_enum = 4
			"vec3", "vector3":
				type_enum = 5
			"vec4", "color":
				type_enum = 6
			"sampler2d", "texture":
				type_enum = 7
		RenderingServer.global_shader_parameter_add(StringName(name_s), type_enum, value)
	return _set({"name": name_s, "value": value, "persist": true, "save": optional_bool(params, "save", true)})


func _remove(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "name")
	if r0[1] != null:
		return r0[1]
	var name_s: String = r0[0]
	if RenderingServer.has_method("global_shader_parameter_remove"):
		RenderingServer.global_shader_parameter_remove(StringName(name_s))
	var key := "shader_globals/%s" % name_s
	if ProjectSettings.has_setting(key):
		ProjectSettings.clear(key)
		ProjectSettings.save()
	return success({"name": name_s, "removed": true})


func _batch(params: Dictionary) -> Dictionary:
	## values: {name: value}
	if not params.has("values") or not params["values"] is Dictionary:
		return error_invalid_params("values{} required")
	var results: Array = []
	for k in params["values"]:
		results.append(_set({"name": str(k), "value": params["values"][k], "save": false}))
	if optional_bool(params, "save", true):
		ProjectSettings.save()
	return success({"results": results, "count": results.size()})
