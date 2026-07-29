## Video record + property timeline + event log for MCPGameInspector.
## Owns capture state; host Node provides viewport/tree and _write_response / _serialize_value.
extends RefCounted

enum Mode { OFF, VIDEO, TIMELINE }

const LOG_RING_MAX := 200

var host: Node = null  # MCPGameInspector autoload
var mode: Mode = Mode.OFF

# Video
var video_dir: String = ""
var video_frame_idx: int = 0
var video_fps: float = 10.0
var video_accum: float = 0.0
var video_half: bool = true
var video_events: Array = []
var video_start_msec: int = 0
var video_max_frames: int = 900
var video_track_nodes: Array = []
var video_save_images: bool = true

# Timeline
var timeline_remaining_sec: float = 0.0
var timeline_interval_sec: float = 0.1
var timeline_accum: float = 0.0
var timeline_samples: Array = []
var timeline_nodes: Array = []
var timeline_include_images: bool = false
var timeline_half: bool = true

# Shared log ring
var log_ring: Array = []


func setup(p_host: Node) -> void:
	host = p_host


func is_video() -> bool:
	return mode == Mode.VIDEO


func is_timeline() -> bool:
	return mode == Mode.TIMELINE


func is_active() -> bool:
	return mode != Mode.OFF


func session_t() -> float:
	return (Time.get_ticks_msec() - video_start_msec) / 1000.0 if video_start_msec > 0 else 0.0


func _serialize(v: Variant) -> Variant:
	if host and host.has_method("_serialize_value"):
		return host._serialize_value(v)
	return v


func _write(data: Dictionary) -> void:
	if host and host.has_method("_write_response"):
		host._write_response(data)


func _set_host_idle() -> void:
	if host:
		host._state = host.State.IDLE


func _set_host_video() -> void:
	if host:
		host._state = host.State.VIDEO_RECORDING


func _set_host_timeline() -> void:
	if host:
		host._state = host.State.CAPTURING_TIMELINE


func _clear_pending() -> void:
	if host:
		host._pending_command = false


func append_log(level: String, message: String, extra: Dictionary = {}) -> void:
	var entry := {
		"t": session_t() if is_active() else Time.get_ticks_msec() / 1000.0,
		"level": level,
		"message": message,
	}
	for k in extra:
		entry[k] = extra[k]
	log_ring.append(entry)
	while log_ring.size() > LOG_RING_MAX:
		log_ring.pop_front()
	if mode == Mode.VIDEO:
		video_events.append(entry)
		_flush_event_line(entry)


func _flush_event_line(entry: Dictionary) -> void:
	if video_dir.is_empty():
		return
	var path := video_dir.path_join("events.jsonl")
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(entry))
	f.close()


func start_video(params: Dictionary) -> void:
	_clear_pending()
	var session_id: String = str(params.get("session_id", "session_%d" % Time.get_ticks_msec()))
	video_dir = "user://mcp_recordings/%s" % session_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(video_dir))
	video_frame_idx = 0
	video_fps = clampf(float(params.get("fps", 10.0)), 1.0, 30.0)
	video_accum = 0.0
	video_half = bool(params.get("half_resolution", true))
	video_max_frames = clampi(int(params.get("max_frames", 900)), 30, 3600)
	video_save_images = bool(params.get("save_images", true))
	video_events.clear()
	video_track_nodes.clear()
	if params.has("track_nodes") and params["track_nodes"] is Array:
		video_track_nodes = params["track_nodes"]
	video_start_msec = Time.get_ticks_msec()
	var ef := FileAccess.open(video_dir.path_join("events.jsonl"), FileAccess.WRITE)
	if ef:
		ef.close()
	mode = Mode.VIDEO
	_set_host_video()
	append_log("info", "video_record_start", {"session_id": session_id, "fps": video_fps})
	_write({
		"recording": true,
		"session_id": session_id,
		"dir": video_dir,
		"fps": video_fps,
		"half_resolution": video_half,
		"max_frames": video_max_frames,
		"hint": "stop_video_record then media_frames_to_video / media_extract_keyframes",
	})


func process_video(delta: float) -> void:
	if mode != Mode.VIDEO:
		return
	if video_frame_idx >= video_max_frames:
		finalize_video(true)
		return
	video_accum += delta
	var interval := 1.0 / video_fps
	if video_accum < interval:
		return
	video_accum = 0.0
	if not video_save_images:
		video_frame_idx += 1
		return
	if host == null:
		return
	var viewport := host.get_viewport()
	if viewport == null:
		return
	var image := viewport.get_texture().get_image()
	if image == null:
		return
	if video_half:
		var ns := image.get_size() / 2
		if ns.x >= 2 and ns.y >= 2:
			image.resize(ns.x, ns.y, Image.INTERPOLATE_BILINEAR)
	var fname := "frame_%05d.png" % video_frame_idx
	image.save_png(video_dir.path_join(fname))
	if not video_track_nodes.is_empty() and host.get_tree():
		var sample_props := {}
		for spec in video_track_nodes:
			if not spec is Dictionary:
				continue
			var np := str(spec.get("node_path", ""))
			var node := host.get_tree().root.get_node_or_null(np) if not np.is_empty() else null
			if node == null:
				continue
			var bag := {}
			for p in spec.get("properties", []):
				bag[str(p)] = _serialize(node.get(str(p)))
			sample_props[np] = bag
		_flush_event_line({
			"t": session_t(),
			"type": "sample",
			"frame": video_frame_idx,
			"props": sample_props,
		})
	video_frame_idx += 1


func finalize_video(auto: bool) -> Dictionary:
	var duration := session_t()
	var meta := {
		"dir": video_dir,
		"frame_count": video_frame_idx,
		"fps": video_fps,
		"duration_sec": duration,
		"events_path": video_dir.path_join("events.jsonl") if not video_dir.is_empty() else "",
		"frame_pattern": video_dir.path_join("frame_%05d.png") if not video_dir.is_empty() else "",
		"half_resolution": video_half,
		"auto_stopped": auto,
		"event_count": video_events.size(),
	}
	if not video_dir.is_empty():
		var mf := FileAccess.open(video_dir.path_join("meta.json"), FileAccess.WRITE)
		if mf:
			mf.store_string(JSON.stringify(meta, "\t"))
			mf.close()
	mode = Mode.OFF
	_set_host_idle()
	append_log("info", "video_record_stop", meta)
	return meta


func stop_video() -> void:
	if mode != Mode.VIDEO and video_dir.is_empty():
		_write({"error": "No video recording in progress"})
		return
	var meta := finalize_video(false)
	_write({"recording": false, "meta": meta})


func log_event(params: Dictionary) -> void:
	var type: String = str(params.get("type", params.get("event_type", "event")))
	var message: String = str(params.get("message", params.get("name", type)))
	var level: String = str(params.get("level", "info"))
	var extra: Dictionary = {}
	if params.has("data") and params["data"] is Dictionary:
		extra = params["data"]
	extra["type"] = type
	append_log(level, message, extra)
	_write({"logged": true, "t": session_t(), "type": type, "message": message})


func get_events(params: Dictionary) -> void:
	var max_n: int = clampi(int(params.get("max", 100)), 1, 500)
	var out: Array = []
	if not video_dir.is_empty() and FileAccess.file_exists(video_dir.path_join("events.jsonl")):
		var f := FileAccess.open(video_dir.path_join("events.jsonl"), FileAccess.READ)
		if f:
			while not f.eof_reached():
				var line := f.get_line().strip_edges()
				if line.is_empty():
					continue
				var parsed = JSON.parse_string(line)
				if parsed is Dictionary:
					out.append(parsed)
			f.close()
	else:
		out = video_events.duplicate()
	if out.size() > max_n:
		out = out.slice(out.size() - max_n)
	_write({"events": out, "count": out.size(), "dir": video_dir})


func get_logs(params: Dictionary, state_name: String) -> void:
	var max_n: int = clampi(int(params.get("max", 50)), 1, LOG_RING_MAX)
	var level_filter: String = str(params.get("level", ""))
	var out: Array = []
	for e in log_ring:
		if not level_filter.is_empty() and str(e.get("level", "")) != level_filter:
			continue
		out.append(e)
	if out.size() > max_n:
		out = out.slice(out.size() - max_n)
	_write({
		"logs": out,
		"count": out.size(),
		"playing": true,
		"state": state_name,
		"video_recording": mode == Mode.VIDEO,
	})


func status_extras() -> Dictionary:
	return {
		"video_recording": mode == Mode.VIDEO,
		"video_dir": video_dir,
		"video_frames": video_frame_idx,
		"video_t": session_t() if mode == Mode.VIDEO else 0.0,
		"log_count": log_ring.size(),
	}


func start_timeline(params: Dictionary) -> void:
	_clear_pending()
	var duration: float = clampf(float(params.get("duration_sec", params.get("duration", 2.0))), 0.1, 30.0)
	timeline_interval_sec = clampf(float(params.get("interval_sec", 0.1)), 0.033, 2.0)
	timeline_include_images = bool(params.get("include_images", false))
	timeline_half = bool(params.get("half_resolution", true))
	timeline_nodes.clear()
	if params.has("nodes") and params["nodes"] is Array:
		timeline_nodes = params["nodes"]
	elif params.has("node_path"):
		timeline_nodes = [{
			"node_path": params["node_path"],
			"properties": params.get("properties", []),
		}]
	if timeline_nodes.is_empty():
		_write({"error": "Provide nodes:[{node_path,properties}] or node_path+properties"})
		return
	timeline_samples.clear()
	timeline_remaining_sec = duration
	timeline_accum = 0.0
	video_start_msec = Time.get_ticks_msec()
	mode = Mode.TIMELINE
	_set_host_timeline()
	_sample_timeline_once()


func process_timeline(delta: float) -> void:
	if mode != Mode.TIMELINE:
		return
	timeline_remaining_sec -= delta
	timeline_accum += delta
	if timeline_accum >= timeline_interval_sec:
		timeline_accum = 0.0
		_sample_timeline_once()
	if timeline_remaining_sec <= 0.0:
		_finish_timeline()


func _sample_timeline_once() -> void:
	if host == null or host.get_tree() == null:
		return
	var sample := {"t": (Time.get_ticks_msec() - video_start_msec) / 1000.0, "nodes": {}}
	for spec in timeline_nodes:
		if not spec is Dictionary:
			continue
		var np := str(spec.get("node_path", ""))
		var node := host.get_tree().root.get_node_or_null(np)
		if node == null:
			sample["nodes"][np] = {"error": "not_found"}
			continue
		var bag := {"type": node.get_class()}
		var props: Array = spec.get("properties", [])
		if props.is_empty():
			if "position" in node:
				bag["position"] = _serialize(node.get("position"))
			if "visible" in node:
				bag["visible"] = node.get("visible")
		else:
			for p in props:
				bag[str(p)] = _serialize(node.get(str(p)))
		sample["nodes"][np] = bag
	if timeline_include_images:
		var viewport := host.get_viewport()
		if viewport:
			var image := viewport.get_texture().get_image()
			if image:
				if timeline_half:
					var ns := image.get_size() / 2
					if ns.x >= 2 and ns.y >= 2:
						image.resize(ns.x, ns.y, Image.INTERPOLATE_BILINEAR)
				sample["image_b64"] = Marshalls.raw_to_base64(image.save_png_to_buffer())
	timeline_samples.append(sample)


func _finish_timeline() -> void:
	mode = Mode.OFF
	_set_host_idle()
	var dur := 0.0
	if not timeline_samples.is_empty():
		dur = float(timeline_samples[timeline_samples.size() - 1].get("t", 0.0))
	_write({
		"samples": timeline_samples,
		"count": timeline_samples.size(),
		"duration_sec": dur,
		"include_images": timeline_include_images,
	})
	timeline_samples.clear()


func abort_to_idle() -> void:
	## Called when a non-concurrent command aborts capture modes.
	if mode == Mode.VIDEO and not video_dir.is_empty():
		finalize_video(true)
	mode = Mode.OFF
