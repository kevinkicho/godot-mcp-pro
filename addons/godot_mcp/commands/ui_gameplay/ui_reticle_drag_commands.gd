@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Reticle / crosshair, drag-drop UI, control focus - agent HUD interaction map.


func get_commands() -> Dictionary:
	return {
		"setup_reticle_ui": _setup_reticle,
		"setup_crosshair_ui": _setup_crosshair,
		"create_drag_drop_slot_script": _create_drag_slot,
		"setup_drag_drop_inventory_row": _setup_drag_row,
		"set_control_focus_neighbors": _focus_neighbors,
		"grab_control_focus": _grab_focus,
		"list_ui_reticle_drag_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_hud", "setup_hotbar_ui", "setup_inventory_ui", "setup_first_person_camera",
		"set_control_tooltip", "setup_button",
	])


func _setup_reticle(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "ReticleLayer")
	layer.layer = optional_int(params, "layer", 30)
	add_child_with_undo(parent, layer, root, "MCP: Reticle")
	var center := Control.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child_with_undo(layer, center, root, "MCP: center")
	var style: String = optional_string(params, "style", "cross")
	var size_f := float(params.get("size", 12))
	var color := Color(1, 1, 1, 0.9)
	if params.has("color"):
		var c = params["color"]
		if c is String:
			color = Color.html(c) if str(c).begins_with("#") else Color(str(c))
	if style == "dot":
		var dot := ColorRect.new()
		dot.name = "Dot"
		dot.color = color
		dot.size = Vector2(size_f, size_f)
		dot.position = Vector2(-size_f * 0.5, -size_f * 0.5)
		dot.set_anchors_preset(Control.PRESET_CENTER)
		add_child_with_undo(center, dot, root, "MCP: dot")
	else:
		for axis in [["H", Vector2(size_f * 2, 2), Vector2(-size_f, -1)], ["V", Vector2(2, size_f * 2), Vector2(-1, -size_f)]]:
			var r := ColorRect.new()
			r.name = str(axis[0])
			r.color = color
			r.size = axis[1]
			r.position = axis[2]
			r.set_anchors_preset(Control.PRESET_CENTER)
			add_child_with_undo(center, r, root, "MCP: reticle arm")
	mark_current_scene_unsaved()
	return success({"layer_path": str(root.get_path_to(layer)), "style": style})


func _setup_crosshair(params: Dictionary) -> Dictionary:
	var p := params.duplicate()
	p["style"] = optional_string(params, "style", "cross")
	return _setup_reticle(p)


func _create_drag_slot(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/drag_drop_slot.gd")
	var content := """extends PanelContainer
class_name DragDropSlot
## Simple inventory-style drag source + drop target.

signal dropped(from_slot: Node, to_slot: Node, payload: Variant)

@export var slot_id: String = \"\"
@export var payload: Variant
@export var draggable: bool = true
@export var droppable: bool = true

func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable or payload == null:
		return null
	var preview := Label.new()
	preview.text = str(payload)
	set_drag_preview(preview)
	return {\"from\": self, \"payload\": payload, \"slot_id\": slot_id}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return droppable and data is Dictionary and data.has(\"payload\")

func _drop_data(_at: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var from: Node = data.get(\"from\")
	var pl: Variant = data.get(\"payload\")
	if from and from != self and from.has_method(\"set\") and \"payload\" in from:
		var swap = payload
		payload = pl
		from.set(\"payload\", swap)
	else:
		payload = pl
	dropped.emit(from, self, payload)
	queue_redraw()
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "DragDropSlot"})


func _setup_drag_row(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var script_path: String = optional_string(params, "script_path", "res://scripts/drag_drop_slot.gd")
	if not FileAccess.file_exists(script_path):
		_create_drag_slot({"path": script_path, "overwrite": false})
	var row := HBoxContainer.new()
	row.name = optional_string(params, "name", "DragDropRow")
	add_child_with_undo(parent, row, root, "MCP: drag row")
	var n := optional_int(params, "slots", 5)
	var scr: Script = load(script_path)
	var created: Array = []
	for i in n:
		var slot := PanelContainer.new()
		slot.name = "Slot%d" % i
		slot.custom_minimum_size = Vector2(64, 64)
		if scr:
			slot.set_script(scr)
			if "slot_id" in slot:
				slot.set("slot_id", "slot_%d" % i)
		add_child_with_undo(row, slot, root, "MCP: drag slot")
		created.append(str(root.get_path_to(slot)))
	mark_current_scene_unsaved()
	return success({"row_path": str(root.get_path_to(row)), "slots": created})


func _focus_neighbors(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var ctrl := find_node_by_path(r0[0])
	if ctrl == null or not (ctrl is Control):
		return error_not_found("Control")
	var c := ctrl as Control
	var applied := {}
	for key in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom",
			"focus_next", "focus_previous"]:
		var short_key := key.replace("focus_neighbor_", "").replace("focus_", "")
		if params.has(key):
			c.set(key, NodePath(str(params[key])))
			applied[key] = str(params[key])
		elif params.has(short_key):
			c.set(key if key.begins_with("focus_neighbor") else key, NodePath(str(params[short_key])))
			applied[key] = str(params[short_key])
	if params.has("left"):
		c.focus_neighbor_left = NodePath(str(params["left"]))
		applied["left"] = str(params["left"])
	if params.has("right"):
		c.focus_neighbor_right = NodePath(str(params["right"]))
		applied["right"] = str(params["right"])
	if params.has("top") or params.has("up"):
		c.focus_neighbor_top = NodePath(str(params.get("top", params.get("up"))))
		applied["top"] = str(params.get("top", params.get("up")))
	if params.has("bottom") or params.has("down"):
		c.focus_neighbor_bottom = NodePath(str(params.get("bottom", params.get("down"))))
		applied["bottom"] = str(params.get("bottom", params.get("down")))
	if applied.is_empty():
		return error_invalid_params("Provide left/right/top/bottom neighbor paths")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "neighbors": applied})


func _grab_focus(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var ctrl := find_node_by_path(r0[0])
	if ctrl == null or not (ctrl is Control):
		return error_not_found("Control")
	(ctrl as Control).grab_focus()
	return success({"node_path": r0[0], "focused": true})
