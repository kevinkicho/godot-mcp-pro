@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Animation tracks, keys, Bezier, bone map.

func get_commands() -> Dictionary:
	return {
		"add_animation_track": _add_animation_track,
		"remove_animation_track": _remove_animation_track,
		"set_animation_keyframe": _set_animation_keyframe,
		"remove_animation_key": _remove_animation_key,
		"insert_method_key": _insert_method_key,
		"insert_audio_key": _insert_audio_key,
		"insert_animation_playback_key": _insert_animation_playback_key,
		"set_track_enabled": _set_track_enabled,
		"set_track_interpolation": _set_track_interpolation,
		"set_bezier_key": _set_bezier_key,
		"get_bezier_key_info": _get_bezier_key_info,
		"apply_bone_map_to_skeleton": _apply_bone_map_to_skeleton,
	}

func _find_animation_player(node_path: String) -> AnimationPlayer:
	var node := find_node_by_path(node_path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null



func _get_lib(player: AnimationPlayer, lib_name: String = "") -> AnimationLibrary:
	return player.get_animation_library(lib_name)



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
	## Call Method Track key  -  docs: method name + args array at time
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



func _set_bezier_key(params: Dictionary) -> Dictionary:
	## Insert/update a Bezier track key with in/out handles (Animation editor parity).
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
	var track_path: String = optional_string(params, "track_path", "")
	if track_index < 0:
		if track_path.is_empty():
			return error_invalid_params("track_index or track_path required")
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_BEZIER and str(anim.track_get_path(i)) == track_path:
				track_index = i
				break
		if track_index < 0:
			track_index = anim.add_track(Animation.TYPE_BEZIER)
			anim.track_set_path(track_index, NodePath(track_path))
	if anim.track_get_type(track_index) != Animation.TYPE_BEZIER:
		return error_invalid_params("Track is not TYPE_BEZIER")
	var time: float = float(params.get("time", 0.0))
	var value: float = float(params.get("value", 0.0))
	var in_handle := Vector2(float(params.get("in_handle_x", params.get("in_x", -0.25))), float(params.get("in_handle_y", params.get("in_y", 0.0))))
	var out_handle := Vector2(float(params.get("out_handle_x", params.get("out_x", 0.25))), float(params.get("out_handle_y", params.get("out_y", 0.0))))
	var key_idx: int
	if anim.has_method("bezier_track_insert_key"):
		key_idx = anim.bezier_track_insert_key(track_index, time, value, in_handle, out_handle)
	else:
		key_idx = anim.track_insert_key(track_index, time, value)
		if anim.has_method("bezier_track_set_key_in_handle"):
			anim.bezier_track_set_key_in_handle(track_index, key_idx, in_handle)
			anim.bezier_track_set_key_out_handle(track_index, key_idx, out_handle)
	if params.has("key_index") and anim.has_method("bezier_track_set_key_value"):
		key_idx = int(params["key_index"])
		anim.bezier_track_set_key_value(track_index, key_idx, value)
		if anim.has_method("bezier_track_set_key_in_handle"):
			anim.bezier_track_set_key_in_handle(track_index, key_idx, in_handle)
			anim.bezier_track_set_key_out_handle(track_index, key_idx, out_handle)
	mark_current_scene_unsaved()
	return success({
		"animation": r1[0],
		"track_index": track_index,
		"key_index": key_idx,
		"time": time,
		"value": value,
		"in_handle": {"x": in_handle.x, "y": in_handle.y},
		"out_handle": {"x": out_handle.x, "y": out_handle.y},
	})



func _get_bezier_key_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var track_index: int = int(params.get("track_index", 0))
	var player := _find_animation_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := player.get_animation(r1[0])
	if anim == null:
		return error_not_found("Animation")
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	if anim.track_get_type(track_index) != Animation.TYPE_BEZIER:
		return error_invalid_params("Not a bezier track")
	var keys: Array = []
	var kc := anim.track_get_key_count(track_index)
	for i in kc:
		var entry := {
			"key_index": i,
			"time": anim.track_get_key_time(track_index, i),
		}
		if anim.has_method("bezier_track_get_key_value"):
			entry["value"] = anim.bezier_track_get_key_value(track_index, i)
		if anim.has_method("bezier_track_get_key_in_handle"):
			var ih: Vector2 = anim.bezier_track_get_key_in_handle(track_index, i)
			var oh: Vector2 = anim.bezier_track_get_key_out_handle(track_index, i)
			entry["in_handle"] = {"x": ih.x, "y": ih.y}
			entry["out_handle"] = {"x": oh.x, "y": oh.y}
		keys.append(entry)
	return success({
		"animation": r1[0],
		"track_index": track_index,
		"path": str(anim.track_get_path(track_index)),
		"keys": keys,
		"count": keys.size(),
	})



func _apply_bone_map_to_skeleton(params: Dictionary) -> Dictionary:
	## Apply BoneMap profile names as metadata on Skeleton3D bones (retarget prep).
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var map_path: String = optional_string(params, "bone_map_path", "")
	if map_path.is_empty():
		return error_invalid_params("bone_map_path to BoneMap .tres required")
	if not map_path.begins_with("res://"):
		map_path = "res://" + map_path.trim_prefix("/")
	var bm = load(map_path)
	if bm == null or not (bm is BoneMap):
		return error_not_found("BoneMap at %s" % map_path)
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null or not (node is Skeleton3D):
		return error_not_found("Skeleton3D")
	var sk: Skeleton3D = node
	var applied: Array = []
	# BoneMap maps profile bone name -> skeleton bone name
	if bm.profile:
		for i in bm.profile.get_bone_size() if bm.profile.has_method("get_bone_size") else 0:
			pass
	# Iterate known mappings via get_skeleton_bone_name if available
	if bm.has_method("get_skeleton_bone_name") and bm.profile and bm.profile.has_method("get_bone_size"):
		for i in range(bm.profile.get_bone_size()):
			var profile_name: StringName = bm.profile.get_bone_name(i) if bm.profile.has_method("get_bone_name") else StringName()
			if str(profile_name).is_empty():
				continue
			var sk_name: StringName = bm.get_skeleton_bone_name(profile_name)
			if str(sk_name).is_empty():
				continue
			var bi := sk.find_bone(str(sk_name))
			if bi >= 0:
				sk.set_bone_meta(bi, "retarget_profile_bone", str(profile_name))
				applied.append({"profile": str(profile_name), "skeleton_bone": str(sk_name), "index": bi})
	# Fallback: store whole map path on skeleton
	sk.set_meta("mcp_bone_map", map_path)
	mark_current_scene_unsaved()
	return success({
		"skeleton": r0[0],
		"bone_map_path": map_path,
		"mapped": applied.size(),
		"bones": applied,
		"hint": "Full Animation Retargeting importer is editor-side; this stamps profile metadata for agents/scripts",
	})

