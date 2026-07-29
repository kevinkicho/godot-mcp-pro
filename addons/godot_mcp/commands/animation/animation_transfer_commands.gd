@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Example-based animation transfer & fine-tune.
## Agents: inspect example → copy → remap paths → scale/offset → keyframe tune → playtest.

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")


func get_commands() -> Dictionary:
	return {
		"dump_animation": _dump_animation,
		"list_animation_tracks": _list_animation_tracks,
		"get_track_keys": _get_track_keys,
		"sample_animation_at_time": _sample_animation_at_time,
		"compare_animations": _compare_animations,
		"copy_animation_to_player": _copy_animation_to_player,
		"copy_animation_track": _copy_animation_track,
		"remap_animation_track_paths": _remap_animation_track_paths,
		"set_animation_track_path": _set_animation_track_path,
		"scale_animation_time": _scale_animation_time,
		"offset_animation_keys": _offset_animation_keys,
		"crop_animation": _crop_animation,
		"clear_animation_track_keys": _clear_animation_track_keys,
		"save_animation_resource": _save_animation_resource,
		"load_animation_resource": _load_animation_resource,
		"extract_animations_from_scene": _extract_animations_from_scene,
		"apply_example_animation": _apply_example_animation,
		"list_animation_fine_tune_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"example_to_target_flow": [
			"extract_animations_from_scene OR list_animations on example player",
			"dump_animation / get_animation_info (include full keys)",
			"apply_example_animation OR copy_animation_to_player",
			"remap_animation_track_paths if hierarchy differs",
			"scale_animation_time / offset_animation_keys as needed",
			"set_animation_keyframe / set_bezier_key for fine-tune",
			"animation_player_play + get_game_screenshot / assert",
		],
		"tools": get_commands().keys(),
		"related": [
			"list_animations", "get_animation_info", "duplicate_animation",
			"set_animation_keyframe", "set_bezier_key", "create_animation_tree",
		],
	})


func _find_player(node_path: String) -> AnimationPlayer:
	var node := find_node_by_path(node_path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null


func _get_anim(player: AnimationPlayer, name_str: String) -> Animation:
	if player == null or name_str.is_empty():
		return null
	return player.get_animation(name_str)


func _track_type_name(t: int) -> String:
	match t:
		Animation.TYPE_VALUE: return "value"
		Animation.TYPE_POSITION_3D: return "position_3d"
		Animation.TYPE_ROTATION_3D: return "rotation_3d"
		Animation.TYPE_SCALE_3D: return "scale_3d"
		Animation.TYPE_BLEND_SHAPE: return "blend_shape"
		Animation.TYPE_METHOD: return "method"
		Animation.TYPE_BEZIER: return "bezier"
		Animation.TYPE_AUDIO: return "audio"
		Animation.TYPE_ANIMATION: return "animation"
		_: return "type_%d" % t


func _serialize_key_value(v: Variant) -> Variant:
	return PropertyParser.serialize_value(v)


func _dump_track(anim: Animation, i: int, include_keys: bool, max_keys: int) -> Dictionary:
	var info := {
		"index": i,
		"path": str(anim.track_get_path(i)),
		"type": anim.track_get_type(i),
		"type_name": _track_type_name(anim.track_get_type(i)),
		"enabled": anim.track_is_enabled(i),
		"key_count": anim.track_get_key_count(i),
		"interpolation": anim.track_get_interpolation_type(i) if anim.has_method("track_get_interpolation_type") else null,
	}
	if anim.track_get_type(i) == Animation.TYPE_VALUE and anim.has_method("value_track_get_update_mode"):
		info["update_mode"] = anim.value_track_get_update_mode(i)
	if include_keys:
		var keys: Array = []
		var n := anim.track_get_key_count(i)
		var lim := mini(n, max_keys)
		for k in range(lim):
			var entry := {
				"key_index": k,
				"time": anim.track_get_key_time(i, k),
				"value": _serialize_key_value(anim.track_get_key_value(i, k)),
				"transition": anim.track_get_key_transition(i, k),
			}
			if anim.track_get_type(i) == Animation.TYPE_BEZIER and anim.has_method("bezier_track_get_key_in_handle"):
				var ih: Vector2 = anim.bezier_track_get_key_in_handle(i, k)
				var oh: Vector2 = anim.bezier_track_get_key_out_handle(i, k)
				entry["in_handle"] = {"x": ih.x, "y": ih.y}
				entry["out_handle"] = {"x": oh.x, "y": oh.y}
				if anim.has_method("bezier_track_get_key_value"):
					entry["value"] = anim.bezier_track_get_key_value(i, k)
			keys.append(entry)
		info["keys"] = keys
		info["keys_truncated"] = n > max_keys
	return info


func _dump_animation(params: Dictionary) -> Dictionary:
	## Full agent-readable dump of a clip (example or target).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation '%s'" % r1[0])
	var include_keys: bool = optional_bool(params, "include_keys", true)
	var max_keys: int = clampi(optional_int(params, "max_keys_per_track", 200), 1, 2000)
	var tracks: Array = []
	for i in anim.get_track_count():
		tracks.append(_dump_track(anim, i, include_keys, max_keys))
	return success({
		"node_path": r0[0],
		"name": r1[0],
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"step": anim.step,
		"track_count": anim.get_track_count(),
		"tracks": tracks,
		"hint": "Use compare_animations / apply_example_animation / set_animation_keyframe to fine-tune",
	})


func _list_animation_tracks(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var tracks: Array = []
	for i in anim.get_track_count():
		tracks.append(_dump_track(anim, i, false, 0))
	return success({"animation": r1[0], "tracks": tracks, "count": tracks.size()})


func _get_track_keys(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var track_index: int = int(params.get("track_index", 0))
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	var max_keys: int = clampi(optional_int(params, "max_keys", 500), 1, 5000)
	return success({
		"animation": r1[0],
		"track": _dump_track(anim, track_index, true, max_keys),
	})


func _sample_animation_at_time(params: Dictionary) -> Dictionary:
	## Sample interpolated values at time t (for matching example pose).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var time: float = float(params.get("time", 0.0))
	var samples: Array = []
	for i in anim.get_track_count():
		var ttype := anim.track_get_type(i)
		var entry := {
			"track_index": i,
			"path": str(anim.track_get_path(i)),
			"type_name": _track_type_name(ttype),
		}
		match ttype:
			Animation.TYPE_VALUE:
				if anim.has_method("value_track_interpolate"):
					entry["value"] = _serialize_key_value(anim.value_track_interpolate(i, time))
				else:
					entry["value"] = _serialize_key_value(_nearest_key_value(anim, i, time))
			Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D:
				if anim.has_method("position_track_interpolate") and ttype == Animation.TYPE_POSITION_3D:
					entry["value"] = _serialize_key_value(anim.position_track_interpolate(i, time))
				elif anim.has_method("rotation_track_interpolate") and ttype == Animation.TYPE_ROTATION_3D:
					entry["value"] = _serialize_key_value(anim.rotation_track_interpolate(i, time))
				elif anim.has_method("scale_track_interpolate") and ttype == Animation.TYPE_SCALE_3D:
					entry["value"] = _serialize_key_value(anim.scale_track_interpolate(i, time))
				else:
					entry["value"] = _serialize_key_value(_nearest_key_value(anim, i, time))
			Animation.TYPE_BEZIER:
				if anim.has_method("bezier_track_interpolate"):
					entry["value"] = anim.bezier_track_interpolate(i, time)
				else:
					entry["value"] = _nearest_key_value(anim, i, time)
			_:
				entry["value"] = _serialize_key_value(_nearest_key_value(anim, i, time))
		samples.append(entry)
	return success({"animation": r1[0], "time": time, "samples": samples, "count": samples.size()})


func _nearest_key_value(anim: Animation, track: int, time: float) -> Variant:
	var best := -1
	var best_dt := 1e30
	for k in anim.track_get_key_count(track):
		var dt := absf(anim.track_get_key_time(track, k) - time)
		if dt < best_dt:
			best_dt = dt
			best = k
	if best < 0:
		return null
	return anim.track_get_key_value(track, best)


func _compare_animations(params: Dictionary) -> Dictionary:
	## Diff example vs target for agent fine-tune planning.
	var src_player_path: String = optional_string(params, "source_node_path", optional_string(params, "node_path", ""))
	var src_anim_name: String = optional_string(params, "source_animation", optional_string(params, "animation", ""))
	var dst_player_path: String = optional_string(params, "target_node_path", "")
	var dst_anim_name: String = optional_string(params, "target_animation", "")
	if src_player_path.is_empty() or src_anim_name.is_empty():
		return error_invalid_params("source_node_path + source_animation required")
	if dst_player_path.is_empty():
		dst_player_path = src_player_path
	if dst_anim_name.is_empty():
		return error_invalid_params("target_animation required")
	var sp := _find_player(src_player_path)
	var dp := _find_player(dst_player_path)
	if sp == null or dp == null:
		return error_not_found("AnimationPlayer source/target")
	var sa := _get_anim(sp, src_anim_name)
	var da := _get_anim(dp, dst_anim_name)
	if sa == null or da == null:
		return error_not_found("Animation clip missing")
	var src_paths := {}
	for i in sa.get_track_count():
		src_paths[str(sa.track_get_path(i))] = {
			"index": i,
			"type": _track_type_name(sa.track_get_type(i)),
			"keys": sa.track_get_key_count(i),
		}
	var dst_paths := {}
	for i in da.get_track_count():
		dst_paths[str(da.track_get_path(i))] = {
			"index": i,
			"type": _track_type_name(da.track_get_type(i)),
			"keys": da.track_get_key_count(i),
		}
	var only_source: Array = []
	var only_target: Array = []
	var both: Array = []
	for p in src_paths:
		if dst_paths.has(p):
			both.append({
				"path": p,
				"source": src_paths[p],
				"target": dst_paths[p],
				"key_delta": int(dst_paths[p]["keys"]) - int(src_paths[p]["keys"]),
			})
		else:
			only_source.append({"path": p, "source": src_paths[p]})
	for p in dst_paths:
		if not src_paths.has(p):
			only_target.append({"path": p, "target": dst_paths[p]})
	return success({
		"source": {"player": src_player_path, "animation": src_anim_name, "length": sa.length, "tracks": sa.get_track_count()},
		"target": {"player": dst_player_path, "animation": dst_anim_name, "length": da.length, "tracks": da.get_track_count()},
		"length_delta": da.length - sa.length,
		"paths_only_in_source": only_source,
		"paths_only_in_target": only_target,
		"paths_in_both": both,
		"hint": "remap_animation_track_paths for hierarchy mismatch; copy_animation_track for missing tracks",
	})


func _copy_animation_resource(src: Animation) -> Animation:
	return src.duplicate(true) as Animation


func _copy_animation_to_player(params: Dictionary) -> Dictionary:
	## Copy clip from one AnimationPlayer to another (same or different scene node).
	var src_path: String = optional_string(params, "source_node_path", "")
	var src_name: String = optional_string(params, "source_animation", "")
	var dst_path: String = optional_string(params, "target_node_path", "")
	var dst_name: String = optional_string(params, "target_animation", "")
	if src_path.is_empty() or src_name.is_empty() or dst_path.is_empty():
		return error_invalid_params("source_node_path, source_animation, target_node_path required")
	if dst_name.is_empty():
		dst_name = src_name
	var sp := _find_player(src_path)
	var dp := _find_player(dst_path)
	if sp == null or dp == null:
		return error_not_found("AnimationPlayer")
	var sa := _get_anim(sp, src_name)
	if sa == null:
		return error_not_found("Source animation")
	var copy := _copy_animation_resource(sa)
	var overwrite: bool = optional_bool(params, "overwrite", true)
	var lib_name: String = optional_string(params, "library", "")
	var lib: AnimationLibrary = dp.get_animation_library(lib_name)
	if lib == null:
		lib = AnimationLibrary.new()
		dp.add_animation_library(lib_name, lib)
	if lib.has_animation(dst_name):
		if not overwrite:
			return error_invalid_params("Target animation exists: %s" % dst_name)
		lib.remove_animation(dst_name)
	lib.add_animation(dst_name, copy)
	mark_current_scene_unsaved()
	return success({
		"source": {"player": src_path, "animation": src_name},
		"target": {"player": dst_path, "animation": dst_name},
		"track_count": copy.get_track_count(),
		"length": copy.length,
		"hint": "remap_animation_track_paths if node paths differ from example",
	})


func _copy_animation_track(params: Dictionary) -> Dictionary:
	var src_path: String = optional_string(params, "source_node_path", "")
	var src_name: String = optional_string(params, "source_animation", "")
	var dst_path: String = optional_string(params, "target_node_path", "")
	var dst_name: String = optional_string(params, "target_animation", "")
	var track_index: int = int(params.get("track_index", -1))
	var track_path_filter: String = optional_string(params, "track_path", "")
	if src_path.is_empty() or src_name.is_empty() or dst_path.is_empty() or dst_name.is_empty():
		return error_invalid_params("source/target player + animation names required")
	var sp := _find_player(src_path)
	var dp := _find_player(dst_path)
	var sa := _get_anim(sp, src_name)
	var da := _get_anim(dp, dst_name)
	if sa == null or da == null:
		return error_not_found("Animation")
	if track_index < 0 and not track_path_filter.is_empty():
		for i in sa.get_track_count():
			if str(sa.track_get_path(i)) == track_path_filter:
				track_index = i
				break
	if track_index < 0 or track_index >= sa.get_track_count():
		return error_invalid_params("track_index or track_path required")
	var new_idx := da.add_track(sa.track_get_type(track_index))
	da.track_set_path(new_idx, sa.track_get_path(track_index))
	if sa.track_get_type(track_index) == Animation.TYPE_VALUE and sa.has_method("value_track_get_update_mode"):
		da.value_track_set_update_mode(new_idx, sa.value_track_get_update_mode(track_index))
	for k in sa.track_get_key_count(track_index):
		var t := sa.track_get_key_time(track_index, k)
		var v = sa.track_get_key_value(track_index, k)
		var tr := sa.track_get_key_transition(track_index, k)
		da.track_insert_key(new_idx, t, v, tr)
	mark_current_scene_unsaved()
	return success({
		"source_track": track_index,
		"target_track": new_idx,
		"path": str(da.track_get_path(new_idx)),
		"keys_copied": sa.track_get_key_count(track_index),
	})


func _remap_animation_track_paths(params: Dictionary) -> Dictionary:
	## Replace path prefixes (example Armature/… → target character paths).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var player := _find_player(r0[0])
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var from_prefix: String = optional_string(params, "from_prefix", "")
	var to_prefix: String = optional_string(params, "to_prefix", "")
	var replacements: Dictionary = params.get("replacements", {})  # exact path -> new path
	if from_prefix.is_empty() and replacements.is_empty():
		return error_invalid_params("from_prefix+to_prefix and/or replacements map required")
	var changed: Array = []
	for i in anim.get_track_count():
		var old_p := str(anim.track_get_path(i))
		var new_p := old_p
		if replacements is Dictionary and replacements.has(old_p):
			new_p = str(replacements[old_p])
		elif not from_prefix.is_empty() and old_p.begins_with(from_prefix):
			new_p = to_prefix + old_p.substr(from_prefix.length())
		if new_p != old_p:
			anim.track_set_path(i, NodePath(new_p))
			changed.append({"track": i, "from": old_p, "to": new_p})
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "remapped": changed, "count": changed.size()})


func _set_animation_track_path(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var r2 := require_string(params, "path")
	if r2[1] != null:
		return r2[1]
	var player := _find_player(r0[0])
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var track_index: int = int(params.get("track_index", 0))
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	var old_p := str(anim.track_get_path(track_index))
	anim.track_set_path(track_index, NodePath(r2[0]))
	mark_current_scene_unsaved()
	return success({"track_index": track_index, "from": old_p, "to": r2[0]})


func _scale_animation_time(params: Dictionary) -> Dictionary:
	## Scale all key times and length (speed up / slow down example).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var scale: float = float(params.get("scale", params.get("time_scale", 1.0)))
	if scale <= 0.0:
		return error_invalid_params("scale must be > 0")
	var player := _find_player(r0[0])
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var old_len := anim.length
	for i in anim.get_track_count():
		# Walk keys reverse when scaling >1 to avoid collisions, or rebuild times
		var times: Array = []
		var values: Array = []
		var trans: Array = []
		for k in anim.track_get_key_count(i):
			times.append(anim.track_get_key_time(i, k) * scale)
			values.append(anim.track_get_key_value(i, k))
			trans.append(anim.track_get_key_transition(i, k))
		# Clear and reinsert
		while anim.track_get_key_count(i) > 0:
			anim.track_remove_key(i, 0)
		for k in times.size():
			anim.track_insert_key(i, float(times[k]), values[k], float(trans[k]))
	anim.length = old_len * scale
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "scale": scale, "old_length": old_len, "new_length": anim.length})


func _offset_animation_keys(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var offset: float = float(params.get("offset", params.get("delta", 0.0)))
	var player := _find_player(r0[0])
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var track_index: int = int(params.get("track_index", -1))
	var tracks: Array = []
	if track_index >= 0:
		tracks.append(track_index)
	else:
		for i in anim.get_track_count():
			tracks.append(i)
	for i in tracks:
		var ti: int = int(i)
		if ti < 0 or ti >= anim.get_track_count():
			continue
		var n := anim.track_get_key_count(ti)
		# Collect then rewrite
		var bag: Array = []
		for k in n:
			bag.append({
				"t": anim.track_get_key_time(ti, k) + offset,
				"v": anim.track_get_key_value(ti, k),
				"tr": anim.track_get_key_transition(ti, k),
			})
		while anim.track_get_key_count(ti) > 0:
			anim.track_remove_key(ti, 0)
		for item in bag:
			if float(item["t"]) < 0.0:
				continue
			anim.track_insert_key(ti, float(item["t"]), item["v"], float(item["tr"]))
	if optional_bool(params, "extend_length", true):
		var max_t := anim.length
		for i in anim.get_track_count():
			for k in anim.track_get_key_count(i):
				max_t = maxf(max_t, anim.track_get_key_time(i, k))
		anim.length = max_t
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "offset": offset, "length": anim.length})


func _crop_animation(params: Dictionary) -> Dictionary:
	## Keep keys within [start, end], shift so start→0.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var start_t: float = float(params.get("start", 0.0))
	var end_t: float = float(params.get("end", -1.0))
	var player := _find_player(r0[0])
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	if end_t < 0.0:
		end_t = anim.length
	for i in anim.get_track_count():
		var bag: Array = []
		for k in anim.track_get_key_count(i):
			var t := anim.track_get_key_time(i, k)
			if t >= start_t and t <= end_t:
				bag.append({
					"t": t - start_t,
					"v": anim.track_get_key_value(i, k),
					"tr": anim.track_get_key_transition(i, k),
				})
		while anim.track_get_key_count(i) > 0:
			anim.track_remove_key(i, 0)
		for item in bag:
			anim.track_insert_key(i, float(item["t"]), item["v"], float(item["tr"]))
	anim.length = maxf(0.01, end_t - start_t)
	mark_current_scene_unsaved()
	return success({"animation": r1[0], "start": start_t, "end": end_t, "length": anim.length})


func _clear_animation_track_keys(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var track_index: int = int(params.get("track_index", 0))
	var player := _find_player(r0[0])
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index")
	var removed := anim.track_get_key_count(track_index)
	while anim.track_get_key_count(track_index) > 0:
		anim.track_remove_key(track_index, 0)
	mark_current_scene_unsaved()
	return success({"track_index": track_index, "keys_removed": removed})


func _save_animation_resource(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return r1[1]
	var path: String = optional_string(params, "path", "res://animations/%s.res" % r1[0])
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var player := _find_player(r0[0])
	var anim := _get_anim(player, r1[0])
	if anim == null:
		return error_not_found("Animation")
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var copy := anim.duplicate(true) as Animation
	var err := ResourceSaver.save(copy, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "animation": r1[0], "length": copy.length})


func _load_animation_resource(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var anim_name: String = optional_string(params, "animation", optional_string(params, "name", res[0].get_file().get_basename()))
	var player := _find_player(r0[0])
	if player == null:
		return error_not_found("AnimationPlayer")
	var loaded = load(res[0])
	if loaded == null or not (loaded is Animation):
		return error_invalid_params("Not an Animation resource: %s" % res[0])
	var anim: Animation = (loaded as Animation).duplicate(true) as Animation
	var lib_name: String = optional_string(params, "library", "")
	var lib: AnimationLibrary = player.get_animation_library(lib_name)
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library(lib_name, lib)
	if lib.has_animation(anim_name):
		if optional_bool(params, "overwrite", true):
			lib.remove_animation(anim_name)
		else:
			return error_invalid_params("Exists: %s" % anim_name)
	lib.add_animation(anim_name, anim)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "animation": anim_name, "from": res[0], "tracks": anim.get_track_count()})


func _extract_animations_from_scene(params: Dictionary) -> Dictionary:
	## Load an example .tscn and list AnimationPlayer clips (optional copy into open scene).
	var res := require_res_path(params, "scene_path")
	if res[1] != null:
		return res[1]
	if not ResourceLoader.exists(res[0]):
		return error_not_found(res[0])
	var packed: PackedScene = load(res[0]) as PackedScene
	if packed == null:
		return error_internal("Not a PackedScene")
	var inst := packed.instantiate()
	if inst == null:
		return error_internal("Failed to instantiate")
	var players: Array = []
	_find_players_recursive(inst, players, inst)
	var out: Array = []
	for item in players:
		var p: AnimationPlayer = item["player"]
		var clips: Array = []
		for lib_name in p.get_animation_library_list():
			var lib: AnimationLibrary = p.get_animation_library(lib_name)
			for aname in lib.get_animation_list():
				var a: Animation = lib.get_animation(aname)
				clips.append({
					"name": aname,
					"library": lib_name,
					"length": a.length if a else 0.0,
					"tracks": a.get_track_count() if a else 0,
				})
		out.append({
			"node_path": item["path"],
			"player_name": p.name,
			"animations": clips,
		})
	var copy_to: String = optional_string(params, "copy_to_node_path", "")
	var copy_anim: String = optional_string(params, "copy_animation", "")
	var copied := {}
	if not copy_to.is_empty() and not copy_anim.is_empty() and out.size() > 0:
		for item in players:
			var p: AnimationPlayer = item["player"]
			if p.has_animation(copy_anim):
				var target := _find_player(copy_to)
				if target:
					var lib_name: String = optional_string(params, "library", "")
					var lib: AnimationLibrary = target.get_animation_library(lib_name)
					if lib == null:
						lib = AnimationLibrary.new()
						target.add_animation_library(lib_name, lib)
					var new_name: String = optional_string(params, "target_animation", copy_anim)
					var a: Animation = p.get_animation(copy_anim).duplicate(true) as Animation
					if lib.has_animation(new_name):
						lib.remove_animation(new_name)
					lib.add_animation(new_name, a)
					mark_current_scene_unsaved()
					copied = {"to": copy_to, "animation": new_name, "tracks": a.get_track_count()}
				break
	inst.queue_free()
	return success({
		"scene_path": res[0],
		"animation_players": out,
		"copied": copied,
		"hint": "apply_example_animation or copy_animation_to_player after opening both scenes / extracting",
	})


func _find_players_recursive(node: Node, out: Array, root: Node) -> void:
	if node is AnimationPlayer:
		out.append({
			"player": node,
			"path": "." if node == root else str(root.get_path_to(node)),
		})
	for c in node.get_children():
		_find_players_recursive(c, out, root)


func _apply_example_animation(params: Dictionary) -> Dictionary:
	## One-shot: copy example clip → target player, optional path remap + time scale.
	## Supports example from another AnimationPlayer in the open scene OR a scene file.
	var scene_path: String = optional_string(params, "example_scene_path", "")
	var src_player_path: String = optional_string(params, "source_node_path", "")
	var src_anim: String = optional_string(params, "source_animation", optional_string(params, "example_animation", ""))
	var dst_player_path: String = optional_string(params, "target_node_path", "")
	var dst_anim: String = optional_string(params, "target_animation", src_anim)
	if dst_player_path.is_empty() or src_anim.is_empty():
		return error_invalid_params("target_node_path + source_animation (or example_animation) required")
	var steps: Array = []
	var temp_root: Node = null
	if not scene_path.is_empty():
		if not scene_path.begins_with("res://"):
			scene_path = "res://" + scene_path.trim_prefix("/")
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			return error_not_found(scene_path)
		temp_root = packed.instantiate()
		var players: Array = []
		_find_players_recursive(temp_root, players, temp_root)
		if players.is_empty():
			temp_root.queue_free()
			return error_not_found("AnimationPlayer in example scene")
		var src_p: AnimationPlayer = players[0]["player"]
		if not src_player_path.is_empty():
			for item in players:
				if str(item["path"]) == src_player_path or str(item["player"].name) == src_player_path:
					src_p = item["player"]
					break
		if not src_p.has_animation(src_anim):
			temp_root.queue_free()
			return error_not_found("Animation '%s' in example" % src_anim)
		# Temporarily expose via copy
		var dp := _find_player(dst_player_path)
		if dp == null:
			temp_root.queue_free()
			return error_not_found("Target AnimationPlayer")
		var copy := src_p.get_animation(src_anim).duplicate(true) as Animation
		var lib: AnimationLibrary = dp.get_animation_library("")
		if lib == null:
			lib = AnimationLibrary.new()
			dp.add_animation_library("", lib)
		if lib.has_animation(dst_anim):
			lib.remove_animation(dst_anim)
		lib.add_animation(dst_anim, copy)
		steps.append({"copied_from_scene": scene_path, "animation": dst_anim, "tracks": copy.get_track_count()})
		temp_root.queue_free()
		temp_root = null
	else:
		if src_player_path.is_empty():
			return error_invalid_params("source_node_path or example_scene_path required")
		var r := _copy_animation_to_player({
			"source_node_path": src_player_path,
			"source_animation": src_anim,
			"target_node_path": dst_player_path,
			"target_animation": dst_anim,
			"overwrite": true,
		})
		if r.has("error"):
			return r
		steps.append(r.get("result", r))
	# Optional remaps
	if params.has("from_prefix") or params.has("replacements"):
		var remap_params := {
			"node_path": dst_player_path,
			"animation": dst_anim,
			"from_prefix": optional_string(params, "from_prefix", ""),
			"to_prefix": optional_string(params, "to_prefix", ""),
			"replacements": params.get("replacements", {}),
		}
		var rr := _remap_animation_track_paths(remap_params)
		steps.append({"remap": rr.get("result", rr)})
	if params.has("scale") or params.has("time_scale"):
		var sr := _scale_animation_time({
			"node_path": dst_player_path,
			"animation": dst_anim,
			"scale": float(params.get("scale", params.get("time_scale", 1.0))),
		})
		steps.append({"scale": sr.get("result", sr)})
	if params.has("offset"):
		var orr := _offset_animation_keys({
			"node_path": dst_player_path,
			"animation": dst_anim,
			"offset": float(params["offset"]),
		})
		steps.append({"offset": orr.get("result", orr)})
	mark_current_scene_unsaved()
	return success({
		"target_node_path": dst_player_path,
		"target_animation": dst_anim,
		"steps": steps,
		"next": [
			"dump_animation / compare_animations",
			"set_animation_keyframe for value tweaks",
			"animation_player_play + playtest_report",
		],
	})
