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
