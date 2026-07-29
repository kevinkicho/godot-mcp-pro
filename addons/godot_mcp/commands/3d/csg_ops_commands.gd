@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## CSG composition - operations + bake to MeshInstance (level greybox finalization).


func get_commands() -> Dictionary:
	return {
		"csg_set_operation": _csg_set_operation,
		"csg_set_use_collision": _csg_set_use_collision,
		"csg_get_info": _csg_get_info,
		"csg_bake_to_mesh_instance": _csg_bake_to_mesh_instance,
		"csg_list_shapes": _csg_list_shapes,
		"list_csg_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_csg_box", "setup_csg_sphere", "setup_csg_cylinder", "greybox_room"],
		"flow": [
			"setup_csg_box / greybox_room",
			"csg_set_operation on cutters (subtraction)",
			"csg_set_use_collision true on root",
			"csg_bake_to_mesh_instance when finalizing",
		],
	})


func _csg(path: String) -> CSGShape3D:
	var n := find_node_by_path(path)
	if n is CSGShape3D:
		return n as CSGShape3D
	return null


func _csg_set_operation(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var csg := _csg(r0[0])
	if csg == null:
		return error_not_found("CSGShape3D")
	var op: String = optional_string(params, "operation", "union").to_lower()
	var old := csg.operation
	match op:
		"intersection", "intersect":
			csg.operation = CSGShape3D.OPERATION_INTERSECTION
		"subtraction", "subtract", "difference":
			csg.operation = CSGShape3D.OPERATION_SUBTRACTION
		_:
			csg.operation = CSGShape3D.OPERATION_UNION
			op = "union"
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"operation": op,
		"previous": old,
	})


func _csg_set_use_collision(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var csg := _csg(r0[0])
	if csg == null:
		return error_not_found("CSGShape3D")
	var use: bool = optional_bool(params, "use_collision", true)
	csg.use_collision = use
	if params.has("collision_layer"):
		csg.collision_layer = int(params["collision_layer"])
	if params.has("collision_mask"):
		csg.collision_mask = int(params["collision_mask"])
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"use_collision": csg.use_collision,
		"collision_layer": csg.collision_layer,
		"collision_mask": csg.collision_mask,
	})


func _csg_get_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var csg := _csg(r0[0])
	if csg == null:
		return error_not_found("CSGShape3D")
	var op_name := "union"
	match csg.operation:
		CSGShape3D.OPERATION_INTERSECTION:
			op_name = "intersection"
		CSGShape3D.OPERATION_SUBTRACTION:
			op_name = "subtraction"
	var meshes_info: Array = []
	if csg.has_method("get_meshes"):
		var meshes = csg.get_meshes()
		if meshes is Array:
			for i in range(meshes.size()):
				var m = meshes[i]
				meshes_info.append({"index": i, "type": typeof(m), "class": m.get_class() if m is Object else str(typeof(m))})
	return success({
		"node_path": r0[0],
		"class": csg.get_class(),
		"operation": op_name,
		"use_collision": csg.use_collision,
		"operation_enum": csg.operation,
		"meshes_meta": meshes_info,
		"child_count": csg.get_child_count(),
	})


func _csg_bake_to_mesh_instance(params: Dictionary) -> Dictionary:
	## Convert CSG result to MeshInstance3D (and optional StaticBody collision).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var csg := _csg(r0[0])
	if csg == null:
		return error_not_found("CSGShape3D")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var mesh: Mesh = null
	# CSGShape3D.get_meshes() returns [Transform3D, Mesh] pairs in Godot 4
	if csg.has_method("get_meshes"):
		var arr = csg.get_meshes()
		if arr is Array and arr.size() >= 2:
			# Often [transform, mesh] or multiple pairs
			for item in arr:
				if item is Mesh:
					mesh = item
					break
			if mesh == null and arr.size() >= 2 and arr[1] is Mesh:
				mesh = arr[1]
	if mesh == null and "mesh" in csg:
		var m = csg.get("mesh")
		if m is Mesh:
			mesh = m

	if mesh == null:
		return error_internal(
			"Could not extract mesh from CSG - ensure shape is root CSG combiner with children, or use editor Mesh -> Create MeshInstance"
		)

	var parent: Node = csg.get_parent()
	if parent == null:
		parent = root
	var mi := MeshInstance3D.new()
	mi.name = optional_string(params, "name", csg.name + "_Baked")
	mi.mesh = mesh.duplicate() if optional_bool(params, "duplicate_mesh", true) else mesh
	if csg is Node3D:
		mi.global_transform = (csg as Node3D).global_transform
	add_child_with_undo(parent, mi, root, "MCP: Bake CSG to MeshInstance")
	# Fix transform after reparent
	if csg is Node3D:
		mi.global_transform = (csg as Node3D).global_transform

	var result := {
		"csg_path": r0[0],
		"mesh_instance_path": str(root.get_path_to(mi)),
		"mesh_class": mesh.get_class(),
	}

	if optional_bool(params, "add_collision", false):
		var mode: String = optional_string(params, "collision_mode", "trimesh")
		var shape: Shape3D = null
		if mode == "convex" and mi.mesh.has_method("create_convex_shape"):
			shape = mi.mesh.create_convex_shape(true, false)
		else:
			shape = mi.mesh.create_trimesh_shape()
		if shape:
			var body := StaticBody3D.new()
			body.name = "StaticBody3D"
			var col := CollisionShape3D.new()
			col.name = "CollisionShape3D"
			col.shape = shape
			add_child_with_undo(mi, body, root, "MCP: CSG bake collision body")
			add_child_with_undo(body, col, root, "MCP: CSG bake collision shape")
			result["body_path"] = str(root.get_path_to(body))
			result["collision_path"] = str(root.get_path_to(col))

	if optional_bool(params, "hide_csg", true):
		csg.visible = false
		result["csg_hidden"] = true

	mark_current_scene_unsaved()
	return success(result)


func _csg_list_shapes(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start_path: String = optional_string(params, "node_path", ".")
	var start := find_node_by_path(start_path)
	if start == null:
		start = root
	var out: Array = []
	_collect_csg(start, root, out)
	return success({"shapes": out, "count": out.size()})


func _collect_csg(n: Node, root: Node, out: Array) -> void:
	if n is CSGShape3D:
		var c := n as CSGShape3D
		var op := "union"
		match c.operation:
			CSGShape3D.OPERATION_INTERSECTION:
				op = "intersection"
			CSGShape3D.OPERATION_SUBTRACTION:
				op = "subtraction"
		out.append({
			"path": str(root.get_path_to(n)),
			"class": n.get_class(),
			"operation": op,
			"use_collision": c.use_collision,
			"visible": c.visible,
		})
	for ch in n.get_children():
		_collect_csg(ch, root, out)
