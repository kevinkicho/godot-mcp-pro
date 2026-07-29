@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Skeleton2D / Bone2D / rest poses / SkeletonModificationStack2D + TwoBoneIK.
## Docs: tutorials/animation/2d_skeletons — agent 2D skeletal animation surface.


func get_commands() -> Dictionary:
	return {
		"find_skeletons_2d": _find_skeletons_2d,
		"setup_skeleton_2d": _setup_skeleton_2d,
		"add_bone_2d": _add_bone_2d,
		"list_bones_2d": _list_bones_2d,
		"get_bone_2d_info": _get_bone_2d_info,
		"set_bone_2d_rest": _set_bone_2d_rest,
		"apply_bone_2d_rest": _apply_bone_2d_rest,
		"apply_all_bone_2d_rests": _apply_all_bone_2d_rests,
		"set_bone_2d_pose": _set_bone_2d_pose,
		"set_bone_2d_length": _set_bone_2d_length,
		"setup_modification_stack_2d": _setup_modification_stack_2d,
		"setup_two_bone_ik_2d": _setup_two_bone_ik_2d,
		"set_two_bone_ik_2d_target": _set_two_bone_ik_2d_target,
		"setup_fabrik_ik_2d": _setup_fabrik_ik_2d,
		"list_modification_stack_2d": _list_modification_stack_2d,
		"set_bone_2d_local_pose_override": _set_local_pose_override,
		"list_skeleton_2d_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_polygon_2d", "setup_remote_transform_2d", "create_simple_locomotion_tree", "setup_skeleton_ik"],
		"workflow": [
			"setup_skeleton_2d parent_path=.",
			"add_bone_2d skeleton_path=… name=Root length=32",
			"add_bone_2d parent_bone_path=… name=Arm length=24",
			"set_bone_2d_rest (or apply after positioning)",
			"setup_modification_stack_2d → setup_two_bone_ik_2d",
		],
		"docs": "https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html",
	})


func _xform2d_to_dict(t: Transform2D) -> Dictionary:
	return {
		"x": {"x": t.x.x, "y": t.x.y},
		"y": {"x": t.y.x, "y": t.y.y},
		"origin": {"x": t.origin.x, "y": t.origin.y},
	}


func _dict_to_xform2d(d: Dictionary) -> Transform2D:
	var t := Transform2D.IDENTITY
	if d.has("origin") and d["origin"] is Dictionary:
		var o: Dictionary = d["origin"]
		t.origin = Vector2(float(o.get("x", 0)), float(o.get("y", 0)))
	elif d.has("position") and d["position"] is Dictionary:
		var p: Dictionary = d["position"]
		t.origin = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	if d.has("rotation"):
		t = t.rotated(float(d["rotation"]))
	if d.has("x") and d["x"] is Dictionary:
		var xv: Dictionary = d["x"]
		t.x = Vector2(float(xv.get("x", 1)), float(xv.get("y", 0)))
	if d.has("y") and d["y"] is Dictionary:
		var yv: Dictionary = d["y"]
		t.y = Vector2(float(yv.get("x", 0)), float(yv.get("y", 1)))
	return t


func _find_skeleton_2d(node_path: String) -> Skeleton2D:
	var node := find_node_by_path(node_path)
	if node is Skeleton2D:
		return node as Skeleton2D
	return null


func _find_bone_2d(node_path: String) -> Bone2D:
	var node := find_node_by_path(node_path)
	if node is Bone2D:
		return node as Bone2D
	return null


func _find_skeletons_2d(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var found: Array = []
	_collect_skeletons_2d(root, root, found)
	return success({"skeletons": found, "count": found.size()})


func _collect_skeletons_2d(root: Node, node: Node, out: Array) -> void:
	if node is Skeleton2D:
		var sk: Skeleton2D = node as Skeleton2D
		out.append({
			"node_path": str(root.get_path_to(sk)),
			"name": sk.name,
			"bone_count": sk.get_bone_count(),
			"has_modification_stack": sk.get_modification_stack() != null,
		})
	for child in node.get_children():
		_collect_skeletons_2d(root, child, out)


func _setup_skeleton_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var sk := Skeleton2D.new()
	sk.name = optional_string(params, "name", "Skeleton2D")
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		sk.position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	add_child_with_undo(parent, sk, root, "MCP: Skeleton2D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(sk)),
		"class": "Skeleton2D",
		"hint": "add_bone_2d skeleton_path=… then set_bone_2d_rest / setup_two_bone_ik_2d",
	})


func _add_bone_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_bone_path",
		optional_string(params, "skeleton_path", optional_string(params, "parent_path", "")))
	if parent_path.is_empty():
		return error_invalid_params("skeleton_path or parent_bone_path required")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent at '%s'" % parent_path)
	if not (parent is Skeleton2D or parent is Bone2D):
		return error_invalid_params("Parent must be Skeleton2D or Bone2D")
	var bone := Bone2D.new()
	bone.name = optional_string(params, "name", "Bone2D")
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		bone.position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	if params.has("rotation"):
		bone.rotation = float(params["rotation"])
	if params.has("rotation_degrees"):
		bone.rotation_degrees = float(params["rotation_degrees"])
	var length: float = float(params.get("length", 16.0))
	bone.set_autocalculate_length_and_angle(optional_bool(params, "autocalculate", false))
	if not bone.get_autocalculate_length_and_angle():
		bone.set_length(length)
		if params.has("bone_angle"):
			bone.set_bone_angle(float(params["bone_angle"]))
	# Capture rest from current transform after placement
	add_child_with_undo(parent, bone, root, "MCP: Bone2D")
	if optional_bool(params, "set_rest_from_transform", true):
		bone.rest = bone.transform
	mark_current_scene_unsaved()
	var sk_idx := -1
	if bone.has_method("get_index_in_skeleton"):
		sk_idx = bone.get_index_in_skeleton()
	return success({
		"node_path": str(root.get_path_to(bone)),
		"parent_path": parent_path,
		"length": bone.get_length(),
		"index_in_skeleton": sk_idx,
		"rest": _xform2d_to_dict(bone.rest),
	})


func _list_bones_2d(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	var root := get_edited_root()
	var bones: Array = []
	for i in sk.get_bone_count():
		var b: Bone2D = sk.get_bone(i)
		if b == null:
			continue
		var parent_name := ""
		if b.get_parent() is Bone2D:
			parent_name = b.get_parent().name
		elif b.get_parent() is Skeleton2D:
			parent_name = "(skeleton)"
		bones.append({
			"index": i,
			"name": b.name,
			"node_path": str(root.get_path_to(b)) if root else str(b.get_path()),
			"parent_name": parent_name,
			"length": b.get_length(),
			"bone_angle": b.get_bone_angle(),
			"position": {"x": b.position.x, "y": b.position.y},
			"rotation": b.rotation,
			"rest": _xform2d_to_dict(b.rest),
		})
	return success({
		"skeleton_path": r0[0],
		"bone_count": sk.get_bone_count(),
		"bones": bones,
		"has_modification_stack": sk.get_modification_stack() != null,
	})


func _get_bone_2d_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var bone := _find_bone_2d(r0[0])
	if bone == null:
		return error_not_found("Bone2D at '%s'" % r0[0])
	return success({
		"node_path": r0[0],
		"name": bone.name,
		"index_in_skeleton": bone.get_index_in_skeleton(),
		"length": bone.get_length(),
		"bone_angle": bone.get_bone_angle(),
		"autocalculate": bone.get_autocalculate_length_and_angle(),
		"position": {"x": bone.position.x, "y": bone.position.y},
		"rotation": bone.rotation,
		"scale": {"x": bone.scale.x, "y": bone.scale.y},
		"rest": _xform2d_to_dict(bone.rest),
		"skeleton_rest": _xform2d_to_dict(bone.get_skeleton_rest()),
		"transform": _xform2d_to_dict(bone.transform),
	})


func _set_bone_2d_rest(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var bone := _find_bone_2d(r0[0])
	if bone == null:
		return error_not_found("Bone2D at '%s'" % r0[0])
	if params.has("rest") and params["rest"] is Dictionary:
		bone.rest = _dict_to_xform2d(params["rest"])
	elif optional_bool(params, "from_current_transform", true):
		bone.rest = bone.transform
	else:
		return error_invalid_params("Provide rest={} or from_current_transform=true")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "rest": _xform2d_to_dict(bone.rest)})


func _apply_bone_2d_rest(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var bone := _find_bone_2d(r0[0])
	if bone == null:
		return error_not_found("Bone2D at '%s'" % r0[0])
	bone.apply_rest()
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"transform": _xform2d_to_dict(bone.transform),
	})


func _apply_all_bone_2d_rests(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	var applied := 0
	for i in sk.get_bone_count():
		var b: Bone2D = sk.get_bone(i)
		if b:
			b.apply_rest()
			applied += 1
	mark_current_scene_unsaved()
	return success({"skeleton_path": r0[0], "applied": applied})


func _set_bone_2d_pose(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var bone := _find_bone_2d(r0[0])
	if bone == null:
		return error_not_found("Bone2D at '%s'" % r0[0])
	var applied := {}
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		bone.position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		applied["position"] = {"x": bone.position.x, "y": bone.position.y}
	if params.has("rotation"):
		bone.rotation = float(params["rotation"])
		applied["rotation"] = bone.rotation
	if params.has("rotation_degrees"):
		bone.rotation_degrees = float(params["rotation_degrees"])
		applied["rotation_degrees"] = bone.rotation_degrees
	if params.has("scale") and params["scale"] is Dictionary:
		var s: Dictionary = params["scale"]
		bone.scale = Vector2(float(s.get("x", 1)), float(s.get("y", 1)))
		applied["scale"] = {"x": bone.scale.x, "y": bone.scale.y}
	if applied.is_empty():
		return error_invalid_params("Provide position, rotation, rotation_degrees, and/or scale")
	if optional_bool(params, "update_rest", false):
		bone.rest = bone.transform
		applied["rest_updated"] = true
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _set_bone_2d_length(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var bone := _find_bone_2d(r0[0])
	if bone == null:
		return error_not_found("Bone2D at '%s'" % r0[0])
	if params.has("autocalculate"):
		bone.set_autocalculate_length_and_angle(bool(params["autocalculate"]))
	if params.has("length"):
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(float(params["length"]))
	if params.has("bone_angle"):
		bone.set_bone_angle(float(params["bone_angle"]))
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"length": bone.get_length(),
		"bone_angle": bone.get_bone_angle(),
		"autocalculate": bone.get_autocalculate_length_and_angle(),
	})


func _setup_modification_stack_2d(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	if not ClassDB.class_exists("SkeletonModificationStack2D"):
		return error_internal("SkeletonModificationStack2D not available in this Godot build")
	var stack: Resource = sk.get_modification_stack()
	var created := false
	if stack == null or optional_bool(params, "replace", false):
		stack = ClassDB.instantiate("SkeletonModificationStack2D")
		created = true
	if "enabled" in stack:
		stack.set("enabled", optional_bool(params, "enabled", true))
	if params.has("strength") and "strength" in stack:
		stack.set("strength", float(params["strength"]))
	sk.set_modification_stack(stack)
	mark_current_scene_unsaved()
	return success({
		"skeleton_path": r0[0],
		"created": created,
		"enabled": stack.get("enabled") if "enabled" in stack else true,
		"modification_count": stack.get("modification_count") if "modification_count" in stack else 0,
		"hint": "setup_two_bone_ik_2d skeleton_path=… joint_one_idx=0 joint_two_idx=1 target_path=…",
	})


func _ensure_stack(sk: Skeleton2D) -> Resource:
	var stack: Resource = sk.get_modification_stack()
	if stack == null:
		if not ClassDB.class_exists("SkeletonModificationStack2D"):
			return null
		stack = ClassDB.instantiate("SkeletonModificationStack2D")
		if "enabled" in stack:
			stack.set("enabled", true)
		sk.set_modification_stack(stack)
	return stack


func _setup_two_bone_ik_2d(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	if not ClassDB.class_exists("SkeletonModification2DTwoBoneIK"):
		return error_internal("SkeletonModification2DTwoBoneIK not available (experimental 2D IK)")
	var stack := _ensure_stack(sk)
	if stack == null:
		return error_internal("Could not create SkeletonModificationStack2D")
	var ik: Resource = ClassDB.instantiate("SkeletonModification2DTwoBoneIK")
	if "enabled" in ik:
		ik.set("enabled", optional_bool(params, "enabled", true))
	# Joint indices or Bone2D node paths
	if params.has("joint_one_idx"):
		ik.call("set_joint_one_bone_idx", int(params["joint_one_idx"]))
	if params.has("joint_two_idx"):
		ik.call("set_joint_two_bone_idx", int(params["joint_two_idx"]))
	var root := get_edited_root()
	if params.has("joint_one_path"):
		var b1 := find_node_by_path(str(params["joint_one_path"]))
		if b1 and root:
			ik.call("set_joint_one_bone2d_node", sk.get_path_to(b1))
			if b1 is Bone2D:
				ik.call("set_joint_one_bone_idx", (b1 as Bone2D).get_index_in_skeleton())
	if params.has("joint_two_path"):
		var b2 := find_node_by_path(str(params["joint_two_path"]))
		if b2 and root:
			ik.call("set_joint_two_bone2d_node", sk.get_path_to(b2))
			if b2 is Bone2D:
				ik.call("set_joint_two_bone_idx", (b2 as Bone2D).get_index_in_skeleton())
	if params.has("target_path") or params.has("target_nodepath"):
		var tp: String = optional_string(params, "target_path", optional_string(params, "target_nodepath", ""))
		var target := find_node_by_path(tp)
		if target and root:
			# Path relative to skeleton (modification resolves from skeleton)
			ik.set("target_nodepath", sk.get_path_to(target))
		else:
			ik.set("target_nodepath", NodePath(tp))
	if params.has("flip_bend_direction"):
		ik.set("flip_bend_direction", bool(params["flip_bend_direction"]))
	if params.has("target_minimum_distance"):
		ik.set("target_minimum_distance", float(params["target_minimum_distance"]))
	if params.has("target_maximum_distance"):
		ik.set("target_maximum_distance", float(params["target_maximum_distance"]))
	# Append via modification_count (Godot 4 API)
	var count: int = int(stack.get("modification_count")) if "modification_count" in stack else 0
	if stack.has_method("set_modification"):
		stack.set("modification_count", count + 1)
		stack.call("set_modification", count, ik)
	elif stack.has_method("add_modification"):
		stack.call("add_modification", ik)
	else:
		return error_internal("SkeletonModificationStack2D has no set_modification/add_modification")
	if "enabled" in stack:
		stack.set("enabled", true)
	mark_current_scene_unsaved()
	return success({
		"skeleton_path": r0[0],
		"modification_index": count,
		"joint_one_idx": ik.call("get_joint_one_bone_idx") if ik.has_method("get_joint_one_bone_idx") else -1,
		"joint_two_idx": ik.call("get_joint_two_bone_idx") if ik.has_method("get_joint_two_bone_idx") else -1,
		"target_nodepath": str(ik.get("target_nodepath")) if "target_nodepath" in ik else "",
		"class": "SkeletonModification2DTwoBoneIK",
	})


func _set_two_bone_ik_2d_target(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	var stack: Resource = sk.get_modification_stack()
	if stack == null:
		return error_not_found("modification stack — call setup_two_bone_ik_2d first")
	var idx: int = optional_int(params, "modification_index", 0)
	if not stack.has_method("get_modification"):
		return error_internal("Cannot read modifications")
	var mod: Resource = stack.call("get_modification", idx)
	if mod == null or mod.get_class() != "SkeletonModification2DTwoBoneIK":
		return error_not_found("SkeletonModification2DTwoBoneIK at index %d" % idx)
	var applied := {}
	if params.has("target_path") or params.has("target_nodepath"):
		var tp: String = optional_string(params, "target_path", optional_string(params, "target_nodepath", ""))
		var target := find_node_by_path(tp)
		if target:
			mod.set("target_nodepath", sk.get_path_to(target))
		else:
			mod.set("target_nodepath", NodePath(tp))
		applied["target_nodepath"] = str(mod.get("target_nodepath"))
	if params.has("flip_bend_direction"):
		mod.set("flip_bend_direction", bool(params["flip_bend_direction"]))
		applied["flip_bend_direction"] = mod.get("flip_bend_direction")
	if params.has("enabled") and "enabled" in mod:
		mod.set("enabled", bool(params["enabled"]))
		applied["enabled"] = mod.get("enabled")
	if params.has("target_minimum_distance"):
		mod.set("target_minimum_distance", float(params["target_minimum_distance"]))
		applied["target_minimum_distance"] = mod.get("target_minimum_distance")
	if params.has("target_maximum_distance"):
		mod.set("target_maximum_distance", float(params["target_maximum_distance"]))
		applied["target_maximum_distance"] = mod.get("target_maximum_distance")
	mark_current_scene_unsaved()
	return success({"skeleton_path": r0[0], "modification_index": idx, "applied": applied})


func _list_modification_stack_2d(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	var stack: Resource = sk.get_modification_stack()
	if stack == null:
		return success({"skeleton_path": r0[0], "has_stack": false, "modifications": []})
	var mods: Array = []
	var count: int = int(stack.get("modification_count")) if "modification_count" in stack else 0
	for i in count:
		if not stack.has_method("get_modification"):
			break
		var m: Resource = stack.call("get_modification", i)
		if m == null:
			mods.append({"index": i, "class": null})
			continue
		var entry := {"index": i, "class": m.get_class(), "enabled": m.get("enabled") if "enabled" in m else true}
		if m.get_class() == "SkeletonModification2DTwoBoneIK":
			entry["target_nodepath"] = str(m.get("target_nodepath")) if "target_nodepath" in m else ""
			if m.has_method("get_joint_one_bone_idx"):
				entry["joint_one_idx"] = m.call("get_joint_one_bone_idx")
			if m.has_method("get_joint_two_bone_idx"):
				entry["joint_two_idx"] = m.call("get_joint_two_bone_idx")
		mods.append(entry)
	return success({
		"skeleton_path": r0[0],
		"has_stack": true,
		"enabled": stack.get("enabled") if "enabled" in stack else true,
		"strength": stack.get("strength") if "strength" in stack else 1.0,
		"modification_count": count,
		"modifications": mods,
	})


func _setup_fabrik_ik_2d(params: Dictionary) -> Dictionary:
	## SkeletonModification2DFABRIK when available (chain IK beyond two bones).
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	if not ClassDB.class_exists("SkeletonModification2DFABRIK"):
		return error_internal("SkeletonModification2DFABRIK not available in this Godot build")
	var stack := _ensure_stack(sk)
	if stack == null:
		return error_internal("Could not create SkeletonModificationStack2D")
	var fab: Resource = ClassDB.instantiate("SkeletonModification2DFABRIK")
	if "enabled" in fab:
		fab.set("enabled", optional_bool(params, "enabled", true))
	if params.has("target_path") or params.has("target_nodepath"):
		var tp: String = optional_string(params, "target_path", optional_string(params, "target_nodepath", ""))
		var target := find_node_by_path(tp)
		if target:
			if "target_nodepath" in fab:
				fab.set("target_nodepath", sk.get_path_to(target))
			elif fab.has_method("set_target_node"):
				fab.call("set_target_node", sk.get_path_to(target))
	if params.has("fabrik_chain_length") and fab.has_method("set_fabrik_chain_length"):
		fab.call("set_fabrik_chain_length", int(params["fabrik_chain_length"]))
	elif params.has("chain_length") and fab.has_method("set_fabrik_chain_length"):
		fab.call("set_fabrik_chain_length", int(params["chain_length"]))
	# Optional joint bone indices
	if params.has("joint_indices") and params["joint_indices"] is Array and fab.has_method("set_fabrik_joint_bone_index"):
		var joints: Array = params["joint_indices"]
		if fab.has_method("set_fabrik_chain_length"):
			fab.call("set_fabrik_chain_length", joints.size())
		for i in joints.size():
			fab.call("set_fabrik_joint_bone_index", i, int(joints[i]))
	var count: int = int(stack.get("modification_count")) if "modification_count" in stack else 0
	if stack.has_method("set_modification"):
		stack.set("modification_count", count + 1)
		stack.call("set_modification", count, fab)
	elif stack.has_method("add_modification"):
		stack.call("add_modification", fab)
	else:
		return error_internal("Cannot add modification to stack")
	if "enabled" in stack:
		stack.set("enabled", true)
	mark_current_scene_unsaved()
	return success({
		"skeleton_path": r0[0],
		"modification_index": count,
		"class": "SkeletonModification2DFABRIK",
		"hint": "Tune chain joints via describe_class SkeletonModification2DFABRIK + update_property if needed",
	})


func _set_local_pose_override(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton_2d(r0[0])
	if sk == null:
		return error_not_found("Skeleton2D at '%s'" % r0[0])
	var bone_idx: int = optional_int(params, "bone_index", -1)
	if bone_idx < 0 and params.has("bone_name"):
		for i in sk.get_bone_count():
			var b: Bone2D = sk.get_bone(i)
			if b and b.name == str(params["bone_name"]):
				bone_idx = i
				break
	if bone_idx < 0 or bone_idx >= sk.get_bone_count():
		return error_invalid_params("bone_index or bone_name required / valid")
	var pose := Transform2D.IDENTITY
	if params.has("pose") and params["pose"] is Dictionary:
		pose = _dict_to_xform2d(params["pose"])
	elif params.has("position") or params.has("rotation"):
		if params.has("position") and params["position"] is Dictionary:
			var p: Dictionary = params["position"]
			pose.origin = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		if params.has("rotation"):
			pose = pose.rotated(float(params["rotation"]))
	var strength: float = float(params.get("strength", 1.0))
	var persistent: bool = optional_bool(params, "persistent", true)
	sk.set_bone_local_pose_override(bone_idx, pose, strength, persistent)
	mark_current_scene_unsaved()
	return success({
		"skeleton_path": r0[0],
		"bone_index": bone_idx,
		"strength": strength,
		"persistent": persistent,
		"pose": _xform2d_to_dict(pose),
	})
