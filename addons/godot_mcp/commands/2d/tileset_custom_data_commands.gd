@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## TileSet custom data layers + per-tile values (Wave 6).


func get_commands() -> Dictionary:
	return {
		"tileset_add_custom_data_layer": _tileset_add_custom_data_layer,
		"tileset_list_custom_data_layers": _tileset_list_custom_data_layers,
		"tileset_set_tile_custom_data": _tileset_set_tile_custom_data,
		"tileset_get_tile_custom_data": _tileset_get_tile_custom_data,
		"list_tileset_custom_data_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["tileset_create", "tileset_get_tile_data", "tilemap_get_cell"],
	})


func _load_ts(path: String) -> TileSet:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as TileSet


func _tileset_add_custom_data_layer(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var layer_name: String = optional_string(params, "name", "data")
	var type_str: String = optional_string(params, "type", "bool").to_lower()
	var type := TYPE_BOOL
	match type_str:
		"int":
			type = TYPE_INT
		"float":
			type = TYPE_FLOAT
		"string", "str":
			type = TYPE_STRING
		"color":
			type = TYPE_COLOR
		"vector2":
			type = TYPE_VECTOR2
		"vector3":
			type = TYPE_VECTOR3
		_:
			type = TYPE_BOOL
	ts.add_custom_data_layer()
	var idx := ts.get_custom_data_layers_count() - 1
	ts.set_custom_data_layer_name(idx, layer_name)
	ts.set_custom_data_layer_type(idx, type)
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"tileset_path": res[0],
		"layer_index": idx,
		"name": layer_name,
		"type": type_str,
	})


func _tileset_list_custom_data_layers(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "tileset_path")
	if res[1] != null:
		return res[1]
	var ts := _load_ts(res[0])
	if ts == null:
		return error_not_found("TileSet")
	var layers: Array = []
	for i in range(ts.get_custom_data_layers_count()):
		layers.append({
			"index": i,
			"name": ts.get_custom_data_layer_name(i),
			"type": ts.get_custom_data_layer_type(i),
		})
	return success({"layers": layers, "count": layers.size()})


func _tileset_set_tile_custom_data(params: Dictionary) -> Dictionary:
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
		return error_not_found("tile")
	var td: TileData = atlas.get_tile_data(coords, int(params.get("alternative", 0)))
	var layer_name: String = optional_string(params, "layer_name", optional_string(params, "name", ""))
	if layer_name.is_empty() and params.has("layer_index"):
		var li: int = int(params["layer_index"])
		layer_name = ts.get_custom_data_layer_name(li)
	if layer_name.is_empty():
		return error_invalid_params("layer_name or layer_index required")
	if not params.has("value"):
		return error_invalid_params("value required")
	td.set_custom_data(layer_name, params["value"])
	var err := ResourceSaver.save(ts, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"atlas_coords": {"x": coords.x, "y": coords.y},
		"layer_name": layer_name,
		"value": params["value"],
	})


func _tileset_get_tile_custom_data(params: Dictionary) -> Dictionary:
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
		return error_not_found("tile")
	var td: TileData = atlas.get_tile_data(coords, 0)
	var data := {}
	for i in range(ts.get_custom_data_layers_count()):
		var n := ts.get_custom_data_layer_name(i)
		data[n] = td.get_custom_data(n)
	return success({"atlas_coords": {"x": coords.x, "y": coords.y}, "custom_data": data})
