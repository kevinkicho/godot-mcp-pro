@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Preload / resource registry for agents (startup load lists).


func get_commands() -> Dictionary:
	return {
		"create_resource_registry_script": _create_resource_registry_script,
		"write_preload_manifest": _write_preload_manifest,
		"validate_preload_manifest": _validate_preload_manifest,
		"list_resource_preload_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_async_resource_loader_script", "ensure_imported", "list_resources_by_type"],
	})


func _create_resource_registry_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/resource_registry.gd")
	var content := """extends Node
## Central preload/cache registry — load paths once, fetch by id.
signal loaded(id: StringName, resource: Resource)

@export var manifest_path: String = \"res://data/preload_manifest.json\"
var _cache: Dictionary = {}  # id -> Resource
var _paths: Dictionary = {}  # id -> path

func _ready() -> void:
	if FileAccess.file_exists(manifest_path):
		load_manifest(manifest_path)

func load_manifest(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return
	f.close()
	if j.data is Dictionary and j.data.has(\"resources\"):
		for item in j.data[\"resources\"]:
			if item is Dictionary:
				register(str(item.get(\"id\", \"\")), str(item.get(\"path\", \"\")), bool(item.get(\"preload\", false)))

func register(id: String, path: String, do_preload: bool = false) -> void:
	if id.is_empty() or path.is_empty():
		return
	_paths[StringName(id)] = path
	if do_preload:
		get_resource(StringName(id))

func get_resource(id: StringName) -> Resource:
	if _cache.has(id):
		return _cache[id]
	if not _paths.has(id):
		return null
	var path: String = _paths[id]
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	_cache[id] = res
	loaded.emit(id, res)
	return res

func has_id(id: StringName) -> bool:
	return _paths.has(id)

func clear_cache() -> void:
	_cache.clear()
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var added := maybe_add_autoload(params, path, "ResourceRegistry")
	return success({"path": path, "autoload_added": added})


func _write_preload_manifest(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://data/preload_manifest.json")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var resources: Array = params.get("resources", [])
	if resources.is_empty():
		resources = [
			{"id": "main_theme", "path": "res://themes/main.tres", "preload": false},
		]
	var data := {"version": 1, "resources": resources}
	ensure_parent_dir(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write manifest")
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "count": resources.size()})


func _validate_preload_manifest(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://data/preload_manifest.json")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return error_internal("Invalid JSON")
	f.close()
	var missing: Array = []
	var ok: Array = []
	if j.data is Dictionary and j.data.get("resources") is Array:
		for item in j.data["resources"]:
			if not item is Dictionary:
				continue
			var p := str(item.get("path", ""))
			var id := str(item.get("id", ""))
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				ok.append(id)
			else:
				missing.append({"id": id, "path": p})
	return success({"ok": missing.is_empty(), "valid": ok, "missing": missing})
