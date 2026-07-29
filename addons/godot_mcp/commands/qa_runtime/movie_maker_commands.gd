@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Movie Maker + agent capture session (human Movie Writer / Editor movie maker).


func get_commands() -> Dictionary:
	return {
		"set_movie_maker_enabled": _set_movie_maker_enabled,
		"get_movie_maker_settings": _get_movie_maker_settings,
		"set_movie_maker_output": _set_movie_maker_output,
		"play_with_movie_maker": _play_with_movie_maker,
		"capture_play_session": _capture_play_session,
		"list_movie_maker_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"human": "Editor Movie Maker toggle + MovieWriter project settings",
		"flow": [
			"set_movie_maker_output path=user://movie.avi fps=30",
			"play_with_movie_maker mode=main duration_sec=5",
			"OR capture_play_session (frame screenshots → media_frames_to_video)",
			"run_session_start record=true for TCP run-plane video",
		],
		"related": ["run_record_start", "media_frames_to_video", "playtest_sequence"],
	})


func _set_movie_maker_enabled(params: Dictionary) -> Dictionary:
	var enabled: bool = optional_bool(params, "enabled", true)
	if EditorInterface.has_method("set_movie_maker_enabled"):
		EditorInterface.set_movie_maker_enabled(enabled)
	else:
		# Fallback project setting used by some builds
		ProjectSettings.set_setting("editor/movie_writer/disable_vsync", true)
		return success({
			"enabled": enabled,
			"via": "partial",
			"hint": "set_movie_maker_enabled API missing — use play_with_movie_maker / capture_play_session",
		})
	var actual := false
	if EditorInterface.has_method("is_movie_maker_enabled"):
		actual = EditorInterface.is_movie_maker_enabled()
	return success({"enabled": actual, "requested": enabled})


func _get_movie_maker_settings(_params: Dictionary) -> Dictionary:
	var enabled := false
	if EditorInterface.has_method("is_movie_maker_enabled"):
		enabled = EditorInterface.is_movie_maker_enabled()
	return success({
		"movie_maker_enabled": enabled,
		"movie_file": ProjectSettings.get_setting("editor/movie_writer/movie_file", ""),
		"fps": ProjectSettings.get_setting("editor/movie_writer/fps", 0),
		"mix_rate": ProjectSettings.get_setting("editor/movie_writer/mix_rate", 0),
		"speaker_mode": ProjectSettings.get_setting("editor/movie_writer/speaker_mode", 0),
		"mjpeg_quality": ProjectSettings.get_setting("editor/movie_writer/mjpeg_quality", 0.75),
		"disable_vsync": ProjectSettings.get_setting("editor/movie_writer/disable_vsync", false),
		"playing": EditorInterface.is_playing_scene(),
	})


func _set_movie_maker_output(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", optional_string(params, "movie_file", "user://mcp_movie.avi"))
	if path.is_empty():
		return error_invalid_params("path required")
	# Movie writer typically wants OS path or user://
	ProjectSettings.set_setting("editor/movie_writer/movie_file", path)
	if params.has("fps"):
		ProjectSettings.set_setting("editor/movie_writer/fps", int(params["fps"]))
	if params.has("mix_rate"):
		ProjectSettings.set_setting("editor/movie_writer/mix_rate", int(params["mix_rate"]))
	if params.has("mjpeg_quality"):
		ProjectSettings.set_setting("editor/movie_writer/mjpeg_quality", float(params["mjpeg_quality"]))
	if params.has("disable_vsync"):
		ProjectSettings.set_setting("editor/movie_writer/disable_vsync", bool(params["disable_vsync"]))
	else:
		ProjectSettings.set_setting("editor/movie_writer/disable_vsync", true)
	ProjectSettings.save()
	return success({
		"movie_file": ProjectSettings.get_setting("editor/movie_writer/movie_file", ""),
		"fps": ProjectSettings.get_setting("editor/movie_writer/fps", 0),
		"disable_vsync": ProjectSettings.get_setting("editor/movie_writer/disable_vsync", false),
	})


func _play_with_movie_maker(params: Dictionary) -> Dictionary:
	## Enable movie maker, play scene for duration_sec, stop, disable movie maker.
	var duration: float = float(params.get("duration_sec", params.get("seconds", 5.0)))
	duration = clampf(duration, 0.5, 120.0)
	var mode: String = optional_string(params, "mode", "main")
	var path: String = optional_string(params, "path", "")
	var movie_file: String = optional_string(params, "movie_file", "")
	if not movie_file.is_empty():
		_set_movie_maker_output({"path": movie_file, "fps": int(params.get("fps", 30))})

	if EditorInterface.has_method("set_movie_maker_enabled"):
		EditorInterface.set_movie_maker_enabled(true)

	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
		await get_tree().create_timer(0.3).timeout

	match mode:
		"current":
			EditorInterface.play_current_scene()
		"custom":
			if path.is_empty():
				return error_invalid_params("custom needs path")
			if not path.begins_with("res://"):
				path = "res://" + path.trim_prefix("/")
			EditorInterface.play_custom_scene(path)
		_:
			EditorInterface.play_main_scene()

	var start := Time.get_ticks_msec()
	var attempts := 30
	while attempts > 0 and not EditorInterface.is_playing_scene():
		await get_tree().create_timer(0.1).timeout
		attempts -= 1
	await get_tree().create_timer(duration).timeout

	var errors: Array = collect_debugger_errors(15)
	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
	if EditorInterface.has_method("set_movie_maker_enabled"):
		EditorInterface.set_movie_maker_enabled(false)

	var out_file: String = str(ProjectSettings.get_setting("editor/movie_writer/movie_file", ""))
	var exists := false
	if not out_file.is_empty():
		var abs_p := ProjectSettings.globalize_path(out_file) if out_file.begins_with("user://") or out_file.begins_with("res://") else out_file
		exists = FileAccess.file_exists(abs_p)

	return success({
		"duration_sec": duration,
		"mode": mode,
		"movie_file": out_file,
		"file_exists": exists,
		"elapsed_ms": Time.get_ticks_msec() - start,
		"debugger_errors": errors,
		"movie_maker_disabled_after": true,
		"hint": "If file missing, engine MovieWriter may need .avi path writable; use capture_play_session as fallback",
	})


func _capture_play_session(params: Dictionary) -> Dictionary:
	## Portable agent capture: play, grab N screenshots at interval, optional FFmpeg encode.
	var duration: float = float(params.get("duration_sec", 3.0))
	duration = clampf(duration, 0.5, 60.0)
	var fps: float = float(params.get("fps", 5.0))
	fps = clampf(fps, 1.0, 30.0)
	var mode: String = optional_string(params, "mode", "main")
	var path: String = optional_string(params, "path", "")
	var frames_dir: String = optional_string(params, "frames_dir", "user://mcp_recordings/capture")
	var make_video: bool = optional_bool(params, "make_video", true)
	var output_video: String = optional_string(params, "output_path", frames_dir.path_join("capture.mp4"))

	# Ensure dir
	var abs_dir := ProjectSettings.globalize_path(frames_dir) if frames_dir.begins_with("user://") or frames_dir.begins_with("res://") else frames_dir
	DirAccess.make_dir_recursive_absolute(abs_dir)

	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
		await get_tree().create_timer(0.3).timeout

	match mode:
		"current":
			EditorInterface.play_current_scene()
		"custom":
			if path.is_empty():
				return error_invalid_params("custom needs path")
			if not path.begins_with("res://"):
				path = "res://" + path.trim_prefix("/")
			EditorInterface.play_custom_scene(path)
		_:
			EditorInterface.play_main_scene()

	var attempts := 30
	while attempts > 0 and not EditorInterface.is_playing_scene():
		await get_tree().create_timer(0.1).timeout
		attempts -= 1
	await get_tree().create_timer(float(params.get("settle_sec", 0.5))).timeout

	var interval := 1.0 / fps
	var frame_count := int(duration * fps)
	frame_count = clampi(frame_count, 1, 300)
	var saved: Array = []
	for i in range(frame_count):
		if not EditorInterface.is_playing_scene():
			break
		if is_debugger_paused():
			try_debugger_continue()
		var shot: Dictionary = await send_game_command("get_screenshot", {}, 6.0)
		var fname := "frame_%05d.png" % i
		var fpath := frames_dir.rstrip("/") + "/" + fname
		if shot.has("result") and shot["result"] is Dictionary:
			var sr: Dictionary = shot["result"]
			if sr.has("image_base64") and str(sr["image_base64"]).length() > 32:
				var raw := Marshalls.base64_to_raw(str(sr["image_base64"]))
				var abs_f := ProjectSettings.globalize_path(fpath) if fpath.begins_with("user://") or fpath.begins_with("res://") else fpath
				var img := Image.new()
				# Prefer PNG buffer; fallback write raw if already png
				var load_err := img.load_png_from_buffer(raw)
				if load_err == OK:
					img.save_png(abs_f)
					saved.append(fpath)
				else:
					# Write raw bytes
					var wf := FileAccess.open(abs_f, FileAccess.WRITE)
					if wf:
						wf.store_buffer(raw)
						wf.close()
						saved.append(fpath)
			elif sr.has("path") and not str(sr["path"]).is_empty():
				saved.append(str(sr["path"]))
		await get_tree().create_timer(interval).timeout

	if EditorInterface.is_playing_scene() and optional_bool(params, "stop_after", true):
		EditorInterface.stop_playing_scene()

	var video_result = null
	if make_video and saved.size() > 0:
		# Delegate to media module via router if present
		var router = get_parent()
		if router and router.has_method("execute"):
			video_result = await router.execute("media_frames_to_video", {
				"frames_dir": frames_dir,
				"fps": fps,
				"output_path": output_video,
			})
		else:
			video_result = {"hint": "call media_frames_to_video manually", "frames_dir": frames_dir}

	return success({
		"frames_dir": frames_dir,
		"frames_saved": saved.size(),
		"fps": fps,
		"duration_sec": duration,
		"output_path": output_video,
		"video": video_result,
		"sample_frames": saved.slice(0, mini(5, saved.size())),
	})
