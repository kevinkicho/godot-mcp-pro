@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")

## Node property / inspector / resource surface.

func get_commands() -> Dictionary:
	return {
		"update_property": _update_property,
		"update_properties": _update_properties,
		"get_property": _get_property,
		"list_property_info": _list_property_info,
		"search_properties": _search_properties,
		"reset_property": _reset_property,
		"inspect_node": _inspect_node,
		"list_node_methods": _list_node_methods,
		"call_node_method": _call_node_method,
		"clear_property": _clear_property,
		"get_node_properties": _get_node_properties,
		"add_resource": _add_resource,
		"remove_resource": _remove_resource,
		"set_anchor_preset": _set_anchor_preset,
		"batch_update_property": _batch_update_property,
	}

func _resolve_property_path(root_obj: Object, property_path: String) -> Dictionary:
	var normalized := property_path.replace(":", "/").replace(".", "/")
	var parts := normalized.split("/", false)
	if parts.is_empty():
		return {"error": error_invalid_params("Empty property path")}
	var obj: Object = root_obj
	for i in range(parts.size() - 1):
		var part: String = parts[i]
		if obj == null or not part in obj:
			return {"error": error_not_found("Property path segment '%s' on %s" % [part, obj.get_class() if obj else "null"])}
		var next: Variant = obj.get(part)
		if next == null:
			return {"error": error_not_found(
				"Property '%s' is null  -  create a resource first (add_resource)" % part,
				"Example: add_resource node_path=... property=%s resource_type=RectangleShape2D" % part
			)}
		if not next is Object:
			return {"error": error_invalid_params("Cannot traverse into non-object property '%s'" % part)}
		obj = next as Object
	return {"object": obj, "property": parts[parts.size() - 1], "path": property_path}



func _find_script_by_class_name(class_name_str: String) -> Script:
	# Search project files for a script with matching class_name
	var global_classes: Array = ProjectSettings.get_global_class_list()
	for entry: Dictionary in global_classes:
		if entry.get("class", "") == class_name_str:
			var path: String = entry.get("path", "")
			if not path.is_empty():
				return load(path) as Script
	return null



func _update_property(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var property: String = result2[0]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")
	var value: Variant = params["value"]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	return _set_object_property(root, node, property, value)



func _update_properties(params: Dictionary) -> Dictionary:
	## Batch fine-tune: set many properties on one node (human inspector multi-edit).
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]
	if not params.has("properties") or not params["properties"] is Dictionary:
		return error_invalid_params("Missing required parameter: properties (Dictionary of name -> value)")
	var properties: Dictionary = params["properties"]
	if properties.is_empty():
		return error_invalid_params("properties dictionary is empty")

	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var changed: Array = []
	var errors: Array = []
	for prop_name: String in properties:
		var one := _set_object_property(root, node, prop_name, properties[prop_name])
		if one.has("error"):
			errors.append({"property": prop_name, "error": one["error"]})
		else:
			var res: Dictionary = one.get("result", {})
			changed.append({
				"property": prop_name,
				"old_value": res.get("old_value"),
				"new_value": res.get("new_value"),
			})

	return success({
		"node_path": str(root.get_path_to(node)),
		"changed": changed,
		"changed_count": changed.size(),
		"errors": errors,
	})



func _find_prop_info(obj: Object, leaf: String) -> Dictionary:
	for prop in obj.get_property_list():
		if prop["name"] == leaf:
			return prop
	return {}



func _set_object_property(root: Node, node: Node, property: String, value: Variant) -> Dictionary:
	var resolved := _resolve_property_path(node, property)
	if resolved.has("error"):
		return resolved["error"]
	var target: Object = resolved["object"]
	var leaf: String = resolved["property"]

	var prop_info := _find_prop_info(target, leaf)
	if prop_info.is_empty() and not leaf in target:
		var available: Array = []
		for prop in target.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_EDITOR:
				available.append(prop["name"])
		return error_not_found("Property '%s' on %s" % [property, target.get_class()],
			"Available: %s  -  use list_property_info / search_properties" % str(available.slice(0, 40)))

	var old_value: Variant = target.get(leaf) if leaf in target else null
	var target_type: int = int(prop_info.get("type", typeof(old_value))) if not prop_info.is_empty() else typeof(old_value)
	var hint: int = int(prop_info.get("hint", PROPERTY_HINT_NONE)) if not prop_info.is_empty() else PROPERTY_HINT_NONE
	var hint_string: String = str(prop_info.get("hint_string", "")) if not prop_info.is_empty() else ""

	# Prefer declared type when current value is null (e.g. empty resource slots)
	if old_value == null and not prop_info.is_empty() and target_type != TYPE_NIL:
		pass  # use prop_info type
	elif old_value != null:
		target_type = typeof(old_value)

	var parsed_value: Variant = PropertyParser.parse_value(value, target_type, hint, hint_string)

	# Handle @export Node / NodePath references
	if value is String:
		if target_type == TYPE_NODE_PATH:
			parsed_value = NodePath(str(value))
		elif hint == PROPERTY_HINT_NODE_TYPE:
			var target_node: Node = node.get_node_or_null(NodePath(value))
			if target_node == null:
				target_node = root.get_node_or_null(NodePath(value))
			if target_node == null:
				return error_not_found("Node '%s'" % value, "Could not resolve node path for property '%s'" % property)
			parsed_value = target_node

	if value is String and target_type == TYPE_OBJECT and parsed_value == null and not str(value).is_empty():
		return error_invalid_params(
			"Could not resolve '%s' to a Resource/Object for property '%s'. Use res:// path or add_resource first." % [str(value), property])
	if value is String and parsed_value is String and target_type in [TYPE_NIL, TYPE_OBJECT] \
			and (str(value).begins_with("res://") or str(value).begins_with("uid://")):
		return error_not_found("Resource '%s'" % str(value),
			"The path could not be loaded for property '%s'" % property)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set %s.%s" % [node.name, property])
	undo_redo.add_do_property(target, leaf, parsed_value)
	undo_redo.add_undo_property(target, leaf, old_value)
	undo_redo.commit_action()
	mark_current_scene_unsaved()

	return success({
		"node": str(root.get_path_to(node)),
		"property": property,
		"type": type_string(target_type),
		"old_value": PropertyParser.serialize_value(old_value),
		"new_value": PropertyParser.serialize_value(target.get(leaf)),
	})



func _get_property(params: Dictionary) -> Dictionary:
	## Single property with full metadata  -  agent fine-tune read path.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var property: String = result2[0]
	var resolved := _resolve_property_path(node, property)
	if resolved.has("error"):
		return resolved["error"]
	var target: Object = resolved["object"]
	var leaf: String = resolved["property"]
	var prop_info := _find_prop_info(target, leaf)
	if prop_info.is_empty() and not leaf in target:
		return error_not_found("Property '%s'" % property, "Use list_property_info or search_properties")
	var entry: Dictionary
	if prop_info.is_empty():
		entry = {
			"name": leaf,
			"path": property,
			"type": type_string(typeof(target.get(leaf))),
			"value": PropertyParser.serialize_value(target.get(leaf)),
		}
	else:
		var prefix := property.substr(0, property.rfind(".")) if property.contains(".") or property.contains("/") else ""
		if property.contains("/"):
			prefix = property.substr(0, property.rfind("/")).replace("/", ".")
		elif property.contains("."):
			prefix = property.substr(0, property.rfind("."))
		else:
			prefix = ""
		entry = PropertyParser.property_entry(target, prop_info, prefix)
		entry["path"] = property
	return success({
		"node_path": str(root.get_path_to(node)),
		"node_type": node.get_class(),
		"property": entry,
	})



func _catalog_object_properties(
	obj: Object,
	path_prefix: String,
	only_editable: bool,
	include_internal: bool,
	include_headers: bool,
	filter: String,
	recurse_resources: bool,
	max_depth: int,
	depth: int,
	out: Array,
	max_props: int
) -> void:
	if obj == null or out.size() >= max_props:
		return
	var filter_l := filter.to_lower()
	for prop_info in obj.get_property_list():
		if out.size() >= max_props:
			break
		var usage: int = prop_info["usage"]
		var is_header := (usage & PROPERTY_USAGE_CATEGORY) or (usage & PROPERTY_USAGE_GROUP) or (usage & PROPERTY_USAGE_SUBGROUP)
		if is_header:
			if include_headers:
				var h := PropertyParser.property_entry(obj, prop_info, path_prefix)
				out.append(h)
			continue
		if only_editable and not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if not include_internal and (usage & PROPERTY_USAGE_INTERNAL):
			continue
		var prop_name: String = prop_info["name"]
		if prop_name.begins_with("_") and not include_internal:
			continue
		if prop_name == "script" and only_editable:
			continue
		var full_path := prop_name if path_prefix.is_empty() else "%s.%s" % [path_prefix, prop_name]
		if not filter_l.is_empty() and not full_path.to_lower().contains(filter_l) and not prop_name.to_lower().contains(filter_l):
			# Still recurse into resources if name doesn't match  -  nested may match
			if not (recurse_resources and prop_info["type"] == TYPE_OBJECT):
				continue
		var entry := PropertyParser.property_entry(obj, prop_info, path_prefix)
		if filter_l.is_empty() or full_path.to_lower().contains(filter_l) or prop_name.to_lower().contains(filter_l):
			out.append(entry)
		if recurse_resources and depth < max_depth and prop_info["type"] == TYPE_OBJECT and prop_name in obj:
			var nested = obj.get(prop_name)
			if nested is Resource:
				_catalog_object_properties(
					nested, full_path, only_editable, include_internal, include_headers,
					filter, recurse_resources, max_depth, depth + 1, out, max_props
				)



func _list_property_info(params: Dictionary) -> Dictionary:
	## Inspector-style property catalog: types, hints, enums, ranges, nested resources.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]
	var include_internal: bool = optional_bool(params, "include_internal", false)
	var only_editable: bool = optional_bool(params, "only_editable", true)
	var include_headers: bool = optional_bool(params, "include_headers", false)
	var recurse_resources: bool = optional_bool(params, "recurse_resources", false)
	var max_depth: int = clampi(optional_int(params, "max_depth", 2), 0, 4)
	var filter: String = optional_string(params, "filter", "")
	var property_path: String = optional_string(params, "property_path", "")
	var max_props: int = clampi(optional_int(params, "max", 500), 1, 2000)

	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path)

	var target: Object = node
	var path_prefix := ""
	if not property_path.is_empty():
		var resolved := _resolve_property_path(node, property_path)
		if resolved.has("error"):
			# property_path may point at the object itself (no leaf)  -  try parent path
			return resolved["error"]
		# If user passed path to a resource slot value, resolve to that object
		var leaf: String = resolved["property"]
		var parent_obj: Object = resolved["object"]
		if leaf in parent_obj:
			var val = parent_obj.get(leaf)
			if val is Object:
				target = val
				path_prefix = property_path.replace(":", ".").replace("/", ".")
			else:
				return error_invalid_params("property_path '%s' is not an Object/Resource  -  use get_property" % property_path)
		else:
			return error_not_found("property_path '%s'" % property_path)

	var props: Array = []
	_catalog_object_properties(
		target, path_prefix, only_editable, include_internal, include_headers,
		filter, recurse_resources, max_depth, 0, props, max_props
	)

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"catalog_root": target.get_class() if target else "",
		"property_path": property_path,
		"property_count": props.size(),
		"properties": props,
		"recurse_resources": recurse_resources,
		"hint": "update_property / update_properties; nested paths e.g. shape.radius; enums by name; get_property for one field; call_node_method for methods.",
	})



func _search_properties(params: Dictionary) -> Dictionary:
	## Find properties by name substring across a node (and optional nested resources).
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var query: String = optional_string(params, "query", optional_string(params, "filter", ""))
	if query.is_empty():
		return error_invalid_params("query (or filter) is required")
	params = params.duplicate()
	params["filter"] = query
	params["recurse_resources"] = optional_bool(params, "recurse_resources", true)
	params["only_editable"] = optional_bool(params, "only_editable", true)
	return _list_property_info(params)



func _reset_property(params: Dictionary) -> Dictionary:
	## Revert a property to editor default (inspector Revert) when available.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var property: String = result2[0]
	var resolved := _resolve_property_path(node, property)
	if resolved.has("error"):
		return resolved["error"]
	var target: Object = resolved["object"]
	var leaf: String = resolved["property"]
	if not leaf in target:
		return error_not_found("Property '%s'" % property)
	var old_value: Variant = target.get(leaf)
	var new_value: Variant = null
	var reverted := false
	if target is Node and (target as Node).property_can_revert(leaf):
		new_value = (target as Node).property_get_revert(leaf)
		reverted = true
	elif target.has_method("property_can_revert") and target.property_can_revert(leaf):
		new_value = target.property_get_revert(leaf)
		reverted = true
	else:
		return error_invalid_params(
			"No revert default for '%s'  -  set an explicit value with update_property" % property
		)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Reset %s.%s" % [node.name, property])
	undo_redo.add_do_property(target, leaf, new_value)
	undo_redo.add_undo_property(target, leaf, old_value)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node": str(root.get_path_to(node)),
		"property": property,
		"reverted": reverted,
		"old_value": PropertyParser.serialize_value(old_value),
		"new_value": PropertyParser.serialize_value(target.get(leaf)),
	})



func _list_node_methods(params: Dictionary) -> Dictionary:
	## Instance methods (ClassDB + script) for call_node_method discovery.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var filter: String = optional_string(params, "filter", "").to_lower()
	var include_inherited: bool = optional_bool(params, "include_inherited", true)
	var max_n: int = clampi(optional_int(params, "max", 200), 1, 1000)
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var methods: Array = []
	var seen := {}
	for m in node.get_method_list():
		if not m is Dictionary:
			continue
		var mname: String = str(m.get("name", ""))
		if mname.is_empty() or seen.has(mname):
			continue
		if mname.begins_with("_") and not optional_bool(params, "include_private", false):
			continue
		if not filter.is_empty() and not mname.to_lower().contains(filter):
			continue
		# Skip pure engine internals when not include_inherited... still on instance list
		seen[mname] = true
		var args: Array = []
		for a in m.get("args", []):
			if a is Dictionary:
				args.append({
					"name": a.get("name", ""),
					"type": type_string(a.get("type", 0)),
					"class_name": str(a.get("class_name", "")),
				})
		methods.append({"name": mname, "args": args, "flags": m.get("flags", 0)})
		if methods.size() >= max_n:
			break
	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"method_count": methods.size(),
		"methods": methods,
		"hint": "call_node_method node_path=... method=... args=[...]",
		"include_inherited_note": include_inherited,
	})



func _call_node_method(params: Dictionary) -> Dictionary:
	## Call a method on a scene node (structured alternative to execute_editor_script).
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "method")
	if result2[1] != null:
		return result2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var method: String = result2[0]
	if not node.has_method(method):
		return error_not_found("Method '%s' on %s" % [method, node.get_class()],
			"Use list_node_methods or describe_class")
	var args: Array = []
	if params.has("args") and params["args"] is Array:
		for a in params["args"]:
			args.append(PropertyParser.parse_value(a))
	var ret: Variant = node.callv(method, args)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"method": method,
		"args_count": args.size(),
		"return": PropertyParser.serialize_value(ret),
	})



func _inspect_node(params: Dictionary) -> Dictionary:
	## One-shot human-like inspector: properties, signals, groups, script, meta.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]
	var deep: bool = optional_bool(params, "deep", false)
	var include_methods: bool = optional_bool(params, "include_methods", false)
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path)

	var script_path := ""
	var script: Script = node.get_script()
	if script:
		script_path = script.resource_path

	var signal_list: Array = []
	for sig in node.get_signal_list():
		var sig_name: String = sig["name"]
		var conns: Array = []
		for c in node.get_signal_connection_list(sig_name):
			var callable: Callable = c["callable"]
			var target_obj = callable.get_object()
			var target_path := str(target_obj)
			if target_obj is Node:
				var tn: Node = target_obj
				if tn == root or root.is_ancestor_of(tn):
					target_path = str(root.get_path_to(tn))
			conns.append({
				"target": target_path,
				"method": str(callable.get_method()),
				"flags": c.get("flags", 0),
			})
		signal_list.append({"name": sig_name, "connections": conns, "args": sig.get("args", [])})

	var meta_keys: Array = []
	for k in node.get_meta_list():
		meta_keys.append(str(k))

	var props: Variant = NodeUtils.get_node_properties_dict(node)
	var prop_info: Array = []
	if deep:
		_catalog_object_properties(
			node, "", true, false, false, "", true, 2, 0, prop_info, 400
		)

	var out := {
		"node_path": str(root.get_path_to(node)),
		"name": node.name,
		"type": node.get_class(),
		"script": script_path,
		"groups": node.get_groups(),
		"child_count": node.get_child_count(),
		"properties": props,
		"signals": signal_list,
		"meta_keys": meta_keys,
		"process_mode": node.process_mode,
		"hint": "Fine-tune: list_property_info -> update_property/update_properties; nested shape.radius; call_node_method; describe_class for ClassDB.",
	}
	if deep:
		out["property_info"] = prop_info
		out["property_info_count"] = prop_info.size()
	if include_methods:
		var ml: Array = []
		for m in node.get_method_list():
			var mn := str(m.get("name", ""))
			if mn.begins_with("_"):
				continue
			ml.append(mn)
			if ml.size() >= 80:
				break
		out["methods_sample"] = ml
	return success(out)


func _clear_property(params: Dictionary) -> Dictionary:
	## Clear an Object property (e.g. remove mesh/material) or reset with explicit null.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]
	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var property: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path)

	return _set_object_property(root, node, property, null)



func _remove_resource(params: Dictionary) -> Dictionary:
	## Alias for clearing a resource-typed property on a node (human: clear slot in inspector).
	return _clear_property(params)



func _get_node_properties(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var category: String = optional_string(params, "category", "")
	var props := NodeUtils.get_node_properties_dict(node)

	# Filter by category if specified
	if not category.is_empty():
		var filtered: Dictionary = {}
		for key: String in props:
			if key.begins_with(category):
				filtered[key] = props[key]
		props = filtered

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"properties": props,
	})



func _add_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var property: String = result2[0]

	var result3 := require_string(params, "resource_type")
	if result3[1] != null:
		return result3[1]
	var resource_type: String = result3[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not ClassDB.class_exists(resource_type):
		return error_invalid_params("Unknown resource type: %s" % resource_type)

	if not ClassDB.is_parent_class(resource_type, "Resource"):
		return error_invalid_params("'%s' is not a Resource type" % resource_type)

	var resource: Resource = ClassDB.instantiate(resource_type)
	if resource == null:
		return error_internal("Failed to create resource: %s" % resource_type)

	# Apply resource properties if provided (supports nested keys on the new resource)
	var resource_props: Dictionary = params.get("resource_properties", {})
	for prop_name: String in resource_props:
		if prop_name in resource:
			var current: Variant = resource.get(prop_name)
			var pi := _find_prop_info(resource, prop_name)
			resource.set(prop_name, PropertyParser.parse_value(
				resource_props[prop_name],
				int(pi.get("type", typeof(current))) if not pi.is_empty() else typeof(current),
				int(pi.get("hint", 0)) if not pi.is_empty() else 0,
				str(pi.get("hint_string", "")) if not pi.is_empty() else ""
			))

	# Nested property paths: material_override. next_pass etc.
	var resolved := _resolve_property_path(node, property)
	if resolved.has("error"):
		return resolved["error"]
	var target: Object = resolved["object"]
	var leaf: String = resolved["property"]
	var old_value: Variant = target.get(leaf) if leaf in target else null

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add %s to %s.%s" % [resource_type, node.name, property])
	undo_redo.add_do_property(target, leaf, resource)
	undo_redo.add_undo_property(target, leaf, old_value)
	undo_redo.commit_action()
	mark_current_scene_unsaved()

	return success({
		"node_path": str(root.get_path_to(node)),
		"property": property,
		"resource_type": resource_type,
		"resource_properties_applied": resource_props.keys(),
		"hint": "Fine-tune with update_property property='%s.field' or list_property_info property_path='%s' recurse_resources=true" % [property, property],
	})



func _set_anchor_preset(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "preset")
	if result2[1] != null:
		return result2[1]
	var preset_name: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not node is Control:
		return error_invalid_params("Node '%s' is not a Control (is %s)" % [node_path, node.get_class()])

	var control: Control = node
	var presets := {
		"top_left": Control.PRESET_TOP_LEFT,
		"top_right": Control.PRESET_TOP_RIGHT,
		"bottom_left": Control.PRESET_BOTTOM_LEFT,
		"bottom_right": Control.PRESET_BOTTOM_RIGHT,
		"center_left": Control.PRESET_CENTER_LEFT,
		"center_top": Control.PRESET_CENTER_TOP,
		"center_right": Control.PRESET_CENTER_RIGHT,
		"center_bottom": Control.PRESET_CENTER_BOTTOM,
		"center": Control.PRESET_CENTER,
		"left_wide": Control.PRESET_LEFT_WIDE,
		"top_wide": Control.PRESET_TOP_WIDE,
		"right_wide": Control.PRESET_RIGHT_WIDE,
		"bottom_wide": Control.PRESET_BOTTOM_WIDE,
		"vcenter_wide": Control.PRESET_VCENTER_WIDE,
		"hcenter_wide": Control.PRESET_HCENTER_WIDE,
		"full_rect": Control.PRESET_FULL_RECT,
	}

	if not presets.has(preset_name):
		return error_invalid_params("Unknown preset: '%s'. Available: %s" % [preset_name, presets.keys()])

	var keep_offsets: bool = optional_bool(params, "keep_offsets", false)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set anchor preset on %s" % node.name)

	# Store old values
	var old_anchors := [control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom]
	var old_offsets := [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]

	var target: Control = control.duplicate() as Control
	target.set_anchors_and_offsets_preset(presets[preset_name],
		Control.PRESET_MODE_KEEP_SIZE if keep_offsets else Control.PRESET_MODE_MINSIZE)

	undo_redo.add_do_property(control, "anchor_left", target.anchor_left)
	undo_redo.add_do_property(control, "anchor_top", target.anchor_top)
	undo_redo.add_do_property(control, "anchor_right", target.anchor_right)
	undo_redo.add_do_property(control, "anchor_bottom", target.anchor_bottom)
	undo_redo.add_do_property(control, "offset_left", target.offset_left)
	undo_redo.add_do_property(control, "offset_top", target.offset_top)
	undo_redo.add_do_property(control, "offset_right", target.offset_right)
	undo_redo.add_do_property(control, "offset_bottom", target.offset_bottom)

	undo_redo.add_undo_property(control, "anchor_left", old_anchors[0])
	undo_redo.add_undo_property(control, "anchor_top", old_anchors[1])
	undo_redo.add_undo_property(control, "anchor_right", old_anchors[2])
	undo_redo.add_undo_property(control, "anchor_bottom", old_anchors[3])
	undo_redo.add_undo_property(control, "offset_left", old_offsets[0])
	undo_redo.add_undo_property(control, "offset_top", old_offsets[1])
	undo_redo.add_undo_property(control, "offset_right", old_offsets[2])
	undo_redo.add_undo_property(control, "offset_bottom", old_offsets[3])

	target.free()
	undo_redo.commit_action()

	return success({"node_path": str(root.get_path_to(control)), "preset": preset_name})



func _batch_update_property(params: Dictionary) -> Dictionary:
	## Set the same property on many nodes (multi-select inspector).
	var paths: Array = params.get("node_paths", [])
	if paths.is_empty():
		return error_invalid_params("node_paths required")
	var prop_r := require_string(params, "property")
	if prop_r[1] != null:
		return prop_r[1]
	if not params.has("value"):
		return error_invalid_params("value required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var results: Array = []
	for p in paths:
		var one := _set_object_property(root, find_node_by_path(str(p)), prop_r[0], params["value"]) if find_node_by_path(str(p)) else {"error": {"message": "not found"}}
		if find_node_by_path(str(p)) == null:
			results.append({"path": str(p), "error": "not found"})
		else:
			var node := find_node_by_path(str(p))
			var r := _set_object_property(root, node, prop_r[0], params["value"])
			results.append({"path": str(p), "result": r})
	return success({"results": results, "count": results.size(), "property": prop_r[0]})

