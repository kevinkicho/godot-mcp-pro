@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Animation clip CRUD and libraries.

func get_commands() -> Dictionary:
	return {
		"list_animations": _list_animations,
		"create_animation": _create_animation,
		"remove_animation": _remove_animation,
		"rename_animation": _rename_animation,
		"duplicate_animation": _duplicate_animation,
		"get_animation_info": _get_animation_info,
		"set_animation_length": _set_animation_length,
		"set_animation_loop": _set_animation_loop,
		"ensure_reset_animation": _ensure_reset_animation,
		"list_animation_libraries": _list_animation_libraries,
		"add_animation_library": _add_animation_library,
		"remove_animation_library": _remove_animation_library,
	}

func _find_animation_player(node_path: String) -> AnimationPlayer:
	var node := find_node_by_path(node_path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null



func _list_animations(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var animations: Array = []
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		animations.append({
			"name": anim_name,
			"length": anim.length,
			"loop_mode": anim.loop_mode,
			"track_count": anim.get_track_count(),
		})

	return success({"node_path": node_path, "animations": animations, "count": animations.size()})



func _create_animation(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var length: float = float(params.get("length", 1.0))
	var loop_mode: int = int(params.get("loop_mode", 0))  # 0=none, 1=linear, 2=pingpong

	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = loop_mode as Animation.LoopMode

	var lib := player.get_animation_library("")
	var created_library := false
	if lib == null:
		lib = AnimationLibrary.new()
		created_library = true

	if lib.has_animation(anim_name):
		return error_invalid_params("Animation '%s' already exists" % anim_name)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Create animation %s" % anim_name)
	if created_library:
		undo_redo.add_do_method(player, "add_animation_library", "", lib)
		undo_redo.add_do_reference(lib)
		undo_redo.add_undo_method(player, "remove_animation_library", "")
	undo_redo.add_do_method(lib, "add_animation", anim_name, anim)
	undo_redo.add_do_reference(anim)
	undo_redo.add_undo_method(lib, "remove_animation", anim_name)
	undo_redo.commit_action()

	return success({"name": anim_name, "length": length, "created": true})



func _remove_animation(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var lib := player.get_animation_library("")
	if lib == null or not lib.has_animation(anim_name):
		return error_not_found("Animation '%s'" % anim_name)

	var anim := lib.get_animation(anim_name)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Remove animation %s" % anim_name)
	undo_redo.add_do_method(lib, "remove_animation", anim_name)
	undo_redo.add_undo_method(lib, "add_animation", anim_name, anim)
	undo_redo.add_undo_reference(anim)
	undo_redo.commit_action()
	return success({"name": anim_name, "removed": true})



func _rename_animation(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var r1 := require_string(params, "old_name")
	if r1[1] != null:
		return r1[1]
	var r2 := require_string(params, "new_name")
	if r2[1] != null:
		return r2[1]
	var lib_name: String = optional_string(params, "library", "")
	var lib := _get_lib(player, lib_name)
	if lib == null or not lib.has_animation(r1[0]):
		return error_not_found("Animation '%s'" % r1[0])
	if lib.has_animation(r2[0]):
		return error_invalid_params("Target name already exists: %s" % r2[0])
	var undo := get_undo_redo()
	undo.create_action("MCP: Rename animation")
	undo.add_do_method(lib, "rename_animation", r1[0], r2[0])
	undo.add_undo_method(lib, "rename_animation", r2[0], r1[0])
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"old_name": r1[0], "new_name": r2[0]})



func _duplicate_animation(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "name")
	if r1[1] != null:
		return r1[1]
	var new_name: String = optional_string(params, "new_name", str(r1[0]) + "_copy")
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var lib := _get_lib(player, optional_string(params, "library", ""))
	if lib == null or not lib.has_animation(r1[0]):
		return error_not_found("Animation '%s'" % r1[0])
	if lib.has_animation(new_name):
		return error_invalid_params("Already exists: %s" % new_name)
	var anim: Animation = lib.get_animation(r1[0]).duplicate(true) as Animation
	var undo := get_undo_redo()
	undo.create_action("MCP: Duplicate animation")
	undo.add_do_method(lib, "add_animation", new_name, anim)
	undo.add_do_reference(anim)
	undo.add_undo_method(lib, "remove_animation", new_name)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"name": new_name, "from": r1[0]})



func _get_animation_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "animation")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var anim := player.get_animation(anim_name)
	if anim == null:
		return error_not_found("Animation '%s'" % anim_name)

	var include_keys: bool = optional_bool(params, "include_keys", true)
	var max_keys: int = clampi(optional_int(params, "max_keys_per_track", 100), 1, 2000)
	const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")
	var tracks: Array = []
	for i in anim.get_track_count():
		var track_info := {
			"index": i,
			"path": str(anim.track_get_path(i)),
			"type": anim.track_get_type(i),
			"key_count": anim.track_get_key_count(i),
		}
		if include_keys:
			var keys: Array = []
			var kn := anim.track_get_key_count(i)
			var lim := mini(kn, max_keys)
			for k in range(lim):
				keys.append({
					"time": anim.track_get_key_time(i, k),
					"value": PropertyParser.serialize_value(anim.track_get_key_value(i, k)),
					"easing": anim.track_get_key_transition(i, k),
				})
			track_info["keys"] = keys
			track_info["keys_truncated"] = kn > max_keys
		tracks.append(track_info)

	return success({
		"name": anim_name,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"step": anim.step,
		"tracks": tracks,
		"hint": "For example->target workflow use dump_animation / apply_example_animation / compare_animations",
	})



func _set_animation_length(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := player.get_animation(r1[0])
	if anim == null:
		return error_not_found("Animation")
	var length: float = float(params.get("length", anim.length))
	var old := anim.length
	var undo := get_undo_redo()
	undo.create_action("MCP: Set animation length")
	undo.add_do_property(anim, "length", length)
	undo.add_undo_property(anim, "length", old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "length": anim.length})



func _set_animation_loop(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := player.get_animation(r1[0])
	if anim == null:
		return error_not_found("Animation")
	var loop_mode: int = int(params.get("loop_mode", 1))
	var old := anim.loop_mode
	var undo := get_undo_redo()
	undo.create_action("MCP: Set animation loop")
	undo.add_do_property(anim, "loop_mode", loop_mode)
	undo.add_undo_property(anim, "loop_mode", old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "loop_mode": anim.loop_mode})



func _ensure_reset_animation(params: Dictionary) -> Dictionary:
	## Docs: RESET defines default pose for blending (one frame at t=0).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var lib := _get_lib(player, "")
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	var created := false
	if not lib.has_animation("RESET"):
		var anim := Animation.new()
		anim.length = 0.001
		lib.add_animation("RESET", anim)
		created = true
	# Optional: snapshot listed property paths from current scene into RESET
	var paths: Array = params.get("property_paths", [])
	var anim_r: Animation = lib.get_animation("RESET")
	var added_tracks := 0
	if paths is Array and paths.size() > 0:
		var root := get_edited_root()
		for p in paths:
			var track_path := str(p)
			var node_and_prop := track_path.split(":", true, 1)
			if node_and_prop.size() < 2 or root == null:
				continue
			var n := root.get_node_or_null(NodePath(node_and_prop[0]))
			if n == null:
				n = find_node_by_path(node_and_prop[0])
			if n == null or not node_and_prop[1] in n:
				continue
			var val = n.get(node_and_prop[1])
			var idx := anim_r.add_track(Animation.TYPE_VALUE)
			anim_r.track_set_path(idx, NodePath(track_path))
			anim_r.track_insert_key(idx, 0.0, val)
			added_tracks += 1
	mark_current_scene_unsaved()
	return success({"created": created, "animation": "RESET", "tracks_added": added_tracks})



func _list_animation_libraries(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var libs: Array = []
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		var anims: Array = []
		if lib:
			for a in lib.get_animation_list():
				anims.append(str(a))
		libs.append({"name": str(lib_name), "animations": anims, "count": anims.size()})
	return success({"libraries": libs, "count": libs.size()})



func _add_animation_library(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "name")
	if r1[1] != null:
		return r1[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	if player.has_animation_library(r1[0]):
		return error_invalid_params("Library exists: %s" % r1[0])
	var lib := AnimationLibrary.new()
	var undo := get_undo_redo()
	undo.create_action("MCP: Add animation library")
	undo.add_do_method(player, "add_animation_library", r1[0], lib)
	undo.add_do_reference(lib)
	undo.add_undo_method(player, "remove_animation_library", r1[0])
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"library": r1[0], "created": true})



func _remove_animation_library(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "name")
	if r1[1] != null:
		return r1[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	if not player.has_animation_library(r1[0]):
		return error_not_found("Library '%s'" % r1[0])
	var lib := player.get_animation_library(r1[0])
	var undo := get_undo_redo()
	undo.create_action("MCP: Remove animation library")
	undo.add_do_method(player, "remove_animation_library", r1[0])
	undo.add_undo_method(player, "add_animation_library", r1[0], lib)
	undo.add_undo_reference(lib)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"library": r1[0], "removed": true})



func _get_lib(player: AnimationPlayer, lib_name: String = "") -> AnimationLibrary:
	return player.get_animation_library(lib_name)



