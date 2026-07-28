@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		# AnimationPlayer library / clips
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
		# Tracks / keys (human Animation editor)
		"add_animation_track": _add_animation_track,
		"remove_animation_track": _remove_animation_track,
		"set_animation_keyframe": _set_animation_keyframe,
		"remove_animation_key": _remove_animation_key,
		"insert_method_key": _insert_method_key,
		"insert_audio_key": _insert_audio_key,
		"insert_animation_playback_key": _insert_animation_playback_key,
		"set_track_enabled": _set_track_enabled,
		"set_track_interpolation": _set_track_interpolation,
		# Playback (like pressing play in editor / code)
		"animation_player_play": _animation_player_play,
		"animation_player_stop": _animation_player_stop,
		"animation_player_seek": _animation_player_seek,
		"animation_player_queue": _animation_player_queue,
		"animation_player_get_current": _animation_player_get_current,
		"animation_player_set_autoplay": _animation_player_set_autoplay,
		"animation_player_set_speed": _animation_player_set_speed,
		"set_root_motion_track": _set_root_motion_track,
		# SpriteFrames
		"sprite_frames_create": _sprite_frames_create,
		"sprite_frames_add_animation": _sprite_frames_add_animation,
		"sprite_frames_add_frame": _sprite_frames_add_frame,
		"sprite_frames_assign": _sprite_frames_assign,
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


func _add_animation_track(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "animation")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var result3 := require_string(params, "track_path")
	if result3[1] != null:
		return result3[1]
	var track_path: String = result3[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var anim := player.get_animation(anim_name)
	if anim == null:
		return error_not_found("Animation '%s'" % anim_name)

	var track_type_str: String = optional_string(params, "track_type", "value")
	var track_type: int = _parse_track_type(track_type_str)

	var track_idx := anim.get_track_count()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add animation track")
	undo_redo.add_do_method(anim, "add_track", track_type, track_idx)
	undo_redo.add_do_method(anim, "track_set_path", track_idx, NodePath(track_path))

	var update_mode_str: String = optional_string(params, "update_mode", "")
	if not update_mode_str.is_empty() and track_type == Animation.TYPE_VALUE:
		match update_mode_str:
			"continuous": undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_CONTINUOUS)
			"discrete": undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_DISCRETE)
			"capture": undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_CAPTURE)
	undo_redo.add_undo_method(anim, "remove_track", track_idx)
	undo_redo.commit_action()

	return success({"track_index": track_idx, "track_path": track_path, "track_type": track_type_str})


func _set_animation_keyframe(params: Dictionary) -> Dictionary:
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

	var track_index: int = int(params.get("track_index", 0))
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index: %d" % track_index)

	var time: float = float(params.get("time", 0.0))
	var value = params.get("value")

	# Parse value string for common types
	if value is String:
		var s: String = value
		var expr := Expression.new()
		if expr.parse(s) == OK:
			var parsed = expr.execute()
			if parsed != null:
				value = parsed

	var easing: float = float(params.get("easing", 1.0))
	var old_key_idx := _find_animation_key_at_time(anim, track_index, time)
	var had_old_key := old_key_idx >= 0
	var old_value: Variant = anim.track_get_key_value(track_index, old_key_idx) if had_old_key else null
	var old_easing: float = anim.track_get_key_transition(track_index, old_key_idx) if had_old_key else 1.0

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set animation keyframe")
	undo_redo.add_do_method(self, "_upsert_animation_key", anim, track_index, time, value, easing)
	undo_redo.add_undo_method(self, "_restore_animation_key", anim, track_index, time, had_old_key, old_value, old_easing)
	undo_redo.commit_action()

	var key_idx := _find_animation_key_at_time(anim, track_index, time)

	return success({"track_index": track_index, "time": time, "key_index": key_idx, "easing": anim.track_get_key_transition(track_index, key_idx)})


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

	var tracks: Array = []
	for i in anim.get_track_count():
		var track_info := {
			"index": i,
			"path": str(anim.track_get_path(i)),
			"type": anim.track_get_type(i),
			"key_count": anim.track_get_key_count(i),
		}
		var keys: Array = []
		for k in anim.track_get_key_count(i):
			keys.append({
				"time": anim.track_get_key_time(i, k),
				"value": str(anim.track_get_key_value(i, k)),
				"easing": anim.track_get_key_transition(i, k),
			})
		track_info["keys"] = keys
		tracks.append(track_info)

	return success({
		"name": anim_name,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"step": anim.step,
		"tracks": tracks,
	})


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


func _find_animation_key_at_time(anim: Animation, track_index: int, time: float) -> int:
	for key_index: int in anim.track_get_key_count(track_index):
		if is_equal_approx(anim.track_get_key_time(track_index, key_index), time):
			return key_index
	return -1


func _upsert_animation_key(anim: Animation, track_index: int, time: float, value: Variant, easing: float) -> void:
	var key_idx := _find_animation_key_at_time(anim, track_index, time)
	if key_idx < 0:
		key_idx = anim.track_insert_key(track_index, time, value)
	else:
		anim.track_set_key_value(track_index, key_idx, value)
	if easing != 1.0:
		anim.track_set_key_transition(track_index, key_idx, easing)


func _restore_animation_key(anim: Animation, track_index: int, time: float, had_old_key: bool, old_value: Variant, old_easing: float) -> void:
	var key_idx := _find_animation_key_at_time(anim, track_index, time)
	if had_old_key:
		if key_idx < 0:
			key_idx = anim.track_insert_key(track_index, time, old_value)
		else:
			anim.track_set_key_value(track_index, key_idx, old_value)
		anim.track_set_key_transition(track_index, key_idx, old_easing)
	elif key_idx >= 0:
		anim.track_remove_key(track_index, key_idx)

func _sprite_frames_create(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var sf := SpriteFrames.new()
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(sf, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "type": "SpriteFrames"})


func _sprite_frames_add_animation(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var result := require_string(params, "animation")
	if result[1] != null:
		return result[1]
	var path: String = res_path[0]
	var anim: String = result[0]
	var sf: SpriteFrames = load(path) as SpriteFrames
	if sf == null:
		return error_internal("Not SpriteFrames: %s" % path)
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	sf.set_animation_speed(anim, float(params.get("speed", 5.0)))
	sf.set_animation_loop(anim, optional_bool(params, "loop", true))
	var err := ResourceSaver.save(sf, path)
	if err != OK:
		return error_internal(error_string(err))
	return success({"path": path, "animation": anim})


func _sprite_frames_add_frame(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var result := require_string(params, "animation")
	if result[1] != null:
		return result[1]
	var tex_r := require_res_path(params, "texture_path")
	if tex_r[1] != null:
		return tex_r[1]
	var path: String = res_path[0]
	var anim: String = result[0]
	var sf: SpriteFrames = load(path) as SpriteFrames
	if sf == null:
		return error_internal("Not SpriteFrames")
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	var tex: Texture2D = load(tex_r[0]) as Texture2D
	if tex == null:
		return error_not_found(tex_r[0])
	var duration: float = float(params.get("duration", 1.0))
	sf.add_frame(anim, tex, duration)
	var err := ResourceSaver.save(sf, path)
	if err != OK:
		return error_internal(error_string(err))
	return success({"path": path, "animation": anim, "frame_count": sf.get_frame_count(anim)})


func _sprite_frames_assign(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var res_path := require_res_path(params, "sprite_frames_path")
	if res_path[1] != null:
		return res_path[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node")
	if not (node is AnimatedSprite2D or node is AnimatedSprite3D):
		return error_invalid_params("Node must be AnimatedSprite2D/3D")
	var sf: SpriteFrames = load(res_path[0]) as SpriteFrames
	if sf == null:
		return error_internal("Failed to load SpriteFrames")
	var undo := get_undo_redo()
	undo.create_action("MCP: Assign SpriteFrames")
	undo.add_do_property(node, "sprite_frames", sf)
	undo.add_undo_property(node, "sprite_frames", node.get("sprite_frames"))
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "sprite_frames_path": res_path[0]})

func _parse_track_type(track_type_str: String) -> int:
	match track_type_str:
		"value", "property":
			return Animation.TYPE_VALUE
		"position_3d", "position", "position_2d":
			return Animation.TYPE_POSITION_3D
		"rotation_3d", "rotation", "rotation_2d":
			return Animation.TYPE_ROTATION_3D
		"scale_3d", "scale", "scale_2d":
			return Animation.TYPE_SCALE_3D
		"method", "call_method":
			return Animation.TYPE_METHOD
		"bezier":
			return Animation.TYPE_BEZIER
		"audio":
			return Animation.TYPE_AUDIO
		"animation", "animation_playback":
			return Animation.TYPE_ANIMATION
		"blend_shape":
			return Animation.TYPE_BLEND_SHAPE
		_:
			return Animation.TYPE_VALUE


func _get_lib(player: AnimationPlayer, lib_name: String = "") -> AnimationLibrary:
	return player.get_animation_library(lib_name)


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


func _remove_animation_track(params: Dictionary) -> Dictionary:
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
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	anim.remove_track(track_index)
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "removed_track": track_index, "track_count": anim.get_track_count()})


func _remove_animation_key(params: Dictionary) -> Dictionary:
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
	var track_index: int = int(params.get("track_index", 0))
	var key_index: int = int(params.get("key_index", -1))
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	if key_index < 0:
		var time: float = float(params.get("time", 0.0))
		key_index = _find_animation_key_at_time(anim, track_index, time)
	if key_index < 0 or key_index >= anim.track_get_key_count(track_index):
		return error_not_found("Key")
	anim.track_remove_key(track_index, key_index)
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "track_index": track_index, "removed_key": key_index})


func _insert_method_key(params: Dictionary) -> Dictionary:
	## Call Method Track key — docs: method name + args array at time
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var r2 := require_string(params, "method")
	if r2[1] != null:
		return r2[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := player.get_animation(r1[0])
	if anim == null:
		return error_not_found("Animation")
	var track_path: String = optional_string(params, "track_path", ".")
	var time: float = float(params.get("time", 0.0))
	var args: Array = params.get("args", [])
	if not args is Array:
		args = []
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0:
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_METHOD and str(anim.track_get_path(i)) == track_path:
				track_index = i
				break
		if track_index < 0:
			track_index = anim.add_track(Animation.TYPE_METHOD)
			anim.track_set_path(track_index, NodePath(track_path))
	var key_idx: int
	if anim.has_method("method_track_insert_key"):
		key_idx = anim.method_track_insert_key(track_index, time, StringName(r2[0]), args)
	else:
		key_idx = anim.track_insert_key(track_index, time, {"method": StringName(r2[0]), "args": args})
	mark_current_scene_unsaved()
	return success({
		"animation": r1[0],
		"track_index": track_index,
		"key_index": key_idx,
		"time": time,
		"method": r2[0],
		"args": args,
	})


func _insert_audio_key(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var stream_r := require_res_path(params, "stream_path")
	if stream_r[1] != null:
		return stream_r[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := player.get_animation(r1[0])
	if anim == null:
		return error_not_found("Animation")
	var track_path: String = optional_string(params, "track_path", "")
	if track_path.is_empty():
		return error_invalid_params("track_path to AudioStreamPlayer* required")
	var time: float = float(params.get("time", 0.0))
	var stream: AudioStream = load(stream_r[0]) as AudioStream
	if stream == null:
		return error_not_found("AudioStream %s" % stream_r[0])
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0:
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_AUDIO and str(anim.track_get_path(i)) == track_path:
				track_index = i
				break
		if track_index < 0:
			track_index = anim.add_track(Animation.TYPE_AUDIO)
			anim.track_set_path(track_index, NodePath(track_path))
	var start_offset: float = float(params.get("start_offset", 0.0))
	var end_offset: float = float(params.get("end_offset", 0.0))
	var key_idx: int
	if anim.has_method("audio_track_insert_key"):
		key_idx = anim.audio_track_insert_key(track_index, time, stream, start_offset, end_offset)
	else:
		key_idx = anim.track_insert_key(track_index, time, stream)
	mark_current_scene_unsaved()
	return success({
		"animation": r1[0],
		"track_index": track_index,
		"key_index": key_idx,
		"stream_path": stream_r[0],
		"time": time,
	})


func _insert_animation_playback_key(params: Dictionary) -> Dictionary:
	## Nested AnimationPlayer playback track
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var nested: String = optional_string(params, "play_animation", "")
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := player.get_animation(r1[0])
	if anim == null:
		return error_not_found("Animation")
	var track_path: String = optional_string(params, "track_path", "")
	if track_path.is_empty():
		return error_invalid_params("track_path to target AnimationPlayer required")
	var time: float = float(params.get("time", 0.0))
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0:
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_ANIMATION and str(anim.track_get_path(i)) == track_path:
				track_index = i
				break
		if track_index < 0:
			track_index = anim.add_track(Animation.TYPE_ANIMATION)
			anim.track_set_path(track_index, NodePath(track_path))
	# STOP is empty string in some versions; use "[STOP]" as docs inspector shows
	var key_val: String = nested if not nested.is_empty() else "[STOP]"
	var key_idx := anim.track_insert_key(track_index, time, key_val)
	mark_current_scene_unsaved()
	return success({
		"animation": r1[0],
		"track_index": track_index,
		"key_index": key_idx,
		"play_animation": key_val,
		"time": time,
	})


func _set_track_enabled(params: Dictionary) -> Dictionary:
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
	var track_index: int = int(params.get("track_index", 0))
	var enabled: bool = optional_bool(params, "enabled", true)
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	anim.track_set_enabled(track_index, enabled)
	mark_current_scene_unsaved()
	return success({"track_index": track_index, "enabled": enabled})


func _set_track_interpolation(params: Dictionary) -> Dictionary:
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
	var track_index: int = int(params.get("track_index", 0))
	var mode_str: String = optional_string(params, "interpolation", "linear")
	var mode: int = Animation.INTERPOLATION_LINEAR
	match mode_str:
		"nearest": mode = Animation.INTERPOLATION_NEAREST
		"linear": mode = Animation.INTERPOLATION_LINEAR
		"cubic": mode = Animation.INTERPOLATION_CUBIC
		"linear_angle": mode = Animation.INTERPOLATION_LINEAR_ANGLE
		"cubic_angle": mode = Animation.INTERPOLATION_CUBIC_ANGLE
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	anim.track_set_interpolation_type(track_index, mode)
	mark_current_scene_unsaved()
	return success({"track_index": track_index, "interpolation": mode_str})


func _animation_player_play(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim_name: String = optional_string(params, "animation", "")
	var custom_blend: float = float(params.get("custom_blend", -1.0))
	var custom_speed: float = float(params.get("custom_speed", 1.0))
	var from_end: bool = optional_bool(params, "from_end", false)
	if anim_name.is_empty():
		player.play()
	else:
		player.play(anim_name, custom_blend, custom_speed, from_end)
	return success({
		"playing": player.is_playing(),
		"current": player.current_animation,
		"position": player.current_animation_position,
	})


func _animation_player_stop(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var keep_state: bool = optional_bool(params, "keep_state", false)
	player.stop(keep_state)
	return success({"stopped": true, "keep_state": keep_state})


func _animation_player_seek(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var seconds: float = float(params.get("time", params.get("seconds", 0.0)))
	var update: bool = optional_bool(params, "update", true)
	player.seek(seconds, update)
	return success({"position": player.current_animation_position, "current": player.current_animation})


func _animation_player_queue(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	player.queue(r1[0])
	return success({"queued": r1[0], "current": player.current_animation})


func _animation_player_get_current(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	return success({
		"is_playing": player.is_playing(),
		"current_animation": player.current_animation,
		"position": player.current_animation_position,
		"length": player.current_animation_length,
		"speed_scale": player.speed_scale,
		"autoplay": player.autoplay,
		"assigned_animation": player.assigned_animation,
	})


func _animation_player_set_autoplay(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim_name: String = optional_string(params, "animation", "")
	var old := player.autoplay
	player.autoplay = anim_name
	mark_current_scene_unsaved()
	return success({"autoplay": player.autoplay, "old": old})


func _animation_player_set_speed(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var speed: float = float(params.get("speed_scale", params.get("speed", 1.0)))
	player.speed_scale = speed
	mark_current_scene_unsaved()
	return success({"speed_scale": player.speed_scale})


func _set_root_motion_track(params: Dictionary) -> Dictionary:
	## AnimationMixer / AnimationPlayer root motion track path
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var track: String = optional_string(params, "track", "")
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not ("root_motion_track" in node):
		return error_invalid_params("Node has no root_motion_track (need AnimationPlayer/AnimationTree/AnimationMixer)")
	var old = node.get("root_motion_track")
	node.set("root_motion_track", NodePath(track))
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"root_motion_track": str(node.get("root_motion_track")),
		"old": str(old),
	})
