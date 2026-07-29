@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Performance budget -> auto-fix recipes (LOD, shadows, cull, particles).


func get_commands() -> Dictionary:
	return {
		"suggest_performance_fixes": _suggest,
		"apply_performance_autofix_pack": _apply_pack,
		"autofix_reduce_shadows": _fix_shadows,
		"autofix_apply_lod_visibility": _fix_lod,
		"autofix_cap_particles": _fix_particles,
		"autofix_disable_gi_dynamic": _fix_gi,
		"create_performance_watchdog_script": _watchdog,
		"list_performance_autofix_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"analyze_performance_budget", "get_performance_monitors", "apply_lod_distance_preset",
		"set_visibility_range", "set_geometry_instance_params", "batch_set_geometry_instance_params",
		"mesh_generate_lods", "apply_platform_render_pack",
	], {
		"flow": [
			"analyze_performance_budget / get_performance_monitors",
			"suggest_performance_fixes",
			"apply_performance_autofix_pack preset=mobile|balanced|aggressive",
		],
	})


func _exec(method: String, params: Dictionary = {}) -> Dictionary:
	var r = get_parent()
	if r == null or not r.has_method("execute"):
		return {"error": {"message": "No router", "method": method}}
	return await r.execute(method, params)


func _collect_mesh_instances(n: Node, out: Array) -> void:
	if n is MeshInstance3D or n is GeometryInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_mesh_instances(c, out)


func _collect_lights(n: Node, out: Array) -> void:
	if n is Light3D or n is Light2D:
		out.append(n)
	for c in n.get_children():
		_collect_lights(c, out)


func _collect_particles(n: Node, out: Array) -> void:
	var cn := n.get_class()
	if "Particle" in cn:
		out.append(n)
	for c in n.get_children():
		_collect_particles(c, out)


func _suggest(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var meshes: Array = []
	var lights: Array = []
	var particles: Array = []
	_collect_mesh_instances(root, meshes)
	_collect_lights(root, lights)
	_collect_particles(root, particles)
	var shadow_lights := 0
	for L in lights:
		if "shadow_enabled" in L and bool(L.get("shadow_enabled")):
			shadow_lights += 1
	var suggestions: Array = []
	if meshes.size() > 80:
		suggestions.append({
			"id": "lod_visibility",
			"reason": "Many GeometryInstance3D (%d)" % meshes.size(),
			"tool": "autofix_apply_lod_visibility",
			"priority": 1,
		})
	if shadow_lights > 3:
		suggestions.append({
			"id": "reduce_shadows",
			"reason": "Many shadow-casting lights (%d)" % shadow_lights,
			"tool": "autofix_reduce_shadows",
			"priority": 1,
		})
	if particles.size() > 10:
		suggestions.append({
			"id": "cap_particles",
			"reason": "Many particle nodes (%d)" % particles.size(),
			"tool": "autofix_cap_particles",
			"priority": 2,
		})
	suggestions.append({
		"id": "gi_static",
		"reason": "Prefer static GI for static meshes",
		"tool": "autofix_disable_gi_dynamic",
		"priority": 3,
	})
	suggestions.append({
		"id": "platform_pack",
		"reason": "Apply platform render pack for target device",
		"tool": "apply_platform_render_pack",
		"priority": 2,
	})
	return success({
		"mesh_count": meshes.size(),
		"light_count": lights.size(),
		"shadow_lights": shadow_lights,
		"particle_count": particles.size(),
		"suggestions": suggestions,
		"packs": ["mobile", "balanced", "aggressive"],
	})


func _fix_shadows(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var keep_dir := optional_bool(params, "keep_directional", true)
	var max_shadow := optional_int(params, "max_shadow_lights", 1)
	var lights: Array = []
	_collect_lights(root, lights)
	var changed: Array = []
	var shadow_count := 0
	for L in lights:
		if not ("shadow_enabled" in L):
			continue
		var is_dir := L is DirectionalLight3D or L is DirectionalLight2D
		if is_dir and keep_dir:
			if not bool(L.get("shadow_enabled")):
				L.set("shadow_enabled", true)
				changed.append({"path": str(root.get_path_to(L)), "shadow": true, "keep_directional": true})
			shadow_count += 1
			continue
		if bool(L.get("shadow_enabled")):
			if shadow_count >= max_shadow:
				L.set("shadow_enabled", false)
				changed.append({"path": str(root.get_path_to(L)), "shadow": false})
			else:
				shadow_count += 1
	mark_current_scene_unsaved()
	return success({"changed": changed, "count": changed.size(), "shadow_lights_remaining_cap": max_shadow})


func _fix_lod(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var begin := float(params.get("visibility_range_begin", 0.0))
	var end := float(params.get("visibility_range_end", 80.0))
	var margin := float(params.get("margin", 5.0))
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	var changed: Array = []
	for m in meshes:
		if m is GeometryInstance3D:
			var gi := m as GeometryInstance3D
			gi.visibility_range_begin = begin
			gi.visibility_range_end = end
			if "visibility_range_end_margin" in gi:
				gi.visibility_range_end_margin = margin
			changed.append(str(root.get_path_to(gi)))
	# Also try LOD distance preset if available
	var preset: String = optional_string(params, "lod_preset", "")
	var preset_result = null
	if not preset.is_empty():
		preset_result = await _exec("apply_lod_distance_preset", {"preset": preset})
	mark_current_scene_unsaved()
	return success({
		"changed_count": changed.size(),
		"visibility_range_end": end,
		"paths_sample": changed.slice(0, mini(20, changed.size())),
		"lod_preset": preset_result,
	})


func _fix_particles(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var max_amount := optional_int(params, "max_amount", 64)
	var particles: Array = []
	_collect_particles(root, particles)
	var changed: Array = []
	for p in particles:
		if "amount" in p:
			var old = int(p.get("amount"))
			if old > max_amount:
				p.set("amount", max_amount)
				changed.append({"path": str(root.get_path_to(p)), "old": old, "amount": max_amount})
		if optional_bool(params, "disable_excess", false) and particles.find(p) >= optional_int(params, "max_systems", 8):
			if "emitting" in p:
				p.set("emitting", false)
				changed.append({"path": str(root.get_path_to(p)), "emitting": false})
	mark_current_scene_unsaved()
	return success({"changed": changed, "particle_nodes": particles.size()})


func _fix_gi(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var mode_s: String = optional_string(params, "mode", "static")
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	var paths: Array = []
	for m in meshes:
		if m is GeometryInstance3D:
			paths.append(str(root.get_path_to(m)))
	if paths.is_empty():
		return success({"changed_count": 0})
	# Batch via geometry tool if present
	var res = await _exec("batch_set_geometry_instance_params", {
		"node_paths": paths,
		"gi_mode": mode_s,
	})
	return success({"gi_mode": mode_s, "count": paths.size(), "result": res})


func _apply_pack(params: Dictionary) -> Dictionary:
	var preset: String = optional_string(params, "preset", "balanced")
	var steps: Array = []
	match preset.to_lower():
		"mobile":
			steps.append(await _fix_shadows({"keep_directional": true, "max_shadow_lights": 1}))
			steps.append(await _fix_lod({"visibility_range_end": 45.0, "lod_preset": "mobile"}))
			steps.append(await _fix_particles({"max_amount": 32, "disable_excess": true, "max_systems": 4}))
			steps.append(await _fix_gi({"mode": "static"}))
			steps.append(await _exec("apply_platform_render_pack", {"preset": "mobile"}))
		"aggressive":
			steps.append(await _fix_shadows({"keep_directional": true, "max_shadow_lights": 0}))
			steps.append(await _fix_lod({"visibility_range_end": 30.0, "lod_preset": "mobile"}))
			steps.append(await _fix_particles({"max_amount": 16, "disable_excess": true, "max_systems": 2}))
			steps.append(await _fix_gi({"mode": "disabled"}))
		_:  # balanced
			steps.append(await _fix_shadows({"keep_directional": true, "max_shadow_lights": 2}))
			steps.append(await _fix_lod({"visibility_range_end": 80.0, "lod_preset": "desktop"}))
			steps.append(await _fix_particles({"max_amount": 64}))
			steps.append(await _fix_gi({"mode": "static"}))
	return success({"preset": preset, "steps": steps})


func _watchdog(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/performance_watchdog.gd")
	var content := """extends Node
## Runtime FPS watchdog - emits when below budget so agents/UI can react.

signal budget_breached(fps: float, frame_ms: float)
signal recovered(fps: float)

@export var min_fps: float = 30.0
@export var sample_seconds: float = 1.0
@export var cooldown: float = 3.0

var _acc: float = 0.0
var _frames: int = 0
var _breached: bool = false
var _cool: float = 0.0

func _process(delta: float) -> void:
	_acc += delta
	_frames += 1
	if _cool > 0.0:
		_cool -= delta
	if _acc >= sample_seconds:
		var fps := float(_frames) / _acc
		var ms := 1000.0 / maxf(fps, 0.001)
		if fps < min_fps:
			if not _breached and _cool <= 0.0:
				_breached = true
				_cool = cooldown
				budget_breached.emit(fps, ms)
		elif _breached:
			_breached = false
			recovered.emit(fps)
		_acc = 0.0
		_frames = 0
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	if optional_bool(params, "add_autoload", false):
		maybe_add_autoload(params, path, "PerfWatchdog")
	return success({"path": path})
