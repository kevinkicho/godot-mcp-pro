@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Node process mode / priority / call_group - editor-side setup agents need often.


func get_commands() -> Dictionary:
	return {
		"set_process_mode": _set_process_mode,
		"batch_set_process_mode": _batch_set_process_mode,
		"set_process_priority": _set_process_priority,
		"set_physics_process_priority": _set_physics_process_priority,
		"get_node_process_info": _get_process_info,
		"call_group_in_scene": _call_group,
		"list_node_process_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"set_node_groups", "find_nodes_in_group", "update_property",
		"create_game_flow_controller_script", "setup_pause_menu",
	], {
		"process_mode_values": [
			"PROCESS_MODE_INHERIT", "PROCESS_MODE_PAUSABLE", "PROCESS_MODE_WHEN_PAUSED",
			"PROCESS_MODE_ALWAYS", "PROCESS_MODE_DISABLED",
		],
	})


func _parse_process_mode(v: Variant) -> int:
	if v is int:
		return int(v)
	var s := str(v).strip_edges().to_upper()
	var map := {
		"INHERIT": Node.PROCESS_MODE_INHERIT,
		"PROCESS_MODE_INHERIT": Node.PROCESS_MODE_INHERIT,
		"PAUSABLE": Node.PROCESS_MODE_PAUSABLE,
		"PROCESS_MODE_PAUSABLE": Node.PROCESS_MODE_PAUSABLE,
		"WHEN_PAUSED": Node.PROCESS_MODE_WHEN_PAUSED,
		"PROCESS_MODE_WHEN_PAUSED": Node.PROCESS_MODE_WHEN_PAUSED,
		"ALWAYS": Node.PROCESS_MODE_ALWAYS,
		"PROCESS_MODE_ALWAYS": Node.PROCESS_MODE_ALWAYS,
		"DISABLED": Node.PROCESS_MODE_DISABLED,
		"PROCESS_MODE_DISABLED": Node.PROCESS_MODE_DISABLED,
	}
	if s in map:
		return map[s]
	if s.is_valid_int():
		return int(s)
	return -1


func _mode_name(mode: int) -> String:
	match mode:
		Node.PROCESS_MODE_INHERIT:
			return "PROCESS_MODE_INHERIT"
		Node.PROCESS_MODE_PAUSABLE:
			return "PROCESS_MODE_PAUSABLE"
		Node.PROCESS_MODE_WHEN_PAUSED:
			return "PROCESS_MODE_WHEN_PAUSED"
		Node.PROCESS_MODE_ALWAYS:
			return "PROCESS_MODE_ALWAYS"
		Node.PROCESS_MODE_DISABLED:
			return "PROCESS_MODE_DISABLED"
		_:
			return str(mode)


func _set_process_mode(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("mode") and not params.has("process_mode"):
		return error_invalid_params("mode or process_mode required (e.g. PROCESS_MODE_ALWAYS)")
	var mode := _parse_process_mode(params.get("mode", params.get("process_mode")))
	if mode < 0:
		return error_invalid_params("Unknown process_mode: %s" % str(params.get("mode", params.get("process_mode"))))
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node '%s'" % r0[0])
	var old := node.process_mode
	var undo := get_undo_redo()
	undo.create_action("MCP: Set process_mode")
	undo.add_do_property(node, "process_mode", mode)
	undo.add_undo_property(node, "process_mode", old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"process_mode": mode,
		"process_mode_name": _mode_name(mode),
		"old": old,
		"old_name": _mode_name(old),
	})


func _batch_set_process_mode(params: Dictionary) -> Dictionary:
	## items: [{node_path, mode}] OR node_paths:[] + mode
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var results: Array = []
	if params.has("items") and params["items"] is Array:
		for item in params["items"]:
			if not item is Dictionary:
				continue
			var sub := _set_process_mode(item)
			if sub.has("error"):
				results.append({"ok": false, "error": sub["error"], "node_path": item.get("node_path", "")})
			else:
				results.append({"ok": true, "result": sub.get("result", {})})
	elif params.has("node_paths") and params["node_paths"] is Array:
		var mode_v = params.get("mode", params.get("process_mode"))
		for np in params["node_paths"]:
			var sub := _set_process_mode({"node_path": str(np), "mode": mode_v})
			if sub.has("error"):
				results.append({"ok": false, "error": sub["error"], "node_path": str(np)})
			else:
				results.append({"ok": true, "result": sub.get("result", {})})
	else:
		return error_invalid_params("items array or node_paths+mode required")
	return success({"results": results, "count": results.size()})


func _set_process_priority(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("priority"):
		return error_invalid_params("priority int required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var prio := int(params["priority"])
	var old := node.process_priority
	var undo := get_undo_redo()
	undo.create_action("MCP: process_priority")
	undo.add_do_property(node, "process_priority", prio)
	undo.add_undo_property(node, "process_priority", old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "process_priority": prio, "old": old})


func _set_physics_process_priority(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("priority"):
		return error_invalid_params("priority int required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var prio := int(params["priority"])
	var old := node.physics_process_priority
	var undo := get_undo_redo()
	undo.create_action("MCP: physics_process_priority")
	undo.add_do_property(node, "physics_process_priority", prio)
	undo.add_undo_property(node, "physics_process_priority", old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"physics_process_priority": prio,
		"old": old,
	})


func _get_process_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	return success({
		"node_path": str(root.get_path_to(node)),
		"process_mode": node.process_mode,
		"process_mode_name": _mode_name(node.process_mode),
		"process_priority": node.process_priority,
		"physics_process_priority": node.physics_process_priority,
		"process_thread_group": node.process_thread_group if "process_thread_group" in node else null,
	})


func _call_group(params: Dictionary) -> Dictionary:
	## Editor-tree call_group (not running game). Useful for setup scripts attached to nodes.
	var r0 := require_string(params, "group")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "method")
	if r1[1] != null:
		return r1[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var args: Array = params.get("args", [])
	if not args is Array:
		args = []
	var tree := root.get_tree()
	if tree == null:
		return error_internal("No SceneTree on edited root")
	var nodes := tree.get_nodes_in_group(r0[0])
	var called: Array = []
	var skipped: Array = []
	for n in nodes:
		if n == null or not is_instance_valid(n):
			continue
		# Prefer nodes under edited scene
		if not root.is_ancestor_of(n) and n != root:
			continue
		if not n.has_method(r1[0]):
			skipped.append({"path": str(root.get_path_to(n)) if root.is_ancestor_of(n) or n == root else str(n.name), "reason": "no_method"})
			continue
		var ret: Variant = n.callv(r1[0], args)
		called.append({
			"path": str(root.get_path_to(n)) if (root.is_ancestor_of(n) or n == root) else str(n.name),
			"return": str(ret) if ret != null else null,
		})
	return success({
		"group": r0[0],
		"method": r1[0],
		"called_count": called.size(),
		"called": called,
		"skipped": skipped,
		"note": "Editor scene only. For runtime call_group use play + execute or scripts.",
	})
