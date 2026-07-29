## Shared res:// / user:// text & JSON writers for command modules.
## Use via base_command helpers so modules do not reimplement file I/O.
extends RefCounted


static func normalize_res_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	return "res://" + path.trim_prefix("/")


static func ensure_parent(path: String) -> Dictionary:
	## Returns {} on success, or error dictionary.
	var dir := path.get_base_dir()
	if dir.is_empty():
		return {}
	var abs_dir := ProjectSettings.globalize_path(dir) if dir.begins_with("res://") or dir.begins_with("user://") else dir
	if DirAccess.dir_exists_absolute(abs_dir):
		return {}
	var derr := DirAccess.make_dir_recursive_absolute(abs_dir)
	if derr != OK:
		return {"error": true, "message": "Cannot create directory '%s': %s" % [dir, error_string(derr)]}
	return {}


static func write_text(path: String, content: String, overwrite: bool = false) -> Dictionary:
	## Returns {path} on success, or {error: true, message, code?} 
	path = normalize_res_path(path) if not path.begins_with("user://") else path
	if FileAccess.file_exists(path) and not overwrite:
		return {"error": true, "code": -32000, "message": "Exists: %s" % path, "suggestion": "overwrite=true"}
	var parent_err := ensure_parent(path)
	if parent_err.get("error", false):
		return parent_err
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"error": true, "message": "Cannot write %s" % path}
	f.store_string(content)
	f.close()
	if path.begins_with("res://") and Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.update_file(path)
	return {"path": path}


static func write_json(path: String, data: Dictionary, overwrite: bool = false) -> Dictionary:
	return write_text(path, JSON.stringify(data, "\t"), overwrite)
