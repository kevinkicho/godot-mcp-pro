@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## TileSetScenesCollectionSource (scenes-as-tiles) + TileMapPattern library.
## Completes TileSet surface for props, interactive tiles, stamp patterns.


func get_commands() -> Dictionary:
	return {
		"tileset_add_scenes_collection_source": _add_scenes_source,
		"tileset_add_scene_tile": _add_scene_tile,
		"tileset_list_scene_tiles": _list_scene_tiles,
		"tileset_remove_scene_tile": _remove_scene_tile,
		"tileset_set_scene_tile_placeholder": _set_placeholder,
		"tileset_add_pattern_from_cells": _add_pattern_from_cells,
		"tileset_add_pattern_from_rect": _add_pattern_from_rect,
		"tileset_list_patterns": _list_patterns,
		"tileset_remove_pattern": _remove_pattern,
		"tilemap_stamp_pattern": _stamp_pattern,
		"list_tileset_scenes_pattern_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"tileset_create",
			"tileset_add_atlas_source",
			"tileset_assign_to_tilemap",
			"tilemap_paint_cells",
			"tilemap_fill_rect",
		],
		"workflow_scenes": [
			"tileset_add_scenes_collection_source tileset_path=…",
			"tileset_add_scene_tile tileset_path=… source_id=… scene_path=res://props/chest.tscn",
			"tilemap_set_cell with atlas_coords={x:0,y:0} alternative_tile=<scene_id>",
		],
		"workflow_patterns": [
			"tileset_add_pattern_from_rect tilemap_path=… tileset_path=… from={x,y} to={x,y}",
			"tilemap_stamp_pattern tilemap_path=… pattern_index=0 position={x,y}",
		],
	})


func _load_tileset(path: String) -> Array:
	if not ResourceLoader.exists(path):
		return [null, error_not_found(path)]
	var ts = load(path)
	if ts == null or not (ts is TileSet):
		return [null, error_internal("Not a TileSet: %s" % path)]
	return [ts as TileSet, null]


func _save_tileset(ts: TileSet, path: String) -> Dictionary:
	var err := ResourceSaver.save(ts, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return {}


func _find_tilemap(node_path: String) -> Node:
	var node := find_node_by_path(node_path)
	if node is TileMapLayer or (node != null and node.get_class() == "TileMap"):
		return node
	return null


func _add_scenes_source(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	var source := TileSetScenesCollectionSource.new()
	var source_id: int = int(params.get("source_id", -1))
	if source_id < 0:
		source_id = ts.add_source(source)
	else:
		ts.add_source(source, source_id)
	# Optional initial scenes
	var created_ids: Array = []
	if params.has("scenes") and params["scenes"] is Array:
		for s in params["scenes"]:
			var sp := str(s)
			if not ResourceLoader.exists(sp):
				continue
			var packed = load(sp)
			if packed is PackedScene:
				var sid: int = source.create_scene_tile(packed as PackedScene)
				created_ids.append({"scene_path": sp, "scene_tile_id": sid})
	var save_err := _save_tileset(ts, res[0])
	if not save_err.is_empty():
		return save_err
	return success({
		"tileset_path": res[0],
		"source_id": source_id,
		"class": "TileSetScenesCollectionSource",
		"initial_scene_tiles": created_ids,
		"hint": "tileset_add_scene_tile; place with alternative_tile = scene_tile_id, atlas_coords (0,0)",
	})


func _add_scene_tile(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var scene_r := require_res_path(params, "scene_path")
	if scene_r[1] != null:
		return scene_r[1]
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	var source_id: int = optional_int(params, "source_id", -1)
	var source: TileSetScenesCollectionSource = null
	if source_id >= 0:
		if not ts.has_source(source_id):
			return error_not_found("source_id %d" % source_id)
		var src = ts.get_source(source_id)
		if not (src is TileSetScenesCollectionSource):
			return error_invalid_params("source_id %d is not TileSetScenesCollectionSource" % source_id)
		source = src as TileSetScenesCollectionSource
	else:
		# Find first scenes collection or create
		for i in ts.get_source_count():
			var sid := ts.get_source_id(i)
			var src = ts.get_source(sid)
			if src is TileSetScenesCollectionSource:
				source = src as TileSetScenesCollectionSource
				source_id = sid
				break
		if source == null:
			source = TileSetScenesCollectionSource.new()
			source_id = ts.add_source(source)
	if not ResourceLoader.exists(scene_r[0]):
		return error_not_found(scene_r[0])
	var packed = load(scene_r[0])
	if not (packed is PackedScene):
		return error_internal("Not a PackedScene: %s" % scene_r[0])
	var id_override: int = optional_int(params, "scene_tile_id", -1)
	var scene_tile_id: int = source.create_scene_tile(packed as PackedScene, id_override)
	if params.has("display_placeholder"):
		source.set_scene_tile_display_placeholder(scene_tile_id, bool(params["display_placeholder"]))
	var save_err := _save_tileset(ts, res[0])
	if not save_err.is_empty():
		return save_err
	return success({
		"tileset_path": res[0],
		"source_id": source_id,
		"scene_path": scene_r[0],
		"scene_tile_id": scene_tile_id,
		"place_with": {
			"source_id": source_id,
			"atlas_coords": {"x": 0, "y": 0},
			"alternative_tile": scene_tile_id,
		},
	})


func _list_scene_tiles(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	var sources: Array = []
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src = ts.get_source(sid)
		if not (src is TileSetScenesCollectionSource):
			continue
		var sc: TileSetScenesCollectionSource = src as TileSetScenesCollectionSource
		var tiles: Array = []
		for ti in sc.get_scene_tiles_count():
			var tid: int = sc.get_scene_tile_id(ti)
			var scene: PackedScene = sc.get_scene_tile_scene(tid)
			tiles.append({
				"scene_tile_id": tid,
				"scene_path": scene.resource_path if scene else "",
				"display_placeholder": sc.get_scene_tile_display_placeholder(tid),
			})
		sources.append({
			"source_id": sid,
			"scene_tiles_count": sc.get_scene_tiles_count(),
			"tiles": tiles,
		})
	return success({
		"tileset_path": res[0],
		"scenes_sources": sources,
		"count": sources.size(),
	})


func _remove_scene_tile(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	if not params.has("source_id") or not params.has("scene_tile_id"):
		return error_invalid_params("source_id and scene_tile_id required")
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	var source_id: int = int(params["source_id"])
	var scene_tile_id: int = int(params["scene_tile_id"])
	if not ts.has_source(source_id):
		return error_not_found("source_id %d" % source_id)
	var src = ts.get_source(source_id)
	if not (src is TileSetScenesCollectionSource):
		return error_invalid_params("Not a scenes collection source")
	var sc: TileSetScenesCollectionSource = src as TileSetScenesCollectionSource
	if not sc.has_scene_tile_id(scene_tile_id):
		return error_not_found("scene_tile_id %d" % scene_tile_id)
	sc.remove_scene_tile(scene_tile_id)
	var save_err := _save_tileset(ts, res[0])
	if not save_err.is_empty():
		return save_err
	return success({
		"tileset_path": res[0],
		"source_id": source_id,
		"removed_scene_tile_id": scene_tile_id,
	})


func _set_placeholder(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	if not params.has("source_id") or not params.has("scene_tile_id"):
		return error_invalid_params("source_id and scene_tile_id required")
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	var source_id: int = int(params["source_id"])
	var scene_tile_id: int = int(params["scene_tile_id"])
	if not ts.has_source(source_id):
		return error_not_found("source_id %d" % source_id)
	var src = ts.get_source(source_id)
	if not (src is TileSetScenesCollectionSource):
		return error_invalid_params("Not a scenes collection source")
	var sc: TileSetScenesCollectionSource = src as TileSetScenesCollectionSource
	var display: bool = optional_bool(params, "display_placeholder", true)
	sc.set_scene_tile_display_placeholder(scene_tile_id, display)
	var save_err := _save_tileset(ts, res[0])
	if not save_err.is_empty():
		return save_err
	return success({
		"tileset_path": res[0],
		"source_id": source_id,
		"scene_tile_id": scene_tile_id,
		"display_placeholder": display,
	})


func _parse_vec2i(v: Variant) -> Vector2i:
	if v is Dictionary:
		return Vector2i(int(v.get("x", 0)), int(v.get("y", 0)))
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO


func _get_cell_source_id(tilemap: Node, layer: int, coords: Vector2i) -> int:
	if tilemap is TileMapLayer:
		return (tilemap as TileMapLayer).get_cell_source_id(coords)
	return tilemap.call("get_cell_source_id", layer, coords)


func _get_cell_atlas(tilemap: Node, layer: int, coords: Vector2i) -> Vector2i:
	if tilemap is TileMapLayer:
		return (tilemap as TileMapLayer).get_cell_atlas_coords(coords)
	return tilemap.call("get_cell_atlas_coords", layer, coords)


func _get_cell_alt(tilemap: Node, layer: int, coords: Vector2i) -> int:
	if tilemap is TileMapLayer:
		return (tilemap as TileMapLayer).get_cell_alternative_tile(coords)
	return tilemap.call("get_cell_alternative_tile", layer, coords)


func _build_pattern_from_coords(tilemap: Node, layer: int, coords_list: Array) -> TileMapPattern:
	var pattern := TileMapPattern.new()
	if coords_list.is_empty():
		return pattern
	var min_c := _parse_vec2i(coords_list[0])
	for c in coords_list:
		var v := _parse_vec2i(c)
		min_c = Vector2i(mini(min_c.x, v.x), mini(min_c.y, v.y))
	for c in coords_list:
		var cell := _parse_vec2i(c)
		var local := cell - min_c
		var sid := _get_cell_source_id(tilemap, layer, cell)
		if sid < 0:
			continue
		var atlas := _get_cell_atlas(tilemap, layer, cell)
		var alt := _get_cell_alt(tilemap, layer, cell)
		pattern.set_cell(local, sid, atlas, alt)
	return pattern


func _add_pattern_from_cells(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var r_tm := require_string(params, "tilemap_path")
	if r_tm[1] != null:
		return r_tm[1]
	var tilemap := _find_tilemap(r_tm[0])
	if tilemap == null:
		return error_not_found("TileMapLayer/TileMap at '%s'" % r_tm[0])
	if not params.has("cells") or not (params["cells"] is Array):
		return error_invalid_params("cells array of {x,y} required")
	var layer: int = optional_int(params, "layer", 0)
	var pattern := _build_pattern_from_coords(tilemap, layer, params["cells"])
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	var idx: int = ts.add_pattern(pattern, optional_int(params, "index", -1))
	var save_err := _save_tileset(ts, res[0])
	if not save_err.is_empty():
		return save_err
	return success({
		"tileset_path": res[0],
		"pattern_index": idx,
		"size": {"x": pattern.get_size().x, "y": pattern.get_size().y},
		"used_cells": pattern.get_used_cells().size(),
	})


func _add_pattern_from_rect(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var r_tm := require_string(params, "tilemap_path")
	if r_tm[1] != null:
		return r_tm[1]
	var tilemap := _find_tilemap(r_tm[0])
	if tilemap == null:
		return error_not_found("TileMapLayer/TileMap at '%s'" % r_tm[0])
	if not params.has("from") or not params.has("to"):
		return error_invalid_params("from and to {x,y} required")
	var from_c := _parse_vec2i(params["from"])
	var to_c := _parse_vec2i(params["to"])
	var min_c := Vector2i(mini(from_c.x, to_c.x), mini(from_c.y, to_c.y))
	var max_c := Vector2i(maxi(from_c.x, to_c.x), maxi(from_c.y, to_c.y))
	var cells: Array = []
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			cells.append({"x": x, "y": y})
	# Reuse cells path
	var p2 := params.duplicate()
	p2["cells"] = cells
	return _add_pattern_from_cells(p2)


func _list_patterns(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	var patterns: Array = []
	var count: int = ts.get_patterns_count()
	for i in count:
		var pat: TileMapPattern = ts.get_pattern(i)
		if pat == null:
			patterns.append({"index": i, "empty": true})
			continue
		patterns.append({
			"index": i,
			"size": {"x": pat.get_size().x, "y": pat.get_size().y},
			"used_cells": pat.get_used_cells().size(),
		})
	return success({
		"tileset_path": res[0],
		"patterns_count": count,
		"patterns": patterns,
	})


func _remove_pattern(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	if not params.has("pattern_index") and not params.has("index"):
		return error_invalid_params("pattern_index required")
	var idx: int = int(params.get("pattern_index", params.get("index", -1)))
	var loaded := _load_tileset(res[0])
	if loaded[1] != null:
		return loaded[1]
	var ts: TileSet = loaded[0]
	if idx < 0 or idx >= ts.get_patterns_count():
		return error_invalid_params("pattern_index out of range")
	ts.remove_pattern(idx)
	var save_err := _save_tileset(ts, res[0])
	if not save_err.is_empty():
		return save_err
	return success({"tileset_path": res[0], "removed_index": idx})


func _stamp_pattern(params: Dictionary) -> Dictionary:
	var r_tm := require_string(params, "tilemap_path")
	if r_tm[1] != null:
		return r_tm[1]
	var tilemap := _find_tilemap(r_tm[0])
	if tilemap == null:
		return error_not_found("TileMapLayer/TileMap at '%s'" % r_tm[0])
	var position := _parse_vec2i(params.get("position", {"x": 0, "y": 0}))
	var pattern: TileMapPattern = null
	# From tileset library
	if params.has("tileset_path") and (params.has("pattern_index") or params.has("index")):
		var res := require_res_path(params, "tileset_path")
		if res[1] != null:
			return res[1]
		var loaded := _load_tileset(res[0])
		if loaded[1] != null:
			return loaded[1]
		var ts: TileSet = loaded[0]
		var idx: int = int(params.get("pattern_index", params.get("index", 0)))
		if idx < 0 or idx >= ts.get_patterns_count():
			return error_invalid_params("pattern_index out of range")
		pattern = ts.get_pattern(idx)
	elif params.has("cells") and params["cells"] is Array:
		# Ad-hoc pattern from cell descriptors: [{x,y,source_id,atlas_coords,alternative_tile}]
		pattern = TileMapPattern.new()
		for c in params["cells"]:
			if not c is Dictionary:
				continue
			var local := Vector2i(int(c.get("x", 0)), int(c.get("y", 0)))
			var sid: int = int(c.get("source_id", 0))
			var atlas := _parse_vec2i(c.get("atlas_coords", {"x": 0, "y": 0}))
			var alt: int = int(c.get("alternative_tile", 0))
			pattern.set_cell(local, sid, atlas, alt)
	else:
		return error_invalid_params("tileset_path+pattern_index or cells[] required")
	if pattern == null:
		return error_internal("Pattern is null")
	if tilemap is TileMapLayer:
		(tilemap as TileMapLayer).set_pattern(position, pattern)
	else:
		var layer: int = optional_int(params, "layer", 0)
		tilemap.call("set_pattern", layer, position, pattern)
	mark_current_scene_unsaved()
	return success({
		"tilemap_path": r_tm[0],
		"position": {"x": position.x, "y": position.y},
		"pattern_size": {"x": pattern.get_size().x, "y": pattern.get_size().y},
		"used_cells": pattern.get_used_cells().size(),
	})
