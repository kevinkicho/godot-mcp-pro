@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Advanced UI containers - Tab/Split/Flow/Center/Aspect/SubViewport.


func get_commands() -> Dictionary:
	return {
		"setup_tab_container": _setup_tab_container,
		"setup_split_container": _setup_split_container,
		"setup_flow_container": _setup_flow_container,
		"setup_center_container": _setup_center_container,
		"setup_aspect_ratio_container": _setup_aspect_ratio_container,
		"setup_subviewport_container": _setup_subviewport_container,
		"tab_container_add_page": _tab_container_add_page,
		"list_ui_container_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_vbox", "setup_hbox", "setup_scroll_container", "set_anchor_preset", "setup_control"],
	})


func _add(parent_path: String, node: Control, root: Node, action: String) -> Dictionary:
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	add_child_with_undo(parent, node, root, action)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "type": node.get_class()})


func _flags(c: Control, params: Dictionary) -> void:
	if params.has("size_flags_h"):
		c.size_flags_horizontal = int(params["size_flags_h"])
	if params.has("size_flags_v"):
		c.size_flags_vertical = int(params["size_flags_v"])
	if optional_bool(params, "expand", false):
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _setup_tab_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var tabs := TabContainer.new()
	tabs.name = optional_string(params, "name", "TabContainer")
	if params.has("current_tab"):
		tabs.current_tab = int(params["current_tab"])
	if params.has("tab_alignment") and "tab_alignment" in tabs:
		tabs.tab_alignment = int(params["tab_alignment"])
	_flags(tabs, params)
	var res := _add(optional_string(params, "parent_path", "."), tabs, root, "MCP: TabContainer")
	# Optional pages
	if params.has("pages") and params["pages"] is Array:
		for p in params["pages"]:
			var title := str(p) if not (p is Dictionary) else str(p.get("title", p.get("name", "Tab")))
			var page := VBoxContainer.new()
			page.name = title
			add_child_with_undo(tabs, page, root, "MCP: Tab page")
			if tabs.has_method("set_tab_title"):
				var idx := tabs.get_child_count() - 1
				tabs.set_tab_title(idx, title)
	return res


func _setup_split_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var vertical: bool = optional_bool(params, "vertical", false)
	var split: SplitContainer
	if vertical:
		split = VSplitContainer.new()
		split.name = optional_string(params, "name", "VSplitContainer")
	else:
		split = HSplitContainer.new()
		split.name = optional_string(params, "name", "HSplitContainer")
	if params.has("split_offset"):
		split.split_offset = int(params["split_offset"])
	if params.has("collapsed"):
		split.collapsed = bool(params["collapsed"])
	_flags(split, params)
	return _add(optional_string(params, "parent_path", "."), split, root, "MCP: SplitContainer")


func _setup_flow_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var vertical: bool = optional_bool(params, "vertical", false)
	var flow: FlowContainer
	if ClassDB.class_exists("HFlowContainer") and not vertical:
		flow = HFlowContainer.new()
		flow.name = optional_string(params, "name", "HFlowContainer")
	elif ClassDB.class_exists("VFlowContainer") and vertical:
		flow = VFlowContainer.new()
		flow.name = optional_string(params, "name", "VFlowContainer")
	elif ClassDB.class_exists("FlowContainer"):
		flow = FlowContainer.new()
		flow.name = optional_string(params, "name", "FlowContainer")
	else:
		return error_internal("FlowContainer unavailable")
	if params.has("alignment") and "alignment" in flow:
		flow.set("alignment", int(params["alignment"]))
	_flags(flow, params)
	return _add(optional_string(params, "parent_path", "."), flow, root, "MCP: FlowContainer")


func _setup_center_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var c := CenterContainer.new()
	c.name = optional_string(params, "name", "CenterContainer")
	_flags(c, params)
	return _add(optional_string(params, "parent_path", "."), c, root, "MCP: CenterContainer")


func _setup_aspect_ratio_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var a := AspectRatioContainer.new()
	a.name = optional_string(params, "name", "AspectRatioContainer")
	if params.has("ratio"):
		a.ratio = float(params["ratio"])
	if params.has("stretch_mode"):
		a.stretch_mode = int(params["stretch_mode"]) as AspectRatioContainer.StretchMode
	if params.has("alignment_horizontal"):
		a.alignment_horizontal = int(params["alignment_horizontal"]) as AspectRatioContainer.AlignmentMode
	if params.has("alignment_vertical"):
		a.alignment_vertical = int(params["alignment_vertical"]) as AspectRatioContainer.AlignmentMode
	_flags(a, params)
	return _add(optional_string(params, "parent_path", "."), a, root, "MCP: AspectRatioContainer")


func _setup_subviewport_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var container := SubViewportContainer.new()
	container.name = optional_string(params, "name", "SubViewportContainer")
	container.stretch = optional_bool(params, "stretch", true)
	_flags(container, params)
	var sv := SubViewport.new()
	sv.name = "SubViewport"
	sv.size = Vector2i(
		int(params.get("width", 256)),
		int(params.get("height", 256))
	)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if params.has("transparent_bg"):
		sv.transparent_bg = bool(params["transparent_bg"])
	add_child_with_undo(parent, container, root, "MCP: SubViewportContainer")
	add_child_with_undo(container, sv, root, "MCP: SubViewport")
	mark_current_scene_unsaved()
	return success({
		"container_path": str(root.get_path_to(container)),
		"viewport_path": str(root.get_path_to(sv)),
		"size": {"x": sv.size.x, "y": sv.size.y},
	})


func _tab_container_add_page(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tabs := find_node_by_path(r0[0])
	if tabs == null or not (tabs is TabContainer):
		return error_not_found("TabContainer")
	var root := get_edited_root()
	var title: String = optional_string(params, "title", "Tab")
	var child_type: String = optional_string(params, "child_type", "VBoxContainer")
	var page: Control
	match child_type:
		"HBoxContainer":
			page = HBoxContainer.new()
		"ScrollContainer":
			page = ScrollContainer.new()
		"MarginContainer":
			page = MarginContainer.new()
		_:
			page = VBoxContainer.new()
	page.name = title
	add_child_with_undo(tabs, page, root, "MCP: Tab page")
	var idx := tabs.get_child_count() - 1
	if tabs.has_method("set_tab_title"):
		(tabs as TabContainer).set_tab_title(idx, title)
	mark_current_scene_unsaved()
	return success({"page_path": str(root.get_path_to(page)), "title": title, "index": idx})
