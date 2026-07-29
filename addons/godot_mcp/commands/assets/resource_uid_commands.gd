@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## ResourceUID helpers - resolve UIDs, list uid cache, remap after renames.


func get_commands() -> Dictionary:
	return {
		"resolve_resource_uid": _resolve_uid,
		"get_resource_uid": _get_uid,
		"list_resource_uids": _list_uids,
		"uid_cache_stats": _uid_stats,
		"list_resource_uid_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"uid_to_project_path", "project_path_to_uid", "find_files_referencing",
		"remap_resource_references", "list_resource_dependencies",
	])


func _resolve_uid(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "uid")
	if r0[1] != null:
		return r0[1]
	var uid_str: String = r0[0].strip_edges()
	if not uid_str.begins_with("uid://"):
		if uid_str.is_valid_int():
			uid_str = "uid://%s" % uid_str
		else:
			return error_invalid_params("uid must look like uid://...")
	var path := ResourceUID.get_id_path(ResourceUID.text_to_id(uid_str)) if ResourceUID.has_method("text_to_id") else ""
	# Prefer ResourceLoader path resolution
	if ResourceLoader.exists(uid_str):
		# In Godot 4, load/uid map via ResourceUID
		pass
	var id := ResourceUID.text_to_id(uid_str) if ResourceUID.has_method("text_to_id") else ResourceUID.INVALID_ID
	if id == ResourceUID.INVALID_ID:
		# try bare
		if ResourceUID.has_id(ResourceUID.text_to_id(uid_str)):
			pass
	var resolved := ""
	if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
		resolved = ResourceUID.get_id_path(id)
	if resolved.is_empty() and ResourceLoader.exists(uid_str):
		# Fallback: some builds accept uid path via ProjectSettings
		resolved = uid_str
	if resolved.is_empty():
		return error_not_found("UID '%s'" % uid_str, "Reimport asset or check .uid files")
	return success({"uid": uid_str, "id": id, "path": resolved, "exists": FileAccess.file_exists(resolved) or ResourceLoader.exists(resolved)})


func _get_uid(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "path")
	if r0[1] != null:
		return r0[1]
	var path: String = normalize_project_path(r0[0])
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return error_not_found("Resource path '%s'" % path)
	var id := ResourceLoader.get_resource_uid(path) if ResourceLoader.has_method("get_resource_uid") else ResourceUID.INVALID_ID
	if id == ResourceUID.INVALID_ID and ResourceUID.has_method("path_to_id"):
		id = ResourceUID.path_to_id(path) if false else id
	# Godot 4 ResourceUID
	if id == ResourceUID.INVALID_ID:
		for existing_id in []:  # placeholder - use has_id scan below
			pass
	# Scan known ids is expensive; use .uid sidecar if present
	var uid_file := path + ".uid"
	var sidecar := ""
	if FileAccess.file_exists(uid_file):
		var f := FileAccess.open(uid_file, FileAccess.READ)
		if f:
			sidecar = f.get_as_text().strip_edges()
	var text_uid := ""
	if id != ResourceUID.INVALID_ID and ResourceUID.has_method("id_to_text"):
		text_uid = ResourceUID.id_to_text(id)
	elif not sidecar.is_empty():
		text_uid = sidecar
	return success({
		"path": path,
		"uid": text_uid,
		"id": id,
		"uid_file": uid_file if FileAccess.file_exists(uid_file) else null,
		"sidecar": sidecar if not sidecar.is_empty() else null,
	})


func _list_uids(params: Dictionary) -> Dictionary:
	## Walk res:// for *.uid sidecars (fast, reliable for agents).
	var base: String = optional_string(params, "path", "res://")
	if not base.begins_with("res://"):
		base = "res://" + base.trim_prefix("/")
	var limit: int = optional_int(params, "limit", 200)
	var out: Array = []
	_walk_uid(base, out, limit)
	return success({"path": base, "uids": out, "count": out.size(), "truncated": out.size() >= limit})


func _walk_uid(dir_path: String, out: Array, limit: int) -> void:
	if out.size() >= limit:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.rstrip("/") + "/" + name
		if dir.current_is_dir():
			if name != "addons" or dir_path == "res://":
				# Skip .godot cache
				if name != ".godot":
					_walk_uid(full, out, limit)
		elif name.ends_with(".uid"):
			var f := FileAccess.open(full, FileAccess.READ)
			var uid_text := f.get_as_text().strip_edges() if f else ""
			var resource_path := full.trim_suffix(".uid")
			out.append({"uid": uid_text, "path": resource_path, "uid_file": full})
			if out.size() >= limit:
				return
		name = dir.get_next()
	dir.list_dir_end()


func _uid_stats(_params: Dictionary) -> Dictionary:
	var count := 0
	var sample: Array = []
	_walk_uid("res://", sample, 50)
	# full count (capped)
	var all: Array = []
	_walk_uid("res://", all, 10000)
	count = all.size()
	return success({
		"uid_sidecar_count": count,
		"sample": sample.slice(0, 10),
		"hint": "resolve_resource_uid / get_resource_uid / list_resource_uids",
	})
