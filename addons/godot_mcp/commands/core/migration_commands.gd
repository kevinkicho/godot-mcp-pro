@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Godot 3 → 4 migration aids — scan + rewrite suggestions (not a full auto-migrator).


func get_commands() -> Dictionary:
	return {
		"scan_godot3_patterns": _scan_godot3_patterns,
		"list_migration_replacements": _list_migration_replacements,
		"apply_migration_replacements": _apply_migration_replacements,
		"get_migration_guide": _get_migration_guide,
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
		"honesty": "Not a full automated 3→4 migrator; covers common GDScript renames and flags.",
	})


func _list_migration_replacements(_params: Dictionary) -> Dictionary:
	return success({"replacements": _replacements()})


func _replacements() -> Array:
	## Conservative GDScript 3→4 string replacements (order matters for some).
	return [
		{"from": "yield(", "to": "await ", "note": "yield→await; may need manual Coroutine fixes"},
		{"from": ".instance()", "to": ".instantiate()", "note": "PackedScene"},
		{"from": "Spatial", "to": "Node3D", "note": "type renames — verify class contexts"},
		{"from": "KinematicBody", "to": "CharacterBody3D", "note": "or CharacterBody2D"},
		{"from": "KinematicBody2D", "to": "CharacterBody2D", "note": ""},
		{"from": "RigidBody", "to": "RigidBody3D", "note": "disambiguate 2D"},
		{"from": "RigidBody2D", "to": "RigidBody2D", "note": "unchanged"},
		{"from": "StaticBody", "to": "StaticBody3D", "note": ""},
		{"from": "Area", "to": "Area3D", "note": "careful with Area2D"},
		{"from": "move_and_slide()", "to": "move_and_slide()", "note": "API changed — velocity property"},
		{"from": "export(", "to": "@export ", "note": "export var → @export var (manual tweak)"},
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
