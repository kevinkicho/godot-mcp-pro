@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Mesh LOD generation + GeometryInstance visibility ranges (human Mesh/LOD workflow).


func get_commands() -> Dictionary:
	return {
		"mesh_generate_lods": _mesh_generate_lods,
		"mesh_get_lod_info": _mesh_get_lod_info,
		"set_visibility_range": _set_visibility_range,
		"setup_lod_mesh_instances": _setup_lod_mesh_instances,
		"create_shadow_mesh": _create_shadow_mesh,
		"list_lod_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"human": "Import generate LODs + GeometryInstance visibility ranges + shadow mesh",
		"flow": [
			"mesh_generate_lods on MeshInstance3D (ImporterMesh path)",
			"set_visibility_range for distance culling",
			"setup_lod_mesh_instances for discrete LOD0/1/2 nodes",
			"create_shadow_mesh for cheaper shadow pass",
		],
	})


func _mi(path: String) -> MeshInstance3D:
	var n := find_node_by_path(path)
	if n is MeshInstance3D:
		return n as MeshInstance3D
	return null


func _to_array_mesh(mesh: Mesh) -> ArrayMesh:
	if mesh is ArrayMesh:
		return mesh as ArrayMesh
	# Convert PrimitiveMesh / other Mesh via SurfaceTool
	var am := ArrayMesh.new()
	var sc := mesh.get_surface_count()
	for i in range(sc):
		var st := SurfaceTool.new()
		st.create_from(mesh, i)
		st.commit(am)
	return am


func _mesh_generate_lods(params: Dictionary) -> Dictionary:
	## Generate geometric LODs (Godot ImporterMesh pipeline) and assign ArrayMesh.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null or mi.mesh == null:
		return error_not_found("MeshInstance3D with mesh")
	var root := get_edited_root()
	var normal_merge: float = float(params.get("normal_merge_angle", 25.0))
	var normal_split: float = float(params.get("normal_split_angle", 60.0))
	var save_path: String = optional_string(params, "save_path", "")

	var source := _to_array_mesh(mi.mesh)
	var method_used := ""
	var new_mesh: ArrayMesh = null

	# Preferred: ImporterMesh.generate_lods (engine meshoptimizer path)
	if ClassDB.class_exists("ImporterMesh"):
		var importer = ClassDB.instantiate("ImporterMesh")
		if importer:
			for s in range(source.get_surface_count()):
				var arrays := source.surface_get_arrays(s)
				var prim = source.surface_get_primitive_type(s)
				var mat := source.surface_get_material(s)
				if importer.has_method("add_surface"):
					# add_surface(primitive, arrays, blend_shapes, lods, material, name, flags)
					importer.call("add_surface", prim, arrays, [], {}, mat, "surface_%d" % s, 0)
			if importer.has_method("generate_lods"):
				importer.call("generate_lods", normal_merge, normal_split, [])
				method_used = "ImporterMesh.generate_lods"
				if importer.has_method("get_mesh"):
					new_mesh = importer.call("get_mesh")
			elif importer.has_method("generate_lods") == false:
				pass

	# Fallback: keep ArrayMesh; document that discrete LODs via setup_lod_mesh_instances
	if new_mesh == null:
		# Try Mesh method if present in this Godot build
		if source.has_method("generate_lods"):
			source.call("generate_lods", normal_merge, normal_split, [])
			new_mesh = source
			method_used = "ArrayMesh.generate_lods"
		else:
			new_mesh = source
			method_used = "passthrough — use setup_lod_mesh_instances for discrete LODs; ImporterMesh unavailable or failed"

	if optional_bool(params, "duplicate_resource", true) and new_mesh:
		new_mesh = new_mesh.duplicate(true) as ArrayMesh

	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			save_path = "res://" + save_path.trim_prefix("/")
		var derr := ensure_parent_dir(save_path)
		if not derr.is_empty():
			return derr
		var err := ResourceSaver.save(new_mesh, save_path)
		if err != OK:
			return error_internal("Failed to save mesh: %s" % error_string(err))
		new_mesh = load(save_path) as ArrayMesh

	mi.mesh = new_mesh
	mark_current_scene_unsaved()
	var info := _lod_info_from_mesh(new_mesh)
	return success({
		"node_path": r0[0],
		"method": method_used,
		"save_path": save_path,
		"mesh_info": info,
		"hint": "Engine LODs auto-pick by screen size; pair with set_visibility_range if needed",
	})


func _mesh_get_lod_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	var info := _lod_info_from_mesh(mi.mesh)
	info["node_path"] = r0[0]
	info["visibility_range_begin"] = mi.visibility_range_begin if "visibility_range_begin" in mi else null
	info["visibility_range_end"] = mi.visibility_range_end if "visibility_range_end" in mi else null
	return success(info)


func _lod_info_from_mesh(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {"has_mesh": false}
	var surfaces: Array = []
	var total_verts := 0
	for i in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(i)
		var vcount := 0
		var icount := 0
		if arrays is Array and arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			vcount = arrays[Mesh.ARRAY_VERTEX].size()
		if arrays is Array and arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			icount = arrays[Mesh.ARRAY_INDEX].size()
		total_verts += vcount
		var lod_keys: Array = []
		# Surface LODs via RenderingServer if available
		if mesh is ArrayMesh:
			var am := mesh as ArrayMesh
			# Godot stores LODs internally; expose array lens
			surfaces.append({
				"index": i,
				"name": am.surface_get_name(i) if am.has_method("surface_get_name") else "",
				"vertex_count": vcount,
				"index_count": icount,
				"format": am.surface_get_format(i) if am.has_method("surface_get_format") else 0,
				"primitive": am.surface_get_primitive_type(i) if am.has_method("surface_get_primitive_type") else 0,
			})
		else:
			surfaces.append({"index": i, "vertex_count": vcount, "index_count": icount})
	return {
		"has_mesh": true,
		"mesh_class": mesh.get_class(),
		"surface_count": mesh.get_surface_count(),
		"total_vertices_estimate": total_verts,
		"surfaces": surfaces,
		"resource_path": mesh.resource_path,
	}


func _set_visibility_range(params: Dictionary) -> Dictionary:
	## GeometryInstance3D visibility ranges — discrete distance LOD / culling.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is GeometryInstance3D):
		return error_not_found("GeometryInstance3D")
	var gi := node as GeometryInstance3D
	var applied := {}
	if params.has("begin") or params.has("visibility_range_begin"):
		gi.visibility_range_begin = float(params.get("begin", params.get("visibility_range_begin", 0.0)))
		applied["begin"] = gi.visibility_range_begin
	if params.has("end") or params.has("visibility_range_end"):
		gi.visibility_range_end = float(params.get("end", params.get("visibility_range_end", 0.0)))
		applied["end"] = gi.visibility_range_end
	if params.has("begin_margin") or params.has("visibility_range_begin_margin"):
		gi.visibility_range_begin_margin = float(params.get("begin_margin", params.get("visibility_range_begin_margin", 0.0)))
		applied["begin_margin"] = gi.visibility_range_begin_margin
	if params.has("end_margin") or params.has("visibility_range_end_margin"):
		gi.visibility_range_end_margin = float(params.get("end_margin", params.get("visibility_range_end_margin", 0.0)))
		applied["end_margin"] = gi.visibility_range_end_margin
	if params.has("fade_mode") or params.has("visibility_range_fade_mode"):
		var fm = params.get("fade_mode", params.get("visibility_range_fade_mode", 0))
		if fm is String:
			match str(fm).to_lower():
				"disabled": gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				"self": gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				"dependencies": gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
		else:
			gi.visibility_range_fade_mode = int(fm) as GeometryInstance3D.VisibilityRangeFadeMode
		applied["fade_mode"] = gi.visibility_range_fade_mode
	if applied.is_empty():
		return error_invalid_params("Provide begin/end and optional margins/fade_mode")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _setup_lod_mesh_instances(params: Dictionary) -> Dictionary:
	## Create LOD0..N MeshInstance3D children with visibility ranges from mesh paths or ratios.
	## params.levels: [{mesh_path?|mesh_node?, begin, end}] or auto from source with distance bands.
	var parent_r := require_string(params, "parent_path")
	if parent_r[1] != null:
		return parent_r[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_r[0])
	if parent == null:
		return error_not_found("Parent")

	var source_path: String = optional_string(params, "source_mesh_path", "")
	var source_mi: MeshInstance3D = null
	if not source_path.is_empty():
		source_mi = _mi(source_path)

	var levels: Array = []
	if params.has("levels") and params["levels"] is Array:
		levels = params["levels"]
	else:
		# Auto bands from distances array
		var distances: Array = params.get("distances", [0.0, 15.0, 40.0, 80.0])
		if source_mi == null or source_mi.mesh == null:
			return error_invalid_params("levels[] or source_mesh_path + distances required")
		for i in range(distances.size() - 1):
			levels.append({
				"begin": float(distances[i]),
				"end": float(distances[i + 1]),
				"use_source": i == 0,
				"name": "LOD%d" % i,
			})

	var created: Array = []
	for i in range(levels.size()):
		var lv = levels[i]
		if not lv is Dictionary:
			continue
		var mi := MeshInstance3D.new()
		mi.name = str(lv.get("name", "LOD%d" % i))
		var mesh_path: String = str(lv.get("mesh_path", ""))
		if not mesh_path.is_empty():
			if ResourceLoader.exists(mesh_path):
				mi.mesh = load(mesh_path)
		elif source_mi and source_mi.mesh:
			mi.mesh = source_mi.mesh
			if source_mi is Node3D and mi is Node3D:
				mi.transform = Transform3D.IDENTITY
		if mi.mesh == null:
			mi.free()
			continue
		mi.visibility_range_begin = float(lv.get("begin", 0.0))
		mi.visibility_range_end = float(lv.get("end", 0.0))
		if lv.has("begin_margin"):
			mi.visibility_range_begin_margin = float(lv["begin_margin"])
		if lv.has("end_margin"):
			mi.visibility_range_end_margin = float(lv["end_margin"])
		# Hysteresis defaults
		if not lv.has("begin_margin"):
			mi.visibility_range_begin_margin = 1.0
		if not lv.has("end_margin"):
			mi.visibility_range_end_margin = 1.0
		add_child_with_undo(parent, mi, root, "MCP: LOD mesh instance")
		if source_mi:
			mi.global_transform = source_mi.global_transform
		created.append({
			"path": str(root.get_path_to(mi)),
			"name": mi.name,
			"begin": mi.visibility_range_begin,
			"end": mi.visibility_range_end,
		})

	if optional_bool(params, "hide_source", true) and source_mi:
		source_mi.visible = false

	mark_current_scene_unsaved()
	return success({
		"parent_path": parent_r[0],
		"lods": created,
		"count": created.size(),
		"source_hidden": optional_bool(params, "hide_source", true) and source_mi != null,
	})


func _create_shadow_mesh(params: Dictionary) -> Dictionary:
	## Assign simplified shadow_mesh on ArrayMesh (positions only when possible).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null or mi.mesh == null:
		return error_not_found("MeshInstance3D with mesh")
	var am := _to_array_mesh(mi.mesh)
	# Shadow mesh: reuse same mesh or build position-only surfaces
	var shadow := ArrayMesh.new()
	for s in range(am.get_surface_count()):
		var arrays := am.surface_get_arrays(s)
		if arrays is Array and arrays.size() > Mesh.ARRAY_VERTEX:
			var only: Array = []
			only.resize(Mesh.ARRAY_MAX)
			only[Mesh.ARRAY_VERTEX] = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_INDEX] != null:
				only[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
			shadow.add_surface_from_arrays(am.surface_get_primitive_type(s), only)
	am.shadow_mesh = shadow
	if optional_bool(params, "assign_to_instance", true):
		mi.mesh = am
	var save_path: String = optional_string(params, "save_path", "")
	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			save_path = "res://" + save_path.trim_prefix("/")
		ensure_parent_dir(save_path)
		ResourceSaver.save(am, save_path)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"shadow_mesh_surfaces": shadow.get_surface_count(),
		"save_path": save_path,
	})
