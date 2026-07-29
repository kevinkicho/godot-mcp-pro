@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## AnimationPlayer play/seek/queue/speed controls.

func get_commands() -> Dictionary:
	return {
		"animation_player_play": _animation_player_play,
		"animation_player_stop": _animation_player_stop,
		"animation_player_seek": _animation_player_seek,
		"animation_player_queue": _animation_player_queue,
		"animation_player_get_current": _animation_player_get_current,
		"animation_player_set_autoplay": _animation_player_set_autoplay,
		"animation_player_set_speed": _animation_player_set_speed,
		"set_root_motion_track": _set_root_motion_track,
	}

func _find_animation_player(node_path: String) -> AnimationPlayer:
	var node := find_node_by_path(node_path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null



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



