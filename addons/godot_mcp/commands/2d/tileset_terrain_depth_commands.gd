@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## TileSet terrain peering + TileMapLayer terrain fill (2D auto-tile depth).


func get_commands() -> Dictionary:
	return {
		"tileset_set_terrain_peering": _tileset_set_terrain_peering,
		"tileset_set_tiles_terrain_batch": _tileset_set_tiles_terrain_batch,
		"tileset_list_terrain_peering": _tileset_list_terrain_peering,
		"tilemap_fill_terrain_rect": _tilemap_fill_terrain_rect,
		"tilemap_paint_terrain_cells": _tilemap_paint_terrain_cells,
		"list_tileset_terrain_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["tileset_add_terrain_set", "tileset_add_terrain", "tileset_set_tile_terrain", "tilemap_set_cells_terrain_connect"],
		"peering_bits": [
			"right", "bottom_right", "bottom", "bottom_left", "left", "top_left", "top", "top_right",
		],
	})


func _bit_from_name(name: String) -> int:
	# TileSet.CELL_NEIGHBOR_* constants
	match name.to_lower():
		"right", "east":
			return TileSet.CELL_NEIGHBOR_RIGHT_SIDE
		"bottom_right", "southeast":
			return TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
		"bottom", "south":
			return TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
		"bottom_left", "southwest":
			return TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
		"left", "west":
			return TileSet.CELL_NEIGHBOR_LEFT_SIDE
		"top_left", "northwest":
			return TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER
		"top", "north":
			return TileSet.CELL_NEIGHBOR_TOP_SIDE
		"top_right", "northeast":
			return TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER
		_:
			return -1


func _tileset_set_terrain_peering(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var coords := Vector2i(int(params.get("atlas_x", 0)), int(params.get("atlas_y", 0)))
	var src := ts.get_source(source_id)
	if src == null or not (src is TileSetAtlasSource):
		return error_not_found("Atlas source")
	var atlas: TileSetAtlasSource = src
	if not atlas.has_tile(coords):
		atlas.create_tile(coords)
	var td: TileData = atlas.get_tile_data(coords, int(params.get("alternative", 0)))
	if params.has("terrain_set"):
		td.terrain_set = int(params["terrain_set"])
	if params.has("terrain"):
		td.terrain = int(params["terrain"])
	var applied: Dictionary = {}
	# peering: { "right": 0, "top": 0, ... } terrain index or -1
	if params.has("peering") and params["peering"] is Dictionary:
		for k in params["peering"]:
			var bit := _bit_from_name(str(k))
			if bit < 0 and str(k).is_valid_int():
				bit = int(k)
			if bit < 0:
				continue
			var terr: int = int(params["peering"][k])
			td.set_terrain_peering_bit(bit as TileSet.CellNeighbor, terr)
			applied[str(k)] = terr
	# all_sides convenience
	if params.has("all_peering"):
		var t: int = int(params["all_peering"])
		for bit_name in ["right", "bottom", "left", "top", "bottom_right", "bottom_left", "top_left", "top_right"]:
			var b := _bit_from_name(bit_name)
			if b >= 0:
				td.set_terrain_peering_bit(b as TileSet.CellNeighbor, t)
				applied[bit_name] = t
	var err := ResourceSaver.save(ts, res_path[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"tileset_path": res_path[0],
		"atlas_coords": {"x": coords.x, "y": coords.y},
		"terrain_set": td.terrain_set,
		"terrain": td.terrain,
		"peering": applied,
	})


func _tileset_set_tiles_terrain_batch(params: Dictionary) -> Dictionary:
	## tiles: [{atlas_x, atlas_y, terrain?, peering?}]
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	if not params.has("tiles") or not params["tiles"] is Array:
		return error_invalid_params("tiles array required")
	var source_id: int = int(params.get("source_id", 0))
	var terrain_set: int = int(params.get("terrain_set", 0))
	var default_terrain: int = int(params.get("terrain", 0))
	var results: Array = []
	for t in params["tiles"]:
		if not t is Dictionary:
			continue
		var one := {
			"tileset_path": res_path[0],
			"source_id": source_id,
			"atlas_x": int(t.get("atlas_x", t.get("x", 0))),
			"atlas_y": int(t.get("atlas_y", t.get("y", 0))),
			"terrain_set": int(t.get("terrain_set", terrain_set)),
			"terrain": int(t.get("terrain", default_terrain)),
		}
		if t.has("peering"):
			one["peering"] = t["peering"]
		if t.has("all_peering"):
			one["all_peering"] = t["all_peering"]
		elif optional_bool(params, "all_peering_default", false):
			one["all_peering"] = one["terrain"]
		results.append(_tileset_set_terrain_peering(one))
	return success({"count": results.size(), "results": results})


func _tileset_list_terrain_peering(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var coords := Vector2i(int(params.get("atlas_x", 0)), int(params.get("atlas_y", 0)))
	var src := ts.get_source(source_id)
	if src == null or not (src is TileSetAtlasSource):
		return error_not_found("source")
	var atlas: TileSetAtlasSource = src
	if not atlas.has_tile(coords):
		return error_not_found("tile")
	var td: TileData = atlas.get_tile_data(coords, 0)
	var peering: Dictionary = {}
	for bit_name in ["right", "bottom_right", "bottom", "bottom_left", "left", "top_left", "top", "top_right"]:
		var b := _bit_from_name(bit_name)
		if b >= 0:
			peering[bit_name] = td.get_terrain_peering_bit(b as TileSet.CellNeighbor)
	return success({
		"terrain_set": td.terrain_set,
		"terrain": td.terrain,
		"peering": peering,
	})


func _find_tilemap(node_path: String) -> Node:
	var n := find_node_by_path(node_path)
	if n is TileMapLayer or (n != null and n.get_class() == "TileMap"):
		return n
	return null


func _tilemap_fill_terrain_rect(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tm := _find_tilemap(r0[0])
	if tm == null:
		return error_not_found("TileMapLayer/TileMap")
	var x0 := int(params.get("x0", params.get("x", 0)))
	var y0 := int(params.get("y0", params.get("y", 0)))
	var x1 := int(params.get("x1", x0 + int(params.get("width", 1)) - 1))
	var y1 := int(params.get("y1", y0 + int(params.get("height", 1)) - 1))
	var terrain_set: int = int(params.get("terrain_set", 0))
	var terrain: int = int(params.get("terrain", 0))
	var cells: Array[Vector2i] = []
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			cells.append(Vector2i(x, y))
			if cells.size() > 50000:
				return error_invalid_params("Region too large (>50000 cells)")
	if tm is TileMapLayer:
		var layer := tm as TileMapLayer
		layer.set_cells_terrain_connect(cells, terrain_set, terrain, optional_bool(params, "ignore_empty", true))
	else:
		var layer_i: int = int(params.get("layer", 0))
		tm.call("set_cells_terrain_connect", layer_i, cells, terrain_set, terrain, optional_bool(params, "ignore_empty", true))
	mark_current_scene_unsaved()
	return success({
		"cells": cells.size(),
		"terrain_set": terrain_set,
		"terrain": terrain,
		"rect": {"x0": x0, "y0": y0, "x1": x1, "y1": y1},
	})


func _tilemap_paint_terrain_cells(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tm := _find_tilemap(r0[0])
	if tm == null:
		return error_not_found("TileMapLayer/TileMap")
	if not params.has("cells") or not params["cells"] is Array:
		return error_invalid_params("cells: [{x,y},...] required")
	var terrain_set: int = int(params.get("terrain_set", 0))
	var terrain: int = int(params.get("terrain", 0))
	var cells: Array[Vector2i] = []
	for c in params["cells"]:
		if c is Dictionary:
			cells.append(Vector2i(int(c.get("x", 0)), int(c.get("y", 0))))
		elif c is Array and c.size() >= 2:
			cells.append(Vector2i(int(c[0]), int(c[1])))
	if cells.is_empty():
		return error_invalid_params("cells empty")
	var connect: bool = optional_bool(params, "connect", true)
	if tm is TileMapLayer:
		var layer := tm as TileMapLayer
		if connect:
			layer.set_cells_terrain_connect(cells, terrain_set, terrain, true)
		else:
			layer.set_cells_terrain_path(cells, terrain_set, terrain, true)
	else:
		var layer_i: int = int(params.get("layer", 0))
		if connect:
			tm.call("set_cells_terrain_connect", layer_i, cells, terrain_set, terrain, true)
		else:
			tm.call("set_cells_terrain_path", layer_i, cells, terrain_set, terrain, true)
	mark_current_scene_unsaved()
	return success({"cells": cells.size(), "terrain_set": terrain_set, "terrain": terrain, "connect": connect})
