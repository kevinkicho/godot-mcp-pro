@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scene unique names — scripting/scene_unique_nodes.rst


func get_commands() -> Dictionary:
	return {
		"set_scene_unique_name": _set_scene_unique_name,
		"get_scene_unique_name": _get_scene_unique_name,
		"find_node_by_unique_name": _find_node_by_unique_name,
		"list_scene_unique_names": _list_scene_unique_names,
		"batch_set_scene_unique_names": _batch_set_scene_unique_names,
		"list_scene_unique_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload(["get_scene_tree", "find_nodes_by_class", "set_scene_unique_name"])


func _batch_set_scene_unique_names(params: Dictionary) -> Dictionary:
	## items: [{node_path, unique_name?}] — default unique_name = node name
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("items array required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var results: Array = []
	for item in params["items"]:
		if not item is Dictionary:
			continue
		var np := str(item.get("node_path", item.get("path", "")))
		var n := find_node_by_path(np)
		if n == null:
			results.append({"path": np, "ok": false})
			continue
		var uname: String = str(item.get("unique_name", n.name))
		n.unique_name_in_owner = true
		if uname != n.name and optional_bool(item, "rename", false):
			n.name = uname
		results.append({
			"path": str(root.get_path_to(n)),
			"ok": true,
			"unique_name_in_owner": true,
			"name": n.name,
		})
	mark_current_scene_unsaved()
	return success({"results": results, "count": results.size()})



func _set_scene_unique_name(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var enabled: bool = optional_bool(params, "enabled", true)
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var old: bool = node.unique_name_in_owner
	var undo := get_undo_redo()
	undo.create_action("MCP: Set unique name")
	undo.add_do_property(node, "unique_name_in_owner", enabled)
	undo.add_undo_property(node, "unique_name_in_owner", old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"unique_name_in_owner": node.unique_name_in_owner,
		"access_as": ("%%%s" % node.name) if node.unique_name_in_owner else "",
	})


func _get_scene_unique_name(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	return success({
		"node_path": str(root.get_path_to(node)),
		"unique_name_in_owner": node.unique_name_in_owner,
		"name": node.name,
	})


func _find_node_by_unique_name(params: Dictionary) -> Dictionary:
	var uname: String = optional_string(params, "name", optional_string(params, "unique_name", "")).trim_prefix("%")
	if uname.is_empty():
		return error_invalid_params("name or unique_name required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := root.get_node_or_null("%" + uname)
	if node == null:
		node = _find_unique_walk(root, uname)
	if node == null:
		return error_not_found("Unique node '%%%s'" % uname)
	return success({
		"name": uname,
		"unique_name": uname,
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"class": node.get_class(),
	})


func _find_unique_walk(n: Node, uname: String) -> Node:
	if n.unique_name_in_owner and n.name == uname:
		return n
	for c in n.get_children():
		var f := _find_unique_walk(c, uname)
		if f:
			return f
	return null


func _list_scene_unique_names(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var found: Array = []
	_collect_unique(root, root, found)
	return success({"unique_nodes": found, "count": found.size()})


func _collect_unique(node: Node, root: Node, out: Array) -> void:
	if node.unique_name_in_owner:
		out.append({
			"name": node.name,
			"path": str(root.get_path_to(node)),
			"access": "%%%s" % node.name,
			"type": node.get_class(),
		})
	for ch in node.get_children():
		_collect_unique(ch, root, out)
