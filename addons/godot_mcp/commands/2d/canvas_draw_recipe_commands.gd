@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## CanvasItem _draw recipe scripts — fills the custom-draw gap agents hit for debug/UI overlays.


func get_commands() -> Dictionary:
	return {
		"list_canvas_draw_recipes": _list_recipes,
		"create_canvas_draw_script": _create_draw_script,
		"setup_canvas_draw_node": _setup_draw_node,
		"list_canvas_draw_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_script", "attach_script", "setup_line_2d", "setup_polygon_2d"],
		"docs": "https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html",
	})


func _list_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"recipes": {
			"grid": "Draw a 2D debug grid",
			"crosshair": "Centered crosshair",
			"circle_ring": "Ring / circle outline",
			"rect_border": "Rectangle border",
			"polyline": "Open polyline from points export",
			"health_bar": "World-space HP bar above node",
			"debug_bounds": "Draw Rect2 bounds from export size",
			"radial_sector": "Pie / FOV cone wedge",
			"dashed_line": "Dashed line between two points",
			"blank": "Empty _draw stub with queue_redraw helpers",
		},
	})


func _script_for_recipe(recipe: String, class_name_str: String) -> String:
	var cn := class_name_str
	var header := "@tool\nextends Node2D\n"
	if not cn.is_empty():
		header += "class_name %s\n" % cn
	header += "\n"
	match recipe.to_lower():
		"grid":
			return header + """@export var cell_size: Vector2 = Vector2(32, 32)
@export var grid_size: Vector2i = Vector2i(20, 15)
@export var color: Color = Color(1, 1, 1, 0.25)
@export var origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var w := float(grid_size.x) * cell_size.x
	var h := float(grid_size.y) * cell_size.y
	for x in range(grid_size.x + 1):
		var px := origin.x + float(x) * cell_size.x
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + h), color, 1.0)
	for y in range(grid_size.y + 1):
		var py := origin.y + float(y) * cell_size.y
		draw_line(Vector2(origin.x, py), Vector2(origin.x + w, py), color, 1.0)
"""
		"crosshair":
			return header + """@export var size: float = 16.0
@export var color: Color = Color(0, 1, 0, 0.9)
@export var thickness: float = 1.5

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-size, 0), Vector2(size, 0), color, thickness)
	draw_line(Vector2(0, -size), Vector2(0, size), color, thickness)
	draw_circle(Vector2.ZERO, 2.0, color)
"""
		"circle_ring":
			return header + """@export var radius: float = 48.0
@export var color: Color = Color(1, 0.8, 0.2, 0.9)
@export var width: float = 2.0
@export var filled: bool = false

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if filled:
		draw_circle(Vector2.ZERO, radius, color)
	else:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, width, true)
"""
		"rect_border":
			return header + """@export var size: Vector2 = Vector2(64, 48)
@export var color: Color = Color(1, 1, 1, 0.85)
@export var width: float = 2.0
@export var filled: bool = false
@export var centered: bool = true

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var r := Rect2(-size * 0.5, size) if centered else Rect2(Vector2.ZERO, size)
	if filled:
		draw_rect(r, color, true)
	else:
		draw_rect(r, color, false, width)
"""
		"polyline":
			return header + """@export var points: PackedVector2Array = PackedVector2Array([
	Vector2(0, 0), Vector2(32, -16), Vector2(64, 0)
])
@export var color: Color = Color(0.3, 0.8, 1.0, 1.0)
@export var width: float = 2.0
@export var closed: bool = false

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	draw_polyline(points, color, width, true)
	if closed and points.size() > 2:
		draw_line(points[points.size() - 1], points[0], color, width, true)
"""
		"health_bar":
			return header + """@export var max_hp: float = 100.0
@export var hp: float = 100.0
@export var bar_size: Vector2 = Vector2(40, 6)
@export var offset: Vector2 = Vector2(0, -24)
@export var bg_color: Color = Color(0.1, 0.1, 0.1, 0.8)
@export var fg_color: Color = Color(0.2, 0.9, 0.3, 1.0)
@export var border_color: Color = Color(1, 1, 1, 0.5)

func _ready() -> void:
	queue_redraw()

func set_hp(value: float) -> void:
	hp = clampf(value, 0.0, max_hp)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(offset - bar_size * 0.5, bar_size)
	draw_rect(r, bg_color, true)
	var ratio := 0.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)
	var fg := Rect2(r.position, Vector2(r.size.x * ratio, r.size.y))
	draw_rect(fg, fg_color, true)
	draw_rect(r, border_color, false, 1.0)
"""
		"debug_bounds":
			return header + """@export var size: Vector2 = Vector2(32, 32)
@export var color: Color = Color(1, 0, 0, 0.6)
@export var centered: bool = true

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var r := Rect2(-size * 0.5, size) if centered else Rect2(Vector2.ZERO, size)
	draw_rect(r, color, false, 1.0)
	draw_line(r.position, r.position + r.size, color, 1.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), color, 1.0)
"""
		"radial_sector":
			return header + """@export var radius: float = 80.0
@export var angle_degrees: float = 60.0
@export var rotation_offset_degrees: float = -90.0
@export var color: Color = Color(1, 1, 0, 0.25)
@export var outline_color: Color = Color(1, 1, 0, 0.8)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var half := deg_to_rad(angle_degrees) * 0.5
	var base := deg_to_rad(rotation_offset_degrees)
	var pts := PackedVector2Array([Vector2.ZERO])
	var steps := 24
	for i in range(steps + 1):
		var t := lerpf(-half, half, float(i) / float(steps))
		pts.append(Vector2.from_angle(base + t) * radius)
	draw_colored_polygon(pts, color)
	draw_polyline(pts, outline_color, 1.5, true)
"""
		"dashed_line":
			return header + """@export var from_point: Vector2 = Vector2.ZERO
@export var to_point: Vector2 = Vector2(64, 0)
@export var dash_length: float = 6.0
@export var gap_length: float = 4.0
@export var color: Color = Color(1, 1, 1, 0.9)
@export var width: float = 2.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var delta := to_point - from_point
	var total := delta.length()
	if total <= 0.001:
		return
	var dir := delta / total
	var pos := 0.0
	var drawing := true
	while pos < total:
		var seg := dash_length if drawing else gap_length
		var a := from_point + dir * pos
		var b := from_point + dir * minf(pos + seg, total)
		if drawing:
			draw_line(a, b, color, width, true)
		pos += seg
		drawing = not drawing
"""
		_:
			return header + """# Blank custom draw — call queue_redraw() when exports change.

@export var color: Color = Color.WHITE

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# draw_circle(Vector2.ZERO, 8.0, color)
	pass
"""


func _create_draw_script(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var recipe: String = optional_string(params, "recipe", "blank")
	var class_name_str: String = optional_string(params, "class_name", "")
	var content := _script_for_recipe(recipe, class_name_str)
	var overwrite: bool = optional_bool(params, "overwrite", false)
	var wr := write_script_file(path, content, overwrite)
	if wr.has("error"):
		return wr
	return success({
		"path": path,
		"recipe": recipe,
		"class_name": class_name_str,
		"hint": "setup_canvas_draw_node path=… OR attach_script",
	})


func _setup_draw_node(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var recipe: String = optional_string(params, "recipe", "grid")
	var script_path: String = optional_string(params, "script_path", "")
	if script_path.is_empty():
		script_path = "res://scripts/draw_%s.gd" % recipe.to_lower()
	# Ensure script exists
	if not FileAccess.file_exists(script_path) or optional_bool(params, "overwrite_script", false):
		var created := _create_draw_script({
			"path": script_path,
			"recipe": recipe,
			"class_name": optional_string(params, "class_name", ""),
			"overwrite": true,
		})
		if created.has("error"):
			return created
	var node := Node2D.new()
	node.name = optional_string(params, "name", "Draw_%s" % recipe.capitalize())
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		node.position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	var script_res = load(script_path)
	if script_res:
		node.set_script(script_res)
	add_child_with_undo(parent, node, root, "MCP: Canvas draw node")
	# Apply simple exports
	for key in ["radius", "size", "hp", "max_hp", "width", "cell_size"]:
		if params.has(key) and key in node:
			node.set(key, params[key])
	if params.has("color") and "color" in node:
		var c: String = str(params["color"])
		node.set("color", Color.html(c) if c.begins_with("#") else Color(c))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"script_path": script_path,
		"recipe": recipe,
	})
