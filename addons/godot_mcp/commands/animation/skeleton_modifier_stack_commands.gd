@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Skeleton modifier stack - list/enable IK, look-at, spring bones; humanoid presets.


func get_commands() -> Dictionary:
	return {
		"list_skeleton_modifiers": _list_modifiers,
		"set_skeleton_modifier_active": _set_active,
		"reorder_skeleton_modifiers": _reorder,
		"apply_humanoid_modifier_preset": _apply_preset,
		"list_skeleton_modifier_presets": _list_presets,
		"list_skeleton_modifier_stack_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_skeleton_ik", "setup_look_at_modifier", "setup_spring_bone_simulator",
		"set_skeleton_ik_target", "spring_bone_add_chain",
	])


func _is_modifier(n: Node) -> bool:
	var c := n.get_class()
	if c in ["SkeletonIK3D", "LookAtModifier3D", "SpringBoneSimulator3D", "PhysicalBoneSimulator3D"]:
		return true
	if ClassDB.class_exists("SkeletonModifier3D") and n.is_class("SkeletonModifier3D"):
		return true
	if c.ends_with("Modifier3D") or c.begins_with("SkeletonIK"):
		return true
	return false


func _list_modifiers(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start := find_node_by_path(r0[0])
	if start == null:
		return error_not_found("Node")
	var mods: Array = []
	_collect(start, root, mods)
	return success({"node_path": r0[0], "modifiers": mods, "count": mods.size()})


func _collect(n: Node, root: Node, out: Array) -> void:
	if _is_modifier(n):
		var active := true
		if "active" in n:
			active = bool(n.get("active"))
		elif n.has_method("is_running"):
			active = bool(n.call("is_running"))
		out.append({
			"path": str(root.get_path_to(n)),
			"name": n.name,
			"class": n.get_class(),
			"active": active,
			"index": out.size(),
		})
	for c in n.get_children():
		_collect(c, root, out)


func _set_active(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var active := optional_bool(params, "active", true)
	var n := find_node_by_path(r0[0])
	if n == null:
		return error_not_found("Modifier node")
	if "active" in n:
		n.set("active", active)
	elif active and n.has_method("start"):
		n.call("start")
	elif (not active) and n.has_method("stop"):
		n.call("stop")
	else:
		n.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "active": active, "class": n.get_class()})


func _reorder(params: Dictionary) -> Dictionary:
	## order: array of node_paths - reparents order under shared parent (best-effort).
	if not params.has("order") or not params["order"] is Array:
		return error_invalid_params("order array of node_paths required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var nodes: Array = []
	var parent: Node = null
	for p in params["order"]:
		var n := find_node_by_path(str(p))
		if n == null:
			continue
		if parent == null:
			parent = n.get_parent()
		if n.get_parent() != parent:
			return error_invalid_params("All modifiers must share the same parent for reorder")
		nodes.append(n)
	if parent == null or nodes.is_empty():
		return error_invalid_params("No valid nodes")
	var i := 0
	for n in nodes:
		parent.move_child(n, i)
		i += 1
	mark_current_scene_unsaved()
	return success({"reordered": nodes.size(), "parent": str(root.get_path_to(parent))})


func _list_presets(_params: Dictionary) -> Dictionary:
	return success({
		"presets": [
			{
				"id": "look_at_head",
				"desc": "LookAtModifier on Head bone toward a target",
				"needs": ["skeleton_path", "target_path?"],
			},
			{
				"id": "hand_ik",
				"desc": "SkeletonIK3D LeftHand + RightHand toward targets",
				"needs": ["skeleton_path", "left_target?", "right_target?"],
			},
			{
				"id": "hair_spring",
				"desc": "SpringBoneSimulator chain from Head",
				"needs": ["skeleton_path", "chain_bones?"],
			},
			{
				"id": "full_humanoid_stack",
				"desc": "look_at_head + hand_ik + optional hair_spring",
				"needs": ["skeleton_path"],
			},
		],
	})


func _exec(method: String, params: Dictionary) -> Dictionary:
	var r = get_parent()
	if r == null or not r.has_method("execute"):
		return {"error": {"message": "No router", "method": method}}
	return await r.execute(method, params)


func _apply_preset(params: Dictionary) -> Dictionary:
	var preset: String = optional_string(params, "preset", "look_at_head")
	var sk_path: String = optional_string(params, "skeleton_path", optional_string(params, "node_path", ""))
	if sk_path.is_empty():
		return error_invalid_params("skeleton_path required")
	var steps: Array = []
	match preset.to_lower():
		"look_at_head":
			steps.append(await _exec("setup_look_at_modifier", {
				"skeleton_path": sk_path,
				"bone_name": optional_string(params, "bone_name", "Head"),
				"target_node": optional_string(params, "target_path", ""),
				"name": optional_string(params, "name", "LookAtHead"),
			}))
		"hand_ik":
			steps.append(await _exec("setup_skeleton_ik", {
				"skeleton_path": sk_path,
				"name": "IK_LeftHand",
				"root_bone": optional_string(params, "left_root", "LeftUpperArm"),
				"tip_bone": optional_string(params, "left_tip", "LeftHand"),
				"target_node": optional_string(params, "left_target", ""),
			}))
			steps.append(await _exec("setup_skeleton_ik", {
				"skeleton_path": sk_path,
				"name": "IK_RightHand",
				"root_bone": optional_string(params, "right_root", "RightUpperArm"),
				"tip_bone": optional_string(params, "right_tip", "RightHand"),
				"target_node": optional_string(params, "right_target", ""),
			}))
		"hair_spring":
			steps.append(await _exec("setup_spring_bone_simulator", {
				"skeleton_path": sk_path,
				"name": optional_string(params, "name", "HairSpring"),
			}))
			if params.has("chain_bones"):
				steps.append(await _exec("spring_bone_add_chain", {
					"node_path": sk_path,
					"bones": params["chain_bones"],
				}))
		"full_humanoid_stack":
			steps.append(await _apply_preset({
				"preset": "look_at_head",
				"skeleton_path": sk_path,
				"target_path": params.get("look_target", ""),
			}))
			steps.append(await _apply_preset({
				"preset": "hand_ik",
				"skeleton_path": sk_path,
				"left_target": params.get("left_target", ""),
				"right_target": params.get("right_target", ""),
			}))
			if optional_bool(params, "with_hair", false):
				steps.append(await _apply_preset({
					"preset": "hair_spring",
					"skeleton_path": sk_path,
				}))
		_:
			return error_invalid_params("Unknown preset. list_skeleton_modifier_presets")
	return success({"preset": preset, "skeleton_path": sk_path, "steps": steps})
