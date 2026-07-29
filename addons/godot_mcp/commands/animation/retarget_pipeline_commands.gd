@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Character pipeline: glTF/scene -> bone map -> humanoid -> locomotion (Wave 3).


func get_commands() -> Dictionary:
	return {
		"pipeline_character_from_gltf": _pipeline_character_from_gltf,
		"pipeline_retarget_animations": _pipeline_retarget_animations,
		"list_retarget_pipeline_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["set_gltf_import_flags", "create_bone_map_preset", "setup_humanoid_actor", "apply_example_animation", "create_simple_locomotion_tree"],
		"flow": [
			"ensure_imported gltf",
			"pipeline_character_from_gltf gltf_path=... profile=mixamo",
			"pipeline_retarget_animations if needed",
			"playtest_report",
		],
	})


func _exec(method: String, params: Dictionary = {}) -> Dictionary:
	var r = get_parent()
	if r == null or not r.has_method("execute"):
		return {"error": {"message": "No router", "method": method}}
	return await r.execute(method, params)


func _pipeline_character_from_gltf(params: Dictionary) -> Dictionary:
	var gltf: String = optional_string(params, "gltf_path", optional_string(params, "path", ""))
	if gltf.is_empty():
		return error_invalid_params("gltf_path required")
	if not gltf.begins_with("res://"):
		gltf = "res://" + gltf.trim_prefix("/")
	var steps: Array = []
	var profile: String = optional_string(params, "profile", "mixamo")
	var parent_path: String = optional_string(params, "parent_path", ".")

	# Import flags for character
	if optional_bool(params, "configure_import", true):
		steps.append({"import_preset": await _exec("apply_import_schema_preset", {
			"path": gltf,
			"type": "scene_3d",
			"preset": "character_animated",
			"reimport": true,
		})})
		steps.append({"wait": await _exec("wait_for_import", {"timeout_sec": float(params.get("import_timeout", 30))})})

	# Instance scene
	var instance_path := ""
	var scene_path := gltf
	# Prefer .tscn sibling if create_scene_from_gltf available
	if optional_bool(params, "create_inherited", true):
		var created = await _exec("create_scene_from_gltf", {
			"path": gltf,
			"output_path": optional_string(params, "output_scene", gltf.get_basename() + "_character.tscn"),
			"overwrite": optional_bool(params, "overwrite", false),
		})
		steps.append({"create_scene_from_gltf": created})
		var cr = created.get("result", created)
		if cr is Dictionary and cr.has("path"):
			scene_path = str(cr["path"])
		elif cr is Dictionary and cr.has("output_path"):
			scene_path = str(cr["output_path"])

	# Open / instance into current
	if optional_bool(params, "instance_into_open_scene", true):
		var inst = await _exec("instance_scene_as_inherited" if false else "add_node", {})
		# Prefer stamp or pack instance via stamp_scene_instances if exists
		var stamp = await _exec("stamp_scene_instances", {
			"scene_path": scene_path,
			"parent_path": parent_path,
			"count": 1,
		})
		steps.append({"instance": stamp})
		var sr = stamp.get("result", stamp)
		if sr is Dictionary and sr.has("paths") and sr["paths"] is Array and sr["paths"].size() > 0:
			instance_path = str(sr["paths"][0])
		elif sr is Dictionary and sr.has("instances") and sr["instances"] is Array and sr["instances"].size() > 0:
			instance_path = str(sr["instances"][0])

	# Bone map preset
	var bone_map_path: String = optional_string(params, "bone_map_path", "res://animation/bone_map_%s.tres" % profile)
	steps.append({"bone_map": await _exec("create_bone_map_preset", {
		"path": bone_map_path,
		"profile": profile,
		"overwrite": optional_bool(params, "overwrite", true),
	})})

	# Humanoid setup if path known
	if not instance_path.is_empty() and optional_bool(params, "setup_humanoid", true):
		steps.append({"humanoid": await _exec("setup_humanoid_actor", {
			"model_scene": scene_path,
			"parent_path": parent_path,
			"name": optional_string(params, "name", "Player"),
		})})

	# Locomotion tree
	if optional_bool(params, "setup_locomotion", true):
		var anim_player: String = optional_string(params, "anim_player", "")
		steps.append({"locomotion": await _exec("create_simple_locomotion_tree", {
			"parent_path": optional_string(params, "locomotion_parent", parent_path),
			"anim_player": anim_player,
			"idle": optional_string(params, "idle", "Idle"),
			"walk": optional_string(params, "walk", "Walk"),
			"run": optional_string(params, "run", "Run"),
		})})

	return success({
		"pipeline": "character_from_gltf",
		"gltf_path": gltf,
		"scene_path": scene_path,
		"instance_path": instance_path,
		"bone_map_path": bone_map_path,
		"profile": profile,
		"steps": steps,
		"next": ["apply_example_animation", "validate_humanoid_rig", "playtest_report"],
	})


func _pipeline_retarget_animations(params: Dictionary) -> Dictionary:
	## Copy animations from example player/scene onto target with path remap.
	var steps: Array = []
	var target: String = optional_string(params, "target_node_path", "")
	if target.is_empty():
		return error_invalid_params("target_node_path (AnimationPlayer) required")
	if params.has("example_scene_path"):
		steps.append({"apply": await _exec("apply_example_animation", {
			"example_scene_path": str(params["example_scene_path"]),
			"source_animation": optional_string(params, "source_animation", ""),
			"target_node_path": target,
			"animation_name": optional_string(params, "animation_name", ""),
		})})
	elif params.has("source_node_path"):
		steps.append({"copy": await _exec("copy_animation_to_player", {
			"source_node_path": str(params["source_node_path"]),
			"target_node_path": target,
			"animation": optional_string(params, "source_animation", ""),
		})})
	else:
		return error_invalid_params("example_scene_path or source_node_path required")
	if params.has("from_prefix") and params.has("to_prefix"):
		steps.append({"remap": await _exec("remap_animation_track_paths", {
			"node_path": target,
			"animation": optional_string(params, "animation_name", optional_string(params, "source_animation", "")),
			"from_prefix": str(params["from_prefix"]),
			"to_prefix": str(params["to_prefix"]),
		})})
	return success({
		"pipeline": "retarget_animations",
		"target_node_path": target,
		"steps": steps,
		"next": ["compare_animations", "animation_player_play", "playtest_report"],
	})
