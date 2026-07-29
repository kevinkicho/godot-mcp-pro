@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## TileSetAtlasSource region / tile creation polish (2D atlas gap).


func get_commands() -> Dictionary:
	return {
		"tileset_get_atlas_info": _tileset_get_atlas_info,
		"tileset_set_atlas_region_size": _tileset_set_atlas_region_size,
		"tileset_create_tiles_in_region": _tileset_create_tiles_in_region,
		"tileset_remove_tiles_in_region": _tileset_remove_tiles_in_region,
		"tileset_set_tile_texture_origin": _tileset_set_tile_texture_origin,
		"list_tileset_atlas_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["tileset_add_atlas_source", "tileset_create_tile", "tileset_list_atlas_tiles", "tileset_set_atlas_margins"],
	})


func _load_ts(path: String) -> TileSet:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as TileSet


func _atlas(ts: TileSet, source_id: int) -> TileSetAtlasSource:
	if ts == null or not ts.has_source(source_id):
		return null
	var src := ts.get_source(source_id)
	if src is TileSetAtlasSource:
		return src as TileSetAtlasSource
	return null


func _tileset_get_atlas_info(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var atlas := _atlas(ts, source_id)
	if atlas == null:
		return error_not_found("TileSetAtlasSource")
	var tiles: Array = []
	var max_n: int = clampi(optional_int(params, "max", 200), 1, 2000)
	# Iterate grid
	if atlas.texture:
		var tw: int = atlas.texture_region_size.x
		var th: int = atlas.texture_region_size.y
		var cols: int = maxi(1, atlas.texture.get_width() / maxi(tw, 1))
		var rows: int = maxi(1, atlas.texture.get_height() / maxi(th, 1))
		for y in range(rows):
			for x in range(cols):
				var c := Vector2i(x, y)
				if atlas.has_tile(c):
					var td: TileData = atlas.get_tile_data(c, 0)
					tiles.append({
						"x": x, "y": y,
						"modulate": td.modulate.to_html() if td else "",
						"z_index": td.z_index if td else 0,
						"probability": td.probability if td else 1.0,
					})
					if tiles.size() >= max_n:
						break
			if tiles.size() >= max_n:
				break
	return success({
		"tileset_path": res[0],
		"source_id": source_id,
		"texture": atlas.texture.resource_path if atlas.texture else "",
		"texture_region_size": {"x": atlas.texture_region_size.x, "y": atlas.texture_region_size.y},
		"margins": {"x": atlas.margins.x, "y": atlas.margins.y} if "margins" in atlas else {},
		"separation": {"x": atlas.separation.x, "y": atlas.separation.y} if "separation" in atlas else {},
		"tiles": tiles,
		"tile_count_listed": tiles.size(),
	})


func _tileset_set_atlas_region_size(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var atlas := _atlas(ts, source_id)
	if atlas == null:
		return error_not_found("Atlas source")
	var w: int = int(params.get("width", params.get("texture_region_size_x", atlas.texture_region_size.x)))
	var h: int = int(params.get("height", params.get("texture_region_size_y", atlas.texture_region_size.y)))
	atlas.texture_region_size = Vector2i(w, h)
	if params.has("margin_x") or params.has("margins"):
		var mx := int(params.get("margin_x", 0))
		var my := int(params.get("margin_y", mx))
		if params.has("margins") and params["margins"] is Dictionary:
			mx = int(params["margins"].get("x", mx))
			my = int(params["margins"].get("y", my))
		if "margins" in atlas:
			atlas.margins = Vector2i(mx, my)
	if params.has("separation_x") or params.has("separation"):
		var sx := int(params.get("separation_x", 0))
		var sy := int(params.get("separation_y", sx))
		if params.has("separation") and params["separation"] is Dictionary:
			sx = int(params["separation"].get("x", sx))
			sy = int(params["separation"].get("y", sy))
		if "separation" in atlas:
			atlas.separation = Vector2i(sx, sy)
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"source_id": source_id,
		"texture_region_size": {"x": w, "y": h},
	})


func _tileset_create_tiles_in_region(params: Dictionary) -> Dictionary:
	## Create atlas tiles for x0..x1, y0..y1 grid cells.
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var atlas := _atlas(ts, source_id)
	if atlas == null:
		return error_not_found("Atlas source")
	var x0 := int(params.get("x0", 0))
	var y0 := int(params.get("y0", 0))
	var x1 := int(params.get("x1", x0 + int(params.get("columns", 1)) - 1))
	var y1 := int(params.get("y1", y0 + int(params.get("rows", 1)) - 1))
	var created: Array = []
	var skipped := 0
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			var c := Vector2i(x, y)
			if atlas.has_tile(c):
				skipped += 1
				continue
			atlas.create_tile(c)
			created.append({"x": x, "y": y})
			if created.size() > 5000:
				return error_invalid_params("Too many tiles (>5000)")
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"created": created.size(), "skipped_existing": skipped, "tiles": created.slice(0, mini(50, created.size()))})


func _tileset_remove_tiles_in_region(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var atlas := _atlas(ts, source_id)
	if atlas == null:
		return error_not_found("Atlas source")
	var x0 := int(params.get("x0", 0))
	var y0 := int(params.get("y0", 0))
	var x1 := int(params.get("x1", x0))
	var y1 := int(params.get("y1", y0))
	var removed := 0
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			var c := Vector2i(x, y)
			if atlas.has_tile(c):
				atlas.remove_tile(c)
				removed += 1
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"removed": removed})


func _tileset_set_tile_texture_origin(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var coords := Vector2i(int(params.get("atlas_x", 0)), int(params.get("atlas_y", 0)))
	var atlas := _atlas(ts, source_id)
	if atlas == null or not atlas.has_tile(coords):
		return error_not_found("tile")
	var td: TileData = atlas.get_tile_data(coords, int(params.get("alternative", 0)))
	var ox: int = int(params.get("origin_x", params.get("x", 0)))
	var oy: int = int(params.get("origin_y", params.get("y", 0)))
	if "texture_origin" in td:
		td.texture_origin = Vector2i(ox, oy)
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"atlas_coords": {"x": coords.x, "y": coords.y}, "texture_origin": {"x": ox, "y": oy}})
