@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SkeletonIK3D / LookAtModifier-style helpers for agents.


func get_commands() -> Dictionary:
	return {
		"setup_skeleton_ik": _setup_skeleton_ik,
		"set_skeleton_ik_target": _set_skeleton_ik_target,
		"setup_look_at_modifier": _setup_look_at_modifier,
		"list_skeleton_ik_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["find_skeletons", "list_skeleton_bones", "add_bone_attachment", "generate_ragdoll_from_skeleton"],
	})


func _setup_skeleton_ik(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var sk_path: String = optional_string(params, "skeleton_path", optional_string(params, "parent_path", ""))
	if sk_path.is_empty():
		return error_invalid_params("skeleton_path required")
	var sk := find_node_by_path(sk_path)
	if sk == null or not (sk is Skeleton3D):
		return error_not_found("Skeleton3D")
	if not ClassDB.class_exists("SkeletonIK3D"):
		return error_internal("SkeletonIK3D not available in this Godot build")
	var ik: Node = ClassDB.instantiate("SkeletonIK3D")
	ik.name = optional_string(params, "name", "SkeletonIK3D")
	if params.has("root_bone") and "root_bone" in ik:
		ik.set("root_bone", StringName(str(params["root_bone"])))
	if params.has("tip_bone") and "tip_bone" in ik:
		ik.set("tip_bone", StringName(str(params["tip_bone"])))
	if params.has("target_node") and "target_node" in ik:
		ik.set("target_node", NodePath(str(params["target_node"])))
	if params.has("override_tip_basis") and "override_tip_basis" in ik:
		ik.set("override_tip_basis", bool(params["override_tip_basis"]))
	if params.has("use_magnet") and "use_magnet" in ik:
		ik.set("use_magnet", bool(params["use_magnet"]))
	if params.has("magnet") and "magnet" in ik:
		var m = params["magnet"]
		if m is Dictionary:
			ik.set("magnet", Vector3(float(m.get("x", 0)), float(m.get("y", 0)), float(m.get("z", 0))))
	if optional_bool(params, "start", false) and ik.has_method("start"):
		ik.call("start")
	add_child_with_undo(sk, ik, root, "MCP: SkeletonIK3D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(ik)),
		"root_bone": str(ik.get("root_bone")) if "root_bone" in ik else "",
		"tip_bone": str(ik.get("tip_bone")) if "tip_bone" in ik else "",
	})


func _set_skeleton_ik_target(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var ik := find_node_by_path(r0[0])
	if ik == null or ik.get_class() != "SkeletonIK3D":
		return error_not_found("SkeletonIK3D")
	var applied := {}
	if params.has("target_node") and "target_node" in ik:
		ik.set("target_node", NodePath(str(params["target_node"])))
		applied["target_node"] = str(ik.get("target_node"))
	if params.has("interpolation") and "interpolation" in ik:
		ik.set("interpolation", float(params["interpolation"]))
		applied["interpolation"] = ik.get("interpolation")
	if params.has("min_distance") and "min_distance" in ik:
		ik.set("min_distance", float(params["min_distance"]))
		applied["min_distance"] = ik.get("min_distance")
	if optional_bool(params, "start", false) and ik.has_method("start"):
		ik.call("start")
		applied["started"] = true
	if optional_bool(params, "stop", false) and ik.has_method("stop"):
		ik.call("stop")
		applied["stopped"] = true
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _setup_look_at_modifier(params: Dictionary) -> Dictionary:
	## Godot 4.3+ SkeletonModifier3D LookAtModifier3D if available; else scripted Marker target.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var sk_path: String = optional_string(params, "skeleton_path", "")
	if sk_path.is_empty():
		return error_invalid_params("skeleton_path required")
	var sk := find_node_by_path(sk_path)
	if sk == null or not (sk is Skeleton3D):
		return error_not_found("Skeleton3D")
	if ClassDB.class_exists("LookAtModifier3D"):
		var mod: Node = ClassDB.instantiate("LookAtModifier3D")
		mod.name = optional_string(params, "name", "LookAtModifier3D")
		if params.has("bone_name") and "bone_name" in mod:
			mod.set("bone_name", StringName(str(params["bone_name"])))
		if params.has("target_node") and "target_node" in mod:
			mod.set("target_node", NodePath(str(params["target_node"])))
		add_child_with_undo(sk, mod, root, "MCP: LookAtModifier3D")
		mark_current_scene_unsaved()
		return success({"node_path": str(root.get_path_to(mod)), "class": "LookAtModifier3D"})
	# Fallback marker + hint
	var marker := Marker3D.new()
	marker.name = optional_string(params, "name", "LookAtTarget")
	add_child_with_undo(sk.get_parent() if sk.get_parent() else sk, marker, root, "MCP: LookAt target marker")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(marker)),
		"class": "Marker3D",
		"placeholder": true,
		"hint": "LookAtModifier3D unavailable - use Marker3D as target for custom look-at script",
	})
