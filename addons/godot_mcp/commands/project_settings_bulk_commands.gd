@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Bulk project settings — list by prefix, batch set, export snapshot for agents.


func get_commands() -> Dictionary:
	return {
		"list_project_settings_by_prefix": _list_by_prefix,
		"batch_set_project_settings": _batch_set,
		"get_project_settings_snapshot": _snapshot,
		"list_project_settings_bulk_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["set_project_setting", "get_project_info", "scaffold_project_defaults", "set_window_project_settings"],
		"prefixes": [
			"application/", "display/", "rendering/", "physics/", "input/",
			"layer_names/", "audio/", "navigation/", "internationalization/",
		],
	})


func _list_by_prefix(params: Dictionary) -> Dictionary:
	var prefix: String = optional_string(params, "prefix", "")
	if prefix.is_empty():
		return error_invalid_params("prefix required e.g. display/ or rendering/")
	var limit: int = optional_int(params, "limit", 200)
	var settings: Array = []
	for prop in ProjectSettings.get_property_list():
		var n: String = str(prop.get("name", ""))
		if n.begins_with(prefix):
			settings.append({
				"name": n,
				"value": ProjectSettings.get_setting(n),
				"type": prop.get("type", 0),
			})
			if settings.size() >= limit:
				break
	return success({
		"prefix": prefix,
		"count": settings.size(),
		"settings": settings,
		"truncated": settings.size() >= limit,
	})


func _batch_set(params: Dictionary) -> Dictionary:
	## settings: { "display/window/size/viewport_width": 1280, ... }
	if not params.has("settings") or not (params["settings"] is Dictionary):
		return error_invalid_params("settings dictionary required")
	var applied := {}
	var skipped: Array = []
	for k in params["settings"]:
		var key := str(k)
		if key.is_empty() or key.contains(".."):
			skipped.append({"key": key, "reason": "invalid"})
			continue
		ProjectSettings.set_setting(key, params["settings"][k])
		applied[key] = params["settings"][k]
	if applied.is_empty():
		return error_invalid_params("No settings applied")
	if optional_bool(params, "save", true):
		ProjectSettings.save()
	return success({"applied": applied, "count": applied.size(), "skipped": skipped})


func _snapshot(params: Dictionary) -> Dictionary:
	var prefixes: Array = params.get("prefixes", [
		"application/config",
		"application/run",
		"display/window",
		"rendering/renderer",
		"physics/common",
		"audio/buses",
	])
	var out := {}
	for p in prefixes:
		var prefix := str(p)
		var bucket := {}
		for prop in ProjectSettings.get_property_list():
			var n: String = str(prop.get("name", ""))
			if n.begins_with(prefix):
				bucket[n] = ProjectSettings.get_setting(n)
		out[prefix] = bucket
	return success({"snapshot": out, "prefixes": prefixes})
