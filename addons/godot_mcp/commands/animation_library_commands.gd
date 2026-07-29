@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## AnimationLibrary asset packs — bulk clip import, rename, merge for humanoid sets.


func get_commands() -> Dictionary:
	return {
		"create_animation_library_resource": _create_library,
		"animation_library_add_clip": _add_clip,
		"animation_library_list_clips": _list_clips,
		"animation_library_rename_clip": _rename_clip,
		"animation_library_remove_clip": _remove_clip,
		"animation_library_merge_from_player": _merge_from_player,
		"animation_library_assign_to_player": _assign_to_player,
		"animation_library_import_from_scene": _import_from_scene,
		"list_animation_library_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"flow": [
			"create_animation_library_resource",
			"animation_library_import_from_scene or merge_from_player",
			"animation_library_rename_clip to idle/walk/run",
			"animation_library_assign_to_player",
			"apply_locomotion_set",
		],
		"tools": get_commands().keys(),
	})


func _create_library(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://animation/locomotion.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var lib := AnimationLibrary.new()
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	var err := ResourceSaver.save(lib, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "clip_count": 0})


func _load_lib(path: String) -> AnimationLibrary:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AnimationLibrary


func _add_clip(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "library_path")
	if r[1] != null:
		return r[1]
	var lib := _load_lib(r[0])
	if lib == null:
		return error_not_found(r[0])
	var name_s: String = optional_string(params, "name", "clip")
	var anim_path: String = optional_string(params, "animation_path", "")
	var anim: Animation = null
	if not anim_path.is_empty():
		if not anim_path.begins_with("res://"):
			anim_path = "res://" + anim_path.trim_prefix("/")
		anim = load(anim_path) as Animation
	if anim == null:
		anim = Animation.new()
		anim.length = float(params.get("length", 1.0))
	if lib.has_animation(name_s) and optional_bool(params, "overwrite", true):
		lib.remove_animation(name_s)
	lib.add_animation(name_s, anim.duplicate(true) as Animation)
	ResourceSaver.save(lib, r[0])
	return success({"library_path": r[0], "name": name_s, "length": anim.length})


func _list_clips(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "library_path")
	if r[1] != null:
		return r[1]
	var lib := _load_lib(r[0])
	if lib == null:
		return error_not_found(r[0])
	var clips: Array = []
	for n in lib.get_animation_list():
		var a: Animation = lib.get_animation(n)
		clips.append({
			"name": n,
			"length": a.length if a else 0.0,
			"tracks": a.get_track_count() if a else 0,
			"loop_mode": a.loop_mode if a else 0,
		})
	return success({"library_path": r[0], "clips": clips, "count": clips.size()})


func _rename_clip(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "library_path")
	if r[1] != null:
		return r[1]
	var lib := _load_lib(r[0])
	if lib == null:
		return error_not_found(r[0])
	var old_n: String = optional_string(params, "old_name", "")
	var new_n: String = optional_string(params, "new_name", "")
	if old_n.is_empty() or new_n.is_empty():
		return error_invalid_params("old_name and new_name required")
	if not lib.has_animation(old_n):
		return error_not_found(old_n)
	if lib.has_animation(new_n):
		return error_invalid_params("Target name exists: %s" % new_n)
	lib.rename_animation(old_n, new_n)
	ResourceSaver.save(lib, r[0])
	return success({"old_name": old_n, "new_name": new_n})


func _remove_clip(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "library_path")
	if r[1] != null:
		return r[1]
	var lib := _load_lib(r[0])
	if lib == null:
		return error_not_found(r[0])
	var name_s: String = optional_string(params, "name", "")
	if not lib.has_animation(name_s):
		return error_not_found(name_s)
	lib.remove_animation(name_s)
	ResourceSaver.save(lib, r[0])
	return success({"removed": name_s})


func _merge_from_player(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "library_path")
	if r[1] != null:
		return r[1]
	var lib := _load_lib(r[0])
	if lib == null:
		# create
		lib = AnimationLibrary.new()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is AnimationPlayer):
		return error_not_found("AnimationPlayer")
	var player: AnimationPlayer = node
	var only: Array = params.get("animations", [])
	var added: Array = []
	for aname in player.get_animation_list():
		if only is Array and only.size() > 0 and not (aname in only):
			continue
		var a: Animation = player.get_animation(aname)
		if a == null:
			continue
		var dest_name := str(aname)
		if params.has("rename_map") and params["rename_map"] is Dictionary:
			var rm: Dictionary = params["rename_map"]
			if rm.has(aname):
				dest_name = str(rm[aname])
		if lib.has_animation(dest_name):
			lib.remove_animation(dest_name)
		lib.add_animation(dest_name, a.duplicate(true) as Animation)
		added.append(dest_name)
	ResourceSaver.save(lib, r[0])
	EditorInterface.get_resource_filesystem().update_file(r[0])
	return success({"library_path": r[0], "added": added, "count": added.size()})


func _assign_to_player(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "library_path")
	if r[1] != null:
		return r[1]
	var lib := _load_lib(r[0])
	if lib == null:
		return error_not_found(r[0])
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is AnimationPlayer):
		return error_not_found("AnimationPlayer")
	var player: AnimationPlayer = node
	var lib_name: String = optional_string(params, "library_name", "locomotion")
	if player.has_animation_library(lib_name):
		player.remove_animation_library(lib_name)
	player.add_animation_library(lib_name, lib)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"library_name": lib_name,
		"clips": lib.get_animation_list(),
	})


func _import_from_scene(params: Dictionary) -> Dictionary:
	## Pull all clips from first AnimationPlayer in a packed scene into a library resource.
	var scene_path: String = optional_string(params, "scene_path", "")
	if scene_path.is_empty():
		return error_invalid_params("scene_path required")
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path.trim_prefix("/")
	var lib_path: String = optional_string(params, "library_path", "res://animation/imported.tres")
	if not lib_path.begins_with("res://"):
		lib_path = "res://" + lib_path.trim_prefix("/")
	if not ResourceLoader.exists(scene_path):
		return error_not_found(scene_path)
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return error_internal("Not PackedScene")
	var inst := packed.instantiate()
	var player := _find_ap(inst)
	if player == null:
		inst.queue_free()
		return error_not_found("AnimationPlayer in scene")
	var lib := AnimationLibrary.new()
	var added: Array = []
	for aname in player.get_animation_list():
		var a: Animation = player.get_animation(aname)
		if a:
			lib.add_animation(aname, a.duplicate(true) as Animation)
			added.append(aname)
	inst.queue_free()
	var derr := ensure_parent_dir(lib_path)
	if not derr.is_empty():
		return derr
	ResourceSaver.save(lib, lib_path)
	EditorInterface.get_resource_filesystem().update_file(lib_path)
	return success({"library_path": lib_path, "from_scene": scene_path, "clips": added, "count": added.size()})


func _find_ap(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _find_ap(c)
		if f:
			return f
	return null
