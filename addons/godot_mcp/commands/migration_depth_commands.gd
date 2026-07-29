@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Deeper Godot 3→4 migration — expanded patterns, .tscn notes, report.


func get_commands() -> Dictionary:
	return {
		"list_migration_replacements_extended": _list_extended,
		"scan_project_migration_report": _scan_report,
		"scan_tscn_godot3_markers": _scan_tscn,
		"get_migration_out_of_scope": _out_of_scope,
		"list_migration_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["scan_godot3_patterns", "apply_migration_replacements", "get_migration_guide"],
		"honesty": "Official Project Converter still required for full scene format conversion",
	})


func _list_extended(_params: Dictionary) -> Dictionary:
	return success({
		"replacements": _extended(),
		"count": _extended().size(),
		"note": "Use apply_migration_replacements for base set; apply these carefully via edit_script",
	})


func _extended() -> Array:
	return [
		{"from": "get_tree().get_root()", "to": "get_tree().root", "area": "SceneTree"},
		{"from": "TranslationServer.set_locale", "to": "TranslationServer.set_locale", "area": "i18n"},
		{"from": "OS.window_fullscreen", "to": "DisplayServer.window_set_mode", "area": "display"},
		{"from": "OS.window_size", "to": "DisplayServer.window_get_size", "area": "display"},
		{"from": "OS.set_window_title", "to": "DisplayServer.window_set_title", "area": "display"},
		{"from": "Input.is_action_just_pressed", "to": "Input.is_action_just_pressed", "area": "input"},
		{"from": "File.new()", "to": "FileAccess.open", "area": "io"},
		{"from": "Directory.new()", "to": "DirAccess.open", "area": "io"},
		{"from": "ResourceLoader.load", "to": "ResourceLoader.load", "area": "resources"},
		{"from": "Engine.editor_hint", "to": "Engine.is_editor_hint()", "area": "engine"},
		{"from": "VisualServer", "to": "RenderingServer", "area": "servers"},
		{"from": "Physics2DServer", "to": "PhysicsServer2D", "area": "servers"},
		{"from": "PhysicsServer", "to": "PhysicsServer3D", "area": "servers"},
		{"from": "ARVRServer", "to": "XRServer", "area": "xr"},
		{"from": "ARVROrigin", "to": "XROrigin3D", "area": "xr"},
		{"from": "ARVRCamera", "to": "XRCamera3D", "area": "xr"},
		{"from": "ARVRController", "to": "XRController3D", "area": "xr"},
		{"from": "Position2D", "to": "Marker2D", "area": "nodes"},
		{"from": "Position3D", "to": "Marker3D", "area": "nodes"},
		{"from": "YSort", "to": "Node2D (y_sort_enabled)", "area": "nodes"},
		{"from": "VisibilityNotifier", "to": "VisibleOnScreenNotifier3D", "area": "nodes"},
		{"from": "VisibilityEnabler", "to": "VisibleOnScreenEnabler3D", "area": "nodes"},
		{"from": "Particles", "to": "GPUParticles3D", "area": "particles"},
		{"from": "Particles2D", "to": "GPUParticles2D", "area": "particles"},
		{"from": "CPUParticles", "to": "CPUParticles3D", "area": "particles"},
		{"from": "StreamTexture", "to": "CompressedTexture2D / PortableCompressedTexture2D", "area": "textures"},
		{"from": "ImageTexture.create_from_image", "to": "ImageTexture.create_from_image", "area": "textures"},
		{"from": "update()", "to": "queue_redraw()", "area": "canvas"},
		{"from": "get_translation()", "to": "position", "area": "transform"},
		{"from": "set_translation(", "to": "position = ", "area": "transform"},
		{"from": "translation =", "to": "position =", "area": "transform"},
		{"from": "get_rotation_degrees()", "to": "rotation_degrees", "area": "transform"},
		{"from": "linear_interpolate(", "to": "lerp(", "area": "math"},
		{"from": "Cubic_interpolate", "to": "cubic_interpolate", "area": "math"},
		{"from": "funcref(", "to": "Callable(", "area": "callables"},
		{"from": "FuncRef", "to": "Callable", "area": "callables"},
		{"from": "signal ", "to": "signal ", "area": "signals"},
		{"from": ".connect(", "to": ".connect(", "area": "signals", "note": "Prefer signal.connect(callable)"},
	]


func _scan_report(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path.trim_prefix("/")
	var max_files: int = clampi(optional_int(params, "max_files", 300), 1, 3000)
	var files: Array = []
	_collect_gd(root_path, files, max_files)
	var hits: Dictionary = {}
	var file_hits: Array = []
	for fpath in files:
		var abs := ProjectSettings.globalize_path(fpath)
		if not FileAccess.file_exists(abs):
			continue
		var text := FileAccess.get_file_as_string(abs)
		var local: Array = []
		for r in _extended():
			var fr: String = r["from"]
			if fr.length() < 4:
				continue
			if text.contains(fr):
				var key: String = fr
				hits[key] = int(hits.get(key, 0)) + text.count(fr)
				local.append({"pattern": fr, "to": r.get("to", ""), "area": r.get("area", "")})
		if not local.is_empty():
			file_hits.append({"path": fpath, "matches": local})
	var sorted: Array = []
	for k in hits.keys():
		sorted.append({"pattern": k, "count": hits[k]})
	sorted.sort_custom(func(a, b): return a["count"] > b["count"])
	return success({
		"files_scanned": files.size(),
		"files_with_hits": file_hits.size(),
		"pattern_totals": sorted,
		"files": file_hits.slice(0, mini(50, file_hits.size())),
		"next": ["apply_migration_replacements dry_run=true", "edit_script for remaining", "playtest_report"],
	})


func _scan_tscn(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path.trim_prefix("/")
	var max_files: int = clampi(optional_int(params, "max_files", 200), 1, 2000)
	var files: Array = []
	_collect_ext(root_path, files, max_files, ["tscn", "tres"])
	var markers := ["[gd_scene load_steps=", "type=\"Spatial\"", "type=\"KinematicBody\"", "type=\"KinematicBody2D\"", "type=\"YSort\"", "type=\"Particles\"", "type=\"Particles2D\"", "type=\"ARVROrigin\"", "format=2"]
	var hits: Array = []
	for fpath in files:
		var abs := ProjectSettings.globalize_path(fpath)
		if not FileAccess.file_exists(abs):
			continue
		var text := FileAccess.get_file_as_string(abs)
		var found: Array = []
		for m in markers:
			if text.contains(m):
				found.append(m)
		if text.contains("format=2"):
			found.append("format=2 (Godot 3 scene — open in Godot 4 converter)")
		if not found.is_empty():
			hits.append({"path": fpath, "markers": found})
	return success({
		"files_scanned": files.size(),
		"hits": hits,
		"count": hits.size(),
		"hint": "format=2 scenes need Godot Project Manager conversion — not MCP auto-rewrite",
	})


func _out_of_scope(_params: Dictionary) -> Dictionary:
	return success({
		"out_of_scope": [
			"Full automatic .tscn/.tres binary format conversion (use Godot Project Converter)",
			"C# API renames across all assemblies",
			"Plugin API breaks for editor plugins written for Godot 3",
			"Custom GDNative → GDExtension automatic port",
		],
		"in_scope": [
			"GDScript string renames (scan + apply)",
			"Migration report + .tscn marker detection",
			"Manual guide via get_migration_guide",
		],
	})


func _collect_gd(res_dir: String, out: Array, max_files: int) -> void:
	_collect_ext(res_dir, out, max_files, ["gd"])


func _collect_ext(res_dir: String, out: Array, max_files: int, exts: Array) -> void:
	if out.size() >= max_files:
		return
	var abs := ProjectSettings.globalize_path(res_dir)
	var da := DirAccess.open(abs)
	if da == null:
		return
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "" and out.size() < max_files:
		if fn.begins_with("."):
			fn = da.get_next()
			continue
		var child_res := res_dir.rstrip("/").path_join(fn)
		if da.current_is_dir():
			if fn not in ["addons", ".git"]:
				_collect_ext(child_res, out, max_files, exts)
		else:
			if fn.get_extension().to_lower() in exts:
				out.append(child_res)
		fn = da.get_next()
	da.list_dir_end()
