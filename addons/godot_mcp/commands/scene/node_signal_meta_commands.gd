@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")

## Signals, meta, and groups on nodes.

func get_commands() -> Dictionary:
	return {
		"connect_signal": _connect_signal,
		"disconnect_signal": _disconnect_signal,
		"get_node_groups": _get_node_groups,
		"set_node_groups": _set_node_groups,
		"find_nodes_in_group": _find_nodes_in_group,
		"get_meta": _get_meta,
		"set_meta": _set_meta,
		"remove_meta": _remove_meta,
		"list_meta": _list_meta,
	}

func _connect_signal(params: Dictionary) -> Dictionary:
	var result := require_string(params, "source_path")
	if result[1] != null:
		return result[1]
	var source_path: String = result[0]

	var result2 := require_string(params, "signal_name")
	if result2[1] != null:
		return result2[1]
	var signal_name: String = result2[0]

	var result3 := require_string(params, "target_path")
	if result3[1] != null:
		return result3[1]
	var target_path: String = result3[0]

	var result4 := require_string(params, "method_name")
	if result4[1] != null:
		return result4[1]
	var method_name: String = result4[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var source := find_node_by_path(source_path)
	if source == null:
		return error_not_found("Source node '%s'" % source_path)

	var target := find_node_by_path(target_path)
	if target == null:
		return error_not_found("Target node '%s'" % target_path)

	if not source.has_signal(signal_name):
		return error_invalid_params("Signal '%s' not found on %s" % [signal_name, source.get_class()])

	if source.is_connected(signal_name, Callable(target, method_name)):
		return success({"already_connected": true, "signal": signal_name})

	# CONNECT_PERSIST is required for PackedScene.pack() to serialize the
	# connection into the .tscn  -  without it the connection is editor-memory only.
	var flags: int = Object.CONNECT_PERSIST
	if optional_bool(params, "deferred", false):
		flags |= Object.CONNECT_DEFERRED
	if optional_bool(params, "one_shot", false):
		flags |= Object.CONNECT_ONE_SHOT

	var callable := Callable(target, method_name)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Connect signal")
	undo_redo.add_do_method(source, "connect", signal_name, callable, flags)
	undo_redo.add_undo_method(source, "disconnect", signal_name, callable)
	undo_redo.commit_action()

	return success({
		"source": str(root.get_path_to(source)),
		"signal": signal_name,
		"target": str(root.get_path_to(target)),
		"method": method_name,
		"connected": true,
		"flags": flags,
		"persistent": true,
	})



func _disconnect_signal(params: Dictionary) -> Dictionary:
	var result := require_string(params, "source_path")
	if result[1] != null:
		return result[1]
	var source_path: String = result[0]

	var result2 := require_string(params, "signal_name")
	if result2[1] != null:
		return result2[1]
	var signal_name: String = result2[0]

	var result3 := require_string(params, "target_path")
	if result3[1] != null:
		return result3[1]
	var target_path: String = result3[0]

	var result4 := require_string(params, "method_name")
	if result4[1] != null:
		return result4[1]
	var method_name: String = result4[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var source := find_node_by_path(source_path)
	if source == null:
		return error_not_found("Source node '%s'" % source_path)

	var target := find_node_by_path(target_path)
	if target == null:
		return error_not_found("Target node '%s'" % target_path)

	if not source.is_connected(signal_name, Callable(target, method_name)):
		return success({"was_connected": false})

	var callable := Callable(target, method_name)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Disconnect signal")
	undo_redo.add_do_method(source, "disconnect", signal_name, callable)
	undo_redo.add_undo_method(source, "connect", signal_name, callable)
	undo_redo.commit_action()

	return success({
		"source": str(root.get_path_to(source)),
		"signal": signal_name,
		"target": str(root.get_path_to(target)),
		"method": method_name,
		"disconnected": true,
	})



func _get_node_groups(params: Dictionary) -> Dictionary:
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

	var groups: Array = []
	for group: StringName in node.get_groups():
		var g := str(group)
		# Filter out internal groups (start with _)
		if not g.begins_with("_"):
			groups.append(g)

	return success({
		"node_path": str(root.get_path_to(node)),
		"groups": groups,
		"count": groups.size(),
	})



func _set_node_groups(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	if not params.has("groups") or not params["groups"] is Array:
		return error_invalid_params("'groups' array is required")
	var desired_groups: Array = params["groups"]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	# Get current non-internal groups
	var current_groups: Array = []
	for group: StringName in node.get_groups():
		var g := str(group)
		if not g.begins_with("_"):
			current_groups.append(g)

	var added: Array = []
	var removed: Array = []

	for group: String in current_groups:
		if group not in desired_groups:
			removed.append(group)

	for group in desired_groups:
		var g: String = str(group)
		if g not in current_groups:
			added.append(g)

	if not added.is_empty() or not removed.is_empty():
		var undo_redo := get_undo_redo()
		undo_redo.create_action("MCP: Set node groups")
		for group: String in removed:
			undo_redo.add_do_method(node, "remove_from_group", group)
			undo_redo.add_undo_method(node, "add_to_group", group, true)
		for group: String in added:
			undo_redo.add_do_method(node, "add_to_group", group, true)
			undo_redo.add_undo_method(node, "remove_from_group", group)
		undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"groups": desired_groups,
		"added": added,
		"removed": removed,
	})



func _find_nodes_in_group(params: Dictionary) -> Dictionary:
	var result := require_string(params, "group")
	if result[1] != null:
		return result[1]
	var group_name: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var matches: Array = []
	_find_in_group_recursive(root, root, group_name, matches)

	return success({
		"group": group_name,
		"nodes": matches,
		"count": matches.size(),
	})



func _find_in_group_recursive(node: Node, root: Node, group_name: String, matches: Array) -> void:
	if node.is_in_group(group_name):
		matches.append({
			"name": node.name,
			"path": str(root.get_path_to(node)),
			"type": node.get_class(),
		})
	for child in node.get_children():
		_find_in_group_recursive(child, root, group_name, matches)



func _get_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "key")
	if result2[1] != null:
		return result2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var key: String = result2[0]
	if not node.has_meta(key):
		return error_not_found("Meta key '%s'" % key)
	return success({
		"node_path": str(root.get_path_to(node)),
		"key": key,
		"value": PropertyParser.serialize_value(node.get_meta(key)),
	})



func _set_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "key")
	if result2[1] != null:
		return result2[1]
	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var key: String = result2[0]
	var value: Variant = PropertyParser.parse_value(params["value"])
	var old = node.get_meta(key) if node.has_meta(key) else null
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set meta %s" % key)
	undo_redo.add_do_method(node, "set_meta", key, value)
	if old != null:
		undo_redo.add_undo_method(node, "set_meta", key, old)
	else:
		undo_redo.add_undo_method(node, "remove_meta", key)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"key": key,
		"value": PropertyParser.serialize_value(node.get_meta(key)),
	})



func _remove_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "key")
	if result2[1] != null:
		return result2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var key: String = result2[0]
	if not node.has_meta(key):
		return error_not_found("Meta key '%s'" % key)
	var old = node.get_meta(key)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Remove meta %s" % key)
	undo_redo.add_do_method(node, "remove_meta", key)
	undo_redo.add_undo_method(node, "set_meta", key, old)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "key": key, "removed": true})



func _list_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var meta: Dictionary = {}
	for k in node.get_meta_list():
		meta[str(k)] = PropertyParser.serialize_value(node.get_meta(k))
	return success({
		"node_path": str(root.get_path_to(node)),
		"meta": meta,
		"count": meta.size(),
	})



