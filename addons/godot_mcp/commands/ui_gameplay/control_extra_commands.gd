@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Control extras — tooltips, cursors, clip, drag, ninepatch, color rect (human UI polish).


func get_commands() -> Dictionary:
	return {
		"set_control_tooltip": _set_control_tooltip,
		"set_control_cursor": _set_control_cursor,
		"set_control_clip_contents": _set_control_clip_contents,
		"set_control_custom_minimum_size": _set_control_custom_minimum_size,
		"set_control_modulate": _set_control_modulate,
		"setup_color_rect": _setup_color_rect,
		"setup_nine_patch_rect": _setup_nine_patch_rect,
		"setup_hseparator": _setup_hseparator,
		"setup_vseparator": _setup_vseparator,
		"setup_check_box": _setup_check_box,
		"setup_check_button": _setup_check_button,
		"setup_spin_box": _setup_spin_box,
		"setup_hslider": _setup_hslider,
		"setup_line_edit": _setup_line_edit,
		"setup_text_edit": _setup_text_edit,
	}


func _require_control(params: Dictionary) -> Array:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0
	var node := find_node_by_path(r0[0])
	if node == null or not node is Control:
		return [null, error_not_found("Control at '%s'" % r0[0])]
	return [node as Control, null]


func _set_control_tooltip(params: Dictionary) -> Dictionary:
	var r := _require_control(params)
	if r[1] != null:
		return r[1]
	var c: Control = r[0]
	var tip: String = optional_string(params, "tooltip", optional_string(params, "tooltip_text", ""))
	c.tooltip_text = tip
	mark_current_scene_unsaved()
	return success({"node_path": str(get_edited_root().get_path_to(c)), "tooltip_text": tip})


func _set_control_cursor(params: Dictionary) -> Dictionary:
	var r := _require_control(params)
	if r[1] != null:
		return r[1]
	var c: Control = r[0]
	var shape: String = optional_string(params, "shape", "arrow")
	var map := {
		"arrow": Control.CURSOR_ARROW,
		"ibeam": Control.CURSOR_IBEAM,
		"pointing_hand": Control.CURSOR_POINTING_HAND,
		"cross": Control.CURSOR_CROSS,
		"wait": Control.CURSOR_WAIT,
		"busy": Control.CURSOR_BUSY,
		"drag": Control.CURSOR_DRAG,
		"can_drop": Control.CURSOR_CAN_DROP,
		"forbidden": Control.CURSOR_FORBIDDEN,
		"vsize": Control.CURSOR_VSIZE,
		"hsize": Control.CURSOR_HSIZE,
		"bdiagsize": Control.CURSOR_BDIAGSIZE,
		"fdiagsize": Control.CURSOR_FDIAGSIZE,
		"move": Control.CURSOR_MOVE,
		"vsplit": Control.CURSOR_VSPLIT,
		"hsplit": Control.CURSOR_HSPLIT,
		"help": Control.CURSOR_HELP,
	}
	c.mouse_default_cursor_shape = map.get(shape, Control.CURSOR_ARROW)
	mark_current_scene_unsaved()
	return success({"shape": shape, "cursor": c.mouse_default_cursor_shape})


func _set_control_clip_contents(params: Dictionary) -> Dictionary:
	var r := _require_control(params)
	if r[1] != null:
		return r[1]
	var c: Control = r[0]
	c.clip_contents = optional_bool(params, "clip_contents", true)
	mark_current_scene_unsaved()
	return success({"clip_contents": c.clip_contents})


func _set_control_custom_minimum_size(params: Dictionary) -> Dictionary:
	var r := _require_control(params)
	if r[1] != null:
		return r[1]
	var c: Control = r[0]
	var x := float(params.get("x", params.get("width", c.custom_minimum_size.x)))
	var y := float(params.get("y", params.get("height", c.custom_minimum_size.y)))
	c.custom_minimum_size = Vector2(x, y)
	mark_current_scene_unsaved()
	return success({"custom_minimum_size": {"x": x, "y": y}})


func _set_control_modulate(params: Dictionary) -> Dictionary:
	var r := _require_control(params)
	if r[1] != null:
		return r[1]
	var c: Control = r[0]
	var col := c.modulate
	if params.has("color"):
		var v = params["color"]
		if v is String:
			col = Color.html(v) if str(v).begins_with("#") else Color(v)
		elif v is Dictionary:
			col = Color(float(v.get("r", 1)), float(v.get("g", 1)), float(v.get("b", 1)), float(v.get("a", 1)))
	if params.has("a"):
		col.a = float(params["a"])
	c.modulate = col
	mark_current_scene_unsaved()
	return success({"modulate": col.to_html(true)})


func _add_control(parent_path: String, node: Control, action: String) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	add_child_with_undo(parent, node, root, action)
	return success({"node_path": str(root.get_path_to(node)), "type": node.get_class()})


func _setup_color_rect(params: Dictionary) -> Dictionary:
	var cr := ColorRect.new()
	cr.name = optional_string(params, "name", "ColorRect")
	var col := Color(0.2, 0.2, 0.25, 1)
	if params.has("color"):
		var v = params["color"]
		if v is String:
			col = Color.html(v) if str(v).begins_with("#") else Color(v)
	cr.color = col
	return _add_control(optional_string(params, "parent_path", "."), cr, "MCP: Add ColorRect")


func _setup_nine_patch_rect(params: Dictionary) -> Dictionary:
	var np := NinePatchRect.new()
	np.name = optional_string(params, "name", "NinePatchRect")
	var tex: String = optional_string(params, "texture_path", "")
	if not tex.is_empty():
		if not tex.begins_with("res://"):
			tex = "res://" + tex.trim_prefix("/")
		if ResourceLoader.exists(tex):
			np.texture = load(tex)
	if params.has("patch_margin_left"):
		np.patch_margin_left = int(params["patch_margin_left"])
	if params.has("patch_margin_top"):
		np.patch_margin_top = int(params["patch_margin_top"])
	if params.has("patch_margin_right"):
		np.patch_margin_right = int(params["patch_margin_right"])
	if params.has("patch_margin_bottom"):
		np.patch_margin_bottom = int(params["patch_margin_bottom"])
	var m: int = optional_int(params, "patch_margin", -1)
	if m >= 0:
		np.patch_margin_left = m
		np.patch_margin_top = m
		np.patch_margin_right = m
		np.patch_margin_bottom = m
	return _add_control(optional_string(params, "parent_path", "."), np, "MCP: Add NinePatchRect")


func _setup_hseparator(params: Dictionary) -> Dictionary:
	var s := HSeparator.new()
	s.name = optional_string(params, "name", "HSeparator")
	return _add_control(optional_string(params, "parent_path", "."), s, "MCP: Add HSeparator")


func _setup_vseparator(params: Dictionary) -> Dictionary:
	var s := VSeparator.new()
	s.name = optional_string(params, "name", "VSeparator")
	return _add_control(optional_string(params, "parent_path", "."), s, "MCP: Add VSeparator")


func _setup_check_box(params: Dictionary) -> Dictionary:
	var cb := CheckBox.new()
	cb.name = optional_string(params, "name", "CheckBox")
	cb.text = optional_string(params, "text", "CheckBox")
	cb.button_pressed = optional_bool(params, "pressed", false)
	return _add_control(optional_string(params, "parent_path", "."), cb, "MCP: Add CheckBox")


func _setup_check_button(params: Dictionary) -> Dictionary:
	var cb := CheckButton.new()
	cb.name = optional_string(params, "name", "CheckButton")
	cb.text = optional_string(params, "text", "CheckButton")
	cb.button_pressed = optional_bool(params, "pressed", false)
	return _add_control(optional_string(params, "parent_path", "."), cb, "MCP: Add CheckButton")


func _setup_spin_box(params: Dictionary) -> Dictionary:
	var sb := SpinBox.new()
	sb.name = optional_string(params, "name", "SpinBox")
	sb.min_value = float(params.get("min_value", 0))
	sb.max_value = float(params.get("max_value", 100))
	sb.step = float(params.get("step", 1))
	sb.value = float(params.get("value", 0))
	return _add_control(optional_string(params, "parent_path", "."), sb, "MCP: Add SpinBox")


func _setup_hslider(params: Dictionary) -> Dictionary:
	var sl := HSlider.new()
	sl.name = optional_string(params, "name", "HSlider")
	sl.min_value = float(params.get("min_value", 0))
	sl.max_value = float(params.get("max_value", 100))
	sl.step = float(params.get("step", 1))
	sl.value = float(params.get("value", 50))
	return _add_control(optional_string(params, "parent_path", "."), sl, "MCP: Add HSlider")


func _setup_line_edit(params: Dictionary) -> Dictionary:
	var le := LineEdit.new()
	le.name = optional_string(params, "name", "LineEdit")
	le.text = optional_string(params, "text", "")
	le.placeholder_text = optional_string(params, "placeholder", optional_string(params, "placeholder_text", ""))
	le.editable = optional_bool(params, "editable", true)
	le.secret = optional_bool(params, "secret", false)
	return _add_control(optional_string(params, "parent_path", "."), le, "MCP: Add LineEdit")


func _setup_text_edit(params: Dictionary) -> Dictionary:
	var te := TextEdit.new()
	te.name = optional_string(params, "name", "TextEdit")
	te.text = optional_string(params, "text", "")
	te.editable = optional_bool(params, "editable", true)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if optional_bool(params, "wrap", false) else TextEdit.LINE_WRAPPING_NONE
	return _add_control(optional_string(params, "parent_path", "."), te, "MCP: Add TextEdit")
