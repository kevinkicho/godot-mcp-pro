@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## IO / save helpers — ConfigFile, JSON, user:// browsing (tutorials/io).


func get_commands() -> Dictionary:
	return {
		"config_file_get": _config_file_get,
		"config_file_set": _config_file_set,
		"json_read": _json_read,
		"json_write": _json_write,
		"user_list_dir": _user_list_dir,
		"user_read_text": _user_read_text,
		"user_write_text": _user_write_text,
		"user_delete_path": _user_delete_path,
	}


func _normalize_user_path(path: String) -> String:
	if path.is_empty():
		return "user://"
	if path.begins_with("user://"):
		return path
	if path.begins_with("res://"):
		return path  # allow explicit res if needed
	return "user://" + path.trim_prefix("/")


func _config_file_get(params: Dictionary) -> Dictionary:
	var path: String = _normalize_user_path(optional_string(params, "path", "user://settings.cfg"))
	if not FileAccess.file_exists(path):
		return success({"path": path, "exists": false, "sections": {}})
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return error_internal("Failed to load %s: %s" % [path, error_string(err)])
	var section: String = optional_string(params, "section", "")
	var key: String = optional_string(params, "key", "")
	if not section.is_empty() and not key.is_empty():
		if not cfg.has_section_key(section, key):
			return success({"path": path, "section": section, "key": key, "found": false})
		return success({
			"path": path, "section": section, "key": key,
			"found": true, "value": cfg.get_value(section, key),
		})
	var out := {}
	for s in cfg.get_sections():
		var keys := {}
		for k in cfg.get_section_keys(s):
			keys[k] = cfg.get_value(s, k)
		out[s] = keys
	return success({"path": path, "exists": true, "sections": out})


func _config_file_set(params: Dictionary) -> Dictionary:
	var path: String = _normalize_user_path(optional_string(params, "path", "user://settings.cfg"))
	var section_r := require_string(params, "section")
	if section_r[1] != null:
		return section_r[1]
	var key_r := require_string(params, "key")
	if key_r[1] != null:
		return key_r[1]
	if not params.has("value"):
		return error_invalid_params("value required")
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path):
		cfg.load(path)
	var old = cfg.get_value(section_r[0], key_r[0]) if cfg.has_section_key(section_r[0], key_r[0]) else null
	cfg.set_value(section_r[0], key_r[0], params["value"])
	var err := cfg.save(path)
	if err != OK:
		return error_internal("Failed to save %s: %s" % [path, error_string(err)])
	return success({
		"path": path, "section": section_r[0], "key": key_r[0],
		"old_value": old, "new_value": params["value"],
	})


func _json_read(params: Dictionary) -> Dictionary:
	var path: String = _normalize_user_path(optional_string(params, "path", ""))
	if path.is_empty():
		var res := require_res_path(params, "path")
		if res[1] != null:
			return res[1]
		path = res[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot open %s" % path)
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if data == null and not text.strip_edges().is_empty():
		return error_invalid_params("Invalid JSON in %s" % path)
	return success({"path": path, "data": data})


func _json_write(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "")
	if path.is_empty():
		return error_invalid_params("path required (user:// or res://)")
	if not path.begins_with("user://") and not path.begins_with("res://"):
		path = "user://" + path.trim_prefix("/")
	if not params.has("data"):
		return error_invalid_params("data required")
	var pretty: bool = optional_bool(params, "pretty", true)
	var text: String
	if pretty:
		text = JSON.stringify(params["data"], "\t")
	else:
		text = JSON.stringify(params["data"])
	# Ensure parent dir for user://
	var abs := ProjectSettings.globalize_path(path)
	var dir_path := abs.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(text)
	f.close()
	if path.begins_with("res://"):
		EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "bytes": text.length()})


func _user_list_dir(params: Dictionary) -> Dictionary:
	var path: String = _normalize_user_path(optional_string(params, "path", "user://"))
	var dir := DirAccess.open(path)
	if dir == null:
		return error_not_found(path)
	var files: Array = []
	var dirs: Array = []
	dir.list_dir_begin()
	var n := dir.get_next()
	while not n.is_empty():
		if n.begins_with("."):
			n = dir.get_next()
			continue
		if dir.current_is_dir():
			dirs.append(n)
		else:
			files.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	return success({"path": path, "directories": dirs, "files": files})


func _user_read_text(params: Dictionary) -> Dictionary:
	var path: String = _normalize_user_path(optional_string(params, "path", ""))
	if path.is_empty() or path == "user://":
		return error_invalid_params("path required under user://")
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot open %s" % path)
	var text := f.get_as_text()
	f.close()
	return success({"path": path, "content": text, "length": text.length()})


func _user_write_text(params: Dictionary) -> Dictionary:
	var path: String = _normalize_user_path(optional_string(params, "path", ""))
	if path.is_empty() or path == "user://":
		return error_invalid_params("path required under user://")
	if not params.has("content"):
		return error_invalid_params("content required")
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(str(params["content"]))
	f.close()
	return success({"path": path, "written": true})


func _user_delete_path(params: Dictionary) -> Dictionary:
	var path: String = _normalize_user_path(optional_string(params, "path", ""))
	if path.is_empty() or path == "user://":
		return error_invalid_params("Refuse to delete user:// root; give a specific path")
	if path.begins_with("res://"):
		return error_invalid_params("Use res_delete_path for res://")
	var abs := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs):
		var err := DirAccess.remove_absolute(abs)
		if err != OK:
			return error_internal("Failed to remove dir %s" % path)
		return success({"path": path, "deleted": "directory"})
	if FileAccess.file_exists(path):
		var err2 := DirAccess.remove_absolute(abs)
		if err2 != OK:
			return error_internal("Failed to remove file %s" % path)
		return success({"path": path, "deleted": "file"})
	return error_not_found(path)
