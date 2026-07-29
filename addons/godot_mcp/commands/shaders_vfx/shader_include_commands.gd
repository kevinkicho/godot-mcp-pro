@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Shader include libraries (.gdshaderinc) — shaders docs gap.


func get_commands() -> Dictionary:
	return {
		"create_shader_include": _create_shader_include,
		"list_shader_includes": _list_shader_includes,
		"shader_add_include": _shader_add_include,
		"create_shader_include_library_preset": _create_shader_include_library_preset,
		"list_shader_include_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_shader", "edit_shader", "assign_shader_material", "set_shader_param"],
		"flow": [
			"create_shader_include_library_preset",
			"create_shader path=… then shader_add_include",
		],
	})


func _create_shader_include(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://shaders/includes/common.gdshaderinc")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not path.ends_with(".gdshaderinc") and not path.ends_with(".gdshader"):
		path += ".gdshaderinc"
	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var content: String = optional_string(params, "content", "")
	if content.is_empty():
		var preset: String = optional_string(params, "preset", "common")
		content = _preset_content(preset)
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write include")
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "bytes": content.length()})


func _preset_content(preset: String) -> String:
	match preset.to_lower():
		"math":
			return """// MCP math helpers for .gdshader
#ifndef MCP_MATH_INC
#define MCP_MATH_INC
float mcp_remap(float v, float a, float b, float c, float d) {
	return c + (v - a) * (d - c) / max(b - a, 0.0001);
}
float mcp_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}
#endif
"""
		"noise":
			return """// MCP simple hash noise (not simplex)
#ifndef MCP_NOISE_INC
#define MCP_NOISE_INC
float mcp_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float mcp_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = mcp_hash(i);
	float b = mcp_hash(i + vec2(1.0, 0.0));
	float c = mcp_hash(i + vec2(0.0, 1.0));
	float d = mcp_hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
#endif
"""
		"tonemap":
			return """// MCP ACES-ish filmic helpers
#ifndef MCP_TONEMAP_INC
#define MCP_TONEMAP_INC
vec3 mcp_aces(vec3 x) {
	float a = 2.51;
	float b = 0.03;
	float c = 2.43;
	float d = 0.59;
	float e = 0.14;
	return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}
#endif
"""
		_:
			return """// MCP common shader include
#ifndef MCP_COMMON_INC
#define MCP_COMMON_INC
const float MCP_PI = 3.14159265359;
float mcp_saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3 mcp_saturate3(vec3 x) { return clamp(x, 0.0, 1.0); }
#endif
"""


func _list_shader_includes(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	var max_n: int = clampi(optional_int(params, "max", 100), 1, 500)
	var out: Array = []
	_scan(root_path, out, max_n)
	return success({"includes": out, "count": out.size()})


func _scan(dir_path: String, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.rstrip("/") + "/" + name if dir_path != "res://" else "res://" + name
		if dir.current_is_dir():
			if name != ".godot":
				_scan(full, out, max_n)
		elif name.ends_with(".gdshaderinc") or name.ends_with(".glslinc"):
			out.append(full)
		name = dir.get_next()
		if out.size() >= max_n:
			break
	dir.list_dir_end()


func _shader_add_include(params: Dictionary) -> Dictionary:
	## Insert #include "res://..." after shader_type line if missing.
	var shader_r := require_res_path(params, "shader_path")
	if shader_r[1] != null:
		return shader_r[1]
	var include_r := require_res_path(params, "include_path")
	if include_r[1] != null:
		return include_r[1]
	var shader_path: String = shader_r[0]
	var include_path: String = include_r[0]
	if not FileAccess.file_exists(shader_path):
		return error_not_found(shader_path)
	var f := FileAccess.open(shader_path, FileAccess.READ)
	if f == null:
		return error_internal("read failed")
	var text := f.get_as_text()
	f.close()
	var inc_line := '#include "%s"' % include_path
	if text.contains(include_path):
		return success({"shader_path": shader_path, "already_included": true, "include_path": include_path})
	# Insert after first shader_type line
	var lines := text.split("\n")
	var out_lines: PackedStringArray = PackedStringArray()
	var inserted := false
	for i in range(lines.size()):
		out_lines.append(lines[i])
		if not inserted and lines[i].strip_edges().begins_with("shader_type"):
			out_lines.append(inc_line)
			inserted = true
	if not inserted:
		out_lines.insert(0, inc_line)
	var new_text := "\n".join(out_lines)
	var w := FileAccess.open(shader_path, FileAccess.WRITE)
	if w == null:
		return error_internal("write failed")
	w.store_string(new_text)
	w.close()
	EditorInterface.get_resource_filesystem().update_file(shader_path)
	return success({"shader_path": shader_path, "include_path": include_path, "inserted": true})


func _create_shader_include_library_preset(params: Dictionary) -> Dictionary:
	var dir: String = optional_string(params, "dir", "res://shaders/includes")
	if not dir.begins_with("res://"):
		dir = "res://" + dir.trim_prefix("/")
	var created: Array = []
	for preset in ["common", "math", "noise", "tonemap"]:
		var path := dir.rstrip("/") + "/%s.gdshaderinc" % preset
		var r := _create_shader_include({"path": path, "preset": preset, "overwrite": optional_bool(params, "overwrite", false)})
		if r.has("result"):
			created.append(path)
		elif r.has("error") and optional_bool(params, "overwrite", false) == false:
			# exists is ok
			if FileAccess.file_exists(path):
				created.append(path)
	return success({"dir": dir, "files": created, "count": created.size()})
