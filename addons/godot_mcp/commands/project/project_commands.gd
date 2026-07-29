@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_project_info": _get_project_info,
		"get_filesystem_tree": _get_filesystem_tree,
		"search_files": _search_files,
		"search_in_files": _search_in_files,
		"get_project_settings": _get_project_settings,
		"set_project_setting": _set_project_setting,
		"get_project_setting": _get_project_setting,
		"set_project_settings": _set_project_settings_bulk,
		"clear_project_setting": _clear_project_setting,
		"has_project_setting": _has_project_setting,
		"search_project_settings": _search_project_settings,
		"get_project_feature_list": _get_project_feature_list,
		"set_project_feature": _set_project_feature,
		"uid_to_project_path": _uid_to_project_path,
		"project_path_to_uid": _project_path_to_uid,
		"add_autoload": _add_autoload,
		"remove_autoload": _remove_autoload,
		"list_autoloads": _list_autoloads,
		"set_window_settings": _set_window_settings,
		"set_physics_ticks": _set_physics_ticks,
		"list_project_settings_keys": _list_project_settings_keys,
		"set_layer_names": _set_layer_names,
		"get_layer_names": _get_layer_names,
		# bulk / snapshot (merged from project_settings_bulk_commands)
		"list_project_settings_by_prefix": _list_project_settings_by_prefix,
		"batch_set_project_settings": _batch_set_project_settings_dict,
		"get_project_settings_snapshot": _get_project_settings_snapshot,
	}


func _get_project_info(params: Dictionary) -> Dictionary:
	var info := {}
	info["project_name"] = ProjectSettings.get_setting("application/config/name", "")
	info["godot_version"] = Engine.get_version_info()
	info["project_path"] = ProjectSettings.globalize_path("res://")
	info["main_scene"] = ProjectSettings.get_setting("application/run/main_scene", "")

	# Viewport settings
	info["viewport_width"] = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	info["viewport_height"] = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	info["window_width"] = ProjectSettings.get_setting("display/window/size/window_width_override", 0)
	info["window_height"] = ProjectSettings.get_setting("display/window/size/window_height_override", 0)

	# Rendering
	info["renderer"] = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")

	# Autoloads
	var autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("autoload/"):
			autoloads[name.substr(9)] = ProjectSettings.get_setting(name)
	info["autoloads"] = autoloads

	return success(info)


func _get_filesystem_tree(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var filter: String = optional_string(params, "filter", "")  # e.g. "*.gd", "*.tscn"
	var max_depth: int = optional_int(params, "max_depth", 10)

	var tree := _scan_directory(path, filter, max_depth, 0)
	return success({"tree": tree})


func _scan_directory(path: String, filter: String, max_depth: int, depth: int) -> Dictionary:
	var result := {"name": path.get_file(), "path": path, "type": "directory"}

	if depth >= max_depth:
		return result

	var dir := DirAccess.open(path)
	if dir == null:
		return result

	var children: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			children.append(_scan_directory(full_path, filter, max_depth, depth + 1))
		else:
			if filter.is_empty() or file_name.match(filter):
				children.append({
					"name": file_name,
					"path": full_path,
					"type": "file",
				})

		file_name = dir.get_next()

	dir.list_dir_end()

	if not children.is_empty():
		result["children"] = children

	return result


func _search_files(params: Dictionary) -> Dictionary:
	var result := require_string(params, "query")
	if result[1] != null:
		return result[1]
	var query: String = result[0]

	var path: String = optional_string(params, "path", "res://")
	var file_type: String = optional_string(params, "file_type", "")  # e.g. "gd", "tscn"
	var max_results: int = optional_int(params, "max_results", 50)

	var matches: Array = []
	_search_recursive(path, query, file_type, matches, max_results)

	return success({"matches": matches, "count": matches.size()})


func _search_recursive(path: String, query: String, file_type: String, matches: Array, max_results: int) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty() and matches.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			_search_recursive(full_path, query, file_type, matches, max_results)
		else:
			# Check file type filter
			if not file_type.is_empty() and file_name.get_extension() != file_type:
				file_name = dir.get_next()
				continue

			# Fuzzy match: check if query is contained in filename (case insensitive)
			if file_name.to_lower().contains(query.to_lower()):
				matches.append(full_path)
			# Also check glob pattern
			elif file_name.match(query):
				matches.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


func _get_project_settings(params: Dictionary) -> Dictionary:
	var section: String = optional_string(params, "section", "")
	var key: String = optional_string(params, "key", "")

	# If specific key requested
	if not key.is_empty():
		if ProjectSettings.has_setting(key):
			var value = ProjectSettings.get_setting(key)
			return success({"key": key, "value": str(value), "type": typeof(value)})
		else:
			return error_not_found("Setting '%s'" % key)

	# If section requested, return all settings in that section
	var settings := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if section.is_empty() or name.begins_with(section):
			settings[name] = str(ProjectSettings.get_setting(name))

	return success({"settings": settings, "count": settings.size()})


func _set_project_setting(params: Dictionary) -> Dictionary:
	var result := require_string(params, "key")
	if result[1] != null:
		return result[1]
	var key: String = result[0]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")

	var value = params["value"]

	# Type conversion for common patterns
	if value is String:
		var s: String = value
		# Try to parse typed values from string
		if s.begins_with("Vector2("):
			var expr := Expression.new()
			if expr.parse(s) == OK:
				var parsed = expr.execute()
				if parsed is Vector2:
					value = parsed
		elif s == "true":
			value = true
		elif s == "false":
			value = false
		elif s.is_valid_int():
			value = s.to_int()
		elif s.is_valid_float():
			value = s.to_float()

	ProjectSettings.set_setting(key, value)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"key": key,
		"value": str(ProjectSettings.get_setting(key)),
		"saved": true,
	})


func _uid_to_project_path(params: Dictionary) -> Dictionary:
	var result := require_string(params, "uid")
	if result[1] != null:
		return result[1]
	var uid_str: String = result[0]

	# Use ResourceUID to convert
	var uid := ResourceUID.text_to_id(uid_str)
	if uid == ResourceUID.INVALID_ID:
		return error_invalid_params("Invalid UID format: %s" % uid_str)

	if not ResourceUID.has_id(uid):
		return error_not_found("UID '%s'" % uid_str)

	var path := ResourceUID.get_id_path(uid)
	return success({"uid": uid_str, "path": path})


func _project_path_to_uid(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not ResourceLoader.exists(path):
		return error_not_found("Resource at '%s'" % path)

	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return error(-32001, "No UID assigned to '%s'" % path)

	var uid_str := ResourceUID.id_to_text(uid)
	return success({"path": path, "uid": uid_str})


const _TEXT_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres", "cfg", "godot", "gdshader", "md", "txt", "json"]

func _search_in_files(params: Dictionary) -> Dictionary:
	var result := require_string(params, "query")
	if result[1] != null:
		return result[1]
	var query: String = result[0]

	var path: String = optional_string(params, "path", "res://")
	var max_results: int = optional_int(params, "max_results", 50)
	var use_regex: bool = optional_bool(params, "regex", false)
	var file_type: String = optional_string(params, "file_type", "")

	var regex: RegEx = null
	if use_regex:
		regex = RegEx.new()
		var err := regex.compile(query)
		if err != OK:
			return error_invalid_params("Invalid regex pattern: %s" % error_string(err))

	var matches: Array = []
	_search_in_files_recursive(path, query, regex, file_type, matches, max_results)

	return success({"matches": matches, "count": matches.size(), "query": query})


func _search_in_files_recursive(path: String, query: String, regex: RegEx, file_type: String, matches: Array, max_results: int) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty() and matches.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			# Skip addons and .godot directories
			if file_name != "addons" and file_name != ".godot":
				_search_in_files_recursive(full_path, query, regex, file_type, matches, max_results)
		else:
			var ext := file_name.get_extension()
			# Filter by file type if specified, otherwise use text extensions
			if not file_type.is_empty():
				if ext != file_type:
					file_name = dir.get_next()
					continue
			elif ext not in _TEXT_EXTENSIONS:
				file_name = dir.get_next()
				continue

			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var lines := content.split("\n")
				for i in range(lines.size()):
					if matches.size() >= max_results:
						break
					var line: String = lines[i]
					var matched := false
					if regex != null:
						matched = regex.search(line) != null
					else:
						matched = line.contains(query)
					if matched:
						matches.append({
							"file": full_path,
							"line": i + 1,
							"text": line.strip_edges(),
						})

		file_name = dir.get_next()

	dir.list_dir_end()


func _add_autoload(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var autoload_name: String = result[0]

	var result2 := require_string(params, "path")
	if result2[1] != null:
		return result2[1]
	var autoload_path: String = result2[0]

	if not FileAccess.file_exists(autoload_path):
		return error_not_found("File '%s'" % autoload_path)

	# Check if already exists
	var setting_key := "autoload/" + autoload_name
	if ProjectSettings.has_setting(setting_key):
		return error(-32000, "Autoload '%s' already exists" % autoload_name, {
			"current_value": str(ProjectSettings.get_setting(setting_key)),
			"suggestion": "Use remove_autoload first to replace it",
		})

	# Autoload format: "*res://path.gd" (the * prefix means it's a singleton)
	ProjectSettings.set_setting(setting_key, "*" + autoload_path)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"name": autoload_name,
		"path": autoload_path,
		"added": true,
	})


func _remove_autoload(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var autoload_name: String = result[0]

	var setting_key := "autoload/" + autoload_name
	if not ProjectSettings.has_setting(setting_key):
		return error_not_found("Autoload '%s'" % autoload_name)

	var old_value: String = str(ProjectSettings.get_setting(setting_key))
	ProjectSettings.clear(setting_key)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"name": autoload_name,
		"old_path": old_value,
		"removed": true,
	})


func _list_autoloads(_params: Dictionary) -> Dictionary:
	var autoloads: Array = []
	for prop in ProjectSettings.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.begins_with("autoload/"):
			var raw := str(ProjectSettings.get_setting(pname))
			var singleton := raw.begins_with("*")
			var path := raw.trim_prefix("*")
			autoloads.append({
				"name": pname.trim_prefix("autoload/"),
				"path": path,
				"singleton": singleton,
				"raw": raw,
			})
	autoloads.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return success({"autoloads": autoloads, "count": autoloads.size()})


func _set_window_settings(params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("viewport_width"):
		ProjectSettings.set_setting("display/window/size/viewport_width", int(params["viewport_width"]))
		applied["viewport_width"] = int(params["viewport_width"])
	if params.has("viewport_height"):
		ProjectSettings.set_setting("display/window/size/viewport_height", int(params["viewport_height"]))
		applied["viewport_height"] = int(params["viewport_height"])
	if params.has("mode"):
		# 0=windowed 1=minimized 2=maximized 3=fullscreen 4=exclusive fullscreen (varies)
		var mode = params["mode"]
		if mode is String:
			match str(mode).to_lower():
				"windowed":
					ProjectSettings.set_setting("display/window/size/mode", 0)
				"fullscreen":
					ProjectSettings.set_setting("display/window/size/mode", 3)
				"exclusive_fullscreen":
					ProjectSettings.set_setting("display/window/size/mode", 4)
				_:
					ProjectSettings.set_setting("display/window/size/mode", int(mode) if str(mode).is_valid_int() else 0)
		else:
			ProjectSettings.set_setting("display/window/size/mode", int(mode))
		applied["mode"] = ProjectSettings.get_setting("display/window/size/mode")
	if params.has("stretch_mode"):
		ProjectSettings.set_setting("display/window/stretch/mode", str(params["stretch_mode"]))
		applied["stretch_mode"] = str(params["stretch_mode"])
	if params.has("stretch_aspect"):
		ProjectSettings.set_setting("display/window/stretch/aspect", str(params["stretch_aspect"]))
		applied["stretch_aspect"] = str(params["stretch_aspect"])
	if params.has("vsync"):
		# 0=disabled 1=enabled 2=adaptive 3=mailbox
		ProjectSettings.set_setting("display/window/vsync/vsync_mode", int(params["vsync"]))
		applied["vsync"] = int(params["vsync"])
	if applied.is_empty():
		return error_invalid_params("Provide viewport_width/height, mode, stretch_mode/aspect, and/or vsync")
	ProjectSettings.save()
	return success({"applied": applied})


func _set_physics_ticks(params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("ticks_per_second"):
		ProjectSettings.set_setting("physics/common/physics_ticks_per_second", int(params["ticks_per_second"]))
		applied["physics_ticks_per_second"] = int(params["ticks_per_second"])
	if params.has("max_physics_steps_per_frame"):
		ProjectSettings.set_setting("physics/common/max_physics_steps_per_frame", int(params["max_physics_steps_per_frame"]))
		applied["max_physics_steps_per_frame"] = int(params["max_physics_steps_per_frame"])
	if params.has("physics_jitter_fix"):
		ProjectSettings.set_setting("physics/common/physics_jitter_fix", float(params["physics_jitter_fix"]))
		applied["physics_jitter_fix"] = float(params["physics_jitter_fix"])
	if applied.is_empty():
		return error_invalid_params("Provide ticks_per_second and/or related physics common settings")
	ProjectSettings.save()
	return success({"applied": applied})


func _list_project_settings_keys(params: Dictionary) -> Dictionary:
	var filter: String = optional_string(params, "filter", "").to_lower()
	var max_n: int = optional_int(params, "max_results", 200)
	var keys: Array = []
	for prop in ProjectSettings.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.is_empty():
			continue
		if not filter.is_empty() and not pname.to_lower().contains(filter):
			continue
		keys.append(pname)
		if keys.size() >= max_n:
			break
	keys.sort()
	return success({"keys": keys, "count": keys.size(), "filter": filter, "capped": keys.size() >= max_n})


func _get_project_setting(params: Dictionary) -> Dictionary:
	var r := require_string(params, "key")
	if r[1] != null:
		return r[1]
	var key: String = r[0]
	if not ProjectSettings.has_setting(key):
		return error_not_found("Setting '%s'" % key, "Use search_project_settings or list_project_settings_keys")
	var value = ProjectSettings.get_setting(key)
	return success({
		"key": key,
		"value": _serialize_setting(value),
		"raw_type": typeof(value),
		"type_name": type_string(typeof(value)),
	})


func _serialize_setting(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_COLOR:
			const PP := preload("res://addons/godot_mcp/utils/property_parser.gd")
			return PP.serialize_value(value)
		TYPE_PACKED_STRING_ARRAY:
			var a: Array = []
			for x in value:
				a.append(str(x))
			return a
		TYPE_DICTIONARY, TYPE_ARRAY:
			return value
		_:
			return value


func _set_project_settings_bulk(params: Dictionary) -> Dictionary:
	if not params.has("settings") or not params["settings"] is Dictionary:
		return error_invalid_params("settings Dictionary required {key: value, ...}")
	var settings: Dictionary = params["settings"]
	var applied: Array = []
	var errors: Array = []
	for key in settings:
		var one := _set_project_setting({"key": str(key), "value": settings[key]})
		if one.has("error"):
			errors.append({"key": key, "error": one["error"]})
		else:
			applied.append(str(key))
	return success({"applied": applied, "count": applied.size(), "errors": errors})


func _clear_project_setting(params: Dictionary) -> Dictionary:
	var r := require_string(params, "key")
	if r[1] != null:
		return r[1]
	var key: String = r[0]
	if not ProjectSettings.has_setting(key):
		return error_not_found(key)
	ProjectSettings.set_setting(key, null)
	# Some versions use clear
	if ProjectSettings.has_method("clear"):
		ProjectSettings.clear(key)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal(error_string(err))
	return success({"key": key, "cleared": true})


func _has_project_setting(params: Dictionary) -> Dictionary:
	var r := require_string(params, "key")
	if r[1] != null:
		return r[1]
	return success({"key": r[0], "exists": ProjectSettings.has_setting(r[0])})


func _search_project_settings(params: Dictionary) -> Dictionary:
	## Search keys and stringified values (Project Settings dialog search).
	var query: String = optional_string(params, "query", optional_string(params, "filter", "")).to_lower()
	if query.is_empty():
		return error_invalid_params("query required")
	var max_n: int = clampi(optional_int(params, "max", 100), 1, 500)
	var include_values: bool = optional_bool(params, "include_values", true)
	var hits: Array = []
	for prop in ProjectSettings.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.is_empty():
			continue
		var match_key := pname.to_lower().contains(query)
		var match_val := false
		var val_s := ""
		if include_values and ProjectSettings.has_setting(pname):
			val_s = str(ProjectSettings.get_setting(pname))
			match_val = val_s.to_lower().contains(query)
		if match_key or match_val:
			var entry := {"key": pname, "match": "key" if match_key else "value"}
			if include_values:
				entry["value"] = val_s.left(200)
			hits.append(entry)
			if hits.size() >= max_n:
				break
	return success({"query": query, "hits": hits, "count": hits.size()})


func _get_project_feature_list(_params: Dictionary) -> Dictionary:
	var features: Array = []
	if ProjectSettings.has_setting("application/config/features"):
		var f = ProjectSettings.get_setting("application/config/features")
		if f is PackedStringArray:
			for x in f:
				features.append(str(x))
		elif f is Array:
			for x in f:
				features.append(str(x))
	return success({
		"features": features,
		"count": features.size(),
		"hint": "Feature tags drive export filters and platform code paths",
	})


func _set_project_feature(params: Dictionary) -> Dictionary:
	var r := require_string(params, "feature")
	if r[1] != null:
		return r[1]
	var feature: String = r[0]
	var remove: bool = optional_bool(params, "remove", false)
	var features: PackedStringArray = PackedStringArray()
	if ProjectSettings.has_setting("application/config/features"):
		var f = ProjectSettings.get_setting("application/config/features")
		if f is PackedStringArray:
			features = f
		elif f is Array:
			for x in f:
				features.append(str(x))
	var arr: Array = []
	for x in features:
		arr.append(str(x))
	if remove:
		arr.erase(feature)
	elif not (feature in arr):
		arr.append(feature)
	var out := PackedStringArray()
	for x in arr:
		out.append(str(x))
	ProjectSettings.set_setting("application/config/features", out)
	ProjectSettings.save()
	return success({"features": arr, "removed": remove, "feature": feature})


func _layer_setting_prefix(kind: String) -> String:
	match kind:
		"2d_physics", "physics_2d":
			return "layer_names/2d_physics/layer_"
		"3d_physics", "physics_3d":
			return "layer_names/3d_physics/layer_"
		"2d_render", "render_2d":
			return "layer_names/2d_render/layer_"
		"3d_render", "render_3d":
			return "layer_names/3d_render/layer_"
		"2d_navigation", "navigation_2d":
			return "layer_names/2d_navigation/layer_"
		"3d_navigation", "navigation_3d":
			return "layer_names/3d_navigation/layer_"
		_:
			return ""


func _get_layer_names(params: Dictionary) -> Dictionary:
	var kind: String = optional_string(params, "kind", "2d_physics")
	var prefix := _layer_setting_prefix(kind)
	if prefix.is_empty():
		return error_invalid_params("kind: 2d_physics|3d_physics|2d_render|3d_render|2d_navigation|3d_navigation")
	var layers: Array = []
	for i in range(1, 33):
		var key := prefix + str(i)
		var name := ""
		if ProjectSettings.has_setting(key):
			name = str(ProjectSettings.get_setting(key))
		layers.append({"layer": i, "name": name, "setting": key})
	return success({"kind": kind, "layers": layers})


func _set_layer_names(params: Dictionary) -> Dictionary:
	## Set named collision/render/navigation layers. names: { "1": "player", "2": "world" } or array.
	var kind: String = optional_string(params, "kind", "2d_physics")
	var prefix := _layer_setting_prefix(kind)
	if prefix.is_empty():
		return error_invalid_params("kind required: 2d_physics|3d_physics|2d_render|3d_render|2d_navigation|3d_navigation")
	if not params.has("names"):
		return error_invalid_params("names dict or array required")
	var applied: Array = []
	var names = params["names"]
	if names is Dictionary:
		for k in names:
			var layer_i := int(k)
			if layer_i < 1 or layer_i > 32:
				continue
			var key := prefix + str(layer_i)
			ProjectSettings.set_setting(key, str(names[k]))
			applied.append({"layer": layer_i, "name": str(names[k])})
	elif names is Array:
		for i in names.size():
			var layer_i2 := i + 1
			if layer_i2 > 32:
				break
			var key2 := prefix + str(layer_i2)
			ProjectSettings.set_setting(key2, str(names[i]))
			applied.append({"layer": layer_i2, "name": str(names[i])})
	else:
		return error_invalid_params("names must be Dictionary or Array")
	ProjectSettings.save()
	return success({"kind": kind, "applied": applied, "count": applied.size()})
