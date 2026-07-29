@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Threaded resource loading helpers for agents (assets pipeline).


func get_commands() -> Dictionary:
	return {
		"create_async_resource_loader_script": _create_async_loader_script,
		"resource_load_threaded_request": _resource_load_threaded_request,
		"resource_load_threaded_status": _resource_load_threaded_status,
		"resource_load_threaded_get": _resource_load_threaded_get,
		"list_async_resource_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["ensure_imported", "stage_files_into_res", "load", "wait_for_import"],
		"note": "Threaded load APIs run in editor process; prefer scripts for runtime game loading",
	})


func _create_async_loader_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/async_resource_loader.gd")
	var content := """extends Node
## Async ResourceLoader helper - request paths, poll status, emit when ready.
signal load_finished(path: String, resource: Resource)
signal load_failed(path: String, status: int)

var _pending: Dictionary = {}  # path -> true

func request(path: String, type_hint: String = \"\") -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if not path.begins_with(\"res://\"):
		path = \"res://\" + path.trim_prefix(\"/\")
	var err := ResourceLoader.load_threaded_request(path, type_hint)
	if err == OK:
		_pending[path] = true
	return err

func _process(_dt: float) -> void:
	var done: Array = []
	for path in _pending.keys():
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(path)
			load_finished.emit(path, res)
			done.append(path)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			load_failed.emit(path, st)
			done.append(path)
	for p in done:
		_pending.erase(p)

func is_pending(path: String) -> bool:
	return _pending.has(path)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var added := maybe_add_autoload(params, path, "AsyncResourcesLoader")
	return success({"path": path, "autoload_added": added})


func _resource_load_threaded_request(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var path: String = path_r[0]
	var type_hint: String = optional_string(params, "type_hint", "")
	var use_sub_threads: bool = optional_bool(params, "use_sub_threads", false)
	var err: Error
	if use_sub_threads:
		err = ResourceLoader.load_threaded_request(path, type_hint, true)
	else:
		err = ResourceLoader.load_threaded_request(path, type_hint)
	if err != OK:
		return error_internal("load_threaded_request failed: %s" % error_string(err))
	return success({"path": path, "requested": true})


func _resource_load_threaded_status(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var path: String = path_r[0]
	var progress: Array = []
	var st: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress)
	var name := "invalid"
	match st:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			name = "in_progress"
		ResourceLoader.THREAD_LOAD_FAILED:
			name = "failed"
		ResourceLoader.THREAD_LOAD_LOADED:
			name = "loaded"
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			name = "invalid"
	return success({
		"path": path,
		"status": name,
		"status_code": st,
		"progress": progress[0] if progress.size() > 0 else 0.0,
	})


func _resource_load_threaded_get(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var path: String = path_r[0]
	var st := ResourceLoader.load_threaded_get_status(path)
	if st != ResourceLoader.THREAD_LOAD_LOADED:
		return error(-32000, "Resource not loaded yet", {
			"status": st,
			"suggestion": "Poll resource_load_threaded_status until loaded",
		})
	var res = ResourceLoader.load_threaded_get(path)
	return success({
		"path": path,
		"loaded": res != null,
		"class": res.get_class() if res else "",
		"resource_path": res.resource_path if res else "",
	})
