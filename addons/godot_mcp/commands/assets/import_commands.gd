@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Assets pipeline — import_process.rst coverage.


func get_commands() -> Dictionary:
	return {
		"reimport_files": _reimport_files,
		"wait_for_import": _wait_for_import,
		"get_import_info": _get_import_info,
		"set_import_option": _set_import_option,
		"set_import_options": _set_import_options,
		"apply_texture_import_preset": _apply_texture_import_preset,
		"apply_scene_import_preset": _apply_scene_import_preset,
		"create_atlas_texture": _create_atlas_texture,
		"list_import_presets": _list_import_presets,
		"scan_filesystem": _scan_filesystem,
		"is_filesystem_scanning": _is_filesystem_scanning,
		"get_filesystem_hash": _get_filesystem_hash,
		# Headless-agent asset pipeline (human FileSystem + Import dock)
		"ensure_imported": _ensure_imported,
		"import_paths": _import_paths,
		"stage_files_into_res": _stage_files_into_res,
	}


func _fs() -> EditorFileSystem:
	return EditorInterface.get_resource_filesystem()


func _reimport_files(params: Dictionary) -> Dictionary:
	if not params.has("paths") or not params["paths"] is Array:
		return error_invalid_params("'paths' array of res:// files is required")
	var paths: Array = params["paths"]
	var packed := PackedStringArray()
	for p in paths:
		var s := str(p)
		if not s.begins_with("res://"):
			s = "res://" + s.trim_prefix("/")
		packed.append(s)
	if packed.is_empty():
		return error_invalid_params("paths is empty")
	var fs := _fs()
	if fs == null:
		return error_internal("EditorFileSystem unavailable")
	fs.reimport_files(packed)
	return success({"reimporting": packed, "count": packed.size(), "message": "Reimport started — use wait_for_import"})


func _wait_for_import(params: Dictionary) -> Dictionary:
	var timeout_sec: float = float(params.get("timeout_sec", 60.0))
	var fs := _fs()
	if fs == null:
		return error_internal("EditorFileSystem unavailable")
	var start := Time.get_ticks_msec()
	# Kick a scan if idle
	if not fs.is_scanning():
		fs.scan()
	var attempts := int(timeout_sec / 0.1)
	while attempts > 0:
		if not fs.is_scanning():
			return success({
				"done": true,
				"elapsed_ms": Time.get_ticks_msec() - start,
				"scanning": false,
			})
		await get_tree().create_timer(0.1).timeout
		attempts -= 1
	return error(-32000, "Timeout waiting for filesystem import/scan", {
		"elapsed_ms": Time.get_ticks_msec() - start,
		"suggestion": "Increase timeout_sec or check for broken assets",
	})


func _get_import_info(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return success({
			"path": path,
			"has_import_file": false,
			"message": "No .import yet — file may not be imported. Call scan_filesystem / wait_for_import.",
		})
	var cfg := ConfigFile.new()
	var err := cfg.load(import_path)
	if err != OK:
		return error_internal("Failed to read %s: %s" % [import_path, error_string(err)])
	var remap: Dictionary = {}
	var deps: Dictionary = {}
	var params_out: Dictionary = {}
	if cfg.has_section("remap"):
		for k in cfg.get_section_keys("remap"):
			remap[k] = cfg.get_value("remap", k)
	if cfg.has_section("deps"):
		for k in cfg.get_section_keys("deps"):
			deps[k] = cfg.get_value("deps", k)
	if cfg.has_section("params"):
		for k in cfg.get_section_keys("params"):
			params_out[k] = cfg.get_value("params", k)
	return success({
		"path": path,
		"import_path": import_path,
		"has_import_file": true,
		"remap": remap,
		"deps": deps,
		"params": params_out,
	})


func _set_import_option(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var result2 := require_string(params, "key")
	if result2[1] != null:
		return result2[1]
	var key: String = result2[0]
	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")
	var value: Variant = params["value"]
	var section: String = optional_string(params, "section", "params")
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return error_not_found(".import file for '%s'" % path, "Import the asset first (scan/reimport)")
	var cfg := ConfigFile.new()
	var err := cfg.load(import_path)
	if err != OK:
		return error_internal("Failed to load import file")
	var old = cfg.get_value(section, key) if cfg.has_section_key(section, key) else null
	cfg.set_value(section, key, value)
	err = cfg.save(import_path)
	if err != OK:
		return error_internal("Failed to save import file")
	var reimport: bool = optional_bool(params, "reimport", true)
	if reimport:
		var fs := _fs()
		if fs:
			fs.reimport_files(PackedStringArray([path]))
	return success({
		"path": path,
		"section": section,
		"key": key,
		"old_value": old,
		"new_value": value,
		"reimport_started": reimport,
	})


func _scan_filesystem(_params: Dictionary) -> Dictionary:
	var fs := _fs()
	if fs == null:
		return error_internal("EditorFileSystem unavailable")
	fs.scan()
	return success({"scanning": fs.is_scanning(), "message": "Filesystem scan started"})


func _is_filesystem_scanning(_params: Dictionary) -> Dictionary:
	var fs := _fs()
	if fs == null:
		return error_internal("EditorFileSystem unavailable")
	return success({"scanning": fs.is_scanning()})


func _get_filesystem_hash(_params: Dictionary) -> Dictionary:
	# Useful to detect change completion
	var fs := _fs()
	if fs == null:
		return error_internal("EditorFileSystem unavailable")
	var hash_val := ""
	if fs.has_method("get_filesystem_hash"):
		hash_val = str(fs.call("get_filesystem_hash"))
	return success({"hash": hash_val, "scanning": fs.is_scanning()})


func _normalize_res(path: String) -> String:
	var s := path.strip_edges()
	if s.is_empty():
		return s
	if s.begins_with("res://"):
		return s
	return "res://" + s.trim_prefix("/")


func _path_is_ready(path: String) -> Dictionary:
	## Check file exists and is loadable (import finished for engine resources).
	var p := _normalize_res(path)
	var out := {
		"path": p,
		"file_exists": FileAccess.file_exists(p),
		"import_file_exists": FileAccess.file_exists(p + ".import"),
		"resource_loader_exists": ResourceLoader.exists(p),
		"ready": false,
		"error": "",
	}
	if not out["file_exists"]:
		out["error"] = "file_missing"
		return out
	# Text scripts / tscn often don't need .import
	var ext := p.get_extension().to_lower()
	if ext in ["gd", "cs", "txt", "json", "cfg", "md", "godot", "tscn", "scn", "tres", "res", "shader", "gdshader"]:
		out["ready"] = true
		if ext in ["gd", "cs", "shader", "gdshader", "tscn", "scn", "tres", "res"]:
			out["resource_loader_exists"] = ResourceLoader.exists(p)
		return out
	# Imported assets: prefer loadable via ResourceLoader
	if ResourceLoader.exists(p):
		var res = load(p)
		if res != null:
			out["ready"] = true
			out["type"] = res.get_class()
			return out
		out["error"] = "load_returned_null"
		return out
	if out["import_file_exists"]:
		out["error"] = "import_pending_or_failed"
	else:
		out["error"] = "no_import_file_yet"
	return out


func _ensure_imported(params: Dictionary) -> Dictionary:
	## Headless-friendly: scan, wait, optionally reimport until paths are loadable.
	var paths: Array = []
	if params.has("paths") and params["paths"] is Array:
		paths = params["paths"]
	elif params.has("path"):
		paths = [params["path"]]
	else:
		return error_invalid_params("path or paths[] required")
	var timeout_sec: float = float(params.get("timeout_sec", 90.0))
	var reimport: bool = optional_bool(params, "reimport", false)
	var fs := _fs()
	if fs == null:
		return error_internal("EditorFileSystem unavailable — open Godot editor with plugin for import")
	var normalized: Array = []
	for p in paths:
		normalized.append(_normalize_res(str(p)))
	fs.scan()
	# Wait for scan
	var start := Time.get_ticks_msec()
	var attempts := int(timeout_sec / 0.1)
	while attempts > 0 and fs.is_scanning():
		await get_tree().create_timer(0.1).timeout
		attempts -= 1
	if reimport:
		var packed := PackedStringArray()
		for p2 in normalized:
			if FileAccess.file_exists(p2):
				packed.append(p2)
		if packed.size() > 0:
			fs.reimport_files(packed)
	# Wait again + poll readiness
	var results: Array = []
	var all_ready := false
	while attempts > 0:
		if not fs.is_scanning():
			results.clear()
			all_ready = true
			for p3 in normalized:
				var st: Dictionary = _path_is_ready(p3)
				results.append(st)
				if not st.get("ready", false):
					all_ready = false
			if all_ready:
				break
		await get_tree().create_timer(0.15).timeout
		attempts -= 1
	if results.is_empty():
		for p4 in normalized:
			results.append(_path_is_ready(p4))
		all_ready = true
		for st2 in results:
			if not st2.get("ready", false):
				all_ready = false
	return success({
		"ready": all_ready,
		"paths": results,
		"elapsed_ms": Time.get_ticks_msec() - start,
		"scanning": fs.is_scanning(),
		"hint": "If not ready: check broken assets in editor Output; call reimport_files or fix paths",
	})


func _stage_files_into_res(params: Dictionary) -> Dictionary:
	## Copy OS/files into res:// (batch). Human "drop into project folder".
	if not params.has("files") or not params["files"] is Array:
		return error_invalid_params("files: array of {from, to} or from strings with dest_dir")
	var dest_dir: String = optional_string(params, "dest_dir", "res://assets")
	if not dest_dir.begins_with("res://"):
		dest_dir = "res://" + dest_dir.trim_prefix("/")
	dest_dir = dest_dir.rstrip("/")
	var copied: Array = []
	var failed: Array = []
	for item in params["files"]:
		var from_path := ""
		var to_path := ""
		if item is Dictionary:
			from_path = str(item.get("from", item.get("source", "")))
			to_path = str(item.get("to", item.get("dest", "")))
		else:
			from_path = str(item)
		if from_path.is_empty():
			failed.append({"from": from_path, "error": "empty_from"})
			continue
		if to_path.is_empty():
			var base := from_path.get_file()
			to_path = dest_dir + "/" + base
		if not to_path.begins_with("res://"):
			to_path = "res://" + to_path.trim_prefix("/")
		var abs_from := from_path
		if from_path.begins_with("res://"):
			abs_from = ProjectSettings.globalize_path(from_path)
		if not FileAccess.file_exists(abs_from) and not FileAccess.file_exists(from_path):
			failed.append({"from": from_path, "error": "source_missing"})
			continue
		if not FileAccess.file_exists(abs_from):
			abs_from = from_path
		var derr := ensure_parent_dir(to_path)
		if not derr.is_empty():
			failed.append({"from": from_path, "to": to_path, "error": "parent_dir"})
			continue
		var abs_to := ProjectSettings.globalize_path(to_path)
		var err := DirAccess.copy_absolute(abs_from, abs_to)
		if err != OK:
			failed.append({"from": from_path, "to": to_path, "error": error_string(err)})
			continue
		EditorInterface.get_resource_filesystem().update_file(to_path)
		copied.append({"from": from_path, "to": to_path})
	var wait_import: bool = optional_bool(params, "wait_import", true)
	var ensure_result := {}
	if wait_import and copied.size() > 0:
		var paths: Array = []
		for c in copied:
			paths.append(c["to"])
		ensure_result = await _ensure_imported({
			"paths": paths,
			"timeout_sec": float(params.get("timeout_sec", 90.0)),
			"reimport": optional_bool(params, "reimport", false),
		})
	return success({
		"copied": copied,
		"failed": failed,
		"copied_count": copied.size(),
		"failed_count": failed.size(),
		"import": ensure_result.get("result", ensure_result) if ensure_result is Dictionary else ensure_result,
	})


func _import_paths(params: Dictionary) -> Dictionary:
	## Alias pipeline: stage optional + ensure_imported (agent one-shot).
	if params.has("files"):
		return await _stage_files_into_res(params)
	return await _ensure_imported(params)


func _set_import_options(params: Dictionary) -> Dictionary:
	## Batch set many keys in a resource .import file.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if not params.has("options") or not params["options"] is Dictionary:
		return error_invalid_params("'options' Dictionary required")
	var options: Dictionary = params["options"]
	var section: String = optional_string(params, "section", "params")
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return error_not_found(".import for '%s'" % path, "Import the asset first")
	var cfg := ConfigFile.new()
	var err := cfg.load(import_path)
	if err != OK:
		return error_internal("Failed to load import file")
	var changed: Array = []
	for k in options:
		var key := str(k)
		var old = cfg.get_value(section, key) if cfg.has_section_key(section, key) else null
		cfg.set_value(section, key, options[k])
		changed.append({"key": key, "old": old, "new": options[k]})
	err = cfg.save(import_path)
	if err != OK:
		return error_internal("Failed to save import file")
	var reimport: bool = optional_bool(params, "reimport", true)
	if reimport:
		var fs := _fs()
		if fs:
			fs.reimport_files(PackedStringArray([path]))
	return success({"path": path, "changed": changed, "count": changed.size(), "reimport_started": reimport})


func _list_import_presets(_params: Dictionary) -> Dictionary:
	## Documented named presets agents can pass to apply_*_import_preset.
	return success({
		"texture": {
			"lossless": "VRAM uncompressed / lossless for pixel art UI",
			"vram_compressed": "GPU compressed for large textures",
			"lossy": "Lossy disk compress",
			"2d_pixel": "Nearest filter, no mipmaps — pixel art",
			"2d_smooth": "Linear + mipmaps — general 2D",
		},
		"scene_3d": {
			"static": "Meshes as static, generate collision optional",
			"animated": "Keep animations, skin, import as skeleton",
			"collision_trimesh": "Generate trimesh static collision",
		},
		"usage": "apply_texture_import_preset path= res://a.png preset=2d_pixel; apply_scene_import_preset path=res://m.glb preset=animated",
	})


func _apply_texture_import_preset(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var preset: String = optional_string(params, "preset", "2d_smooth")
	var options := {}
	match preset:
		"lossless", "vram_uncompressed":
			options = {
				"compress/mode": 0,  # Lossless
				"mipmaps/generate": false,
			}
		"vram_compressed":
			options = {
				"compress/mode": 2,  # VRAM Compressed
				"mipmaps/generate": true,
			}
		"lossy":
			options = {
				"compress/mode": 1,
				"mipmaps/generate": true,
			}
		"2d_pixel":
			options = {
				"compress/mode": 0,
				"mipmaps/generate": false,
				"process/fix_fix_enabled": false,
			}
		"2d_smooth":
			options = {
				"compress/mode": 0,
				"mipmaps/generate": true,
			}
		_:
			return error_invalid_params("Unknown texture preset '%s'. Call list_import_presets." % preset)
	# Also set detect_3d off for pure 2D presets
	if preset.begins_with("2d"):
		options["detect_3d/compress_to"] = 0
	return _set_import_options({
		"path": path,
		"options": options,
		"reimport": optional_bool(params, "reimport", true),
	})


func _apply_scene_import_preset(params: Dictionary) -> Dictionary:
	## glTF/FBX .import params — keys vary by importer; set common ones.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var preset: String = optional_string(params, "preset", "animated")
	var options := {}
	match preset:
		"static":
			options = {
				"nodes/root_type": "Node3D",
				"meshes/ensure_tangents": true,
				"animation/import": false,
			}
		"animated":
			options = {
				"animation/import": true,
				"animation/fps": 30,
				"meshes/ensure_tangents": true,
			}
		"collision_trimesh":
			options = {
				"meshes/create_shadow_meshes": true,
				"meshes/light_baking": 1,
			}
		_:
			return error_invalid_params("Unknown scene preset '%s'" % preset)
	# Merge user overrides
	if params.has("options") and params["options"] is Dictionary:
		for k in params["options"]:
			options[k] = params["options"][k]
	return _set_import_options({
		"path": path,
		"options": options,
		"reimport": optional_bool(params, "reimport", true),
	})


func _create_atlas_texture(params: Dictionary) -> Dictionary:
	## Create AtlasTexture resource from region of a base texture (2D pipeline).
	var out_r := require_res_path(params, "path")
	if out_r[1] != null:
		return out_r[1]
	var atlas_r := require_res_path(params, "atlas_path")
	if atlas_r[1] != null:
		# also accept texture_path
		var alt := optional_string(params, "texture_path", "")
		if alt.is_empty():
			return atlas_r[1]
		atlas_r = [alt if alt.begins_with("res://") else "res://" + alt.trim_prefix("/"), null]
	if not ResourceLoader.exists(atlas_r[0]):
		return error_not_found(atlas_r[0])
	var base: Texture2D = load(atlas_r[0]) as Texture2D
	if base == null:
		return error_internal("Not Texture2D: %s" % atlas_r[0])
	var at := AtlasTexture.new()
	at.atlas = base
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var w: float = float(params.get("width", params.get("w", base.get_width())))
	var h: float = float(params.get("height", params.get("h", base.get_height())))
	at.region = Rect2(x, y, w, h)
	if params.has("margin"):
		var m = params["margin"]
		if m is Dictionary:
			at.margin = Rect2(float(m.get("x", 0)), float(m.get("y", 0)), float(m.get("w", 0)), float(m.get("h", 0)))
	var derr := ensure_parent_dir(out_r[0])
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(at, out_r[0])
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(out_r[0])
	return success({
		"path": out_r[0],
		"atlas_path": atlas_r[0],
		"region": {"x": x, "y": y, "w": w, "h": h},
	})
