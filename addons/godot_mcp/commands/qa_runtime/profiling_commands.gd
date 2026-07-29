@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_performance_monitors": _get_performance_monitors,
		"get_editor_performance": _get_editor_performance,
		"capture_performance_sample": _capture_performance_sample,
		"capture_performance_timeline": _capture_performance_timeline,
		"get_render_info": _get_render_info,
		"list_performance_monitor_names": _list_performance_monitor_names,
		"export_performance_report": _export_performance_report,
		"get_gpu_profiling_hints": _get_gpu_profiling_hints,
	}


func _get_performance_monitors(params: Dictionary) -> Dictionary:
	# Performance is a per-process singleton: reading it here would report the
	# EDITOR's metrics, not the game's. Route through the game IPC channel.
	if get_editor().is_playing_scene():
		var game_result := await send_game_command("get_performance_monitors", {}, 5.0)
		if game_result.has("error"):
			return game_result
		var payload := unwrap_game_result(game_result)
		var game_monitors: Dictionary = payload.get("monitors", {})
		var category: String = optional_string(params, "category", "")
		if not category.is_empty():
			var filtered := {}
			for key: String in game_monitors:
				if key.begins_with(category):
					filtered[key] = game_monitors[key]
			return success({"monitors": filtered, "category": category, "process": "game"})
		return success({"monitors": game_monitors, "process": "game"})

	return error(-32000, "No scene is currently playing", {
		"suggestion": "Use play_scene first. For editor-process metrics, use get_editor_performance.",
	})


func _get_editor_performance(params: Dictionary) -> Dictionary:
	# Quick summary for common use
	var summary := {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time_msec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memory_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
	}
	return success(summary)


func _monitor_snapshot(process_label: String) -> Dictionary:
	return {
		"process": process_label,
		"timestamp_ms": Time.get_ticks_msec(),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_msec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_msec": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memory_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		"texture_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / (1024.0 * 1024.0),
		"buffer_mem_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / (1024.0 * 1024.0),
		"physics_2d_active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"physics_3d_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
	}


func _capture_performance_sample(params: Dictionary) -> Dictionary:
	## Single snapshot: game process if playing, else editor.
	var prefer_game: bool = optional_bool(params, "prefer_game", true)
	if prefer_game and get_editor() and get_editor().is_playing_scene():
		var game_result := await send_game_command("get_performance_monitors", {}, 5.0)
		if not game_result.has("error"):
			var payload := unwrap_game_result(game_result)
			return success({
				"process": "game",
				"timestamp_ms": Time.get_ticks_msec(),
				"monitors": payload.get("monitors", {}),
				"summary": payload.get("summary", payload),
			})
		# fall through to editor snapshot with note
		var snap := _monitor_snapshot("editor")
		snap["game_ipc_error"] = game_result.get("error", game_result)
		return success(snap)
	return success(_monitor_snapshot("editor"))


func _capture_performance_timeline(params: Dictionary) -> Dictionary:
	## Sample N frames over duration (editor process only — use while editor is idle or playing for editor-side).
	## For game-side multi-sample, samples game monitors repeatedly via IPC when playing.
	var samples_n: int = clampi(optional_int(params, "samples", 10), 2, 60)
	var interval_sec: float = clampf(float(params.get("interval_sec", 0.1)), 0.05, 2.0)
	var prefer_game: bool = optional_bool(params, "prefer_game", true)
	var series: Array = []
	var playing := get_editor() != null and get_editor().is_playing_scene()
	for i in samples_n:
		if prefer_game and playing:
			var game_result := await send_game_command("get_performance_monitors", {}, 5.0)
			if not game_result.has("error"):
				var payload := unwrap_game_result(game_result)
				var monitors: Dictionary = payload.get("monitors", {})
				series.append({
					"i": i,
					"timestamp_ms": Time.get_ticks_msec(),
					"fps": monitors.get("time/fps", monitors.get("fps", null)),
					"monitors": monitors,
					"process": "game",
				})
			else:
				series.append({"i": i, "error": game_result.get("error", "ipc"), "process": "game"})
		else:
			var s := _monitor_snapshot("editor")
			s["i"] = i
			series.append(s)
		if i < samples_n - 1:
			await get_tree().create_timer(interval_sec).timeout
	# Aggregate simple stats when possible
	var fps_vals: Array = []
	for s in series:
		if s is Dictionary and s.has("fps") and s["fps"] != null:
			fps_vals.append(float(s["fps"]))
		elif s is Dictionary and s.has("monitors") and s["monitors"] is Dictionary:
			var m: Dictionary = s["monitors"]
			if m.has("time/fps"):
				fps_vals.append(float(m["time/fps"]))
	var agg := {}
	if fps_vals.size() > 0:
		var sum := 0.0
		var mn := fps_vals[0]
		var mx := fps_vals[0]
		for v in fps_vals:
			sum += float(v)
			mn = minf(mn, float(v))
			mx = maxf(mx, float(v))
		agg = {"fps_avg": sum / fps_vals.size(), "fps_min": mn, "fps_max": mx, "fps_samples": fps_vals.size()}
	return success({
		"samples": series,
		"count": series.size(),
		"interval_sec": interval_sec,
		"aggregate": agg,
		"process": "game" if prefer_game and playing else "editor",
	})


func _get_render_info(params: Dictionary) -> Dictionary:
	## RenderingServer / viewport-oriented snapshot (editor viewport by default).
	var info := {
		"timestamp_ms": Time.get_ticks_msec(),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		"texture_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / (1024.0 * 1024.0),
		"buffer_mem_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / (1024.0 * 1024.0),
	}
	# Viewport info
	var ei := get_editor()
	if ei:
		var vp := ei.get_editor_viewport_3d(0) if ei.has_method("get_editor_viewport_3d") else null
		if vp is SubViewport:
			info["viewport_3d_size"] = {"x": vp.size.x, "y": vp.size.y}
		var vp2 = ei.get_editor_viewport_2d() if ei.has_method("get_editor_viewport_2d") else null
		if vp2 is SubViewport:
			info["viewport_2d_size"] = {"x": vp2.size.x, "y": vp2.size.y}
	if optional_bool(params, "include_pipeline", false):
		info["note"] = "Full GPU frame debugger is editor UI only; use this + capture_performance_timeline while playing."
	# Prefer game render stats when playing
	if optional_bool(params, "prefer_game", true) and ei and ei.is_playing_scene():
		var game_result := await send_game_command("get_performance_monitors", {}, 5.0)
		if not game_result.has("error"):
			var payload := unwrap_game_result(game_result)
			info["game_monitors"] = payload.get("monitors", {})
			info["process"] = "game+editor"
		else:
			info["process"] = "editor"
	else:
		info["process"] = "editor"
	return success(info)


func _list_performance_monitor_names(_params: Dictionary) -> Dictionary:
	## Document common Performance monitor ids agents can filter by category.
	var names := [
		"time/fps", "time/process", "time/physics_process",
		"memory/static", "memory/static_max",
		"object/node_count", "object/resource_count", "object/orphan_node_count",
		"render/total_objects_in_frame", "render/total_primitives_in_frame", "render/total_draw_calls_in_frame",
		"render/video_mem_used", "render/texture_mem_used", "render/buffer_mem_used",
		"physics_2d/active_objects", "physics_3d/active_objects",
		"navigation/active_maps",
	]
	return success({
		"monitors": names,
		"usage": "get_performance_monitors while playing; capture_performance_timeline for multi-sample; category filter e.g. 'render'",
	})


func _export_performance_report(params: Dictionary) -> Dictionary:
	## Capture sample/timeline and write JSON report under user:// or res://.
	var out_path: String = optional_string(params, "path", "user://mcp_perf_report.json")
	var samples: int = clampi(optional_int(params, "samples", 5), 1, 30)
	var interval: float = clampf(float(params.get("interval_sec", 0.1)), 0.05, 1.0)
	var timeline := await _capture_performance_timeline({
		"samples": samples,
		"interval_sec": interval,
		"prefer_game": optional_bool(params, "prefer_game", true),
	})
	var body: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(true),
		"godot_version": Engine.get_version_info(),
		"report": timeline.get("result", timeline),
		"editor_snapshot": _monitor_snapshot("editor"),
	}
	if out_path.begins_with("res://") or out_path.begins_with("user://"):
		var abs := ProjectSettings.globalize_path(out_path)
		DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f == null:
			return error_internal("Cannot write %s" % out_path)
		f.store_string(JSON.stringify(body, "\t"))
		f.close()
	else:
		return error_invalid_params("path must be res:// or user://")
	return success({
		"path": out_path,
		"samples": samples,
		"aggregate": body.get("report", {}).get("aggregate", {}),
		"hint": "GPU frame debugger still editor-only; this exports CPU/render counters agents can diff",
	})


func _get_gpu_profiling_hints(_params: Dictionary) -> Dictionary:
	return success({
		"engine_ui": [
			"Debugger → Profiler / Monitors / Visual Profiler",
			"Editor → Editor Settings → Network → Remote FS (for device)",
			"Project Settings → Rendering → Driver / V-Sync",
		],
		"mcp_tools": [
			"get_performance_monitors (game)",
			"capture_performance_timeline",
			"get_render_info",
			"export_performance_report",
			"analyze_scene_complexity",
		],
		"honesty": "Godot does not expose the full GPU frame debugger graph via plugin API; agents use counters + screenshots + media keyframes.",
		"docs": "https://docs.godotengine.org/en/stable/tutorials/performance/index.html",
	})
