@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Pack branch / selection as scene — highest-gain Scene dock workflow for agents.


func get_commands() -> Dictionary:
	return {
		"pack_node_as_scene": _pack_node,
		"pack_selection_as_scene": _pack_selection,
		"create_inherited_scene_from": _create_inherited,
		"replace_node_with_scene_instance": _replace_with_instance,
		"list_scene_pack_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["instance_packed_scene", "instance_scene_as_inherited", "save_scene", "add_scene_instance"],
		"workflow": [
			"Build prop under open scene",
			"pack_node_as_scene node_path=Chest path=res://props/chest.tscn",
			"replace_node_with_scene_instance (optional) to use the packed instance",
		],
	})


func _pack_node(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not path.get_extension().to_lower() in ["tscn", "scn"]:
		return error_invalid_params("path must end in .tscn or .scn")
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node '%s'" % r0[0])
	if node == root and optional_bool(params, "allow_root", false) == false:
		return error_invalid_params("Packing root is just save_scene — pass allow_root=true or save_scene")

	# Duplicate tree so we don't detach the live scene unless requested
	var packed_root: Node = node.duplicate(DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_SCRIPTS)
	_clear_scene_file_paths(packed_root)
	_set_owner_recursive(packed_root, packed_root)

	var packed := PackedScene.new()
	var pack_err := packed.pack(packed_root)
	packed_root.queue_free()
	if pack_err != OK:
		return error_internal("PackedScene.pack failed: %s" % error_string(pack_err))

	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)

	var replaced := false
	var new_path := ""
	if optional_bool(params, "replace_with_instance", false):
		var rep := _replace_node_with_scene(node, path, root)
		if rep.has("error"):
			return success({
				"path": path,
				"source_node": r0[0],
				"replaced": false,
				"replace_error": rep.get("error"),
			})
		replaced = true
		new_path = str(rep.get("node_path", ""))

	return success({
		"path": path,
		"source_node": r0[0],
		"replaced": replaced,
		"instance_path": new_path,
		"hint": "Instance with instance_packed_scene or add_scene_instance",
	})


func _clear_scene_file_paths(n: Node) -> void:
	n.scene_file_path = ""
	for c in n.get_children():
		_clear_scene_file_paths(c)


func _set_owner_recursive(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_set_owner_recursive(c, owner)


func _pack_selection(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var sel: Array = EditorInterface.get_selection().get_selected_nodes()
	if sel.is_empty():
		return error_invalid_params("No editor selection — select nodes or use pack_node_as_scene")
	if sel.size() == 1:
		params = params.duplicate()
		params["node_path"] = str(root.get_path_to(sel[0]))
		return _pack_node(params)
	# Multiple: pack under a temporary Node2D/Node3D/Node shell
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var shell: Node
	if sel[0] is Node3D:
		shell = Node3D.new()
	elif sel[0] is Node2D:
		shell = Node2D.new()
	else:
		shell = Node.new()
	shell.name = optional_string(params, "root_name", "PackedGroup")
	for n in sel:
		if n == root:
			continue
		var d: Node = n.duplicate(DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_SCRIPTS)
		shell.add_child(d)
	_set_owner_recursive(shell, shell)
	var packed := PackedScene.new()
	var pack_err := packed.pack(shell)
	shell.queue_free()
	if pack_err != OK:
		return error_internal("pack failed: %s" % error_string(pack_err))
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "node_count": sel.size(), "mode": "multi_selection"})


func _create_inherited(params: Dictionary) -> Dictionary:
	## Thin wrapper: source scene + save_path inherited .tscn
	var source_r := require_res_path(params, "source_path")
	if source_r[1] != null:
		return source_r[1]
	var save_r := require_res_path(params, "path")
	if save_r[1] != null:
		# alternate key save_path
		if params.has("save_path"):
			save_r = require_res_path(params, "save_path")
		if save_r[1] != null:
			return error_invalid_params("path or save_path required")
	var router = get_parent()
	if router and router.has_method("execute"):
		# Prefer existing import_3d/instance inherited if registered
		var methods: Array = router.get_available_methods() if router.has_method("get_available_methods") else []
		if "instance_scene_as_inherited" in methods:
			return await router.execute("instance_scene_as_inherited", {
				"source_path": source_r[0],
				"save_path": save_r[0],
				"overwrite": optional_bool(params, "overwrite", false),
				"open": optional_bool(params, "open", true),
			})
	# Fallback: write minimal inherited tscn
	if not ResourceLoader.exists(source_r[0]):
		return error_not_found(source_r[0])
	if FileAccess.file_exists(save_r[0]) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	var body := "[gd_scene load_steps=2 format=3]\n\n"
	body += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1\"]\n\n" % source_r[0]
	body += "[node name=\"%s\" instance=ExtResource(\"1\")]\n" % optional_string(params, "root_name", source_r[0].get_file().get_basename().capitalize())
	var derr := ensure_parent_dir(save_r[0])
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(save_r[0], FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write")
	f.store_string(body)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(save_r[0])
	if optional_bool(params, "open", true):
		EditorInterface.open_scene_from_path(save_r[0])
	return success({"path": save_r[0], "source_path": source_r[0], "type": "inherited_scene"})


func _replace_with_instance(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var scene_r := require_res_path(params, "scene_path")
	if scene_r[1] != null:
		return scene_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	return _replace_node_with_scene(node, scene_r[0], root)


func _replace_node_with_scene(node: Node, scene_path: String, root: Node) -> Dictionary:
	if not ResourceLoader.exists(scene_path):
		return error_not_found(scene_path)
	var packed = load(scene_path)
	if not (packed is PackedScene):
		return error_internal("Not PackedScene")
	var parent := node.get_parent()
	if parent == null:
		return error_invalid_params("Cannot replace root this way")
	var idx := node.get_index()
	var inst: Node = (packed as PackedScene).instantiate()
	inst.name = node.name
	# Copy transform if both Node2D or Node3D
	if node is Node2D and inst is Node2D:
		(inst as Node2D).transform = (node as Node2D).transform
	elif node is Node3D and inst is Node3D:
		(inst as Node3D).transform = (node as Node3D).transform
	elif node is Control and inst is Control:
		(inst as Control).position = (node as Control).position
		(inst as Control).size = (node as Control).size
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Replace with scene instance")
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_do_method(parent, "add_child", inst)
	undo_redo.add_do_method(parent, "move_child", inst, idx)
	undo_redo.add_do_method(inst, "set_owner", root)
	undo_redo.add_do_reference(inst)
	undo_redo.add_undo_method(parent, "remove_child", inst)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(parent, "move_child", node, idx)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(inst)),
		"scene_path": scene_path,
		"replaced": true,
	})
