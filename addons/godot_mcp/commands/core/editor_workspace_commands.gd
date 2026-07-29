@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Editor workspace parity — run modes, open scenes, snap, selection transforms, resource browser helpers.


func get_commands() -> Dictionary:
	return {
		"play_main_scene": _play_main_scene,
		"play_current_scene": _play_current_scene,
		"play_custom_scene": _play_custom_scene,
		"get_editor_workspace_info": _get_workspace_info,
		"set_editor_3d_snap": _set_editor_3d_snap,
		"list_open_scenes": _list_open_scenes,
		"close_scene": _close_scene,
		"save_all_scenes": _save_all_scenes,
		"list_resources_by_type": _list_resources_by_type,
		"duplicate_scene_file": _duplicate_scene_file,
		"list_editor_workspace_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["select_nodes", "set_nodes_transform", "open_path_in_filesystem", "set_main_screen"],
	})


func _play_main_scene(_params: Dictionary) -> Dictionary:
	EditorInterface.play_main_scene()
	return success({"playing": "main", "hint": "stop_scene or EditorInterface.stop_playing_scene"})


func _play_current_scene(_params: Dictionary) -> Dictionary:
	EditorInterface.play_current_scene()
	return success({"playing": "current"})


func _play_custom_scene(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "")
	if path.is_empty():
		return error_invalid_params("path required")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not ResourceLoader.exists(path):
		return error_not_found(path)
	EditorInterface.play_custom_scene(path)
	return success({"playing": path})


func _get_workspace_info(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	var ei := get_editor()
	return success({
		"playing": ei.is_playing_scene() if ei else false,
		"open_scenes": get_open_scene_paths(),
		"active_scene": root.scene_file_path if root else "",
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"distraction_free": ei.is_distraction_free_mode_enabled() if ei and ei.has_method("is_distraction_free_mode_enabled") else null,
		"movie_maker": false,
		"hint": "play_main_scene / play_current_scene / play_custom_scene / stop_scene",
	})


func _set_editor_3d_snap(params: Dictionary) -> Dictionary:
	## Best-effort editor 3D snap settings (EditorSettings).
	var es := EditorInterface.get_editor_settings()
	var applied := {}
	if params.has("translate_snap"):
		es.set_setting("editors/3d/grid_xy_plane", true)
		# Common keys vary by version
		for key in ["editors/3d/snap_translate", "editors/3d/manipulator_gizmo_size"]:
			pass
		if es.has_setting("editors/3d/grid_size"):
			pass
		# Documented approach: project snap via Node3DEditor — limited API
		applied["translate_snap_requested"] = float(params["translate_snap"])
	if params.has("rotate_snap_degrees"):
		applied["rotate_snap_degrees"] = float(params["rotate_snap_degrees"])
	# Store agent-facing snap prefs in project metadata
	if params.has("translate_snap"):
		ProjectSettings.set_setting("mcp/editor_snap_translate", float(params["translate_snap"]))
	if params.has("rotate_snap_degrees"):
		ProjectSettings.set_setting("mcp/editor_snap_rotate", float(params["rotate_snap_degrees"]))
	ProjectSettings.save()
	return success({
		"applied": applied,
		"note": "Snap values stored under mcp/editor_snap_*; use set_nodes_transform for numeric placement",
		"project_settings": {
			"mcp/editor_snap_translate": ProjectSettings.get_setting("mcp/editor_snap_translate", null),
			"mcp/editor_snap_rotate": ProjectSettings.get_setting("mcp/editor_snap_rotate", null),
		},
	})


func _list_open_scenes(_params: Dictionary) -> Dictionary:
	return success({"scenes": get_open_scene_paths(), "count": get_open_scene_paths().size()})


func _close_scene(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "")
	if path.is_empty():
		# close current
		var root := get_edited_root()
		if root == null:
			return error_no_scene()
		path = root.scene_file_path
	if not path.begins_with("res://") and not path.is_empty():
		path = "res://" + path.trim_prefix("/")
	if EditorInterface.has_method("close_scene_from_path") and not path.is_empty():
		EditorInterface.close_scene_from_path(path)
		return success({"closed": path})
	# Fallback: reload empty
	return error_internal("close_scene_from_path unavailable — close tab manually or use EditorInterface API in this Godot version")


func _save_all_scenes(_params: Dictionary) -> Dictionary:
	if EditorInterface.has_method("save_all_scenes"):
		EditorInterface.save_all_scenes()
		return success({"saved_all": true})
	# Fallback save current
	var root := get_edited_root()
	if root and not root.scene_file_path.is_empty():
		EditorInterface.save_scene()
		return success({"saved_all": false, "saved_current": root.scene_file_path})
	return error_no_scene()


func _list_resources_by_type(params: Dictionary) -> Dictionary:
	## FileSystem-like filter: list res:// files by extension or class.
	var ext: String = optional_string(params, "extension", "").to_lower().trim_prefix(".")
	var type_filter: String = optional_string(params, "type", "")  # e.g. Texture2D, PackedScene
	var root_path: String = optional_string(params, "path", "res://")
	var max_n: int = clampi(optional_int(params, "max", 100), 1, 1000)
	var out: Array = []
	_scan(root_path, ext, type_filter, out, max_n)
	return success({"resources": out, "count": out.size(), "extension": ext, "type": type_filter})


func _scan(dir_path: String, ext: String, type_filter: String, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.rstrip("/") + "/" + name if dir_path != "res://" else "res://" + name
		if dir.current_is_dir():
			if name != ".godot" and name != "addons":
				_scan(full, ext, type_filter, out, max_n)
		else:
			var ok := true
			if not ext.is_empty() and name.get_extension().to_lower() != ext:
				ok = false
			if ok and not type_filter.is_empty() and ResourceLoader.exists(full):
				var r = load(full)
				if r == null or not r.is_class(type_filter):
					ok = false
			if ok:
				out.append(full)
		name = dir.get_next()
		if out.size() >= max_n:
			break
	dir.list_dir_end()


func _duplicate_scene_file(params: Dictionary) -> Dictionary:
	var src := require_res_path(params, "path")
	if src[1] != null:
		return src[1]
	var dest: String = optional_string(params, "dest", "")
	if dest.is_empty():
		dest = src[0].get_basename() + "_copy." + src[0].get_extension()
	if not dest.begins_with("res://"):
		dest = "res://" + dest.trim_prefix("/")
	if not FileAccess.file_exists(src[0]):
		return error_not_found(src[0])
	var derr := ensure_parent_dir(dest)
	if not derr.is_empty():
		return derr
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(src[0]), ProjectSettings.globalize_path(dest))
	if err != OK:
		# Fallback read/write
		var f := FileAccess.open(src[0], FileAccess.READ)
		if f == null:
			return error_internal("Copy failed")
		var data := f.get_buffer(f.get_length())
		f.close()
		var w := FileAccess.open(dest, FileAccess.WRITE)
		if w == null:
			return error_internal("Cannot write dest")
		w.store_buffer(data)
		w.close()
	EditorInterface.get_resource_filesystem().update_file(dest)
	return success({"from": src[0], "to": dest})
