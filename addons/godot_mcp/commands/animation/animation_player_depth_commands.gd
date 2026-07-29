@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## AnimationPlayer depth  -  autoplay, speed, libraries, active clip (Animation dock).


func get_commands() -> Dictionary:
	return {
		"set_animation_player_autoplay": _set_autoplay,
		"set_animation_player_speed": _set_speed,
		"list_animation_player_libraries": _list_libs,
		"assign_animation_library": _assign_lib,
		"get_animation_player_status": _get_status,
		"list_animation_player_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["list_animations", "animation_player_play", "create_animation", "animation_library_*"],
	})


func _player(path: String) -> AnimationPlayer:
	var n := find_node_by_path(path)
	if n is AnimationPlayer:
		return n as AnimationPlayer
	return null


func _set_autoplay(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var p := _player(r0[0])
	if p == null:
		return error_not_found("AnimationPlayer")
	var anim: String = optional_string(params, "animation", optional_string(params, "autoplay", ""))
	p.autoplay = anim
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "autoplay": p.autoplay})


func _set_speed(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var p := _player(r0[0])
	if p == null:
		return error_not_found("AnimationPlayer")
	var applied := {}
	if params.has("speed_scale"):
		p.speed_scale = float(params["speed_scale"])
		applied["speed_scale"] = p.speed_scale
	if params.has("callback_mode_process"):
		p.callback_mode_process = int(params["callback_mode_process"]) as AnimationMixer.AnimationCallbackModeProcess
		applied["callback_mode_process"] = p.callback_mode_process
	if params.has("active"):
		p.active = bool(params["active"])
		applied["active"] = p.active
	if params.has("playback_default_blend_time") and "playback_default_blend_time" in p:
		p.set("playback_default_blend_time", float(params["playback_default_blend_time"]))
		applied["playback_default_blend_time"] = p.get("playback_default_blend_time")
	if applied.is_empty():
		return error_invalid_params("Provide speed_scale, active, callback_mode_process, ...")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _list_libs(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var p := _player(r0[0])
	if p == null:
		return error_not_found("AnimationPlayer")
	var libs: Array = []
	for lib_name in p.get_animation_library_list():
		var lib: AnimationLibrary = p.get_animation_library(lib_name)
		var clips: Array = []
		if lib:
			for an in lib.get_animation_list():
				clips.append(str(an))
		libs.append({
			"library": str(lib_name),
			"animation_count": clips.size(),
			"animations": clips,
			"resource_path": lib.resource_path if lib else "",
		})
	return success({
		"node_path": r0[0],
		"libraries": libs,
		"autoplay": p.autoplay,
		"current_animation": p.current_animation,
		"is_playing": p.is_playing(),
	})


func _assign_lib(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var p := _player(r0[0])
	if p == null:
		return error_not_found("AnimationPlayer")
	var lib_path_r := require_res_path(params, "library_path")
	if lib_path_r[1] != null:
		return lib_path_r[1]
	if not ResourceLoader.exists(lib_path_r[0]):
		return error_not_found(lib_path_r[0])
	var lib = load(lib_path_r[0])
	if not (lib is AnimationLibrary):
		return error_internal("Not an AnimationLibrary")
	var lib_name: String = optional_string(params, "library_name", "")
	if lib_name.is_empty():
		lib_name = lib_path_r[0].get_file().get_basename()
	if p.has_animation_library(lib_name):
		if optional_bool(params, "replace", true):
			p.remove_animation_library(lib_name)
		else:
			return error_conflict("Library exists: %s" % lib_name, {"suggestion": "replace=true"})
	p.add_animation_library(lib_name, lib)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"library_name": lib_name,
		"library_path": lib_path_r[0],
		"animation_count": (lib as AnimationLibrary).get_animation_list().size(),
	})


func _get_status(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var p := _player(r0[0])
	if p == null:
		return error_not_found("AnimationPlayer")
	return success({
		"node_path": r0[0],
		"active": p.active,
		"autoplay": p.autoplay,
		"current_animation": p.current_animation,
		"current_animation_position": p.current_animation_position if p.is_playing() else 0.0,
		"current_animation_length": p.current_animation_length if p.current_animation != "" else 0.0,
		"is_playing": p.is_playing(),
		"speed_scale": p.speed_scale,
		"animation_list": p.get_animation_list(),
	})


func _stop(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var p := _player(r0[0])
	if p == null:
		return error_not_found("AnimationPlayer")
	var keep_state: bool = optional_bool(params, "keep_state", false)
	p.stop(keep_state)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "stopped": true, "keep_state": keep_state})
