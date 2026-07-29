@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Autoload registry management (project.godot) for agents.


func get_commands() -> Dictionary:
	return {
		# list_autoloads / remove_autoload canonical in project_commands
		"set_autoload": _set_autoload,
		"rename_autoload": _rename_autoload,
		"list_autoload_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["add_autoload", "ensure_autoload", "check_autoload_hygiene"],
	})


func _list_autoloads(_params: Dictionary) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load("res://project.godot") != OK:
		return error_internal("Cannot load project.godot")
	var out: Array = []
	if cfg.has_section("autoload"):
		for key in cfg.get_section_keys("autoload"):
			var val := str(cfg.get_value("autoload", key, ""))
			out.append({
				"name": key,
				"path": val.trim_prefix("*"),
				"singleton": val.begins_with("*"),
				"raw": val,
			})
	return success({"autoloads": out, "count": out.size()})


func _set_autoload(params: Dictionary) -> Dictionary:
	var name_r := require_string(params, "name")
	if name_r[1] != null:
		return name_r[1]
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var singleton: bool = optional_bool(params, "singleton", true)
	var key := "autoload/" + name_r[0]
	var value := ("*" if singleton else "") + path_r[0]
	ProjectSettings.set_setting(key, value)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal(error_string(err))
	return success({"name": name_r[0], "path": path_r[0], "singleton": singleton})


func _remove_autoload(params: Dictionary) -> Dictionary:
	var name_r := require_string(params, "name")
	if name_r[1] != null:
		return name_r[1]
	var key := "autoload/" + name_r[0]
	if not ProjectSettings.has_setting(key):
		return error_not_found("autoload %s" % name_r[0])
	ProjectSettings.clear(key)
	# Also edit project.godot section if clear insufficient
	var cfg := ConfigFile.new()
	if cfg.load("res://project.godot") == OK and cfg.has_section_key("autoload", name_r[0]):
		cfg.erase_section_key("autoload", name_r[0])
		cfg.save("res://project.godot")
	ProjectSettings.save()
	return success({"removed": name_r[0]})


func _rename_autoload(params: Dictionary) -> Dictionary:
	var from_r := require_string(params, "from")
	if from_r[1] != null:
		return from_r[1]
	var to_r := require_string(params, "to")
	if to_r[1] != null:
		return to_r[1]
	var from_key := "autoload/" + from_r[0]
	if not ProjectSettings.has_setting(from_key):
		return error_not_found("autoload %s" % from_r[0])
	var val = ProjectSettings.get_setting(from_key)
	ProjectSettings.set_setting("autoload/" + to_r[0], val)
	ProjectSettings.clear(from_key)
	var cfg := ConfigFile.new()
	if cfg.load("res://project.godot") == OK:
		if cfg.has_section_key("autoload", from_r[0]):
			var v = cfg.get_value("autoload", from_r[0])
			cfg.set_value("autoload", to_r[0], v)
			cfg.erase_section_key("autoload", from_r[0])
			cfg.save("res://project.godot")
	ProjectSettings.save()
	return success({"from": from_r[0], "to": to_r[0], "value": val})
