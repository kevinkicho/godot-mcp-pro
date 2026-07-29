@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Pixel-game project presets — stretch, integer scale, nearest filter, snap, AA off.
## Matches human Project Settings + Import defaults for crisp 2D pixel art.


func get_commands() -> Dictionary:
	return {
		"list_pixel_2d_presets": _list_presets,
		"apply_pixel_2d_project_preset": _apply_project_preset,
		"get_pixel_2d_project_settings": _get_settings,
		"apply_pixel_texture_import_batch": _apply_texture_batch,
		"set_canvas_item_texture_filter": _set_node_filter,
		"list_pixel_2d_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"scaffold_project_defaults",
			"set_window_project_settings",
			"apply_texture_import_preset",
			"create_input_map_preset",
		],
		"workflow": [
			"apply_pixel_2d_project_preset preset=classic_pixel viewport_width=320 viewport_height=180",
			"apply_pixel_texture_import_batch paths=[res://assets/…]  OR apply_texture_import_preset preset=2d_pixel",
			"tilemap + sprites with nearest filter",
		],
	})


func _list_presets(_params: Dictionary) -> Dictionary:
	return success({
		"presets": {
			"classic_pixel": {
				"description": "Low-res viewport stretch, integer scale, nearest filter, 2D snap, no AA",
				"typical_viewport": "320x180 or 640x360",
				"stretch_mode": "viewport",
				"stretch_aspect": "keep",
				"scale_mode": "integer",
			},
			"pixel_canvas_items": {
				"description": "canvas_items stretch (sharp when scaled), nearest, snap",
				"stretch_mode": "canvas_items",
				"stretch_aspect": "keep",
			},
			"hd_pixel": {
				"description": "Higher base resolution (1280x720) with nearest + snap — modern pixel",
				"typical_viewport": "1280x720",
				"stretch_mode": "canvas_items",
			},
			"smooth_2d": {
				"description": "Linear filter, no forced pixel snap — non-pixel 2D",
				"filter": "linear",
			},
		},
		"tools": get_commands().keys(),
	})


func _get_settings(_params: Dictionary) -> Dictionary:
	return success({
		"viewport_width": ProjectSettings.get_setting("display/window/size/viewport_width", 0),
		"viewport_height": ProjectSettings.get_setting("display/window/size/viewport_height", 0),
		"stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode", ""),
		"stretch_aspect": ProjectSettings.get_setting("display/window/stretch/aspect", ""),
		"stretch_scale": ProjectSettings.get_setting("display/window/stretch/scale", 1.0),
		"scale_mode": ProjectSettings.get_setting("display/window/stretch/scale_mode", ""),
		"default_texture_filter": ProjectSettings.get_setting(
			"rendering/textures/canvas_textures/default_texture_filter", -1
		),
		"snap_2d_transforms_to_pixel": ProjectSettings.get_setting(
			"rendering/2d/snap/snap_2d_transforms_to_pixel", false
		),
		"snap_2d_vertices_to_pixel": ProjectSettings.get_setting(
			"rendering/2d/snap/snap_2d_vertices_to_pixel", false
		),
		"msaa_2d": ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", -1),
		"screen_space_aa": ProjectSettings.get_setting(
			"rendering/anti_aliasing/quality/screen_space_aa", -1
		),
		"use_hdr_2d": ProjectSettings.get_setting("rendering/viewport/hdr_2d", false),
	})


func _apply_project_preset(params: Dictionary) -> Dictionary:
	var preset: String = optional_string(params, "preset", "classic_pixel").to_lower()
	var applied := {}

	var vw: int = int(params.get("viewport_width", 0))
	var vh: int = int(params.get("viewport_height", 0))
	var stretch_mode := "viewport"
	var stretch_aspect := "keep"
	var scale_mode := "integer"
	var filter_nearest := true
	var snap := true
	var disable_aa := true

	match preset:
		"classic_pixel", "pixel", "retro":
			if vw <= 0:
				vw = 320
			if vh <= 0:
				vh = 180
			stretch_mode = "viewport"
			stretch_aspect = "keep"
			scale_mode = "integer"
			filter_nearest = true
			snap = true
			disable_aa = true
		"pixel_canvas_items", "canvas_items_pixel":
			if vw <= 0:
				vw = 640
			if vh <= 0:
				vh = 360
			stretch_mode = "canvas_items"
			stretch_aspect = "keep"
			scale_mode = "integer"
			filter_nearest = true
			snap = true
			disable_aa = true
		"hd_pixel", "modern_pixel":
			if vw <= 0:
				vw = 1280
			if vh <= 0:
				vh = 720
			stretch_mode = "canvas_items"
			stretch_aspect = "keep"
			scale_mode = "fractional"  # allow non-integer on high-res
			filter_nearest = true
			snap = true
			disable_aa = true
		"smooth_2d", "smooth", "hires_2d":
			if vw <= 0:
				vw = 1280
			if vh <= 0:
				vh = 720
			stretch_mode = "canvas_items"
			stretch_aspect = "expand"
			scale_mode = "fractional"
			filter_nearest = false
			snap = false
			disable_aa = false
		_:
			return error_invalid_params(
				"Unknown preset '%s' — classic_pixel | pixel_canvas_items | hd_pixel | smooth_2d" % preset
			)

	# Allow overrides
	if params.has("stretch_mode"):
		stretch_mode = str(params["stretch_mode"])
	if params.has("stretch_aspect"):
		stretch_aspect = str(params["stretch_aspect"])
	if params.has("scale_mode"):
		scale_mode = str(params["scale_mode"])
	if params.has("nearest_filter"):
		filter_nearest = bool(params["nearest_filter"])
	if params.has("snap"):
		snap = bool(params["snap"])
	if params.has("disable_aa"):
		disable_aa = bool(params["disable_aa"])

	ProjectSettings.set_setting("display/window/size/viewport_width", vw)
	ProjectSettings.set_setting("display/window/size/viewport_height", vh)
	applied["display/window/size/viewport_width"] = vw
	applied["display/window/size/viewport_height"] = vh

	ProjectSettings.set_setting("display/window/stretch/mode", stretch_mode)
	ProjectSettings.set_setting("display/window/stretch/aspect", stretch_aspect)
	applied["display/window/stretch/mode"] = stretch_mode
	applied["display/window/stretch/aspect"] = stretch_aspect

	# Godot 4 scale_mode: "fractional" | "integer"
	if ProjectSettings.has_setting("display/window/stretch/scale_mode") \
			or true:
		ProjectSettings.set_setting("display/window/stretch/scale_mode", scale_mode)
		applied["display/window/stretch/scale_mode"] = scale_mode

	if params.has("stretch_scale"):
		ProjectSettings.set_setting("display/window/stretch/scale", float(params["stretch_scale"]))
		applied["display/window/stretch/scale"] = float(params["stretch_scale"])

	# 0 = Nearest, 1 = Linear (Godot 4 CanvasItem default texture filter project setting)
	var filter_val := 0 if filter_nearest else 1
	ProjectSettings.set_setting(
		"rendering/textures/canvas_textures/default_texture_filter", filter_val
	)
	applied["rendering/textures/canvas_textures/default_texture_filter"] = filter_val

	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", snap)
	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", snap)
	applied["rendering/2d/snap/snap_2d_transforms_to_pixel"] = snap
	applied["rendering/2d/snap/snap_2d_vertices_to_pixel"] = snap

	if disable_aa:
		ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_2d", 0)
		ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", 0)
		applied["rendering/anti_aliasing/quality/msaa_2d"] = 0
		applied["rendering/anti_aliasing/quality/screen_space_aa"] = 0

	# Optional: keep window size multiple of viewport for classic feel
	if optional_bool(params, "set_window_size_multiple", false):
		var mult: int = optional_int(params, "window_scale", 3)
		ProjectSettings.set_setting("display/window/size/window_width_override", vw * mult)
		ProjectSettings.set_setting("display/window/size/window_height_override", vh * mult)
		applied["window_override"] = {"w": vw * mult, "h": vh * mult}

	ProjectSettings.save()
	return success({
		"preset": preset,
		"applied": applied,
		"hint": "Also apply_texture_import_preset preset=2d_pixel on art; restart play to see stretch",
		"next": [
			"apply_pixel_texture_import_batch",
			"scaffold_project_defaults genre=2d (if folders/input still needed)",
			"create_input_map_preset platformer_2d|topdown_2d",
		],
	})


func _apply_texture_batch(params: Dictionary) -> Dictionary:
	## Batch nearest-filter import on paths[] or under directory.
	var paths: Array = []
	if params.has("paths") and params["paths"] is Array:
		paths = params["paths"]
	var directory: String = optional_string(params, "directory", "")
	if not directory.is_empty():
		paths.append_array(_collect_textures(directory))
	if paths.is_empty():
		return error_invalid_params("paths[] or directory required")

	var router = get_parent()
	if router == null or not router.has_method("execute"):
		return error_internal("No command router")
	var preset: String = optional_string(params, "preset", "2d_pixel")
	var results: Array = []
	var ok_count := 0
	for p in paths:
		var path_str := str(p)
		var res = await router.execute("apply_texture_import_preset", {
			"path": path_str,
			"preset": preset,
		})
		var is_ok := res is Dictionary and not res.has("error")
		if is_ok:
			ok_count += 1
		results.append({"path": path_str, "ok": is_ok, "result": res})
	return success({
		"preset": preset,
		"count": paths.size(),
		"ok_count": ok_count,
		"results": results,
	})


func _collect_textures(dir_path: String) -> Array:
	var out: Array = []
	var path := dir_path
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var abs := ProjectSettings.globalize_path(path)
	_walk_textures(path, abs, out)
	return out


func _walk_textures(res_dir: String, abs_dir: String, out: Array) -> void:
	var da := DirAccess.open(abs_dir)
	if da == null:
		return
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if fn.begins_with("."):
			fn = da.get_next()
			continue
		var child_abs := abs_dir.path_join(fn)
		var child_res := res_dir.rstrip("/").path_join(fn)
		if da.current_is_dir():
			_walk_textures(child_res, child_abs, out)
		else:
			var ext := fn.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]:
				out.append(child_res)
		fn = da.get_next()
	da.list_dir_end()


func _set_node_filter(params: Dictionary) -> Dictionary:
	## CanvasItem.texture_filter: 0 Parent, 1 Nearest, 2 Linear, …
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is CanvasItem):
		return error_not_found("CanvasItem at '%s'" % r0[0])
	var filter_name: String = optional_string(params, "filter", "nearest").to_lower()
	var filter_i := 1  # TEXTURE_FILTER_NEAREST
	match filter_name:
		"parent", "inherit":
			filter_i = 0
		"nearest", "nearest_mipmap":
			filter_i = 1 if filter_name == "nearest" else 3
		"linear", "linear_mipmap":
			filter_i = 2 if filter_name == "linear" else 4
		_:
			if params.has("filter_enum"):
				filter_i = int(params["filter_enum"])
	(node as CanvasItem).texture_filter = filter_i as CanvasItem.TextureFilter
	var recursive: bool = optional_bool(params, "recursive", false)
	var count := 1
	if recursive:
		count += _set_filter_recursive(node, filter_i)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"filter": filter_name,
		"filter_enum": filter_i,
		"nodes_updated": count,
	})


func _set_filter_recursive(node: Node, filter_i: int) -> int:
	var n := 0
	for c in node.get_children():
		if c is CanvasItem:
			(c as CanvasItem).texture_filter = filter_i as CanvasItem.TextureFilter
			n += 1
		n += _set_filter_recursive(c, filter_i)
	return n
