@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Multi TileMapLayer stack authoring (Godot 4 recommended tilemap structure).


func get_commands() -> Dictionary:
	return {
		"setup_tilemap_layer": _setup_layer,
		"setup_tilemap_layer_stack": _setup_stack,
		"list_tilemap_layers": _list_layers,
		"assign_tileset_to_layers": _assign_tileset,
		"set_tilemap_layer_props": _set_layer_props,
		"list_tilemap_layer_stack_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["tileset_create", "tileset_assign_to_tilemap", "tilemap_set_cell", "tilemap_paint_cells"],
		"workflow": [
			"tileset_create path=res://tiles/world.tres",
			"setup_tilemap_layer_stack layers=[{name:Ground},{name:Decor,z_index:1}] tileset_path=…",
			"tilemap_set_cell node_path=Ground …",
		],
	})


func _setup_layer(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := TileMapLayer.new()
	layer.name = optional_string(params, "name", "TileMapLayer")
	if params.has("z_index"):
		layer.z_index = int(params["z_index"])
	if params.has("y_sort_enabled"):
		layer.y_sort_enabled = bool(params["y_sort_enabled"])
	if params.has("enabled"):
		layer.enabled = bool(params["enabled"])
	if params.has("collision_enabled"):
		layer.collision_enabled = bool(params["collision_enabled"])
	if params.has("navigation_enabled"):
		layer.navigation_enabled = bool(params["navigation_enabled"])
	if params.has("modulate"):
		var m: String = str(params["modulate"])
		layer.modulate = Color.html(m) if m.begins_with("#") else Color(m)
	var tileset_path: String = optional_string(params, "tileset_path", "")
	if not tileset_path.is_empty():
		var vr := validate_res_path(tileset_path)
		if vr[1] != null:
			return vr[1]
		if ResourceLoader.exists(vr[0]):
			var ts = load(vr[0])
			if ts is TileSet:
				layer.tile_set = ts
	add_child_with_undo(parent, layer, root, "MCP: TileMapLayer")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(layer)),
		"tileset_path": tileset_path,
		"z_index": layer.z_index,
	})


func _setup_stack(params: Dictionary) -> Dictionary:
	## layers: [{name, z_index, y_sort_enabled, …}] or names: ["Ground","Walls","Decor"]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	# Optional root Node2D wrapper
	var stack_parent: Node = parent
	if optional_bool(params, "create_root", true):
		var wrap := Node2D.new()
		wrap.name = optional_string(params, "root_name", "TileMap")
		if params.has("y_sort_enabled"):
			wrap.y_sort_enabled = bool(params["y_sort_enabled"])
		add_child_with_undo(parent, wrap, root, "MCP: TileMap stack root")
		stack_parent = wrap
	var tileset_path: String = optional_string(params, "tileset_path", "")
	var layer_defs: Array = []
	if params.has("layers") and params["layers"] is Array:
		layer_defs = params["layers"]
	elif params.has("names") and params["names"] is Array:
		var z := 0
		for n in params["names"]:
			layer_defs.append({"name": str(n), "z_index": z})
			z += 1
	else:
		layer_defs = [
			{"name": "Ground", "z_index": 0},
			{"name": "Walls", "z_index": 0},
			{"name": "Decor", "z_index": 1},
		]
	var created: Array = []
	for i in layer_defs.size():
		var def: Dictionary = layer_defs[i] if layer_defs[i] is Dictionary else {"name": str(layer_defs[i])}
		var one := {
			"parent_path": str(root.get_path_to(stack_parent)),
			"name": str(def.get("name", "Layer%d" % i)),
			"z_index": int(def.get("z_index", i)),
			"tileset_path": tileset_path,
		}
		if def.has("y_sort_enabled"):
			one["y_sort_enabled"] = def["y_sort_enabled"]
		if def.has("collision_enabled"):
			one["collision_enabled"] = def["collision_enabled"]
		if def.has("navigation_enabled"):
			one["navigation_enabled"] = def["navigation_enabled"]
		var r := _setup_layer(one)
		created.append(r.get("result", r))
	mark_current_scene_unsaved()
	return success({
		"stack_root": str(root.get_path_to(stack_parent)),
		"layers": created,
		"count": created.size(),
		"tileset_path": tileset_path,
	})


func _list_layers(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start_path: String = optional_string(params, "node_path", ".")
	var start := find_node_by_path(start_path)
	if start == null:
		return error_not_found("Node")
	var layers: Array = []
	_collect_layers(root, start, layers, optional_bool(params, "recursive", true))
	return success({"layers": layers, "count": layers.size()})


func _collect_layers(root: Node, node: Node, out: Array, recursive: bool) -> void:
	if node is TileMapLayer:
		var l: TileMapLayer = node as TileMapLayer
		out.append({
			"node_path": str(root.get_path_to(l)),
			"name": l.name,
			"z_index": l.z_index,
			"enabled": l.enabled,
			"y_sort_enabled": l.y_sort_enabled,
			"has_tileset": l.tile_set != null,
			"tileset_path": l.tile_set.resource_path if l.tile_set else "",
			"collision_enabled": l.collision_enabled,
			"navigation_enabled": l.navigation_enabled,
		})
	if recursive:
		for c in node.get_children():
			_collect_layers(root, c, out, true)
	elif node == find_node_by_path(optional_string({}, "x", ".")):
		pass


func _assign_tileset(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	if not ResourceLoader.exists(res[0]):
		return error_not_found(res[0])
	var ts = load(res[0])
	if not (ts is TileSet):
		return error_internal("Not a TileSet")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var updated: Array = []
	if params.has("layer_paths") and params["layer_paths"] is Array:
		for p in params["layer_paths"]:
			var n := find_node_by_path(str(p))
			if n is TileMapLayer:
				(n as TileMapLayer).tile_set = ts
				updated.append(str(p))
	else:
		var start := find_node_by_path(optional_string(params, "node_path", "."))
		if start == null:
			return error_not_found("node_path")
		var layers: Array = []
		_collect_layers(root, start, layers, true)
		for info in layers:
			var n2 := find_node_by_path(str(info["node_path"]))
			if n2 is TileMapLayer:
				(n2 as TileMapLayer).tile_set = ts
				updated.append(str(info["node_path"]))
	mark_current_scene_unsaved()
	return success({
		"tileset_path": res[0],
		"updated_layers": updated,
		"count": updated.size(),
	})


func _set_layer_props(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is TileMapLayer):
		return error_not_found("TileMapLayer at '%s'" % r0[0])
	var layer: TileMapLayer = node as TileMapLayer
	var applied := {}
	var map := {
		"z_index": "z_index",
		"enabled": "enabled",
		"y_sort_enabled": "y_sort_enabled",
		"collision_enabled": "collision_enabled",
		"navigation_enabled": "navigation_enabled",
		"collision_visibility_mode": "collision_visibility_mode",
		"navigation_visibility_mode": "navigation_visibility_mode",
	}
	for k in map:
		if params.has(k):
			layer.set(map[k], params[k])
			applied[k] = params[k]
	if params.has("modulate"):
		var m: String = str(params["modulate"])
		layer.modulate = Color.html(m) if m.begins_with("#") else Color(m)
		applied["modulate"] = layer.modulate.to_html()
	if applied.is_empty():
		return error_invalid_params("Provide z_index, enabled, y_sort_enabled, collision_enabled, etc.")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})
