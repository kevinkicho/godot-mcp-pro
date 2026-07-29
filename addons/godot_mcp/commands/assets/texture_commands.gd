@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Procedural texture / gradient / noise resources (2D pipeline helpers).


func get_commands() -> Dictionary:
	return {
		"create_gradient_texture": _create_gradient_texture,
		"create_noise_texture": _create_noise_texture,
		"create_placeholder_texture": _create_placeholder_texture,
		"create_curve_texture": _create_curve_texture,
	}


func _create_gradient_texture(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var width: int = optional_int(params, "width", 256)
	var grad := Gradient.new()
	# Optional stops: [{offset, color}, ...]
	var stops: Array = params.get("stops", [])
	if stops is Array and stops.size() >= 2:
		# Clear default and set
		while grad.get_point_count() > 0:
			grad.remove_point(0)
		for s in stops:
			if s is Dictionary:
				var col = s.get("color", "#ffffff")
				var c: Color
				if col is String:
					c = Color.html(col) if str(col).begins_with("#") else Color(col)
				elif col is Dictionary:
					c = Color(float(col.get("r", 1)), float(col.get("g", 1)), float(col.get("b", 1)), float(col.get("a", 1)))
				else:
					c = Color.WHITE
				grad.add_point(float(s.get("offset", 0)), c)
	else:
		grad.set_color(0, Color.BLACK)
		grad.set_color(1, Color.WHITE)
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = width
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(tex, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "type": "GradientTexture1D", "width": width})


func _create_noise_texture(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var noise := FastNoiseLite.new()
	noise.seed = optional_int(params, "seed", randi())
	noise.frequency = float(params.get("frequency", 0.01))
	if params.has("fractal_octaves"):
		noise.fractal_octaves = int(params["fractal_octaves"])
	if params.has("noise_type"):
		match str(params["noise_type"]).to_lower():
			"simplex":
				noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			"perlin":
				noise.noise_type = FastNoiseLite.TYPE_PERLIN
			"cellular":
				noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			_:
				noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = optional_int(params, "width", 512)
	tex.height = optional_int(params, "height", 512)
	tex.seamless = optional_bool(params, "seamless", true)
	if params.has("as_normal_map"):
		tex.as_normal_map = bool(params["as_normal_map"])
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(tex, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"type": "NoiseTexture2D",
		"width": tex.width,
		"height": tex.height,
		"seed": noise.seed,
	})


func _create_placeholder_texture(params: Dictionary) -> Dictionary:
	## Solid-color ImageTexture for prototypes.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var w: int = optional_int(params, "width", 64)
	var h: int = optional_int(params, "height", 64)
	var color := Color(0.4, 0.4, 0.45)
	if params.has("color"):
		var c = params["color"]
		if c is String:
			color = Color.html(c) if str(c).begins_with("#") else Color(c)
		elif c is Dictionary:
			color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	# Optional checker
	if optional_bool(params, "checker", false):
		var c2 := color.darkened(0.25)
		var cell: int = optional_int(params, "checker_size", 8)
		for y in h:
			for x in w:
				if ((x / cell) + (y / cell)) % 2 == 0:
					img.set_pixel(x, y, c2)
	var tex := ImageTexture.create_from_image(img)
	var derr := ensure_parent_dir(res[0])
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(tex, res[0])
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(res[0])
	return success({"path": res[0], "type": "ImageTexture", "width": w, "height": h})


func _create_curve_texture(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	var points: Array = params.get("points", [])
	if points is Array and points.size() >= 2:
		curve.clear_points()
		for p in points:
			if p is Array and p.size() >= 2:
				curve.add_point(Vector2(float(p[0]), float(p[1])))
			elif p is Dictionary:
				curve.add_point(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	var tex := CurveTexture.new()
	tex.curve = curve
	tex.width = optional_int(params, "width", 256)
	var derr := ensure_parent_dir(res[0])
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(tex, res[0])
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(res[0])
	return success({"path": res[0], "type": "CurveTexture"})
