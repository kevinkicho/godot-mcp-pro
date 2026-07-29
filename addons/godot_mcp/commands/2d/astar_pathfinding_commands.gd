@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## AStar2D / AStar3D / AStarGrid2D pathfinding — grid games, tactical maps, point graphs.


func get_commands() -> Dictionary:
	return {
		"create_astar_grid_2d_script": _create_grid_script,
		"create_astar_point_graph_script": _create_point_script,
		"setup_astar_grid_controller": _setup_grid_controller,
		"list_astar_pathfinding_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_navigation_region", "navigation_query_path", "setup_ai_agent_2d", "tilemap_*"],
		"docs": "https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html",
		"when": "Use AStarGrid2D for tile/grid games; NavigationServer for free-form navmeshes",
	})


func _create_grid_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/astar_grid_2d.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## AStarGrid2D wrapper for tile/grid pathfinding.

signal path_ready(points: PackedVector2Array)

@export var region: Rect2i = Rect2i(0, 0, 64, 64)
@export var cell_size: Vector2 = Vector2(16, 16)
@export var offset: Vector2 = Vector2.ZERO
@export var diagonal_mode: int = 1 ## AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES

var grid: AStarGrid2D = AStarGrid2D.new()

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	grid.region = region
	grid.cell_size = cell_size
	grid.offset = offset
	grid.diagonal_mode = diagonal_mode as AStarGrid2D.DiagonalMode
	grid.update()

func set_solid(cell: Vector2i, solid: bool = true) -> void:
	if grid.is_in_boundsv(cell):
		grid.set_point_solid(cell, solid)

func set_solid_rect(rect: Rect2i, solid: bool = true) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			set_solid(Vector2i(x, y), solid)

func clear_solids() -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var c := Vector2i(x, y)
			if grid.is_in_boundsv(c):
				grid.set_point_solid(c, false)

func world_to_id(world: Vector2) -> Vector2i:
	return grid.get_id_from_world(world) if grid.has_method("get_id_from_world") else Vector2i(
		int(floor((world.x - offset.x) / cell_size.x)),
		int(floor((world.y - offset.y) / cell_size.y))
	)

func id_to_world(id: Vector2i) -> Vector2:
	return grid.get_point_position(id)

func find_path_ids(from_id: Vector2i, to_id: Vector2i) -> Array[Vector2i]:
	var pts := grid.get_id_path(from_id, to_id)
	var out: Array[Vector2i] = []
	for p in pts:
		out.append(p)
	return out

func find_path_world(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var a := world_to_id(from_world)
	var b := world_to_id(to_world)
	var ids := grid.get_id_path(a, b)
	var out := PackedVector2Array()
	for id in ids:
		out.append(id_to_world(id))
	path_ready.emit(out)
	return out

func apply_tilemap_solids(tilemap: TileMapLayer, solid_source_ids: PackedInt32Array = PackedInt32Array()) -> int:
	## Mark used cells solid, or only those whose source_id is in solid_source_ids when non-empty.
	var n := 0
	for cell in tilemap.get_used_cells():
		var sid := tilemap.get_cell_source_id(cell)
		var solid := true
		if solid_source_ids.size() > 0:
			solid = sid in solid_source_ids
		set_solid(cell, solid)
		if solid:
			n += 1
	return n
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "class": "AStarGrid2D wrapper", "hint": "setup_astar_grid_controller or attach_script"})


func _create_point_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/astar_point_graph.gd")
	var dim: String = optional_string(params, "dimension", "2d").to_lower()
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var is_3d := dim in ["3d", "3"]
	var content: String
	if is_3d:
		content = """extends Node
## AStar3D point-graph pathfinding.

var astar := AStar3D.new()

func clear() -> void:
	astar.clear()

func add_point(id: int, position: Vector3, weight_scale: float = 1.0) -> void:
	astar.add_point(id, position, weight_scale)

func connect_points(a: int, b: int, bidirectional: bool = true) -> void:
	astar.connect_points(a, b, bidirectional)

func disconnect_points(a: int, b: int, bidirectional: bool = true) -> void:
	astar.disconnect_points(a, b, bidirectional)

func set_point_disabled(id: int, disabled: bool = true) -> void:
	astar.set_point_disabled(id, disabled)

func get_path(from_id: int, to_id: int) -> PackedVector3Array:
	return astar.get_point_path(from_id, to_id)

func get_id_path(from_id: int, to_id: int) -> PackedInt64Array:
	return astar.get_id_path(from_id, to_id)

func get_closest_point(to: Vector3, include_disabled: bool = false) -> int:
	return astar.get_closest_point(to, include_disabled)
"""
	else:
		content = """extends Node
## AStar2D point-graph pathfinding.

var astar := AStar2D.new()

func clear() -> void:
	astar.clear()

func add_point(id: int, position: Vector2, weight_scale: float = 1.0) -> void:
	astar.add_point(id, position, weight_scale)

func connect_points(a: int, b: int, bidirectional: bool = true) -> void:
	astar.connect_points(a, b, bidirectional)

func disconnect_points(a: int, b: int, bidirectional: bool = true) -> void:
	astar.disconnect_points(a, b, bidirectional)

func set_point_disabled(id: int, disabled: bool = true) -> void:
	astar.set_point_disabled(id, disabled)

func get_path(from_id: int, to_id: int) -> PackedVector2Array:
	return astar.get_point_path(from_id, to_id)

func get_id_path(from_id: int, to_id: int) -> PackedInt64Array:
	return astar.get_id_path(from_id, to_id)

func get_closest_point(to: Vector2, include_disabled: bool = false) -> int:
	return astar.get_closest_point(to, include_disabled)

func build_grid(cols: int, rows: int, cell: Vector2 = Vector2(16, 16), connect8: bool = true) -> void:
	clear()
	for y in rows:
		for x in cols:
			var id := y * cols + x
			add_point(id, Vector2(x * cell.x, y * cell.y))
	for y in rows:
		for x in cols:
			var id := y * cols + x
			if x + 1 < cols:
				connect_points(id, id + 1)
			if y + 1 < rows:
				connect_points(id, id + cols)
			if connect8:
				if x + 1 < cols and y + 1 < rows:
					connect_points(id, id + cols + 1)
				if x > 0 and y + 1 < rows:
					connect_points(id, id + cols - 1)
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "dimension": "3d" if is_3d else "2d"})


func _setup_grid_controller(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var script_path: String = optional_string(params, "script_path", "res://scripts/astar_grid_2d.gd")
	if not FileAccess.file_exists(script_path) or optional_bool(params, "overwrite_script", false):
		var cr := _create_grid_script({"path": script_path, "overwrite": true})
		if cr.has("error"):
			return cr
	var node := Node.new()
	node.name = optional_string(params, "name", "AStarGrid")
	var script_res = load(script_path)
	if script_res:
		node.set_script(script_res)
	add_child_with_undo(parent, node, root, "MCP: AStarGrid controller")
	if "region" in node and params.has("region") and params["region"] is Dictionary:
		var r: Dictionary = params["region"]
		node.set("region", Rect2i(
			int(r.get("x", 0)), int(r.get("y", 0)),
			int(r.get("w", r.get("width", 64))), int(r.get("h", r.get("height", 64)))
		))
	if "cell_size" in node and params.has("cell_size"):
		var cs = params["cell_size"]
		if cs is Dictionary:
			node.set("cell_size", Vector2(float(cs.get("x", 16)), float(cs.get("y", 16))))
		elif cs is float or cs is int:
			node.set("cell_size", Vector2(float(cs), float(cs)))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"script_path": script_path,
		"hint": "Call rebuild(), set_solid(cell), find_path_world(from, to)",
	})
