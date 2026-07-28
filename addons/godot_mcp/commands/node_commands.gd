@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const NodeUtils := preload("res://addons/godot_mcp/utils/node_utils.gd")
const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")


func get_commands() -> Dictionary:
	return {
		"add_node": _add_node,
		"delete_node": _delete_node,
		"duplicate_node": _duplicate_node,
		"move_node": _move_node,
		"update_property": _update_property,
		"update_properties": _update_properties,
		"list_property_info": _list_property_info,
		"inspect_node": _inspect_node,
		"clear_property": _clear_property,
		"get_node_properties": _get_node_properties,
		"add_resource": _add_resource,
		"remove_resource": _remove_resource,
		"set_anchor_preset": _set_anchor_preset,
		"rename_node": _rename_node,
		"connect_signal": _connect_signal,
		"disconnect_signal": _disconnect_signal,
		"get_node_groups": _get_node_groups,
		"set_node_groups": _set_node_groups,
		"find_nodes_in_group": _find_nodes_in_group,
		"get_editor_selection": _get_editor_selection,
		"select_nodes": _select_nodes,
		"clear_editor_selection": _clear_editor_selection,
		"get_meta": _get_meta,
		"set_meta": _set_meta,
		"remove_meta": _remove_meta,
		"list_meta": _list_meta,
	}


## Resolve "shape.radius" / "shape:radius" / "shape/radius" to (object, leaf_property).
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
				"Property '%s' is null — create a resource first (add_resource)" % part,
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


func _add_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "type")
	if result[1] != null:
		return result[1]
	var type: String = result[0]

	var parent_path: String = optional_string(params, "parent_path", ".")
	var node_name: String = optional_string(params, "name", "")
	var properties: Dictionary = params.get("properties", {})

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path, "Use get_scene_tree to see available nodes")

	var node: Node
	var custom_script: Script = null

	if ClassDB.class_exists(type):
		node = ClassDB.instantiate(type)
	else:
		# Try to find a script with matching class_name
		custom_script = _find_script_by_class_name(type)
		if custom_script == null:
			return error_invalid_params("Unknown node type: '%s'. Not found in ClassDB or as a script class_name. Use list_scripts to see available script classes." % type)
		var base_type: String = custom_script.get_instance_base_type()
		if not ClassDB.class_exists(base_type):
			return error_invalid_params("Script '%s' extends '%s' which is not a valid node type" % [type, base_type])
		node = ClassDB.instantiate(base_type)
		node.set_script(custom_script)
	if not node_name.is_empty():
		node.name = node_name

	# Apply properties
	for prop_name: String in properties:
		var prop_exists := false
		for prop in node.get_property_list():
			if prop["name"] == prop_name:
				prop_exists = true
				break
		if prop_exists:
			var current: Variant = node.get(prop_name)
			var target_type := typeof(current)
			node.set(prop_name, PropertyParser.parse_value(properties[prop_name], target_type))

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add %s" % type)
	undo_redo.add_do_method(parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": type,
		"name": str(node.name),
	})


func _delete_node(params: Dictionary) -> Dictionary:
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

	if node == root:
		return error_invalid_params("Cannot delete the root node")

	var parent := node.get_parent()
	var node_name := str(node.name)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Delete %s" % node_name)
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(node, "set_owner", root)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()

	return success({"deleted": node_name})


func _duplicate_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var new_name: String = optional_string(params, "name", "")

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if new_name.is_empty():
		new_name = str(node.name) + "_copy"

	var dup := node.duplicate()
	dup.name = new_name
	var parent := node.get_parent()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Duplicate %s" % node.name)
	undo_redo.add_do_method(parent, "add_child", dup)
	undo_redo.add_do_method(dup, "set_owner", root)
	undo_redo.add_do_reference(dup)
	undo_redo.add_undo_method(parent, "remove_child", dup)
	undo_redo.commit_action()

	NodeUtils.set_owner_recursive(dup, root)

	return success({
		"original": str(root.get_path_to(node)),
		"duplicate": str(root.get_path_to(dup)),
		"name": str(dup.name),
	})


func _move_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "new_parent_path")
	if result2[1] != null:
		return result2[1]
	var new_parent_path: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if node == root:
		return error_invalid_params("Cannot move the root node")

	var new_parent := find_node_by_path(new_parent_path)
	if new_parent == null:
		return error_not_found("Target parent '%s'" % new_parent_path, "Use get_scene_tree to see available nodes")

	# Check we're not moving a node into its own subtree
	if new_parent == node or node.is_ancestor_of(new_parent):
		return error_invalid_params("Cannot move a node into its own subtree")

	var old_parent := node.get_parent()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Move %s" % node.name)
	undo_redo.add_do_method(old_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(old_parent, "add_child", node)
	undo_redo.add_undo_method(node, "set_owner", root)
	undo_redo.commit_action()

	NodeUtils.set_owner_recursive(node, root)

	return success({
		"node": str(node.name),
		"old_parent": str(root.get_path_to(old_parent)),
		"new_parent": str(root.get_path_to(new_parent)),
		"new_path": str(root.get_path_to(node)),
	})


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
		return error_invalid_params("Missing required parameter: properties (Dictionary of name → value)")
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


func _set_object_property(root: Node, node: Node, property: String, value: Variant) -> Dictionary:
	var resolved := _resolve_property_path(node, property)
	if resolved.has("error"):
		return resolved["error"]
	var target: Object = resolved["object"]
	var leaf: String = resolved["property"]

	if not leaf in target:
		var available: Array = []
		for prop in target.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_EDITOR:
				available.append(prop["name"])
		return error_not_found("Property '%s' on %s" % [property, target.get_class()],
			"Available: %s" % str(available.slice(0, 30)))

	var old_value: Variant = target.get(leaf)
	var target_type := typeof(old_value)
	var parsed_value: Variant = PropertyParser.parse_value(value, target_type)

	# Handle @export node references
	if value is String:
		for prop in target.get_property_list():
			if prop["name"] == leaf and prop["hint"] == PROPERTY_HINT_NODE_TYPE:
				var target_node: Node = node.get_node_or_null(NodePath(value))
				if target_node == null:
					target_node = root.get_node_or_null(NodePath(value))
				if target_node == null:
					return error_not_found("Node '%s'" % value, "Could not resolve node path for property '%s'" % property)
				parsed_value = target_node
				break

	if value is String and typeof(old_value) == TYPE_OBJECT and parsed_value == null:
		return error_invalid_params(
			"Could not resolve '%s' to a Resource for property '%s'" % [str(value), property])
	if value is String and parsed_value is String and typeof(old_value) in [TYPE_NIL, TYPE_OBJECT] \
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
		"old_value": PropertyParser.serialize_value(old_value),
		"new_value": PropertyParser.serialize_value(target.get(leaf)),
	})


func _list_property_info(params: Dictionary) -> Dictionary:
	## Inspector-style property catalog: types, hints, enums, ranges — for agent fine-tuning.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]
	var include_internal: bool = optional_bool(params, "include_internal", false)
	var only_editable: bool = optional_bool(params, "only_editable", true)

	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path)

	var props: Array = []
	for prop_info in node.get_property_list():
		var usage: int = prop_info["usage"]
		if only_editable and not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if not include_internal and (usage & PROPERTY_USAGE_INTERNAL):
			continue
		var prop_name: String = prop_info["name"]
		if prop_name.begins_with("_") and not include_internal:
			continue
		var entry := {
			"name": prop_name,
			"type": type_string(prop_info["type"]),
			"type_id": prop_info["type"],
			"hint": prop_info["hint"],
			"hint_string": prop_info["hint_string"],
			"usage": usage,
			"value": PropertyParser.serialize_value(node.get(prop_name)) if prop_name in node else null,
		}
		# Expand enum options for agents
		if prop_info["hint"] == PROPERTY_HINT_ENUM and str(prop_info["hint_string"]).length() > 0:
			entry["enum_options"] = str(prop_info["hint_string"]).split(",")
		if prop_info["hint"] == PROPERTY_HINT_RANGE and str(prop_info["hint_string"]).length() > 0:
			entry["range"] = str(prop_info["hint_string"])
		if prop_info["type"] == TYPE_OBJECT and prop_info["hint_string"]:
			entry["object_class"] = prop_info["hint_string"]
		props.append(entry)

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"property_count": props.size(),
		"properties": props,
		"hint": "Use update_property / update_properties. Nested: property='shape.radius' after add_resource.",
	})


func _inspect_node(params: Dictionary) -> Dictionary:
	## One-shot human-like inspector: properties, signals, groups, script, meta.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]
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
		signal_list.append({"name": sig_name, "connections": conns})

	var meta_keys: Array = []
	for k in node.get_meta_list():
		meta_keys.append(str(k))

	return success({
		"node_path": str(root.get_path_to(node)),
		"name": node.name,
		"type": node.get_class(),
		"script": script_path,
		"groups": node.get_groups(),
		"child_count": node.get_child_count(),
		"properties": NodeUtils.get_node_properties_dict(node),
		"signals": signal_list,
		"meta_keys": meta_keys,
		"hint": "Fine-tune with update_property, list_property_info for hints, connect_signal, add_resource.",
	})


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


func _get_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "key")
	if result2[1] != null:
		return result2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var key: String = result2[0]
	if not node.has_meta(key):
		return error_not_found("Meta key '%s'" % key)
	return success({
		"node_path": str(root.get_path_to(node)),
		"key": key,
		"value": PropertyParser.serialize_value(node.get_meta(key)),
	})


func _set_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "key")
	if result2[1] != null:
		return result2[1]
	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var key: String = result2[0]
	var value: Variant = PropertyParser.parse_value(params["value"])
	var old = node.get_meta(key) if node.has_meta(key) else null
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set meta %s" % key)
	undo_redo.add_do_method(node, "set_meta", key, value)
	if old != null:
		undo_redo.add_undo_method(node, "set_meta", key, old)
	else:
		undo_redo.add_undo_method(node, "remove_meta", key)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"key": key,
		"value": PropertyParser.serialize_value(node.get_meta(key)),
	})


func _remove_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "key")
	if result2[1] != null:
		return result2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var key: String = result2[0]
	if not node.has_meta(key):
		return error_not_found("Meta key '%s'" % key)
	var old = node.get_meta(key)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Remove meta %s" % key)
	undo_redo.add_do_method(node, "remove_meta", key)
	undo_redo.add_undo_method(node, "set_meta", key, old)
	undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "key": key, "removed": true})


func _list_meta(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	var meta: Dictionary = {}
	for k in node.get_meta_list():
		meta[str(k)] = PropertyParser.serialize_value(node.get_meta(k))
	return success({
		"node_path": str(root.get_path_to(node)),
		"meta": meta,
		"count": meta.size(),
	})


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


func _get_editor_selection(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var selection := EditorInterface.get_selection()
	var include_top_only: bool = optional_bool(params, "top_only", false)
	var selected_nodes: Array = selection.get_top_selected_nodes() if include_top_only else selection.get_selected_nodes()

	return success({
		"nodes": _serialize_selection_nodes(root, selected_nodes),
		"count": selected_nodes.size(),
		"top_only": include_top_only,
	})


func _select_nodes(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node_paths_result := _get_selection_node_paths(params)
	if node_paths_result[1] != null:
		return node_paths_result[1]
	var node_paths: Array = node_paths_result[0]

	var mode: String = optional_string(params, "mode", "replace")
	if mode != "replace" and mode != "add" and mode != "remove":
		return error_invalid_params("mode must be one of: replace, add, remove")

	var inspect: bool = optional_bool(params, "inspect", true)
	var focus: bool = optional_bool(params, "focus", inspect)
	var inspector_only: bool = optional_bool(params, "inspector_only", false)
	var for_property: String = optional_string(params, "for_property", "")

	var resolved_nodes: Array[Node] = []
	for node_path_variant: Variant in node_paths:
		var node_path := str(node_path_variant)
		if node_path.is_empty():
			return error_invalid_params("node_paths cannot contain empty values")
		var node := find_node_by_path(node_path)
		if node == null:
			return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")
		resolved_nodes.append(node)

	var selection := EditorInterface.get_selection()
	if mode == "replace":
		selection.clear()

	for node: Node in resolved_nodes:
		if mode == "remove":
			selection.remove_node(node)
		else:
			selection.add_node(node)

	# edit_node() and inspect_object() both reset EditorSelection to a single
	# node, which would collapse a multi-node selection down to the last node.
	# Only focus/inspect when exactly one node was selected.
	if mode != "remove" and resolved_nodes.size() == 1:
		var edited_node: Node = resolved_nodes[0]
		if focus:
			EditorInterface.edit_node(edited_node)
		if inspect:
			EditorInterface.inspect_object(edited_node, for_property, inspector_only)

	var selected_nodes: Array = selection.get_selected_nodes()
	return success({
		"mode": mode,
		"selected": _serialize_selection_nodes(root, selected_nodes),
		"count": selected_nodes.size(),
	})


func _clear_editor_selection(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var selection := EditorInterface.get_selection()
	var before_count := selection.get_selected_nodes().size()
	selection.clear()

	return success({
		"cleared": before_count,
		"selected": [],
		"count": 0,
	})


func _get_selection_node_paths(params: Dictionary) -> Array:
	if params.has("node_paths"):
		if not params["node_paths"] is Array:
			return [[], error_invalid_params("node_paths must be an array of node paths")]
		return [params["node_paths"], null]

	var result := require_string(params, "node_path")
	if result[1] != null:
		return [[], result[1]]
	return [[result[0]], null]


func _serialize_selection_nodes(root: Node, nodes: Array) -> Array:
	var serialized: Array = []
	for node: Node in nodes:
		if node == null:
			continue
		if node != root and not root.is_ancestor_of(node):
			continue
		serialized.append({
			"name": node.name,
			"path": str(root.get_path_to(node)) if node != root else ".",
			"type": node.get_class(),
		})
	return serialized


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

	# Apply resource properties if provided
	var resource_props: Dictionary = params.get("resource_properties", {})
	for prop_name: String in resource_props:
		if prop_name in resource:
			var current: Variant = resource.get(prop_name)
			resource.set(prop_name, PropertyParser.parse_value(resource_props[prop_name], typeof(current)))

	var old_value: Variant = node.get(property) if property in node else null

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add %s to %s" % [resource_type, node.name])
	undo_redo.add_do_property(node, property, resource)
	undo_redo.add_undo_property(node, property, old_value)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"property": property,
		"resource_type": resource_type,
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


func _rename_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "new_name")
	if result2[1] != null:
		return result2[1]
	var new_name: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var old_name: String = node.name
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Rename %s to %s" % [old_name, new_name])
	undo_redo.add_do_property(node, "name", new_name)
	undo_redo.add_undo_property(node, "name", old_name)
	undo_redo.commit_action()

	return success({"old_name": old_name, "new_name": str(node.name), "node_path": str(root.get_path_to(node))})


func _connect_signal(params: Dictionary) -> Dictionary:
	var result := require_string(params, "source_path")
	if result[1] != null:
		return result[1]
	var source_path: String = result[0]

	var result2 := require_string(params, "signal_name")
	if result2[1] != null:
		return result2[1]
	var signal_name: String = result2[0]

	var result3 := require_string(params, "target_path")
	if result3[1] != null:
		return result3[1]
	var target_path: String = result3[0]

	var result4 := require_string(params, "method_name")
	if result4[1] != null:
		return result4[1]
	var method_name: String = result4[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var source := find_node_by_path(source_path)
	if source == null:
		return error_not_found("Source node '%s'" % source_path)

	var target := find_node_by_path(target_path)
	if target == null:
		return error_not_found("Target node '%s'" % target_path)

	if not source.has_signal(signal_name):
		return error_invalid_params("Signal '%s' not found on %s" % [signal_name, source.get_class()])

	if source.is_connected(signal_name, Callable(target, method_name)):
		return success({"already_connected": true, "signal": signal_name})

	# CONNECT_PERSIST is required for PackedScene.pack() to serialize the
	# connection into the .tscn — without it the connection is editor-memory only.
	var flags: int = Object.CONNECT_PERSIST
	if optional_bool(params, "deferred", false):
		flags |= Object.CONNECT_DEFERRED
	if optional_bool(params, "one_shot", false):
		flags |= Object.CONNECT_ONE_SHOT

	var callable := Callable(target, method_name)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Connect signal")
	undo_redo.add_do_method(source, "connect", signal_name, callable, flags)
	undo_redo.add_undo_method(source, "disconnect", signal_name, callable)
	undo_redo.commit_action()

	return success({
		"source": str(root.get_path_to(source)),
		"signal": signal_name,
		"target": str(root.get_path_to(target)),
		"method": method_name,
		"connected": true,
		"flags": flags,
		"persistent": true,
	})


func _disconnect_signal(params: Dictionary) -> Dictionary:
	var result := require_string(params, "source_path")
	if result[1] != null:
		return result[1]
	var source_path: String = result[0]

	var result2 := require_string(params, "signal_name")
	if result2[1] != null:
		return result2[1]
	var signal_name: String = result2[0]

	var result3 := require_string(params, "target_path")
	if result3[1] != null:
		return result3[1]
	var target_path: String = result3[0]

	var result4 := require_string(params, "method_name")
	if result4[1] != null:
		return result4[1]
	var method_name: String = result4[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var source := find_node_by_path(source_path)
	if source == null:
		return error_not_found("Source node '%s'" % source_path)

	var target := find_node_by_path(target_path)
	if target == null:
		return error_not_found("Target node '%s'" % target_path)

	if not source.is_connected(signal_name, Callable(target, method_name)):
		return success({"was_connected": false})

	var callable := Callable(target, method_name)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Disconnect signal")
	undo_redo.add_do_method(source, "disconnect", signal_name, callable)
	undo_redo.add_undo_method(source, "connect", signal_name, callable)
	undo_redo.commit_action()

	return success({
		"source": str(root.get_path_to(source)),
		"signal": signal_name,
		"target": str(root.get_path_to(target)),
		"method": method_name,
		"disconnected": true,
	})


func _get_node_groups(params: Dictionary) -> Dictionary:
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

	var groups: Array = []
	for group: StringName in node.get_groups():
		var g := str(group)
		# Filter out internal groups (start with _)
		if not g.begins_with("_"):
			groups.append(g)

	return success({
		"node_path": str(root.get_path_to(node)),
		"groups": groups,
		"count": groups.size(),
	})


func _set_node_groups(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	if not params.has("groups") or not params["groups"] is Array:
		return error_invalid_params("'groups' array is required")
	var desired_groups: Array = params["groups"]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	# Get current non-internal groups
	var current_groups: Array = []
	for group: StringName in node.get_groups():
		var g := str(group)
		if not g.begins_with("_"):
			current_groups.append(g)

	var added: Array = []
	var removed: Array = []

	for group: String in current_groups:
		if group not in desired_groups:
			removed.append(group)

	for group in desired_groups:
		var g: String = str(group)
		if g not in current_groups:
			added.append(g)

	if not added.is_empty() or not removed.is_empty():
		var undo_redo := get_undo_redo()
		undo_redo.create_action("MCP: Set node groups")
		for group: String in removed:
			undo_redo.add_do_method(node, "remove_from_group", group)
			undo_redo.add_undo_method(node, "add_to_group", group, true)
		for group: String in added:
			undo_redo.add_do_method(node, "add_to_group", group, true)
			undo_redo.add_undo_method(node, "remove_from_group", group)
		undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"groups": desired_groups,
		"added": added,
		"removed": removed,
	})


func _find_nodes_in_group(params: Dictionary) -> Dictionary:
	var result := require_string(params, "group")
	if result[1] != null:
		return result[1]
	var group_name: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var matches: Array = []
	_find_in_group_recursive(root, root, group_name, matches)

	return success({
		"group": group_name,
		"nodes": matches,
		"count": matches.size(),
	})


func _find_in_group_recursive(node: Node, root: Node, group_name: String, matches: Array) -> void:
	if node.is_in_group(group_name):
		matches.append({
			"name": node.name,
			"path": str(root.get_path_to(node)),
			"type": node.get_class(),
		})
	for child in node.get_children():
		_find_in_group_recursive(child, root, group_name, matches)
