@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Export signing / packaging checklist - Android keystore + docs-level readiness.


func get_commands() -> Dictionary:
	return {
		"get_export_signing_checklist": _get_export_signing_checklist,
		"configure_android_keystore": _configure_android_keystore,
		"get_android_signing_status": _get_android_signing_status,
		"set_export_preset_signing_options": _set_export_preset_signing_options,
		"list_export_signing_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["verify_export_ready", "create_export_preset", "run_export", "deploy_to_android"],
		"note": "Does not store passwords in git; use env vars or local editor settings",
	})


func _get_export_signing_checklist(params: Dictionary) -> Dictionary:
	var platform: String = optional_string(params, "platform", "Android").to_lower()
	var items: Array = []
	match platform:
		"android":
			items = [
				{"id": "templates", "desc": "Export templates installed (Editor -> Manage Export Templates)", "tool": "list_export_templates"},
				{"id": "preset", "desc": "Android export preset exists", "tool": "list_export_presets"},
				{"id": "keystore_debug", "desc": "Debug keystore configured (auto or custom)", "tool": "get_android_signing_status"},
				{"id": "keystore_release", "desc": "Release keystore path + user + password for store builds", "tool": "configure_android_keystore"},
				{"id": "package_name", "desc": "Unique package/bundle id (com.company.game)", "tool": "set_export_preset_option"},
				{"id": "permissions", "desc": "Only required Android permissions enabled", "tool": "set_export_preset_option"},
				{"id": "min_sdk", "desc": "min/target SDK match store policy", "tool": "set_export_preset_option"},
			]
		"ios":
			items = [
				{"id": "templates", "desc": "iOS export templates installed"},
				{"id": "xcode", "desc": "macOS + Xcode required to archive/sign (export produces Xcode project)"},
				{"id": "team_id", "desc": "Apple Developer Team ID in export preset / Xcode"},
				{"id": "bundle_id", "desc": "Unique Bundle Identifier"},
				{"id": "capabilities", "desc": "Push/IAP capabilities only if needed"},
				{"id": "note", "desc": "MCP cannot run codesign on Windows; checklist only"},
			]
		"windows", "linux", "macos":
			items = [
				{"id": "templates", "desc": "Desktop export templates installed"},
				{"id": "icon", "desc": "Application icon set in project settings / preset"},
				{"id": "macos_sign", "desc": "macOS: notarization requires Apple certs outside Godot"},
				{"id": "windows_sign", "desc": "Windows: Authenticode optional (signtool external)"},
			]
		"web":
			items = [
				{"id": "templates", "desc": "Web export templates"},
				{"id": "coi", "desc": "COOP/COEP headers if SharedArrayBuffer/threads"},
				{"id": "size", "desc": "Export filters to reduce PCK size"},
			]
		_:
			items = [{"id": "unknown", "desc": "Use platform=Android|iOS|Windows|Web"}]
	var status := await _quick_status()
	return success({
		"platform": platform,
		"checklist": items,
		"current_status": status,
		"hint": "configure_android_keystore for local paths; never commit keystore passwords",
	})


func _quick_status() -> Dictionary:
	var templates := []
	# Best-effort
	var tpl_path := ""
	if ProjectSettings.has_setting("application/config/features"):
		pass
	var has_presets := FileAccess.file_exists("res://export_presets.cfg")
	return {
		"has_export_presets_cfg": has_presets,
		"editor_export_templates_path_hint": "EditorSettings export_templates_path or list_export_templates",
	}


func _get_android_signing_status(_params: Dictionary) -> Dictionary:
	var es := EditorInterface.get_editor_settings()
	var keys := [
		"export/android/debug_keystore",
		"export/android/debug_keystore_user",
		"export/android/android_sdk_path",
		"export/android/java_sdk_path",
	]
	var out := {}
	for k in keys:
		if es.has_setting(k):
			var v = es.get_setting(k)
			# Redact passwords
			if "password" in k.to_lower():
				out[k] = "(set)" if str(v).length() > 0 else ""
			else:
				out[k] = str(v)
		else:
			out[k] = null
	# Preset-level options from export_presets.cfg
	var preset_sign := []
	if FileAccess.file_exists("res://export_presets.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("res://export_presets.cfg") == OK:
			var idx := 0
			while cfg.has_section("preset.%d" % idx):
				var sec := "preset.%d" % idx
				var plat := str(cfg.get_value(sec, "platform", ""))
				if "Android" in plat:
					var opt_sec := "preset.%d.options" % idx
					preset_sign.append({
						"index": idx,
						"name": cfg.get_value(sec, "name", ""),
						"keystore": cfg.get_value(opt_sec, "keystore/release", cfg.get_value(opt_sec, "package/signed", null)),
						"package": cfg.get_value(opt_sec, "package/unique_name", ""),
					})
				idx += 1
	return success({
		"editor_settings": out,
		"android_presets": preset_sign,
		"hint": "Release passwords stay in editor local settings / CI secrets",
	})


func _configure_android_keystore(params: Dictionary) -> Dictionary:
	## Set EditorSettings paths for debug/release keystore (local machine).
	var es := EditorInterface.get_editor_settings()
	var applied := {}
	if params.has("debug_keystore"):
		es.set_setting("export/android/debug_keystore", str(params["debug_keystore"]))
		applied["debug_keystore"] = str(params["debug_keystore"])
	if params.has("debug_keystore_user"):
		es.set_setting("export/android/debug_keystore_user", str(params["debug_keystore_user"]))
		applied["debug_keystore_user"] = str(params["debug_keystore_user"])
	if params.has("debug_keystore_pass"):
		es.set_setting("export/android/debug_keystore_pass", str(params["debug_keystore_pass"]))
		applied["debug_keystore_pass"] = "(set)"
	if params.has("android_sdk_path"):
		es.set_setting("export/android/android_sdk_path", str(params["android_sdk_path"]))
		applied["android_sdk_path"] = str(params["android_sdk_path"])
	if params.has("java_sdk_path"):
		es.set_setting("export/android/java_sdk_path", str(params["java_sdk_path"]))
		applied["java_sdk_path"] = str(params["java_sdk_path"])
	if applied.is_empty():
		return error_invalid_params("Provide debug_keystore, android_sdk_path, and/or java_sdk_path")
	return success({
		"applied": applied,
		"note": "EditorSettings are machine-local - not written to project.godot",
	})


func _set_export_preset_signing_options(params: Dictionary) -> Dictionary:
	## Write common Android signing-related options into export_presets.cfg
	var preset_index: int = optional_int(params, "preset_index", -1)
	var preset_name: String = optional_string(params, "preset_name", "")
	var cfg_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(cfg_path):
		return error_not_found("export_presets.cfg - create_export_preset first")
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return error_internal("Failed to load export_presets.cfg")
	var idx := preset_index
	if idx < 0 and not preset_name.is_empty():
		var i := 0
		while cfg.has_section("preset.%d" % i):
			if str(cfg.get_value("preset.%d" % i, "name", "")) == preset_name:
				idx = i
				break
			i += 1
	if idx < 0:
		# first Android preset
		var i := 0
		while cfg.has_section("preset.%d" % i):
			if "Android" in str(cfg.get_value("preset.%d" % i, "platform", "")):
				idx = i
				break
			i += 1
	if idx < 0:
		return error_not_found("Android export preset")
	var opt := "preset.%d.options" % idx
	var applied := {}
	var map := {
		"package_name": "package/unique_name",
		"package_unique_name": "package/unique_name",
		"version_code": "version/code",
		"version_name": "version/name",
		"min_sdk": "gradle_build/min_sdk",
		"target_sdk": "gradle_build/target_sdk",
		"release_keystore": "keystore/release",
		"release_user": "keystore/release_user",
		"architectures_arm64": "architectures/arm64-v8a",
		"architectures_armeabi": "architectures/armeabi-v7a",
		"architectures_x86_64": "architectures/x86_64",
	}
	for pk in map.keys():
		if params.has(pk):
			cfg.set_value(opt, map[pk], params[pk])
			applied[map[pk]] = params[pk]
	# Direct option keys
	if params.has("options") and params["options"] is Dictionary:
		for k in params["options"]:
			cfg.set_value(opt, str(k), params["options"][k])
			applied[str(k)] = params["options"][k]
	if applied.is_empty():
		return error_invalid_params("Provide package_name, version_*, release_keystore, or options{}")
	# Never write plaintext password if user passes release_password - warn
	if params.has("release_password"):
		return error_invalid_params("Do not store release_password in export_presets.cfg via MCP - set in editor UI or CI secrets")
	var err := cfg.save(cfg_path)
	if err != OK:
		return error_internal(error_string(err))
	return success({"preset_index": idx, "applied": applied})
