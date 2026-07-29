@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scene unique names (%Name) batch + lookup.


func get_commands() -> Dictionary:
	return {
		"batch_set_scene_unique_names": _batch_set_scene_unique_names,
		"find_node_by_unique_name": _find_node_by_unique_name,
		"list_scene_unique_names": _list_scene_unique_names,
		"list_scene_unique_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["set_scene_unique_name", "get_scene_tree", "find_nodes"],
	})


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
		# unique name is the node name in Godot 4 when flag set
		if uname != n.name and optional_bool(item, "rename", false):
			n.name = uname
		results.append({"path": str(root.get_path_to(n)), "ok": true, "unique_name_in_owner": true, "name": n.name})
	mark_current_scene_unsaved()
	return success({"results": results, "count": results.size()})


func _find_node_by_unique_name(params: Dictionary) -> Dictionary:
	var name_r := require_string(params, "unique_name")
	if name_r[1] != null:
		# also accept "name"
		var alt := optional_string(params, "name", "")
		if alt.is_empty():
			return name_r[1]
		name_r = [alt, null]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var n := root.get_node_or_null("%" + name_r[0])
	if n == null:
		# walk
		n = _find_unique(root, name_r[0])
	if n == null:
		return error_not_found("unique name %s" % name_r[0])
	return success({
		"unique_name": name_r[0],
		"node_path": str(root.get_path_to(n)),
		"class": n.get_class(),
	})


func _find_unique(n: Node, uname: String) -> Node:
	if n.unique_name_in_owner and n.name == uname:
		return n
	for c in n.get_children():
		var f := _find_unique(c, uname)
		if f:
			return f
	return null


func _list_scene_unique_names(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var out: Array = []
	_collect_unique(root, root, out)
	return success({"unique_nodes": out, "count": out.size()})


func _collect_unique(n: Node, root: Node, out: Array) -> void:
	if n.unique_name_in_owner:
		out.append({"name": n.name, "path": str(root.get_path_to(n)), "class": n.get_class()})
	for c in n.get_children():
		_collect_unique(c, root, out)
