@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Agent-facing native run plane: session lifecycle, video record, timeline, events.
## Builds on MCPGameInspector IPC — structure first, video for motion/feel.


func get_commands() -> Dictionary:
	return {
		"run_session_start": _run_session_start,
		"run_session_stop": _run_session_stop,
		"run_session_status": _run_session_status,
		"run_record_start": _run_record_start,
		"run_record_stop": _run_record_stop,
		"run_log_event": _run_log_event,
		"run_get_events": _run_get_events,
		"run_get_logs": _run_get_logs,
		"run_capture_timeline": _run_capture_timeline,
		"run_find_nodes": _run_find_nodes,
		"run_probe_report": _run_probe_report,
	}


func _ensure_playing() -> Dictionary:
	if not EditorInterface.is_playing_scene():
		return error(-32000, "No scene is currently playing", {
			"suggestion": "Call run_session_start or play_scene first",
		})
	return {}


func _run_session_start(params: Dictionary) -> Dictionary:
	## Play main/current/custom and wait until game is up; optional video record.
	var mode: String = optional_string(params, "mode", "main")
	var path: String = optional_string(params, "path", "")
	var settle_sec: float = float(params.get("settle_sec", 1.0))
	var start_record: bool = optional_bool(params, "record", false)

	if EditorInterface.is_playing_scene():
		if optional_bool(params, "restart", false):
			EditorInterface.stop_playing_scene()
			await get_tree().create_timer(0.4).timeout
		else:
			var st := await send_game_command("get_run_status", {}, 5.0)
			return success({
				"already_playing": true,
				"status": st.get("result", st),
				"hint": "restart=true to stop and replay",
			})

	match mode:
		"current":
			EditorInterface.play_current_scene()
		"custom":
			if path.is_empty():
				return error_invalid_params("custom mode needs path")
			if not path.begins_with("res://"):
				path = "res://" + path.trim_prefix("/")
			if not FileAccess.file_exists(path):
				return error_not_found(path)
			EditorInterface.play_custom_scene(path)
		_:
			EditorInterface.play_main_scene()

	var attempts := int(maxf(settle_sec, 0.5) / 0.1) + 10
	while attempts > 0 and not EditorInterface.is_playing_scene():
		await get_tree().create_timer(0.1).timeout
		attempts -= 1
	await get_tree().create_timer(settle_sec).timeout

	if not EditorInterface.is_playing_scene():
		return error(-32000, "Failed to start play session", {"mode": mode, "path": path})

	if is_debugger_paused():
		try_debugger_continue()
		await get_tree().create_timer(0.2).timeout

	var status := await send_game_command("get_run_status", {}, 6.0)
	var record_meta := {}
	if start_record:
		record_meta = await _run_record_start({
			"session_id": optional_string(params, "session_id", "session_%d" % Time.get_ticks_msec()),
			"fps": params.get("fps", 10),
			"half_resolution": optional_bool(params, "half_resolution", true),
			"track_nodes": params.get("track_nodes", []),
		})

	return success({
		"playing": true,
		"mode": mode,
		"path": path,
		"settle_sec": settle_sec,
		"status": status.get("result", status),
		"record": record_meta.get("result", record_meta) if start_record else null,
		"next": [
			"run_find_nodes / get_game_node_properties / assert_node_state",
			"run_log_event for markers",
			"run_capture_timeline for property time series",
			"run_record_stop → media_frames_to_video",
			"run_session_stop",
		],
	})


func _run_session_stop(params: Dictionary) -> Dictionary:
	var stop_record: bool = optional_bool(params, "stop_record", true)
	var record_out := {}
	if stop_record and EditorInterface.is_playing_scene():
		var chk := await send_game_command("get_run_status", {}, 3.0)
		var st = chk.get("result", {})
		if st is Dictionary and st.get("video_recording", false):
			record_out = await send_game_command("stop_video_record", {}, 15.0)
	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
	return success({
		"stopped": true,
		"record": record_out.get("result", record_out) if not record_out.is_empty() else null,
	})


func _run_session_status(_params: Dictionary) -> Dictionary:
	var playing := EditorInterface.is_playing_scene()
	var game := {}
	if playing:
		if is_debugger_paused():
			try_debugger_continue()
		var res := await send_game_command("get_run_status", {}, 5.0)
		game = res.get("result", res)
	return success({
		"playing": playing,
		"debugger_paused": is_debugger_paused(),
		"game": game,
		"channel": "file_ipc" if playing else "offline",
	})


func _run_record_start(params: Dictionary) -> Dictionary:
	var err := _ensure_playing()
	if not err.is_empty():
		return err
	return await send_game_command("start_video_record", {
		"session_id": optional_string(params, "session_id", "session_%d" % Time.get_ticks_msec()),
		"fps": float(params.get("fps", 10)),
		"half_resolution": optional_bool(params, "half_resolution", true),
		"max_frames": optional_int(params, "max_frames", 900),
		"save_images": optional_bool(params, "save_images", true),
		"track_nodes": params.get("track_nodes", []),
	}, 8.0)


func _run_record_stop(params: Dictionary) -> Dictionary:
	var err := _ensure_playing()
	if not err.is_empty():
		return err
	var res: Dictionary = await send_game_command("stop_video_record", {}, 20.0)
	var meta = res.get("result", res)
	if meta is Dictionary and meta.has("meta"):
		meta = meta["meta"]
	# Optionally encode with FFmpeg immediately
	var encode: bool = optional_bool(params, "encode", true)
	var encode_result := {}
	if encode and meta is Dictionary:
		var dir: String = str(meta.get("dir", ""))
		var fps: float = float(meta.get("fps", 10))
		if not dir.is_empty():
			var media = load("res://addons/godot_mcp/commands/media_commands.gd").new()
			media.editor_plugin = editor_plugin
			encode_result = media._frames_to_video_impl({
				"frames_dir": dir,
				"fps": fps,
				"output_path": dir.path_join("session.mp4"),
			})
	return success({
		"meta": meta,
		"encode": encode_result,
		"hint": "Use media_extract_keyframes / media_clip_video / media_contact_sheet on the mp4 or frame dir",
	})


func _run_log_event(params: Dictionary) -> Dictionary:
	var err := _ensure_playing()
	if not err.is_empty():
		return err
	return await send_game_command("log_run_event", params, 5.0)


func _run_get_events(params: Dictionary) -> Dictionary:
	var err := _ensure_playing()
	if not err.is_empty():
		return err
	return await send_game_command("get_run_events", params, 8.0)


func _run_get_logs(params: Dictionary) -> Dictionary:
	var err := _ensure_playing()
	if not err.is_empty():
		return err
	return await send_game_command("get_run_logs", params, 5.0)


func _run_capture_timeline(params: Dictionary) -> Dictionary:
	var err := _ensure_playing()
	if not err.is_empty():
		return err
	var duration: float = float(params.get("duration_sec", params.get("duration", 2.0)))
	# IPC is async on game side — wait duration + buffer
	var timeout: float = duration + 8.0
	return await send_game_command("capture_timeline", params, timeout)


func _run_find_nodes(params: Dictionary) -> Dictionary:
	var err := _ensure_playing()
	if not err.is_empty():
		return err
	return await send_game_command("find_nodes", params, 8.0)


func _run_probe_report(params: Dictionary) -> Dictionary:
	## One-shot: ensure playing → optional record → settle → tree/status/logs/screenshot → stop.
	var start := await _run_session_start({
		"mode": optional_string(params, "mode", "main"),
		"path": optional_string(params, "path", ""),
		"settle_sec": float(params.get("settle_sec", 1.2)),
		"record": optional_bool(params, "record", false),
		"restart": optional_bool(params, "restart", true),
		"fps": params.get("fps", 8),
	})
	if start.has("error"):
		return start

	var report := {
		"session": start.get("result", start),
	}

	if params.has("log_event"):
		await send_game_command("log_run_event", {
			"type": "probe_marker",
			"message": str(params["log_event"]),
		}, 3.0)

	var status := await send_game_command("get_run_status", {}, 5.0)
	report["status"] = status.get("result", status)

	var tree := await send_game_command("get_scene_tree", {
		"max_depth": optional_int(params, "max_depth", 4),
	}, 8.0)
	report["tree"] = tree.get("result", tree)

	var errors := collect_debugger_errors(20)
	report["debugger_errors"] = errors

	if optional_bool(params, "screenshot", true):
		var shot := await send_game_command("get_screenshot", {}, 8.0)
		# get_screenshot may not exist on inspector — use capture_frames count=1 fallback
		if shot.has("error") or (shot.get("result") is Dictionary and shot["result"].has("error")):
			shot = await send_game_command("capture_frames", {"count": 1, "frame_interval": 1, "half_resolution": true}, 12.0)
		report["screenshot"] = shot.get("result", shot)

	if params.has("asserts") and params["asserts"] is Array:
		var assert_results: Array = []
		for a in params["asserts"]:
			if a is Dictionary:
				var ar := await send_game_command("assert_node_state", a, 5.0)
				assert_results.append(ar.get("result", ar))
		report["asserts"] = assert_results

	if params.has("timeline") and params["timeline"] is Dictionary:
		var tl := await _run_capture_timeline(params["timeline"])
		report["timeline"] = tl.get("result", tl)

	var record_stop := {}
	if optional_bool(params, "record", false):
		record_stop = await _run_record_stop({"encode": optional_bool(params, "encode", true)})
		report["record"] = record_stop.get("result", record_stop)

	if optional_bool(params, "stop_after", true):
		await _run_session_stop({"stop_record": false})
		report["stopped"] = true

	var ok := errors.is_empty()
	if report.has("asserts"):
		for ar2 in report["asserts"]:
			if ar2 is Dictionary and ar2.get("passed", true) == false:
				ok = false
	report["ok"] = ok
	report["summary"] = "run_probe %s — %d debugger errors" % ["PASS" if ok else "FAIL", errors.size()]
	return success(report)
