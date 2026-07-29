@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## TileSet physics + navigation layers (tilemap production depth).


func get_commands() -> Dictionary:
	return {
		"tileset_add_physics_layer": _tileset_add_physics_layer,
		"tileset_add_navigation_layer": _tileset_add_navigation_layer,
		"tileset_list_physics_layers": _tileset_list_physics_layers,
		"tileset_set_tile_navigation_polygon": _tileset_set_tile_navigation_polygon,
		"list_tileset_physics_nav_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["tileset_set_tile_collision", "tileset_add_custom_data_layer", "bake_navigation_mesh"],
	})


func _load_ts(path: String) -> TileSet:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as TileSet


func _tileset_add_physics_layer(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	ts.add_physics_layer()
	var idx := ts.get_physics_layers_count() - 1
	if params.has("collision_layer"):
		ts.set_physics_layer_collision_layer(idx, int(params["collision_layer"]))
	if params.has("collision_mask"):
		ts.set_physics_layer_collision_mask(idx, int(params["collision_mask"]))
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"physics_layer": idx,
		"collision_layer": ts.get_physics_layer_collision_layer(idx),
		"collision_mask": ts.get_physics_layer_collision_mask(idx),
	})


func _tileset_add_navigation_layer(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	ts.add_navigation_layer()
	var idx := ts.get_navigation_layers_count() - 1
	if params.has("layers") and "set_navigation_layer_layers" in ts:
		ts.set_navigation_layer_layers(idx, int(params["layers"]))
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"navigation_layer": idx, "count": ts.get_navigation_layers_count()})


func _tileset_list_physics_layers(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var phys: Array = []
	for i in range(ts.get_physics_layers_count()):
		phys.append({
			"index": i,
			"collision_layer": ts.get_physics_layer_collision_layer(i),
			"collision_mask": ts.get_physics_layer_collision_mask(i),
		})
	var nav: Array = []
	for i in range(ts.get_navigation_layers_count()):
		nav.append({"index": i})
	return success({
		"physics_layers": phys,
		"navigation_layers": nav,
		"physics_count": phys.size(),
		"navigation_count": nav.size(),
	})


func _tileset_set_tile_navigation_polygon(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
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
	var td: TileData = atlas.get_tile_data(coords, 0)
	var nav_layer: int = int(params.get("navigation_layer", 0))
	if ts.get_navigation_layers_count() == 0:
		ts.add_navigation_layer()
	var poly := NavigationPolygon.new()
	var points: PackedVector2Array = PackedVector2Array()
	if params.has("points") and params["points"] is Array:
		for p in params["points"]:
			if p is Dictionary:
				points.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	else:
		var sz: Vector2i = atlas.texture_region_size
		var hw := sz.x * 0.5
		var hh := sz.y * 0.5
		points = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	poly.add_outline(points)
	poly.make_polygons_from_outlines()
	td.set_navigation_polygon(nav_layer, poly)
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"atlas_coords": {"x": coords.x, "y": coords.y},
		"navigation_layer": nav_layer,
		"outline_points": points.size(),
	})
