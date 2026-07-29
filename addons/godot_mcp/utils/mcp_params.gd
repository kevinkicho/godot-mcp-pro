@tool
extends RefCounted
class_name MCPParams

## Shared MCP parameter parsers — used by base_command and command modules.


static func parse_vec2(v: Variant, default: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Vector2:
		return v
	if v is Dictionary:
		return Vector2(float(v.get("x", default.x)), float(v.get("y", default.y)))
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return default


static func parse_vec3(v: Variant, default: Vector3 = Vector3.ZERO) -> Vector3:
	if v is Vector3:
		return v
	if v is Dictionary:
		return Vector3(
			float(v.get("x", default.x)),
			float(v.get("y", default.y)),
			float(v.get("z", default.z))
		)
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return default


static func parse_vec2i(v: Variant, default: Vector2i = Vector2i.ZERO) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Dictionary:
		return Vector2i(int(v.get("x", default.x)), int(v.get("y", default.y)))
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return default


static func parse_color(v: Variant, default: Color = Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is String:
		var s := str(v)
		return Color.html(s) if s.begins_with("#") else Color(s)
	if v is Dictionary:
		return Color(
			float(v.get("r", 1)),
			float(v.get("g", 1)),
			float(v.get("b", 1)),
			float(v.get("a", 1))
		)
	return default


static func parse_rect2(v: Variant, default: Rect2 = Rect2()) -> Rect2:
	if v is Rect2:
		return v
	if v is Dictionary:
		var x := float(v.get("x", v.get("left", default.position.x)))
		var y := float(v.get("y", v.get("top", default.position.y)))
		var w := float(v.get("w", v.get("width", default.size.x)))
		var h := float(v.get("h", v.get("height", default.size.y)))
		if v.has("right") and not v.has("w") and not v.has("width"):
			w = float(v["right"]) - x
		if v.has("bottom") and not v.has("h") and not v.has("height"):
			h = float(v["bottom"]) - y
		return Rect2(x, y, w, h)
	return default
