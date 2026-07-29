@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## FFmpeg media tools for run recordings - keyframes, clips, contact sheets.
## Does not reimplement codecs; shells out to system ffmpeg when available.


func get_commands() -> Dictionary:
	return {
		"media_find_ffmpeg": _media_find_ffmpeg,
		"media_frames_to_video": _media_frames_to_video,
		"media_extract_keyframes": _media_extract_keyframes,
		"media_clip_video": _media_clip_video,
		"media_contact_sheet": _media_contact_sheet,
		"media_probe": _media_probe,
	}


func _ffmpeg_path() -> String:
	# Env override
	var env := OS.get_environment("FFMPEG_PATH")
	if not env.is_empty() and FileAccess.file_exists(env):
		return env
	# PATH lookup
	var candidates: Array = []
	if OS.get_name() == "Windows":
		candidates = ["ffmpeg.exe", "ffmpeg"]
	else:
		candidates = ["ffmpeg"]
	for c in candidates:
		var out: Array = []
		var code := OS.execute(c, PackedStringArray(["-version"]), out, true, false)
		if code == 0:
			return c
	return ""


func _media_find_ffmpeg(_params: Dictionary) -> Dictionary:
	var path := _ffmpeg_path()
	return success({
		"found": not path.is_empty(),
		"path": path,
		"hint": "Install FFmpeg and ensure it is on PATH, or set FFMPEG_PATH",
	})


func _globalize_user_or_res(p: String) -> String:
	if p.begins_with("user://") or p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return p


func _is_abs_path(p: String) -> bool:
	if p.is_empty():
		return false
	if p.begins_with("/") or p.begins_with("\\"):
		return true
	# Windows drive
	if p.length() >= 3 and p[1] == ":" and (p[2] == "/" or p[2] == "\\"):
		return true
	return false


func _frames_to_video_impl(params: Dictionary) -> Dictionary:
	var ff := _ffmpeg_path()
	if ff.is_empty():
		return error(-32000, "FFmpeg not found", {"suggestion": "Install FFmpeg or set FFMPEG_PATH"})
	var frames_dir: String = str(params.get("frames_dir", ""))
	if frames_dir.is_empty():
		return error_invalid_params("frames_dir required (user://mcp_recordings/session)")
	var abs_dir := _globalize_user_or_res(frames_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return error_not_found(frames_dir)
	var fps: float = float(params.get("fps", 10))
	var output: String = str(params.get("output_path", frames_dir.path_join("session.mp4")))
	if not output.begins_with("user://") and not output.begins_with("res://") and not _is_abs_path(output):
		output = frames_dir.path_join(output)
	var abs_out := _globalize_user_or_res(output)
	var parent := abs_out.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	var pattern := abs_dir.path_join("frame_%05d.png")
	# ffmpeg -y -framerate N -i frame_%05d.png -c:v libx264 -pix_fmt yuv420p out.mp4
	var args := PackedStringArray([
		"-y",
		"-framerate", str(fps),
		"-i", pattern,
		"-c:v", "libx264",
		"-pix_fmt", "yuv420p",
		"-movflags", "+faststart",
		abs_out,
	])
	var out_lines: Array = []
	var code := OS.execute(ff, args, out_lines, true, false)
	var exists := FileAccess.file_exists(abs_out)
	return {
		"ok": code == 0 and exists,
		"exit_code": code,
		"output_path": output,
		"absolute_path": abs_out,
		"file_exists": exists,
		"fps": fps,
		"log_tail": "\n".join(PackedStringArray(out_lines)).right(1500),
	}


func _media_frames_to_video(params: Dictionary) -> Dictionary:
	var r := _frames_to_video_impl(params)
	if r.has("ok") and not r["ok"] and r.get("exit_code", 0) != 0:
		return error(-32000, "FFmpeg frames_to_video failed", r)
	return success(r)


func _media_extract_keyframes(params: Dictionary) -> Dictionary:
	var ff := _ffmpeg_path()
	if ff.is_empty():
		return error(-32000, "FFmpeg not found", {"suggestion": "Install FFmpeg or set FFMPEG_PATH"})
	var video: String = str(params.get("video_path", params.get("path", "")))
	if video.is_empty():
		return error_invalid_params("video_path required")
	var abs_v := _globalize_user_or_res(video)
	if not FileAccess.file_exists(abs_v):
		return error_not_found(video)
	var fps: float = float(params.get("fps", 1.0))  # 1 keyframe per second
	var out_dir: String = str(params.get("output_dir", ""))
	if out_dir.is_empty():
		out_dir = video.get_basename() + "_keyframes"
	if not out_dir.begins_with("user://") and not out_dir.begins_with("res://") and not _is_abs_path(out_dir):
		out_dir = "user://mcp_recordings/" + out_dir.get_file()
	var abs_dir := _globalize_user_or_res(out_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var pattern := abs_dir.path_join("key_%04d.png")
	var args := PackedStringArray([
		"-y", "-i", abs_v,
		"-vf", "fps=%s" % str(fps),
		pattern,
	])
	var out_lines: Array = []
	var code := OS.execute(ff, args, out_lines, true, false)
	var files: Array = []
	var d := DirAccess.open(abs_dir)
	if d:
		d.list_dir_begin()
		var n := d.get_next()
		while not n.is_empty():
			if n.ends_with(".png"):
				if out_dir.begins_with("user://") or out_dir.begins_with("res://"):
					files.append(out_dir.rstrip("/") + "/" + n)
				else:
					files.append(abs_dir.path_join(n))
			n = d.get_next()
		d.list_dir_end()
	files.sort()
	return success({
		"ok": code == 0,
		"exit_code": code,
		"output_dir": out_dir,
		"keyframes": files,
		"count": files.size(),
		"fps": fps,
		"log_tail": "\n".join(PackedStringArray(out_lines)).right(800),
	})


func _media_clip_video(params: Dictionary) -> Dictionary:
	var ff := _ffmpeg_path()
	if ff.is_empty():
		return error(-32000, "FFmpeg not found")
	var video: String = str(params.get("video_path", params.get("path", "")))
	if video.is_empty():
		return error_invalid_params("video_path required")
	var abs_v := _globalize_user_or_res(video)
	if not FileAccess.file_exists(abs_v):
		return error_not_found(video)
	var start: float = float(params.get("start_sec", params.get("start", 0)))
	var duration: float = float(params.get("duration_sec", params.get("duration", 2.0)))
	if params.has("end_sec"):
		duration = float(params["end_sec"]) - start
	var output: String = str(params.get("output_path", video.get_basename() + "_clip.mp4"))
	if not output.begins_with("user://") and not output.begins_with("res://") and not _is_abs_path(output):
		output = "user://mcp_recordings/" + output.get_file()
	var abs_out := _globalize_user_or_res(output)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var args := PackedStringArray([
		"-y",
		"-ss", str(start),
		"-i", abs_v,
		"-t", str(duration),
		"-c", "copy",
		abs_out,
	])
	var out_lines: Array = []
	var code := OS.execute(ff, args, out_lines, true, false)
	if code != 0 or not FileAccess.file_exists(abs_out):
		args = PackedStringArray([
			"-y", "-ss", str(start), "-i", abs_v, "-t", str(duration),
			"-c:v", "libx264", "-pix_fmt", "yuv420p", abs_out,
		])
		out_lines.clear()
		code = OS.execute(ff, args, out_lines, true, false)
	return success({
		"ok": code == 0 and FileAccess.file_exists(abs_out),
		"exit_code": code,
		"output_path": output,
		"absolute_path": abs_out,
		"start_sec": start,
		"duration_sec": duration,
		"log_tail": "\n".join(PackedStringArray(out_lines)).right(800),
	})


func _media_contact_sheet(params: Dictionary) -> Dictionary:
	## Grid of frames for one multimodal glance.
	var ff := _ffmpeg_path()
	if ff.is_empty():
		return error(-32000, "FFmpeg not found")
	var video: String = str(params.get("video_path", params.get("path", "")))
	if video.is_empty():
		return error_invalid_params("video_path required")
	var abs_v := _globalize_user_or_res(video)
	if not FileAccess.file_exists(abs_v):
		return error_not_found(video)
	var cols: int = optional_int(params, "columns", 4)
	var rows: int = optional_int(params, "rows", 3)
	var output: String = str(params.get("output_path", video.get_basename() + "_sheet.jpg"))
	if not output.begins_with("user://") and not output.begins_with("res://") and not _is_abs_path(output):
		output = "user://mcp_recordings/" + output.get_file()
	var abs_out := _globalize_user_or_res(output)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var args := PackedStringArray([
		"-y", "-i", abs_v,
		"-frames:v", "1",
		"-q:v", "2",
		"-vf", "select='not(mod(n\\,30))',scale=160:-1,tile=%dx%d" % [cols, rows],
		abs_out,
	])
	var out_lines: Array = []
	var code := OS.execute(ff, args, out_lines, true, false)
	if code != 0 or not FileAccess.file_exists(abs_out):
		var kf := _media_extract_keyframes({
			"video_path": video,
			"fps": 0.5,
			"output_dir": "user://mcp_recordings/sheet_kf_%d" % Time.get_ticks_msec(),
		})
		return success({
			"ok": false,
			"fallback": "keyframes",
			"keyframes": kf.get("result", kf),
			"log_tail": "\n".join(PackedStringArray(out_lines)).right(800),
			"hint": "Contact sheet tile failed; use keyframes list for VLM",
		})
	return success({
		"ok": true,
		"output_path": output,
		"absolute_path": abs_out,
		"columns": cols,
		"rows": rows,
	})


func _media_probe(params: Dictionary) -> Dictionary:
	var ff := _ffmpeg_path()
	if ff.is_empty():
		return error(-32000, "FFmpeg not found")
	var video: String = str(params.get("video_path", params.get("path", "")))
	if video.is_empty():
		return error_invalid_params("video_path required")
	var abs_v := _globalize_user_or_res(video)
	if not FileAccess.file_exists(abs_v):
		return error_not_found(video)
	var args := PackedStringArray(["-v", "error", "-show_entries", "format=duration,size:stream=width,height,codec_name,avg_frame_rate", "-of", "json", abs_v])
	# ffprobe may be separate
	var probe := "ffprobe"
	if OS.get_name() == "Windows":
		probe = "ffprobe.exe"
	var out_lines: Array = []
	var code := OS.execute(probe, args, out_lines, true, false)
	if code != 0:
		# try ffmpeg -i
		out_lines.clear()
		code = OS.execute(ff, PackedStringArray(["-i", abs_v]), out_lines, true, false)
		return success({"path": video, "ffmpeg_i": "\n".join(PackedStringArray(out_lines)).right(2000), "note": "ffprobe unavailable; raw ffmpeg -i"})
	var text := "\n".join(PackedStringArray(out_lines))
	var parsed = JSON.parse_string(text)
	return success({"path": video, "probe": parsed if parsed else text})
