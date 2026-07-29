@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## UI container recipes - HBox/VBox/Grid/Margin packs like a human layout pass.


func get_commands() -> Dictionary:
	return {
		"setup_vbox": _setup_vbox,
		"setup_hbox": _setup_hbox,
		"setup_grid_container": _setup_grid_container,
		"setup_margin_container": _setup_margin_container,
		"setup_scroll_container": _setup_scroll_container,
		"setup_panel_container": _setup_panel_container,
		"apply_container_recipe": _apply_container_recipe,
		"list_container_recipes": _list_container_recipes,
	}


func _add_container(parent_path: String, node: Control, root: Node, action: String) -> Dictionary:
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	add_child_with_undo(parent, node, root, action)
	return success({"node_path": str(root.get_path_to(node)), "type": node.get_class()})


func _setup_vbox(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var box := VBoxContainer.new()
	box.name = optional_string(params, "name", "VBoxContainer")
	if params.has("separation"):
		box.add_theme_constant_override("separation", int(params["separation"]))
	_apply_size_flags(box, params)
	return _add_container(optional_string(params, "parent_path", "."), box, root, "MCP: Add VBoxContainer")


func _setup_hbox(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var box := HBoxContainer.new()
	box.name = optional_string(params, "name", "HBoxContainer")
	if params.has("separation"):
		box.add_theme_constant_override("separation", int(params["separation"]))
	_apply_size_flags(box, params)
	return _add_container(optional_string(params, "parent_path", "."), box, root, "MCP: Add HBoxContainer")


func _setup_grid_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var grid := GridContainer.new()
	grid.name = optional_string(params, "name", "GridContainer")
	grid.columns = optional_int(params, "columns", 2)
	if params.has("h_separation"):
		grid.add_theme_constant_override("h_separation", int(params["h_separation"]))
	if params.has("v_separation"):
		grid.add_theme_constant_override("v_separation", int(params["v_separation"]))
	_apply_size_flags(grid, params)
	return _add_container(optional_string(params, "parent_path", "."), grid, root, "MCP: Add GridContainer")


func _setup_margin_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var mc := MarginContainer.new()
	mc.name = optional_string(params, "name", "MarginContainer")
	var m: int = optional_int(params, "margin", -1)
	if m >= 0:
		for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			mc.add_theme_constant_override(side, m)
	else:
		if params.has("left"):
			mc.add_theme_constant_override("margin_left", int(params["left"]))
		if params.has("top"):
			mc.add_theme_constant_override("margin_top", int(params["top"]))
		if params.has("right"):
			mc.add_theme_constant_override("margin_right", int(params["right"]))
		if params.has("bottom"):
			mc.add_theme_constant_override("margin_bottom", int(params["bottom"]))
	_apply_size_flags(mc, params)
	return _add_container(optional_string(params, "parent_path", "."), mc, root, "MCP: Add MarginContainer")


func _setup_scroll_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var sc := ScrollContainer.new()
	sc.name = optional_string(params, "name", "ScrollContainer")
	sc.horizontal_scroll_mode = int(params.get("horizontal_scroll_mode", ScrollContainer.SCROLL_MODE_AUTO))
	sc.vertical_scroll_mode = int(params.get("vertical_scroll_mode", ScrollContainer.SCROLL_MODE_AUTO))
	_apply_size_flags(sc, params)
	return _add_container(optional_string(params, "parent_path", "."), sc, root, "MCP: Add ScrollContainer")


func _setup_panel_container(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var pc := PanelContainer.new()
	pc.name = optional_string(params, "name", "PanelContainer")
	_apply_size_flags(pc, params)
	return _add_container(optional_string(params, "parent_path", "."), pc, root, "MCP: Add PanelContainer")


func _apply_size_flags(c: Control, params: Dictionary) -> void:
	var flags := {
		"fill": Control.SIZE_FILL,
		"expand": Control.SIZE_EXPAND,
		"fill_expand": Control.SIZE_EXPAND_FILL,
		"expand_fill": Control.SIZE_EXPAND_FILL,
		"shrink_center": Control.SIZE_SHRINK_CENTER,
		"shrink_end": Control.SIZE_SHRINK_END,
	}
	if params.has("size_flags_h"):
		var h := str(params["size_flags_h"])
		if flags.has(h):
			c.size_flags_horizontal = flags[h]
	if params.has("size_flags_v"):
		var v := str(params["size_flags_v"])
		if flags.has(v):
			c.size_flags_vertical = flags[v]
	if params.has("stretch_ratio"):
		c.size_flags_stretch_ratio = float(params["stretch_ratio"])


func _list_container_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"recipes": {
			"full_rect_margin_vbox": "MarginContainer full rect + VBox child (HUD root)",
			"toolbar_hbox": "HBox expand fill, separation 8 (top bar)",
			"form_grid": "GridContainer columns=2 (label/field forms)",
			"scroll_list": "ScrollContainer + VBox (inventory lists)",
			"centered_panel": "CenterContainer-like via anchors + PanelContainer",
			"sidebar_split": "HBox: fixed sidebar + expand content VBox",
		},
		"usage": "apply_container_recipe recipe=full_rect_margin_vbox parent_path=.",
	})


func _apply_container_recipe(params: Dictionary) -> Dictionary:
	var recipe: String = optional_string(params, "recipe", "full_rect_margin_vbox")
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var created: Array = []
	match recipe:
		"full_rect_margin_vbox":
			var mc := MarginContainer.new()
			mc.name = optional_string(params, "name", "HUDRoot")
			mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var m: int = optional_int(params, "margin", 16)
			for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
				mc.add_theme_constant_override(side, m)
			add_child_with_undo(parent, mc, root, "MCP: container recipe")
			var vb := VBoxContainer.new()
			vb.name = "VBox"
			vb.add_theme_constant_override("separation", optional_int(params, "separation", 8))
			mc.add_child(vb)
			vb.owner = root
			created = [str(root.get_path_to(mc)), str(root.get_path_to(vb))]
		"toolbar_hbox":
			var hb := HBoxContainer.new()
			hb.name = optional_string(params, "name", "Toolbar")
			hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_theme_constant_override("separation", optional_int(params, "separation", 8))
			add_child_with_undo(parent, hb, root, "MCP: toolbar recipe")
			created = [str(root.get_path_to(hb))]
		"form_grid":
			var grid := GridContainer.new()
			grid.name = optional_string(params, "name", "FormGrid")
			grid.columns = optional_int(params, "columns", 2)
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 8)
			add_child_with_undo(parent, grid, root, "MCP: form grid")
			created = [str(root.get_path_to(grid))]
		"scroll_list":
			var sc := ScrollContainer.new()
			sc.name = optional_string(params, "name", "ScrollList")
			sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			add_child_with_undo(parent, sc, root, "MCP: scroll list")
			var vb2 := VBoxContainer.new()
			vb2.name = "Items"
			vb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sc.add_child(vb2)
			vb2.owner = root
			created = [str(root.get_path_to(sc)), str(root.get_path_to(vb2))]
		"sidebar_split":
			var split := HBoxContainer.new()
			split.name = optional_string(params, "name", "SidebarSplit")
			split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child_with_undo(parent, split, root, "MCP: sidebar split")
			var side := VBoxContainer.new()
			side.name = "Sidebar"
			side.custom_minimum_size = Vector2(float(params.get("sidebar_width", 200)), 0)
			split.add_child(side)
			side.owner = root
			var content := VBoxContainer.new()
			content.name = "Content"
			content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.size_flags_vertical = Control.SIZE_EXPAND_FILL
			split.add_child(content)
			content.owner = root
			created = [str(root.get_path_to(split)), str(root.get_path_to(side)), str(root.get_path_to(content))]
		"centered_panel":
			var center := CenterContainer.new()
			center.name = optional_string(params, "name", "Centered")
			center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child_with_undo(parent, center, root, "MCP: centered panel")
			var panel := PanelContainer.new()
			panel.name = "Panel"
			center.add_child(panel)
			panel.owner = root
			created = [str(root.get_path_to(center)), str(root.get_path_to(panel))]
		_:
			return error_invalid_params("Unknown recipe '%s'. Call list_container_recipes." % recipe)
	return success({"recipe": recipe, "created": created})
