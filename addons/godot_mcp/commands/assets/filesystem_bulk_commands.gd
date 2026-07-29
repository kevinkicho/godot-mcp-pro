@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Filesystem bulk ops - move/rename with reference remap (editor FileSystem dock parity).


func get_commands() -> Dictionary:
	return {
		"move_resource_file": _move_one,
		"rename_resource_file": _rename_one,
		"bulk_move_resources": _bulk_move,
		"bulk_rename_resources": _bulk_rename,
		"duplicate_resource_file": _duplicate,
		"delete_resource_files": _delete_files,
		"list_directory_resources": _list_dir,
		"list_filesystem_bulk_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"find_files_referencing", "remap_resource_references", "search_files",
		"get_filesystem_tree", "uid_to_project_path",
	], {
		"flow": [
			"list_directory_resources path=res://sprites",
			"move_resource_file from=... to=... remap=true",
			"bulk_move_resources items=[{from,to}] dry_run=true then false",
		],
		"safety": "remap rewrites text refs (.tscn/.tres/.gd/.json/etc). Binary .res may need re-save.",
	})


func _norm(path: String) -> String:
	var p := path.strip_edges()
	if not p.begins_with("res://") and not p.begins_with("user://"):
		p = "res://" + p.trim_prefix("/")
	return p.simplify_path()


func _exec_remap(from_path: String, to_path: String, dry_run: bool) -> Dictionary:
	var r = get_parent()
	if r and r.has_method("execute"):
		return await r.execute("remap_resource_references", {
			"from": from_path,
			"to": to_path,
			"dry_run": dry_run,
		})
	return {"error": {"message": "remap unavailable"}}


func _fs_rename(from_path: String, to_path: String) -> Dictionary:
	from_path = _norm(from_path)
	to_path = _norm(to_path)
	if not FileAccess.file_exists(from_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(from_path)):
		# DirAccess for res
		var da_check := DirAccess.open(from_path.get_base_dir())
		if da_check == null or not da_check.file_exists(from_path.get_file()):
			if not FileAccess.file_exists(from_path):
				return error_not_found(from_path)
	if FileAccess.file_exists(to_path) and from_path != to_path:
		return error(-32000, "Target exists: %s" % to_path, {"suggestion": "choose another path or delete first"})
	var derr := ensure_parent_dir(to_path)
	if not derr.is_empty():
		return derr
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	)
	# Also try relative DirAccess
	if err != OK:
		var da := DirAccess.open("res://")
		if da:
			err = da.rename(from_path.trim_prefix("res://"), to_path.trim_prefix("res://"))
	if err != OK:
		# Fallback: copy + remove
		var bytes := FileAccess.get_file_as_bytes(from_path)
		if bytes.is_empty() and not FileAccess.file_exists(from_path):
			return error_internal("Rename failed: %s" % error_string(err))
		var f := FileAccess.open(to_path, FileAccess.WRITE)
		if f == null:
			return error_internal("Cannot write %s" % to_path)
		f.store_buffer(bytes)
		f.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(from_path))
	# Move .import / .uid sidecars
	for suffix in [".import", ".uid"]:
		var side_from := from_path + suffix
		var side_to := to_path + suffix
		if FileAccess.file_exists(side_from):
			var sb := FileAccess.get_file_as_bytes(side_from)
			var sf := FileAccess.open(side_to, FileAccess.WRITE)
			if sf:
				sf.store_buffer(sb)
				sf.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(side_from))
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.update_file(from_path)
		fs.update_file(to_path)
		fs.scan()
	return success({"from": from_path, "to": to_path, "moved": true})


func _move_one(params: Dictionary) -> Dictionary:
	var fr := require_string(params, "from")
	if fr[1] != null:
		# also accept path/source
		if params.has("path") and params.has("to"):
			fr = [str(params["path"]), null]
		else:
			return fr[1] if fr[1] != null else error_invalid_params("from required")
	var to_r := require_string(params, "to")
	if to_r[1] != null:
		return to_r[1]
	var from_path := _norm(str(fr[0]))
	var to_path := _norm(to_r[0])
	if optional_bool(params, "dry_run", false):
		return success({
			"from": from_path,
			"to": to_path,
			"dry_run": true,
			"exists": FileAccess.file_exists(from_path),
			"remap": optional_bool(params, "remap", true),
		})
	var moved := _fs_rename(from_path, to_path)
	if moved.has("error"):
		return moved
	var remap_result = null
	if optional_bool(params, "remap", true):
		remap_result = await _exec_remap(from_path, to_path, false)
	return success({
		"from": from_path,
		"to": to_path,
		"moved": true,
		"remap": remap_result,
	})


func _rename_one(params: Dictionary) -> Dictionary:
	var fr := require_string(params, "path")
	if fr[1] != null:
		return fr[1]
	var new_name := optional_string(params, "new_name", "")
	if new_name.is_empty():
		return error_invalid_params("new_name required (filename or full res path)")
	var from_path := _norm(fr[0])
	var to_path: String
	if new_name.begins_with("res://"):
		to_path = _norm(new_name)
	else:
		to_path = from_path.get_base_dir().path_join(new_name)
	return await _move_one({
		"from": from_path,
		"to": to_path,
		"remap": optional_bool(params, "remap", true),
		"dry_run": optional_bool(params, "dry_run", false),
	})


func _bulk_move(params: Dictionary) -> Dictionary:
	## items: [{from,to}] or from_paths[] + to_dir
	var dry := optional_bool(params, "dry_run", false)
	var remap := optional_bool(params, "remap", true)
	var items: Array = []
	if params.has("items") and params["items"] is Array:
		items = params["items"]
	elif params.has("from_paths") and params.has("to_dir"):
		var to_dir := _norm(str(params["to_dir"])).rstrip("/")
		for p in params["from_paths"]:
			var fp := _norm(str(p))
			items.append({"from": fp, "to": to_dir.path_join(fp.get_file())})
	else:
		return error_invalid_params("items[{from,to}] or from_paths[]+to_dir required")
	var results: Array = []
	for item in items:
		if not item is Dictionary:
			continue
		var sub := await _move_one({
			"from": str(item.get("from", "")),
			"to": str(item.get("to", "")),
			"remap": remap,
			"dry_run": dry,
		})
		results.append(sub)
	var ok := 0
	for r in results:
		if r is Dictionary and not r.has("error"):
			ok += 1
	return success({"results": results, "ok_count": ok, "dry_run": dry})


func _bulk_rename(params: Dictionary) -> Dictionary:
	## renames: [{path, new_name}] or prefix/suffix on paths[]
	var dry := optional_bool(params, "dry_run", false)
	var results: Array = []
	if params.has("renames") and params["renames"] is Array:
		for item in params["renames"]:
			if item is Dictionary:
				var sub := await _rename_one({
					"path": str(item.get("path", "")),
					"new_name": str(item.get("new_name", "")),
					"remap": optional_bool(params, "remap", true),
					"dry_run": dry,
				})
				results.append(sub)
	elif params.has("paths") and params["paths"] is Array:
		var prefix := optional_string(params, "prefix", "")
		var suffix := optional_string(params, "suffix", "")
		var replace_from := optional_string(params, "replace", "")
		var replace_to := optional_string(params, "with", "")
		for p in params["paths"]:
			var fp := _norm(str(p))
			var base := fp.get_file()
			var stem := base.get_basename()
			var ext := base.get_extension()
			if not replace_from.is_empty():
				stem = stem.replace(replace_from, replace_to)
			stem = prefix + stem + suffix
			var new_file := stem if ext.is_empty() else "%s.%s" % [stem, ext]
			results.append(await _rename_one({
				"path": fp,
				"new_name": new_file,
				"remap": optional_bool(params, "remap", true),
				"dry_run": dry,
			}))
	else:
		return error_invalid_params("renames[] or paths[] with prefix/suffix/replace required")
	return success({"results": results, "count": results.size(), "dry_run": dry})


func _duplicate(params: Dictionary) -> Dictionary:
	var fr := require_string(params, "path")
	if fr[1] != null:
		return fr[1]
	var from_path := _norm(fr[0])
	if not FileAccess.file_exists(from_path):
		return error_not_found(from_path)
	var to_path: String = optional_string(params, "to", "")
	if to_path.is_empty():
		var stem := from_path.get_basename()
		var ext := from_path.get_extension()
		to_path = "%s_copy.%s" % [stem, ext] if not ext.is_empty() else stem + "_copy"
	to_path = _norm(to_path)
	if FileAccess.file_exists(to_path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % to_path, {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(to_path)
	if not derr.is_empty():
		return derr
	var bytes := FileAccess.get_file_as_bytes(from_path)
	var f := FileAccess.open(to_path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % to_path)
	f.store_buffer(bytes)
	f.close()
	if FileAccess.file_exists(from_path + ".import"):
		var ib := FileAccess.get_file_as_bytes(from_path + ".import")
		var imf := FileAccess.open(to_path + ".import", FileAccess.WRITE)
		if imf:
			# Fix path inside .import
			var txt := ib.get_string_from_utf8().replace(from_path, to_path)
			imf.store_string(txt)
			imf.close()
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.update_file(to_path)
		fs.scan()
	return success({"from": from_path, "to": to_path, "duplicated": true})


func _delete_files(params: Dictionary) -> Dictionary:
	if not params.has("paths") or not params["paths"] is Array:
		return error_invalid_params("paths array required")
	if not optional_bool(params, "confirm", false):
		return error_invalid_params("confirm=true required to delete")
	var deleted: Array = []
	var failed: Array = []
	for p in params["paths"]:
		var path := _norm(str(p))
		if not FileAccess.file_exists(path):
			failed.append({"path": path, "reason": "missing"})
			continue
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if err != OK:
			var da := DirAccess.open(path.get_base_dir())
			if da:
				err = da.remove(path.get_file())
		if err == OK:
			for suffix in [".import", ".uid"]:
				if FileAccess.file_exists(path + suffix):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
			deleted.append(path)
		else:
			failed.append({"path": path, "reason": error_string(err)})
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()
	return success({"deleted": deleted, "failed": failed, "count": deleted.size()})


func _list_dir(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	path = _norm(path)
	var da := DirAccess.open(path)
	if da == null:
		return error_not_found(path)
	var files: Array = []
	var dirs: Array = []
	da.list_dir_begin()
	var n := da.get_next()
	while n != "":
		if n.begins_with("."):
			n = da.get_next()
			continue
		var full := path.rstrip("/") + "/" + n
		if da.current_is_dir():
			dirs.append(full)
		else:
			if not n.ends_with(".import") and not n.ends_with(".uid"):
				files.append(full)
		n = da.get_next()
	da.list_dir_end()
	files.sort()
	dirs.sort()
	return success({
		"path": path,
		"directories": dirs,
		"files": files,
		"file_count": files.size(),
		"dir_count": dirs.size(),
	})
