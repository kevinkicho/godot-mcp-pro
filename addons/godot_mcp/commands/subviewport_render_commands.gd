@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## SubViewport / ViewportTexture / BackBufferCopy — minimaps, portals, offscreen render.


func get_commands() -> Dictionary:
	return {
		"setup_subviewport_container": _setup_svc,
		"setup_subviewport_2d_world": _setup_sv_2d,
		"setup_viewport_texture_rect": _setup_vtex_rect,
		"setup_sprite_from_subviewport": _setup_sprite_from_sv,
		"setup_back_buffer_copy": _setup_bbc,
		"set_subviewport_update_mode": _set_update_mode,
		"list_subviewport_render_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_subviewport", "create_minimap_viewport", "setup_camera_2d", "get_game_screenshot"],
		"workflow_minimap": [
			"setup_subviewport_2d_world size={x:128,y:128}",
			"setup_viewport_texture_rect viewport_path=… parent_path=HUD",
		],
	})


func _parse_vec2i(v: Variant, default: Vector2i = Vector2i(256, 256)) -> Vector2i:
	if v is Dictionary:
		return Vector2i(int(v.get("x", default.x)), int(v.get("y", default.y)))
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return default


func _setup_svc(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var svc := SubViewportContainer.new()
	svc.name = optional_string(params, "name", "SubViewportContainer")
	svc.stretch = optional_bool(params, "stretch", true)
	if params.has("custom_minimum_size"):
		svc.custom_minimum_size = Vector2(_parse_vec2i(params["custom_minimum_size"]))
	elif params.has("size"):
		svc.custom_minimum_size = Vector2(_parse_vec2i(params["size"]))
	add_child_with_undo(parent, svc, root, "MCP: SubViewportContainer")
	var sv := SubViewport.new()
	sv.name = optional_string(params, "viewport_name", "SubViewport")
	var size := _parse_vec2i(params.get("size", {"x": 256, "y": 256}))
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if params.has("transparent_bg"):
		sv.transparent_bg = bool(params["transparent_bg"])
	if params.has("handle_input_locally"):
		sv.handle_input_locally = bool(params["handle_input_locally"])
	add_child_with_undo(svc, sv, root, "MCP: SubViewport under container")
	mark_current_scene_unsaved()
	return success({
		"container_path": str(root.get_path_to(svc)),
		"viewport_path": str(root.get_path_to(sv)),
		"size": {"x": size.x, "y": size.y},
	})


func _setup_sv_2d(params: Dictionary) -> Dictionary:
	## Standalone SubViewport (not in container) for ViewportTexture consumers.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var sv := SubViewport.new()
	sv.name = optional_string(params, "name", "SubViewport")
	var size := _parse_vec2i(params.get("size", {"x": 256, "y": 256}))
	sv.size = size
	sv.transparent_bg = optional_bool(params, "transparent_bg", true)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if optional_bool(params, "disable_3d", true):
		sv.disable_3d = true
	# Optional world content root
	add_child_with_undo(parent, sv, root, "MCP: SubViewport 2D world")
	var world_root: Node2D = null
	if optional_bool(params, "create_world_root", true):
		world_root = Node2D.new()
		world_root.name = optional_string(params, "world_name", "World")
		add_child_with_undo(sv, world_root, root, "MCP: SubViewport world root")
	if optional_bool(params, "add_camera", true) and world_root:
		var cam := Camera2D.new()
		cam.name = "Camera2D"
		cam.enabled = true
		add_child_with_undo(world_root, cam, root, "MCP: SubViewport Camera2D")
	mark_current_scene_unsaved()
	return success({
		"viewport_path": str(root.get_path_to(sv)),
		"world_path": str(root.get_path_to(world_root)) if world_root else "",
		"size": {"x": size.x, "y": size.y},
		"hint": "setup_viewport_texture_rect viewport_path=… or setup_sprite_from_subviewport",
	})


func _setup_vtex_rect(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var vp_path: String = optional_string(params, "viewport_path", "")
	if vp_path.is_empty():
		return error_invalid_params("viewport_path required")
	var vp := find_node_by_path(vp_path)
	if vp == null or not (vp is SubViewport or vp is Viewport):
		return error_not_found("SubViewport at '%s'" % vp_path)
	var tr := TextureRect.new()
	tr.name = optional_string(params, "name", "ViewportPreview")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var vtex := ViewportTexture.new()
	# Viewport path must be set after tree entry for some Godot versions
	add_child_with_undo(parent, tr, root, "MCP: ViewportTexture TextureRect")
	vtex.viewport_path = root.get_path_to(vp)
	tr.texture = vtex
	if params.has("custom_minimum_size"):
		tr.custom_minimum_size = Vector2(_parse_vec2i(params["custom_minimum_size"]))
	elif vp is SubViewport:
		tr.custom_minimum_size = Vector2((vp as SubViewport).size)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(tr)),
		"viewport_path": vp_path,
		"viewport_texture_path": str(vtex.viewport_path),
	})


func _setup_sprite_from_sv(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var vp_path: String = optional_string(params, "viewport_path", "")
	if vp_path.is_empty():
		return error_invalid_params("viewport_path required")
	var vp := find_node_by_path(vp_path)
	if vp == null or not (vp is Viewport):
		return error_not_found("Viewport at '%s'" % vp_path)
	var spr := Sprite2D.new()
	spr.name = optional_string(params, "name", "ViewportSprite")
	add_child_with_undo(parent, spr, root, "MCP: Sprite from SubViewport")
	var vtex := ViewportTexture.new()
	vtex.viewport_path = root.get_path_to(vp)
	spr.texture = vtex
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		spr.position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(spr)),
		"viewport_path": vp_path,
	})


func _setup_bbc(params: Dictionary) -> Dictionary:
	## BackBufferCopy for screen-reading shaders (blur, distortion).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var bbc := BackBufferCopy.new()
	bbc.name = optional_string(params, "name", "BackBufferCopy")
	var mode_name: String = optional_string(params, "copy_mode", "viewport").to_lower()
	match mode_name:
		"disabled":
			bbc.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
		"rect":
			bbc.copy_mode = BackBufferCopy.COPY_MODE_RECT
		_:
			bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	if params.has("rect") and params["rect"] is Dictionary:
		var r: Dictionary = params["rect"]
		bbc.rect = Rect2(
			float(r.get("x", 0)), float(r.get("y", 0)),
			float(r.get("w", r.get("width", 100))), float(r.get("h", r.get("height", 100)))
		)
	add_child_with_undo(parent, bbc, root, "MCP: BackBufferCopy")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(bbc)),
		"copy_mode": mode_name,
		"hint": "Place before CanvasItem that samples screen texture in shader",
	})


func _set_update_mode(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is SubViewport):
		return error_not_found("SubViewport at '%s'" % r0[0])
	var sv: SubViewport = node as SubViewport
	var mode_name: String = optional_string(params, "mode", "when_visible").to_lower()
	var mode := SubViewport.UPDATE_WHEN_VISIBLE
	match mode_name:
		"disabled", "once":
			mode = SubViewport.UPDATE_DISABLED if mode_name == "disabled" else SubViewport.UPDATE_ONCE
		"always":
			mode = SubViewport.UPDATE_ALWAYS
		"when_visible", "visible":
			mode = SubViewport.UPDATE_WHEN_VISIBLE
		"when_parent_visible", "parent":
			mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	sv.render_target_update_mode = mode
	if params.has("size"):
		sv.size = _parse_vec2i(params["size"], sv.size)
	if params.has("transparent_bg"):
		sv.transparent_bg = bool(params["transparent_bg"])
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"mode": mode_name,
		"size": {"x": sv.size.x, "y": sv.size.y},
	})
