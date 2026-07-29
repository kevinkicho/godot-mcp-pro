@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")

## Scene tree node ops (add/move/select).

func get_commands() -> Dictionary:
	return {
		"add_node": _add_node,
		"delete_node": _delete_node,
		"duplicate_node": _duplicate_node,
		"move_node": _move_node,
		"rename_node": _rename_node,
		"set_nodes_transform": _set_nodes_transform,
		"get_editor_selection": _get_editor_selection,
		"select_nodes": _select_nodes,
		"clear_editor_selection": _clear_editor_selection,
	}

func _add_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "type")
	if result[1] != null:
		return result[1]
	var type: String = result[0]

	var parent_path: String = optional_string(params, "parent_path", ".")
	var node_name: String = optional_string(params, "name", "")
	var properties: Dictionary = params.get("properties", {})

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path, "Use get_scene_tree to see available nodes")

	var node: Node
	var custom_script: Script = null

	if ClassDB.class_exists(type):
		node = ClassDB.instantiate(type)
	else:
		# Try to find a script with matching class_name
		custom_script = _find_script_by_class_name(type)
		if custom_script == null:
			return error_invalid_params("Unknown node type: '%s'. Not found in ClassDB or as a script class_name. Use list_scripts to see available script classes." % type)
		var base_type: String = custom_script.get_instance_base_type()
		if not ClassDB.class_exists(base_type):
			return error_invalid_params("Script '%s' extends '%s' which is not a valid node type" % [type, base_type])
		node = ClassDB.instantiate(base_type)
		node.set_script(custom_script)
	if not node_name.is_empty():
		node.name = node_name

	# Apply properties
	for prop_name: String in properties:
		var prop_exists := false
		for prop in node.get_property_list():
			if prop["name"] == prop_name:
				prop_exists = true
				break
		if prop_exists:
			var current: Variant = node.get(prop_name)
			var target_type := typeof(current)
			node.set(prop_name, PropertyParser.parse_value(properties[prop_name], target_type))

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add %s" % type)
	undo_redo.add_do_method(parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": type,
		"name": str(node.name),
	})



func _delete_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if node == root:
		return error_invalid_params("Cannot delete the root node")

	var parent := node.get_parent()
	var node_name := str(node.name)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Delete %s" % node_name)
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(node, "set_owner", root)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()

	return success({"deleted": node_name})



func _duplicate_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var new_name: String = optional_string(params, "name", "")

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if new_name.is_empty():
		new_name = str(node.name) + "_copy"

	var dup := node.duplicate()
	dup.name = new_name
	var parent := node.get_parent()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Duplicate %s" % node.name)
	undo_redo.add_do_method(parent, "add_child", dup)
	undo_redo.add_do_method(dup, "set_owner", root)
	undo_redo.add_do_reference(dup)
	undo_redo.add_undo_method(parent, "remove_child", dup)
	undo_redo.commit_action()

	NodeUtils.set_owner_recursive(dup, root)

	return success({
		"original": str(root.get_path_to(node)),
		"duplicate": str(root.get_path_to(dup)),
		"name": str(dup.name),
	})



func _move_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "new_parent_path")
	if result2[1] != null:
		return result2[1]
	var new_parent_path: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if node == root:
		return error_invalid_params("Cannot move the root node")

	var new_parent := find_node_by_path(new_parent_path)
	if new_parent == null:
		return error_not_found("Target parent '%s'" % new_parent_path, "Use get_scene_tree to see available nodes")

	# Check we're not moving a node into its own subtree
	if new_parent == node or node.is_ancestor_of(new_parent):
		return error_invalid_params("Cannot move a node into its own subtree")

	var old_parent := node.get_parent()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Move %s" % node.name)
	undo_redo.add_do_method(old_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(old_parent, "add_child", node)
	undo_redo.add_undo_method(node, "set_owner", root)
	undo_redo.commit_action()

	NodeUtils.set_owner_recursive(node, root)

	return success({
		"node": str(node.name),
		"old_parent": str(root.get_path_to(old_parent)),
		"new_parent": str(root.get_path_to(new_parent)),
		"new_path": str(root.get_path_to(node)),
	})



func _rename_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "new_name")
	if result2[1] != null:
		return result2[1]
	var new_name: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var old_name: String = node.name
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Rename %s to %s" % [old_name, new_name])
	undo_redo.add_do_property(node, "name", new_name)
	undo_redo.add_undo_property(node, "name", old_name)
	undo_redo.commit_action()

	return success({"old_name": old_name, "new_name": str(node.name), "node_path": str(root.get_path_to(node))})



func _set_nodes_transform(params: Dictionary) -> Dictionary:
	## Numeric multi-node transform (gizmo parity without drag).
	var paths: Array = params.get("node_paths", [])
	if paths.is_empty() and params.has("node_path"):
		paths = [params["node_path"]]
	if paths.is_empty():
		return error_invalid_params("node_paths or node_path required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var changed: Array = []
	for p in paths:
		var node := find_node_by_path(str(p))
		if node == null or not (node is Node2D or node is Node3D):
			changed.append({"path": str(p), "error": "not Node2D/3D"})
			continue
		if node is Node3D:
			var n3: Node3D = node
			if params.has("position"):
				var pos = params["position"]
				if pos is Dictionary:
					n3.position = Vector3(float(pos.get("x", n3.position.x)), float(pos.get("y", n3.position.y)), float(pos.get("z", n3.position.z)))
			if params.has("rotation_degrees"):
				var rot = params["rotation_degrees"]
				if rot is Dictionary:
					n3.rotation_degrees = Vector3(float(rot.get("x", 0)), float(rot.get("y", 0)), float(rot.get("z", 0)))
			if params.has("scale"):
				var sc = params["scale"]
				if sc is Dictionary:
					n3.scale = Vector3(float(sc.get("x", 1)), float(sc.get("y", 1)), float(sc.get("z", 1)))
				elif sc is float or sc is int:
					n3.scale = Vector3.ONE * float(sc)
			if params.has("translate"):
				var tr = params["translate"]
				if tr is Dictionary:
					n3.position += Vector3(float(tr.get("x", 0)), float(tr.get("y", 0)), float(tr.get("z", 0)))
			changed.append({"path": str(root.get_path_to(n3)), "position": {"x": n3.position.x, "y": n3.position.y, "z": n3.position.z}})
		elif node is Node2D:
			var n2: Node2D = node
			if params.has("position"):
				var pos2 = params["position"]
				if pos2 is Dictionary:
					n2.position = Vector2(float(pos2.get("x", n2.position.x)), float(pos2.get("y", n2.position.y)))
			if params.has("rotation_degrees"):
				n2.rotation_degrees = float(params["rotation_degrees"]) if not (params["rotation_degrees"] is Dictionary) else float(params["rotation_degrees"].get("z", 0))
			if params.has("scale"):
				var sc2 = params["scale"]
				if sc2 is Dictionary:
					n2.scale = Vector2(float(sc2.get("x", 1)), float(sc2.get("y", 1)))
				else:
					n2.scale = Vector2.ONE * float(sc2)
			if params.has("translate"):
				var tr2 = params["translate"]
				if tr2 is Dictionary:
					n2.position += Vector2(float(tr2.get("x", 0)), float(tr2.get("y", 0)))
			changed.append({"path": str(root.get_path_to(n2)), "position": {"x": n2.position.x, "y": n2.position.y}})
	mark_current_scene_unsaved()
	return success({"changed": changed, "count": changed.size()})



func _get_editor_selection(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var selection := EditorInterface.get_selection()
	var include_top_only: bool = optional_bool(params, "top_only", false)
	var selected_nodes: Array = selection.get_top_selected_nodes() if include_top_only else selection.get_selected_nodes()

	return success({
		"nodes": _serialize_selection_nodes(root, selected_nodes),
		"count": selected_nodes.size(),
		"top_only": include_top_only,
	})



func _select_nodes(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node_paths_result := _get_selection_node_paths(params)
	if node_paths_result[1] != null:
		return node_paths_result[1]
	var node_paths: Array = node_paths_result[0]

	var mode: String = optional_string(params, "mode", "replace")
	if mode != "replace" and mode != "add" and mode != "remove":
		return error_invalid_params("mode must be one of: replace, add, remove")

	var inspect: bool = optional_bool(params, "inspect", true)
	var focus: bool = optional_bool(params, "focus", inspect)
	var inspector_only: bool = optional_bool(params, "inspector_only", false)
	var for_property: String = optional_string(params, "for_property", "")

	var resolved_nodes: Array[Node] = []
	for node_path_variant: Variant in node_paths:
		var node_path := str(node_path_variant)
		if node_path.is_empty():
			return error_invalid_params("node_paths cannot contain empty values")
		var node := find_node_by_path(node_path)
		if node == null:
			return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")
		resolved_nodes.append(node)

	var selection := EditorInterface.get_selection()
	if mode == "replace":
		selection.clear()

	for node: Node in resolved_nodes:
		if mode == "remove":
			selection.remove_node(node)
		else:
			selection.add_node(node)

	# edit_node() and inspect_object() both reset EditorSelection to a single
	# node, which would collapse a multi-node selection down to the last node.
	# Only focus/inspect when exactly one node was selected.
	if mode != "remove" and resolved_nodes.size() == 1:
		var edited_node: Node = resolved_nodes[0]
		if focus:
			EditorInterface.edit_node(edited_node)
		if inspect:
			EditorInterface.inspect_object(edited_node, for_property, inspector_only)

	var selected_nodes: Array = selection.get_selected_nodes()
	return success({
		"mode": mode,
		"selected": _serialize_selection_nodes(root, selected_nodes),
		"count": selected_nodes.size(),
	})



func _clear_editor_selection(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var selection := EditorInterface.get_selection()
	var before_count := selection.get_selected_nodes().size()
	selection.clear()

	return success({
		"cleared": before_count,
		"selected": [],
		"count": 0,
	})



func _get_selection_node_paths(params: Dictionary) -> Array:
	if params.has("node_paths"):
		if not params["node_paths"] is Array:
			return [[], error_invalid_params("node_paths must be an array of node paths")]
		return [params["node_paths"], null]

	var result := require_string(params, "node_path")
	if result[1] != null:
		return [[], result[1]]
	return [[result[0]], null]



func _serialize_selection_nodes(root: Node, nodes: Array) -> Array:
	var serialized: Array = []
	for node: Node in nodes:
		if node == null:
			continue
		if node != root and not root.is_ancestor_of(node):
			continue
		serialized.append({
			"name": node.name,
			"path": str(root.get_path_to(node)) if node != root else ".",
			"type": node.get_class(),
		})
	return serialized



