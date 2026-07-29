@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scene instance depth — editable children, placeholders, make local, owner fixups.
## Mirrors Scene dock instance workflows humans use constantly.


func get_commands() -> Dictionary:
	return {
		"set_editable_instance": _set_editable_instance,
		"get_instance_info": _get_instance_info,
		"setup_instance_placeholder": _setup_placeholder,
		"make_scene_instance_local": _make_local,
		"instance_packed_scene": _instance_packed,
		"batch_set_owners": _batch_set_owners,
		"list_scene_instance_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["instance_scene_as_inherited", "stamp_scene_instances", "open_scene", "save_scene"],
		"workflow": [
			"instance_packed_scene scene_path=res://props/chest.tscn parent_path=.",
			"set_editable_instance node_path=Chest editable=true",
			"make_scene_instance_local only when you need to break inheritance",
		],
	})


func _set_editable_instance(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node at '%s'" % r0[0])
	if node.scene_file_path.is_empty() and node != root:
		# Still may be an instance with scene_file_path on the root of the instance
		pass
	var editable: bool = optional_bool(params, "editable", true)
	# EditorInterface.set_editable_instance(node, editable)
	if EditorInterface.has_method("set_editable_instance"):
		EditorInterface.set_editable_instance(node, editable)
	else:
		return error_internal("EditorInterface.set_editable_instance unavailable")
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"editable": editable,
		"scene_file_path": node.scene_file_path,
	})


func _get_instance_info(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node at '%s'" % r0[0])
	var editable := false
	if EditorInterface.has_method("is_editable_instance"):
		editable = EditorInterface.is_editable_instance(node)
	return success({
		"node_path": r0[0],
		"name": node.name,
		"class": node.get_class(),
		"scene_file_path": node.scene_file_path,
		"is_instance": not node.scene_file_path.is_empty() and node != root,
		"editable_instance": editable,
		"owner": str(root.get_path_to(node.owner)) if node.owner else "",
		"child_count": node.get_child_count(),
		"filename_legacy": node.scene_file_path,
	})


func _setup_placeholder(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	if not ClassDB.class_exists("InstancePlaceholder"):
		return error_internal("InstancePlaceholder not available")
	var ph: Node = ClassDB.instantiate("InstancePlaceholder")
	ph.name = optional_string(params, "name", "InstancePlaceholder")
	var scene_path: String = optional_string(params, "scene_path", "")
	if not scene_path.is_empty():
		var vr := validate_res_path(scene_path)
		if vr[1] != null:
			return vr[1]
		# InstancePlaceholder uses create_instance / path property depending on version
		if "path" in ph:
			ph.set("path", vr[0])
		elif ph.has_method("set_instance_path"):
			ph.call("set_instance_path", vr[0])
	if params.has("position") and ph is Node2D and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		(ph as Node2D).position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	elif params.has("position") and ph is Node3D and params["position"] is Dictionary:
		var p3: Dictionary = params["position"]
		(ph as Node3D).position = Vector3(
			float(p3.get("x", 0)), float(p3.get("y", 0)), float(p3.get("z", 0))
		)
	add_child_with_undo(parent, ph, root, "MCP: InstancePlaceholder")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(ph)),
		"scene_path": scene_path,
		"class": "InstancePlaceholder",
		"hint": "Loads deferred at runtime — good for large levels",
	})


func _make_local(params: Dictionary) -> Dictionary:
	## Break inheritance: duplicate instance tree into current scene (like "Make Local").
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node at '%s'" % r0[0])
	if node.scene_file_path.is_empty():
		return error_invalid_params("Node is not a scene instance (no scene_file_path)")
	var parent := node.get_parent()
	if parent == null:
		return error_invalid_params("Cannot make root scene local this way")
	var idx := node.get_index()
	# Duplicate without instancing
	var local_copy: Node = node.duplicate(DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_SCRIPTS)
	local_copy.scene_file_path = ""
	local_copy.name = node.name
	# Replace
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Make scene instance local")
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_do_method(parent, "add_child", local_copy)
	undo_redo.add_do_method(parent, "move_child", local_copy, idx)
	undo_redo.add_do_method(local_copy, "set_owner", root)
	_owner_recursive_do(undo_redo, local_copy, root)
	undo_redo.add_do_reference(local_copy)
	undo_redo.add_undo_method(parent, "remove_child", local_copy)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(parent, "move_child", node, idx)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(local_copy)),
		"was_scene": node.scene_file_path if is_instance_valid(node) else "",
		"made_local": true,
		"warning": "Breaks inheritance — edits no longer follow the source .tscn",
	})


func _owner_recursive_do(undo_redo: EditorUndoRedoManager, node: Node, owner: Node) -> void:
	for c in node.get_children():
		undo_redo.add_do_method(c, "set_owner", owner)
		_owner_recursive_do(undo_redo, c, owner)


func _instance_packed(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var scene_r := require_res_path(params, "scene_path")
	if scene_r[1] != null:
		return scene_r[1]
	if not ResourceLoader.exists(scene_r[0]):
		return error_not_found(scene_r[0])
	var packed = load(scene_r[0])
	if not (packed is PackedScene):
		return error_internal("Not a PackedScene: %s" % scene_r[0])
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var inst: Node = (packed as PackedScene).instantiate()
	if params.has("name"):
		inst.name = str(params["name"])
	if params.has("position"):
		if inst is Node2D and params["position"] is Dictionary:
			var p: Dictionary = params["position"]
			(inst as Node2D).position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		elif inst is Node3D and params["position"] is Dictionary:
			var p3: Dictionary = params["position"]
			(inst as Node3D).position = Vector3(
				float(p3.get("x", 0)), float(p3.get("y", 0)), float(p3.get("z", 0))
			)
	add_child_with_undo(parent, inst, root, "MCP: Instance packed scene")
	if optional_bool(params, "editable", false) and EditorInterface.has_method("set_editable_instance"):
		EditorInterface.set_editable_instance(inst, true)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(inst)),
		"scene_path": scene_r[0],
		"class": inst.get_class(),
		"editable": optional_bool(params, "editable", false),
	})


func _batch_set_owners(params: Dictionary) -> Dictionary:
	## Ensure all descendants under node_path have owner = edited root (or owner_path).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var owner_node: Node = root
	var op: String = optional_string(params, "owner_path", "")
	if not op.is_empty():
		owner_node = find_node_by_path(op)
		if owner_node == null:
			return error_not_found("owner_path")
	var count := 0
	count += _set_owner_tree(node, owner_node, optional_bool(params, "include_root", true))
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"owner_path": str(root.get_path_to(owner_node)),
		"nodes_updated": count,
	})


func _set_owner_tree(node: Node, owner: Node, include_root: bool) -> int:
	var n := 0
	if include_root:
		node.owner = owner
		n += 1
	for c in node.get_children():
		c.owner = owner
		n += 1
		n += _set_owner_tree(c, owner, false)
	return n
