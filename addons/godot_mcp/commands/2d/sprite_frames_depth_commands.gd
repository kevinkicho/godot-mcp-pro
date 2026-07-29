@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SpriteFrames depth - list/remove frames, FPS, looping (2D animation polish).


func get_commands() -> Dictionary:
	return {
		"sprite_frames_get_info": _sprite_frames_get_info,
		"sprite_frames_set_animation_speed": _sprite_frames_set_animation_speed,
		"sprite_frames_set_animation_loop": _sprite_frames_set_animation_loop,
		"sprite_frames_remove_frame": _sprite_frames_remove_frame,
		"sprite_frames_clear_animation": _sprite_frames_clear_animation,
		"sprite_frames_rename_animation": _sprite_frames_rename_animation,
		"list_sprite_frames_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["sprite_frames_create", "sprite_frames_add_animation", "sprite_frames_add_frame", "sprite_frames_assign"],
	})


func _load_sf(path: String) -> SpriteFrames:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as SpriteFrames


func _sprite_frames_get_info(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		# Also allow node with sprite_frames
		if params.has("node_path"):
			var n := find_node_by_path(str(params["node_path"]))
			if n and "sprite_frames" in n and n.get("sprite_frames") is SpriteFrames:
				return _info_from_sf(n.get("sprite_frames") as SpriteFrames, str(params["node_path"]))
		return res[1]
	var sf := _load_sf(res[0])
	if sf == null:
		return error_not_found("SpriteFrames")
	return _info_from_sf(sf, res[0])


func _info_from_sf(sf: SpriteFrames, path: String) -> Dictionary:
	var anims: Array = []
	for aname in sf.get_animation_names():
		var frames: Array = []
		var count := sf.get_frame_count(aname)
		for i in range(mini(count, 50)):
			var tex: Texture2D = sf.get_frame_texture(aname, i)
			frames.append({
				"index": i,
				"duration": sf.get_frame_duration(aname, i) if sf.has_method("get_frame_duration") else 1.0,
				"texture": tex.resource_path if tex else "",
			})
		anims.append({
			"name": aname,
			"frame_count": count,
			"speed": sf.get_animation_speed(aname),
			"loop": sf.get_animation_loop(aname),
			"frames_sample": frames,
		})
	return success({"path": path, "animations": anims, "animation_count": anims.size()})


func _sprite_frames_set_animation_speed(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var anim_r := require_string(params, "animation")
	if anim_r[1] != null:
		return anim_r[1]
	var sf := _load_sf(res[0])
	if sf == null:
		return error_not_found("SpriteFrames")
	if not sf.has_animation(anim_r[0]):
		return error_not_found("animation")
	var speed: float = float(params.get("speed", params.get("fps", 5.0)))
	sf.set_animation_speed(anim_r[0], speed)
	var err := ResourceSaver.save(sf, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"animation": anim_r[0], "speed": speed})


func _sprite_frames_set_animation_loop(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var anim_r := require_string(params, "animation")
	if anim_r[1] != null:
		return anim_r[1]
	var sf := _load_sf(res[0])
	if sf == null:
		return error_not_found("SpriteFrames")
	if not sf.has_animation(anim_r[0]):
		return error_not_found("animation")
	var loop: bool = optional_bool(params, "loop", true)
	sf.set_animation_loop(anim_r[0], loop)
	var err := ResourceSaver.save(sf, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"animation": anim_r[0], "loop": loop})


func _sprite_frames_remove_frame(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var anim_r := require_string(params, "animation")
	if anim_r[1] != null:
		return anim_r[1]
	var sf := _load_sf(res[0])
	if sf == null:
		return error_not_found("SpriteFrames")
	var idx: int = int(params.get("frame", params.get("index", 0)))
	if idx < 0 or idx >= sf.get_frame_count(anim_r[0]):
		return error_invalid_params("frame index out of range")
	sf.remove_frame(anim_r[0], idx)
	var err := ResourceSaver.save(sf, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"animation": anim_r[0], "removed_index": idx, "frame_count": sf.get_frame_count(anim_r[0])})


func _sprite_frames_clear_animation(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var anim_r := require_string(params, "animation")
	if anim_r[1] != null:
		return anim_r[1]
	var sf := _load_sf(res[0])
	if sf == null:
		return error_not_found("SpriteFrames")
	if not sf.has_animation(anim_r[0]):
		return error_not_found("animation")
	sf.clear(anim_r[0])
	var err := ResourceSaver.save(sf, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"animation": anim_r[0], "cleared": true})


func _sprite_frames_rename_animation(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var from_r := require_string(params, "from")
	if from_r[1] != null:
		return from_r[1]
	var to_r := require_string(params, "to")
	if to_r[1] != null:
		return to_r[1]
	var sf := _load_sf(res[0])
	if sf == null:
		return error_not_found("SpriteFrames")
	if not sf.has_animation(from_r[0]):
		return error_not_found("animation")
	if sf.has_animation(to_r[0]):
		return error_invalid_params("target animation already exists")
	sf.rename_animation(from_r[0], to_r[0])
	var err := ResourceSaver.save(sf, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"from": from_r[0], "to": to_r[0]})
