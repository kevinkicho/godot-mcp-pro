@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Heightmap -> MeshInstance3D terrain (engine-native; no third-party Terrain3D required).


func get_commands() -> Dictionary:
	return {
		"create_heightmap_terrain": _create_heightmap_terrain,
		"create_plane_mesh_terrain": _create_plane_mesh_terrain,
		"terrain_apply_height_noise": _terrain_apply_height_noise,
		"list_terrain_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"note": "Generates ArrayMesh / PlaneMesh heightfields. Third-party Terrain3D plugins can still be driven via update_property / call_node_method.",
		"tools": get_commands().keys(),
		"flow": [
			"create_heightmap_terrain or create_plane_mesh_terrain",
			"setup_collision StaticBody + Concave/Trimesh if needed",
			"setup_navigation_region bake over terrain",
		],
	})


func _create_plane_mesh_terrain(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var mi := MeshInstance3D.new()
	mi.name = optional_string(params, "name", "Terrain")
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(params.get("size_x", 64)), float(params.get("size_z", 64)))
	plane.subdivide_width = clampi(optional_int(params, "subdivide_x", 64), 1, 512)
	plane.subdivide_depth = clampi(optional_int(params, "subdivide_z", 64), 1, 512)
	mi.mesh = plane
	add_child_with_undo(parent, mi, root, "MCP: plane terrain")
	var body_path := ""
	if optional_bool(params, "with_static_body", true):
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		add_child_with_undo(mi, body, root, "MCP: terrain body")
		# Collision later via create_trimesh or agent; place empty shape optional
		body_path = str(root.get_path_to(body))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(mi)),
		"static_body": body_path,
		"hint": "terrain_apply_height_noise to displace vertices, or replace mesh via create_heightmap_terrain",
	})


func _create_heightmap_terrain(params: Dictionary) -> Dictionary:
	## Build ArrayMesh from height function or flat + optional noise.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var res_x: int = clampi(optional_int(params, "resolution_x", 65), 2, 257)
	var res_z: int = clampi(optional_int(params, "resolution_z", 65), 2, 257)
	var size_x: float = float(params.get("size_x", 64.0))
	var size_z: float = float(params.get("size_z", 64.0))
	var height_scale: float = float(params.get("height_scale", 8.0))
	var seed_v: int = optional_int(params, "seed", 1)
	var noise_amp: float = float(params.get("noise_amplitude", 1.0))
	var noise_freq: float = float(params.get("noise_frequency", 0.05))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# Simple value noise via RNG grid
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(res_x * res_z)
	for z in res_z:
		for x in res_x:
			var nx := float(x) * noise_freq
			var nz := float(z) * noise_freq
			# multi-octave pseudo noise
			var h := 0.0
			var amp := 1.0
			var freq := 1.0
			for o in 4:
				h += amp * _hash_noise(nx * freq, nz * freq, seed_v + o)
				amp *= 0.5
				freq *= 2.0
			heights[z * res_x + x] = h * height_scale * noise_amp

	# Heights override array if provided (row-major)
	if params.has("heights") and params["heights"] is Array:
		var arr: Array = params["heights"]
		for i in mini(arr.size(), heights.size()):
			heights[i] = float(arr[i]) * height_scale

	for z in res_z - 1:
		for x in res_x - 1:
			var i00 := z * res_x + x
			var i10 := z * res_x + x + 1
			var i01 := (z + 1) * res_x + x
			var i11 := (z + 1) * res_x + x + 1
			var p00 := _vert(x, z, res_x, res_z, size_x, size_z, heights[i00])
			var p10 := _vert(x + 1, z, res_x, res_z, size_x, size_z, heights[i10])
			var p01 := _vert(x, z + 1, res_x, res_z, size_x, size_z, heights[i01])
			var p11 := _vert(x + 1, z + 1, res_x, res_z, size_x, size_z, heights[i11])
			_tri(st, p00, p10, p11)
			_tri(st, p00, p11, p01)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.name = optional_string(params, "name", "HeightmapTerrain")
	mi.mesh = mesh
	add_child_with_undo(parent, mi, root, "MCP: heightmap terrain")

	var col_path := ""
	if optional_bool(params, "with_collision", true):
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		add_child_with_undo(mi, body, root, "MCP: terrain static")
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		# Trimesh
		var faces := mesh.get_faces()
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		shape.shape = concave
		add_child_with_undo(body, shape, root, "MCP: terrain coll")
		col_path = str(root.get_path_to(body))

	# Optional save mesh
	var save_path: String = optional_string(params, "save_mesh_path", "")
	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			save_path = "res://" + save_path.trim_prefix("/")
		ensure_parent_dir(save_path)
		ResourceSaver.save(mesh, save_path)
		EditorInterface.get_resource_filesystem().update_file(save_path)

	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(mi)),
		"collision": col_path,
		"resolution": {"x": res_x, "z": res_z},
		"size": {"x": size_x, "z": size_z},
		"mesh_path": save_path,
	})


func _vert(x: int, z: int, res_x: int, res_z: int, size_x: float, size_z: float, h: float) -> Vector3:
	var px := (float(x) / float(res_x - 1) - 0.5) * size_x
	var pz := (float(z) / float(res_z - 1) - 0.5) * size_z
	return Vector3(px, h, pz)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x, a.z))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x, b.z))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x, c.z))
	st.add_vertex(c)


func _hash_noise(x: float, z: float, seed_v: int) -> float:
	# Value noise via hash of grid corners + bilinear
	var x0 := floori(x)
	var z0 := floori(z)
	var fx := x - float(x0)
	var fz := z - float(z0)
	var v00 := _hash2(x0, z0, seed_v)
	var v10 := _hash2(x0 + 1, z0, seed_v)
	var v01 := _hash2(x0, z0 + 1, seed_v)
	var v11 := _hash2(x0 + 1, z0 + 1, seed_v)
	var ix0 := lerpf(v00, v10, fx)
	var ix1 := lerpf(v01, v11, fx)
	return lerpf(ix0, ix1, fz)


func _hash2(x: int, z: int, seed_v: int) -> float:
	var n := x * 374761393 + z * 668265263 + seed_v * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return (float(n & 0x7fffffff) / float(0x7fffffff)) * 2.0 - 1.0


func _terrain_apply_height_noise(params: Dictionary) -> Dictionary:
	## Rebuild heightmap terrain on existing MeshInstance3D path by regenerating mesh.
	params = params.duplicate()
	if not params.has("name"):
		var r0 := require_string(params, "node_path")
		if r0[1] != null:
			return r0[1]
		var node := find_node_by_path(r0[0])
		if node:
			params["parent_path"] = str(get_edited_root().get_path_to(node.get_parent())) if node.get_parent() else "."
			# Remove old and recreate under same parent
			var parent_path := params["parent_path"]
			node.queue_free()
			params["parent_path"] = parent_path
	return _create_heightmap_terrain(params)
