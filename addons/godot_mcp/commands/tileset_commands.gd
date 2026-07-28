@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## TileSet authoring — tutorials/2d tilemaps


func get_commands() -> Dictionary:
	return {
		"tileset_create": _tileset_create,
		"tileset_add_atlas_source": _tileset_add_atlas_source,
		"tileset_get_info": _tileset_get_info,
		"tileset_assign_to_tilemap": _tileset_assign_to_tilemap,
		"tileset_set_tile_collision": _tileset_set_tile_collision,
		"tileset_set_tile_modulate": _tileset_set_tile_modulate,
		"tileset_remove_source": _tileset_remove_source,
		"tileset_add_terrain_set": _tileset_add_terrain_set,
		"tileset_add_terrain": _tileset_add_terrain,
		"tileset_set_tile_terrain": _tileset_set_tile_terrain,
		"tileset_get_terrains": _tileset_get_terrains,
	}


func _tileset_create(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var ts := TileSet.new()
	var tile_size := Vector2i(
		int(params.get("tile_width", params.get("tile_size", 16))),
		int(params.get("tile_height", params.get("tile_size", 16)))
	)
	ts.tile_size = tile_size
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(ts, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "tile_size": {"x": tile_size.x, "y": tile_size.y}})


func _tileset_add_atlas_source(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts_path: String = res_path[0]
	var tex_r := require_res_path(params, "texture_path")
	if tex_r[1] != null:
		return tex_r[1]
	var texture_path: String = tex_r[0]
	if not ResourceLoader.exists(ts_path):
		return error_not_found(ts_path)
	if not ResourceLoader.exists(texture_path):
		return error_not_found(texture_path)
	var ts: TileSet = load(ts_path) as TileSet
	if ts == null:
		return error_internal("Not a TileSet: %s" % ts_path)
	var tex: Texture2D = load(texture_path) as Texture2D
	if tex == null:
		return error_internal("Not a Texture2D: %s" % texture_path)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	var tw: int = int(params.get("texture_region_size_x", ts.tile_size.x))
	var th: int = int(params.get("texture_region_size_y", ts.tile_size.y))
	source.texture_region_size = Vector2i(tw, th)
	# Create tiles for atlas grid
	var cols: int = int(params.get("columns", maxi(1, tex.get_width() / tw)))
	var rows: int = int(params.get("rows", maxi(1, tex.get_height() / th)))
	var created := 0
	for y in range(rows):
		for x in range(cols):
			var atlas_coords := Vector2i(x, y)
			if not source.has_tile(atlas_coords):
				source.create_tile(atlas_coords)
				created += 1
	var source_id: int = int(params.get("source_id", -1))
	if source_id < 0:
		source_id = ts.add_source(source)
	else:
		ts.add_source(source, source_id)
	var err := ResourceSaver.save(ts, ts_path)
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"tileset_path": ts_path,
		"texture_path": texture_path,
		"source_id": source_id,
		"tiles_created": created,
		"columns": cols,
		"rows": rows,
	})


func _tileset_get_info(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if not ResourceLoader.exists(path):
		return error_not_found(path)
	var ts: TileSet = load(path) as TileSet
	if ts == null:
		return error_internal("Not a TileSet")
	var sources: Array = []
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src := ts.get_source(sid)
		var info := {"source_id": sid, "type": src.get_class() if src else "null"}
		if src is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = src
			info["texture"] = atlas.texture.resource_path if atlas.texture else ""
			info["texture_region_size"] = {"x": atlas.texture_region_size.x, "y": atlas.texture_region_size.y}
			info["tiles_count"] = atlas.get_tiles_count()
		sources.append(info)
	return success({
		"path": path,
		"tile_size": {"x": ts.tile_size.x, "y": ts.tile_size.y},
		"sources": sources,
		"source_count": ts.get_source_count(),
	})


func _tileset_assign_to_tilemap(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	if not (node is TileMap or node is TileMapLayer):
		return error_invalid_params("Node must be TileMap or TileMapLayer (got %s)" % node.get_class())
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_internal("Failed to load TileSet")
	var undo := get_undo_redo()
	undo.create_action("MCP: Assign TileSet")
	if node is TileMap:
		undo.add_do_property(node, "tile_set", ts)
		undo.add_undo_property(node, "tile_set", (node as TileMap).tile_set)
	else:
		undo.add_do_property(node, "tile_set", ts)
		undo.add_undo_property(node, "tile_set", (node as TileMapLayer).tile_set)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "tileset_path": res_path[0]})


func _tileset_set_tile_collision(params: Dictionary) -> Dictionary:
	## Set physics collision polygon on an atlas tile (TileSet physics layer 0).
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet %s" % res_path[0])
	var source_id: int = int(params.get("source_id", 0))
	var atlas_x: int = int(params.get("atlas_x", params.get("x", 0)))
	var atlas_y: int = int(params.get("atlas_y", params.get("y", 0)))
	var coords := Vector2i(atlas_x, atlas_y)
	var src := ts.get_source(source_id)
	if src == null or not src is TileSetAtlasSource:
		return error_not_found("Atlas source_id %d" % source_id)
	var atlas: TileSetAtlasSource = src as TileSetAtlasSource
	if not atlas.has_tile(coords):
		atlas.create_tile(coords)
	# Ensure at least one physics layer
	if ts.get_physics_layers_count() == 0:
		ts.add_physics_layer()
	var physics_layer: int = int(params.get("physics_layer", 0))
	while ts.get_physics_layers_count() <= physics_layer:
		ts.add_physics_layer()
	var td: TileData = atlas.get_tile_data(coords, 0)
	if td == null:
		return error_internal("No TileData at %s" % str(coords))
	var points: Array = params.get("points", [])
	var packed := PackedVector2Array()
	if points is Array and points.size() >= 3:
		for p in points:
			if p is Array and p.size() >= 2:
				packed.append(Vector2(float(p[0]), float(p[1])))
			elif p is Dictionary:
				packed.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	else:
		# Full tile rectangle in local tile coords
		var sz: Vector2i = atlas.texture_region_size
		var hw := sz.x * 0.5
		var hh := sz.y * 0.5
		packed = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
	td.set_collision_polygons_count(physics_layer, 1)
	td.set_collision_polygon_points(physics_layer, 0, packed)
	var err := ResourceSaver.save(ts, res_path[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"tileset_path": res_path[0],
		"source_id": source_id,
		"atlas_coords": {"x": atlas_x, "y": atlas_y},
		"physics_layer": physics_layer,
		"point_count": packed.size(),
	})


func _tileset_set_tile_modulate(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var coords := Vector2i(int(params.get("atlas_x", 0)), int(params.get("atlas_y", 0)))
	var src := ts.get_source(source_id)
	if src == null or not src is TileSetAtlasSource:
		return error_not_found("source")
	var atlas: TileSetAtlasSource = src
	if not atlas.has_tile(coords):
		return error_not_found("tile")
	var td: TileData = atlas.get_tile_data(coords, 0)
	var color_str: String = optional_string(params, "modulate", "#ffffff")
	td.modulate = Color.html(color_str) if color_str.begins_with("#") else Color(color_str)
	var err := ResourceSaver.save(ts, res_path[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"atlas_coords": {"x": coords.x, "y": coords.y}, "modulate": td.modulate.to_html()})


func _tileset_remove_source(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", -1))
	if source_id < 0:
		return error_invalid_params("source_id required")
	if not ts.has_source(source_id):
		return error_not_found("source_id %d" % source_id)
	ts.remove_source(source_id)
	var err := ResourceSaver.save(ts, res_path[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"removed_source_id": source_id, "source_count": ts.get_source_count()})


func _tileset_add_terrain_set(params: Dictionary) -> Dictionary:
	## Add a terrain set (match corners / sides) — TileSet terrain painting surface.
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var mode_str: String = optional_string(params, "mode", "match_corners_and_sides")
	var mode := TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES
	match mode_str:
		"match_corners":
			mode = TileSet.TERRAIN_MODE_MATCH_CORNERS
		"match_sides":
			mode = TileSet.TERRAIN_MODE_MATCH_SIDES
		_:
			mode = TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES
	ts.add_terrain_set()
	var set_index := ts.get_terrain_sets_count() - 1
	ts.set_terrain_set_mode(set_index, mode)
	var err := ResourceSaver.save(ts, res_path[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"tileset_path": res_path[0],
		"terrain_set": set_index,
		"mode": mode_str,
		"terrain_sets_count": ts.get_terrain_sets_count(),
	})


func _tileset_add_terrain(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var terrain_set: int = int(params.get("terrain_set", 0))
	if terrain_set < 0 or terrain_set >= ts.get_terrain_sets_count():
		return error_invalid_params("Invalid terrain_set — call tileset_add_terrain_set first")
	var tname: String = optional_string(params, "name", "Terrain")
	var color := Color(0.3, 0.7, 0.3)
	if params.has("color"):
		var c = params["color"]
		if c is String:
			color = Color.html(c) if str(c).begins_with("#") else Color(c)
	ts.add_terrain(terrain_set)
	var t_index := ts.get_terrains_count(terrain_set) - 1
	ts.set_terrain_name(terrain_set, t_index, tname)
	ts.set_terrain_color(terrain_set, t_index, color)
	var err := ResourceSaver.save(ts, res_path[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"terrain_set": terrain_set,
		"terrain_index": t_index,
		"name": tname,
	})


func _tileset_set_tile_terrain(params: Dictionary) -> Dictionary:
	## Assign terrain + peering bits on an atlas tile (auto-tiling setup).
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var source_id: int = int(params.get("source_id", 0))
	var coords := Vector2i(int(params.get("atlas_x", 0)), int(params.get("atlas_y", 0)))
	var src := ts.get_source(source_id)
	if src == null or not src is TileSetAtlasSource:
		return error_not_found("Atlas source")
	var atlas: TileSetAtlasSource = src
	if not atlas.has_tile(coords):
		atlas.create_tile(coords)
	var td: TileData = atlas.get_tile_data(coords, 0)
	var terrain_set: int = int(params.get("terrain_set", 0))
	var terrain: int = int(params.get("terrain", 0))
	td.terrain_set = terrain_set
	td.terrain = terrain
	# Optional peering bits: dict of bit_name/int -> terrain index (-1 empty)
	# Bit names: top_left_corner, top_side, top_right_corner, ... or numeric TileSet.CELL_NEIGHBOR_*
	if params.has("peering_bits") and params["peering_bits"] is Dictionary:
		var bits: Dictionary = params["peering_bits"]
		for k in bits:
			var bit := _parse_peering_bit(str(k))
			if bit >= 0:
				td.set_terrain_peering_bit(bit, int(bits[k]))
	# Convenience: set all bits to same terrain
	if optional_bool(params, "all_bits", false):
		for bit in [
			TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_TOP_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		]:
			td.set_terrain_peering_bit(bit, terrain)
	var err := ResourceSaver.save(ts, res_path[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"atlas_coords": {"x": coords.x, "y": coords.y},
		"terrain_set": terrain_set,
		"terrain": terrain,
	})


func _parse_peering_bit(name: String) -> int:
	match name.to_lower():
		"right", "right_side":
			return TileSet.CELL_NEIGHBOR_RIGHT_SIDE
		"bottom_right", "bottom_right_corner":
			return TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
		"bottom", "bottom_side":
			return TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
		"bottom_left", "bottom_left_corner":
			return TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
		"left", "left_side":
			return TileSet.CELL_NEIGHBOR_LEFT_SIDE
		"top_left", "top_left_corner":
			return TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER
		"top", "top_side":
			return TileSet.CELL_NEIGHBOR_TOP_SIDE
		"top_right", "top_right_corner":
			return TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER
		_:
			if name.is_valid_int():
				return int(name)
			return -1


func _tileset_get_terrains(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "tileset_path")
	if res_path[1] != null:
		return res_path[1]
	var ts: TileSet = load(res_path[0]) as TileSet
	if ts == null:
		return error_not_found("TileSet")
	var sets: Array = []
	for s in ts.get_terrain_sets_count():
		var terrains: Array = []
		for t in ts.get_terrains_count(s):
			terrains.append({
				"index": t,
				"name": ts.get_terrain_name(s, t),
				"color": ts.get_terrain_color(s, t).to_html(),
			})
		sets.append({
			"terrain_set": s,
			"mode": ts.get_terrain_set_mode(s),
			"terrains": terrains,
		})
	return success({"tileset_path": res_path[0], "terrain_sets": sets, "count": sets.size()})
