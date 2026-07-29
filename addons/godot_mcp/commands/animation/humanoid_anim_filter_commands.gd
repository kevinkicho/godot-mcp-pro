@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Humanoid animation filters - upper-body masks, foot IK recipe, aim offset shell.


func get_commands() -> Dictionary:
	return {
		"create_animation_node_blend_filter": _create_blend_filter_script,
		"setup_upper_body_mask_tree": _upper_body_mask_tree,
		"list_humanoid_bone_filter_presets": _list_filter_presets,
		"create_foot_ik_helper_script": _foot_ik_script,
		"setup_aim_offset_blend_space": _aim_offset,
		"list_humanoid_anim_filter_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"create_animation_tree", "create_simple_locomotion_tree", "set_blend_tree_node",
		"connect_blend_tree_nodes", "setup_skeleton_ik", "set_root_motion_track",
	], {
		"flow": [
			"create_simple_locomotion_tree for legs",
			"setup_upper_body_mask_tree to layer aim/attack",
			"create_foot_ik_helper_script for plant feet polish",
		],
	})


func _list_filter_presets(_params: Dictionary) -> Dictionary:
	return success({
		"presets": {
			"upper_body": [
				"Spine", "Spine1", "Spine2", "Chest", "UpperChest", "Neck", "Head",
				"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
				"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
			],
			"lower_body": [
				"Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
				"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
			],
			"arms_only": [
				"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
				"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
			],
			"head_only": ["Neck", "Head"],
		},
		"note": "Names follow SkeletonProfileHumanoid; remap for Mixamo prefixes if needed.",
	})


func _create_blend_filter_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/anim_bone_filter.gd")
	var content := """extends RefCounted
class_name AnimBoneFilter
## Helper: which bones a filter preset includes (for agent docs / custom trees).

const PRESETS := {
	\"upper_body\": [
		\"Spine\", \"Chest\", \"UpperChest\", \"Neck\", \"Head\",
		\"LeftShoulder\", \"LeftUpperArm\", \"LeftLowerArm\", \"LeftHand\",
		\"RightShoulder\", \"RightUpperArm\", \"RightLowerArm\", \"RightHand\",
	],
	\"lower_body\": [
		\"Hips\", \"LeftUpperLeg\", \"LeftLowerLeg\", \"LeftFoot\",
		\"RightUpperLeg\", \"RightLowerLeg\", \"RightFoot\",
	],
	\"arms_only\": [
		\"LeftShoulder\", \"LeftUpperArm\", \"LeftLowerArm\", \"LeftHand\",
		\"RightShoulder\", \"RightUpperArm\", \"RightLowerArm\", \"RightHand\",
	],
}

static func bones(preset: String) -> PackedStringArray:
	return PackedStringArray(PRESETS.get(preset, []))
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "AnimBoneFilter"})


func _find_tree(path: String) -> AnimationTree:
	var n := find_node_by_path(path)
	return n as AnimationTree if n is AnimationTree else null


func _upper_body_mask_tree(params: Dictionary) -> Dictionary:
	## Build or extend AnimationTree root as BlendTree: locomotion + upper action via Add2.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var blend := AnimationNodeBlendTree.new()
	# Base locomotion time-scale node name
	var loco_anim: String = optional_string(params, "locomotion_animation", "Idle")
	var upper_anim: String = optional_string(params, "upper_animation", "Aim")
	var loco := AnimationNodeAnimation.new()
	loco.animation = StringName(loco_anim)
	var upper := AnimationNodeAnimation.new()
	upper.animation = StringName(upper_anim)
	var add := AnimationNodeAdd2.new()
	blend.add_node("Locomotion", loco, Vector2(0, 0))
	blend.add_node("Upper", upper, Vector2(0, 120))
	blend.add_node("Add", add, Vector2(200, 60))
	blend.connect_node("Add", 0, "Locomotion")
	blend.connect_node("Add", 1, "Upper")
	blend.connect_node("output", 0, "Add")
	# Filter: try to enable filter on Add2 for upper if API allows
	if add.has_method("set_filter_path") or "filter_enabled" in add:
		if "filter_enabled" in add:
			add.filter_enabled = true
		var preset = _list_filter_presets({})
		var bones: Array = preset.get("result", {}).get("presets", {}).get("upper_body", [])
		for b in bones:
			var fpath := "Skeleton3D:%s" % b
			if add.has_method("set_filter_path"):
				add.set_filter_path(NodePath(fpath), true)
	tree.tree_root = blend
	tree.active = optional_bool(params, "active", true)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"tree_root": "AnimationNodeBlendTree",
		"nodes": ["Locomotion", "Upper", "Add"],
		"locomotion_animation": loco_anim,
		"upper_animation": upper_anim,
		"hint": "Assign real clip names present on the AnimationPlayer; filter paths may need skeleton path prefix.",
	})


func _foot_ik_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/foot_ik_helper.gd")
	var content := """extends Node
## Simple foot plant helper - pair with SkeletonIK3D LeftFoot/RightFoot targets.
## Attach under CharacterBody3D; assign skeleton + IK nodes + ray length.

@export var skeleton_path: NodePath
@export var left_ik_path: NodePath
@export var right_ik_path: NodePath
@export var left_target_path: NodePath
@export var right_target_path: NodePath
@export var ray_length: float = 1.2
@export var foot_height: float = 0.05
@export var collision_mask: int = 1

func _physics_process(_dt: float) -> void:
	_update_foot(left_target_path, left_ik_path)
	_update_foot(right_target_path, right_ik_path)

func _update_foot(target_np: NodePath, ik_np: NodePath) -> void:
	if target_np.is_empty():
		return
	var target := get_node_or_null(target_np) as Node3D
	if target == null:
		return
	var from := target.global_position + Vector3.UP * 0.5
	var to := from + Vector3.DOWN * ray_length
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = collision_mask
	var hit := space.intersect_ray(q)
	if hit:
		target.global_position = hit.position + hit.normal * foot_height
	var ik := get_node_or_null(ik_np)
	if ik and ik.has_method(\"start\"):
		ik.call(\"start\")
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({
		"path": path,
		"related": ["setup_skeleton_ik tip_bone=LeftFoot", "setup_skeleton_ik tip_bone=RightFoot"],
	})


func _aim_offset(params: Dictionary) -> Dictionary:
	## Create a BlendSpace1D aim-pitch shell on an AnimationTree (or new tree root child recipe).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = float(params.get("min", -90))
	bs.max_space = float(params.get("max", 90))
	var down_anim: String = optional_string(params, "down_animation", "AimDown")
	var mid_anim: String = optional_string(params, "mid_animation", "AimForward")
	var up_anim: String = optional_string(params, "up_animation", "AimUp")
	for item in [
		{"pos": float(params.get("min", -90)), "anim": down_anim},
		{"pos": 0.0, "anim": mid_anim},
		{"pos": float(params.get("max", 90)), "anim": up_anim},
	]:
		var an := AnimationNodeAnimation.new()
		an.animation = StringName(str(item["anim"]))
		if bs.has_method("add_blend_point"):
			bs.add_blend_point(an, float(item["pos"]))
	# If tree root is BlendTree, inject; else replace with simple tree that exposes parameter
	if tree.tree_root is AnimationNodeBlendTree:
		var bt := tree.tree_root as AnimationNodeBlendTree
		bt.add_node("AimOffset", bs, Vector2(0, 240))
	else:
		var wrap := AnimationNodeBlendTree.new()
		wrap.add_node("AimOffset", bs, Vector2(0, 0))
		wrap.connect_node("output", 0, "AimOffset")
		tree.tree_root = wrap
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"blend_space": "AimOffset",
		"parameter_hint": "parameters/AimOffset/blend_position (pitch degrees)",
		"clips": [down_anim, mid_anim, up_anim],
	})
