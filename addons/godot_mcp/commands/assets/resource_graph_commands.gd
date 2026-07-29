@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Resource dependency graph — human FileSystem move/rename + broken-ref fix.


func get_commands() -> Dictionary:
	return {
		"list_resource_dependencies": _list_resource_dependencies,
		"find_files_referencing": _find_files_referencing,
		"remap_resource_references": _remap_resource_references,
		"list_orphaned_resources": _list_orphaned_resources,
		"validate_scene_dependencies": _validate_scene_dependencies,
		"list_resource_graph_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"flow": [
			"list_resource_dependencies path=res://scenes/main.tscn",
			"find_files_referencing path=res://textures/old.png",
			"remap_resource_references from=… to=… dry_run=true then false",
			"validate_scene_dependencies",
		],
	})


func _list_resource_dependencies(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return error_not_found(path)
	var deps: PackedStringArray = ResourceLoader.get_dependencies(path)
	var out: Array = []
	var missing: Array = []
	for d in deps:
		# Godot may return "uid://…::res://path" or plain path
		var p := _dep_to_path(str(d))
		var exists := ResourceLoader.exists(p) or FileAccess.file_exists(p)
		out.append({"path": p, "raw": str(d), "exists": exists})
		if not exists:
			missing.append(p)
	return success({
		"path": path,
		"dependencies": out,
		"count": out.size(),
		"missing": missing,
		"ok": missing.is_empty(),
	})


func _dep_to_path(dep: String) -> String:
	if dep.contains("::"):
		var parts := dep.split("::")
		return parts[parts.size() - 1]
	return dep


func _find_files_referencing(params: Dictionary) -> Dictionary:
	var target_r := require_res_path(params, "path")
	if target_r[1] != null:
		return target_r[1]
	var target: String = target_r[0]
	var root_path: String = optional_string(params, "search_root", "res://")
	var max_n: int = clampi(optional_int(params, "max", 200), 1, 2000)
	var exts := ["tscn", "tres", "scn", "res", "gd", "cs", "import", "cfg", "godot"]
	if params.has("extensions") and params["extensions"] is Array:
		exts = []
		for e in params["extensions"]:
			exts.append(str(e).trim_prefix("."))
	var hits: Array = []
	_scan_refs(root_path, target, exts, hits, max_n)
	return success({
		"target": target,
		"referencing_files": hits,
		"count": hits.size(),
		"truncated": hits.size() >= max_n,
	})


func _scan_refs(dir_path: String, target: String, exts: Array, hits: Array, max_n: int) -> void:
	if hits.size() >= max_n:
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
			if name != ".godot":
				_scan_refs(full, target, exts, hits, max_n)
		else:
			var ext := name.get_extension().to_lower()
			if ext in exts or exts.is_empty():
				if _file_contains_ref(full, target):
					hits.append(full)
		name = dir.get_next()
		if hits.size() >= max_n:
			break
	dir.list_dir_end()


func _file_contains_ref(path: String, target: String) -> bool:
	# Prefer ResourceLoader deps for resources
	if path.get_extension().to_lower() in ["tscn", "tres", "scn", "res"]:
		for d in ResourceLoader.get_dependencies(path):
			if _dep_to_path(str(d)) == target or str(d).contains(target):
				return true
	# Text search for scripts and text resources
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	# Cap read size
	var len := mini(int(f.get_length()), 2_000_000)
	var text := f.get_buffer(len).get_string_from_utf8()
	f.close()
	return text.contains(target)


func _remap_resource_references(params: Dictionary) -> Dictionary:
	var from_r := require_res_path(params, "from")
	if from_r[1] != null:
		return from_r[1]
	var to_r := require_res_path(params, "to")
	if to_r[1] != null:
		return to_r[1]
	var from_path: String = from_r[0]
	var to_path: String = to_r[0]
	var dry_run: bool = optional_bool(params, "dry_run", true)
	var search_root: String = optional_string(params, "search_root", "res://")
	var max_n: int = clampi(optional_int(params, "max", 500), 1, 5000)

	var candidates: Array = []
	_scan_refs(search_root, from_path, ["tscn", "tres", "scn", "res", "gd", "cs", "cfg", "godot", "import"], candidates, max_n)

	var changed: Array = []
	var skipped: Array = []
	for cpath in candidates:
		if not FileAccess.file_exists(cpath):
			continue
		# Skip binary-ish
		var ext := str(cpath).get_extension().to_lower()
		if ext in ["scn", "res"]:
			skipped.append({"path": cpath, "reason": "binary resource — re-save in editor or use UID remap"})
			continue
		var f := FileAccess.open(cpath, FileAccess.READ)
		if f == null:
			continue
		var original := f.get_as_text()
		f.close()
		if not original.contains(from_path):
			continue
		var updated := original.replace(from_path, to_path)
		if updated == original:
			continue
		if dry_run:
			changed.append({"path": cpath, "would_replace": true})
		else:
			# Soft guard for open scenes — require force=true
			if is_scene_resource_path(str(cpath)) and is_scene_path_open(str(cpath)) and not optional_bool(params, "force", false):
				skipped.append({"path": cpath, "reason": "scene open in editor — pass force=true or close first"})
				continue
			var w := FileAccess.open(cpath, FileAccess.WRITE)
			if w == null:
				skipped.append({"path": cpath, "reason": "write failed"})
				continue
			w.store_string(updated)
			w.close()
			changed.append({"path": cpath, "replaced": true})
			if EditorInterface.get_resource_filesystem():
				EditorInterface.get_resource_filesystem().update_file(cpath)

	return success({
		"from": from_path,
		"to": to_path,
		"dry_run": dry_run,
		"files_touched": changed,
		"skipped": skipped,
		"candidate_count": candidates.size(),
		"hint": "Run dry_run=false after reviewing; scan_filesystem if needed",
	})


func _list_orphaned_resources(params: Dictionary) -> Dictionary:
	## Files under assets/ that nothing references (heuristic).
	var asset_root: String = optional_string(params, "path", "res://assets")
	var max_n: int = clampi(optional_int(params, "max", 100), 1, 500)
	var all_files: Array = []
	_collect_files(asset_root, all_files, max_n * 5)
	# Build reverse index from scenes/scripts
	var referenced := {}
	var scan_roots := ["res://scenes", "res://", "res://scripts"]
	for sr in scan_roots:
		_collect_dep_targets(sr, referenced, 2000)
	var orphans: Array = []
	for fpath in all_files:
		if orphans.size() >= max_n:
			break
		var p: String = str(fpath)
		if p.ends_with(".import"):
			continue
		if not referenced.has(p):
			# also check if any .import points
			orphans.append(p)
	return success({
		"path": asset_root,
		"orphans": orphans,
		"count": orphans.size(),
		"note": "Heuristic — UIDs and dynamic load() paths may false-positive",
	})


func _collect_files(dir_path: String, out: Array, max_n: int) -> void:
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
				_collect_files(full, out, max_n)
		else:
			out.append(full)
		name = dir.get_next()
		if out.size() >= max_n:
			break
	dir.list_dir_end()


func _collect_dep_targets(dir_path: String, referenced: Dictionary, max_files: int) -> void:
	var files: Array = []
	_collect_files(dir_path, files, max_files)
	for fpath in files:
		var ext := str(fpath).get_extension().to_lower()
		if ext in ["tscn", "tres", "scn", "res"]:
			for d in ResourceLoader.get_dependencies(str(fpath)):
				referenced[_dep_to_path(str(d))] = true
		elif ext in ["gd", "cs"]:
			if not FileAccess.file_exists(str(fpath)):
				continue
			var f := FileAccess.open(str(fpath), FileAccess.READ)
			if f == null:
				continue
			var text := f.get_as_text()
			f.close()
			# crude res:// extraction
			var i := 0
			while true:
				var idx := text.find("res://", i)
				if idx < 0:
					break
				var end := idx
				while end < text.length():
					var ch := text[end]
					if ch in ['"', "'", ")", " ", "\n", "\r", "\t", ",", "]"]:
						break
					end += 1
				var p := text.substr(idx, end - idx)
				referenced[p] = true
				i = end


func _validate_scene_dependencies(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	var max_n: int = clampi(optional_int(params, "max", 100), 1, 500)
	var scenes: Array = []
	_collect_scenes(root_path, scenes, max_n)
	var problems: Array = []
	var ok_count := 0
	for sp in scenes:
		var deps: PackedStringArray = ResourceLoader.get_dependencies(str(sp))
		var missing: Array = []
		for d in deps:
			var p := _dep_to_path(str(d))
			if not ResourceLoader.exists(p) and not FileAccess.file_exists(p):
				missing.append(p)
		if missing.is_empty():
			ok_count += 1
		else:
			problems.append({"scene": sp, "missing": missing})
	return success({
		"scenes_checked": scenes.size(),
		"ok": ok_count,
		"problems": problems,
		"all_ok": problems.is_empty(),
	})


func _collect_scenes(dir_path: String, out: Array, max_n: int) -> void:
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
				_collect_scenes(full, out, max_n)
		elif name.get_extension().to_lower() in ["tscn", "scn"]:
			out.append(full)
		name = dir.get_next()
		if out.size() >= max_n:
			break
	dir.list_dir_end()
