@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Humanoid actor vertical — rig + interaction + locomotion recipes for agents.


func get_commands() -> Dictionary:
	return {
		"setup_humanoid_actor": _setup_humanoid_actor,
		"bind_interaction": _bind_interaction,
		"apply_locomotion_set": _apply_locomotion_set,
		"validate_humanoid_rig": _validate_humanoid_rig,
		"create_bone_map_preset": _create_bone_map_preset,
		"list_humanoid_recipes": _list_recipes,
	}


func _list_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"flow": [
			"import glTF → ensure_imported",
			"setup_humanoid_actor (or setup_character_3d + mesh)",
			"validate_humanoid_rig",
			"create_bone_map_preset profile=mixamo|humanoid|rpm",
			"apply_locomotion_set / apply_example_animation",
			"bind_interaction for talk/use",
			"playtest_report",
		],
		"tools": get_commands().keys(),
		"related": ["setup_character_3d", "apply_example_animation", "setup_ai_agent_3d", "create_dialogue_runner_script"],
	})


func _setup_humanoid_actor(params: Dictionary) -> Dictionary:
	## CharacterBody3D + capsule + optional model instance + AnimationPlayer + interaction Area3D.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var name_s: String = optional_string(params, "name", "Humanoid")
	var body := CharacterBody3D.new()
	body.name = name_s
	body.collision_layer = optional_int(params, "collision_layer", 1)
	body.collision_mask = optional_int(params, "collision_mask", 1)
	add_child_with_undo(parent, body, root, "MCP: Humanoid actor")

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = float(params.get("radius", 0.35))
	cap.height = float(params.get("height", 1.6))
	col.shape = cap
	col.position = Vector3(0, cap.height * 0.5, 0)
	add_child_with_undo(body, col, root, "MCP: capsule")

	var model_path: String = optional_string(params, "model_scene", "")
	var model_node_path := ""
	if not model_path.is_empty():
		if not model_path.begins_with("res://"):
			model_path = "res://" + model_path.trim_prefix("/")
		if ResourceLoader.exists(model_path):
			var packed: PackedScene = load(model_path) as PackedScene
			if packed:
				var inst := packed.instantiate()
				inst.name = optional_string(params, "model_name", "Model")
				add_child_with_undo(body, inst, root, "MCP: model")
				model_node_path = str(root.get_path_to(inst))

	var anim_player: AnimationPlayer = null
	if optional_bool(params, "with_animation_player", true):
		# Prefer existing under model
		if not model_node_path.is_empty():
			var model := find_node_by_path(model_node_path)
			anim_player = _find_anim_player(model)
		if anim_player == null:
			anim_player = AnimationPlayer.new()
			anim_player.name = "AnimationPlayer"
			add_child_with_undo(body, anim_player, root, "MCP: AnimationPlayer")

	var interact_path := ""
	if optional_bool(params, "with_interaction_area", true):
		var area := Area3D.new()
		area.name = "InteractionArea"
		area.collision_layer = optional_int(params, "interaction_layer", 0)
		area.collision_mask = optional_int(params, "interaction_mask", 1)
		area.monitoring = true
		area.monitorable = true
		add_child_with_undo(body, area, root, "MCP: InteractionArea")
		var ac := CollisionShape3D.new()
		ac.name = "CollisionShape3D"
		var sph := SphereShape3D.new()
		sph.radius = float(params.get("interaction_radius", 1.5))
		ac.shape = sph
		ac.position = Vector3(0, 1.0, 0)
		add_child_with_undo(area, ac, root, "MCP: interaction shape")
		interact_path = str(root.get_path_to(area))

	var cam_path := ""
	if optional_bool(params, "with_camera_pivot", false):
		var pivot := Node3D.new()
		pivot.name = "CameraPivot"
		add_child_with_undo(body, pivot, root, "MCP: CameraPivot")
		var cam := Camera3D.new()
		cam.name = "Camera3D"
		cam.position = Vector3(0, 1.6, 3.5)
		add_child_with_undo(pivot, cam, root, "MCP: Camera3D")
		cam_path = str(root.get_path_to(cam))

	mark_current_scene_unsaved()
	return success({
		"actor_path": str(root.get_path_to(body)),
		"collision": str(root.get_path_to(col)),
		"model_path": model_node_path,
		"animation_player": str(root.get_path_to(anim_player)) if anim_player else "",
		"interaction_area": interact_path,
		"camera": cam_path,
		"next": ["validate_humanoid_rig", "apply_locomotion_set", "bind_interaction"],
	})


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _find_anim_player(c)
		if f:
			return f
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var f := _find_skeleton(c)
		if f:
			return f
	return null


func _bind_interaction(params: Dictionary) -> Dictionary:
	## Attach interaction prompt script to an Area3D (talk/use range).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var area_path: String = optional_string(params, "area_path", "")
	var actor_path: String = optional_string(params, "actor_path", "")
	var area: Area3D = null
	if not area_path.is_empty():
		var n := find_node_by_path(area_path)
		if n is Area3D:
			area = n
	elif not actor_path.is_empty():
		var actor := find_node_by_path(actor_path)
		if actor:
			var ia := actor.get_node_or_null("InteractionArea")
			if ia is Area3D:
				area = ia
	if area == null:
		return error_not_found("Area3D — provide area_path or actor_path with InteractionArea")

	var prompt: String = optional_string(params, "prompt", "Press E to interact")
	var action: String = optional_string(params, "action", "interact")
	var kind: String = optional_string(params, "kind", "use")  # use|talk|pickup
	var script_path: String = optional_string(params, "script_path", "res://scripts/interaction_area.gd")
	var content := """extends Area3D
## MCP interaction area — body_entered tracking + action prompt.
signal interacted(body: Node)
signal prompt_changed(visible: bool, text: String)

@export var prompt_text: String = "%s"
@export var action_name: String = "%s"
@export var kind: String = "%s"
var _bodies: Array = []

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node) -> void:
	if body is CharacterBody3D or body is CharacterBody2D:
		_bodies.append(body)
		prompt_changed.emit(true, prompt_text)

func _on_exit(body: Node) -> void:
	_bodies.erase(body)
	if _bodies.is_empty():
		prompt_changed.emit(false, "")

func _unhandled_input(event: InputEvent) -> void:
	if _bodies.is_empty():
		return
	if event.is_action_pressed(action_name):
		interacted.emit(_bodies[0])
		get_viewport().set_input_as_handled()
""" % [prompt, action, kind]
	var w := write_script_file(script_path, content, optional_bool(params, "overwrite", true))
	if w.has("error"):
		return w
	var scr: Script = load(w.get("path", script_path)) as Script
	if scr:
		area.set_script(scr)
	# Ensure input action exists lightly
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.keycode = KEY_E
		InputMap.action_add_event(action, ev)
		ProjectSettings.set_setting("input/" + action, {
			"deadzone": 0.5,
			"events": [ev],
		})
		ProjectSettings.save()
	mark_current_scene_unsaved()
	return success({
		"area_path": str(root.get_path_to(area)),
		"script": w.get("path", script_path),
		"prompt": prompt,
		"action": action,
		"kind": kind,
		"hint": "Connect interacted signal to dialogue/quest via wire_signal_to_new_method",
	})


func _apply_locomotion_set(params: Dictionary) -> Dictionary:
	## Ensure AnimationPlayer has named clips (from existing or empty placeholders) + optional AnimationTree blend.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found(r0[0])
	var player: AnimationPlayer = null
	if node is AnimationPlayer:
		player = node
	else:
		player = _find_anim_player(node)
	if player == null:
		return error_not_found("AnimationPlayer under %s" % r0[0])

	var clips: Array = params.get("clips", ["idle", "walk", "run", "jump"])
	if not clips is Array or clips.is_empty():
		clips = ["idle", "walk", "run", "jump"]
	var lib: AnimationLibrary = player.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	var ensured: Array = []
	var missing: Array = []
	for c in clips:
		var cname := str(c)
		if player.has_animation(cname):
			ensured.append({"name": cname, "status": "exists", "length": player.get_animation(cname).length})
		else:
			# Placeholder zero-length-ish idle clip so tree can wire
			var anim := Animation.new()
			anim.length = float(params.get("placeholder_length", 0.5))
			anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(cname, anim)
			ensured.append({"name": cname, "status": "placeholder_created"})
			missing.append(cname)

	var tree_path := ""
	if optional_bool(params, "with_blend_tree", false):
		var parent_n: Node = player.get_parent() if player.get_parent() else node
		var tree := AnimationTree.new()
		tree.name = "AnimationTree"
		add_child_with_undo(parent_n, tree, root, "MCP: AnimationTree locomotion")
		tree.anim_player = tree.get_path_to(player)
		tree.active = false
		tree_path = str(root.get_path_to(tree))
	mark_current_scene_unsaved()
	return success({
		"animation_player": str(root.get_path_to(player)),
		"clips": ensured,
		"placeholders": missing,
		"animation_tree": tree_path,
		"hint": "Fill placeholders via apply_example_animation; wire AnimationTree with create_animation_tree tools",
	})


func _validate_humanoid_rig(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found(r0[0])
	var sk := _find_skeleton(node)
	var player := _find_anim_player(node)
	var issues: Array = []
	var info := {
		"has_skeleton": sk != null,
		"has_animation_player": player != null,
		"bone_count": sk.get_bone_count() if sk else 0,
		"animations": [],
	}
	if sk == null:
		issues.append({"severity": "warning", "message": "No Skeleton3D under node — mesh may be static"})
	else:
		var expected: Array = params.get("expected_bones", [
			"Hips", "Spine", "Head", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg",
			"mixamorig:Hips", "mixamorig:Head",
		])
		var found_names: Array = []
		for i in sk.get_bone_count():
			found_names.append(sk.get_bone_name(i))
		info["bones_sample"] = found_names.slice(0, mini(40, found_names.size()))
		var hits := 0
		for eb in expected:
			if str(eb) in found_names:
				hits += 1
		info["expected_bone_hits"] = hits
		if hits < 3 and sk.get_bone_count() > 0:
			issues.append({
				"severity": "info",
				"message": "Few standard bone names matched — use create_bone_map_preset + auto_map_bones_by_name",
			})
		# Scale sanity
		var sc: Vector3 = sk.scale if "scale" in sk else Vector3.ONE
		if sc.x < 0.01 or sc.x > 100.0:
			issues.append({"severity": "warning", "message": "Unusual skeleton scale %s" % str(sc)})
	if player == null:
		issues.append({"severity": "warning", "message": "No AnimationPlayer — add apply_locomotion_set"})
	else:
		for an in player.get_animation_list():
			info["animations"].append(an)
		if player.get_animation_list().is_empty():
			issues.append({"severity": "info", "message": "AnimationPlayer has no clips yet"})
	var ok := true
	for i in issues:
		if str(i.get("severity", "")) == "error":
			ok = false
	return success({
		"ok": ok and sk != null,
		"node_path": r0[0],
		"info": info,
		"issues": issues,
		"hint": "create_bone_map_preset + apply_example_animation for locomotion",
	})


func _create_bone_map_preset(params: Dictionary) -> Dictionary:
	## Write a BoneMap resource with common DCC name mappings into a SkeletonProfileHumanoid-style map.
	var profile_id: String = optional_string(params, "profile", "mixamo").to_lower()
	var path: String = optional_string(params, "path", "res://animation/bone_map_%s.tres" % profile_id)
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var bone_map := BoneMap.new()
	# SkeletonProfileHumanoid when available
	if ClassDB.class_exists("SkeletonProfileHumanoid"):
		var prof = ClassDB.instantiate("SkeletonProfileHumanoid")
		if prof:
			bone_map.profile = prof
	var mappings: Dictionary = params.get("mappings", {})
	if mappings.is_empty():
		mappings = _preset_mappings(profile_id)
	# Apply mappings if API allows set_skeleton_bone_name
	if bone_map.profile and bone_map.has_method("set_skeleton_bone_name"):
		for profile_bone in mappings:
			bone_map.set_skeleton_bone_name(StringName(str(profile_bone)), StringName(str(mappings[profile_bone])))
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(bone_map, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	# Optional apply meta to skeleton
	var sk_path: String = optional_string(params, "skeleton_path", "")
	if not sk_path.is_empty():
		var skn := find_node_by_path(sk_path)
		if skn is Skeleton3D:
			(skn as Skeleton3D).set_meta("mcp_bone_map", path)
			mark_current_scene_unsaved()
	return success({
		"path": path,
		"profile": profile_id,
		"mapping_count": mappings.size(),
		"mappings": mappings,
		"hint": "auto_map_bones_by_name / apply_bone_map_to_skeleton for retarget prep",
	})


func _preset_mappings(profile_id: String) -> Dictionary:
	match profile_id:
		"mixamo":
			return {
				"Hips": "mixamorig:Hips",
				"Spine": "mixamorig:Spine",
				"Chest": "mixamorig:Spine1",
				"UpperChest": "mixamorig:Spine2",
				"Neck": "mixamorig:Neck",
				"Head": "mixamorig:Head",
				"LeftUpperArm": "mixamorig:LeftArm",
				"LeftLowerArm": "mixamorig:LeftForeArm",
				"LeftHand": "mixamorig:LeftHand",
				"RightUpperArm": "mixamorig:RightArm",
				"RightLowerArm": "mixamorig:RightForeArm",
				"RightHand": "mixamorig:RightHand",
				"LeftUpperLeg": "mixamorig:LeftUpLeg",
				"LeftLowerLeg": "mixamorig:LeftLeg",
				"LeftFoot": "mixamorig:LeftFoot",
				"RightUpperLeg": "mixamorig:RightUpLeg",
				"RightLowerLeg": "mixamorig:RightLeg",
				"RightFoot": "mixamorig:RightFoot",
			}
		"rpm", "ready_player_me":
			return {
				"Hips": "Hips",
				"Spine": "Spine",
				"Chest": "Spine1",
				"Neck": "Neck",
				"Head": "Head",
				"LeftUpperArm": "LeftArm",
				"LeftLowerArm": "LeftForeArm",
				"LeftHand": "LeftHand",
				"RightUpperArm": "RightArm",
				"RightLowerArm": "RightForeArm",
				"RightHand": "RightHand",
				"LeftUpperLeg": "LeftUpLeg",
				"LeftLowerLeg": "LeftLeg",
				"LeftFoot": "LeftFoot",
				"RightUpperLeg": "RightUpLeg",
				"RightLowerLeg": "RightLeg",
				"RightFoot": "RightFoot",
			}
		_:  # humanoid identity / Godot profile names
			return {
				"Hips": "Hips",
				"Spine": "Spine",
				"Chest": "Chest",
				"UpperChest": "UpperChest",
				"Neck": "Neck",
				"Head": "Head",
				"LeftUpperArm": "LeftUpperArm",
				"LeftLowerArm": "LeftLowerArm",
				"LeftHand": "LeftHand",
				"RightUpperArm": "RightUpperArm",
				"RightLowerArm": "RightLowerArm",
				"RightHand": "RightHand",
				"LeftUpperLeg": "LeftUpperLeg",
				"LeftLowerLeg": "LeftLowerLeg",
				"LeftFoot": "LeftFoot",
				"RightUpperLeg": "RightUpperLeg",
				"RightLowerLeg": "RightLowerLeg",
				"RightFoot": "RightFoot",
			}
