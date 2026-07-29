@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Make unique / local_to_scene — inspector Resource dropdown parity for agents.


func get_commands() -> Dictionary:
	return {
		"make_resource_unique": _make_unique,
		"set_resource_local_to_scene": _set_local,
		"duplicate_subresource_on_node": _duplicate_sub,
		"list_resource_unique_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["add_resource", "update_property", "duplicate_resource", "get_resource_info"],
		"workflow": "inspect_node deep → make_resource_unique node_path=… property=material_override",
	})


func _make_unique(params: Dictionary) -> Dictionary:
	## Duplicate the resource at property so the node owns a unique copy.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var prop_r := require_string(params, "property")
	if prop_r[1] != null:
		return prop_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var prop: String = prop_r[0]
	var value: Variant = _get_nested(node, prop)
	if value == null:
		return error_invalid_params("Property '%s' not found or null" % prop)
	if not (value is Resource):
		return error_invalid_params("Property '%s' is not a Resource" % prop)
	var dup: Resource = (value as Resource).duplicate(optional_bool(params, "deep", true))
	if optional_bool(params, "local_to_scene", true):
		dup.resource_local_to_scene = true
	_set_nested(node, prop, dup)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"property": prop,
		"class": dup.get_class(),
		"local_to_scene": dup.resource_local_to_scene,
		"resource_path": dup.resource_path,
	})


func _set_local(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var prop_r := require_string(params, "property")
	if prop_r[1] != null:
		return prop_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var value: Variant = _get_nested(node, prop_r[0])
	if not (value is Resource):
		return error_invalid_params("Not a Resource")
	var res: Resource = value as Resource
	res.resource_local_to_scene = optional_bool(params, "local_to_scene", true)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"property": prop_r[0],
		"local_to_scene": res.resource_local_to_scene,
	})


func _duplicate_sub(params: Dictionary) -> Dictionary:
	## Alias of make_unique with deep default.
	params = params.duplicate()
	params["deep"] = optional_bool(params, "deep", true)
	return _make_unique(params)


func _get_nested(obj: Object, path: String) -> Variant:
	var parts := path.split(".")
	var cur: Variant = obj
	for i in parts.size():
		var p: String = parts[i]
		if cur == null:
			return null
		if cur is Object:
			if p in cur:
				cur = cur.get(p)
			else:
				return null
		else:
			return null
	return cur


func _set_nested(obj: Object, path: String, value: Variant) -> void:
	var parts := path.split(".")
	if parts.size() == 1:
		obj.set(parts[0], value)
		return
	var cur: Object = obj
	for i in range(parts.size() - 1):
		var next = cur.get(parts[i])
		if next is Object:
			cur = next
		else:
			return
	cur.set(parts[parts.size() - 1], value)
