@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Godot curve surface — Curve / Curve2D / Curve3D / Path curves / Animation Bezier tracks.
## Agents operate on Cartesian control points and handles (SDK-complete numerical API).
## docs: tutorials/math (interpolation), animation tracks, Path2D/3D.


func get_commands() -> Dictionary:
	return {
		# Resource Curve (float domain)
		"create_curve_resource": _create_curve_resource,
		"curve_set_points": _curve_set_points,
		"curve_get_points": _curve_get_points,
		"curve_sample": _curve_sample,
		"curve_sample_baked": _curve_sample_baked,
		# Curve2D / Curve3D
		"create_curve2d_resource": _create_curve2d,
		"create_curve3d_resource": _create_curve3d,
		"curve2d_set_points": _curve2d_set_points,
		"curve2d_get_points": _curve2d_get_points,
		"curve2d_sample_polyline": _curve2d_sample_polyline,
		"curve3d_set_points": _curve3d_set_points,
		"curve3d_get_points": _curve3d_get_points,
		"curve3d_sample_polyline": _curve3d_sample_polyline,
		# Path nodes
		"path_get_curve_points": _path_get_curve_points,
		"path_set_curve_points": _path_set_curve_points,
		# Animation Bezier tracks (Cartesian plane: x=time, y=value)
		"bezier_list_keys_cartesian": _bezier_list_keys_cartesian,
		"bezier_set_keys_batch": _bezier_set_keys_batch,
		"bezier_sample_dense": _bezier_sample_dense,
		"bezier_remove_key": _bezier_remove_key,
		"bezier_set_handle_mode": _bezier_set_handle_mode,
		"list_curve_sdk_tools": _list_curve_sdk_tools,
	}


func _list_curve_sdk_tools(_params: Dictionary) -> Dictionary:
	return success({
		"sdk_areas": [
			"Curve / CurveTexture",
			"Curve2D / Path2D",
			"Curve3D / Path3D",
			"Animation TYPE_BEZIER tracks",
		],
		"agent_model": [
			"Control points and handles are (x,y) or (x,y,z) numbers — full fine-tune without GUI drag",
			"bezier_list_keys_cartesian exposes anchors + handle endpoints for plane mapping",
			"bezier_sample_dense / curve*_sample_polyline return dense polylines for analysis",
		],
		"tools": get_commands().keys(),
	})


# ── Curve (1D) ────────────────────────────────────────────────────────────────

func _create_curve_resource(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://curves/curve.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var curve := Curve.new()
	_apply_curve_points(curve, params.get("points", []))
	if params.has("min_value"):
		curve.min_value = float(params["min_value"])
	if params.has("max_value"):
		curve.max_value = float(params["max_value"])
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var err := ResourceSaver.save(curve, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "point_count": curve.point_count})


func _apply_curve_points(curve: Curve, points: Variant) -> void:
	if not points is Array:
		return
	curve.clear_points()
	for p in points:
		if p is Array and p.size() >= 2:
			var x := float(p[0])
			var y := float(p[1])
			var left := float(p[2]) if p.size() > 2 else 0.0
			var right := float(p[3]) if p.size() > 3 else 0.0
			curve.add_point(Vector2(x, y), left, right)
		elif p is Dictionary:
			curve.add_point(
				Vector2(float(p.get("x", p.get("offset", 0))), float(p.get("y", p.get("value", 0)))),
				float(p.get("left_tangent", p.get("left", 0))),
				float(p.get("right_tangent", p.get("right", 0)))
			)


func _load_curve(path: String) -> Curve:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Curve


func _curve_set_points(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve(r[0])
	if curve == null:
		return error_not_found(r[0])
	if not params.has("points"):
		return error_invalid_params("points required: [{x,y,left,right}|[x,y]]")
	_apply_curve_points(curve, params["points"])
	ResourceSaver.save(curve, r[0])
	return success({"path": r[0], "point_count": curve.point_count})


func _curve_get_points(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve(r[0])
	if curve == null:
		return error_not_found(r[0])
	var pts: Array = []
	for i in curve.point_count:
		var pos := curve.get_point_position(i)
		pts.append({
			"index": i,
			"x": pos.x,
			"y": pos.y,
			"left_tangent": curve.get_point_left_tangent(i),
			"right_tangent": curve.get_point_right_tangent(i),
			"left_mode": curve.get_point_left_mode(i),
			"right_mode": curve.get_point_right_mode(i),
		})
	return success({
		"path": r[0],
		"points": pts,
		"count": pts.size(),
		"min_value": curve.min_value,
		"max_value": curve.max_value,
		"domain": "x in [0,1] typically; y = curve value",
	})


func _curve_sample(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve(r[0])
	if curve == null:
		return error_not_found(r[0])
	var offset: float = float(params.get("offset", params.get("x", 0.0)))
	return success({"path": r[0], "offset": offset, "value": curve.sample(offset)})


func _curve_sample_baked(params: Dictionary) -> Dictionary:
	## Dense samples for agent analysis (Cartesian polyline of the curve).
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve(r[0])
	if curve == null:
		return error_not_found(r[0])
	var samples_n: int = clampi(optional_int(params, "samples", 32), 2, 512)
	var out: Array = []
	for i in samples_n:
		var t := float(i) / float(samples_n - 1)
		out.append({"x": t, "y": curve.sample(t)})
	return success({"path": r[0], "samples": out, "count": out.size()})


# ── Curve2D ───────────────────────────────────────────────────────────────────

func _create_curve2d(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://curves/curve2d.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var curve := Curve2D.new()
	_apply_curve2d_points(curve, params.get("points", []))
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	ResourceSaver.save(curve, path)
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "point_count": curve.point_count})


func _apply_curve2d_points(curve: Curve2D, points: Variant) -> void:
	if not points is Array:
		return
	curve.clear_points()
	for p in points:
		var pos := Vector2.ZERO
		var pin := Vector2.ZERO
		var pout := Vector2.ZERO
		if p is Array:
			if p.size() >= 2:
				pos = Vector2(float(p[0]), float(p[1]))
			if p.size() >= 4:
				pin = Vector2(float(p[2]), float(p[3]))
			if p.size() >= 6:
				pout = Vector2(float(p[4]), float(p[5]))
		elif p is Dictionary:
			pos = _v2(p.get("position", p.get("pos", p)))
			pin = _v2(p.get("in", p.get("in_handle", {})))
			pout = _v2(p.get("out", p.get("out_handle", {})))
		curve.add_point(pos, pin, pout)


func _v2(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


func _v3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Dictionary:
		return Vector3(float(v.get("x", 0)), float(v.get("y", 0)), float(v.get("z", 0)))
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


func _load_curve2d(path: String) -> Curve2D:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Curve2D


func _curve2d_set_points(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve2d(r[0])
	if curve == null:
		return error_not_found(r[0])
	_apply_curve2d_points(curve, params.get("points", []))
	ResourceSaver.save(curve, r[0])
	return success({"path": r[0], "point_count": curve.point_count})


func _curve2d_get_points(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve2d(r[0])
	if curve == null:
		return error_not_found(r[0])
	var pts: Array = []
	for i in curve.point_count:
		var pos := curve.get_point_position(i)
		var pin := curve.get_point_in(i)
		var pout := curve.get_point_out(i)
		pts.append({
			"index": i,
			"position": {"x": pos.x, "y": pos.y},
			"in_handle": {"x": pin.x, "y": pin.y},
			"out_handle": {"x": pout.x, "y": pout.y},
			## Absolute Cartesian endpoints of handles (agent plane mapping)
			"in_world": {"x": pos.x + pin.x, "y": pos.y + pin.y},
			"out_world": {"x": pos.x + pout.x, "y": pos.y + pout.y},
		})
	return success({"path": r[0], "points": pts, "count": pts.size(), "baked_length": curve.get_baked_length()})


func _curve2d_sample_polyline(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve2d(r[0])
	if curve == null:
		return error_not_found(r[0])
	var interval: float = maxf(float(params.get("interval", 8.0)), 0.5)
	var baked: PackedVector2Array = curve.get_baked_points()
	# Also resample by length
	var samples_n: int = clampi(optional_int(params, "samples", 0), 0, 2000)
	var out: Array = []
	if samples_n >= 2:
		var L := curve.get_baked_length()
		for i in samples_n:
			var d := L * float(i) / float(samples_n - 1)
			var p := curve.sample_baked(d)
			out.append({"x": p.x, "y": p.y, "offset": d})
	else:
		for p in baked:
			out.append({"x": p.x, "y": p.y})
	return success({"path": r[0], "polyline": out, "count": out.size(), "interval_hint": interval})


# ── Curve3D ───────────────────────────────────────────────────────────────────

func _create_curve3d(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://curves/curve3d.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var curve := Curve3D.new()
	_apply_curve3d_points(curve, params.get("points", []))
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	ResourceSaver.save(curve, path)
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "point_count": curve.point_count})


func _apply_curve3d_points(curve: Curve3D, points: Variant) -> void:
	if not points is Array:
		return
	curve.clear_points()
	for p in points:
		var pos := Vector3.ZERO
		var pin := Vector3.ZERO
		var pout := Vector3.ZERO
		if p is Array and p.size() >= 3:
			pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
			if p.size() >= 6:
				pin = Vector3(float(p[3]), float(p[4]), float(p[5]))
			if p.size() >= 9:
				pout = Vector3(float(p[6]), float(p[7]), float(p[8]))
		elif p is Dictionary:
			pos = _v3(p.get("position", p.get("pos", p)))
			pin = _v3(p.get("in", p.get("in_handle", {})))
			pout = _v3(p.get("out", p.get("out_handle", {})))
		curve.add_point(pos, pin, pout)


func _load_curve3d(path: String) -> Curve3D:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Curve3D


func _curve3d_set_points(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve3d(r[0])
	if curve == null:
		return error_not_found(r[0])
	_apply_curve3d_points(curve, params.get("points", []))
	ResourceSaver.save(curve, r[0])
	return success({"path": r[0], "point_count": curve.point_count})


func _curve3d_get_points(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve3d(r[0])
	if curve == null:
		return error_not_found(r[0])
	var pts: Array = []
	for i in curve.point_count:
		var pos := curve.get_point_position(i)
		var pin := curve.get_point_in(i)
		var pout := curve.get_point_out(i)
		pts.append({
			"index": i,
			"position": {"x": pos.x, "y": pos.y, "z": pos.z},
			"in_handle": {"x": pin.x, "y": pin.y, "z": pin.z},
			"out_handle": {"x": pout.x, "y": pout.y, "z": pout.z},
			"in_world": {"x": pos.x + pin.x, "y": pos.y + pin.y, "z": pos.z + pin.z},
			"out_world": {"x": pos.x + pout.x, "y": pos.y + pout.y, "z": pos.z + pout.z},
		})
	return success({"path": r[0], "points": pts, "count": pts.size(), "baked_length": curve.get_baked_length()})


func _curve3d_sample_polyline(params: Dictionary) -> Dictionary:
	var r := require_res_path(params, "path")
	if r[1] != null:
		return r[1]
	var curve := _load_curve3d(r[0])
	if curve == null:
		return error_not_found(r[0])
	var samples_n: int = clampi(optional_int(params, "samples", 64), 2, 2000)
	var out: Array = []
	var L := curve.get_baked_length()
	for i in samples_n:
		var d := L * float(i) / float(samples_n - 1)
		var p := curve.sample_baked(d)
		out.append({"x": p.x, "y": p.y, "z": p.z, "offset": d})
	return success({"path": r[0], "polyline": out, "count": out.size(), "length": L})


# ── Path2D / Path3D live nodes ────────────────────────────────────────────────

func _path_get_curve_points(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found(r0[0])
	if node is Path2D:
		var c: Curve2D = (node as Path2D).curve
		if c == null:
			return success({"node_path": r0[0], "type": "Path2D", "points": [], "empty": true})
		# Reuse serialization via temp save? inline
		var pts: Array = []
		for i in c.point_count:
			var pos := c.get_point_position(i)
			var pin := c.get_point_in(i)
			var pout := c.get_point_out(i)
			pts.append({
				"index": i,
				"position": {"x": pos.x, "y": pos.y},
				"in_handle": {"x": pin.x, "y": pin.y},
				"out_handle": {"x": pout.x, "y": pout.y},
				"in_world": {"x": pos.x + pin.x, "y": pos.y + pin.y},
				"out_world": {"x": pos.x + pout.x, "y": pos.y + pout.y},
			})
		return success({"node_path": r0[0], "type": "Path2D", "points": pts, "count": pts.size()})
	if node is Path3D:
		var c3: Curve3D = (node as Path3D).curve
		if c3 == null:
			return success({"node_path": r0[0], "type": "Path3D", "points": [], "empty": true})
		var pts3: Array = []
		for i in c3.point_count:
			var pos := c3.get_point_position(i)
			var pin := c3.get_point_in(i)
			var pout := c3.get_point_out(i)
			pts3.append({
				"index": i,
				"position": {"x": pos.x, "y": pos.y, "z": pos.z},
				"in_handle": {"x": pin.x, "y": pin.y, "z": pin.z},
				"out_handle": {"x": pout.x, "y": pout.y, "z": pout.z},
				"in_world": {"x": pos.x + pin.x, "y": pos.y + pin.y, "z": pos.z + pin.z},
				"out_world": {"x": pos.x + pout.x, "y": pos.y + pout.y, "z": pos.z + pout.z},
			})
		return success({"node_path": r0[0], "type": "Path3D", "points": pts3, "count": pts3.size()})
	return error_invalid_params("Node must be Path2D or Path3D")


func _path_set_curve_points(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("points"):
		return error_invalid_params("points required")
	var node := find_node_by_path(r0[0])
	if node is Path2D:
		var c := Curve2D.new()
		_apply_curve2d_points(c, params["points"])
		(node as Path2D).curve = c
		mark_current_scene_unsaved()
		return success({"node_path": r0[0], "type": "Path2D", "point_count": c.point_count})
	if node is Path3D:
		var c3 := Curve3D.new()
		_apply_curve3d_points(c3, params["points"])
		(node as Path3D).curve = c3
		mark_current_scene_unsaved()
		return success({"node_path": r0[0], "type": "Path3D", "point_count": c3.point_count})
	return error_invalid_params("Node must be Path2D or Path3D")


# ── Animation Bezier (Cartesian: x=time, y=value) ─────────────────────────────

func _anim_bezier_ctx(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return {"error": r0[1]}
	var r1 := require_string(params, "animation")
	if r1[1] != null:
		return {"error": r1[1]}
	var node := find_node_by_path(r0[0])
	if not node is AnimationPlayer:
		return {"error": error_not_found("AnimationPlayer")}
	var player: AnimationPlayer = node
	var anim := player.get_animation(r1[0])
	if anim == null:
		return {"error": error_not_found("Animation '%s'" % r1[0])}
	var track_index: int = int(params.get("track_index", -1))
	var track_path: String = optional_string(params, "track_path", "")
	if track_index < 0 and not track_path.is_empty():
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_BEZIER and str(anim.track_get_path(i)) == track_path:
				track_index = i
				break
	if track_index < 0:
		return {"error": error_invalid_params("track_index or track_path to TYPE_BEZIER required")}
	if track_index >= anim.get_track_count() or anim.track_get_type(track_index) != Animation.TYPE_BEZIER:
		return {"error": error_invalid_params("Track is not TYPE_BEZIER")}
	return {"player": player, "anim": anim, "track_index": track_index, "anim_name": r1[0], "node_path": r0[0]}


func _bezier_list_keys_cartesian(params: Dictionary) -> Dictionary:
	## Full plane map: anchors (time, value) + handle endpoints in the same plane.
	var ctx := _anim_bezier_ctx(params)
	if ctx.has("error"):
		return ctx["error"]
	var anim: Animation = ctx["anim"]
	var ti: int = ctx["track_index"]
	var keys: Array = []
	for i in anim.track_get_key_count(ti):
		var t := anim.track_get_key_time(ti, i)
		var val := float(anim.bezier_track_get_key_value(ti, i) if anim.has_method("bezier_track_get_key_value") else anim.track_get_key_value(ti, i))
		var ih := Vector2(-0.25, 0)
		var oh := Vector2(0.25, 0)
		if anim.has_method("bezier_track_get_key_in_handle"):
			ih = anim.bezier_track_get_key_in_handle(ti, i)
			oh = anim.bezier_track_get_key_out_handle(ti, i)
		# Godot stores handles as offsets in (time, value) space relative to key
		keys.append({
			"key_index": i,
			"anchor": {"x": t, "y": val},  # Cartesian focal point
			"in_handle_offset": {"x": ih.x, "y": ih.y},
			"out_handle_offset": {"x": oh.x, "y": oh.y},
			"in_endpoint": {"x": t + ih.x, "y": val + ih.y},
			"out_endpoint": {"x": t + oh.x, "y": val + oh.y},
		})
	return success({
		"animation": ctx["anim_name"],
		"track_index": ti,
		"path": str(anim.track_get_path(ti)),
		"plane": "x=time (seconds), y=value",
		"keys": keys,
		"count": keys.size(),
		"hint": "Agents set focal points via bezier_set_keys_batch / set_bezier_key using the same coordinates",
	})


func _bezier_set_keys_batch(params: Dictionary) -> Dictionary:
	## Replace or merge keys from Cartesian specs: {time/x, value/y, in, out}.
	var ctx := _anim_bezier_ctx(params)
	if ctx.has("error"):
		return ctx["error"]
	if not params.has("keys") or not params["keys"] is Array:
		return error_invalid_params("keys: Array of {time|x, value|y, in_handle?, out_handle?}")
	var anim: Animation = ctx["anim"]
	var ti: int = ctx["track_index"]
	var clear_first: bool = optional_bool(params, "clear", true)
	if clear_first:
		while anim.track_get_key_count(ti) > 0:
			anim.track_remove_key(ti, 0)
	var written: Array = []
	for item in params["keys"]:
		if not item is Dictionary:
			continue
		var t := float(item.get("time", item.get("x", 0.0)))
		var val := float(item.get("value", item.get("y", 0.0)))
		var ih := _v2(item.get("in_handle", item.get("in", {"x": -0.25, "y": 0})))
		var oh := _v2(item.get("out_handle", item.get("out", {"x": 0.25, "y": 0})))
		# Absolute endpoints → convert to offsets if agent sent in_endpoint
		if item.has("in_endpoint"):
			var ie := _v2(item["in_endpoint"])
			ih = Vector2(ie.x - t, ie.y - val)
		if item.has("out_endpoint"):
			var oe := _v2(item["out_endpoint"])
			oh = Vector2(oe.x - t, oe.y - val)
		var kidx: int
		if anim.has_method("bezier_track_insert_key"):
			kidx = anim.bezier_track_insert_key(ti, t, val, ih, oh)
		else:
			kidx = anim.track_insert_key(ti, t, val)
			if anim.has_method("bezier_track_set_key_in_handle"):
				anim.bezier_track_set_key_in_handle(ti, kidx, ih)
				anim.bezier_track_set_key_out_handle(ti, kidx, oh)
		written.append({"key_index": kidx, "time": t, "value": val})
	# Extend length if needed
	var max_t := anim.length
	for k in anim.track_get_key_count(ti):
		max_t = maxf(max_t, anim.track_get_key_time(ti, k))
	if max_t > anim.length:
		anim.length = max_t
	mark_current_scene_unsaved()
	return success({
		"animation": ctx["anim_name"],
		"track_index": ti,
		"keys_written": written.size(),
		"keys": written,
		"length": anim.length,
	})


func _bezier_sample_dense(params: Dictionary) -> Dictionary:
	## Dense polyline of the Bezier track for agent understanding of curve shape.
	var ctx := _anim_bezier_ctx(params)
	if ctx.has("error"):
		return ctx["error"]
	var anim: Animation = ctx["anim"]
	var ti: int = ctx["track_index"]
	var samples_n: int = clampi(optional_int(params, "samples", 64), 2, 2000)
	var t0: float = float(params.get("start", 0.0))
	var t1: float = float(params.get("end", anim.length))
	if t1 <= t0:
		t1 = t0 + 0.001
	var out: Array = []
	for i in samples_n:
		var u := float(i) / float(samples_n - 1)
		var t := lerpf(t0, t1, u)
		var y: float
		if anim.has_method("bezier_track_interpolate"):
			y = float(anim.bezier_track_interpolate(ti, t))
		else:
			y = float(anim.track_get_key_value(ti, 0)) if anim.track_get_key_count(ti) > 0 else 0.0
		out.append({"x": t, "y": y})
	return success({
		"animation": ctx["anim_name"],
		"track_index": ti,
		"plane": "x=time, y=value",
		"polyline": out,
		"count": out.size(),
		"range": {"start": t0, "end": t1},
	})


func _bezier_remove_key(params: Dictionary) -> Dictionary:
	var ctx := _anim_bezier_ctx(params)
	if ctx.has("error"):
		return ctx["error"]
	var anim: Animation = ctx["anim"]
	var ti: int = ctx["track_index"]
	var key_index: int = int(params.get("key_index", -1))
	if key_index < 0 and params.has("time"):
		var t := float(params["time"])
		for k in anim.track_get_key_count(ti):
			if is_equal_approx(anim.track_get_key_time(ti, k), t):
				key_index = k
				break
	if key_index < 0 or key_index >= anim.track_get_key_count(ti):
		return error_invalid_params("key_index or time required")
	anim.track_remove_key(ti, key_index)
	mark_current_scene_unsaved()
	return success({"track_index": ti, "removed_key_index": key_index})


func _bezier_set_handle_mode(params: Dictionary) -> Dictionary:
	## If engine exposes handle balance modes on keys, set them; else document offsets only.
	var ctx := _anim_bezier_ctx(params)
	if ctx.has("error"):
		return ctx["error"]
	var anim: Animation = ctx["anim"]
	var ti: int = ctx["track_index"]
	var key_index: int = int(params.get("key_index", 0))
	var mode: String = optional_string(params, "mode", "free")  # free | linear | balanced | mirrored
	# Godot 4 Animation bezier handles are free offsets; "modes" approximated by rewriting handles
	if not anim.has_method("bezier_track_get_key_in_handle"):
		return error_internal("Bezier handle API unavailable")
	if key_index < 0 or key_index >= anim.track_get_key_count(ti):
		return error_invalid_params("Invalid key_index")
	var t := anim.track_get_key_time(ti, key_index)
	var val := float(anim.bezier_track_get_key_value(ti, key_index))
	var ih: Vector2 = anim.bezier_track_get_key_in_handle(ti, key_index)
	var oh: Vector2 = anim.bezier_track_get_key_out_handle(ti, key_index)
	match mode:
		"linear":
			ih = Vector2(-0.001, 0)
			oh = Vector2(0.001, 0)
		"balanced", "mirrored":
			# Mirror out = -in
			oh = Vector2(-ih.x, -ih.y)
		"aligned":
			# Same direction, equal magnitude
			var mag := ih.length()
			if mag < 0.0001:
				mag = 0.25
			var dir := (-ih).normalized() if ih.length() > 0.0001 else Vector2(1, 0)
			oh = dir * mag
			ih = -dir * mag
		_:
			pass  # free — leave as-is unless overrides provided
	if params.has("in_handle"):
		ih = _v2(params["in_handle"])
	if params.has("out_handle"):
		oh = _v2(params["out_handle"])
	anim.bezier_track_set_key_in_handle(ti, key_index, ih)
	anim.bezier_track_set_key_out_handle(ti, key_index, oh)
	mark_current_scene_unsaved()
	return success({
		"key_index": key_index,
		"mode": mode,
		"anchor": {"x": t, "y": val},
		"in_handle": {"x": ih.x, "y": ih.y},
		"out_handle": {"x": oh.x, "y": oh.y},
		"in_endpoint": {"x": t + ih.x, "y": val + ih.y},
		"out_endpoint": {"x": t + oh.x, "y": val + oh.y},
	})
