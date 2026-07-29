@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## StyleBoxFlat / theme stylebox authoring for UI agents.


func get_commands() -> Dictionary:
	return {
		"create_stylebox_flat": _create_stylebox_flat,
		"theme_set_stylebox_flat": _theme_set_stylebox_flat,
		"apply_stylebox_to_panel": _apply_stylebox_to_panel,
		"list_stylebox_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_theme", "theme_set_type_*", "assign_theme_to_control", "setup_panel_container"],
	})


func _make_flat(params: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if params.has("bg_color"):
		var c := str(params["bg_color"])
		sb.bg_color = Color.html(c) if c.begins_with("#") else Color(c)
	else:
		sb.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	if params.has("border_color"):
		var bc := str(params["border_color"])
		sb.border_color = Color.html(bc) if bc.begins_with("#") else Color(bc)
	var bw: int = int(params.get("border_width", 0))
	if params.has("border_width_left") or bw > 0:
		sb.border_width_left = int(params.get("border_width_left", bw))
		sb.border_width_top = int(params.get("border_width_top", bw))
		sb.border_width_right = int(params.get("border_width_right", bw))
		sb.border_width_bottom = int(params.get("border_width_bottom", bw))
	var cr: int = int(params.get("corner_radius", 0))
	if params.has("corner_radius") or params.has("corner_radius_top_left"):
		sb.corner_radius_top_left = int(params.get("corner_radius_top_left", cr))
		sb.corner_radius_top_right = int(params.get("corner_radius_top_right", cr))
		sb.corner_radius_bottom_right = int(params.get("corner_radius_bottom_right", cr))
		sb.corner_radius_bottom_left = int(params.get("corner_radius_bottom_left", cr))
	if params.has("content_margin"):
		var m: int = int(params["content_margin"])
		sb.content_margin_left = m
		sb.content_margin_top = m
		sb.content_margin_right = m
		sb.content_margin_bottom = m
	if params.has("shadow_size"):
		sb.shadow_size = int(params["shadow_size"])
	if params.has("shadow_color"):
		var sc := str(params["shadow_color"])
		sb.shadow_color = Color.html(sc) if sc.begins_with("#") else Color(sc)
	if params.has("anti_aliasing"):
		sb.anti_aliasing = bool(params["anti_aliasing"])
	return sb


func _create_stylebox_flat(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://themes/stylebox_panel.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var sb := _make_flat(params)
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(sb, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "type": "StyleBoxFlat", "bg_color": sb.bg_color.to_html()})


func _theme_set_stylebox_flat(params: Dictionary) -> Dictionary:
	var theme_r := require_res_path(params, "theme_path")
	if theme_r[1] != null:
		return theme_r[1]
	var theme: Theme = load(theme_r[0]) as Theme
	if theme == null:
		return error_not_found("Theme")
	var type_name: String = optional_string(params, "type", "PanelContainer")
	var style_name: String = optional_string(params, "style_name", "panel")
	var sb := _make_flat(params)
	if optional_bool(params, "save_stylebox", false):
		var sp: String = optional_string(params, "stylebox_path", theme_r[0].get_base_dir() + "/sb_%s.tres" % style_name)
		ResourceSaver.save(sb, sp)
		sb = load(sp) as StyleBoxFlat
	theme.set_stylebox(style_name, type_name, sb)
	var err := ResourceSaver.save(theme, theme_r[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"theme_path": theme_r[0],
		"type": type_name,
		"style_name": style_name,
	})


func _apply_stylebox_to_panel(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Control):
		return error_not_found("Control")
	var ctrl := n as Control
	var sb: StyleBox
	if params.has("stylebox_path") and ResourceLoader.exists(str(params["stylebox_path"])):
		sb = load(str(params["stylebox_path"])) as StyleBox
	else:
		sb = _make_flat(params)
	var style_name: String = optional_string(params, "style_name", "panel")
	ctrl.add_theme_stylebox_override(style_name, sb)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "style_name": style_name})
