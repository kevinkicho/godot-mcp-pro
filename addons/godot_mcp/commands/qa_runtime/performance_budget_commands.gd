@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Performance budget reports with thresholds (Wave 5).


func get_commands() -> Dictionary:
	return {
		"analyze_performance_budget": _analyze_performance_budget,
		"set_performance_budget_thresholds": _set_performance_budget_thresholds,
		"get_performance_budget_thresholds": _get_performance_budget_thresholds,
		"list_performance_budget_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["get_performance_monitors", "capture_performance_sample", "analyze_scene_complexity", "export_performance_report"],
	})


func _default_thresholds() -> Dictionary:
	return {
		"max_nodes": 8000,
		"max_fps_budget_ms": 16.7,
		"min_fps": 30.0,
		"max_static_memory_mb": 1024.0,
		"max_object_count": 50000,
		"max_draw_calls_hint": 1000,
	}


func _get_thresholds() -> Dictionary:
	var t := _default_thresholds()
	for k in t.keys():
		var pk := "mcp/perf_budget/%s" % k
		if ProjectSettings.has_setting(pk):
			t[k] = ProjectSettings.get_setting(pk)
	return t


func _set_performance_budget_thresholds(params: Dictionary) -> Dictionary:
	var applied := {}
	var keys := _default_thresholds().keys()
	for k in keys:
		if params.has(k):
			var pk := "mcp/perf_budget/%s" % k
			ProjectSettings.set_setting(pk, params[k])
			applied[k] = params[k]
	if applied.is_empty():
		return error_invalid_params("Provide max_nodes, min_fps, max_static_memory_mb, etc.")
	ProjectSettings.save()
	return success({"applied": applied, "thresholds": _get_thresholds()})


func _get_performance_budget_thresholds(_params: Dictionary) -> Dictionary:
	return success({"thresholds": _get_thresholds()})


func _analyze_performance_budget(params: Dictionary) -> Dictionary:
	var thresholds := _get_thresholds()
	# Override from params
	for k in thresholds.keys():
		if params.has(k):
			thresholds[k] = params[k]
	var report := {
		"scene": {},
		"runtime": {},
		"violations": [],
		"ok": true,
	}
	var root := get_edited_root()
	if root:
		var node_count := _count_nodes(root)
		report["scene"]["node_count"] = node_count
		report["scene"]["path"] = root.scene_file_path
		if node_count > int(thresholds["max_nodes"]):
			report["violations"].append({
				"metric": "node_count",
				"value": node_count,
				"budget": thresholds["max_nodes"],
				"fix": "analyze_scene_complexity; split scenes / Multimesh / streaming",
			})
			report["ok"] = false
	# Runtime monitors if playing
	if EditorInterface.is_playing_scene():
		var sample = await send_game_command("get_performance_monitors", {}, 5.0)
		var mon = sample.get("result", sample)
		if mon is Dictionary:
			# unwrap
			while mon.has("result") and mon["result"] is Dictionary and not mon.has("fps"):
				mon = mon["result"]
			report["runtime"] = mon
			var fps := float(mon.get("fps", mon.get("time_fps", 0)))
			if fps > 0.0 and fps < float(thresholds["min_fps"]):
				report["violations"].append({
					"metric": "fps",
					"value": fps,
					"budget_min": thresholds["min_fps"],
					"fix": "capture_performance_timeline; reduce draw/particles/lights",
				})
				report["ok"] = false
			var mem := float(mon.get("memory_static", mon.get("static_memory", 0)))
			# memory often in bytes
			var mem_mb := mem / (1024.0 * 1024.0) if mem > 10000.0 else mem
			if mem_mb > float(thresholds["max_static_memory_mb"]):
				report["violations"].append({
					"metric": "static_memory_mb",
					"value": mem_mb,
					"budget": thresholds["max_static_memory_mb"],
					"fix": "check textures/import compress; ResourceLoader",
				})
				report["ok"] = false
	else:
		report["runtime"]["note"] = "Not playing - scene node budget only; play for FPS/memory"
	# Editor complexity helper
	var router = get_parent()
	if router and router.has_method("execute") and optional_bool(params, "include_complexity", true) and root:
		var cx = await router.execute("analyze_scene_complexity", {})
		report["complexity"] = cx.get("result", cx)
	return success(report)


func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c
