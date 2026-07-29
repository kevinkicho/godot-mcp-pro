@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SpringBoneSimulator3D / secondary motion for characters (Godot 4.x).


func get_commands() -> Dictionary:
	return {
		"setup_spring_bone_simulator": _setup_spring_bone_simulator,
		"spring_bone_add_chain": _spring_bone_add_chain,
		"list_spring_bone_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["find_skeletons", "setup_skeleton_ik", "generate_ragdoll_from_skeleton"],
		"note": "API names vary by Godot 4.x minor version",
	})


func _setup_spring_bone_simulator(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var sk_path: String = optional_string(params, "skeleton_path", "")
	if sk_path.is_empty():
		return error_invalid_params("skeleton_path required")
	var sk := find_node_by_path(sk_path)
	if sk == null or not (sk is Skeleton3D):
		return error_not_found("Skeleton3D")
	var class_names := ["SpringBoneSimulator3D", "SkeletonModificationStack3D"]
	var node: Node = null
	var used := ""
	for cn in class_names:
		if ClassDB.class_exists(cn) and cn == "SpringBoneSimulator3D":
			node = ClassDB.instantiate(cn)
			used = cn
			break
	if node == null:
		# Fallback Marker for agent documentation
		var m := Marker3D.new()
		m.name = optional_string(params, "name", "SpringBonePlaceholder")
		add_child_with_undo(sk, m, root, "MCP: SpringBone placeholder")
		mark_current_scene_unsaved()
		return success({
			"node_path": str(root.get_path_to(m)),
			"placeholder": true,
			"hint": "SpringBoneSimulator3D not in this Godot build — upgrade engine or use custom secondary bone script",
		})
	node.name = optional_string(params, "name", "SpringBoneSimulator3D")
	add_child_with_undo(sk, node, root, "MCP: SpringBoneSimulator3D")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "class": used, "placeholder": false})


func _spring_bone_add_chain(params: Dictionary) -> Dictionary:
	## Best-effort set properties if settings array API exists.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null:
		return error_not_found("Node")
	var root_bone: String = optional_string(params, "root_bone", "")
	var end_bone: String = optional_string(params, "end_bone", "")
	var applied := {}
	if n.has_method("set_root_bone_name") and not root_bone.is_empty():
		n.call("set_root_bone_name", 0, StringName(root_bone))
		applied["root_bone"] = root_bone
	if "settings" in n:
		applied["settings_note"] = "Configure spring bone settings in inspector or via update_property on nested resources"
	if not end_bone.is_empty():
		applied["end_bone_requested"] = end_bone
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"applied": applied,
		"hint": "Use list_property_info on SpringBoneSimulator3D for version-specific fields",
	})
