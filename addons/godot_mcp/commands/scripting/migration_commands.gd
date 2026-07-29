@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Godot 3 -> 4 migration aids - scan + rewrite suggestions (not a full auto-migrator).


func get_commands() -> Dictionary:
	return {
		"scan_godot3_patterns": _scan_godot3_patterns,
		"list_migration_replacements": _list_migration_replacements,
		"apply_migration_replacements": _apply_migration_replacements,
		"get_migration_guide": _get_migration_guide,
		"list_migration_replacements_extended": _list_extended,
		"scan_project_migration_report": _scan_report,
		"scan_tscn_godot3_markers": _scan_tscn,
		"get_migration_out_of_scope": _out_of_scope,
		"list_migration_depth_tools": _list_migration_depth_tools,
	}


func _get_migration_guide(_params: Dictionary) -> Dictionary:
	return success({
		"docs": "https://docs.godotengine.org/en/stable/tutorials/migrating/index.html",
		"steps": [
			"Backup project; open in Godot 4 (or convert via Project Manager)",
			"scan_godot3_patterns path=res://",
			"apply_migration_replacements dry_run=true then dry_run=false",
			"Fix remaining via list_migration_replacements + edit_script",
			"validate_script / playtest_report",
		],
		"honesty": "Not a full automated 3->4 migrator; covers common GDScript renames and flags.",
	})


func _list_migration_replacements(_params: Dictionary) -> Dictionary:
	return success({"replacements": _replacements()})


func _replacements() -> Array:
	## Conservative GDScript 3->4 string replacements (order matters for some).
	return [
		{"from": "yield(", "to": "await ", "note": "yield->await; may need manual Coroutine fixes"},
		{"from": ".instance()", "to": ".instantiate()", "note": "PackedScene"},
		{"from": "Spatial", "to": "Node3D", "note": "type renames  -  verify class contexts"},
		{"from": "KinematicBody", "to": "CharacterBody3D", "note": "or CharacterBody2D"},
		{"from": "KinematicBody2D", "to": "CharacterBody2D", "note": ""},
		{"from": "RigidBody", "to": "RigidBody3D", "note": "disambiguate 2D"},
		{"from": "RigidBody2D", "to": "RigidBody2D", "note": "unchanged"},
		{"from": "StaticBody", "to": "StaticBody3D", "note": ""},
		{"from": "Area", "to": "Area3D", "note": "careful with Area2D"},
		{"from": "move_and_slide()", "to": "move_and_slide()", "note": "API changed  -  velocity property"},
		{"from": "export(", "to": "@export ", "note": "export var -> @export var (manual tweak)"},
		{"from": "onready var", "to": "@onready var", "note": ""},
		{"from": "tool", "to": "@tool", "note": "first line"},
		{"from": "OS.get_ticks_msec()", "to": "Time.get_ticks_msec()", "note": ""},
		{"from": "OS.get_datetime()", "to": "Time.get_datetime_dict_from_system()", "note": ""},
		{"from": "rand_range(", "to": "randf_range(", "note": ""},
		{"from": "PoolStringArray", "to": "PackedStringArray", "note": ""},
		{"from": "PoolByteArray", "to": "PackedByteArray", "note": ""},
		{"from": "PoolVector2Array", "to": "PackedVector2Array", "note": ""},
		{"from": "PoolVector3Array", "to": "PackedVector3Array", "note": ""},
		{"from": "PoolRealArray", "to": "PackedFloat32Array", "note": ""},
		{"from": "PoolIntArray", "to": "PackedInt32Array", "note": ""},
		{"from": "PoolColorArray", "to": "PackedColorArray", "note": ""},
		{"from": "FILE_READ", "to": "READ", "note": "FileAccess mode"},
		{"from": "FILE_WRITE", "to": "WRITE", "note": ""},
		{"from": "connect(\"", "to": "connect(\"", "note": "signals often use Callable now"},
	]


func _scan_godot3_patterns(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path.trim_prefix("/")
	var max_files: int = clampi(optional_int(params, "max_files", 200), 1, 2000)
	var hits: Array = []
	var files: Array = []
	_collect_gd(root_path, files, max_files)
	var patterns: Array = []
	for r in _replacements():
		var fr: String = r["from"]
		if fr in ["RigidBody2D", "move_and_slide()", "connect(\""]:
			continue  # skip no-op / noisy
		patterns.append(r)
	for fpath in files:
		var text := _read(fpath)
		if text.is_empty():
			continue
		var file_hits: Array = []
		for r in patterns:
			var fr: String = r["from"]
			if text.contains(fr):
				file_hits.append({"pattern": fr, "to": r["to"], "note": r.get("note", "")})
		if not file_hits.is_empty():
			hits.append({"path": fpath, "matches": file_hits, "match_count": file_hits.size()})
	return success({
		"scanned_files": files.size(),
		"files_with_hits": hits.size(),
		"hits": hits,
		"hint": "Review hits then apply_migration_replacements with dry_run=true",
	})


func _apply_migration_replacements(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path.trim_prefix("/")
	var dry: bool = optional_bool(params, "dry_run", true)
	var max_files: int = clampi(optional_int(params, "max_files", 100), 1, 500)
	var only: Array = params.get("only_patterns", [])  # optional subset of "from" strings
	var files: Array = []
	_collect_gd(root_path, files, max_files)
	var changed: Array = []
	var skip_from := {
		"RigidBody2D": true, "move_and_slide()": true, "connect(\"": true,
	}
	for fpath in files:
		var text := _read(fpath)
		if text.is_empty():
			continue
		var orig := text
		for r in _replacements():
			var fr: String = r["from"]
			if skip_from.has(fr):
				continue
			if only is Array and only.size() > 0 and not (fr in only):
				continue
			# Safer renames only
			if fr in ["yield(", ".instance()", "onready var", "PoolStringArray", "PoolByteArray",
					"PoolVector2Array", "PoolVector3Array", "PoolRealArray", "PoolIntArray",
					"PoolColorArray", "OS.get_ticks_msec()", "rand_range("]:
				text = text.replace(fr, r["to"])
		if text != orig:
			changed.append({"path": fpath, "bytes_delta": text.length() - orig.length()})
			if not dry:
				var f := FileAccess.open(fpath, FileAccess.WRITE)
				if f:
					f.store_string(text)
					f.close()
	if not dry and changed.size() > 0:
		EditorInterface.get_resource_filesystem().scan()
	return success({
		"dry_run": dry,
		"files_changed": changed.size(),
		"changed": changed,
		"hint": "Set dry_run=false to write. Always re-validate scripts after migration.",
	})


func _collect_gd(dir_path: String, out: Array, max_n: int) -> void:
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
		var full := (dir_path.rstrip("/") + "/" + name) if dir_path != "res://" else "res://" + name
		if dir_path == "res://" and not name.contains("."):
			full = "res://" + name
		if dir.current_is_dir():
			if name != ".godot" and name != "addons":
				_collect_gd(full if full.begins_with("res://") else dir_path.path_join(name), out, max_n)
		elif name.ends_with(".gd"):
			out.append(full if full.begins_with("res://") else dir_path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

# --- merged from migration_depth_commands ---

func _list_migration_depth_tools(_params: Dictionary) -> Dictionary:
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
	_collect_gd_depth(root_path, files, max_files)
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
			found.append("format=2 (Godot 3 scene  -  open in Godot 4 converter)")
		if not found.is_empty():
			hits.append({"path": fpath, "markers": found})
	return success({
		"files_scanned": files.size(),
		"hits": hits,
		"count": hits.size(),
		"hint": "format=2 scenes need Godot Project Manager conversion  -  not MCP auto-rewrite",
	})


func _out_of_scope(_params: Dictionary) -> Dictionary:
	return success({
		"out_of_scope": [
			"Full automatic .tscn/.tres binary format conversion (use Godot Project Converter)",
			"C# API renames across all assemblies",
			"Plugin API breaks for editor plugins written for Godot 3",
			"Custom GDNative -> GDExtension automatic port",
		],
		"in_scope": [
			"GDScript string renames (scan + apply)",
			"Migration report + .tscn marker detection",
			"Manual guide via get_migration_guide",
		],
	})


func _collect_gd_depth(res_dir: String, out: Array, max_files: int) -> void:
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
