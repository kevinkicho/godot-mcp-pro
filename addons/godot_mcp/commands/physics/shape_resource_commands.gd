@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Shape2D / Shape3D resource authoring + assign to CollisionShape(2D/3D).
## Agents often need saved shapes (shared radius/size) not only inline inspector shapes.


func get_commands() -> Dictionary:
	return {
		"create_shape_resource": _create_shape_resource,
		"list_shape_resource_types": _list_types,
		"assign_shape_to_collision": _assign_shape,
		"setup_collision_from_shape_resource": _setup_collision_from_shape,
		"batch_create_shape_resources": _batch_create,
		"list_shape_resource_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_collision", "create_physics_body", "mesh_create_trimesh_static_body"],
		"workflow": [
			"create_shape_resource path=res://shapes/player_capsule.tres type=capsule2d radius=8 height=24",
			"setup_collision_from_shape_resource parent_path=Player shape_path=...",
		],
	})


func _list_types(_params: Dictionary) -> Dictionary:
	return success({
		"shape2d": [
			"circle", "circle2d", "rectangle", "rectangle2d", "capsule", "capsule2d",
			"segment", "segment2d", "world_boundary", "world_boundary2d",
			"convex_polygon", "convex_polygon2d", "concave_polygon", "concave_polygon2d",
		],
		"shape3d": [
			"box", "box3d", "sphere", "sphere3d", "capsule", "capsule3d",
			"cylinder", "cylinder3d", "world_boundary", "world_boundary3d",
			"convex_polygon", "convex_polygon3d", "concave_polygon", "concave_polygon3d",
		],
	})


func _parse_vec2(v: Variant, default: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Dictionary:
		return Vector2(float(v.get("x", default.x)), float(v.get("y", default.y)))
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return default


func _parse_vec3(v: Variant, default: Vector3 = Vector3.ZERO) -> Vector3:
	if v is Dictionary:
		return Vector3(float(v.get("x", default.x)), float(v.get("y", default.y)), float(v.get("z", default.z)))
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return default


func _build_shape(params: Dictionary) -> Array:
	## Returns [shape_resource, error_or_null]
	var type_name: String = optional_string(params, "type", optional_string(params, "shape_type", "")).to_lower()
	if type_name.is_empty():
		return [null, error_invalid_params("type required - list_shape_resource_types")]
	var shape: Resource = null
	match type_name:
		"circle", "circle2d":
			var s := CircleShape2D.new()
			s.radius = float(params.get("radius", 16.0))
			shape = s
		"rectangle", "rectangle2d", "rect", "box2d":
			var s2 := RectangleShape2D.new()
			if params.has("size"):
				s2.size = _parse_vec2(params["size"], Vector2(32, 32))
			else:
				s2.size = Vector2(float(params.get("width", 32)), float(params.get("height", 32)))
			shape = s2
		"capsule2d":
			var s3 := CapsuleShape2D.new()
			s3.radius = float(params.get("radius", 8.0))
			s3.height = float(params.get("height", 24.0))
			shape = s3
		"capsule":
			# Ambiguous: prefer dimension param or 3d default for bare "capsule"
			if str(params.get("dimension", "3d")).to_lower() in ["2d", "2"]:
				var s3b := CapsuleShape2D.new()
				s3b.radius = float(params.get("radius", 8.0))
				s3b.height = float(params.get("height", 24.0))
				shape = s3b
			else:
				var s3c := CapsuleShape3D.new()
				s3c.radius = float(params.get("radius", 0.5))
				s3c.height = float(params.get("height", 2.0))
				shape = s3c
		"segment", "segment2d":
			var s4 := SegmentShape2D.new()
			s4.a = _parse_vec2(params.get("a", {"x": 0, "y": 0}))
			s4.b = _parse_vec2(params.get("b", {"x": 32, "y": 0}))
			shape = s4
		"world_boundary2d", "world_boundary_2d":
			var s5 := WorldBoundaryShape2D.new()
			if params.has("normal"):
				s5.normal = _parse_vec2(params["normal"], Vector2(0, -1))
			if params.has("distance"):
				s5.distance = float(params["distance"])
			shape = s5
		"convex_polygon2d", "convex_polygon_2d":
			var s6 := ConvexPolygonShape2D.new()
			s6.points = _points2(params.get("points", []))
			shape = s6
		"concave_polygon2d", "concave_polygon_2d":
			var s7 := ConcavePolygonShape2D.new()
			s7.segments = _points2(params.get("segments", params.get("points", [])))
			shape = s7
		"box", "box3d":
			var s8 := BoxShape3D.new()
			if params.has("size"):
				s8.size = _parse_vec3(params["size"], Vector3(1, 1, 1))
			else:
				s8.size = Vector3(
					float(params.get("width", params.get("x", 1))),
					float(params.get("height", params.get("y", 1))),
					float(params.get("depth", params.get("z", 1)))
				)
			shape = s8
		"sphere", "sphere3d":
			var s9 := SphereShape3D.new()
			s9.radius = float(params.get("radius", 0.5))
			shape = s9
		"capsule3d":
			var s10 := CapsuleShape3D.new()
			s10.radius = float(params.get("radius", 0.5))
			s10.height = float(params.get("height", 2.0))
			shape = s10
		"cylinder", "cylinder3d":
			var s11 := CylinderShape3D.new()
			s11.radius = float(params.get("radius", 0.5))
			s11.height = float(params.get("height", 2.0))
			shape = s11
		"world_boundary3d", "world_boundary_3d", "world_boundary":
			if type_name == "world_boundary" and str(params.get("dimension", "3d")).to_lower() in ["2d", "2"]:
				var s5b := WorldBoundaryShape2D.new()
				if params.has("normal"):
					s5b.normal = _parse_vec2(params["normal"], Vector2(0, -1))
				shape = s5b
			else:
				var s12 := WorldBoundaryShape3D.new()
				if params.has("plane") and params["plane"] is Dictionary:
					var pl: Dictionary = params["plane"]
					s12.plane = Plane(
						float(pl.get("x", 0)), float(pl.get("y", 1)),
						float(pl.get("z", 0)), float(pl.get("d", 0))
					)
				shape = s12
		"convex_polygon3d", "convex_polygon_3d":
			var s13 := ConvexPolygonShape3D.new()
			s13.points = _points3(params.get("points", []))
			shape = s13
		"concave_polygon3d", "concave_polygon_3d":
			var s14 := ConcavePolygonShape3D.new()
			# faces as flat Vector3 array of triangles
			s14.set_faces(_points3(params.get("faces", params.get("points", []))))
			shape = s14
		_:
			return [null, error_invalid_params("Unknown shape type '%s'" % type_name)]
	return [shape, null]


func _points2(arr: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not arr is Array:
		return out
	for p in arr:
		out.append(_parse_vec2(p))
	return out


func _points3(arr: Variant) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not arr is Array:
		return out
	for p in arr:
		out.append(_parse_vec3(p))
	return out


func _create_shape_resource(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var built := _build_shape(params)
	if built[1] != null:
		return built[1]
	var shape: Resource = built[0]
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(shape, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"class": shape.get_class(),
		"type": optional_string(params, "type", ""),
	})


func _batch_create(params: Dictionary) -> Dictionary:
	## shapes: [{path, type, ...params}]
	if not params.has("shapes") or not (params["shapes"] is Array):
		return error_invalid_params("shapes array required")
	var results: Array = []
	var ok := 0
	for item in params["shapes"]:
		if not item is Dictionary:
			results.append({"ok": false, "error": "item not dict"})
			continue
		var one: Dictionary = (item as Dictionary).duplicate()
		if not one.has("overwrite"):
			one["overwrite"] = optional_bool(params, "overwrite", false)
		var r := _create_shape_resource(one)
		var is_ok := r is Dictionary and r.has("result")
		if is_ok:
			ok += 1
		results.append({"ok": is_ok, "result": r})
	return success({"count": results.size(), "ok_count": ok, "results": results})


func _assign_shape(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var shape_r := require_res_path(params, "shape_path")
	if shape_r[1] != null:
		return shape_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node at '%s'" % r0[0])
	if not ResourceLoader.exists(shape_r[0]):
		return error_not_found(shape_r[0])
	var shape = load(shape_r[0])
	if shape == null:
		return error_internal("Failed to load shape")
	if node is CollisionShape2D:
		if not (shape is Shape2D):
			return error_invalid_params("CollisionShape2D needs Shape2D, got %s" % shape.get_class())
		(node as CollisionShape2D).shape = shape
	elif node is CollisionShape3D:
		if not (shape is Shape3D):
			return error_invalid_params("CollisionShape3D needs Shape3D, got %s" % shape.get_class())
		(node as CollisionShape3D).shape = shape
	elif node is CollisionPolygon2D:
		return error_invalid_params("Use polygon points on CollisionPolygon2D - not Shape resources")
	else:
		return error_invalid_params("Node must be CollisionShape2D or CollisionShape3D")
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"shape_path": shape_r[0],
		"shape_class": shape.get_class(),
	})


func _setup_collision_from_shape(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var shape_path: String = optional_string(params, "shape_path", "")
	var shape: Resource = null
	if not shape_path.is_empty():
		var vr := validate_res_path(shape_path)
		if vr[1] != null:
			return vr[1]
		shape_path = vr[0]
		if not ResourceLoader.exists(shape_path):
			return error_not_found(shape_path)
		shape = load(shape_path)
	else:
		# Inline create without save
		var built := _build_shape(params)
		if built[1] != null:
			return built[1]
		shape = built[0]
	var is_2d := shape is Shape2D
	var col: Node
	if is_2d:
		col = CollisionShape2D.new()
		(col as CollisionShape2D).shape = shape as Shape2D
	else:
		col = CollisionShape3D.new()
		(col as CollisionShape3D).shape = shape as Shape3D
	col.name = optional_string(params, "name", "CollisionShape")
	if params.has("position"):
		if is_2d and params["position"] is Dictionary:
			(col as Node2D).position = _parse_vec2(params["position"])
		elif not is_2d and params["position"] is Dictionary:
			(col as Node3D).position = _parse_vec3(params["position"])
	if params.has("disabled"):
		col.set("disabled", bool(params["disabled"]))
	add_child_with_undo(parent, col, root, "MCP: Collision from shape resource")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(col)),
		"shape_class": shape.get_class(),
		"shape_path": shape_path,
		"dimension": "2d" if is_2d else "3d",
	})
