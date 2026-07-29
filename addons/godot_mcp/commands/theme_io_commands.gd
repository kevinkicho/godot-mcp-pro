@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Theme resource I/O — export/import/duplicate project themes for agents.


func get_commands() -> Dictionary:
	return {
		"export_theme_resource": _export_theme,
		"import_theme_to_project": _import_theme,
		"duplicate_theme_resource": _duplicate_theme,
		"assign_theme_to_scene_root": _assign_to_root,
		"list_theme_io_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_theme", "theme_set_type_color", "theme_seed_default_types", "assign_theme_to_control"],
	})


func _export_theme(params: Dictionary) -> Dictionary:
	## Save Theme from a Control or existing theme path to a new .tres
	var dest := require_res_path(params, "path")
	if dest[1] != null:
		return dest[1]
	var path: String = dest[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	var theme: Theme = null
	var src: String = optional_string(params, "theme_path", "")
	if not src.is_empty():
		var vr := validate_res_path(src)
		if vr[1] != null:
			return vr[1]
		if ResourceLoader.exists(vr[0]):
			var r = load(vr[0])
			if r is Theme:
				theme = (r as Theme).duplicate(true) as Theme
	if theme == null:
		var node_path: String = optional_string(params, "node_path", "")
		if not node_path.is_empty():
			var n := find_node_by_path(node_path)
			if n is Control and (n as Control).theme:
				theme = (n as Control).theme.duplicate(true) as Theme
			elif n is Window and (n as Window).theme:
				theme = (n as Window).theme.duplicate(true) as Theme
	if theme == null and optional_bool(params, "from_project_default", true):
		theme = ThemeDB.get_default_theme().duplicate(true) as Theme if ThemeDB.get_default_theme() else Theme.new()
	if theme == null:
		theme = Theme.new()
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(theme, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "type_count": theme.get_type_list().size() if theme.has_method("get_type_list") else 0})


func _import_theme(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	if not ResourceLoader.exists(res[0]):
		return error_not_found(res[0])
	var r = load(res[0])
	if not (r is Theme):
		return error_internal("Not a Theme")
	if optional_bool(params, "set_project_default", false):
		# Project default theme path setting
		ProjectSettings.set_setting("gui/theme/custom", res[0])
		ProjectSettings.save()
	return success({
		"path": res[0],
		"set_project_default": optional_bool(params, "set_project_default", false),
		"hint": "assign_theme_to_control or assign_theme_to_scene_root",
	})


func _duplicate_theme(params: Dictionary) -> Dictionary:
	var from_r := require_res_path(params, "from_path")
	if from_r[1] != null:
		return from_r[1]
	var to_r := require_res_path(params, "to_path")
	if to_r[1] != null:
		return to_r[1]
	return _export_theme({
		"path": to_r[0],
		"theme_path": from_r[0],
		"overwrite": optional_bool(params, "overwrite", false),
		"from_project_default": false,
	})


func _assign_to_root(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var theme_r := require_res_path(params, "theme_path")
	if theme_r[1] != null:
		return theme_r[1]
	if not ResourceLoader.exists(theme_r[0]):
		return error_not_found(theme_r[0])
	var theme = load(theme_r[0])
	if not (theme is Theme):
		return error_internal("Not Theme")
	if root is Control:
		(root as Control).theme = theme
	elif root is Window:
		(root as Window).theme = theme
	else:
		# Find first Control child or add CanvasLayer+Control
		var found: Control = null
		for c in root.get_children():
			if c is Control:
				found = c
				break
		if found:
			found.theme = theme
			mark_current_scene_unsaved()
			return success({"node_path": str(root.get_path_to(found)), "theme_path": theme_r[0]})
		return error_invalid_params("Scene root is not Control/Window and no Control child found")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(root)), "theme_path": theme_r[0]})
