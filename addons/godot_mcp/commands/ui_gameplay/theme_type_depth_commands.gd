@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Full Theme type surface — fonts, icons, bulk type seed (Wave 4).


func get_commands() -> Dictionary:
	return {
		"theme_set_type_font": _theme_set_type_font,
		"theme_set_type_icon": _theme_set_type_icon,
		"theme_seed_default_types": _theme_seed_default_types,
		"theme_list_type_items": _theme_list_type_items,
		"theme_copy_type": _theme_copy_type,
		"list_theme_type_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_theme", "theme_set_type_color", "theme_set_type_stylebox", "create_stylebox_flat", "assign_theme_to_control"],
	})


func _load_theme(path: String) -> Theme:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Theme


func _theme_set_type_font(params: Dictionary) -> Dictionary:
	var theme_r := require_res_path(params, "theme_path")
	if theme_r[1] != null:
		return theme_r[1]
	var theme := _load_theme(theme_r[0])
	if theme == null:
		return error_not_found("Theme")
	var type_name: String = optional_string(params, "type", "Label")
	var font_name: String = optional_string(params, "name", "font")
	var font_path: String = optional_string(params, "font_path", "")
	if font_path.is_empty() or not ResourceLoader.exists(font_path):
		return error_invalid_params("font_path res:// font required")
	var font = load(font_path)
	if font == null or not (font is Font):
		return error_invalid_params("Not a Font resource")
	theme.set_font(font_name, type_name, font)
	if params.has("font_size"):
		theme.set_font_size(optional_string(params, "size_name", "font_size"), type_name, int(params["font_size"]))
	var err := ResourceSaver.save(theme, theme_r[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"theme_path": theme_r[0], "type": type_name, "font": font_name, "font_path": font_path})


func _theme_set_type_icon(params: Dictionary) -> Dictionary:
	var theme_r := require_res_path(params, "theme_path")
	if theme_r[1] != null:
		return theme_r[1]
	var theme := _load_theme(theme_r[0])
	if theme == null:
		return error_not_found("Theme")
	var type_name: String = optional_string(params, "type", "Button")
	var icon_name: String = optional_string(params, "name", "icon")
	var tex_path: String = optional_string(params, "texture_path", optional_string(params, "icon_path", ""))
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		return error_invalid_params("texture_path required")
	var tex = load(tex_path)
	if tex == null or not (tex is Texture2D):
		return error_invalid_params("Not Texture2D")
	theme.set_icon(icon_name, type_name, tex)
	var err := ResourceSaver.save(theme, theme_r[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"theme_path": theme_r[0], "type": type_name, "icon": icon_name})


func _theme_seed_default_types(params: Dictionary) -> Dictionary:
	## Seed common control types with readable defaults on a Theme resource.
	var theme_r := require_res_path(params, "theme_path")
	if theme_r[1] != null:
		return theme_r[1]
	var theme := _load_theme(theme_r[0])
	if theme == null:
		# create
		theme = Theme.new()
	var types: Array = params.get("types", ["Button", "Label", "PanelContainer", "LineEdit", "CheckBox", "ProgressBar"])
	var bg: String = optional_string(params, "bg_color", "#2a2a32")
	var fg: String = optional_string(params, "font_color", "#e8e8ec")
	var accent: String = optional_string(params, "accent_color", "#4c8bf5")
	var applied: Array = []
	for t in types:
		var tn := str(t)
		theme.set_color("font_color", tn, Color.html(fg) if fg.begins_with("#") else Color(fg))
		if tn in ["Button", "LineEdit", "PanelContainer", "Panel"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.html(bg) if bg.begins_with("#") else Color(bg)
			sb.set_corner_radius_all(int(params.get("corner_radius", 6)))
			sb.set_content_margin_all(int(params.get("content_margin", 8)))
			if tn == "Button":
				sb.border_color = Color.html(accent) if accent.begins_with("#") else Color(accent)
				sb.set_border_width_all(1)
			theme.set_stylebox("panel" if tn.contains("Panel") else "normal", tn, sb)
			if tn == "Button":
				theme.set_stylebox("hover", tn, sb.duplicate())
				theme.set_stylebox("pressed", tn, sb.duplicate())
		applied.append(tn)
	if params.has("default_font_size"):
		theme.default_font_size = int(params["default_font_size"])
	var err := ResourceSaver.save(theme, theme_r[0])
	if err != OK:
		ensure_parent_dir(theme_r[0])
		err = ResourceSaver.save(theme, theme_r[0])
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(theme_r[0])
	return success({"theme_path": theme_r[0], "seeded_types": applied})


func _theme_list_type_items(params: Dictionary) -> Dictionary:
	var theme_r := require_res_path(params, "theme_path")
	if theme_r[1] != null:
		return theme_r[1]
	var theme := _load_theme(theme_r[0])
	if theme == null:
		return error_not_found("Theme")
	var type_name: String = optional_string(params, "type", "Button")
	return success({
		"type": type_name,
		"colors": theme.get_color_list(type_name),
		"constants": theme.get_constant_list(type_name),
		"fonts": theme.get_font_list(type_name),
		"font_sizes": theme.get_font_size_list(type_name),
		"icons": theme.get_icon_list(type_name),
		"styleboxes": theme.get_stylebox_list(type_name),
	})


func _theme_copy_type(params: Dictionary) -> Dictionary:
	var theme_r := require_res_path(params, "theme_path")
	if theme_r[1] != null:
		return theme_r[1]
	var theme := _load_theme(theme_r[0])
	if theme == null:
		return error_not_found("Theme")
	var from_t: String = optional_string(params, "from_type", "")
	var to_t: String = optional_string(params, "to_type", "")
	if from_t.is_empty() or to_t.is_empty():
		return error_invalid_params("from_type and to_type required")
	# Copy colors
	for n in theme.get_color_list(from_t):
		theme.set_color(n, to_t, theme.get_color(n, from_t))
	for n in theme.get_constant_list(from_t):
		theme.set_constant(n, to_t, theme.get_constant(n, from_t))
	for n in theme.get_font_list(from_t):
		theme.set_font(n, to_t, theme.get_font(n, from_t))
	for n in theme.get_font_size_list(from_t):
		theme.set_font_size(n, to_t, theme.get_font_size(n, from_t))
	for n in theme.get_icon_list(from_t):
		theme.set_icon(n, to_t, theme.get_icon(n, from_t))
	for n in theme.get_stylebox_list(from_t):
		theme.set_stylebox(n, to_t, theme.get_stylebox(n, from_t))
	var err := ResourceSaver.save(theme, theme_r[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"from_type": from_t, "to_type": to_t, "copied": true})
