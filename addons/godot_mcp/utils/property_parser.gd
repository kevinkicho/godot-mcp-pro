@tool
extends RefCounted

## Parse agent/JSON values into Godot types and serialize back for MCP responses.
## Supports inspector-style strings, dicts, enums, and nested math types.


static func parse_value(value: Variant, target_type: int = TYPE_NIL, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> Variant:
	if value == null:
		return null

	# Enum-by-name before generic int coercion
	if target_type == TYPE_INT and hint == PROPERTY_HINT_ENUM and value is String:
		var enum_val := parse_enum_string(str(value), hint_string)
		if enum_val != null:
			return enum_val

	if target_type == TYPE_NIL:
		return _auto_parse(value)

	match target_type:
		TYPE_BOOL:
			if value is bool: return value
			if value is String: return value.to_lower() in ["true", "1", "yes"]
			return bool(value)
		TYPE_INT:
			if value is String and str(value).is_valid_int():
				return str(value).to_int()
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return str(value)
		TYPE_STRING_NAME:
			return StringName(str(value))
		TYPE_VECTOR2:
			return _parse_vector2(value)
		TYPE_VECTOR2I:
			return _parse_vector2i(value)
		TYPE_VECTOR3:
			return _parse_vector3(value)
		TYPE_VECTOR3I:
			return _parse_vector3i(value)
		TYPE_VECTOR4:
			return _parse_vector4(value)
		TYPE_VECTOR4I:
			return _parse_vector4i(value)
		TYPE_RECT2:
			return _parse_rect2(value)
		TYPE_RECT2I:
			return _parse_rect2i(value)
		TYPE_COLOR:
			return _parse_color(value)
		TYPE_AABB:
			return _parse_aabb(value)
		TYPE_PLANE:
			return _parse_plane(value)
		TYPE_QUATERNION:
			return _parse_quaternion(value)
		TYPE_BASIS:
			return _parse_basis(value)
		TYPE_TRANSFORM2D:
			return _parse_transform2d(value)
		TYPE_TRANSFORM3D:
			return _parse_transform3d(value)
		TYPE_NODE_PATH:
			return NodePath(str(value))
		TYPE_PACKED_BYTE_ARRAY:
			if value is PackedByteArray: return value
			if value is Array:
				var pba := PackedByteArray()
				for x in value:
					pba.append(int(x))
				return pba
			return PackedByteArray()
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			if value is PackedInt32Array or value is PackedInt64Array:
				return value
			if value is Array:
				return PackedInt32Array(value)
			return PackedInt32Array()
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			if value is PackedFloat32Array or value is PackedFloat64Array:
				return value
			if value is Array:
				var pfa := PackedFloat32Array()
				for x in value:
					pfa.append(float(x))
				return pfa
			return PackedFloat32Array()
		TYPE_PACKED_STRING_ARRAY:
			if value is PackedStringArray: return value
			if value is Array:
				var psa := PackedStringArray()
				for x in value:
					psa.append(str(x))
				return psa
			return PackedStringArray()
		TYPE_PACKED_VECTOR2_ARRAY:
			if value is PackedVector2Array: return value
			if value is Array:
				var out := PackedVector2Array()
				for x in value:
					out.append(_parse_vector2(x))
				return out
			return PackedVector2Array()
		TYPE_PACKED_VECTOR3_ARRAY:
			if value is PackedVector3Array: return value
			if value is Array:
				var out := PackedVector3Array()
				for x in value:
					out.append(_parse_vector3(x))
				return out
			return PackedVector3Array()
		TYPE_PACKED_COLOR_ARRAY:
			if value is PackedColorArray: return value
			if value is Array:
				var out := PackedColorArray()
				for x in value:
					out.append(_parse_color(x))
				return out
			return PackedColorArray()
		TYPE_ARRAY:
			if value is Array: return value
			return [value]
		TYPE_DICTIONARY:
			if value is Dictionary: return value
			return {}
		TYPE_OBJECT:
			if value is Object:
				return value
			if value is String:
				var s: String = value
				if (s.begins_with("res://") or s.begins_with("uid://")) and ResourceLoader.exists(s):
					return ResourceLoader.load(s)
				return null
			return value
		_:
			return value


## Parse "Walk,Run,Jump" or "Walk:0,Run:1,Jump:2" enum hint against a name or index string.
static func parse_enum_string(value: String, hint_string: String) -> Variant:
	if hint_string.is_empty():
		return null
	var trimmed := value.strip_edges()
	var parts := hint_string.split(",")
	# Numeric index
	if trimmed.is_valid_int():
		var idx := trimmed.to_int()
		if idx >= 0 and idx < parts.size():
			return _enum_value_at(parts, idx)
		return idx
	# Name match (with optional :value suffix in hint)
	for i in range(parts.size()):
		var piece := parts[i].strip_edges()
		var name_part := piece
		var colon := piece.find(":")
		if colon >= 0:
			name_part = piece.substr(0, colon).strip_edges()
		if name_part == trimmed or name_part.to_lower() == trimmed.to_lower():
			return _enum_value_at(parts, i)
	return null


static func _enum_value_at(parts: PackedStringArray, index: int) -> int:
	var piece := parts[index].strip_edges()
	var colon := piece.find(":")
	if colon >= 0:
		var v := piece.substr(colon + 1).strip_edges()
		if v.is_valid_int():
			return v.to_int()
	return index


static func enum_options(hint_string: String) -> Array:
	var out: Array = []
	if hint_string.is_empty():
		return out
	for piece in hint_string.split(","):
		var p := str(piece).strip_edges()
		var colon := p.find(":")
		if colon >= 0:
			out.append({
				"name": p.substr(0, colon).strip_edges(),
				"value": int(p.substr(colon + 1).strip_edges()) if p.substr(colon + 1).strip_edges().is_valid_int() else p.substr(colon + 1),
			})
		else:
			out.append({"name": p, "value": out.size()})
	return out


static func usage_flags(usage: int) -> Dictionary:
	return {
		"editor": (usage & PROPERTY_USAGE_EDITOR) != 0,
		"storage": (usage & PROPERTY_USAGE_STORAGE) != 0,
		"category": (usage & PROPERTY_USAGE_CATEGORY) != 0,
		"group": (usage & PROPERTY_USAGE_GROUP) != 0,
		"subgroup": (usage & PROPERTY_USAGE_SUBGROUP) != 0,
		"internal": (usage & PROPERTY_USAGE_INTERNAL) != 0,
		"script_variable": (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0,
	}


static func _auto_parse(value: Variant) -> Variant:
	if not value is String:
		return value

	var s: String = value

	if s == "true": return true
	if s == "false": return false
	if s.is_valid_int(): return s.to_int()
	if s.is_valid_float(): return s.to_float()

	if s.begins_with("Vector2i("):
		return _parse_vector2i(s)
	if s.begins_with("Vector2("):
		return _parse_vector2(s)
	if s.begins_with("Vector3i("):
		return _parse_vector3i(s)
	if s.begins_with("Vector3("):
		return _parse_vector3(s)
	if s.begins_with("Vector4i("):
		return _parse_vector4i(s)
	if s.begins_with("Vector4("):
		return _parse_vector4(s)
	if s.begins_with("Color(") or s.begins_with("#"):
		return _parse_color(s)
	if s.begins_with("Rect2i("):
		return _parse_rect2i(s)
	if s.begins_with("Rect2("):
		return _parse_rect2(s)
	if s.begins_with("Quaternion("):
		return _parse_quaternion(s)
	if (s.begins_with("res://") or s.begins_with("uid://")) and ResourceLoader.exists(s):
		return ResourceLoader.load(s)

	return s


static func _extract_numbers(s: String) -> PackedFloat64Array:
	var cleaned := s
	for prefix in [
		"Transform3D(", "Transform2D(", "Quaternion(", "Basis(", "AABB(", "Plane(",
		"Vector4i(", "Vector4(", "Vector3i(", "Vector3(", "Vector2i(", "Vector2(",
		"Rect2i(", "Rect2(", "Color(", "(",
	]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length())
			break
	cleaned = cleaned.trim_suffix(")")
	cleaned = cleaned.strip_edges()
	var parts := cleaned.split(",")
	var numbers: PackedFloat64Array = []
	for part in parts:
		var t := part.strip_edges()
		if t.is_empty():
			continue
		numbers.append(t.to_float())
	return numbers


static func _parse_vector2(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	var nums := _extract_numbers(str(value))
	if nums.size() >= 2:
		return Vector2(nums[0], nums[1])
	return Vector2.ZERO


static func _parse_vector2i(value: Variant) -> Vector2i:
	var v := _parse_vector2(value)
	return Vector2i(int(v.x), int(v.y))


static func _parse_vector3(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0)))
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	var nums := _extract_numbers(str(value))
	if nums.size() >= 3:
		return Vector3(nums[0], nums[1], nums[2])
	return Vector3.ZERO


static func _parse_vector3i(value: Variant) -> Vector3i:
	var v := _parse_vector3(value)
	return Vector3i(int(v.x), int(v.y), int(v.z))


static func _parse_vector4(value: Variant) -> Vector4:
	if value is Vector4: return value
	if value is Dictionary:
		return Vector4(
			float(value.get("x", 0)), float(value.get("y", 0)),
			float(value.get("z", 0)), float(value.get("w", 0))
		)
	if value is Array and value.size() >= 4:
		return Vector4(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	var nums := _extract_numbers(str(value))
	if nums.size() >= 4:
		return Vector4(nums[0], nums[1], nums[2], nums[3])
	return Vector4.ZERO


static func _parse_vector4i(value: Variant) -> Vector4i:
	var v := _parse_vector4(value)
	return Vector4i(int(v.x), int(v.y), int(v.z), int(v.w))


static func _parse_rect2(value: Variant) -> Rect2:
	if value is Rect2: return value
	if value is Dictionary:
		return Rect2(
			float(value.get("x", 0)), float(value.get("y", 0)),
			float(value.get("w", value.get("width", 0))),
			float(value.get("h", value.get("height", 0)))
		)
	var nums := _extract_numbers(str(value))
	if nums.size() >= 4:
		return Rect2(nums[0], nums[1], nums[2], nums[3])
	return Rect2()


static func _parse_rect2i(value: Variant) -> Rect2i:
	var r := _parse_rect2(value)
	return Rect2i(int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y))


static func _parse_color(value: Variant) -> Color:
	if value is Color: return value
	if value is Dictionary:
		if value.has("html"):
			return Color.html(str(value["html"]))
		return Color(
			float(value.get("r", 0)), float(value.get("g", 0)),
			float(value.get("b", 0)), float(value.get("a", 1))
		)
	var s := str(value)
	if s.begins_with("#"):
		return Color.html(s)
	if s.begins_with("Color("):
		var nums := _extract_numbers(s)
		match nums.size():
			3: return Color(nums[0], nums[1], nums[2])
			4: return Color(nums[0], nums[1], nums[2], nums[3])
	if Color.html_is_valid(s):
		return Color.html(s)
	return Color.WHITE


static func _parse_aabb(value: Variant) -> AABB:
	if value is AABB: return value
	if value is Dictionary:
		var pos := _parse_vector3(value.get("position", value.get("pos", {})))
		var size := _parse_vector3(value.get("size", {}))
		return AABB(pos, size)
	var nums := _extract_numbers(str(value))
	if nums.size() >= 6:
		return AABB(Vector3(nums[0], nums[1], nums[2]), Vector3(nums[3], nums[4], nums[5]))
	return AABB()


static func _parse_plane(value: Variant) -> Plane:
	if value is Plane: return value
	if value is Dictionary:
		return Plane(
			float(value.get("x", value.get("a", 0))),
			float(value.get("y", value.get("b", 0))),
			float(value.get("z", value.get("c", 0))),
			float(value.get("d", 0))
		)
	var nums := _extract_numbers(str(value))
	if nums.size() >= 4:
		return Plane(nums[0], nums[1], nums[2], nums[3])
	return Plane()


static func _parse_quaternion(value: Variant) -> Quaternion:
	if value is Quaternion: return value
	if value is Dictionary:
		if value.has("x"):
			return Quaternion(
				float(value.get("x", 0)), float(value.get("y", 0)),
				float(value.get("z", 0)), float(value.get("w", 1))
			)
		# Euler degrees shortcut
		if value.has("euler") or value.has("degrees"):
			var e := _parse_vector3(value.get("euler", value.get("degrees")))
			return Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
	var nums := _extract_numbers(str(value))
	if nums.size() >= 4:
		return Quaternion(nums[0], nums[1], nums[2], nums[3])
	return Quaternion.IDENTITY


static func _parse_basis(value: Variant) -> Basis:
	if value is Basis: return value
	if value is Dictionary:
		if value.has("x") and value.has("y") and value.has("z"):
			return Basis(_parse_vector3(value["x"]), _parse_vector3(value["y"]), _parse_vector3(value["z"]))
		if value.has("euler"):
			var e := _parse_vector3(value["euler"])
			return Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
	return Basis.IDENTITY


static func _parse_transform2d(value: Variant) -> Transform2D:
	if value is Transform2D: return value
	if value is Dictionary:
		var origin := _parse_vector2(value.get("origin", value.get("position", {"x": 0, "y": 0})))
		if value.has("rotation_degrees") or value.has("rotation"):
			var rot := float(value.get("rotation_degrees", rad_to_deg(float(value.get("rotation", 0)))))
			var scale := _parse_vector2(value.get("scale", {"x": 1, "y": 1}))
			var t := Transform2D(deg_to_rad(rot), origin)
			t = t.scaled(scale)
			return t
		if value.has("x") and value.has("y"):
			return Transform2D(_parse_vector2(value["x"]), _parse_vector2(value["y"]), origin)
	return Transform2D.IDENTITY


static func _parse_transform3d(value: Variant) -> Transform3D:
	if value is Transform3D: return value
	if value is Dictionary:
		var origin := _parse_vector3(value.get("origin", value.get("position", {})))
		if value.has("basis"):
			return Transform3D(_parse_basis(value["basis"]), origin)
		if value.has("euler") or value.has("rotation_degrees"):
			var e := _parse_vector3(value.get("euler", value.get("rotation_degrees")))
			var b := Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
			if value.has("scale"):
				b = b.scaled(_parse_vector3(value["scale"]))
			return Transform3D(b, origin)
	return Transform3D.IDENTITY


## Serialize a Variant to JSON-safe representation
static func serialize_value(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_VECTOR2:
			var v: Vector2 = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR2I:
			var v2i: Vector2i = value
			return {"x": v2i.x, "y": v2i.y}
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return {"x": v3.x, "y": v3.y, "z": v3.z}
		TYPE_VECTOR3I:
			var v3i: Vector3i = value
			return {"x": v3i.x, "y": v3i.y, "z": v3i.z}
		TYPE_VECTOR4:
			var v4: Vector4 = value
			return {"x": v4.x, "y": v4.y, "z": v4.z, "w": v4.w}
		TYPE_VECTOR4I:
			var v4i: Vector4i = value
			return {"x": v4i.x, "y": v4i.y, "z": v4i.z, "w": v4i.w}
		TYPE_RECT2:
			var r: Rect2 = value
			return {"x": r.position.x, "y": r.position.y, "width": r.size.x, "height": r.size.y}
		TYPE_RECT2I:
			var ri: Rect2i = value
			return {"x": ri.position.x, "y": ri.position.y, "width": ri.size.x, "height": ri.size.y}
		TYPE_COLOR:
			var c: Color = value
			return {"r": c.r, "g": c.g, "b": c.b, "a": c.a, "html": "#" + c.to_html()}
		TYPE_AABB:
			var ab: AABB = value
			return {"position": serialize_value(ab.position), "size": serialize_value(ab.size)}
		TYPE_PLANE:
			var pl: Plane = value
			return {"x": pl.normal.x, "y": pl.normal.y, "z": pl.normal.z, "d": pl.d}
		TYPE_QUATERNION:
			var q: Quaternion = value
			return {"x": q.x, "y": q.y, "z": q.z, "w": q.w}
		TYPE_BASIS:
			var b: Basis = value
			return {"x": serialize_value(b.x), "y": serialize_value(b.y), "z": serialize_value(b.z)}
		TYPE_TRANSFORM2D:
			var t2: Transform2D = value
			return {
				"x": serialize_value(t2.x),
				"y": serialize_value(t2.y),
				"origin": serialize_value(t2.origin),
			}
		TYPE_TRANSFORM3D:
			var t3: Transform3D = value
			return {
				"basis": serialize_value(t3.basis),
				"origin": serialize_value(t3.origin),
			}
		TYPE_NODE_PATH:
			return str(value)
		TYPE_STRING_NAME:
			return str(value)
		TYPE_OBJECT:
			if value is Resource:
				var res: Resource = value
				var info := {"type": res.get_class(), "path": res.resource_path}
				# Nested resource fingerprint for agents
				if res.resource_path.is_empty():
					info["sub_resource"] = true
				return info
			if value is Node:
				return {"type": value.get_class(), "node": str(value.name)}
			return {"type": value.get_class() if value else "null", "object": str(value)}
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(serialize_value(item))
			return arr
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var result: Dictionary = {}
			for key in dict:
				result[str(key)] = serialize_value(dict[key])
			return result
		_:
			return value


## Build inspector-style property catalog entry for one PropertyInfo + live object.
static func property_entry(obj: Object, prop_info: Dictionary, path_prefix: String = "") -> Dictionary:
	var prop_name: String = prop_info["name"]
	var full_path := prop_name if path_prefix.is_empty() else "%s.%s" % [path_prefix, prop_name]
	var usage: int = prop_info["usage"]
	var entry := {
		"name": prop_name,
		"path": full_path,
		"type": type_string(prop_info["type"]),
		"type_id": prop_info["type"],
		"hint": prop_info["hint"],
		"hint_string": prop_info["hint_string"],
		"usage": usage,
		"usage_flags": usage_flags(usage),
		"class_name": str(prop_info.get("class_name", "")),
	}
	if (usage & PROPERTY_USAGE_CATEGORY) or (usage & PROPERTY_USAGE_GROUP) or (usage & PROPERTY_USAGE_SUBGROUP):
		entry["header"] = true
		entry["value"] = null
		return entry
	if prop_name in obj:
		entry["value"] = serialize_value(obj.get(prop_name))
		if obj is Node and (obj as Node).property_can_revert(prop_name):
			entry["can_revert"] = true
			entry["revert_value"] = serialize_value((obj as Node).property_get_revert(prop_name))
		elif obj.has_method("property_can_revert") and obj.property_can_revert(prop_name):
			entry["can_revert"] = true
			entry["revert_value"] = serialize_value(obj.property_get_revert(prop_name))
	else:
		entry["value"] = null
	if prop_info["hint"] == PROPERTY_HINT_ENUM and str(prop_info["hint_string"]).length() > 0:
		entry["enum_options"] = enum_options(str(prop_info["hint_string"]))
	if prop_info["hint"] == PROPERTY_HINT_FLAGS and str(prop_info["hint_string"]).length() > 0:
		entry["flag_options"] = str(prop_info["hint_string"]).split(",")
	if prop_info["hint"] == PROPERTY_HINT_RANGE and str(prop_info["hint_string"]).length() > 0:
		entry["range"] = str(prop_info["hint_string"])
		var rp := str(prop_info["hint_string"]).split(",")
		if rp.size() >= 2:
			entry["range_min"] = rp[0].to_float()
			entry["range_max"] = rp[1].to_float()
		if rp.size() >= 3:
			entry["range_step"] = rp[2].to_float()
	if prop_info["type"] == TYPE_OBJECT:
		if prop_info["hint_string"]:
			entry["object_class"] = prop_info["hint_string"]
		var cur = obj.get(prop_name) if prop_name in obj else null
		if cur is Resource:
			entry["resource_type"] = cur.get_class()
			entry["resource_path"] = cur.resource_path
			entry["nested_tunable"] = true
	return entry
