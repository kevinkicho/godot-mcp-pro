@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## FontFile / LabelSettings - UI typography agents need beyond theme colors.


func get_commands() -> Dictionary:
	return {
		"create_font_file_resource": _create_font,
		"create_label_settings": _create_label_settings,
		"assign_label_settings": _assign_label_settings,
		"set_label_font_size": _set_label_font_size,
		"list_font_label_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_label", "theme_set_type_font", "create_theme", "setup_richtext_label"],
	})


func _create_font(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var font_src := require_res_path(params, "font_path")
	if font_src[1] != null:
		# also accept source_path
		if params.has("source_path"):
			font_src = require_res_path(params, "source_path")
		if font_src[1] != null:
			return error_invalid_params("font_path (ttf/otf/woff under res://) required")
	var path: String = res[0]
	var src: String = font_src[0]
	if not ResourceLoader.exists(src) and not FileAccess.file_exists(src):
		return error_not_found(src)
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var font := FontFile.new()
	var err := font.load_dynamic_font(ProjectSettings.globalize_path(src))
	if err != OK:
		# Fallback: try load as resource
		var loaded = load(src)
		if loaded is Font:
			var derr := ensure_parent_dir(path)
			if not derr.is_empty():
				return derr
			var serr := ResourceSaver.save(loaded, path)
			if serr != OK:
				return error_internal(error_string(serr))
			EditorInterface.get_resource_filesystem().update_file(path)
			return success({"path": path, "source": src, "mode": "resource_copy"})
		return error_internal("load_dynamic_font failed: %s" % error_string(err))
	if params.has("oversampling"):
		font.oversampling = float(params["oversampling"])
	if params.has("antialiasing"):
		font.antialiasing = int(params["antialiasing"]) as TextServer.FontAntialiasing
	var derr2 := ensure_parent_dir(path)
	if not derr2.is_empty():
		return derr2
	var serr2 := ResourceSaver.save(font, path)
	if serr2 != OK:
		return error_internal(error_string(serr2))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "source": src, "class": "FontFile"})


func _create_label_settings(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var ls := LabelSettings.new()
	if params.has("font_size"):
		ls.font_size = int(params["font_size"])
	if params.has("font_color"):
		var c = params["font_color"]
		ls.font_color = Color.html(str(c)) if str(c).begins_with("#") else Color(str(c))
	if params.has("outline_size"):
		ls.outline_size = int(params["outline_size"])
	if params.has("outline_color"):
		var oc = params["outline_color"]
		ls.outline_color = Color.html(str(oc)) if str(oc).begins_with("#") else Color(str(oc))
	if params.has("shadow_size"):
		ls.shadow_size = int(params["shadow_size"])
	if params.has("shadow_color"):
		var sc = params["shadow_color"]
		ls.shadow_color = Color.html(str(sc)) if str(sc).begins_with("#") else Color(str(sc))
	if params.has("line_spacing"):
		ls.line_spacing = float(params["line_spacing"])
	if params.has("font_path") and ResourceLoader.exists(str(params["font_path"])):
		var f = load(str(params["font_path"]))
		if f is Font:
			ls.font = f
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(ls, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"font_size": ls.font_size,
		"class": "LabelSettings",
	})


func _assign_label_settings(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var ls_r := require_res_path(params, "label_settings_path")
	if ls_r[1] != null:
		return ls_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is Label):
		return error_not_found("Label at '%s'" % r0[0])
	if not ResourceLoader.exists(ls_r[0]):
		return error_not_found(ls_r[0])
	var ls = load(ls_r[0])
	if not (ls is LabelSettings):
		return error_internal("Not LabelSettings")
	(node as Label).label_settings = ls
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "label_settings_path": ls_r[0]})


func _set_label_font_size(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is Control):
		return error_not_found("Control")
	var size: int = optional_int(params, "font_size", 16)
	if node is Label:
		var lab: Label = node as Label
		if lab.label_settings:
			lab.label_settings = lab.label_settings.duplicate()
			lab.label_settings.font_size = size
		else:
			lab.add_theme_font_size_override("font_size", size)
	elif node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_size_override("normal_font_size", size)
	elif node is Button:
		(node as Button).add_theme_font_size_override("font_size", size)
	else:
		(node as Control).add_theme_font_size_override("font_size", size)
	if params.has("font_color"):
		var c = params["font_color"]
		var col := Color.html(str(c)) if str(c).begins_with("#") else Color(str(c))
		(node as Control).add_theme_color_override("font_color", col)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "font_size": size})
