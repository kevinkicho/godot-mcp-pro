@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## GridMap deep paint — 3D level cell placement (TileMap parity for GridMap).


func get_commands() -> Dictionary:
	return {
		"gridmap_set_cell": _gridmap_set_cell,
		"gridmap_fill_rect": _gridmap_fill_rect,
		"gridmap_get_cell": _gridmap_get_cell,
		"gridmap_clear": _gridmap_clear,
		"gridmap_get_used_cells": _gridmap_get_used_cells,
		"gridmap_set_mesh_library": _gridmap_set_mesh_library,
		"gridmap_paint_line": _gridmap_paint_line,
		"gridmap_get_info": _gridmap_get_info,
	}


func _gm(path: String) -> GridMap:
	var n := find_node_by_path(path)
	if n is GridMap:
		return n as GridMap
	return null


func _gridmap_set_cell(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	var x := int(params.get("x", 0))
	var y := int(params.get("y", 0))
	var z := int(params.get("z", 0))
	var item: int = int(params.get("item", params.get("mesh_item", 0)))
	var orientation: int = int(params.get("orientation", 0))
	var pos := Vector3i(x, y, z)
	var old := gm.get_cell_item(pos)
	gm.set_cell_item(pos, item, orientation)
	mark_current_scene_unsaved()
	return success({
		"cell": {"x": x, "y": y, "z": z},
		"item": item,
		"orientation": orientation,
		"previous_item": old,
	})


func _gridmap_fill_rect(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	var x0 := int(params.get("x0", params.get("x", 0)))
	var y0 := int(params.get("y0", params.get("y", 0)))
	var z0 := int(params.get("z0", params.get("z", 0)))
	var x1 := int(params.get("x1", x0))
	var y1 := int(params.get("y1", y0))
	var z1 := int(params.get("z1", z0))
	var item: int = int(params.get("item", 0))
	var orientation: int = int(params.get("orientation", 0))
	var count := 0
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			for z in range(mini(z0, z1), maxi(z0, z1) + 1):
				gm.set_cell_item(Vector3i(x, y, z), item, orientation)
				count += 1
				if count > 20000:
					return error_invalid_params("Fill exceeds 20000 cells — shrink region")
	mark_current_scene_unsaved()
	return success({"cells_set": count, "item": item})


func _gridmap_paint_line(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	var x0 := int(params.get("x0", 0))
	var y0 := int(params.get("y0", 0))
	var z0 := int(params.get("z0", 0))
	var x1 := int(params.get("x1", 0))
	var y1 := int(params.get("y1", 0))
	var z1 := int(params.get("z1", 0))
	var item: int = int(params.get("item", 0))
	var orientation: int = int(params.get("orientation", 0))
	# 3D Bresenham-ish via steps
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var dz := absi(z1 - z0)
	var steps := maxi(dx, maxi(dy, dz))
	steps = maxi(steps, 1)
	var count := 0
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := int(round(lerpf(x0, x1, t)))
		var y := int(round(lerpf(y0, y1, t)))
		var z := int(round(lerpf(z0, z1, t)))
		gm.set_cell_item(Vector3i(x, y, z), item, orientation)
		count += 1
	mark_current_scene_unsaved()
	return success({"cells_set": count, "item": item})


func _gridmap_get_cell(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	var pos := Vector3i(int(params.get("x", 0)), int(params.get("y", 0)), int(params.get("z", 0)))
	return success({
		"cell": {"x": pos.x, "y": pos.y, "z": pos.z},
		"item": gm.get_cell_item(pos),
		"orientation": gm.get_cell_item_orientation(pos),
		"empty": gm.get_cell_item(pos) == GridMap.INVALID_CELL_ITEM,
	})


func _gridmap_clear(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	gm.clear()
	mark_current_scene_unsaved()
	return success({"cleared": true})


func _gridmap_get_used_cells(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	var max_n: int = clampi(optional_int(params, "max", 500), 1, 5000)
	var used: Array = gm.get_used_cells()
	var out: Array = []
	for i in mini(used.size(), max_n):
		var c: Vector3i = used[i]
		out.append({
			"x": c.x, "y": c.y, "z": c.z,
			"item": gm.get_cell_item(c),
		})
	return success({
		"cells": out,
		"count": out.size(),
		"total_used": used.size(),
		"truncated": used.size() > max_n,
	})


func _gridmap_set_mesh_library(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	var lib_path: String = optional_string(params, "mesh_library_path", optional_string(params, "path", ""))
	if lib_path.is_empty():
		return error_invalid_params("mesh_library_path required")
	if not lib_path.begins_with("res://"):
		lib_path = "res://" + lib_path.trim_prefix("/")
	if not ResourceLoader.exists(lib_path):
		return error_not_found(lib_path)
	var lib: MeshLibrary = load(lib_path) as MeshLibrary
	if lib == null:
		return error_invalid_params("Not a MeshLibrary")
	gm.mesh_library = lib
	mark_current_scene_unsaved()
	var items: Array = []
	for id in lib.get_item_list():
		items.append({"id": id, "name": lib.get_item_name(id)})
		if items.size() >= 50:
			break
	return success({"mesh_library": lib_path, "items_sample": items, "item_count": lib.get_item_list().size()})


func _gridmap_get_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gm := _gm(r0[0])
	if gm == null:
		return error_not_found("GridMap")
	var lib_path := ""
	if gm.mesh_library:
		lib_path = gm.mesh_library.resource_path
	return success({
		"node_path": r0[0],
		"cell_size": {"x": gm.cell_size.x, "y": gm.cell_size.y, "z": gm.cell_size.z},
		"mesh_library": lib_path,
		"used_cells": gm.get_used_cells().size(),
		"cell_center": gm.cell_center_x if "cell_center_x" in gm else null,
	})
