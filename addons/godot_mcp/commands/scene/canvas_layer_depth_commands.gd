@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## CanvasLayer depth - ordering, follow viewport, custom viewport, stack recipes.


func get_commands() -> Dictionary:
	return {
		"set_canvas_layer_order": _set_layer_order,
		"set_canvas_layer_follow_viewport": _set_follow,
		"set_canvas_layer_custom_viewport": _set_custom_viewport,
		"list_canvas_layers": _list_layers,
		"setup_canvas_layer_stack": _setup_stack,
		"reorder_canvas_layers": _reorder_layers,
		"list_canvas_layer_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_canvas_layer", "setup_hud", "setup_subviewport_2d_world",
		"setup_viewport_texture_rect", "set_canvas_item_visibility",
	])


func _as_canvas_layer(node: Node) -> CanvasLayer:
	if node is CanvasLayer:
		return node as CanvasLayer
	return null


func _set_layer_order(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("layer"):
		return error_invalid_params("layer int required (higher draws on top)")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var cl := _as_canvas_layer(find_node_by_path(r0[0]))
	if cl == null:
		return error_invalid_params("Node is not CanvasLayer")
	var old := cl.layer
	var layer := int(params["layer"])
	var undo := get_undo_redo()
	undo.create_action("MCP: CanvasLayer.layer")
	undo.add_do_property(cl, "layer", layer)
	undo.add_undo_property(cl, "layer", old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(cl)), "layer": cl.layer, "old": old})


func _set_follow(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var cl := _as_canvas_layer(find_node_by_path(r0[0]))
	if cl == null:
		return error_invalid_params("Node is not CanvasLayer")
	var enabled := optional_bool(params, "enabled", true)
	var scale: float = float(params.get("scale", cl.follow_viewport_scale if "follow_viewport_scale" in cl else 1.0))
	cl.follow_viewport_enabled = enabled
	if "follow_viewport_scale" in cl:
		cl.follow_viewport_scale = scale
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(cl)),
		"follow_viewport_enabled": cl.follow_viewport_enabled,
		"follow_viewport_scale": cl.follow_viewport_scale if "follow_viewport_scale" in cl else null,
	})


func _set_custom_viewport(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var cl := _as_canvas_layer(find_node_by_path(r0[0]))
	if cl == null:
		return error_invalid_params("Node is not CanvasLayer")
	var vp_path: String = optional_string(params, "viewport_path", "")
	if vp_path.is_empty() or vp_path == "null" or vp_path == "default":
		cl.custom_viewport = null
		mark_current_scene_unsaved()
		return success({"node_path": str(root.get_path_to(cl)), "custom_viewport": null})
	var vp_node := find_node_by_path(vp_path)
	if vp_node == null:
		return error_not_found("Viewport node")
	if not (vp_node is Viewport):
		return error_invalid_params("viewport_path must be a Viewport/SubViewport")
	cl.custom_viewport = vp_node as Viewport
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(cl)),
		"custom_viewport": str(root.get_path_to(vp_node)),
	})


func _collect_layers(n: Node, root: Node, out: Array) -> void:
	if n is CanvasLayer:
		var cl := n as CanvasLayer
		out.append({
			"path": str(root.get_path_to(cl)),
			"name": cl.name,
			"layer": cl.layer,
			"visible": cl.visible,
			"follow_viewport_enabled": cl.follow_viewport_enabled,
			"custom_viewport": str(root.get_path_to(cl.custom_viewport)) if cl.custom_viewport else null,
		})
	for c in n.get_children():
		_collect_layers(c, root, out)


func _list_layers(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start := find_node_by_path(optional_string(params, "node_path", "."))
	if start == null:
		return error_not_found("Start node")
	var layers: Array = []
	_collect_layers(start, root, layers)
	layers.sort_custom(func(a, b): return int(a.get("layer", 0)) < int(b.get("layer", 0)))
	return success({"layers": layers, "count": layers.size()})


func _setup_stack(params: Dictionary) -> Dictionary:
	## layers: [{name, layer, follow_viewport?}] under parent_path
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var specs: Array = params.get("layers", [])
	if specs.is_empty():
		# Sensible HUD stack defaults
		specs = [
			{"name": "WorldLayer", "layer": 0},
			{"name": "HudLayer", "layer": 10},
			{"name": "PopupLayer", "layer": 20},
			{"name": "OverlayLayer", "layer": 100},
		]
	var created: Array = []
	for spec in specs:
		if not spec is Dictionary:
			continue
		var cl := CanvasLayer.new()
		cl.name = str(spec.get("name", "CanvasLayer"))
		cl.layer = int(spec.get("layer", 0))
		if spec.has("follow_viewport"):
			cl.follow_viewport_enabled = bool(spec["follow_viewport"])
		if spec.has("visible"):
			cl.visible = bool(spec["visible"])
		add_child_with_undo(parent, cl, root, "MCP: CanvasLayer stack")
		created.append({"path": str(root.get_path_to(cl)), "layer": cl.layer, "name": cl.name})
	mark_current_scene_unsaved()
	return success({"created": created, "count": created.size()})


func _reorder_layers(params: Dictionary) -> Dictionary:
	## order: [{node_path, layer}] or paths:[] assigned sequential from base_layer
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var updated: Array = []
	if params.has("order") and params["order"] is Array:
		for item in params["order"]:
			if not item is Dictionary:
				continue
			var cl := _as_canvas_layer(find_node_by_path(str(item.get("node_path", ""))))
			if cl == null:
				continue
			cl.layer = int(item.get("layer", cl.layer))
			updated.append({"path": str(root.get_path_to(cl)), "layer": cl.layer})
	elif params.has("paths") and params["paths"] is Array:
		var base := optional_int(params, "base_layer", 0)
		var step := optional_int(params, "step", 10)
		var i := 0
		for p in params["paths"]:
			var cl := _as_canvas_layer(find_node_by_path(str(p)))
			if cl == null:
				continue
			cl.layer = base + i * step
			updated.append({"path": str(root.get_path_to(cl)), "layer": cl.layer})
			i += 1
	else:
		return error_invalid_params("order array or paths array required")
	mark_current_scene_unsaved()
	return success({"updated": updated, "count": updated.size()})
