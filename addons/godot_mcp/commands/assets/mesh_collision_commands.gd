@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Mesh → collision (human MeshInstance right-click menu parity).
## create_trimesh_static_body / create_convex_collision / multiple convex.


func get_commands() -> Dictionary:
	return {
		"mesh_create_trimesh_collision": _mesh_create_trimesh_collision,
		"mesh_create_convex_collision": _mesh_create_convex_collision,
		"mesh_create_multiple_convex_collisions": _mesh_create_multiple_convex,
		"mesh_create_trimesh_static_body": _mesh_create_trimesh_static_body,
		"mesh_create_convex_static_body": _mesh_create_convex_static_body,
		"add_collision_shape_from_mesh": _add_collision_shape_from_mesh,
		"list_mesh_collision_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"human_menu": "MeshInstance3D → Mesh → Create Trimesh / Convex Collision Sibling / Static Body",
		"flow": [
			"mesh_create_trimesh_static_body on level mesh",
			"or mesh_create_convex_collision as sibling under existing body",
			"get_collision_info / playtest_report",
		],
	})


func _mi(path: String) -> MeshInstance3D:
	var n := find_node_by_path(path)
	if n is MeshInstance3D:
		return n as MeshInstance3D
	return null


func _mesh_create_trimesh_collision(params: Dictionary) -> Dictionary:
	## Sibling CollisionShape3D under same parent (like "Create Trimesh Collision Sibling").
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	if mi.mesh == null:
		return error_invalid_params("MeshInstance3D has no mesh")
	var shape: Shape3D = mi.mesh.create_trimesh_shape()
	if shape == null:
		return error_internal("create_trimesh_shape failed")
	var root := get_edited_root()
	var parent: Node = mi.get_parent()
	if parent == null:
		parent = root
	var col := CollisionShape3D.new()
	col.name = optional_string(params, "name", mi.name + "_TrimeshCol")
	col.shape = shape
	col.transform = mi.transform
	add_child_with_undo(parent, col, root, "MCP: Trimesh collision sibling")
	mark_current_scene_unsaved()
	return success({
		"mesh_path": r0[0],
		"collision_path": str(root.get_path_to(col)),
		"shape_class": shape.get_class(),
	})


func _mesh_create_convex_collision(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	if mi.mesh == null:
		return error_invalid_params("MeshInstance3D has no mesh")
	var clean: bool = optional_bool(params, "clean", true)
	var simplify: bool = optional_bool(params, "simplify", false)
	var shape: Shape3D = null
	if mi.mesh.has_method("create_convex_shape"):
		shape = mi.mesh.create_convex_shape(clean, simplify)
	if shape == null:
		return error_internal("create_convex_shape failed")
	var root := get_edited_root()
	var parent: Node = mi.get_parent()
	if parent == null:
		parent = root
	var col := CollisionShape3D.new()
	col.name = optional_string(params, "name", mi.name + "_ConvexCol")
	col.shape = shape
	col.transform = mi.transform
	add_child_with_undo(parent, col, root, "MCP: Convex collision sibling")
	mark_current_scene_unsaved()
	return success({
		"mesh_path": r0[0],
		"collision_path": str(root.get_path_to(col)),
		"shape_class": shape.get_class(),
		"clean": clean,
		"simplify": simplify,
	})


func _mesh_create_multiple_convex(params: Dictionary) -> Dictionary:
	## Best-effort multi-convex (when Mesh API supports it).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	if mi.mesh == null:
		return error_invalid_params("MeshInstance3D has no mesh")
	var root := get_edited_root()
	var parent: Node = mi.get_parent()
	if parent == null:
		parent = root
	var shapes: Array = []
	if mi.mesh.has_method("convex_decompose"):
		var settings = null
		if ClassDB.class_exists("MeshConvexDecompositionSettings"):
			settings = ClassDB.instantiate("MeshConvexDecompositionSettings")
			if settings and params.has("max_convex_hulls"):
				if "max_convex_hulls" in settings:
					settings.set("max_convex_hulls", int(params["max_convex_hulls"]))
		var result = mi.mesh.call("convex_decompose", settings) if settings else mi.mesh.call("convex_decompose")
		if result is Array:
			shapes = result
	if shapes.is_empty():
		# Fallback single convex
		var one: Shape3D = mi.mesh.create_convex_shape(true, false) if mi.mesh.has_method("create_convex_shape") else null
		if one:
			shapes.append(one)
	if shapes.is_empty():
		return error_internal("convex_decompose unavailable — use mesh_create_convex_collision")
	var paths: Array = []
	var i := 0
	for s in shapes:
		if not s is Shape3D:
			continue
		var col := CollisionShape3D.new()
		col.name = "%s_Convex%d" % [mi.name, i]
		col.shape = s
		col.transform = mi.transform
		add_child_with_undo(parent, col, root, "MCP: Multi convex collision")
		paths.append(str(root.get_path_to(col)))
		i += 1
	mark_current_scene_unsaved()
	return success({"mesh_path": r0[0], "collision_paths": paths, "count": paths.size()})


func _mesh_create_trimesh_static_body(params: Dictionary) -> Dictionary:
	## Human "Create Trimesh Static Body" — StaticBody3D child + trimesh shape.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	if mi.mesh == null:
		return error_invalid_params("MeshInstance3D has no mesh")
	var shape: Shape3D = mi.mesh.create_trimesh_shape()
	if shape == null:
		return error_internal("create_trimesh_shape failed")
	var root := get_edited_root()
	var body := StaticBody3D.new()
	body.name = optional_string(params, "body_name", "StaticBody3D")
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	add_child_with_undo(mi, body, root, "MCP: Trimesh StaticBody")
	add_child_with_undo(body, col, root, "MCP: Trimesh CollisionShape")
	if params.has("collision_layer"):
		body.collision_layer = int(params["collision_layer"])
	if params.has("collision_mask"):
		body.collision_mask = int(params["collision_mask"])
	mark_current_scene_unsaved()
	return success({
		"mesh_path": r0[0],
		"body_path": str(root.get_path_to(body)),
		"collision_path": str(root.get_path_to(col)),
		"shape_class": shape.get_class(),
	})


func _mesh_create_convex_static_body(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	if mi.mesh == null:
		return error_invalid_params("MeshInstance3D has no mesh")
	var clean: bool = optional_bool(params, "clean", true)
	var simplify: bool = optional_bool(params, "simplify", false)
	var shape: Shape3D = mi.mesh.create_convex_shape(clean, simplify) if mi.mesh.has_method("create_convex_shape") else null
	if shape == null:
		return error_internal("create_convex_shape failed")
	var root := get_edited_root()
	var body := StaticBody3D.new()
	body.name = optional_string(params, "body_name", "StaticBody3D")
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	add_child_with_undo(mi, body, root, "MCP: Convex StaticBody")
	add_child_with_undo(body, col, root, "MCP: Convex CollisionShape")
	mark_current_scene_unsaved()
	return success({
		"mesh_path": r0[0],
		"body_path": str(root.get_path_to(body)),
		"collision_path": str(root.get_path_to(col)),
	})


func _add_collision_shape_from_mesh(params: Dictionary) -> Dictionary:
	## Add CollisionShape under an existing PhysicsBody/Area from a MeshInstance mesh.
	var body_r := require_string(params, "body_path")
	if body_r[1] != null:
		return body_r[1]
	var mesh_r := require_string(params, "mesh_path")
	if mesh_r[1] != null:
		return mesh_r[1]
	var body := find_node_by_path(body_r[0])
	var mi := _mi(mesh_r[0])
	if body == null:
		return error_not_found("Body '%s'" % body_r[0])
	if mi == null or mi.mesh == null:
		return error_not_found("MeshInstance3D with mesh")
	var mode: String = optional_string(params, "mode", "trimesh")  # trimesh | convex
	var shape: Shape3D = null
	if mode == "convex":
		shape = mi.mesh.create_convex_shape(true, false) if mi.mesh.has_method("create_convex_shape") else null
	else:
		shape = mi.mesh.create_trimesh_shape()
	if shape == null:
		return error_internal("Shape generation failed")
	var root := get_edited_root()
	var col := CollisionShape3D.new()
	col.name = optional_string(params, "name", "CollisionShape3D")
	col.shape = shape
	# Align to mesh if under different branch — use global transform relative to body
	if body is Node3D and mi is Node3D:
		col.global_transform = mi.global_transform
	add_child_with_undo(body, col, root, "MCP: Collision from mesh")
	# Re-apply after parent so local transform is correct
	if body is Node3D and mi is Node3D:
		col.global_transform = mi.global_transform
	mark_current_scene_unsaved()
	return success({
		"body_path": body_r[0],
		"mesh_path": mesh_r[0],
		"collision_path": str(root.get_path_to(col)),
		"mode": mode,
	})
