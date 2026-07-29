@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"tilemap_set_cell": _tilemap_set_cell,
		"tilemap_fill_rect": _tilemap_fill_rect,
		"tilemap_get_cell": _tilemap_get_cell,
		"tilemap_clear": _tilemap_clear,
		"tilemap_get_info": _tilemap_get_info,
		"tilemap_get_used_cells": _tilemap_get_used_cells,
		"tilemap_set_cells_terrain_connect": _tilemap_set_cells_terrain_connect,
		"tilemap_set_cells_terrain_path": _tilemap_set_cells_terrain_path,
		"tilemap_erase_rect": _tilemap_erase_rect,
		"tilemap_paint_line": _tilemap_paint_line,
		"tilemap_paint_cells": _tilemap_paint_cells,
	}


func _find_tilemap_node(node_path: String) -> Node:
	var node := find_node_by_path(node_path)
	if node is TileMapLayer or _is_legacy_tilemap(node):
		return node
	return null


func _is_legacy_tilemap(node: Node) -> bool:
	return node != null and node.get_class() == "TileMap"


func _not_found_result(node_path: String) -> Dictionary:
	return error_not_found(
		"TileMapLayer or TileMap at '%s'" % node_path,
		"Use TileMapLayer for current Godot projects, or pass a deprecated TileMap node with optional layer."
	)


func _get_single_layer(tilemap: Node, params: Dictionary) -> Array:
	if tilemap is TileMapLayer:
		if params.has("layer") and int(params["layer"]) != 0:
			return [0, error_invalid_params("layer only applies to deprecated TileMap nodes; TileMapLayer has one implicit layer")]
		return [0, null]

	var layer: int = optional_int(params, "layer", 0)
	var layer_error := _validate_tilemap_layer(tilemap, layer)
	if not layer_error.is_empty():
		return [layer, layer_error]
	return [layer, null]


func _get_clear_layers(tilemap: Node, params: Dictionary) -> Array:
	if tilemap is TileMapLayer:
		var layer_result := _get_single_layer(tilemap, params)
		if layer_result[1] != null:
			return [[], layer_result[1]]
		return [[0], null]

	if params.has("layer"):
		var layer_result := _get_single_layer(tilemap, params)
		if layer_result[1] != null:
			return [[], layer_result[1]]
		return [[int(layer_result[0])], null]

	var layers: Array = []
	for layer in range(_get_tilemap_layer_count(tilemap)):
		layers.append(layer)
	return [layers, null]


func _validate_tilemap_layer(tilemap: Node, layer: int) -> Dictionary:
	if tilemap is TileMapLayer:
		return {}

	var layer_count := _get_tilemap_layer_count(tilemap)
	if layer_count <= 0:
		return error_invalid_params("TileMap has no layers")
	if layer < -layer_count or layer >= layer_count:
		return error_invalid_params("layer %d is out of range for TileMap with %d layers" % [layer, layer_count])
	return {}


func _get_tilemap_layer_count(tilemap: Node) -> int:
	if tilemap is TileMapLayer:
		return 1
	return int(tilemap.call("get_layers_count"))


func _get_used_cells(tilemap: Node, layer: int) -> Array:
	if tilemap is TileMapLayer:
		return tilemap.call("get_used_cells")
	return tilemap.call("get_used_cells", layer)


func _get_cell_source_id(tilemap: Node, layer: int, coords: Vector2i) -> int:
	if tilemap is TileMapLayer:
		return int(tilemap.call("get_cell_source_id", coords))
	return int(tilemap.call("get_cell_source_id", layer, coords))


func _get_cell_atlas_coords(tilemap: Node, layer: int, coords: Vector2i) -> Vector2i:
	if tilemap is TileMapLayer:
		return tilemap.call("get_cell_atlas_coords", coords)
	return tilemap.call("get_cell_atlas_coords", layer, coords)


func _get_cell_alternative_tile(tilemap: Node, layer: int, coords: Vector2i) -> int:
	if tilemap is TileMapLayer:
		return int(tilemap.call("get_cell_alternative_tile", coords))
	return int(tilemap.call("get_cell_alternative_tile", layer, coords))


func _tilemap_set_cell(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap_node(node_path)
	if tilemap == null:
		return _not_found_result(node_path)

	var layer_result := _get_single_layer(tilemap, params)
	if layer_result[1] != null:
		return layer_result[1]
	var layer: int = layer_result[0]

	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var source_id: int = int(params.get("source_id", 0))
	var atlas_x: int = int(params.get("atlas_x", 0))
	var atlas_y: int = int(params.get("atlas_y", 0))
	var alternative: int = int(params.get("alternative", 0))

	var coords := Vector2i(x, y)
	var old_cells := [_capture_cell(tilemap, layer, coords)]
	var new_cells := [_make_cell(layer, coords, source_id, Vector2i(atlas_x, atlas_y), alternative)]

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set TileMap cell")
	_add_do_set_cells(undo_redo, tilemap, new_cells)
	_add_undo_set_cells(undo_redo, tilemap, old_cells)
	undo_redo.commit_action()

	return success({"x": x, "y": y, "layer": layer, "node_class": tilemap.get_class(), "source_id": source_id, "atlas_coords": [atlas_x, atlas_y]})


func _tilemap_fill_rect(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap_node(node_path)
	if tilemap == null:
		return _not_found_result(node_path)

	var layer_result := _get_single_layer(tilemap, params)
	if layer_result[1] != null:
		return layer_result[1]
	var layer: int = layer_result[0]

	var x1: int = int(params.get("x1", 0))
	var y1: int = int(params.get("y1", 0))
	var x2: int = int(params.get("x2", 0))
	var y2: int = int(params.get("y2", 0))
	var source_id: int = int(params.get("source_id", 0))
	var atlas_x: int = int(params.get("atlas_x", 0))
	var atlas_y: int = int(params.get("atlas_y", 0))
	var alternative: int = int(params.get("alternative", 0))

	var count := 0
	var old_cells: Array = []
	var new_cells: Array = []
	for cx in range(mini(x1, x2), maxi(x1, x2) + 1):
		for cy in range(mini(y1, y2), maxi(y1, y2) + 1):
			var coords := Vector2i(cx, cy)
			old_cells.append(_capture_cell(tilemap, layer, coords))
			new_cells.append(_make_cell(layer, coords, source_id, Vector2i(atlas_x, atlas_y), alternative))
			count += 1

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Fill TileMap rect")
	_add_do_set_cells(undo_redo, tilemap, new_cells)
	_add_undo_set_cells(undo_redo, tilemap, old_cells)
	undo_redo.commit_action()

	return success({"filled": count, "rect": [x1, y1, x2, y2], "layer": layer, "node_class": tilemap.get_class()})


func _tilemap_get_cell(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap_node(node_path)
	if tilemap == null:
		return _not_found_result(node_path)

	var layer_result := _get_single_layer(tilemap, params)
	if layer_result[1] != null:
		return layer_result[1]
	var layer: int = layer_result[0]

	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var coords := Vector2i(x, y)

	var source_id := _get_cell_source_id(tilemap, layer, coords)
	var atlas_coords := _get_cell_atlas_coords(tilemap, layer, coords)
	var alternative := _get_cell_alternative_tile(tilemap, layer, coords)

	return success({
		"x": x, "y": y,
		"layer": layer,
		"node_class": tilemap.get_class(),
		"source_id": source_id,
		"atlas_coords": [atlas_coords.x, atlas_coords.y],
		"alternative": alternative,
		"empty": source_id == -1,
	})


func _tilemap_clear(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap_node(node_path)
	if tilemap == null:
		return _not_found_result(node_path)

	var clear_layers_result := _get_clear_layers(tilemap, params)
	if clear_layers_result[1] != null:
		return clear_layers_result[1]
	var layers: Array = clear_layers_result[0]

	var old_cells := _capture_cells(tilemap, layers)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Clear TileMap")
	_add_do_clear(undo_redo, tilemap, layers)
	_add_undo_set_cells(undo_redo, tilemap, old_cells)
	undo_redo.commit_action()
	return success({"cleared": true, "layers": layers, "node_class": tilemap.get_class()})


func _make_cell(layer: int, coords: Vector2i, source_id: int, atlas_coords: Vector2i, alternative: int) -> Dictionary:
	return {
		"layer": layer,
		"coords": coords,
		"source_id": source_id,
		"atlas_coords": atlas_coords,
		"alternative": alternative,
	}


func _capture_cell(tilemap: Node, layer: int, coords: Vector2i) -> Dictionary:
	return _make_cell(
		layer,
		coords,
		_get_cell_source_id(tilemap, layer, coords),
		_get_cell_atlas_coords(tilemap, layer, coords),
		_get_cell_alternative_tile(tilemap, layer, coords)
	)


func _capture_cells(tilemap: Node, layers: Array) -> Array:
	var cells: Array = []
	for layer: int in layers:
		for coords: Vector2i in _get_used_cells(tilemap, layer):
			cells.append(_capture_cell(tilemap, layer, coords))
	return cells


func _add_do_set_cells(undo_redo: EditorUndoRedoManager, tilemap: Node, cells: Array) -> void:
	for cell: Dictionary in cells:
		if tilemap is TileMapLayer:
			undo_redo.add_do_method(tilemap, "set_cell", cell["coords"], cell["source_id"], cell["atlas_coords"], cell["alternative"])
		else:
			undo_redo.add_do_method(tilemap, "set_cell", cell["layer"], cell["coords"], cell["source_id"], cell["atlas_coords"], cell["alternative"])


func _add_undo_set_cells(undo_redo: EditorUndoRedoManager, tilemap: Node, cells: Array) -> void:
	for cell: Dictionary in cells:
		if tilemap is TileMapLayer:
			undo_redo.add_undo_method(tilemap, "set_cell", cell["coords"], cell["source_id"], cell["atlas_coords"], cell["alternative"])
		else:
			undo_redo.add_undo_method(tilemap, "set_cell", cell["layer"], cell["coords"], cell["source_id"], cell["atlas_coords"], cell["alternative"])


func _add_do_clear(undo_redo: EditorUndoRedoManager, tilemap: Node, layers: Array) -> void:
	if tilemap is TileMapLayer or layers.size() == _get_tilemap_layer_count(tilemap):
		undo_redo.add_do_method(tilemap, "clear")
		return

	for layer: int in layers:
		undo_redo.add_do_method(tilemap, "clear_layer", layer)


func _tilemap_get_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap_node(node_path)
	if tilemap == null:
		return _not_found_result(node_path)

	var tile_set: TileSet = tilemap.get("tile_set")
	var sources: Array = []
	if tile_set:
		for i in tile_set.get_source_count():
			var source_id := tile_set.get_source_id(i)
			var source := tile_set.get_source(source_id)
			var info := {"id": source_id, "type": source.get_class()}
			if source is TileSetAtlasSource:
				var atlas: TileSetAtlasSource = source
				info["texture"] = atlas.texture.resource_path if atlas.texture else ""
				info["tile_count"] = atlas.get_tiles_count()
			sources.append(info)

	var layers := _get_layer_info(tilemap)
	var used_cells := 0
	for layer_info: Dictionary in layers:
		used_cells += int(layer_info["used_cells"])

	return success({
		"node_path": node_path,
		"node_class": tilemap.get_class(),
		"layer_count": layers.size(),
		"layers": layers,
		"used_cells": used_cells,
		"tile_set_sources": sources,
		"tile_size": [tile_set.tile_size.x, tile_set.tile_size.y] if tile_set else [0, 0],
	})


func _get_layer_info(tilemap: Node) -> Array:
	var layers: Array = []
	if tilemap is TileMapLayer:
		layers.append({
			"index": 0,
			"name": tilemap.name,
			"enabled": true,
			"used_cells": _get_used_cells(tilemap, 0).size(),
		})
		return layers

	for layer in range(_get_tilemap_layer_count(tilemap)):
		layers.append({
			"index": layer,
			"name": String(tilemap.call("get_layer_name", layer)),
			"enabled": bool(tilemap.call("is_layer_enabled", layer)),
			"used_cells": _get_used_cells(tilemap, layer).size(),
		})
	return layers


func _tilemap_get_used_cells(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap_node(node_path)
	if tilemap == null:
		return _not_found_result(node_path)

	var layer_result := _get_single_layer(tilemap, params)
	if layer_result[1] != null:
		return layer_result[1]
	var layer: int = layer_result[0]

	var max_count: int = maxi(0, optional_int(params, "max_count", 500))
	var cells: Array = []
	var used := _get_used_cells(tilemap, layer)

	for i in mini(used.size(), max_count):
		var pos: Vector2i = used[i]
		cells.append({"x": pos.x, "y": pos.y, "layer": layer, "source_id": _get_cell_source_id(tilemap, layer, pos)})

	return success({"cells": cells, "total": used.size(), "returned": cells.size(), "layer": layer, "node_class": tilemap.get_class()})


func _parse_cell_coords(params: Dictionary) -> Array:
	## Returns Array[Vector2i] from cells=[[x,y],...] or points / single x,y
	var out: Array = []
	if params.has("cells") and params["cells"] is Array:
		for c in params["cells"]:
			if c is Array and c.size() >= 2:
				out.append(Vector2i(int(c[0]), int(c[1])))
			elif c is Dictionary:
				out.append(Vector2i(int(c.get("x", 0)), int(c.get("y", 0))))
	elif params.has("x") and params.has("y"):
		out.append(Vector2i(int(params["x"]), int(params["y"])))
	return out


func _tilemap_set_cells_terrain_connect(params: Dictionary) -> Dictionary:
	## Paint terrain with auto-connect (TileMapLayer.set_cells_terrain_connect).
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var tilemap := _find_tilemap_node(result[0])
	if tilemap == null:
		return _not_found_result(result[0])
	var cells := _parse_cell_coords(params)
	if cells.is_empty():
		return error_invalid_params("Provide cells=[[x,y],...] or x,y")
	var terrain_set: int = optional_int(params, "terrain_set", 0)
	var terrain: int = optional_int(params, "terrain", 0)
	var ignore_empty: bool = optional_bool(params, "ignore_empty_terrains", true)
	var packed: Array[Vector2i] = []
	for c in cells:
		packed.append(c as Vector2i)
	if tilemap is TileMapLayer:
		var layer: TileMapLayer = tilemap
		if layer.has_method("set_cells_terrain_connect"):
			layer.set_cells_terrain_connect(packed, terrain_set, terrain, ignore_empty)
		else:
			return error_internal("set_cells_terrain_connect unavailable")
	elif _is_legacy_tilemap(tilemap):
		var layer_i: int = optional_int(params, "layer", 0)
		if tilemap.has_method("set_cells_terrain_connect"):
			tilemap.call("set_cells_terrain_connect", layer_i, packed, terrain_set, terrain, ignore_empty)
		else:
			return error_internal("Legacy TileMap terrain connect unavailable")
	else:
		return _not_found_result(result[0])
	mark_current_scene_unsaved()
	return success({
		"node_path": result[0],
		"cells": cells.size(),
		"terrain_set": terrain_set,
		"terrain": terrain,
		"mode": "connect",
	})


func _tilemap_set_cells_terrain_path(params: Dictionary) -> Dictionary:
	## Paint terrain as a path (set_cells_terrain_path).
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var tilemap := _find_tilemap_node(result[0])
	if tilemap == null:
		return _not_found_result(result[0])
	var cells := _parse_cell_coords(params)
	if cells.is_empty():
		return error_invalid_params("Provide cells path as [[x,y],...]")
	var terrain_set: int = optional_int(params, "terrain_set", 0)
	var terrain: int = optional_int(params, "terrain", 0)
	var ignore_empty: bool = optional_bool(params, "ignore_empty_terrains", true)
	var packed: Array[Vector2i] = []
	for c in cells:
		packed.append(c as Vector2i)
	if tilemap is TileMapLayer:
		var layer: TileMapLayer = tilemap
		if layer.has_method("set_cells_terrain_path"):
			layer.set_cells_terrain_path(packed, terrain_set, terrain, ignore_empty)
		else:
			return error_internal("set_cells_terrain_path unavailable")
	elif _is_legacy_tilemap(tilemap):
		var layer_i: int = optional_int(params, "layer", 0)
		if tilemap.has_method("set_cells_terrain_path"):
			tilemap.call("set_cells_terrain_path", layer_i, packed, terrain_set, terrain, ignore_empty)
		else:
			return error_internal("Legacy terrain path unavailable")
	else:
		return _not_found_result(result[0])
	mark_current_scene_unsaved()
	return success({
		"node_path": result[0],
		"cells": cells.size(),
		"terrain_set": terrain_set,
		"terrain": terrain,
		"mode": "path",
	})


func _tilemap_erase_rect(params: Dictionary) -> Dictionary:
	## Erase all cells in a rectangle (source_id = -1).
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var tilemap := _find_tilemap_node(result[0])
	if tilemap == null:
		return _not_found_result(result[0])
	var layer_result := _get_single_layer(tilemap, params)
	if layer_result[1] != null:
		return layer_result[1]
	var layer: int = layer_result[0]
	var x1: int = int(params.get("x1", 0))
	var y1: int = int(params.get("y1", 0))
	var x2: int = int(params.get("x2", 0))
	var y2: int = int(params.get("y2", 0))
	var old_cells: Array = []
	var new_cells: Array = []
	var count := 0
	for cx in range(mini(x1, x2), maxi(x1, x2) + 1):
		for cy in range(mini(y1, y2), maxi(y1, y2) + 1):
			var coords := Vector2i(cx, cy)
			old_cells.append(_capture_cell(tilemap, layer, coords))
			new_cells.append(_make_cell(layer, coords, -1, Vector2i(-1, -1), 0))
			count += 1
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Erase TileMap rect")
	_add_do_set_cells(undo_redo, tilemap, new_cells)
	_add_undo_set_cells(undo_redo, tilemap, old_cells)
	undo_redo.commit_action()
	return success({"erased": count, "rect": [x1, y1, x2, y2], "layer": layer})


func _tilemap_paint_line(params: Dictionary) -> Dictionary:
	## Bresenham line paint between (x1,y1)-(x2,y2).
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var tilemap := _find_tilemap_node(result[0])
	if tilemap == null:
		return _not_found_result(result[0])
	var layer_result := _get_single_layer(tilemap, params)
	if layer_result[1] != null:
		return layer_result[1]
	var layer: int = layer_result[0]
	var x0: int = int(params.get("x1", params.get("x0", 0)))
	var y0: int = int(params.get("y1", params.get("y0", 0)))
	var x1: int = int(params.get("x2", 0))
	var y1: int = int(params.get("y2", 0))
	var source_id: int = int(params.get("source_id", 0))
	var atlas_x: int = int(params.get("atlas_x", 0))
	var atlas_y: int = int(params.get("atlas_y", 0))
	var alternative: int = int(params.get("alternative", 0))
	var points := _bresenham(x0, y0, x1, y1)
	var old_cells: Array = []
	var new_cells: Array = []
	for p in points:
		old_cells.append(_capture_cell(tilemap, layer, p))
		new_cells.append(_make_cell(layer, p, source_id, Vector2i(atlas_x, atlas_y), alternative))
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Paint TileMap line")
	_add_do_set_cells(undo_redo, tilemap, new_cells)
	_add_undo_set_cells(undo_redo, tilemap, old_cells)
	undo_redo.commit_action()
	return success({"painted": points.size(), "from": [x0, y0], "to": [x1, y1], "layer": layer})


func _tilemap_paint_cells(params: Dictionary) -> Dictionary:
	## Batch paint arbitrary cells [[x,y],...] with same atlas tile.
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var tilemap := _find_tilemap_node(result[0])
	if tilemap == null:
		return _not_found_result(result[0])
	var layer_result := _get_single_layer(tilemap, params)
	if layer_result[1] != null:
		return layer_result[1]
	var layer: int = layer_result[0]
	var cells := _parse_cell_coords(params)
	if cells.is_empty():
		return error_invalid_params("Provide cells=[[x,y],...]")
	var source_id: int = int(params.get("source_id", 0))
	var atlas_x: int = int(params.get("atlas_x", 0))
	var atlas_y: int = int(params.get("atlas_y", 0))
	var alternative: int = int(params.get("alternative", 0))
	var old_cells: Array = []
	var new_cells: Array = []
	for c in cells:
		var coords: Vector2i = c as Vector2i
		old_cells.append(_capture_cell(tilemap, layer, coords))
		new_cells.append(_make_cell(layer, coords, source_id, Vector2i(atlas_x, atlas_y), alternative))
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Paint TileMap cells")
	_add_do_set_cells(undo_redo, tilemap, new_cells)
	_add_undo_set_cells(undo_redo, tilemap, old_cells)
	undo_redo.commit_action()
	return success({"painted": cells.size(), "layer": layer, "source_id": source_id})


func _bresenham(x0: int, y0: int, x1: int, y1: int) -> Array:
	var points: Array = []
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		points.append(Vector2i(x, y))
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return points
