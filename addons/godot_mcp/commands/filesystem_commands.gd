@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Project filesystem mutations under res:// (scripting/filesystem.rst, IO).


func get_commands() -> Dictionary:
	return {
		"res_copy_file": _res_copy_file,
		"res_delete_path": _res_delete_path,
		"res_rename_path": _res_rename_path,
		"res_make_dir": _res_make_dir,
		"res_file_exists": _res_file_exists,
		"res_list_dir": _res_list_dir,
		"res_read_text": _res_read_text,
		"res_write_text": _res_write_text,
	}


func _res_copy_file(params: Dictionary) -> Dictionary:
	var src_r := require_res_path(params, "from")
	if src_r[1] != null:
		# allow absolute OS source
		var from_os: String = optional_string(params, "from", "")
		if from_os.is_empty() or not FileAccess.file_exists(from_os):
			return src_r[1] if src_r[1] else error_invalid_params("from path missing")
		var dest_r := require_res_path(params, "to")
		if dest_r[1] != null:
			return dest_r[1]
		var dest: String = dest_r[0]
		var dir_err := ensure_parent_dir(dest)
		if not dir_err.is_empty():
			return dir_err
		var abs_dest := ProjectSettings.globalize_path(dest)
		var err := DirAccess.copy_absolute(from_os, abs_dest)
		if err != OK:
			return error_internal("Copy failed: %s" % error_string(err))
		EditorInterface.get_resource_filesystem().update_file(dest)
		return success({"from": from_os, "to": dest, "copied": true})
	var from: String = src_r[0]
	var dest_r2 := require_res_path(params, "to")
	if dest_r2[1] != null:
		return dest_r2[1]
	var to: String = dest_r2[0]
	var derr := ensure_parent_dir(to)
	if not derr.is_empty():
		return derr
	var err2 := DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	if err2 != OK:
		return error_internal("Copy failed: %s" % error_string(err2))
	EditorInterface.get_resource_filesystem().update_file(to)
	return success({"from": from, "to": to, "copied": true})


func _res_delete_path(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if path == "res://" or path == "res://addons" or path.begins_with("res://addons/godot_mcp"):
		return error(-32000, "Refusing to delete protected path: %s" % path)
	var abs := ProjectSettings.globalize_path(path)
	var err: Error
	if DirAccess.dir_exists_absolute(abs):
		err = DirAccess.remove_absolute(abs)
	elif FileAccess.file_exists(path):
		err = DirAccess.remove_absolute(abs)
	else:
		return error_not_found(path)
	if err != OK:
		return error_internal("Delete failed: %s" % error_string(err))
	EditorInterface.get_resource_filesystem().scan()
	return success({"path": path, "deleted": true})


func _res_rename_path(params: Dictionary) -> Dictionary:
	var from_r := require_res_path(params, "from")
	if from_r[1] != null:
		return from_r[1]
	var to_r := require_res_path(params, "to")
	if to_r[1] != null:
		return to_r[1]
	var from: String = from_r[0]
	var to: String = to_r[0]
	var derr := ensure_parent_dir(to)
	if not derr.is_empty():
		return derr
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	if err != OK:
		return error_internal("Rename failed: %s" % error_string(err))
	EditorInterface.get_resource_filesystem().scan()
	return success({"from": from, "to": to, "renamed": true})


func _res_make_dir(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	if err != OK and err != ERR_ALREADY_EXISTS:
		return error_internal("mkdir failed: %s" % error_string(err))
	EditorInterface.get_resource_filesystem().scan()
	return success({"path": path, "created": true})


func _res_file_exists(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	return success({
		"path": path,
		"exists": FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)),
		"is_file": FileAccess.file_exists(path),
		"is_dir": DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)),
	})


func _res_list_dir(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var dir := DirAccess.open(path)
	if dir == null:
		return error_not_found(path)
	var files: Array = []
	var dirs: Array = []
	dir.list_dir_begin()
	var n := dir.get_next()
	while not n.is_empty():
		if not n.begins_with("."):
			if dir.current_is_dir():
				dirs.append(n)
			else:
				files.append(n)
		n = dir.get_next()
	return success({"path": path, "files": files, "directories": dirs})


func _res_read_text(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal(error_string(FileAccess.get_open_error()))
	var text := f.get_as_text()
	f.close()
	return success({"path": path, "content": text, "size": text.length()})


func _res_write_text(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if not params.has("content"):
		return error_invalid_params("content is required")
	var content: String = str(params["content"])
	var force: bool = optional_bool(params, "force", false)
	var guard := guard_text_resource_write(path, force)
	if not guard.is_empty():
		return guard
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal(error_string(FileAccess.get_open_error()))
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "written": true, "size": content.length()})
