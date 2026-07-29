@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Shader presets + VFX helpers for polished 2D/3D games.


func get_commands() -> Dictionary:
	return {
		"create_shader_preset": _create_shader_preset,
		"list_shader_presets": _list_shader_presets,
		"apply_canvas_shader_to_node": _apply_canvas_shader_to_node,
		"apply_spatial_shader_to_mesh": _apply_spatial_shader_to_mesh,
		"setup_trail_vfx": _setup_trail_vfx,
		"setup_flash_hurt_vfx": _setup_flash_hurt_vfx,
		"setup_screen_fade_overlay": _setup_screen_fade_overlay,
		"create_dissolve_shader": _create_dissolve_shader,
		"create_outline_shader": _create_outline_shader,
		"create_hit_stop_script": _create_hit_stop_script,
	}


func _list_shader_presets(_params: Dictionary) -> Dictionary:
	return success({
		"canvas_item": ["flash_white", "outline_2d", "color_grade", "pixelate", "wave_distort", "hurt_flash"],
		"spatial": ["dissolve", "hologram", "fresnel_glow", "toon_simple", "triplanar_terrain"],
		"vfx_nodes": ["setup_trail_vfx", "setup_flash_hurt_vfx", "setup_screen_fade_overlay"],
	})



func _shader_source(preset: String) -> Dictionary:
	## Returns {type, code}
	match preset:
		"flash_white", "hurt_flash":
			return {"type": "canvas_item", "code": """shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = mix(c, vec4(flash_color.rgb, c.a), flash);
}
"""}
		"outline_2d":
			return {"type": "canvas_item", "code": """shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0,0,0,1);
uniform float outline_width : hint_range(0.0, 16.0) = 1.0;
void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	float a = texture(TEXTURE, UV).a;
	float outline = 0.0;
	outline += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
	outline = min(outline, 1.0);
	vec4 c = texture(TEXTURE, UV);
	COLOR = mix(vec4(outline_color.rgb, outline * outline_color.a), c, c.a);
}
"""}
		"pixelate":
			return {"type": "canvas_item", "code": """shader_type canvas_item;
uniform float pixel_size : hint_range(1.0, 64.0) = 4.0;
void fragment() {
	vec2 uv = floor(UV / TEXTURE_PIXEL_SIZE / pixel_size) * TEXTURE_PIXEL_SIZE * pixel_size;
	COLOR = texture(TEXTURE, uv);
}
"""}
		"wave_distort":
			return {"type": "canvas_item", "code": """shader_type canvas_item;
uniform float amplitude : hint_range(0.0, 0.2) = 0.02;
uniform float frequency : hint_range(0.0, 40.0) = 10.0;
uniform float speed : hint_range(0.0, 20.0) = 4.0;
void fragment() {
	vec2 uv = UV;
	uv.x += sin(UV.y * frequency + TIME * speed) * amplitude;
	COLOR = texture(TEXTURE, uv);
}
"""}
		"color_grade":
			return {"type": "canvas_item", "code": """shader_type canvas_item;
uniform vec4 multiply : source_color = vec4(1.0);
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * multiply;
	c.rgb = (c.rgb - 0.5) * contrast + 0.5;
	COLOR = c;
}
"""}
		"dissolve":
			return {"type": "spatial", "code": """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color;
uniform sampler2D noise_tex;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
void fragment() {
	vec4 alb = texture(albedo_tex, UV);
	float n = texture(noise_tex, UV).r;
	float d = dissolve_amount;
	if (n < d) discard;
	float edge = smoothstep(d, d + edge_width, n);
	ALBEDO = mix(edge_color.rgb, alb.rgb, edge);
	ALPHA = alb.a;
}
"""}
		"hologram":
			return {"type": "spatial", "code": """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform vec4 color : source_color = vec4(0.2, 0.9, 1.0, 0.6);
uniform float scan_speed = 2.0;
void fragment() {
	float scan = sin((UV.y + TIME * scan_speed) * 40.0) * 0.5 + 0.5;
	ALBEDO = color.rgb;
	ALPHA = color.a * (0.5 + 0.5 * scan);
	EMISSION = color.rgb * 0.8;
}
"""}
		"fresnel_glow":
			return {"type": "spatial", "code": """shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);
uniform vec4 glow_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float power : hint_range(0.5, 8.0) = 3.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = base_color.rgb;
	EMISSION = glow_color.rgb * f;
}
"""}
		"toon_simple":
			return {"type": "spatial", "code": """shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.85, 1.0);
void fragment() {
	ALBEDO = albedo.rgb;
}
"""}
		"triplanar_terrain":
			return {"type": "spatial", "code": """shader_type spatial;
uniform sampler2D top_tex : source_color;
uniform sampler2D side_tex : source_color;
uniform float blend : hint_range(0.0, 8.0) = 4.0;
uniform float scale = 0.25;
void fragment() {
	vec3 n = abs(NORMAL);
	n = pow(n, vec3(blend));
	n /= (n.x + n.y + n.z);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz; // approx; prefer WORLD_MATRIX in older
	vec3 col = texture(side_tex, wp.zy * scale).rgb * n.x
		+ texture(top_tex, wp.xz * scale).rgb * n.y
		+ texture(side_tex, wp.xy * scale).rgb * n.z;
	ALBEDO = col;
}
"""}
		_:
			return {}


func _create_shader_preset(params: Dictionary) -> Dictionary:
	var preset: String = optional_string(params, "preset", "flash_white")
	var src := _shader_source(preset)
	if src.is_empty():
		return error_invalid_params("Unknown preset. Call list_shader_presets.")
	var path: String = optional_string(params, "path", "res://shaders/%s.gdshader" % preset)
	var w := write_script_file(path, src["code"], optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "preset": preset, "shader_type": src["type"]})


func _create_dissolve_shader(params: Dictionary) -> Dictionary:
	return _create_shader_preset({"preset": "dissolve", "path": optional_string(params, "path", "res://shaders/dissolve.gdshader"), "overwrite": optional_bool(params, "overwrite", false)})


func _create_outline_shader(params: Dictionary) -> Dictionary:
	return _create_shader_preset({"preset": "outline_2d", "path": optional_string(params, "path", "res://shaders/outline_2d.gdshader"), "overwrite": optional_bool(params, "overwrite", false)})


func _apply_canvas_shader_to_node(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node_r := require_string(params, "node_path")
	if node_r[1] != null:
		return node_r[1]
	var node := find_node_by_path(node_r[0])
	if node == null or not (node is CanvasItem):
		return error_not_found("CanvasItem at '%s'" % node_r[0])
	var preset: String = optional_string(params, "preset", "flash_white")
	var shader_path: String = optional_string(params, "shader_path", "")
	if shader_path.is_empty():
		var created := _create_shader_preset({"preset": preset, "overwrite": true})
		if created.has("error"):
			return created
		shader_path = created["result"]["path"]
	if not ResourceLoader.exists(shader_path):
		return error_not_found(shader_path)
	var sh: Shader = load(shader_path)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if params.has("params") and params["params"] is Dictionary:
		for k in params["params"]:
			mat.set_shader_parameter(str(k), params["params"][k])
	(node as CanvasItem).material = mat
	mark_current_scene_unsaved()
	return success({"node_path": node_r[0], "shader_path": shader_path, "preset": preset})


func _apply_spatial_shader_to_mesh(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node_r := require_string(params, "node_path")
	if node_r[1] != null:
		return node_r[1]
	var node := find_node_by_path(node_r[0])
	if node == null or not (node is MeshInstance3D):
		return error_not_found("MeshInstance3D at '%s'" % node_r[0])
	var preset: String = optional_string(params, "preset", "fresnel_glow")
	var shader_path: String = optional_string(params, "shader_path", "")
	if shader_path.is_empty():
		var created := _create_shader_preset({"preset": preset, "overwrite": true})
		if created.has("error"):
			return created
		shader_path = created["result"]["path"]
	var sh: Shader = load(shader_path)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if params.has("params") and params["params"] is Dictionary:
		for k in params["params"]:
			mat.set_shader_parameter(str(k), params["params"][k])
	var surface: int = optional_int(params, "surface", 0)
	(node as MeshInstance3D).set_surface_override_material(surface, mat)
	mark_current_scene_unsaved()
	return success({"node_path": node_r[0], "shader_path": shader_path, "surface": surface})


func _setup_trail_vfx(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var is_3d := parent is Node3D or optional_bool(params, "is_3d", false)
	if is_3d:
		var trail := GPUParticles3D.new() if ClassDB.class_exists("GPUParticles3D") else null
		# Prefer dedicated Trail if available (Godot 4 has no Trail3D built-in same as 2D Line)
		# Use CPUParticles3D as fallback trail-ish
		if trail == null:
			return error_internal("GPUParticles3D unavailable")
		trail.name = optional_string(params, "name", "TrailVFX")
		trail.amount = optional_int(params, "amount", 32)
		trail.lifetime = float(params.get("lifetime", 0.4))
		trail.local_coords = false
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 15.0
		mat.initial_velocity_min = 0.1
		mat.initial_velocity_max = 0.5
		mat.gravity = Vector3.ZERO
		mat.scale_min = 0.05
		mat.scale_max = 0.15
		trail.process_material = mat
		add_child_with_undo(parent, trail, root, "MCP: Trail VFX 3D")
		mark_current_scene_unsaved()
		return success({"node_path": str(root.get_path_to(trail)), "type": "GPUParticles3D"})
	else:
		# Line2D trail via script is common; use GPUParticles2D
		var p2 := GPUParticles2D.new()
		p2.name = optional_string(params, "name", "TrailVFX")
		p2.amount = optional_int(params, "amount", 24)
		p2.lifetime = float(params.get("lifetime", 0.35))
		p2.local_coords = false
		var mat2 := ParticleProcessMaterial.new()
		mat2.direction = Vector3(0, -1, 0)
		mat2.spread = 20.0
		mat2.initial_velocity_min = 10.0
		mat2.initial_velocity_max = 40.0
		mat2.gravity = Vector3(0, 0, 0)
		p2.process_material = mat2
		add_child_with_undo(parent, p2, root, "MCP: Trail VFX 2D")
		mark_current_scene_unsaved()
		return success({"node_path": str(root.get_path_to(p2)), "type": "GPUParticles2D"})


func _setup_flash_hurt_vfx(params: Dictionary) -> Dictionary:
	## Apply flash shader + small script to pulse flash on take_damage.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node_r := require_string(params, "node_path")
	if node_r[1] != null:
		return node_r[1]
	var node := find_node_by_path(node_r[0])
	if node == null:
		return error_not_found(node_r[0])
	if node is CanvasItem:
		_apply_canvas_shader_to_node({"node_path": node_r[0], "preset": "flash_white"})
	var script_path: String = optional_string(params, "script_path", "res://scripts/hurt_flash.gd")
	var content := """extends Node
## MCP hurt flash - parent must be CanvasItem with flash shader param.
@export var flash_time: float = 0.12
var _t: float = 0.0
@onready var target: CanvasItem = get_parent() as CanvasItem

func flash() -> void:
	_t = flash_time

func _process(delta: float) -> void:
	if target == null or target.material == null:
		return
	if _t > 0.0:
		_t = maxf(_t - delta, 0.0)
		var mat := target.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("flash", clampf(_t / flash_time, 0.0, 1.0))
	else:
		var mat2 := target.material as ShaderMaterial
		if mat2:
			mat2.set_shader_parameter("flash", 0.0)
"""
	var w := write_script_file(script_path, content, optional_bool(params, "overwrite", true))
	if w.has("error"):
		return w
	var n := Node.new()
	n.name = "HurtFlash"
	add_child_with_undo(node, n, root, "MCP: HurtFlash")
	var s = load(script_path)
	if s:
		n.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(n)), "target": node_r[0]})


func _setup_screen_fade_overlay(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found(parent_path)
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "ScreenFade")
	layer.layer = optional_int(params, "layer", 100)
	add_child_with_undo(parent, layer, root, "MCP: ScreenFade")
	var rect := ColorRect.new()
	rect.name = "FadeRect"
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child_with_undo(layer, rect, root, "MCP: FadeRect")
	var sp: String = optional_string(params, "script_path", "res://scripts/screen_fade.gd")
	var scr := """extends CanvasLayer
## MCP screen fade - fade_to_black / fade_from_black

@onready var rect: ColorRect = $FadeRect

func fade_to_black(duration: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, duration)

func fade_from_black(duration: float = 0.5) -> void:
	rect.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration)

func fade_to_color(color: Color, duration: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(rect, "color", color, duration)
"""
	write_script_file(sp, scr, true)
	var s = load(sp)
	if s:
		layer.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(layer))})


func _create_hit_stop_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/hit_stop.gd")
	var content := """extends Node
## MCP hit-stop / freeze frames - call HitStop.freeze(0.05) on heavy hits.

func freeze(duration: float = 0.05, time_scale: float = 0.0) -> void:
	var prev := Engine.time_scale
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = prev
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", false):
		var aname := optional_string(params, "autoload_name", "HitStop")
		al = ensure_autoload(aname, w["path"], true)
	return success({"path": w["path"], "autoload_added": al})
