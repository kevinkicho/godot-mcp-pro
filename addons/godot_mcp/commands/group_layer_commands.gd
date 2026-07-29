@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Groups + physics/render layer naming — project structure agents always need.


func get_commands() -> Dictionary:
	return {
		"list_project_groups": _list_project_groups,
		"set_physics_layer_names": _set_physics_layer_names,
		"get_physics_layer_names": _get_physics_layer_names,
		"set_render_layer_names": _set_render_layer_names,
		"get_render_layer_names": _get_render_layer_names,
		"find_nodes_in_group": _find_nodes_in_group,
		"batch_set_node_groups": _batch_set_node_groups,
		"list_group_layer_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["set_node_groups", "get_node_groups", "set_physics_layers", "scaffold_project_defaults"],
	})


func _list_project_groups(_params: Dictionary) -> Dictionary:
	## Collect groups used in open scene (edited tree).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var groups := {}
	_walk_groups(root, groups)
	var out: Array = []
	for g in groups.keys():
		out.append({"group": g, "count": groups[g]})
	out.sort_custom(func(a, b): return str(a.get("group")) < str(b.get("group")))
	return success({"groups": out, "count": out.size()})


func _walk_groups(n: Node, groups: Dictionary) -> void:
	for g in n.get_groups():
		var gs := str(g)
		if gs.begins_with("_"):
			continue
		groups[gs] = int(groups.get(gs, 0)) + 1
	for c in n.get_children():
		_walk_groups(c, groups)


func _set_physics_layer_names(params: Dictionary) -> Dictionary:
	## names: {1:"player", 2:"world"} or array of 1..32 names
	var dim: String = optional_string(params, "dimension", "3d").to_lower()
	var prefix := "layer_names/3d_physics/layer_%d" if dim != "2d" else "layer_names/2d_physics/layer_%d"
	var applied := {}
	if params.has("names") and params["names"] is Dictionary:
		for k in params["names"]:
			var idx := int(k)
			if idx < 1 or idx > 32:
				continue
			var key := prefix % idx
			ProjectSettings.set_setting(key, str(params["names"][k]))
			applied[str(idx)] = str(params["names"][k])
	elif params.has("names") and params["names"] is Array:
		var arr: Array = params["names"]
		for i in range(mini(arr.size(), 32)):
			var key := prefix % (i + 1)
			ProjectSettings.set_setting(key, str(arr[i]))
			applied[str(i + 1)] = str(arr[i])
	else:
		return error_invalid_params("names Dictionary {1:\"player\"} or Array required")
	ProjectSettings.save()
	return success({"dimension": dim, "applied": applied})


func _get_physics_layer_names(params: Dictionary) -> Dictionary:
	var dim: String = optional_string(params, "dimension", "3d").to_lower()
	var prefix := "layer_names/3d_physics/layer_%d" if dim != "2d" else "layer_names/2d_physics/layer_%d"
	var names := {}
	for i in range(1, 33):
		var key := prefix % i
		if ProjectSettings.has_setting(key):
			var v := str(ProjectSettings.get_setting(key))
			if not v.is_empty():
				names[str(i)] = v
	return success({"dimension": dim, "names": names})


func _set_render_layer_names(params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("names") and params["names"] is Dictionary:
		for k in params["names"]:
			var idx := int(k)
			if idx < 1 or idx > 20:
				continue
			var key := "layer_names/3d_render/layer_%d" % idx
			ProjectSettings.set_setting(key, str(params["names"][k]))
			applied[str(idx)] = str(params["names"][k])
	else:
		return error_invalid_params("names Dictionary required")
	ProjectSettings.save()
	return success({"applied": applied})


func _get_render_layer_names(_params: Dictionary) -> Dictionary:
	var names := {}
	for i in range(1, 21):
		var key := "layer_names/3d_render/layer_%d" % i
		if ProjectSettings.has_setting(key):
			var v := str(ProjectSettings.get_setting(key))
			if not v.is_empty():
				names[str(i)] = v
	return success({"names": names})


func _find_nodes_in_group(params: Dictionary) -> Dictionary:
	var group_r := require_string(params, "group")
	if group_r[1] != null:
		return group_r[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var found: Array = []
	_find_group(root, root, group_r[0], found, clampi(optional_int(params, "max", 100), 1, 1000))
	return success({"group": group_r[0], "nodes": found, "count": found.size()})


func _find_group(n: Node, root: Node, group: String, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	if n.is_in_group(group):
		out.append({"path": str(root.get_path_to(n)), "class": n.get_class(), "name": n.name})
	for c in n.get_children():
		_find_group(c, root, group, out, max_n)


func _batch_set_node_groups(params: Dictionary) -> Dictionary:
	## items: [{node_path, groups:[...], mode:set|add}]
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("items array required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var results: Array = []
	for item in params["items"]:
		if not item is Dictionary:
			continue
		var np := str(item.get("node_path", item.get("path", "")))
		var n := find_node_by_path(np)
		if n == null:
			results.append({"path": np, "ok": false, "error": "not found"})
			continue
		var groups: Array = item.get("groups", [])
		var mode: String = str(item.get("mode", "set")).to_lower()
		if mode == "set":
			for g in n.get_groups():
				if not str(g).begins_with("_"):
					n.remove_from_group(str(g))
		for g in groups:
			n.add_to_group(str(g), true)
		results.append({"path": np, "ok": true, "groups": groups})
	mark_current_scene_unsaved()
	return success({"results": results, "count": results.size()})
