@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"list_export_presets": _list_export_presets,
		"export_project": _export_project,
		"run_export": _run_export,
		"get_export_info": _get_export_info,
		"create_export_preset": _create_export_preset,
		"set_export_preset_option": _set_export_preset_option,
		"remove_export_preset": _remove_export_preset,
		"get_export_preset": _get_export_preset,
	}


func _list_export_presets(params: Dictionary) -> Dictionary:
	# Read export_presets.cfg
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		return success({"presets": [], "count": 0, "message": "No export_presets.cfg found"})

	var cfg := ConfigFile.new()
	var err := cfg.load(presets_path)
	if err != OK:
		return error_internal("Failed to read export_presets.cfg: %s" % error_string(err))

	var presets: Array = []
	var idx := 0
	while cfg.has_section("preset.%d" % idx):
		var section := "preset.%d" % idx
		presets.append({
			"index": idx,
			"name": cfg.get_value(section, "name", ""),
			"platform": cfg.get_value(section, "platform", ""),
			"runnable": cfg.get_value(section, "runnable", false),
			"export_path": cfg.get_value(section, "export_path", ""),
		})
		idx += 1

	return success({"presets": presets, "count": presets.size()})


func _export_project(params: Dictionary) -> Dictionary:
	var preset_index: int = optional_int(params, "preset_index", -1)
	var preset_name: String = optional_string(params, "preset_name", "")
	var debug: bool = optional_bool(params, "debug", true)

	# Find preset
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		return error(-32000, "No export_presets.cfg found. Configure exports in Project > Export first.")

	var cfg := ConfigFile.new()
	var err := cfg.load(presets_path)
	if err != OK:
		return error_internal("Failed to read export_presets.cfg")

	# Find by name or index
	var target_section := ""
	var target_name := ""
	var target_path := ""

	if not preset_name.is_empty():
		var idx := 0
		while cfg.has_section("preset.%d" % idx):
			var section := "preset.%d" % idx
			if cfg.get_value(section, "name", "") == preset_name:
				target_section = section
				target_name = preset_name
				target_path = cfg.get_value(section, "export_path", "")
				break
			idx += 1
	elif preset_index >= 0:
		var section := "preset.%d" % preset_index
		if cfg.has_section(section):
			target_section = section
			target_name = cfg.get_value(section, "name", "")
			target_path = cfg.get_value(section, "export_path", "")

	if target_section.is_empty():
		return error_not_found("Export preset")

	if target_path.is_empty():
		return error(-32000, "Export path not configured for preset '%s'" % target_name)

	# Use EditorExportPlatform via command line
	# We can't directly call export from the plugin, so we return the command to run
	var godot_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var export_path := ProjectSettings.globalize_path(target_path) if target_path.begins_with("res://") else target_path

	var flag := "--export-debug" if debug else "--export-release"
	var command := '"%s" --headless --path "%s" %s "%s"' % [godot_path, project_path, flag, target_name]

	return success({
		"preset": target_name,
		"export_path": export_path,
		"debug": debug,
		"command": command,
		"message": "Use run_export to execute, or run the command yourself.",
	})


func _run_export(params: Dictionary) -> Dictionary:
	## Actually run a headless export (blocks until done).
	var info := _export_project(params)
	if info.has("error"):
		return info
	var data: Dictionary = info.get("result", info)
	var command: String = str(data.get("command", ""))
	if command.is_empty():
		return error_internal("No export command produced")
	var godot_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var debug: bool = optional_bool(params, "debug", true)
	var flag := "--export-debug" if debug else "--export-release"
	var preset: String = str(data.get("preset", ""))
	var args := PackedStringArray(["--headless", "--path", project_path, flag, preset])
	var output: Array = []
	var exit_code: int = OS.execute(godot_path, args, output, true, false)
	return success({
		"preset": preset,
		"exit_code": exit_code,
		"output": "\n".join(PackedStringArray(output)),
		"export_path": data.get("export_path", ""),
		"ok": exit_code == 0,
	})


func _get_export_info(params: Dictionary) -> Dictionary:
	# General export-related project info
	var info := {}

	# Check if export_presets.cfg exists
	info["has_export_presets"] = FileAccess.file_exists("res://export_presets.cfg")

	# Get Godot executable path (useful for command-line exports)
	info["godot_executable"] = OS.get_executable_path()
	info["project_path"] = ProjectSettings.globalize_path("res://")

	# Check for common export templates
	var templates_path := OS.get_data_dir().path_join("export_templates")
	info["templates_dir"] = templates_path
	info["templates_installed"] = DirAccess.dir_exists_absolute(templates_path)

	return success(info)


func _presets_path() -> String:
	return "res://export_presets.cfg"


func _next_preset_index(cfg: ConfigFile) -> int:
	var idx := 0
	while cfg.has_section("preset.%d" % idx):
		idx += 1
	return idx


func _create_export_preset(params: Dictionary) -> Dictionary:
	## Create a basic export_presets.cfg entry (Windows/Linux/Web/Android/macOS).
	var name_r := require_string(params, "name")
	if name_r[1] != null:
		return name_r[1]
	var platform: String = optional_string(params, "platform", "Windows Desktop")
	var export_path: String = optional_string(params, "export_path", "")
	# Default paths by platform
	if export_path.is_empty():
		match platform:
			"Windows Desktop":
				export_path = "res://build/game.exe"
			"Linux/X11", "Linux":
				platform = "Linux"
				export_path = "res://build/game.x86_64"
			"macOS":
				export_path = "res://build/game.zip"
			"Web":
				export_path = "res://build/web/index.html"
			"Android":
				export_path = "res://build/game.apk"
			"iOS":
				export_path = "res://build/ios"
			_:
				export_path = "res://build/export"
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(_presets_path()):
		cfg.load(_presets_path())
	var idx := _next_preset_index(cfg)
	var section := "preset.%d" % idx
	cfg.set_value(section, "name", name_r[0])
	cfg.set_value(section, "platform", platform)
	cfg.set_value(section, "runnable", optional_bool(params, "runnable", true))
	cfg.set_value(section, "advanced_options", false)
	cfg.set_value(section, "dedicated_server", false)
	cfg.set_value(section, "custom_features", "")
	cfg.set_value(section, "export_filter", "all_resources")
	cfg.set_value(section, "include_filter", "")
	cfg.set_value(section, "exclude_filter", "")
	cfg.set_value(section, "export_path", export_path)
	cfg.set_value(section, "encryption_include_filters", "")
	cfg.set_value(section, "encryption_exclude_filters", "")
	cfg.set_value(section, "encrypt_pck", false)
	cfg.set_value(section, "encrypt_directory", false)
	cfg.set_value(section, "script_export_mode", 2)
	# Options section (minimal platform defaults)
	var opt := "preset.%d.options" % idx
	match platform:
		"Windows Desktop":
			cfg.set_value(opt, "binary_format/embed_pck", optional_bool(params, "embed_pck", false))
			cfg.set_value(opt, "texture_format/s3tc_bptc", true)
			cfg.set_value(opt, "texture_format/etc2_astc", false)
		"Linux":
			cfg.set_value(opt, "binary_format/embed_pck", optional_bool(params, "embed_pck", false))
			cfg.set_value(opt, "texture_format/s3tc_bptc", true)
		"Web":
			cfg.set_value(opt, "variant/extensions_support", false)
			cfg.set_value(opt, "vram_texture_compression/for_desktop", true)
			cfg.set_value(opt, "vram_texture_compression/for_mobile", false)
			cfg.set_value(opt, "html/export_icon", true)
		"Android":
			cfg.set_value(opt, "package/unique_name", optional_string(params, "package_name", "com.example.game"))
			cfg.set_value(opt, "package/name", name_r[0])
			cfg.set_value(opt, "architectures/armeabi-v7a", true)
			cfg.set_value(opt, "architectures/arm64-v8a", true)
		"macOS":
			cfg.set_value(opt, "application/bundle_identifier", optional_string(params, "bundle_id", "com.example.game"))
		"iOS":
			cfg.set_value(opt, "application/bundle_identifier", optional_string(params, "bundle_id", "com.example.game"))
	# Merge user options dict
	if params.has("options") and params["options"] is Dictionary:
		for k in params["options"]:
			cfg.set_value(opt, str(k), params["options"][k])
	var err := cfg.save(_presets_path())
	if err != OK:
		return error_internal("Failed to save export_presets.cfg: %s" % error_string(err))
	EditorInterface.get_resource_filesystem().update_file(_presets_path())
	return success({
		"index": idx,
		"name": name_r[0],
		"platform": platform,
		"export_path": export_path,
		"created": true,
		"hint": "Open Project > Export to verify templates/signing; then run_export.",
	})


func _get_export_preset(params: Dictionary) -> Dictionary:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(_presets_path()):
		return error_not_found("export_presets.cfg")
	cfg.load(_presets_path())
	var section := _resolve_preset_section(cfg, params)
	if section.is_empty():
		return error_not_found("Export preset")
	var data := {}
	for k in cfg.get_section_keys(section):
		data[k] = cfg.get_value(section, k)
	var opt_section := section + ".options"
	var options := {}
	if cfg.has_section(opt_section):
		for k in cfg.get_section_keys(opt_section):
			options[k] = cfg.get_value(opt_section, k)
	return success({"section": section, "preset": data, "options": options})


func _resolve_preset_section(cfg: ConfigFile, params: Dictionary) -> String:
	var preset_name: String = optional_string(params, "preset_name", optional_string(params, "name", ""))
	var preset_index: int = optional_int(params, "preset_index", -1)
	if not preset_name.is_empty():
		var idx := 0
		while cfg.has_section("preset.%d" % idx):
			var section := "preset.%d" % idx
			if str(cfg.get_value(section, "name", "")) == preset_name:
				return section
			idx += 1
		return ""
	if preset_index >= 0:
		var s := "preset.%d" % preset_index
		return s if cfg.has_section(s) else ""
	return ""


func _set_export_preset_option(params: Dictionary) -> Dictionary:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(_presets_path()):
		return error_not_found("export_presets.cfg")
	cfg.load(_presets_path())
	var section := _resolve_preset_section(cfg, params)
	if section.is_empty():
		return error_not_found("Export preset")
	var key_r := require_string(params, "key")
	if key_r[1] != null:
		return key_r[1]
	if not params.has("value"):
		return error_invalid_params("value required")
	var in_options: bool = optional_bool(params, "options", true)
	var target := (section + ".options") if in_options else section
	# Ensure options section exists when writing options
	var old = cfg.get_value(target, key_r[0]) if cfg.has_section_key(target, key_r[0]) else null
	cfg.set_value(target, key_r[0], params["value"])
	var err := cfg.save(_presets_path())
	if err != OK:
		return error_internal(error_string(err))
	return success({"section": target, "key": key_r[0], "old": old, "new": params["value"]})


func _remove_export_preset(params: Dictionary) -> Dictionary:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(_presets_path()):
		return error_not_found("export_presets.cfg")
	cfg.load(_presets_path())
	var section := _resolve_preset_section(cfg, params)
	if section.is_empty():
		return error_not_found("Export preset")
	# Collect all presets, rebuild without target (ConfigFile can't easily renumber)
	var presets: Array = []
	var idx := 0
	while cfg.has_section("preset.%d" % idx):
		var s := "preset.%d" % idx
		if s != section:
			var entry := {"keys": {}, "options": {}}
			for k in cfg.get_section_keys(s):
				entry["keys"][k] = cfg.get_value(s, k)
			var opt := s + ".options"
			if cfg.has_section(opt):
				for k in cfg.get_section_keys(opt):
					entry["options"][k] = cfg.get_value(opt, k)
			presets.append(entry)
		idx += 1
	var new_cfg := ConfigFile.new()
	for i in presets.size():
		var s2 := "preset.%d" % i
		var e: Dictionary = presets[i]
		for k in e["keys"]:
			new_cfg.set_value(s2, k, e["keys"][k])
		for k in e["options"]:
			new_cfg.set_value(s2 + ".options", k, e["options"][k])
	var err := new_cfg.save(_presets_path())
	if err != OK:
		return error_internal(error_string(err))
	return success({"removed": section, "remaining": presets.size()})
