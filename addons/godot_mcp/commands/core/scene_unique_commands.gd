@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scene unique names — scripting/scene_unique_nodes.rst


func get_commands() -> Dictionary:
	return {
		"set_scene_unique_name": _set_scene_unique_name,
		"get_scene_unique_name": _get_scene_unique_name,
		"find_node_by_unique_name": _find_node_by_unique_name,
		"list_scene_unique_names": _list_scene_unique_names,
	}


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
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var uname: String = result[0].trim_prefix("%")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := root.get_node_or_null("%" + uname)
	if node == null:
		return error_not_found("Unique node '%%%s'" % uname)
	return success({
		"name": uname,
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
	})


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
