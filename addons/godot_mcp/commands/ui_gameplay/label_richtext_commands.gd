@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Label / RichTextLabel structural helpers for UI agents.


func get_commands() -> Dictionary:
	return {
		"setup_label": _setup_label,
		"setup_richtext_label": _setup_richtext_label,
		"richtext_append_bbcode": _richtext_append_bbcode,
		"label_set_autowrap": _label_set_autowrap,
		"list_label_richtext_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["richtext_set_bbcode", "set_theme_*", "setup_control"],
	})


func _setup_label(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var label := Label.new()
	label.name = optional_string(params, "name", "Label")
	label.text = optional_string(params, "text", "")
	if params.has("horizontal_alignment"):
		label.horizontal_alignment = int(params["horizontal_alignment"]) as HorizontalAlignment
	if params.has("vertical_alignment"):
		label.vertical_alignment = int(params["vertical_alignment"]) as VerticalAlignment
	if params.has("autowrap"):
		label.autowrap_mode = int(params["autowrap"]) as TextServer.AutowrapMode
	if optional_bool(params, "autowrap_word", false):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child_with_undo(parent, label, root, "MCP: Label")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(label)), "text": label.text})


func _setup_richtext_label(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var rtl := RichTextLabel.new()
	rtl.name = optional_string(params, "name", "RichTextLabel")
	rtl.bbcode_enabled = optional_bool(params, "bbcode_enabled", true)
	rtl.fit_content = optional_bool(params, "fit_content", false)
	rtl.scroll_active = optional_bool(params, "scroll_active", true)
	var text: String = optional_string(params, "text", optional_string(params, "bbcode", ""))
	if rtl.bbcode_enabled:
		rtl.text = text
	else:
		rtl.text = text
	if params.has("custom_minimum_size"):
		var s = params["custom_minimum_size"]
		if s is Dictionary:
			rtl.custom_minimum_size = Vector2(float(s.get("x", 100)), float(s.get("y", 40)))
	add_child_with_undo(parent, rtl, root, "MCP: RichTextLabel")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(rtl)), "bbcode_enabled": rtl.bbcode_enabled})


func _richtext_append_bbcode(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is RichTextLabel):
		return error_not_found("RichTextLabel")
	var rtl := n as RichTextLabel
	var bb: String = optional_string(params, "bbcode", optional_string(params, "text", ""))
	if bb.is_empty():
		return error_invalid_params("bbcode/text required")
	if rtl.has_method("append_text"):
		rtl.append_text(bb)
	else:
		rtl.text = rtl.text + bb
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "appended_length": bb.length()})


func _label_set_autowrap(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Label):
		return error_not_found("Label")
	var label := n as Label
	var mode_str: String = optional_string(params, "mode", "word_smart").to_lower()
	match mode_str:
		"off", "none":
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
		"arbitrary":
			label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		"word":
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "autowrap_mode": label.autowrap_mode})
