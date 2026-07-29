@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Named collision layer/mask bits - agents set layers by name not raw bitmasks.


func get_commands() -> Dictionary:
	return {
		"set_collision_layers_by_name": _set_layers_by_name,
		"set_collision_mask_by_name": _set_mask_by_name,
		"get_collision_layers_named": _get_named,
		"resolve_layer_names_to_mask": _resolve_mask,
		"list_collision_layer_bit_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["set_physics_layer_names", "get_physics_layers", "set_physics_layers", "setup_collision"],
		"workflow": [
			"set_physics_layer_names kind=2d_physics names={1:player,2:enemy,3:world}",
			"set_collision_layers_by_name node_path=Player layers=[player]",
			"set_collision_mask_by_name node_path=Player layers=[world,enemy]",
		],
	})


func _layer_setting_prefix(dim: String) -> String:
	match dim.to_lower():
		"3d", "3d_physics":
			return "layer_names/3d_physics/layer_"
		"2d_render":
			return "layer_names/2d_render/layer_"
		"3d_render":
			return "layer_names/3d_render/layer_"
		"2d_navigation":
			return "layer_names/2d_navigation/layer_"
		"3d_navigation":
			return "layer_names/3d_navigation/layer_"
		_:
			return "layer_names/2d_physics/layer_"


func _build_name_map(dim: String) -> Dictionary:
	## name_lower -> bit index 1..32
	var prefix := _layer_setting_prefix(dim)
	var by_name := {}
	for i in range(1, 33):
		var n: String = str(ProjectSettings.get_setting(prefix + str(i), ""))
		if not n.is_empty():
			by_name[n.to_lower()] = i
			by_name[n] = i
		by_name[str(i)] = i  # allow numeric string
	return by_name


func _names_to_mask(names: Array, dim: String) -> Array:
	## Returns [mask:int, error_or_null, resolved:Array]
	var map := _build_name_map(dim)
	var mask := 0
	var resolved: Array = []
	for item in names:
		var key := str(item)
		var idx := -1
		if key.is_valid_int():
			idx = int(key)
		elif map.has(key.to_lower()):
			idx = int(map[key.to_lower()])
		elif map.has(key):
			idx = int(map[key])
		if idx < 1 or idx > 32:
			return [0, error_invalid_params("Unknown layer '%s' - set_physics_layer_names or use 1-32" % key), []]
		mask |= (1 << (idx - 1))
		resolved.append({"name": key, "layer_index": idx, "bit": idx - 1})
	return [mask, null, resolved]


func _detect_dim(node: Node) -> String:
	if node is CollisionObject3D or node is CharacterBody3D or node is PhysicsBody3D:
		return "3d"
	if node is CollisionObject2D or node is CharacterBody2D or node is PhysicsBody2D:
		return "2d"
	if "collision_layer" in node:
		# Heuristic
		return "3d" if node is Node3D else "2d"
	return "2d"


func _set_layers_by_name(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not ("collision_layer" in node):
		return error_invalid_params("Node has no collision_layer")
	var dim: String = optional_string(params, "dimension", _detect_dim(node))
	var layers: Array = params.get("layers", params.get("names", []))
	if not layers is Array or layers.is_empty():
		return error_invalid_params("layers array required e.g. [player, world]")
	var mode: String = optional_string(params, "mode", "replace").to_lower()  # replace | add | remove
	var result := _names_to_mask(layers, dim)
	if result[1] != null:
		return result[1]
	var bits: int = result[0]
	var current: int = int(node.get("collision_layer"))
	var new_val := bits
	match mode:
		"add":
			new_val = current | bits
		"remove":
			new_val = current & ~bits
		_:
			new_val = bits
	node.set("collision_layer", new_val)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"collision_layer": new_val,
		"mode": mode,
		"resolved": result[2],
		"dimension": dim,
	})


func _set_mask_by_name(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not ("collision_mask" in node):
		return error_invalid_params("Node has no collision_mask")
	var dim: String = optional_string(params, "dimension", _detect_dim(node))
	var layers: Array = params.get("layers", params.get("names", []))
	if not layers is Array or layers.is_empty():
		return error_invalid_params("layers array required")
	var mode: String = optional_string(params, "mode", "replace").to_lower()
	var result := _names_to_mask(layers, dim)
	if result[1] != null:
		return result[1]
	var bits: int = result[0]
	var current: int = int(node.get("collision_mask"))
	var new_val := bits
	match mode:
		"add":
			new_val = current | bits
		"remove":
			new_val = current & ~bits
		_:
			new_val = bits
	node.set("collision_mask", new_val)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"collision_mask": new_val,
		"mode": mode,
		"resolved": result[2],
		"dimension": dim,
	})


func _get_named(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var dim: String = optional_string(params, "dimension", _detect_dim(node))
	var prefix := _layer_setting_prefix(dim)
	var layer_val: int = int(node.get("collision_layer")) if "collision_layer" in node else 0
	var mask_val: int = int(node.get("collision_mask")) if "collision_mask" in node else 0
	var layer_names: Array = []
	var mask_names: Array = []
	for i in range(1, 33):
		var bit := 1 << (i - 1)
		var nm: String = str(ProjectSettings.get_setting(prefix + str(i), ""))
		if nm.is_empty():
			nm = "layer_%d" % i
		if layer_val & bit:
			layer_names.append({"index": i, "name": nm})
		if mask_val & bit:
			mask_names.append({"index": i, "name": nm})
	return success({
		"node_path": r0[0],
		"dimension": dim,
		"collision_layer": layer_val,
		"collision_mask": mask_val,
		"layers": layer_names,
		"masks": mask_names,
	})


func _resolve_mask(params: Dictionary) -> Dictionary:
	var dim: String = optional_string(params, "dimension", "2d")
	var layers: Array = params.get("layers", params.get("names", []))
	if not layers is Array:
		return error_invalid_params("layers array required")
	var result := _names_to_mask(layers, dim)
	if result[1] != null:
		return result[1]
	return success({
		"mask": result[0],
		"resolved": result[2],
		"dimension": dim,
	})
