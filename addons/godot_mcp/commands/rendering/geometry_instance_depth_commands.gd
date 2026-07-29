@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## GeometryInstance3D depth - shadows, GI, overlays, visibility, layers (critical 3D mesh map).


func get_commands() -> Dictionary:
	return {
		"set_geometry_instance_params": _set_gi_params,
		"batch_set_geometry_instance_params": _batch,
		"set_material_overlay": _set_overlay,
		"set_material_overlay_color": _overlay_color,
		"set_cast_shadows": _set_shadows,
		"set_gi_mode": _set_gi_mode,
		"set_geometry_render_layers": _set_layers,
		"list_geometry_instance_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"set_visibility_range", "mesh_generate_lods", "set_mesh_lightmap_params",
		"assign_material_3d_to_mesh", "apply_avatar_material_pack",
	])


func _as_gi(path: String) -> GeometryInstance3D:
	var n := find_node_by_path(path)
	return n as GeometryInstance3D if n is GeometryInstance3D else null


func _parse_shadow(v: Variant) -> int:
	if v is int:
		return int(v)
	match str(v).to_lower():
		"off", "disabled", "0":
			return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"on", "1", "enabled":
			return GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		"double_sided", "2":
			return GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		"shadows_only", "3":
			return GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_:
			return GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _parse_gi(v: Variant) -> int:
	if v is int:
		return int(v)
	match str(v).to_lower():
		"disabled", "off", "0":
			return GeometryInstance3D.GI_MODE_DISABLED
		"static", "1":
			return GeometryInstance3D.GI_MODE_STATIC
		"dynamic", "2":
			return GeometryInstance3D.GI_MODE_DYNAMIC
		_:
			return GeometryInstance3D.GI_MODE_STATIC


func _set_gi_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gi := _as_gi(r0[0])
	if gi == null:
		return error_not_found("GeometryInstance3D (MeshInstance3D etc.)")
	var applied := {}
	if params.has("cast_shadow") or params.has("cast_shadows"):
		gi.cast_shadow = _parse_shadow(params.get("cast_shadow", params.get("cast_shadows"))) as GeometryInstance3D.ShadowCastingSetting
		applied["cast_shadow"] = gi.cast_shadow
	if params.has("gi_mode"):
		gi.gi_mode = _parse_gi(params["gi_mode"]) as GeometryInstance3D.GIMode
		applied["gi_mode"] = gi.gi_mode
	if params.has("transparency"):
		gi.transparency = float(params["transparency"])
		applied["transparency"] = gi.transparency
	if params.has("extra_cull_margin"):
		gi.extra_cull_margin = float(params["extra_cull_margin"])
		applied["extra_cull_margin"] = gi.extra_cull_margin
	if params.has("ignore_occlusion_culling") and "ignore_occlusion_culling" in gi:
		gi.set("ignore_occlusion_culling", bool(params["ignore_occlusion_culling"]))
		applied["ignore_occlusion_culling"] = true
	if params.has("material_overlay") and params["material_overlay"] is String:
		var mp := str(params["material_overlay"])
		if not mp.begins_with("res://"):
			mp = "res://" + mp.trim_prefix("/")
		if ResourceLoader.exists(mp):
			gi.material_overlay = load(mp)
			applied["material_overlay"] = mp
	if params.has("material_overlay") and params["material_overlay"] == null:
		gi.material_overlay = null
		applied["material_overlay"] = null
	if params.has("layers"):
		gi.layers = int(params["layers"])
		applied["layers"] = gi.layers
	if params.has("visibility_range_begin"):
		gi.visibility_range_begin = float(params["visibility_range_begin"])
		applied["visibility_range_begin"] = gi.visibility_range_begin
	if params.has("visibility_range_end"):
		gi.visibility_range_end = float(params["visibility_range_end"])
		applied["visibility_range_end"] = gi.visibility_range_end
	if applied.is_empty():
		return error_invalid_params("Provide cast_shadow, gi_mode, material_overlay, layers, visibility_range_*, transparency, extra_cull_margin")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _batch(params: Dictionary) -> Dictionary:
	## node_paths[] + shared params, or items:[{node_path,...}]
	var results: Array = []
	if params.has("items") and params["items"] is Array:
		for item in params["items"]:
			if item is Dictionary:
				results.append(_set_gi_params(item))
	elif params.has("node_paths") and params["node_paths"] is Array:
		for p in params["node_paths"]:
			var sub := params.duplicate()
			sub.erase("node_paths")
			sub["node_path"] = str(p)
			results.append(_set_gi_params(sub))
	else:
		return error_invalid_params("items[] or node_paths[] required")
	var ok := 0
	for r in results:
		if r is Dictionary and not r.has("error"):
			ok += 1
	return success({"results": results, "ok_count": ok})


func _set_overlay(params: Dictionary) -> Dictionary:
	var p := params.duplicate()
	if params.has("material_path"):
		p["material_overlay"] = params["material_path"]
	return _set_gi_params(p)


func _overlay_color(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var gi := _as_gi(r0[0])
	if gi == null:
		return error_not_found("GeometryInstance3D")
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c := Color(1, 0, 0, 0.35)
	if params.has("color"):
		var v = params["color"]
		if v is String:
			c = Color.html(v) if str(v).begins_with("#") else Color(str(v))
		elif v is Dictionary:
			c = Color(float(v.get("r", 1)), float(v.get("g", 0)), float(v.get("b", 0)), float(v.get("a", 0.35)))
	mat.albedo_color = c
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gi.material_overlay = mat
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "overlay_color": c.to_html(true)})


func _set_shadows(params: Dictionary) -> Dictionary:
	var p := params.duplicate()
	p["cast_shadow"] = params.get("mode", params.get("cast_shadow", "on"))
	return _set_gi_params(p)


func _set_gi_mode(params: Dictionary) -> Dictionary:
	var p := params.duplicate()
	if not p.has("gi_mode"):
		p["gi_mode"] = params.get("mode", "static")
	return _set_gi_params(p)


func _set_layers(params: Dictionary) -> Dictionary:
	var p := params.duplicate()
	if params.has("layer_bits"):
		p["layers"] = int(params["layer_bits"])
	elif params.has("layers") and params["layers"] is Array:
		var bits := 0
		for L in params["layers"]:
			var li := int(L)
			if li >= 1 and li <= 20:
				bits |= (1 << (li - 1))
		p["layers"] = bits
	return _set_gi_params(p)
