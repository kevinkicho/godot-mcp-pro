@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Resource format helpers — text/binary save, duplicate path, take over, reimport touch.


func get_commands() -> Dictionary:
	return {
		"save_resource_as": _save_as,
		"convert_resource_format": _convert_format,
		"duplicate_resource_to": _duplicate_to,
		"get_resource_info": _get_resource_info,
		"list_resource_format_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["duplicate_resource", "remap_resource_references", "list_resource_dependencies"],
	})


func _get_resource_info(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return error_not_found(path)
	var info := {
		"path": path,
		"exists": FileAccess.file_exists(path),
		"resource_loader_exists": ResourceLoader.exists(path),
		"extension": path.get_extension().to_lower(),
	}
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Resource:
			info["class"] = r.get_class()
			info["resource_name"] = r.resource_name
			info["resource_path"] = r.resource_path
			info["local_to_scene"] = r.resource_local_to_scene
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs):
		info["file_size"] = FileAccess.get_file_as_bytes(abs).size()
	return success(info)


func _save_as(params: Dictionary) -> Dictionary:
	var from_r := require_res_path(params, "from_path")
	if from_r[1] != null:
		return from_r[1]
	var to_r := require_res_path(params, "to_path")
	if to_r[1] != null:
		return to_r[1]
	if not ResourceLoader.exists(from_r[0]):
		return error_not_found(from_r[0])
	if FileAccess.file_exists(to_r[0]) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % to_r[0], {"suggestion": "overwrite=true"})
	var r = load(from_r[0])
	if not (r is Resource):
		return error_internal("Not a Resource")
	var dup: Resource = (r as Resource).duplicate(true)
	var derr := ensure_parent_dir(to_r[0])
	if not derr.is_empty():
		return derr
	var flags := 0
	if optional_bool(params, "bundle_resources", false):
		flags |= ResourceSaver.FLAG_BUNDLE_RESOURCES
	if optional_bool(params, "change_path", true):
		flags |= ResourceSaver.FLAG_CHANGE_PATH
	if optional_bool(params, "omit_editor_properties", false):
		flags |= ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
	if optional_bool(params, "compress", false):
		flags |= ResourceSaver.FLAG_COMPRESS
	var err := ResourceSaver.save(dup, to_r[0], flags)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(to_r[0])
	return success({"from": from_r[0], "to": to_r[0], "class": dup.get_class()})


func _convert_format(params: Dictionary) -> Dictionary:
	## Convert .tres ↔ .res by re-saving with appropriate extension.
	var from_r := require_res_path(params, "path")
	if from_r[1] != null:
		return from_r[1]
	var path: String = from_r[0]
	if not ResourceLoader.exists(path):
		return error_not_found(path)
	var target_ext: String = optional_string(params, "format", "").to_lower()
	if target_ext.is_empty():
		target_ext = "res" if path.get_extension().to_lower() == "tres" else "tres"
	target_ext = target_ext.trim_prefix(".")
	if target_ext not in ["tres", "res"]:
		return error_invalid_params("format must be tres or res")
	var to_path: String = optional_string(params, "to_path", "")
	if to_path.is_empty():
		to_path = path.get_basename() + "." + target_ext
	return _save_as({
		"from_path": path,
		"to_path": to_path,
		"overwrite": optional_bool(params, "overwrite", false),
		"compress": target_ext == "res" and optional_bool(params, "compress", true),
		"change_path": true,
	})


func _duplicate_to(params: Dictionary) -> Dictionary:
	return _save_as({
		"from_path": params.get("from_path", params.get("path", "")),
		"to_path": params.get("to_path", params.get("dest_path", "")),
		"overwrite": optional_bool(params, "overwrite", false),
		"change_path": true,
	})
