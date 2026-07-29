@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## 2D material / canvas item visual surface (human Inspector material + modulate).


func get_commands() -> Dictionary:
	return {
		"set_canvas_item_modulate": _set_canvas_item_modulate,
		"set_canvas_item_self_modulate": _set_canvas_item_self_modulate,
		"set_canvas_item_visibility": _set_canvas_item_visibility,
		"set_sprite_texture": _set_sprite_texture,
		"set_sprite_region": _set_sprite_region,
		"create_canvas_item_material": _create_canvas_item_material,
		"assign_canvas_item_material": _assign_canvas_item_material,
		"set_label_text": _set_label_text,
		"set_button_text": _set_button_text,
		# setup_label canonical in label_richtext_commands
		"setup_button": _setup_button,
		"setup_texture_rect": _setup_texture_rect,
	}


func _parse_color(params: Dictionary, key: String, default: Color) -> Color:
	if not params.has(key):
		return default
	var c = params[key]
	if c is String:
		return Color.html(c) if str(c).begins_with("#") else Color(c)
	if c is Dictionary:
		return Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
	return default


func _set_canvas_item_modulate(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is CanvasItem:
		return error_not_found("CanvasItem at '%s'" % r0[0])
	var col := _parse_color(params, "color", (node as CanvasItem).modulate)
	if params.has("a") or params.has("alpha"):
		col.a = float(params.get("a", params.get("alpha", col.a)))
	set_property_with_undo(node, "modulate", col, "MCP: Set modulate")
	return success({"node_path": r0[0], "modulate": col.to_html(true)})


func _set_canvas_item_self_modulate(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is CanvasItem:
		return error_not_found("CanvasItem")
	var col := _parse_color(params, "color", (node as CanvasItem).self_modulate)
	set_property_with_undo(node, "self_modulate", col, "MCP: Set self_modulate")
	return success({"node_path": r0[0], "self_modulate": col.to_html(true)})


func _set_canvas_item_visibility(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is CanvasItem:
		return error_not_found("CanvasItem")
	var vis: bool = optional_bool(params, "visible", true)
	set_property_with_undo(node, "visible", vis, "MCP: Set visible")
	if params.has("z_index") and "z_index" in node:
		set_property_with_undo(node, "z_index", int(params["z_index"]), "MCP: Set z_index")
	if params.has("z_as_relative") and "z_as_relative" in node:
		node.set("z_as_relative", bool(params["z_as_relative"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "visible": vis})


func _set_sprite_texture(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tex_r := require_res_path(params, "texture_path")
	if tex_r[1] != null:
		return tex_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not (node is Sprite2D or node is Sprite3D or node is TextureRect or node is TextureButton):
		return error_invalid_params("Node must be Sprite2D/3D, TextureRect, or TextureButton")
	var tex: Texture2D = load(tex_r[0]) as Texture2D
	if tex == null:
		return error_not_found("Texture %s" % tex_r[0])
	var prop := "texture"
	set_property_with_undo(node, prop, tex, "MCP: Set texture")
	return success({"node_path": r0[0], "texture_path": tex_r[0]})


func _set_sprite_region(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is Sprite2D:
		return error_not_found("Sprite2D")
	var spr: Sprite2D = node
	spr.region_enabled = optional_bool(params, "enabled", true)
	var x := float(params.get("x", spr.region_rect.position.x))
	var y := float(params.get("y", spr.region_rect.position.y))
	var w := float(params.get("width", params.get("w", spr.region_rect.size.x)))
	var h := float(params.get("height", params.get("h", spr.region_rect.size.y)))
	spr.region_rect = Rect2(x, y, w, h)
	if params.has("hframes"):
		spr.hframes = int(params["hframes"])
	if params.has("vframes"):
		spr.vframes = int(params["vframes"])
	if params.has("frame"):
		spr.frame = int(params["frame"])
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"region_rect": {"x": x, "y": y, "w": w, "h": h},
		"frame": spr.frame,
	})


func _create_canvas_item_material(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var mat := CanvasItemMaterial.new()
	var blend: String = optional_string(params, "blend_mode", "mix")
	match blend:
		"add":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		"sub", "subtract":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		"mul", "multiply":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		"premult_alpha":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		_:
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	var light: String = optional_string(params, "light_mode", "normal")
	match light:
		"unshaded":
			mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		"light_only":
			mat.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
		_:
			mat.light_mode = CanvasItemMaterial.LIGHT_MODE_NORMAL
	if params.has("particles_animation"):
		mat.particles_animation = bool(params["particles_animation"])
	var derr := ensure_parent_dir(res[0])
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(mat, res[0])
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(res[0])
	return success({"path": res[0], "blend_mode": blend, "light_mode": light})


func _assign_canvas_item_material(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mat_r := require_res_path(params, "material_path")
	if mat_r[1] != null:
		return mat_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is CanvasItem:
		return error_not_found("CanvasItem")
	var mat = load(mat_r[0])
	if mat == null:
		return error_not_found(mat_r[0])
	set_property_with_undo(node, "material", mat, "MCP: Assign canvas material")
	return success({"node_path": r0[0], "material_path": mat_r[0]})


func _set_label_text(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var text_r := require_string(params, "text")
	if text_r[1] != null:
		return text_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is Label or node is RichTextLabel or node is LineEdit or node is TextEdit):
		return error_not_found("Label/RichTextLabel/LineEdit/TextEdit")
	if node is RichTextLabel:
		(node as RichTextLabel).text = text_r[0]
	elif "text" in node:
		node.set("text", text_r[0])
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "text": text_r[0]})


func _set_button_text(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var text_r := require_string(params, "text")
	if text_r[1] != null:
		return text_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is BaseButton:
		return error_not_found("BaseButton")
	if "text" in node:
		node.set("text", text_r[0])
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "text": text_r[0]})


func _setup_label(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var label := Label.new()
	label.name = optional_string(params, "name", "Label")
	label.text = optional_string(params, "text", "Label")
	if params.has("horizontal_alignment"):
		match str(params["horizontal_alignment"]):
			"center":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			"right":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if params.has("autowrap"):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if bool(params["autowrap"]) else TextServer.AUTOWRAP_OFF
	add_child_with_undo(parent, label, root, "MCP: Add Label")
	return success({"node_path": str(root.get_path_to(label)), "text": label.text})


func _setup_button(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var btn := Button.new()
	btn.name = optional_string(params, "name", "Button")
	btn.text = optional_string(params, "text", "Button")
	btn.disabled = optional_bool(params, "disabled", false)
	btn.toggle_mode = optional_bool(params, "toggle_mode", false)
	add_child_with_undo(parent, btn, root, "MCP: Add Button")
	return success({"node_path": str(root.get_path_to(btn)), "text": btn.text})


func _setup_texture_rect(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var tr := TextureRect.new()
	tr.name = optional_string(params, "name", "TextureRect")
	var tex_path: String = optional_string(params, "texture_path", "")
	if not tex_path.is_empty():
		if not tex_path.begins_with("res://"):
			tex_path = "res://" + tex_path.trim_prefix("/")
		if ResourceLoader.exists(tex_path):
			tr.texture = load(tex_path)
	var expand: String = optional_string(params, "expand_mode", "ignore_size")
	match expand:
		"fit_width":
			tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		"fit_height":
			tr.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		"fit_width_proportional":
			tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_:
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var stretch: String = optional_string(params, "stretch_mode", "scale")
	match stretch:
		"tile":
			tr.stretch_mode = TextureRect.STRETCH_TILE
		"keep":
			tr.stretch_mode = TextureRect.STRETCH_KEEP
		"keep_centered":
			tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		"keep_aspect":
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		"keep_aspect_centered":
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		"keep_aspect_covered":
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_:
			tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child_with_undo(parent, tr, root, "MCP: Add TextureRect")
	return success({"node_path": str(root.get_path_to(tr)), "texture_path": tex_path})
