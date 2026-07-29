@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")


func get_commands() -> Dictionary:
	return {
		"read_resource": _read_resource,
		"edit_resource": _edit_resource,
		"create_resource": _create_resource,
		"get_resource_preview": _get_resource_preview,
		"create_custom_resource_script": _create_custom_resource_script,
		"duplicate_resource": _duplicate_resource,
	}


func _read_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Resource '%s'" % path)

	var guard := guard_offline_scene_save(path)
	if not guard.is_empty():
		return guard

	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		return error_internal("Failed to load resource: %s" % path)

	var props: Dictionary = {}
	for prop_info in resource.get_property_list():
		var prop_name: String = prop_info["name"]
		var usage: int = prop_info["usage"]
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if prop_name.begins_with("_") or prop_name == "script" or prop_name == "resource_local_to_scene" or prop_name == "resource_name" or prop_name == "resource_path":
			continue
		props[prop_name] = PropertyParser.serialize_value(resource.get(prop_name))

	return success({
		"path": path,
		"type": resource.get_class(),
		"resource_name": resource.resource_name,
		"properties": props,
	})


func _edit_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not params.has("properties") or not params["properties"] is Dictionary:
		return error_invalid_params("'properties' dictionary is required")
	var new_props: Dictionary = params["properties"]

	if not FileAccess.file_exists(path):
		return error_not_found("Resource '%s'" % path)

	var guard := guard_offline_scene_save(path)
	if not guard.is_empty():
		return guard

	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		return error_internal("Failed to load resource: %s" % path)

	var changed: Dictionary = {}
	for prop_name: String in new_props:
		if not prop_name in resource:
			continue
		var old_value: Variant = resource.get(prop_name)
		var target_type := typeof(old_value)
		var new_value: Variant = PropertyParser.parse_value(new_props[prop_name], target_type)
		resource.set(prop_name, new_value)
		changed[prop_name] = {
			"old": PropertyParser.serialize_value(old_value),
			"new": PropertyParser.serialize_value(resource.get(prop_name)),
		}

	if changed.is_empty():
		return success({"path": path, "changed": {}, "message": "No properties were changed"})

	var err := ResourceSaver.save(resource, path)
	if err != OK:
		return error_internal("Failed to save resource: %s" % error_string(err))

	return success({
		"path": path,
		"type": resource.get_class(),
		"changed": changed,
	})


func _create_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	var result2 := require_string(params, "type")
	if result2[1] != null:
		return result2[1]
	var resource_type: String = result2[0]

	if not ClassDB.class_exists(resource_type):
		return error_invalid_params("Unknown resource type: %s" % resource_type)
	if not ClassDB.is_parent_class(resource_type, "Resource"):
		return error_invalid_params("'%s' is not a Resource type" % resource_type)

	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "Resource already exists: %s" % path, {"suggestion": "Set overwrite=true to replace"})

	var guard := guard_offline_scene_save(path)
	if not guard.is_empty():
		return guard

	var resource: Resource = ClassDB.instantiate(resource_type)
	if resource == null:
		return error_internal("Failed to instantiate: %s" % resource_type)

	# Apply properties
	var properties: Dictionary = params.get("properties", {})
	for prop_name: String in properties:
		if prop_name in resource:
			var current: Variant = resource.get(prop_name)
			resource.set(prop_name, PropertyParser.parse_value(properties[prop_name], typeof(current)))

	var dir_guard := ensure_parent_dir(path)
	if not dir_guard.is_empty():
		return dir_guard

	var err := ResourceSaver.save(resource, path)
	if err != OK:
		return error_internal("Failed to save resource '%s': %s" % [path, error_string(err)])

	# Rescan filesystem
	EditorInterface.get_resource_filesystem().scan()

	return success({
		"path": path,
		"type": resource_type,
		"properties_set": properties.keys(),
	})


func _get_resource_preview(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Resource '%s'" % path)

	var max_size: int = optional_int(params, "max_size", 256)
	var image: Image = null

	# Try loading as image file directly
	var ext := path.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg", "bmp", "webp", "svg"]:
		image = Image.new()
		var err := image.load(path)
		if err != OK:
			return error_internal("Failed to load image: %s" % error_string(err))
	else:
		# Try loading as resource and extracting image
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			return error_internal("Failed to load resource: %s" % path)

		if resource is Texture2D:
			image = (resource as Texture2D).get_image()
		elif resource is Image:
			image = resource as Image
		else:
			return error_invalid_params("Resource type '%s' does not have an image preview" % resource.get_class())

	if image == null:
		return error_internal("Could not extract image from resource")

	# Resize if needed
	if image.get_width() > max_size or image.get_height() > max_size:
		var scale_x := float(max_size) / float(image.get_width())
		var scale_y := float(max_size) / float(image.get_height())
		var scale := minf(scale_x, scale_y)
		var new_w := int(image.get_width() * scale)
		var new_h := int(image.get_height() * scale)
		image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

	var png_buffer := image.save_png_to_buffer()
	var base64 := Marshalls.raw_to_base64(png_buffer)

	return success({
		"image_base64": base64,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": "png",
		"path": path,
	})


func _create_custom_resource_script(params: Dictionary) -> Dictionary:
	## Create a GDScript Resource subclass with class_name for typed data.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not path.ends_with(".gd"):
		path += ".gd"
	var class_name_str: String = optional_string(params, "class_name", path.get_file().get_basename().capitalize().replace(" ", ""))
	if not class_name_str.is_valid_identifier():
		class_name_str = "CustomData"
	var exports: Array = params.get("exports", [])
	# exports: ["health:int=100", "name:String=\"\""] or [{name, type, default}]
	var lines: PackedStringArray = []
	lines.append("class_name %s" % class_name_str)
	lines.append("extends Resource")
	lines.append("")
	if exports is Array and exports.size() > 0:
		for e in exports:
			if e is String:
				var s: String = e
				if ":" in s:
					var parts := s.split("=", true, 1)
					var left := parts[0].strip_edges()
					var def := parts[1].strip_edges() if parts.size() > 1 else ""
					var nt := left.split(":")
					var ename := nt[0].strip_edges()
					var etype := nt[1].strip_edges() if nt.size() > 1 else "Variant"
					if def.is_empty():
						lines.append("@export var %s: %s" % [ename, etype])
					else:
						lines.append("@export var %s: %s = %s" % [ename, etype, def])
				else:
					lines.append("@export var %s" % s)
			elif e is Dictionary:
				var en: String = str(e.get("name", "value"))
				var et: String = str(e.get("type", "Variant"))
				if e.has("default"):
					lines.append("@export var %s: %s = %s" % [en, et, str(e["default"])])
				else:
					lines.append("@export var %s: %s" % [en, et])
	else:
		lines.append("@export var display_name: String = \"\"")
		lines.append("@export var value: float = 0.0")
	lines.append("")
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	# Optionally create an instance .tres
	var instance_path: String = optional_string(params, "instance_path", "")
	var instance_created := false
	if not instance_path.is_empty():
		if not instance_path.begins_with("res://"):
			instance_path = "res://" + instance_path.trim_prefix("/")
		# Wait: script must be loaded — ResourceLoader may need scan
		EditorInterface.get_resource_filesystem().scan()
		var scr: Script = load(path) as Script
		if scr:
			var inst: Resource = scr.new()
			if inst:
				var err2 := ResourceSaver.save(inst, instance_path)
				instance_created = err2 == OK
	return success({
		"path": path,
		"class_name": class_name_str,
		"instance_path": instance_path if instance_created else "",
		"instance_created": instance_created,
		"hint": "Use create_resource or ResourceSaver after global class registers; reload_project if class_name not found yet.",
	})


func _duplicate_resource(params: Dictionary) -> Dictionary:
	var src_r := require_res_path(params, "path")
	if src_r[1] != null:
		return src_r[1]
	var dst: String = optional_string(params, "to", "")
	if dst.is_empty():
		dst = src_r[0].get_basename() + "_copy." + src_r[0].get_extension()
	if not dst.begins_with("res://"):
		dst = "res://" + dst.trim_prefix("/")
	if not ResourceLoader.exists(src_r[0]) and not FileAccess.file_exists(src_r[0]):
		return error_not_found(src_r[0])
	var res: Resource = load(src_r[0])
	if res == null:
		return error_internal("Failed to load %s" % src_r[0])
	var dup: Resource = res.duplicate(true)
	var derr := ensure_parent_dir(dst)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(dup, dst)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(dst)
	return success({"from": src_r[0], "to": dst, "type": dup.get_class()})
