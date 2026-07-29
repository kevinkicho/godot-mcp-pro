@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Find nodes by class/script/name pattern - agent scene navigation (biggest discovery gain).


func get_commands() -> Dictionary:
	return {
		"find_nodes_by_class": _find_by_class,
		"find_nodes_by_script": _find_by_script,
		"find_nodes_by_name_pattern": _find_by_name,
		"count_nodes_by_class": _count_by_class,
		"reorder_node": _reorder,
		"list_node_query_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["get_scene_tree", "find_nodes_in_group", "select_nodes", "inspect_node"],
	})


func _find_by_class(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var class_name_str: String = optional_string(params, "class_name", optional_string(params, "type", ""))
	if class_name_str.is_empty():
		return error_invalid_params("class_name required e.g. CharacterBody2D")
	var start := find_node_by_path(optional_string(params, "node_path", "."))
	if start == null:
		return error_not_found("Start node")
	var include_internal: bool = optional_bool(params, "include_internal", false)
	var limit: int = optional_int(params, "limit", 200)
	var found: Array = []
	_walk_class(root, start, class_name_str, found, limit, include_internal)
	return success({
		"class_name": class_name_str,
		"nodes": found,
		"count": found.size(),
		"truncated": found.size() >= limit,
	})


func _walk_class(scene_root: Node, node: Node, class_name_str: String, out: Array, limit: int, include_internal: bool) -> void:
	if out.size() >= limit:
		return
	var is_match := false
	if node.get_class() == class_name_str:
		is_match = true
	elif ClassDB.class_exists(class_name_str) and node.is_class(class_name_str):
		is_match = true
	if is_match:
		out.append({
			"node_path": str(scene_root.get_path_to(node)),
			"name": node.name,
			"class": node.get_class(),
		})
	for c in node.get_children():
		if not include_internal and c.name.begins_with("@"):
			continue
		_walk_class(scene_root, c, class_name_str, out, limit, include_internal)


func _find_by_script(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var script_path: String = optional_string(params, "script_path", "")
	if script_path.is_empty():
		return error_invalid_params("script_path required")
	var vr := validate_res_path(script_path)
	if vr[1] == null:
		script_path = vr[0]
	var start := find_node_by_path(optional_string(params, "node_path", "."))
	if start == null:
		return error_not_found("Start")
	var found: Array = []
	_walk_script(root, start, script_path, found, optional_int(params, "limit", 200))
	return success({"script_path": script_path, "nodes": found, "count": found.size()})


func _walk_script(scene_root: Node, node: Node, script_path: String, out: Array, limit: int) -> void:
	if out.size() >= limit:
		return
	var s: Script = node.get_script()
	if s and s.resource_path == script_path:
		out.append({
			"node_path": str(scene_root.get_path_to(node)),
			"name": node.name,
			"class": node.get_class(),
		})
	for c in node.get_children():
		_walk_script(scene_root, c, script_path, out, limit)


func _find_by_name(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var pattern: String = optional_string(params, "pattern", optional_string(params, "name", ""))
	if pattern.is_empty():
		return error_invalid_params("pattern required (substring or * wildcard)")
	var start := find_node_by_path(optional_string(params, "node_path", "."))
	if start == null:
		return error_not_found("Start")
	var found: Array = []
	var limit: int = optional_int(params, "limit", 200)
	_walk_name(root, start, pattern, found, limit, optional_bool(params, "case_sensitive", false))
	return success({"pattern": pattern, "nodes": found, "count": found.size()})


func _match_name(name_str: String, pattern: String, case_sensitive: bool) -> bool:
	var n := name_str if case_sensitive else name_str.to_lower()
	var p := pattern if case_sensitive else pattern.to_lower()
	if p.contains("*"):
		# simple glob: prefix*suffix
		var parts := p.split("*")
		if parts.size() == 1:
			return n == p
		if not n.begins_with(parts[0]):
			return false
		if not n.ends_with(parts[parts.size() - 1]):
			return false
		return true
	return n.contains(p)


func _walk_name(scene_root: Node, node: Node, pattern: String, out: Array, limit: int, case_sensitive: bool) -> void:
	if out.size() >= limit:
		return
	if _match_name(str(node.name), pattern, case_sensitive):
		out.append({
			"node_path": str(scene_root.get_path_to(node)),
			"name": node.name,
			"class": node.get_class(),
		})
	for c in node.get_children():
		_walk_name(scene_root, c, pattern, out, limit, case_sensitive)


func _count_by_class(params: Dictionary) -> Dictionary:
	var r := _find_by_class(params)
	if r.has("error"):
		return r
	var counts: Dictionary = {}
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start := find_node_by_path(optional_string(params, "node_path", "."))
	if start == null:
		return error_not_found("Start")
	_count_walk(start, counts)
	var sorted: Array = []
	for k in counts.keys():
		sorted.append({"class": k, "count": counts[k]})
	sorted.sort_custom(func(a, b): return a["count"] > b["count"])
	return success({"counts": sorted, "total_nodes": _total(counts)})


func _count_walk(node: Node, counts: Dictionary) -> void:
	var cname := node.get_class()
	counts[cname] = int(counts.get(cname, 0)) + 1
	for ch in node.get_children():
		_count_walk(ch, counts)


func _total(counts: Dictionary) -> int:
	var t := 0
	for k in counts:
		t += int(counts[k])
	return t


func _reorder(params: Dictionary) -> Dictionary:
	## move_child to index - Scene dock reorder.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var parent := node.get_parent()
	if parent == null:
		return error_invalid_params("Root cannot be reordered")
	var index: int = optional_int(params, "index", -1)
	if params.has("to_end") and bool(params["to_end"]):
		index = parent.get_child_count() - 1
	if params.has("to_start") and bool(params["to_start"]):
		index = 0
	if index < 0:
		return error_invalid_params("index or to_end/to_start required")
	index = clampi(index, 0, parent.get_child_count() - 1)
	var undo_redo := get_undo_redo()
	var old_index := node.get_index()
	undo_redo.create_action("MCP: Reorder node")
	undo_redo.add_do_method(parent, "move_child", node, index)
	undo_redo.add_undo_method(parent, "move_child", node, old_index)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"old_index": old_index,
		"new_index": node.get_index(),
	})
