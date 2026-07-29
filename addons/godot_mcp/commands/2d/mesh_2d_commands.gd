@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## MeshInstance2D + ArrayMesh 2D authoring (tutorials/2d/2d_meshes).
## Faster fill-rate for large translucent sprites; MultiMeshInstance2D for crowds.


func get_commands() -> Dictionary:
	return {
		"setup_mesh_instance_2d": _setup_mesh_instance_2d,
		"create_quad_mesh_2d": _create_quad_mesh_2d,
		"create_array_mesh_2d": _create_array_mesh_2d,
		"assign_mesh_2d": _assign_mesh_2d,
		"set_mesh_instance_2d_texture": _set_texture,
		"convert_sprite_to_mesh_instance_2d": _convert_sprite_to_mesh,
		"setup_multimesh_instance_2d": _setup_multimesh_instance_2d,
		"list_mesh_2d_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_polygon_2d", "load_sprite", "create_shader", "assign_shader_material"],
		"workflow": [
			"create_quad_mesh_2d path=res://meshes/quad.tres size={x:64,y:64}",
			"setup_mesh_instance_2d mesh_path=... texture_path=...",
			"OR convert_sprite_to_mesh_instance_2d node_path=Sprite2D",
		],
		"docs": "https://docs.godotengine.org/en/stable/tutorials/2d/2d_meshes.html",
	})


func _parse_vec2(v: Variant, default: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Dictionary:
		return Vector2(float(v.get("x", default.x)), float(v.get("y", default.y)))
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return default


func _build_quad_array_mesh(size: Vector2, uv_rect: Rect2 = Rect2(0, 0, 1, 1), centered: bool = true) -> ArrayMesh:
	var hw := size.x * 0.5 if centered else size.x
	var hh := size.y * 0.5 if centered else size.y
	var min_x := -hw if centered else 0.0
	var min_y := -hh if centered else 0.0
	var max_x := hw if centered else size.x
	var max_y := hh if centered else size.y
	var vertices := PackedVector2Array([
		Vector2(min_x, min_y),
		Vector2(max_x, min_y),
		Vector2(max_x, max_y),
		Vector2(min_x, max_y),
	])
	var uvs := PackedVector2Array([
		uv_rect.position,
		Vector2(uv_rect.end.x, uv_rect.position.y),
		uv_rect.end,
		Vector2(uv_rect.position.x, uv_rect.end.y),
	])
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _setup_mesh_instance_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var mi := MeshInstance2D.new()
	mi.name = optional_string(params, "name", "MeshInstance2D")
	if params.has("position") and params["position"] is Dictionary:
		mi.position = _parse_vec2(params["position"])
	# Mesh resource
	var mesh_path: String = optional_string(params, "mesh_path", "")
	if not mesh_path.is_empty():
		var mesh_res = load(mesh_path)
		if mesh_res is Mesh:
			mi.mesh = mesh_res
		else:
			return error_internal("Not a Mesh: %s" % mesh_path)
	elif optional_bool(params, "create_quad", true):
		var size := _parse_vec2(params.get("size", {"x": 64, "y": 64}), Vector2(64, 64))
		mi.mesh = _build_quad_array_mesh(size, Rect2(0, 0, 1, 1), optional_bool(params, "centered", true))
	var tex_path: String = optional_string(params, "texture_path", "")
	if not tex_path.is_empty():
		if not ResourceLoader.exists(tex_path):
			return error_not_found(tex_path)
		var tex = load(tex_path)
		if tex is Texture2D:
			mi.texture = tex
		else:
			return error_internal("Not a Texture2D: %s" % tex_path)
	add_child_with_undo(parent, mi, root, "MCP: MeshInstance2D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(mi)),
		"has_mesh": mi.mesh != null,
		"has_texture": mi.texture != null,
		"mesh_path": mesh_path,
		"texture_path": tex_path,
	})


func _create_quad_mesh_2d(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var size := _parse_vec2(params.get("size", {"x": 64, "y": 64}), Vector2(64, 64))
	var uv := Rect2(0, 0, 1, 1)
	if params.has("uv") and params["uv"] is Dictionary:
		var u: Dictionary = params["uv"]
		uv = Rect2(
			float(u.get("x", 0)), float(u.get("y", 0)),
			float(u.get("w", u.get("width", 1))), float(u.get("h", u.get("height", 1)))
		)
	var mesh := _build_quad_array_mesh(size, uv, optional_bool(params, "centered", true))
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(mesh, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"size": {"x": size.x, "y": size.y},
		"surface_count": mesh.get_surface_count(),
	})


func _create_array_mesh_2d(params: Dictionary) -> Dictionary:
	## vertices: [{x,y},...] or [[x,y],...]; optional uvs, colors, indices.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	if not params.has("vertices") or not (params["vertices"] is Array):
		return error_invalid_params("vertices array required")
	var vertices := PackedVector2Array()
	for v in params["vertices"]:
		vertices.append(_parse_vec2(v))
	if vertices.size() < 3:
		return error_invalid_params("Need at least 3 vertices")
	var uvs := PackedVector2Array()
	if params.has("uvs") and params["uvs"] is Array:
		for u in params["uvs"]:
			uvs.append(_parse_vec2(u))
	else:
		# Default unit square-ish UVs
		for i in vertices.size():
			var vv: Vector2 = vertices[i]
			uvs.append(Vector2(vv.x, vv.y))  # raw; agent can pass proper uvs
	var colors := PackedColorArray()
	if params.has("colors") and params["colors"] is Array:
		for c in params["colors"]:
			if c is String:
				colors.append(Color.html(c) if str(c).begins_with("#") else Color(str(c)))
			elif c is Dictionary:
				colors.append(Color(
					float(c.get("r", 1)), float(c.get("g", 1)),
					float(c.get("b", 1)), float(c.get("a", 1))
				))
			else:
				colors.append(Color.WHITE)
	else:
		for i in vertices.size():
			colors.append(Color.WHITE)
	var indices := PackedInt32Array()
	if params.has("indices") and params["indices"] is Array:
		for idx in params["indices"]:
			indices.append(int(idx))
	else:
		# Fan triangulation from vertex 0
		for i in range(1, vertices.size() - 1):
			indices.append(0)
			indices.append(i)
			indices.append(i + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	var prim := Mesh.PRIMITIVE_TRIANGLES
	if params.has("primitive"):
		var pn := str(params["primitive"]).to_lower()
		match pn:
			"triangles":
				prim = Mesh.PRIMITIVE_TRIANGLES
			"triangle_strip":
				prim = Mesh.PRIMITIVE_TRIANGLE_STRIP
			"lines":
				prim = Mesh.PRIMITIVE_LINES
			"line_strip":
				prim = Mesh.PRIMITIVE_LINE_STRIP
			"points":
				prim = Mesh.PRIMITIVE_POINTS
	mesh.add_surface_from_arrays(prim, arrays)
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(mesh, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"vertex_count": vertices.size(),
		"index_count": indices.size(),
		"surface_count": mesh.get_surface_count(),
	})


func _assign_mesh_2d(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is MeshInstance2D):
		return error_not_found("MeshInstance2D at '%s'" % r0[0])
	var mi: MeshInstance2D = node as MeshInstance2D
	var mesh_path: String = optional_string(params, "mesh_path", "")
	if mesh_path.is_empty():
		return error_invalid_params("mesh_path required")
	if not ResourceLoader.exists(mesh_path):
		return error_not_found(mesh_path)
	var mesh_res = load(mesh_path)
	if not (mesh_res is Mesh):
		return error_internal("Not a Mesh: %s" % mesh_path)
	mi.mesh = mesh_res
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "mesh_path": mesh_path})


func _set_texture(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is MeshInstance2D):
		return error_not_found("MeshInstance2D at '%s'" % r0[0])
	var mi: MeshInstance2D = node as MeshInstance2D
	var tex_path: String = optional_string(params, "texture_path", "")
	if tex_path.is_empty():
		mi.texture = null
		mark_current_scene_unsaved()
		return success({"node_path": r0[0], "texture_path": "", "cleared": true})
	if not ResourceLoader.exists(tex_path):
		return error_not_found(tex_path)
	var tex = load(tex_path)
	if not (tex is Texture2D):
		return error_internal("Not a Texture2D: %s" % tex_path)
	mi.texture = tex
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "texture_path": tex_path})


func _convert_sprite_to_mesh(params: Dictionary) -> Dictionary:
	## Approximate editor "Sprite2D -> Convert to MeshInstance2D" for a rectangular sprite.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is Sprite2D):
		return error_not_found("Sprite2D at '%s'" % r0[0])
	var spr: Sprite2D = node as Sprite2D
	var tex: Texture2D = spr.texture
	if tex == null:
		return error_invalid_params("Sprite2D has no texture")
	var size: Vector2
	if spr.region_enabled:
		size = Vector2(spr.region_rect.size)
	else:
		size = tex.get_size()
	size *= spr.scale.abs()
	# Mesh in local space of sprite (scale baked into mesh size or keep node scale)
	var mesh_size := tex.get_size() if not spr.region_enabled else Vector2(spr.region_rect.size)
	if spr.hframes > 1 or spr.vframes > 1:
		mesh_size = Vector2(
			mesh_size.x / float(spr.hframes),
			mesh_size.y / float(spr.vframes)
		)
	var uv := Rect2(0, 0, 1, 1)
	if spr.region_enabled and tex.get_size().x > 0:
		var ts := tex.get_size()
		uv = Rect2(
			spr.region_rect.position.x / ts.x,
			spr.region_rect.position.y / ts.y,
			spr.region_rect.size.x / ts.x,
			spr.region_rect.size.y / ts.y
		)
	var mesh := _build_quad_array_mesh(mesh_size, uv, spr.centered)
	var mi := MeshInstance2D.new()
	mi.name = optional_string(params, "name", spr.name + "Mesh")
	mi.mesh = mesh
	mi.texture = tex
	mi.position = spr.position
	mi.rotation = spr.rotation
	mi.scale = spr.scale
	mi.z_index = spr.z_index
	mi.modulate = spr.modulate
	var parent: Node = spr.get_parent()
	if parent == null:
		parent = root
	add_child_with_undo(parent, mi, root, "MCP: Convert Sprite2D to MeshInstance2D")
	if optional_bool(params, "hide_sprite", true):
		spr.visible = false
	if optional_bool(params, "remove_sprite", false):
		var undo_redo := get_undo_redo()
		undo_redo.create_action("MCP: Remove Sprite2D after mesh convert")
		undo_redo.add_do_method(parent, "remove_child", spr)
		undo_redo.add_undo_method(parent, "add_child", spr)
		undo_redo.add_undo_method(spr, "set_owner", root)
		undo_redo.add_do_reference(spr)
		undo_redo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(mi)),
		"source_sprite": r0[0],
		"mesh_size": {"x": mesh_size.x, "y": mesh_size.y},
		"sprite_hidden": not spr.visible if is_instance_valid(spr) else true,
	})


func _setup_multimesh_instance_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var mmi := MultiMeshInstance2D.new()
	mmi.name = optional_string(params, "name", "MultiMeshInstance2D")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	var instance_count: int = optional_int(params, "instance_count", 10)
	mm.instance_count = instance_count
	var mesh_path: String = optional_string(params, "mesh_path", "")
	if not mesh_path.is_empty() and ResourceLoader.exists(mesh_path):
		var mesh_res = load(mesh_path)
		if mesh_res is Mesh:
			mm.mesh = mesh_res
	else:
		var size := _parse_vec2(params.get("size", {"x": 16, "y": 16}), Vector2(16, 16))
		mm.mesh = _build_quad_array_mesh(size)
	# Optional grid placement
	if optional_bool(params, "layout_grid", false):
		var cols: int = optional_int(params, "columns", maxi(1, int(sqrt(instance_count))))
		var spacing := _parse_vec2(params.get("spacing", {"x": 32, "y": 32}), Vector2(32, 32))
		var origin := _parse_vec2(params.get("origin", {"x": 0, "y": 0}))
		for i in instance_count:
			var col := i % cols
			var row := i / cols
			var xf := Transform2D(0, origin + Vector2(col * spacing.x, row * spacing.y))
			mm.set_instance_transform_2d(i, xf)
	mmi.multimesh = mm
	var tex_path: String = optional_string(params, "texture_path", "")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		if tex is Texture2D:
			mmi.texture = tex
	add_child_with_undo(parent, mmi, root, "MCP: MultiMeshInstance2D")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(mmi)),
		"instance_count": instance_count,
		"has_texture": mmi.texture != null,
	})
