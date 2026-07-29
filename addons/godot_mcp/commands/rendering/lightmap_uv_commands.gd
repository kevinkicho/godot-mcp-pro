@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## UV2 lightmap unwrap + batch bake prep (human Mesh -> UV2 for LightmapGI).


func get_commands() -> Dictionary:
	return {
		"mesh_lightmap_unwrap": _mesh_lightmap_unwrap,
		"mesh_has_uv2": _mesh_has_uv2,
		"batch_prepare_lightmap_meshes": _batch_prepare_lightmap_meshes,
		"lightmap_bake_prepare": _lightmap_bake_prepare,
		"list_lightmap_uv_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"flow": [
			"mesh_has_uv2 on level meshes",
			"mesh_lightmap_unwrap or batch_prepare_lightmap_meshes",
			"lightmap_bake_prepare (gi_mode + LightmapGI)",
			"request_lightmap_bake",
		],
		"related": ["set_mesh_lightmap_params", "add_lightmap_gi", "request_lightmap_bake", "configure_sdfgi"],
	})


func _mi(path: String) -> MeshInstance3D:
	var n := find_node_by_path(path)
	if n is MeshInstance3D:
		return n as MeshInstance3D
	return null


func _to_array_mesh(mesh: Mesh) -> ArrayMesh:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).duplicate(true) as ArrayMesh
	var am := ArrayMesh.new()
	for i in range(mesh.get_surface_count()):
		var st := SurfaceTool.new()
		st.create_from(mesh, i)
		st.commit(am)
	return am


func _surface_has_uv2(mesh: Mesh, surf: int) -> bool:
	if mesh == null or surf < 0 or surf >= mesh.get_surface_count():
		return false
	if mesh is ArrayMesh:
		var am := mesh as ArrayMesh
		var fmt: int = am.surface_get_format(surf)
		# ARRAY_FORMAT_TEX_UV2 bit
		if (fmt & Mesh.ARRAY_FORMAT_TEX_UV2) != 0:
			return true
	var arrays := mesh.surface_get_arrays(surf)
	if arrays is Array and arrays.size() > Mesh.ARRAY_TEX_UV2:
		var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
		return uv2 != null and uv2.size() > 0
	return false


func _mesh_has_uv2(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null:
		return error_not_found("MeshInstance3D")
	if mi.mesh == null:
		return success({"node_path": r0[0], "has_mesh": false, "has_uv2": false})
	var per_surface: Array = []
	var any := false
	for i in range(mi.mesh.get_surface_count()):
		var has := _surface_has_uv2(mi.mesh, i)
		any = any or has
		per_surface.append({"surface": i, "has_uv2": has})
	return success({
		"node_path": r0[0],
		"has_mesh": true,
		"has_uv2": any,
		"surfaces": per_surface,
		"mesh_class": mi.mesh.get_class(),
		"gi_mode": mi.gi_mode,
	})


func _mesh_lightmap_unwrap(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mi := _mi(r0[0])
	if mi == null or mi.mesh == null:
		return error_not_found("MeshInstance3D with mesh")
	var texel: float = float(params.get("texel_size", 0.2))
	var save_path: String = optional_string(params, "save_path", "")
	var set_gi_static: bool = optional_bool(params, "set_gi_static", true)

	var am := _to_array_mesh(mi.mesh)
	var err: Error = FAILED
	var method := ""
	if am.has_method("lightmap_unwrap"):
		err = am.lightmap_unwrap(mi.global_transform, texel)
		method = "ArrayMesh.lightmap_unwrap"
	elif mi.has_method("lightmap_unwrap"):
		mi.call("lightmap_unwrap", mi.global_transform, texel)
		err = OK
		method = "MeshInstance3D.lightmap_unwrap"
		am = mi.mesh as ArrayMesh if mi.mesh is ArrayMesh else am
	else:
		return error_internal("lightmap_unwrap not available on this mesh type - convert to ArrayMesh first")

	if err != OK and method == "ArrayMesh.lightmap_unwrap":
		return error_internal("lightmap_unwrap failed: %s (mesh may need indices/unique verts)" % error_string(err))

	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			save_path = "res://" + save_path.trim_prefix("/")
		var derr := ensure_parent_dir(save_path)
		if not derr.is_empty():
			return derr
		var serr := ResourceSaver.save(am, save_path)
		if serr != OK:
			return error_internal("Save failed: %s" % error_string(serr))
		am = load(save_path) as ArrayMesh

	mi.mesh = am
	if set_gi_static:
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	if params.has("lightmap_scale") and "lightmap_scale" in mi:
		mi.set("lightmap_scale", int(params["lightmap_scale"]))

	var has_uv2 := false
	for i in range(am.get_surface_count()):
		if _surface_has_uv2(am, i):
			has_uv2 = true
			break

	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"method": method,
		"texel_size": texel,
		"has_uv2": has_uv2,
		"gi_mode": mi.gi_mode,
		"save_path": save_path,
		"error_code": err,
	})


func _batch_prepare_lightmap_meshes(params: Dictionary) -> Dictionary:
	## Walk scene (or subtree), unwrap UV2 + set gi_mode static on MeshInstance3Ds.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start_path: String = optional_string(params, "node_path", ".")
	var start := find_node_by_path(start_path)
	if start == null:
		start = root
	var texel: float = float(params.get("texel_size", 0.2))
	var only_missing: bool = optional_bool(params, "only_missing_uv2", true)
	var max_n: int = clampi(optional_int(params, "max", 50), 1, 200)
	var results: Array = []
	var meshes: Array = []
	_collect_mi(start, meshes)
	var count := 0
	for mi in meshes:
		if count >= max_n:
			break
		if not mi is MeshInstance3D or (mi as MeshInstance3D).mesh == null:
			continue
		var m := mi as MeshInstance3D
		var already := false
		for s in range(m.mesh.get_surface_count()):
			if _surface_has_uv2(m.mesh, s):
				already = true
				break
		if only_missing and already:
			results.append({
				"path": str(root.get_path_to(m)),
				"skipped": true,
				"reason": "already has UV2",
			})
			continue
		var one := _mesh_lightmap_unwrap({
			"node_path": str(root.get_path_to(m)),
			"texel_size": texel,
			"set_gi_static": optional_bool(params, "set_gi_static", true),
		})
		var payload = one.get("result", one)
		results.append(payload if payload is Dictionary else {"raw": one})
		count += 1
	return success({
		"processed": count,
		"results": results,
		"mesh_instances_found": meshes.size(),
		"texel_size": texel,
	})


func _collect_mi(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_mi(c, out)


func _lightmap_bake_prepare(params: Dictionary) -> Dictionary:
	## One-shot: batch UV2 + ensure LightmapGI + optional bake request.
	var batch := _batch_prepare_lightmap_meshes(params)
	var batch_data = batch.get("result", batch)
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var gi_path := ""
	var gi: LightmapGI = _find_lightmap(root)
	if gi == null and optional_bool(params, "add_lightmap_gi", true):
		gi = LightmapGI.new()
		gi.name = optional_string(params, "name", "LightmapGI")
		var parent := find_node_by_path(optional_string(params, "parent_path", "."))
		if parent == null:
			parent = root
		add_child_with_undo(parent, gi, root, "MCP: Add LightmapGI")
		gi_path = str(root.get_path_to(gi))
	elif gi:
		gi_path = str(root.get_path_to(gi))

	var bake_result = null
	if optional_bool(params, "request_bake", false) and gi:
		if gi.has_method("bake"):
			gi.call("bake")
			bake_result = {"baked": true, "via": "bake()"}
		else:
			bake_result = {
				"baked": false,
				"message": "Call request_lightmap_bake or use editor Bake Lightmaps",
			}

	mark_current_scene_unsaved()
	return success({
		"prepare": batch_data,
		"lightmap_gi": gi_path,
		"bake": bake_result,
		"next": ["request_lightmap_bake", "playtest_report", "get_render_info"],
	})


func _find_lightmap(n: Node) -> LightmapGI:
	if n is LightmapGI:
		return n as LightmapGI
	for c in n.get_children():
		var f := _find_lightmap(c)
		if f:
			return f
	return null
