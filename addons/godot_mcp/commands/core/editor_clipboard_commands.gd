@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Clipboard + node duplicate helpers for agent dock parity.


func get_commands() -> Dictionary:
	return {
		"clipboard_set_text": _clipboard_set_text,
		"clipboard_get_text": _clipboard_get_text,
		"duplicate_nodes": _duplicate_nodes,
		"copy_node_path_to_clipboard": _copy_node_path_to_clipboard,
		"list_editor_clipboard_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["duplicate_node", "select_nodes", "get_editor_selection"],
	})


func _clipboard_set_text(params: Dictionary) -> Dictionary:
	var text_r := require_string(params, "text")
	if text_r[1] != null:
		return text_r[1]
	DisplayServer.clipboard_set(text_r[0])
	return success({"set": true, "length": text_r[0].length()})


func _clipboard_get_text(_params: Dictionary) -> Dictionary:
	var t := DisplayServer.clipboard_get()
	return success({"text": t, "length": t.length()})


func _duplicate_nodes(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var paths: Array = params.get("node_paths", [])
	if paths.is_empty() and params.has("node_path"):
		paths = [params["node_path"]]
	if paths.is_empty():
		# selection
		var sel := EditorInterface.get_selection().get_selected_nodes()
		for n in sel:
			paths.append(str(root.get_path_to(n)))
	if paths.is_empty():
		return error_invalid_params("node_paths or selection required")
	var created: Array = []
	for p in paths:
		var n := find_node_by_path(str(p))
		if n == null or n.get_parent() == null:
			continue
		var dup: Node = n.duplicate()
		dup.name = n.name + optional_string(params, "suffix", "_dup")
		add_child_with_undo(n.get_parent(), dup, root, "MCP: Duplicate node")
		if params.has("offset") and dup is Node3D:
			var o = params["offset"]
			if o is Dictionary:
				(dup as Node3D).position += Vector3(float(o.get("x", 1)), float(o.get("y", 0)), float(o.get("z", 0)))
		elif params.has("offset") and dup is Node2D:
			var o2 = params["offset"]
			if o2 is Dictionary:
				(dup as Node2D).position += Vector2(float(o2.get("x", 16)), float(o2.get("y", 0)))
		created.append(str(root.get_path_to(dup)))
	mark_current_scene_unsaved()
	return success({"duplicated": created, "count": created.size()})


func _copy_node_path_to_clipboard(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	var n := find_node_by_path(r0[0])
	if n == null:
		return error_not_found("Node")
	var path_str := str(root.get_path_to(n)) if root else r0[0]
	if optional_bool(params, "absolute", false) and root:
		path_str = str(n.get_path())
	DisplayServer.clipboard_set(path_str)
	return success({"clipboard": path_str})
