@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## 2D human editor surfaces: Camera2D, Parallax, lights/occluders, CanvasModulate.


func get_commands() -> Dictionary:
	return {
		"setup_camera_2d": _setup_camera_2d,
		"setup_parallax_background": _setup_parallax_background,
		"add_parallax_layer": _add_parallax_layer,
		"add_light_occluder_2d": _add_light_occluder_2d,
		"setup_point_light_2d": _setup_point_light_2d,
		"setup_canvas_modulate": _setup_canvas_modulate,
		"setup_world_environment_2d": _setup_world_environment_2d,
		"setup_line_2d": _setup_line_2d,
		"setup_path_2d": _setup_path_2d,
		"setup_polygon_2d": _setup_polygon_2d,
		"set_y_sort_enabled": _set_y_sort_enabled,
		"setup_canvas_layer": _setup_canvas_layer,
		"setup_directional_light_2d": _setup_directional_light_2d,
		"setup_timer": _setup_timer,
		"setup_remote_transform_2d": _setup_remote_transform_2d,
		"setup_visible_on_screen_notifier_2d": _setup_visible_on_screen_notifier_2d,
		"add_camera_shake_to_camera2d": _add_camera_shake_to_camera2d,
	}


func _setup_camera_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	# Reuse existing Camera2D if present under parent
	var cam: Camera2D = null
	var existing_path: String = optional_string(params, "node_path", "")
	if not existing_path.is_empty():
		var n := find_node_by_path(existing_path)
		if n is Camera2D:
			cam = n as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = optional_string(params, "name", "Camera2D")
		add_child_with_undo(parent, cam, root, "MCP: Add Camera2D")
	if params.has("enabled"):
		cam.enabled = bool(params["enabled"])
	if params.has("zoom"):
		var z = params["zoom"]
		if z is float or z is int:
			cam.zoom = Vector2(float(z), float(z))
		elif z is Dictionary:
			cam.zoom = Vector2(float(z.get("x", 1)), float(z.get("y", 1)))
		elif z is String:
			var parts := str(z).replace("Vector2(", "").replace(")", "").split(",")
			if parts.size() >= 2:
				cam.zoom = Vector2(float(parts[0]), float(parts[1]))
	if params.has("position_smoothing_enabled"):
		cam.position_smoothing_enabled = bool(params["position_smoothing_enabled"])
	if params.has("position_smoothing_speed"):
		cam.position_smoothing_speed = float(params["position_smoothing_speed"])
	if params.has("rotation_smoothing_enabled"):
		cam.rotation_smoothing_enabled = bool(params["rotation_smoothing_enabled"])
	if params.has("limit_left"):
		cam.limit_left = int(params["limit_left"])
	if params.has("limit_top"):
		cam.limit_top = int(params["limit_top"])
	if params.has("limit_right"):
		cam.limit_right = int(params["limit_right"])
	if params.has("limit_bottom"):
		cam.limit_bottom = int(params["limit_bottom"])
	if params.has("drag_horizontal_enabled"):
		cam.drag_horizontal_enabled = bool(params["drag_horizontal_enabled"])
	if params.has("drag_vertical_enabled"):
		cam.drag_vertical_enabled = bool(params["drag_vertical_enabled"])
	if optional_bool(params, "make_current", true):
		cam.make_current()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(cam)),
		"zoom": {"x": cam.zoom.x, "y": cam.zoom.y},
		"limits": {
			"left": cam.limit_left, "top": cam.limit_top,
			"right": cam.limit_right, "bottom": cam.limit_bottom,
		},
		"current": cam.is_current(),
	})


func _setup_parallax_background(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var pb := ParallaxBackground.new()
	pb.name = optional_string(params, "name", "ParallaxBackground")
	if params.has("scroll_ignore_camera_zoom"):
		pb.scroll_ignore_camera_zoom = bool(params["scroll_ignore_camera_zoom"])
	add_child_with_undo(parent, pb, root, "MCP: Add ParallaxBackground")
	return success({"node_path": str(root.get_path_to(pb)), "type": "ParallaxBackground"})


func _add_parallax_layer(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	# Godot 4.3+ prefers Parallax2D; keep ParallaxLayer for classic BG stack
	var use_parallax2d: bool = optional_bool(params, "use_parallax2d", false)
	if use_parallax2d and ClassDB.class_exists("Parallax2D"):
		var p2: Node = ClassDB.instantiate("Parallax2D")
		p2.name = optional_string(params, "name", "Parallax2D")
		if "scroll_scale" in p2:
			p2.set("scroll_scale", Vector2(
				float(params.get("scroll_scale_x", params.get("motion_scale_x", 0.5))),
				float(params.get("scroll_scale_y", params.get("motion_scale_y", 0.5)))
			))
		add_child_with_undo(parent, p2, root, "MCP: Add Parallax2D")
		return success({"node_path": str(root.get_path_to(p2)), "type": "Parallax2D"})
	var layer := ParallaxLayer.new()
	layer.name = optional_string(params, "name", "ParallaxLayer")
	layer.motion_scale = Vector2(
		float(params.get("motion_scale_x", 0.5)),
		float(params.get("motion_scale_y", 0.5))
	)
	if params.has("motion_offset_x") or params.has("motion_offset_y"):
		layer.motion_offset = Vector2(
			float(params.get("motion_offset_x", 0)),
			float(params.get("motion_offset_y", 0))
		)
	add_child_with_undo(parent, layer, root, "MCP: Add ParallaxLayer")
	# Optional sprite child with texture
	var tex_path: String = optional_string(params, "texture_path", "")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		var spr := Sprite2D.new()
		spr.name = "Sprite2D"
		spr.texture = load(tex_path)
		layer.add_child(spr)
		spr.owner = root
	return success({
		"node_path": str(root.get_path_to(layer)),
		"type": "ParallaxLayer",
		"motion_scale": {"x": layer.motion_scale.x, "y": layer.motion_scale.y},
	})


func _add_light_occluder_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var occ := LightOccluder2D.new()
	occ.name = optional_string(params, "name", "LightOccluder2D")
	var poly := OccluderPolygon2D.new()
	var points: Array = params.get("points", [])
	var packed := PackedVector2Array()
	if points is Array and points.size() >= 3:
		for p in points:
			if p is Array and p.size() >= 2:
				packed.append(Vector2(float(p[0]), float(p[1])))
			elif p is Dictionary:
				packed.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	else:
		# Default unit square
		var s: float = float(params.get("size", 32.0))
		packed = PackedVector2Array([
			Vector2(-s / 2, -s / 2), Vector2(s / 2, -s / 2),
			Vector2(s / 2, s / 2), Vector2(-s / 2, s / 2),
		])
	poly.polygon = packed
	poly.closed = optional_bool(params, "closed", true)
	occ.occluder = poly
	add_child_with_undo(parent, occ, root, "MCP: Add LightOccluder2D")
	return success({
		"node_path": str(root.get_path_to(occ)),
		"point_count": packed.size(),
	})


func _setup_point_light_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var light := PointLight2D.new()
	light.name = optional_string(params, "name", "PointLight2D")
	light.enabled = optional_bool(params, "enabled", true)
	light.energy = float(params.get("energy", 1.0))
	light.texture_scale = float(params.get("texture_scale", 1.0))
	if params.has("color"):
		var c = params["color"]
		if c is String:
			light.color = Color.html(c) if str(c).begins_with("#") else Color(c)
		elif c is Dictionary:
			light.color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
	var tex_path: String = optional_string(params, "texture_path", "")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		light.texture = load(tex_path)
	add_child_with_undo(parent, light, root, "MCP: Add PointLight2D")
	return success({"node_path": str(root.get_path_to(light)), "type": "PointLight2D", "energy": light.energy})


func _setup_canvas_modulate(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var cm := CanvasModulate.new()
	cm.name = optional_string(params, "name", "CanvasModulate")
	if params.has("color"):
		var c = params["color"]
		if c is String:
			cm.color = Color.html(c) if str(c).begins_with("#") else Color(c)
		elif c is Dictionary:
			cm.color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
	else:
		cm.color = Color(0.2, 0.2, 0.35)  # night-ish default for lighting demos
	add_child_with_undo(parent, cm, root, "MCP: Add CanvasModulate")
	return success({"node_path": str(root.get_path_to(cm)), "color": cm.color.to_html()})


func _setup_world_environment_2d(params: Dictionary) -> Dictionary:
	## Convenience: WorldEnvironment with Environment for glow etc. in 2D projects.
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var we := WorldEnvironment.new()
	we.name = optional_string(params, "name", "WorldEnvironment")
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	if optional_bool(params, "glow_enabled", false):
		env.glow_enabled = true
		env.glow_intensity = float(params.get("glow_intensity", 0.8))
	we.environment = env
	add_child_with_undo(parent, we, root, "MCP: Add WorldEnvironment 2D")
	return success({"node_path": str(root.get_path_to(we)), "glow_enabled": env.glow_enabled})


func _parse_vec2_array(points: Array) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for p in points:
		if p is Array and p.size() >= 2:
			packed.append(Vector2(float(p[0]), float(p[1])))
		elif p is Dictionary:
			packed.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	return packed


func _setup_line_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var line := Line2D.new()
	line.name = optional_string(params, "name", "Line2D")
	line.width = float(params.get("width", 4.0))
	if params.has("default_color"):
		var c = params["default_color"]
		if c is String:
			line.default_color = Color.html(c) if str(c).begins_with("#") else Color(c)
		elif c is Dictionary:
			line.default_color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
	var points: Array = params.get("points", [])
	if points is Array and points.size() >= 2:
		line.points = _parse_vec2_array(points)
	else:
		line.points = PackedVector2Array([Vector2.ZERO, Vector2(64, 0), Vector2(64, 64)])
	if params.has("closed"):
		# Line2D closed exists in some versions as property
		if "closed" in line:
			line.set("closed", bool(params["closed"]))
	if params.has("joint_mode"):
		match str(params["joint_mode"]):
			"sharp": line.joint_mode = Line2D.LINE_JOINT_SHARP
			"bevel": line.joint_mode = Line2D.LINE_JOINT_BEVEL
			"round": line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child_with_undo(parent, line, root, "MCP: Add Line2D")
	return success({"node_path": str(root.get_path_to(line)), "point_count": line.get_point_count()})


func _setup_path_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var path := Path2D.new()
	path.name = optional_string(params, "name", "Path2D")
	var curve := Curve2D.new()
	var points: Array = params.get("points", [])
	if points is Array and points.size() >= 1:
		for p in points:
			if p is Array and p.size() >= 2:
				curve.add_point(Vector2(float(p[0]), float(p[1])))
			elif p is Dictionary:
				curve.add_point(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	else:
		curve.add_point(Vector2.ZERO)
		curve.add_point(Vector2(100, 0))
		curve.add_point(Vector2(100, 100))
	path.curve = curve
	add_child_with_undo(parent, path, root, "MCP: Add Path2D")
	var follow_path := ""
	if optional_bool(params, "with_follow", false):
		var follow := PathFollow2D.new()
		follow.name = "PathFollow2D"
		follow.rotates = optional_bool(params, "rotates", true)
		path.add_child(follow)
		follow.owner = root
		follow_path = str(root.get_path_to(follow))
	return success({
		"node_path": str(root.get_path_to(path)),
		"point_count": curve.point_count,
		"path_follow": follow_path,
	})


func _setup_polygon_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var poly := Polygon2D.new()
	poly.name = optional_string(params, "name", "Polygon2D")
	var points: Array = params.get("points", [])
	if points is Array and points.size() >= 3:
		poly.polygon = _parse_vec2_array(points)
	else:
		var s: float = float(params.get("size", 32.0))
		poly.polygon = PackedVector2Array([
			Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s),
		])
	if params.has("color"):
		var c = params["color"]
		if c is String:
			poly.color = Color.html(c) if str(c).begins_with("#") else Color(c)
	var tex: String = optional_string(params, "texture_path", "")
	if not tex.is_empty() and ResourceLoader.exists(tex):
		poly.texture = load(tex)
	add_child_with_undo(parent, poly, root, "MCP: Add Polygon2D")
	return success({"node_path": str(root.get_path_to(poly)), "vertex_count": poly.polygon.size()})


func _set_y_sort_enabled(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not ("y_sort_enabled" in node):
		return error_invalid_params("%s has no y_sort_enabled (use Node2D / TileMapLayer etc.)" % node.get_class())
	var enabled: bool = optional_bool(params, "enabled", true)
	node.set("y_sort_enabled", enabled)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "y_sort_enabled": enabled})


func _setup_canvas_layer(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var cl := CanvasLayer.new()
	cl.name = optional_string(params, "name", "CanvasLayer")
	cl.layer = optional_int(params, "layer", 1)
	cl.follow_viewport_enabled = optional_bool(params, "follow_viewport", false)
	add_child_with_undo(parent, cl, root, "MCP: Add CanvasLayer")
	return success({"node_path": str(root.get_path_to(cl)), "layer": cl.layer})


func _setup_directional_light_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var light := DirectionalLight2D.new()
	light.name = optional_string(params, "name", "DirectionalLight2D")
	light.enabled = optional_bool(params, "enabled", true)
	light.energy = float(params.get("energy", 1.0))
	if params.has("color"):
		var c = params["color"]
		if c is String:
			light.color = Color.html(c) if str(c).begins_with("#") else Color(c)
	if params.has("height"):
		light.height = float(params["height"])
	add_child_with_undo(parent, light, root, "MCP: Add DirectionalLight2D")
	return success({"node_path": str(root.get_path_to(light)), "energy": light.energy})


func _setup_timer(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var timer := Timer.new()
	timer.name = optional_string(params, "name", "Timer")
	timer.wait_time = float(params.get("wait_time", 1.0))
	timer.one_shot = optional_bool(params, "one_shot", false)
	timer.autostart = optional_bool(params, "autostart", false)
	timer.process_callback = Timer.TIMER_PROCESS_IDLE if optional_string(params, "process", "idle") == "idle" else Timer.TIMER_PROCESS_PHYSICS
	add_child_with_undo(parent, timer, root, "MCP: Add Timer")
	return success({
		"node_path": str(root.get_path_to(timer)),
		"wait_time": timer.wait_time,
		"one_shot": timer.one_shot,
		"autostart": timer.autostart,
	})


func _setup_remote_transform_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var rt := RemoteTransform2D.new()
	rt.name = optional_string(params, "name", "RemoteTransform2D")
	var remote: String = optional_string(params, "remote_path", "")
	if not remote.is_empty():
		rt.remote_path = NodePath(remote)
	rt.update_position = optional_bool(params, "update_position", true)
	rt.update_rotation = optional_bool(params, "update_rotation", true)
	rt.update_scale = optional_bool(params, "update_scale", false)
	add_child_with_undo(parent, rt, root, "MCP: Add RemoteTransform2D")
	return success({"node_path": str(root.get_path_to(rt)), "remote_path": str(rt.remote_path)})


func _setup_visible_on_screen_notifier_2d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var n := VisibleOnScreenNotifier2D.new()
	n.name = optional_string(params, "name", "VisibleOnScreenNotifier2D")
	if params.has("rect"):
		var r = params["rect"]
		if r is Dictionary:
			n.rect = Rect2(float(r.get("x", 0)), float(r.get("y", 0)), float(r.get("w", 16)), float(r.get("h", 16)))
	add_child_with_undo(parent, n, root, "MCP: Add VisibleOnScreenNotifier2D")
	return success({"node_path": str(root.get_path_to(n))})


func _add_camera_shake_to_camera2d(params: Dictionary) -> Dictionary:
	## Attach camera_shake.gd child to a Camera2D (creates script if missing).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var cam := find_node_by_path(r0[0])
	if cam == null or not cam is Camera2D:
		return error_not_found("Camera2D at '%s'" % r0[0])
	var script_path: String = optional_string(params, "script_path", "res://scripts/camera_shake.gd")
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path.trim_prefix("/")
	if not FileAccess.file_exists(script_path):
		var derr := ensure_parent_dir(script_path)
		if not derr.is_empty():
			return derr
		# Minimal shake script so attach works without a prior template call
		var body := """extends Node
@export var max_offset: float = 12.0
@export var decay: float = 1.2
var _trauma: float = 0.0
var _base: Vector2
func _ready() -> void:
	var p := get_parent()
	if p is Camera2D:
		_base = (p as Camera2D).offset
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)
func _process(delta: float) -> void:
	var p := get_parent()
	if not (p is Camera2D) or _trauma <= 0.0:
		return
	_trauma = maxf(_trauma - decay * delta, 0.0)
	var s := _trauma * _trauma
	(p as Camera2D).offset = _base + Vector2(randf_range(-1,1), randf_range(-1,1)) * max_offset * s
"""
		var wf := FileAccess.open(script_path, FileAccess.WRITE)
		if wf == null:
			return error_internal("Cannot write %s" % script_path)
		wf.store_string(body)
		wf.close()
		EditorInterface.get_resource_filesystem().update_file(script_path)
	var shake := Node.new()
	shake.name = optional_string(params, "name", "CameraShake")
	var scr: Script = load(script_path) as Script
	if scr:
		shake.set_script(scr)
	add_child_with_undo(cam, shake, root, "MCP: Add CameraShake")
	return success({
		"node_path": str(root.get_path_to(shake)),
		"camera": r0[0],
		"script_path": script_path,
		"hint": "shake.add_trauma(0.5) from damage code",
	})
