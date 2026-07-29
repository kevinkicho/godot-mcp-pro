@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Remaining UI editor surfaces — CodeEdit, RichText effects, OptionButton bulk.


func get_commands() -> Dictionary:
	return {
		"setup_code_edit": _setup_code_edit,
		"setup_richtext_effects_basic": _setup_rte,
		"set_option_button_items": _set_option_items,
		"setup_progress_bar_ranged": _setup_progress,
		"list_ui_editor_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_label", "setup_button", "setup_text_edit", "richtext_set_bbcode", "set_anchor_preset"],
	})


func _setup_code_edit(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	if not ClassDB.class_exists("CodeEdit"):
		return error_internal("CodeEdit not available")
	var ce: Control = ClassDB.instantiate("CodeEdit")
	ce.name = optional_string(params, "name", "CodeEdit")
	if params.has("text"):
		ce.set("text", str(params["text"]))
	if "gutters_draw_line_numbers" in ce:
		ce.set("gutters_draw_line_numbers", optional_bool(params, "line_numbers", true))
	if "auto_brace_completion_enabled" in ce:
		ce.set("auto_brace_completion_enabled", optional_bool(params, "auto_brace", true))
	if params.has("min_size") and params["min_size"] is Dictionary:
		var s: Dictionary = params["min_size"]
		ce.custom_minimum_size = Vector2(float(s.get("x", 400)), float(s.get("y", 200)))
	else:
		ce.custom_minimum_size = Vector2(400, 200)
	add_child_with_undo(parent, ce, root, "MCP: CodeEdit")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(ce)), "class": "CodeEdit"})


func _setup_rte(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var rtl := RichTextLabel.new()
	rtl.name = optional_string(params, "name", "RichTextLabel")
	rtl.bbcode_enabled = true
	rtl.fit_content = optional_bool(params, "fit_content", true)
	rtl.scroll_active = optional_bool(params, "scroll_active", true)
	var bb: String = optional_string(params, "bbcode", "[b]Hello[/b] [i]world[/i]\n[color=yellow]BBCode[/color] enabled")
	rtl.text = bb
	# Custom effects need script resources — document for agent
	if params.has("min_size") and params["min_size"] is Dictionary:
		var s: Dictionary = params["min_size"]
		rtl.custom_minimum_size = Vector2(float(s.get("x", 300)), float(s.get("y", 100)))
	add_child_with_undo(parent, rtl, root, "MCP: RichTextLabel effects demo")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(rtl)),
		"bbcode_enabled": true,
		"hint": "Custom RichTextEffect requires a Script extending RichTextEffect — use create_script",
		"sample_bbcode": bb,
	})


func _set_option_items(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is OptionButton):
		return error_not_found("OptionButton")
	var ob: OptionButton = node as OptionButton
	if not params.has("items") or not (params["items"] is Array):
		return error_invalid_params("items array of strings required")
	ob.clear()
	for it in params["items"]:
		ob.add_item(str(it))
	if params.has("selected"):
		ob.select(int(params["selected"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "count": ob.item_count})


func _setup_progress(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var pb := ProgressBar.new()
	pb.name = optional_string(params, "name", "ProgressBar")
	pb.min_value = float(params.get("min_value", 0))
	pb.max_value = float(params.get("max_value", 100))
	pb.value = float(params.get("value", 0))
	pb.show_percentage = optional_bool(params, "show_percentage", true)
	pb.custom_minimum_size = Vector2(float(params.get("width", 200)), float(params.get("height", 24)))
	add_child_with_undo(parent, pb, root, "MCP: ProgressBar")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(pb)),
		"value": pb.value,
		"max_value": pb.max_value,
	})
