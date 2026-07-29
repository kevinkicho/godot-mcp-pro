@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SpriteFrames create/assign from Animation dock helpers.

func get_commands() -> Dictionary:
	return {
		"sprite_frames_create": _sprite_frames_create,
		"sprite_frames_add_animation": _sprite_frames_add_animation,
		"sprite_frames_add_frame": _sprite_frames_add_frame,
		"sprite_frames_assign": _sprite_frames_assign,
	}

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


