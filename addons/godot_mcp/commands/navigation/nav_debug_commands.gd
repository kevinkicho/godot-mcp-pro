@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Navigation path queries + debug overlays (human Navigation debug draw).


func get_commands() -> Dictionary:
	return {
		"navigation_set_debug_enabled": _navigation_set_debug_enabled,
		"navigation_get_debug_settings": _navigation_get_debug_settings,
		"navigation_query_path": _navigation_query_path,
		"draw_debug_path": _draw_debug_path,
		"navigation_get_map_info": _navigation_get_map_info,
		"navigation_live_path": _navigation_live_path,
		"list_nav_debug_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"flow": [
			"bake_navigation_mesh",
			"navigation_set_debug_enabled true",
			"navigation_live_path from=... to=... (query + draw while playing)",
			"OR navigation_query_path + draw_debug_path",
		],
		"related": ["setup_navigation_region", "bake_navigation_mesh", "setup_navigation_agent", "pipeline_nav_debug_route"],
	})


func _navigation_set_debug_enabled(params: Dictionary) -> Dictionary:
	var enabled: bool = optional_bool(params, "enabled", true)
	# Project settings used by editor/game navigation debug
	var keys := [
		"debug/shapes/navigation/enable_edge_lines",
		"debug/shapes/navigation/enable_edge_lines_xray",
		"debug/shapes/navigation/enable_edge_connections",
		"debug/shapes/navigation/enable_edge_connections_xray",
		"debug/shapes/navigation/enable_geometry_face_random_color",
	]
	# Master toggle varies by version
	if ProjectSettings.has_setting("debug/shapes/navigation/enable_navigation_debug"):
		ProjectSettings.set_setting("debug/shapes/navigation/enable_navigation_debug", enabled)
	# Godot 4 often uses visible_collision_shapes style - also try NavigationServer
	if enabled:
		for k in keys:
			if ProjectSettings.has_setting(k):
				ProjectSettings.set_setting(k, true)
	else:
		for k in keys:
			if ProjectSettings.has_setting(k):
				ProjectSettings.set_setting(k, false)

	# Runtime server debug (when playing / in editor)
	if ClassDB.class_exists("NavigationServer3D"):
		if NavigationServer3D.has_method("set_debug_enabled"):
			NavigationServer3D.set_debug_enabled(enabled)
	if ClassDB.class_exists("NavigationServer2D"):
		if NavigationServer2D.has_method("set_debug_enabled"):
			NavigationServer2D.set_debug_enabled(enabled)

	# Viewport debug draw mode for game/editor
	if params.has("viewport_debug_draw"):
		var mode_str: String = str(params["viewport_debug_draw"]).to_lower()
		var vp := EditorInterface.get_editor_viewport_3d(0) if EditorInterface.has_method("get_editor_viewport_3d") else null
		if vp and "debug_draw" in vp:
			match mode_str:
				"disabled", "off":
					vp.set("debug_draw", Viewport.DEBUG_DRAW_DISABLED)
				"wireframe":
					vp.set("debug_draw", Viewport.DEBUG_DRAW_WIREFRAME)
				"overdraw":
					vp.set("debug_draw", Viewport.DEBUG_DRAW_OVERDRAW)
				_:
					pass

	ProjectSettings.save()
	return success({
		"enabled": enabled,
		"navigation_server_3d_debug": NavigationServer3D.get_debug_enabled() if NavigationServer3D.has_method("get_debug_enabled") else null,
		"hint": "Visible in running game when collision/navigation debug is on; editor may need play",
	})


func _navigation_get_debug_settings(_params: Dictionary) -> Dictionary:
	var settings := {}
	for k in [
		"debug/shapes/navigation/enable_navigation_debug",
		"debug/shapes/navigation/enable_edge_lines",
		"debug/shapes/navigation/enable_edge_connections",
		"debug/shapes/navigation/enable_geometry_face_random_color",
		"debug/shapes/collision/shape_color",
	]:
		if ProjectSettings.has_setting(k):
			settings[k] = ProjectSettings.get_setting(k)
	return success({
		"settings": settings,
		"server_3d_debug": NavigationServer3D.get_debug_enabled() if NavigationServer3D.has_method("get_debug_enabled") else null,
	})


func _parse_vec3(v: Variant, default: Vector3 = Vector3.ZERO) -> Vector3:
	if v is Dictionary:
		return Vector3(float(v.get("x", 0)), float(v.get("y", 0)), float(v.get("z", 0)))
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	if v is Vector3:
		return v
	return default


func _parse_vec2(v: Variant, default: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return default


func _navigation_query_path(params: Dictionary) -> Dictionary:
	## Query NavigationServer path between two points (3D default, mode=2d optional).
	var mode: String = optional_string(params, "mode", "3d").to_lower()
	var optimize: bool = optional_bool(params, "optimize", true)

	if mode == "2d":
		if not params.has("from") or not params.has("to"):
			return error_invalid_params("from and to required (Vector2 or {x,y})")
		var from2 := _parse_vec2(params["from"])
		var to2 := _parse_vec2(params["to"])
		var map_rid: RID
		if params.has("map_rid"):
			# can't pass RID easily - use world maps
			pass
		var world_2d = EditorInterface.get_edited_scene_root().get_world_2d() if get_edited_root() else null
		if world_2d == null and get_edited_root() and get_edited_root().is_inside_tree():
			world_2d = get_edited_root().get_world_2d()
		# Prefer playing game for accurate baked maps
		if EditorInterface.is_playing_scene():
			var pr: Dictionary = await send_game_command("navigation_query_path", {
				"mode": "2d",
				"from": {"x": from2.x, "y": from2.y},
				"to": {"x": to2.x, "y": to2.y},
				"optimize": optimize,
			}, 5.0)
			if pr.has("result"):
				return success(pr["result"] if pr["result"] is Dictionary else {"path": pr["result"]})
		# Editor-side: use NavigationServer2D default map if available
		var maps: Array = NavigationServer2D.get_maps() if NavigationServer2D.has_method("get_maps") else []
		if maps.is_empty():
			return error_internal("No NavigationServer2D maps - bake NavigationRegion2D and play scene for accurate paths")
		map_rid = maps[0]
		var path2: PackedVector2Array = NavigationServer2D.map_get_path(map_rid, from2, to2, optimize)
		var pts: Array = []
		for p in path2:
			pts.append({"x": p.x, "y": p.y})
		return success({"mode": "2d", "points": pts, "count": pts.size(), "map_count": maps.size()})

	# 3D
	if not params.has("from") or not params.has("to"):
		return error_invalid_params("from and to required (Vector3 or {x,y,z})")
	var from3 := _parse_vec3(params["from"])
	var to3 := _parse_vec3(params["to"])

	if EditorInterface.is_playing_scene():
		var pr3: Dictionary = await send_game_command("navigation_query_path", {
			"mode": "3d",
			"from": {"x": from3.x, "y": from3.y, "z": from3.z},
			"to": {"x": to3.x, "y": to3.y, "z": to3.z},
			"optimize": optimize,
		}, 5.0)
		if pr3.has("result"):
			return success(pr3["result"] if pr3["result"] is Dictionary else {"path": pr3["result"]})

	var maps3: Array = NavigationServer3D.get_maps() if NavigationServer3D.has_method("get_maps") else []
	if maps3.is_empty():
		return error_internal("No NavigationServer3D maps in editor - bake region and prefer play session for queries")
	var map3: RID = maps3[0]
	var path3: PackedVector3Array = NavigationServer3D.map_get_path(map3, from3, to3, optimize)
	var pts3: Array = []
	for p in path3:
		pts3.append({"x": p.x, "y": p.y, "z": p.z})
	return success({
		"mode": "3d",
		"points": pts3,
		"count": pts3.size(),
		"map_count": maps3.size(),
		"from": {"x": from3.x, "y": from3.y, "z": from3.z},
		"to": {"x": to3.x, "y": to3.y, "z": to3.z},
	})


func _draw_debug_path(params: Dictionary) -> Dictionary:
	## Create Path3D/Path2D or MeshInstance line for visualizing a path in the edited scene.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var mode: String = optional_string(params, "mode", "3d").to_lower()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		parent = root
	var points_in: Array = params.get("points", [])
	if points_in.is_empty():
		return error_invalid_params("points array required")

	if mode == "2d":
		var path2 := Path2D.new()
		path2.name = optional_string(params, "name", "DebugPath2D")
		var curve := Curve2D.new()
		for p in points_in:
			curve.add_point(_parse_vec2(p))
		path2.curve = curve
		add_child_with_undo(parent, path2, root, "MCP: Debug Path2D")
		# Optional Line2D visual
		if optional_bool(params, "add_line", true):
			var line := Line2D.new()
			line.name = "DebugLine2D"
			line.width = float(params.get("width", 2.0))
			for p in points_in:
				line.add_point(_parse_vec2(p))
			add_child_with_undo(path2, line, root, "MCP: Debug Line2D")
		mark_current_scene_unsaved()
		return success({"path": str(root.get_path_to(path2)), "point_count": points_in.size(), "mode": "2d"})

	var path3 := Path3D.new()
	path3.name = optional_string(params, "name", "DebugPath3D")
	var curve3 := Curve3D.new()
	for p in points_in:
		curve3.add_point(_parse_vec3(p))
	path3.curve = curve3
	add_child_with_undo(parent, path3, root, "MCP: Debug Path3D")

	# Mesh line via ImmediateMesh / ArrayMesh ribbon
	if optional_bool(params, "add_mesh_line", true):
		var mi := MeshInstance3D.new()
		mi.name = "DebugPathMesh"
		var am := ArrayMesh.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINE_STRIP)
		var col := Color(1, 0.2, 0.2, 1)
		if params.has("color") and params["color"] is Dictionary:
			var c: Dictionary = params["color"]
			col = Color(float(c.get("r", 1)), float(c.get("g", 0.2)), float(c.get("b", 0.2)), float(c.get("a", 1)))
		for p in points_in:
			var v := _parse_vec3(p)
			st.set_color(col)
			st.add_vertex(v)
		st.commit(am)
		mi.mesh = am
		# Unshaded material
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		mat.vertex_color_use_as_albedo = true
		mi.material_override = mat
		add_child_with_undo(path3, mi, root, "MCP: Debug path mesh")

	mark_current_scene_unsaved()
	return success({
		"path": str(root.get_path_to(path3)),
		"point_count": points_in.size(),
		"mode": "3d",
		"baked_length": curve3.get_baked_length(),
	})


func _navigation_live_path(params: Dictionary) -> Dictionary:
	## One-shot: enable debug (optional), query path (prefers play session), draw debug path in scene.
	if not params.has("from") or not params.has("to"):
		return error_invalid_params("from and to required")
	var enable_debug: bool = optional_bool(params, "enable_debug", true)
	if enable_debug:
		_navigation_set_debug_enabled({"enabled": true})

	# Prefer playing for accurate maps
	var was_playing := EditorInterface.is_playing_scene()
	var started_play := false
	if not was_playing and optional_bool(params, "auto_play", true):
		var mode: String = optional_string(params, "play_mode", "main")
		match mode:
			"current":
				EditorInterface.play_current_scene()
			"custom":
				var p: String = optional_string(params, "path", "")
				if not p.is_empty():
					if not p.begins_with("res://"):
						p = "res://" + p.trim_prefix("/")
					EditorInterface.play_custom_scene(p)
			_:
				EditorInterface.play_main_scene()
		started_play = true
		var attempts := 40
		while attempts > 0 and not EditorInterface.is_playing_scene():
			await get_tree().create_timer(0.1).timeout
			attempts -= 1
		await get_tree().create_timer(float(params.get("settle_sec", 0.8))).timeout

	var q := await _navigation_query_path(params)
	var qdata = q.get("result", q)
	if qdata is Dictionary and qdata.has("error") and not qdata.has("points"):
		if started_play and optional_bool(params, "stop_after", true):
			EditorInterface.stop_playing_scene()
		return q

	var points: Array = []
	if qdata is Dictionary and qdata.has("points"):
		points = qdata["points"]
	elif qdata is Dictionary and qdata.has("result") and qdata["result"] is Dictionary:
		points = qdata["result"].get("points", [])

	var draw_res = null
	if points.size() >= 2 and optional_bool(params, "draw", true):
		draw_res = _draw_debug_path({
			"mode": optional_string(params, "mode", "3d"),
			"points": points,
			"parent_path": optional_string(params, "parent_path", "."),
			"name": optional_string(params, "name", "LiveNavPath"),
			"add_mesh_line": true,
		})

	if started_play and optional_bool(params, "stop_after", true) and EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()

	return success({
		"points": points,
		"count": points.size(),
		"query": qdata,
		"draw": draw_res.get("result", draw_res) if draw_res is Dictionary else draw_res,
		"played": started_play,
		"stopped": started_play and optional_bool(params, "stop_after", true),
	})


func _navigation_get_map_info(params: Dictionary) -> Dictionary:
	var mode: String = optional_string(params, "mode", "3d").to_lower()
	if mode == "2d":
		var maps2: Array = NavigationServer2D.get_maps() if NavigationServer2D.has_method("get_maps") else []
		return success({"mode": "2d", "map_count": maps2.size()})
	var maps3: Array = NavigationServer3D.get_maps() if NavigationServer3D.has_method("get_maps") else []
	var regions := 0
	var info_maps: Array = []
	for m in maps3:
		var entry := {"valid": m.is_valid() if m is RID else true}
		if NavigationServer3D.has_method("map_get_regions"):
			var regs = NavigationServer3D.map_get_regions(m)
			entry["region_count"] = regs.size() if regs is Array else 0
			regions += int(entry["region_count"])
		if NavigationServer3D.has_method("map_get_agents"):
			var agents = NavigationServer3D.map_get_agents(m)
			entry["agent_count"] = agents.size() if agents is Array else 0
		info_maps.append(entry)
	# Also scan edited scene for regions
	var root := get_edited_root()
	var scene_regions: Array = []
	if root:
		_collect_nav_regions(root, root, scene_regions)
	return success({
		"mode": "3d",
		"map_count": maps3.size(),
		"maps": info_maps,
		"total_regions_server": regions,
		"scene_regions": scene_regions,
		"playing": EditorInterface.is_playing_scene(),
	})


func _collect_nav_regions(n: Node, root: Node, out: Array) -> void:
	if n is NavigationRegion3D:
		var r := n as NavigationRegion3D
		out.append({
			"path": str(root.get_path_to(n)),
			"type": "NavigationRegion3D",
			"enabled": r.enabled if "enabled" in r else true,
			"has_mesh": r.navigation_mesh != null,
		})
	elif n is NavigationRegion2D:
		var r2 := n as NavigationRegion2D
		out.append({
			"path": str(root.get_path_to(n)),
			"type": "NavigationRegion2D",
			"has_poly": r2.navigation_polygon != null,
		})
	for c in n.get_children():
		_collect_nav_regions(c, root, out)
