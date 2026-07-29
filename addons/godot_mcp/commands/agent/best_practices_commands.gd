@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Executable project hygiene checks (tutorials/best_practices) for agents.


func get_commands() -> Dictionary:
	return {
		"analyze_project_best_practices": _analyze_project_best_practices,
		"check_node_naming": _check_node_naming,
		"check_autoload_hygiene": _check_autoload_hygiene,
		"check_res_path_conventions": _check_res_path_conventions,
		"list_best_practices_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["analyze_scene_complexity", "audit_scene_tree", "health_check", "validate_all_scenes"],
	})


func _analyze_project_best_practices(params: Dictionary) -> Dictionary:
	var issues: Array = []
	var ok_items: Array = []
	# Main scene
	var main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main.is_empty():
		issues.append({"severity": "warning", "id": "no_main_scene", "message": "No main scene set", "fix": "set_main_scene"})
	else:
		ok_items.append("main_scene")
	# Autoloads
	var auto := _check_autoload_hygiene({})
	var auto_r = auto.get("result", auto)
	if auto_r is Dictionary:
		for i in auto_r.get("issues", []):
			issues.append(i)
		if auto_r.get("ok", false):
			ok_items.append("autoloads")
	# Open scene naming
	if get_edited_root():
		var naming := _check_node_naming({"node_path": "."})
		var nr = naming.get("result", naming)
		if nr is Dictionary:
			for i in nr.get("issues", []):
				issues.append(i)
	# Physics layers named?
	var named_layers := 0
	for i in range(1, 9):
		var k := "layer_names/3d_physics/layer_%d" % i
		if ProjectSettings.has_setting(k) and str(ProjectSettings.get_setting(k)).length() > 0:
			named_layers += 1
	if named_layers == 0:
		issues.append({
			"severity": "info",
			"id": "unnamed_physics_layers",
			"message": "Physics layers 1-8 have no names — hard for agents/humans",
			"fix": "scaffold_project_defaults or set_project_setting layer_names/…",
		})
	else:
		ok_items.append("physics_layer_names")
	# Input map
	var actions := InputMap.get_actions()
	if actions.size() < 3:
		issues.append({"severity": "info", "id": "sparse_input_map", "message": "Few input actions", "fix": "create_input_map_preset"})
	else:
		ok_items.append("input_map")
	# Export presets
	if not FileAccess.file_exists("res://export_presets.cfg"):
		issues.append({"severity": "info", "id": "no_export_presets", "message": "No export_presets.cfg yet", "fix": "create_export_preset"})
	else:
		ok_items.append("export_presets")

	var errors := 0
	var warnings := 0
	for i in issues:
		if str(i.get("severity", "")) == "error":
			errors += 1
		elif str(i.get("severity", "")) == "warning":
			warnings += 1
	return success({
		"ok": errors == 0,
		"issues": issues,
		"passed": ok_items,
		"error_count": errors,
		"warning_count": warnings,
		"score_hint": "Fix warnings before ship; info is optional polish",
	})


func _check_node_naming(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start := find_node_by_path(optional_string(params, "node_path", "."))
	if start == null:
		start = root
	var issues: Array = []
	var checked := 0
	_walk_names(start, root, issues, checked)
	return success({"issues": issues, "nodes_checked": checked, "ok": issues.is_empty()})


func _walk_names(n: Node, root: Node, issues: Array, checked: int) -> void:
	checked += 1
	var nm: String = n.name
	if nm.is_empty():
		issues.append({"severity": "warning", "path": str(root.get_path_to(n)), "message": "Empty name"})
	elif nm.contains("@"):
		issues.append({"severity": "info", "path": str(root.get_path_to(n)), "message": "Engine auto-name %s — rename for stable paths" % nm})
	elif nm.begins_with("Node") and nm.length() <= 6:
		issues.append({"severity": "info", "path": str(root.get_path_to(n)), "message": "Generic name %s" % nm})
	# duplicate sibling names are illegal in Godot so skip
	for c in n.get_children():
		_walk_names(c, root, issues, checked)


func _check_autoload_hygiene(_params: Dictionary) -> Dictionary:
	var issues: Array = []
	var autos: Array = []
	var list = ProjectSettings.get_property_list()
	# ProjectSettings autoload/* 
	var ps_keys: Array = []
	# Iterate known pattern
	for i in range(0, 64):
		pass
	# Use ProjectSettings.get_setting with ConfigFile project.godot
	var cfg := ConfigFile.new()
	if cfg.load("res://project.godot") == OK:
		if cfg.has_section("autoload"):
			for key in cfg.get_section_keys("autoload"):
				var val := str(cfg.get_value("autoload", key, ""))
				var path := val.trim_prefix("*")
				autos.append({"name": key, "path": path, "singleton": val.begins_with("*")})
				if not path.begins_with("res://"):
					issues.append({"severity": "warning", "id": "autoload_path", "message": "%s path not res://" % key})
				elif not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
					issues.append({"severity": "error", "id": "autoload_missing", "message": "Autoload %s missing file %s" % [key, path]})
				if key == key.to_lower() and key.length() > 0:
					issues.append({"severity": "info", "id": "autoload_case", "message": "Autoload '%s' is lowercase — PascalCase common for singletons" % key})
	var has_err := false
	for i in issues:
		if str(i.get("severity", "")) == "error":
			has_err = true
			break
	return success({"autoloads": autos, "issues": issues, "ok": not has_err})


func _check_res_path_conventions(params: Dictionary) -> Dictionary:
	var issues: Array = []
	var root_path: String = optional_string(params, "path", "res://")
	var max_n: int = clampi(optional_int(params, "max", 200), 1, 1000)
	var files: Array = []
	_collect(root_path, files, max_n)
	for f in files:
		var p: String = str(f)
		if p.contains(" "):
			issues.append({"severity": "warning", "path": p, "message": "Space in path — prefer snake_case"})
		var base := p.get_file()
		if base != base.to_lower() and p.ends_with(".gd"):
			# GDScript files often snake_case
			if base.find("_") < 0 and base[0] == base[0].to_upper():
				pass  # class_name style file ok
	return success({
		"files_scanned": files.size(),
		"issues": issues.slice(0, mini(50, issues.size())),
		"ok": issues.is_empty(),
	})


func _collect(dir_path: String, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.rstrip("/") + "/" + name if dir_path != "res://" else "res://" + name
		if dir.current_is_dir():
			if name != ".godot" and name != "addons":
				_collect(full, out, max_n)
		else:
			out.append(full)
		name = dir.get_next()
		if out.size() >= max_n:
			break
	dir.list_dir_end()
