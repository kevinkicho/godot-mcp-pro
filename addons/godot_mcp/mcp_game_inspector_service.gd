## Autoload injected by Godot MCP Pro plugin at runtime.
## Handles runtime game inspection: scene tree, node properties, frame capture, property monitoring.
## Transport: file IPC (legacy) + TCP JSON-lines on 127.0.0.1:6510-6514 (preferred).
extends Node

const REQUEST_PATH := "user://mcp_game_request"
const RESPONSE_PATH := "user://mcp_game_response"
const RUNTIME_PORT_FILE := "user://mcp_runtime_port"
const RUNTIME_PORT_START := 6510
const RUNTIME_PORT_END := 6514

enum State { IDLE, CAPTURING_FRAMES, MONITORING, RECORDING, MOVING_TO, WATCHING_SIGNALS, VIDEO_RECORDING, CAPTURING_TIMELINE }

var _state := State.IDLE
var _pending_command: bool = false  # Crash recovery flag

# Video / session recording (frames + event sidecar — agent visual probe)
var _video_dir: String = ""
var _video_frame_idx: int = 0
var _video_fps: float = 10.0
var _video_accum: float = 0.0
var _video_half: bool = true
var _video_events: Array = []  # JSONL-compatible event dicts
var _video_start_msec: int = 0
var _video_max_frames: int = 900
var _video_track_nodes: Array = []  # [{node_path, properties:[]}]
var _video_save_images: bool = true
var _log_ring: Array = []  # recent events/errors for get_run_logs
const LOG_RING_MAX := 200

# Timeline capture (structured + optional frames without full video)
var _timeline_remaining_sec: float = 0.0
var _timeline_interval_sec: float = 0.1
var _timeline_accum: float = 0.0
var _timeline_samples: Array = []
var _timeline_nodes: Array = []
var _timeline_include_images: bool = false
var _timeline_half: bool = true

# Frame capture state
var _capture_frames_remaining: int = 0
var _capture_frame_interval: int = 1
var _capture_frame_counter: int = 0
var _capture_half_res: bool = true
var _captured_images: Array = []  # Array of base64 strings
var _capture_node_path: String = ""  # Optional node to track per frame
var _capture_node_props: Array = []  # Properties to snapshot per frame
var _capture_frame_data: Array = []  # Array of per-frame node snapshots

# Recording state
var _recording_events: Array = []
var _recording_start_msec: int = 0

# Monitor state
var _monitor_node_path: String = ""
var _monitor_properties: Array = []
var _monitor_frames_remaining: int = 0
var _monitor_frame_interval: int = 1
var _monitor_frame_counter: int = 0
var _monitor_timeline: Array = []  # Array of sample dicts

# Signal watch state
var _watch_nodes: Array = []  # Array of node paths being watched
var _watch_signal_filter: Array = []  # Optional signal name filter
var _watch_log: Array = []  # Array of {time_ms, node, signal, args}
var _watch_start_msec: int = 0
var _watch_duration_ms: int = 5000
var _watch_connections: Array = []  # Array of {node, signal, callable} for cleanup

# Move-to state
var _moveto_target: Vector3 = Vector3.ZERO
var _moveto_player: Node3D = null
var _moveto_camera_pivot: Node3D = null
var _moveto_arrival_radius: float = 1.5
var _moveto_timeout: float = 15.0
var _moveto_elapsed: float = 0.0
var _moveto_run: bool = false
var _moveto_look_at: bool = true
var _moveto_keys_held: Array = []  # Track injected keys for guaranteed release

# TCP runtime probe server (preferred over file IPC)
var _tcp: TCPServer
var _tcp_port: int = 0
var _tcp_clients: Array = []  # Array of StreamPeerTCP
var _pending_tcp: StreamPeerTCP = null
var _pending_tcp_id: int = 0
var _tcp_buffers: Dictionary = {}  # instance_id -> String partial line
# Multi-client queue — serialize dispatch so concurrent agents don't race
var _tcp_queue: Array = []  # Array of {peer, id, command, params}
var _dispatch_busy: bool = false
const MAX_TCP_CLIENTS := 8
const MAX_TCP_QUEUE := 48
const RUNTIME_META_FILE := "user://mcp_runtime_meta.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_runtime_tcp()


func _exit_tree() -> void:
	_stop_runtime_tcp()


func _expected_runtime_token() -> String:
	## Optional shared secret. Empty = open on localhost only (default).
	var t := OS.get_environment("MCP_RUNTIME_TOKEN")
	if t.is_empty() and ProjectSettings.has_setting("mcp/runtime_token"):
		t = str(ProjectSettings.get_setting("mcp/runtime_token", ""))
	return t


func _auth_required() -> bool:
	return not _expected_runtime_token().is_empty()


func _request_authorized(parsed: Dictionary) -> bool:
	var expected := _expected_runtime_token()
	if expected.is_empty():
		return true
	var got := str(parsed.get("token", parsed.get("auth", "")))
	if got.is_empty() and parsed.get("params") is Dictionary:
		got = str(parsed["params"].get("token", parsed["params"].get("auth", "")))
	return got == expected


func _write_runtime_meta() -> void:
	var meta := {
		"port": _tcp_port,
		"host": "127.0.0.1",
		"auth_required": _auth_required(),
		"max_clients": MAX_TCP_CLIENTS,
		"max_queue": MAX_TCP_QUEUE,
		"protocol": "json_lines_v1",
	}
	var f := FileAccess.open(RUNTIME_META_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))
		f.close()
	var pf := FileAccess.open(RUNTIME_PORT_FILE, FileAccess.WRITE)
	if pf:
		pf.store_string(str(_tcp_port))
		pf.close()


func _start_runtime_tcp() -> void:
	## Always listen so editor Play AND standalone CLI/export can attach.
	## Bind 127.0.0.1 only — never expose on 0.0.0.0.
	_tcp = TCPServer.new()
	for port in range(RUNTIME_PORT_START, RUNTIME_PORT_END + 1):
		var err := _tcp.listen(port, "127.0.0.1")
		if err == OK:
			_tcp_port = port
			_write_runtime_meta()
			var auth_note := " auth=on" if _auth_required() else " auth=off"
			print("[MCP] Runtime probe TCP 127.0.0.1:%d (queue=%d%s)" % [port, MAX_TCP_QUEUE, auth_note])
			return
	_tcp = null
	push_warning("[MCP] Runtime TCP ports %d-%d busy — file IPC only" % [RUNTIME_PORT_START, RUNTIME_PORT_END])


func _stop_runtime_tcp() -> void:
	_tcp_queue.clear()
	_dispatch_busy = false
	for c in _tcp_clients:
		if c is StreamPeerTCP:
			(c as StreamPeerTCP).disconnect_from_host()
	_tcp_clients.clear()
	_tcp_buffers.clear()
	if _tcp:
		_tcp.stop()
		_tcp = null
	_tcp_port = 0


func _poll_runtime_tcp() -> void:
	if _tcp == null:
		return
	# Accept new clients (cap concurrent sockets)
	while _tcp.is_connection_available():
		if _tcp_clients.size() >= MAX_TCP_CLIENTS:
			var reject: StreamPeerTCP = _tcp.take_connection()
			if reject:
				_tcp_send(reject, {"id": 0, "ok": false, "error": "too many clients", "code": "max_clients"})
				reject.disconnect_from_host()
			break
		var peer: StreamPeerTCP = _tcp.take_connection()
		if peer:
			_tcp_clients.append(peer)
			_tcp_buffers[peer.get_instance_id()] = ""
	var dead: Array = []
	for peer in _tcp_clients:
		if not peer is StreamPeerTCP:
			continue
		var p: StreamPeerTCP = peer
		p.poll()
		var st := p.get_status()
		if st != StreamPeerTCP.STATUS_CONNECTED:
			if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
				dead.append(p)
			continue
		var avail := p.get_available_bytes()
		if avail <= 0:
			continue
		var got: Array = p.get_data(avail)
		if got.size() < 2 or got[0] != OK:
			continue
		var chunk: PackedByteArray = got[1]
		var id := p.get_instance_id()
		var buf: String = str(_tcp_buffers.get(id, "")) + chunk.get_string_from_utf8()
		while true:
			var nl := buf.find("\n")
			if nl < 0:
				break
			var line := buf.substr(0, nl).strip_edges()
			buf = buf.substr(nl + 1)
			if not line.is_empty():
				_handle_tcp_line(p, line)
		_tcp_buffers[id] = buf
	for d in dead:
		_drop_tcp_client(d)
	# If idle, pull next queued request
	if not _dispatch_busy and not _pending_command:
		_drain_tcp_queue()


func _drop_tcp_client(p: StreamPeerTCP) -> void:
	# Drop queued work for this peer
	var kept: Array = []
	for item in _tcp_queue:
		if item is Dictionary and item.get("peer") == p:
			continue
		kept.append(item)
	_tcp_queue = kept
	_tcp_clients.erase(p)
	_tcp_buffers.erase(p.get_instance_id())
	if _pending_tcp == p:
		_pending_tcp = null


func _handle_tcp_line(peer: StreamPeerTCP, line: String) -> void:
	var parsed = JSON.parse_string(line)
	if parsed == null or not parsed is Dictionary:
		_tcp_send(peer, {"id": 0, "ok": false, "error": "Invalid JSON", "code": "bad_json"})
		return
	var req_id: int = int(parsed.get("id", 0))
	if not _request_authorized(parsed):
		_tcp_send(peer, {
			"id": req_id,
			"ok": false,
			"error": "unauthorized — set MCP_RUNTIME_TOKEN or mcp/runtime_token and pass token= in request",
			"code": "auth_required",
			"auth_required": true,
		})
		return
	var command: String = str(parsed.get("command", ""))
	var params: Dictionary = parsed.get("params", {}) if parsed.get("params") is Dictionary else {}
	if command.is_empty():
		_tcp_send(peer, {"id": req_id, "ok": false, "error": "command required", "code": "bad_request"})
		return
	# Serialize: queue if a command is in flight
	if _dispatch_busy or _pending_command:
		if _tcp_queue.size() >= MAX_TCP_QUEUE:
			_tcp_send(peer, {
				"id": req_id,
				"ok": false,
				"error": "runtime queue full (%d)" % MAX_TCP_QUEUE,
				"code": "queue_full",
				"queue_depth": _tcp_queue.size(),
			})
			return
		_tcp_queue.append({
			"peer": peer,
			"id": req_id,
			"command": command,
			"params": params,
			"enqueued_ms": Time.get_ticks_msec(),
		})
		return
	_begin_tcp_dispatch(peer, req_id, command, params)


func _begin_tcp_dispatch(peer: StreamPeerTCP, req_id: int, command: String, params: Dictionary) -> void:
	_dispatch_busy = true
	_pending_tcp = peer
	_pending_tcp_id = req_id
	_dispatch_command(command, params)


func _drain_tcp_queue() -> void:
	if _dispatch_busy or _pending_command:
		return
	while not _tcp_queue.is_empty():
		var item: Dictionary = _tcp_queue.pop_front()
		var peer: StreamPeerTCP = item.get("peer")
		if peer == null or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		_begin_tcp_dispatch(peer, int(item.get("id", 0)), str(item.get("command", "")), item.get("params", {}))
		return


func _tcp_send(peer: StreamPeerTCP, obj: Dictionary) -> void:
	if peer == null:
		return
	var line := JSON.stringify(obj) + "\n"
	peer.put_data(line.to_utf8_buffer())


func _process(_delta: float) -> void:
	_poll_runtime_tcp()

	# Crash recovery: if a command was in progress but never wrote a response
	if _pending_command and not FileAccess.file_exists(REQUEST_PATH) and not FileAccess.file_exists(RESPONSE_PATH):
		push_warning("[MCP] Recovered from crashed command — writing error response")
		_pending_command = false
		_state = State.IDLE
		# Signal editor plugin to auto-press debugger Continue
		var flag := FileAccess.open("user://mcp_debugger_continue", FileAccess.WRITE)
		if flag:
			flag.close()
		_write_response({"error": "Command crashed (runtime error). Check Godot debugger."})
		return

	match _state:
		State.IDLE:
			if FileAccess.file_exists(REQUEST_PATH):
				_handle_request()
		State.CAPTURING_FRAMES:
			_process_capture()
		State.MONITORING:
			_process_monitor()
		State.RECORDING:
			if FileAccess.file_exists(REQUEST_PATH):
				_handle_request()
		State.MOVING_TO:
			_process_move_to(_delta)
		State.WATCHING_SIGNALS:
			_process_watch_signals()
		State.VIDEO_RECORDING:
			_process_video_record(_delta)
			if FileAccess.file_exists(REQUEST_PATH):
				_handle_request()
		State.CAPTURING_TIMELINE:
			_process_timeline(_delta)
			if FileAccess.file_exists(REQUEST_PATH):
				_handle_request()


# ── Request handling ──────────────────────────────────────────────────────────

func _handle_request() -> void:
	var file := FileAccess.open(REQUEST_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(REQUEST_PATH)

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		_write_response({"error": "Invalid request JSON"})
		return

	var command: String = parsed.get("command", "")
	var params: Dictionary = parsed.get("params", {})
	_pending_tcp = null
	_pending_tcp_id = 0
	_dispatch_command(command, params)


func _dispatch_command(command: String, params: Dictionary) -> void:
	# Commands that may run during video/timeline without aborting them
	var concurrent_ok := command in [
		"log_run_event", "get_run_events", "get_run_logs", "get_run_status",
		"get_performance_monitors", "get_node_properties", "get_scene_tree",
		"find_nodes", "assert_node_state", "batch_get_properties", "get_autoload",
		"stop_video_record", "ping_runtime", "get_runtime_info",
	]
	var was_video := _state == State.VIDEO_RECORDING
	var was_timeline := _state == State.CAPTURING_TIMELINE
	if not concurrent_ok:
		# Abort any in-progress operation
		_state = State.IDLE
	_pending_command = true

	match command:
		"ping_runtime":
			_write_response({
				"pong": true,
				"tcp_port": _tcp_port,
				"state": _state_name(),
				"transport": "tcp" if _pending_tcp else "file",
				"auth_required": _auth_required(),
				"queue_depth": _tcp_queue.size(),
				"clients": _tcp_clients.size(),
				"max_clients": MAX_TCP_CLIENTS,
				"max_queue": MAX_TCP_QUEUE,
			})
		"get_runtime_info":
			_write_response({
				"tcp_port": _tcp_port,
				"host": "127.0.0.1",
				"auth_required": _auth_required(),
				"queue_depth": _tcp_queue.size(),
				"clients": _tcp_clients.size(),
				"max_clients": MAX_TCP_CLIENTS,
				"max_queue": MAX_TCP_QUEUE,
				"dispatch_busy": _dispatch_busy,
				"state": _state_name(),
				"protocol": "json_lines_v1",
			})
		"get_scene_tree":
			_cmd_get_scene_tree(params)
		"get_node_properties":
			_cmd_get_node_properties(params)
		"set_node_property":
			_cmd_set_node_property(params)
		"capture_frames":
			_cmd_capture_frames(params)
		"monitor_properties":
			_cmd_monitor_properties(params)
		"execute_script":
			_cmd_execute_script(params)
		"start_recording":
			_cmd_start_recording(params)
		"stop_recording":
			_cmd_stop_recording(params)
		"replay_recording":
			_cmd_replay_recording(params)
		"find_nodes_by_script":
			_cmd_find_nodes_by_script(params)
		"get_autoload":
			_cmd_get_autoload(params)
		"batch_get_properties":
			_cmd_batch_get_properties(params)
		"find_ui_elements":
			_cmd_find_ui_elements(params)
		"click_button_by_text":
			_cmd_click_button_by_text(params)
		"wait_for_node":
			_cmd_wait_for_node(params)
		"find_nearby_nodes":
			_cmd_find_nearby_nodes(params)
		"navigate_to":
			_cmd_navigate_to(params)
		"move_to":
			_cmd_move_to(params)
		"watch_signals":
			_cmd_watch_signals(params)
		"assert_node_state":
			_cmd_assert_node_state(params)
		"get_performance_monitors":
			_cmd_get_performance_monitors(params)
		# Native run probe v2 — video session, timeline, events, find
		"start_video_record":
			_cmd_start_video_record(params)
		"stop_video_record":
			_cmd_stop_video_record(params)
		"log_run_event":
			_cmd_log_run_event(params)
		"get_run_events":
			_cmd_get_run_events(params)
		"get_run_logs":
			_cmd_get_run_logs(params)
		"get_run_status":
			_cmd_get_run_status(params)
		"capture_timeline":
			_cmd_capture_timeline(params)
		"find_nodes":
			_cmd_find_nodes(params)
		_:
			_write_response({"error": "Unknown command: %s" % command})

	# Restore long-running states after concurrent probes
	if concurrent_ok and command != "stop_video_record":
		if was_video and _state == State.IDLE:
			_state = State.VIDEO_RECORDING
		elif was_timeline and _state == State.IDLE and command != "capture_timeline":
			_state = State.CAPTURING_TIMELINE


# ── get_scene_tree ────────────────────────────────────────────────────────────

func _cmd_get_scene_tree(params: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var max_depth: int = params.get("max_depth", -1)
	var script_filter: String = params.get("script_filter", "")
	var type_filter: String = params.get("type_filter", "")
	var named_only: bool = params.get("named_only", false)

	var has_filter: bool = not script_filter.is_empty() or not type_filter.is_empty() or named_only

	if has_filter:
		var tree: Variant = _build_filtered_node_tree(root, max_depth, script_filter, type_filter, named_only)
		if tree == null:
			_write_response({"tree": null, "message": "No nodes matched the filter"})
		else:
			_write_response({"tree": tree})
	else:
		var tree := _build_node_tree(root, max_depth)
		_write_response({"tree": tree})


func _build_node_tree(node: Node, max_depth: int, current_depth: int = 0) -> Dictionary:
	var result := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	var script: Script = node.get_script()
	if script:
		result["script"] = script.resource_path

	if max_depth == -1 or current_depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			children.append(_build_node_tree(child, max_depth, current_depth + 1))
		if not children.is_empty():
			result["children"] = children

	return result


## Build a filtered tree. Returns null if this subtree has no matches.
func _build_filtered_node_tree(node: Node, max_depth: int, script_filter: String, type_filter: String, named_only: bool, current_depth: int = 0) -> Variant:
	var node_matches := _node_matches_filter(node, script_filter, type_filter, named_only)

	# Build children first to check if any descendant matches
	var matched_children: Array = []
	if max_depth == -1 or current_depth < max_depth:
		for child in node.get_children():
			var child_tree: Variant = _build_filtered_node_tree(child, max_depth, script_filter, type_filter, named_only, current_depth + 1)
			if child_tree != null:
				matched_children.append(child_tree)

	# Include this node if it matches or if any descendant matches
	if not node_matches and matched_children.is_empty():
		return null

	var result := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	var script: Script = node.get_script()
	if script:
		result["script"] = script.resource_path

	if not matched_children.is_empty():
		result["children"] = matched_children

	return result


func _node_matches_filter(node: Node, script_filter: String, type_filter: String, named_only: bool) -> bool:
	if named_only and (node.name as String).begins_with("@"):
		return false
	if not type_filter.is_empty() and not node.is_class(type_filter):
		return false
	if not script_filter.is_empty():
		var script: Script = node.get_script()
		if script == null:
			return false
		if not script.resource_path.to_lower().contains(script_filter.to_lower()):
			return false
	return true


# ── get_node_properties ───────────────────────────────────────────────────────

func _cmd_get_node_properties(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_write_response({"error": "node_path is required"})
		return

	var node := get_node_or_null(NodePath(node_path))
	if node == null:
		_write_response({"error": "Node not found: %s" % node_path})
		return

	var filter: Array = params.get("properties", [])
	var props: Dictionary = {}

	if filter.is_empty():
		for prop_info in node.get_property_list():
			var prop_name: String = prop_info["name"]
			var usage: int = prop_info["usage"]
			if not (usage & PROPERTY_USAGE_EDITOR):
				continue
			if prop_name.begins_with("_") or prop_name == "script":
				continue
			props[prop_name] = _serialize_value(node.get(prop_name))
	else:
		for prop_name: String in filter:
			var value: Variant = node.get(prop_name)
			props[prop_name] = _serialize_value(value)

	_write_response({
		"node_path": str(node.get_path()),
		"type": node.get_class(),
		"properties": props,
	})


# ── capture_frames ────────────────────────────────────────────────────────────

func _cmd_capture_frames(params: Dictionary) -> void:
	_pending_command = false  # Async command — don't trigger crash recovery
	var count: int = clampi(params.get("count", 5), 1, 30)
	var interval: int = maxi(params.get("frame_interval", 10), 1)
	_capture_half_res = params.get("half_resolution", true)

	# Optional node_data tracking
	_capture_node_path = ""
	_capture_node_props = []
	_capture_frame_data.clear()
	var node_data: Dictionary = params.get("node_data", {})
	if not node_data.is_empty():
		_capture_node_path = node_data.get("node_path", "")
		_capture_node_props = node_data.get("properties", [])

	_captured_images.clear()
	_capture_frames_remaining = count
	_capture_frame_interval = interval
	_capture_frame_counter = 0
	_state = State.CAPTURING_FRAMES
	_capture_one_frame()


func _process_capture() -> void:
	if FileAccess.file_exists(REQUEST_PATH):
		_state = State.IDLE
		_handle_request()
		return

	_capture_frame_counter += 1
	if _capture_frame_counter >= _capture_frame_interval:
		_capture_frame_counter = 0
		_capture_one_frame()


func _capture_one_frame() -> void:
	var viewport := get_viewport()
	if viewport == null:
		_finish_capture()
		return

	var image := viewport.get_texture().get_image()
	if image == null:
		_finish_capture()
		return

	if _capture_half_res:
		var new_size := image.get_size() / 2
		image.resize(new_size.x, new_size.y, Image.INTERPOLATE_BILINEAR)

	var png_buffer := image.save_png_to_buffer()
	_captured_images.append(Marshalls.raw_to_base64(png_buffer))

	# Snapshot node properties if tracking
	if not _capture_node_path.is_empty() and not _capture_node_props.is_empty():
		var snap := {}
		var node := get_tree().root.get_node_or_null(_capture_node_path)
		if node:
			for prop_name in _capture_node_props:
				var val = node.get(prop_name)
				snap[prop_name] = _serialize_value(val)
		_capture_frame_data.append(snap)

	_capture_frames_remaining -= 1
	if _capture_frames_remaining <= 0:
		_finish_capture()


func _finish_capture() -> void:
	_state = State.IDLE
	var viewport := get_viewport()
	var w := 0
	var h := 0
	if viewport:
		var size := viewport.get_visible_rect().size
		if _capture_half_res:
			size /= 2
		w = int(size.x)
		h = int(size.y)

	var response := {
		"frames": _captured_images,
		"count": _captured_images.size(),
		"width": w,
		"height": h,
		"half_resolution": _capture_half_res,
	}
	if not _capture_frame_data.is_empty():
		response["frame_data"] = _capture_frame_data
	_write_response(response)
	_captured_images.clear()
	_capture_frame_data.clear()


# ── monitor_properties ────────────────────────────────────────────────────────

func _cmd_monitor_properties(params: Dictionary) -> void:
	_pending_command = false  # Async command — don't trigger crash recovery
	_monitor_node_path = params.get("node_path", "")
	_monitor_properties = params.get("properties", [])
	if _monitor_node_path.is_empty() or _monitor_properties.is_empty():
		_write_response({"error": "node_path and properties are required"})
		return

	var frame_count: int = clampi(params.get("frame_count", 60), 1, 600)
	var interval: int = maxi(params.get("frame_interval", 1), 1)

	_monitor_timeline.clear()
	_monitor_frames_remaining = frame_count
	_monitor_frame_interval = interval
	_monitor_frame_counter = 0
	_state = State.MONITORING
	_sample_one_frame()


func _process_monitor() -> void:
	if FileAccess.file_exists(REQUEST_PATH):
		_state = State.IDLE
		_handle_request()
		return

	_monitor_frame_counter += 1
	if _monitor_frame_counter >= _monitor_frame_interval:
		_monitor_frame_counter = 0
		_sample_one_frame()


func _sample_one_frame() -> void:
	var sample: Dictionary = {}
	var node := get_node_or_null(NodePath(_monitor_node_path))

	if node == null:
		for prop_name: String in _monitor_properties:
			sample[prop_name] = null
	else:
		for prop_name: String in _monitor_properties:
			sample[prop_name] = _serialize_value(node.get(prop_name))

	_monitor_timeline.append(sample)

	_monitor_frames_remaining -= 1
	if _monitor_frames_remaining <= 0:
		_finish_monitor()


func _finish_monitor() -> void:
	_state = State.IDLE
	_write_response({
		"node_path": _monitor_node_path,
		"properties": _monitor_properties,
		"samples": _monitor_timeline,
		"sample_count": _monitor_timeline.size(),
		"frame_interval": _monitor_frame_interval,
	})
	_monitor_timeline.clear()


# ── watch_signals ────────────────────────────────────────────────────────────

func _cmd_watch_signals(params: Dictionary) -> void:
	_pending_command = false  # Async command — don't trigger crash recovery

	if not params.has("node_paths") or not params["node_paths"] is Array:
		_write_response({"error": "node_paths array is required"})
		return

	var node_paths: Array = params["node_paths"]
	if node_paths.is_empty():
		_write_response({"error": "node_paths array is empty"})
		return

	_watch_signal_filter = params.get("signal_filter", []) if params.has("signal_filter") and params["signal_filter"] is Array else []
	_watch_duration_ms = clampi(params.get("duration_ms", 5000), 500, 30000)
	_watch_log.clear()
	_watch_connections.clear()
	_watch_nodes = node_paths

	# Connect to signals on each node
	var connected_count: int = 0
	for node_path_str: String in node_paths:
		var node := get_node_or_null(NodePath(node_path_str))
		if node == null:
			_watch_log.append({"warning": "Node not found: %s" % node_path_str})
			continue

		for sig_info: Dictionary in node.get_signal_list():
			var sig_name: String = sig_info["name"]
			# Apply filter if specified
			if not _watch_signal_filter.is_empty():
				var match_found := false
				for filter_str: String in _watch_signal_filter:
					if sig_name.contains(filter_str):
						match_found = true
						break
				if not match_found:
					continue

			# Create a callable matched to the signal's argument count
			var arg_count: int = sig_info["args"].size()
			var cb := _make_signal_callback(node_path_str, sig_name, arg_count)
			if cb.is_valid() and not node.is_connected(sig_name, cb):
				node.connect(sig_name, cb)
				_watch_connections.append({"node": node, "signal": sig_name, "callable": cb})
				connected_count += 1

	if connected_count == 0 and _watch_log.is_empty():
		_write_response({"error": "No signals connected. Check node_paths and signal_filter."})
		return

	_watch_start_msec = Time.get_ticks_msec()
	_state = State.WATCHING_SIGNALS


func _on_signal_fired(node_path_str: String, sig_name: String, args: Array) -> void:
	var elapsed: int = Time.get_ticks_msec() - _watch_start_msec
	var entry: Dictionary = {
		"time_ms": elapsed,
		"node": node_path_str,
		"signal": sig_name,
	}
	if not args.is_empty():
		var serialized: Array = []
		for a: Variant in args:
			serialized.append(_serialize_value(a))
		entry["args"] = serialized
	_watch_log.append(entry)


func _make_signal_callback(node_path_str: String, sig_name: String, arg_count: int) -> Callable:
	var np := node_path_str
	var sn := sig_name
	match arg_count:
		0:
			return func() -> void: _on_signal_fired(np, sn, [])
		1:
			return func(a: Variant) -> void: _on_signal_fired(np, sn, [a])
		2:
			return func(a: Variant, b: Variant) -> void: _on_signal_fired(np, sn, [a, b])
		3:
			return func(a: Variant, b: Variant, c: Variant) -> void: _on_signal_fired(np, sn, [a, b, c])
		4:
			return func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: _on_signal_fired(np, sn, [a, b, c, d])
		_:
			# For 5+ args, drop extra args and log without them
			var cb := func() -> void: _on_signal_fired(np, sn, [])
			return cb.unbind(arg_count)


func _process_watch_signals() -> void:
	# Check for abort (new request)
	if FileAccess.file_exists(REQUEST_PATH):
		_finish_watch_signals()
		_state = State.IDLE
		_handle_request()
		return

	var elapsed: int = Time.get_ticks_msec() - _watch_start_msec
	if elapsed >= _watch_duration_ms:
		_finish_watch_signals()


func _finish_watch_signals() -> void:
	# Disconnect all watchers
	for conn: Dictionary in _watch_connections:
		var node: Node = conn["node"] as Node
		if is_instance_valid(node):
			var sig_name: String = conn["signal"]
			var cb: Callable = conn["callable"]
			if node.is_connected(sig_name, cb):
				node.disconnect(sig_name, cb)
	_watch_connections.clear()

	_state = State.IDLE
	_write_response({
		"node_paths": _watch_nodes,
		"signal_filter": _watch_signal_filter,
		"duration_ms": _watch_duration_ms,
		"events": _watch_log,
		"event_count": _watch_log.size(),
	})
	_watch_log.clear()


# ── set_node_property ─────────────────────────────────────────────────────────

func _cmd_set_node_property(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_write_response({"error": "node_path is required"})
		return

	var property: String = params.get("property", "")
	if property.is_empty():
		_write_response({"error": "property is required"})
		return

	if not params.has("value"):
		_write_response({"error": "value is required"})
		return

	var node := get_node_or_null(NodePath(node_path))
	if node == null:
		_write_response({"error": "Node not found: %s" % node_path})
		return

	var old_value: Variant = node.get(property)
	var raw_value: Variant = params.get("value")
	var parsed_value: Variant = _parse_value_for_type(raw_value, typeof(old_value))

	node.set(property, parsed_value)
	var new_value: Variant = node.get(property)

	_write_response({
		"node_path": str(node.get_path()),
		"property": property,
		"old_value": _serialize_value(old_value),
		"new_value": _serialize_value(new_value),
	})


func _parse_value_for_type(raw: Variant, target_type: int) -> Variant:
	if typeof(raw) == target_type:
		return raw

	# Handle Dictionary → Vector2/Vector3/Color conversion
	if raw is Dictionary:
		var dict: Dictionary = raw
		match target_type:
			TYPE_VECTOR3:
				return Vector3(
					float(dict.get("x", 0)),
					float(dict.get("y", 0)),
					float(dict.get("z", 0))
				)
			TYPE_VECTOR3I:
				return Vector3i(
					int(dict.get("x", 0)),
					int(dict.get("y", 0)),
					int(dict.get("z", 0))
				)
			TYPE_VECTOR2:
				return Vector2(
					float(dict.get("x", 0)),
					float(dict.get("y", 0))
				)
			TYPE_VECTOR2I:
				return Vector2i(
					int(dict.get("x", 0)),
					int(dict.get("y", 0))
				)
			TYPE_COLOR:
				return Color(
					float(dict.get("r", 0)),
					float(dict.get("g", 0)),
					float(dict.get("b", 0)),
					float(dict.get("a", 1))
				)
		return raw

	if raw is String:
		var raw_str: String = raw
		if raw_str.begins_with("#"):
			return Color.html(raw_str)

		var expr := Expression.new()
		var err := expr.parse(raw_str)
		if err == OK:
			var result: Variant = expr.execute()
			if not expr.has_execute_failed():
				return result
		return raw_str

	if raw is float and target_type == TYPE_INT:
		return int(raw)
	if raw is int and target_type == TYPE_FLOAT:
		return float(raw)

	return raw


# ── execute_script ────────────────────────────────────────────────────────────

func _cmd_execute_script(params: Dictionary) -> void:
	var code: String = params.get("code", "")
	if code.is_empty():
		_write_response({"error": "code is required"})
		return

	# Normalize indentation: convert leading spaces to tabs
	var raw_lines := code.split("\n")
	var indent_size := 0
	for raw_line in raw_lines:
		var spaces := 0
		while spaces < raw_line.length() and raw_line[spaces] == " ":
			spaces += 1
		if spaces > 0 and (indent_size == 0 or spaces < indent_size):
			indent_size = spaces
	if indent_size > 0:
		var space_unit := " ".repeat(indent_size)
		for idx in raw_lines.size():
			var rl: String = raw_lines[idx]
			var tabs := ""
			while rl.begins_with(space_unit):
				tabs += "\t"
				rl = rl.substr(indent_size)
			raw_lines[idx] = tabs + rl

	# Separate top-level func definitions (place at class level, not inside run())
	var class_funcs: PackedStringArray = []
	var body_lines: PackedStringArray = []
	var i := 0
	while i < raw_lines.size():
		var line: String = raw_lines[i]
		if not line.begins_with("\t") and not line.begins_with(" ") and line.begins_with("func "):
			class_funcs.append(line)
			i += 1
			while i < raw_lines.size():
				var next_line: String = raw_lines[i]
				if next_line.is_empty() or next_line.begins_with("\t"):
					class_funcs.append(next_line)
					i += 1
				else:
					break
		else:
			body_lines.append(line)
			i += 1

	var wrapped := """extends Node

var _mcp_output: Array = []
var _mcp_error: String = ""

func _mcp_print(value: Variant) -> void:
	_mcp_output.append(str(value))

func _safe_get(node: Node, prop: String, default: Variant = null) -> Variant:
	if node == null:
		return default
	return node.get(prop) if prop in node else default

"""
	# Add user's top-level functions at class level
	for func_line in class_funcs:
		wrapped += func_line + "\n"
	if class_funcs.size() > 0:
		wrapped += "\n"

	wrapped += "func run() -> Variant:\n"
	for line in body_lines:
		wrapped += "\t" + line + "\n"
	wrapped += "\treturn _mcp_output\n"

	var script := GDScript.new()
	script.source_code = wrapped
	var err := script.reload()
	if err != OK:
		_write_response({"error": "Script compilation failed: %s" % error_string(err)})
		return

	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	if host == null:
		_write_response({"error": "No scene tree host available (current_scene and root are null)"})
		return

	var temp_node := Node.new()
	temp_node.set_script(script)
	host.add_child(temp_node)

	var output: Variant = null
	if temp_node.has_method("run"):
		output = temp_node.run()

	var mcp_output: Array = temp_node.get("_mcp_output") if temp_node.get("_mcp_output") is Array else []
	temp_node.queue_free()

	_write_response({
		"output": mcp_output,
		"return_value": str(output) if output != null else null,
	})


# ── find_nodes_by_script ──────────────────────────────────────────────────────

func _cmd_find_nodes_by_script(params: Dictionary) -> void:
	var script_name: String = params.get("script", "")
	if script_name.is_empty():
		_write_response({"error": "'script' is required"})
		return

	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var prop_filter: Array = params.get("properties", [])
	var matches: Array = []
	_find_nodes_by_script_recursive(root, script_name.to_lower(), prop_filter, matches)

	_write_response({"nodes": matches, "count": matches.size()})


func _find_nodes_by_script_recursive(node: Node, script_filter: String, prop_filter: Array, results: Array) -> void:
	var script: Script = node.get_script()
	if script and script.resource_path.to_lower().contains(script_filter):
		var entry := {
			"name": node.name,
			"path": str(node.get_path()),
			"type": node.get_class(),
			"script": script.resource_path,
		}
		var props: Dictionary = {}
		if prop_filter.is_empty():
			for prop_info in node.get_property_list():
				var prop_name: String = prop_info["name"]
				var usage: int = prop_info["usage"]
				if not (usage & PROPERTY_USAGE_EDITOR):
					continue
				if prop_name.begins_with("_") or prop_name == "script":
					continue
				props[prop_name] = _serialize_value(node.get(prop_name))
		else:
			for prop_name: String in prop_filter:
				props[prop_name] = _serialize_value(node.get(prop_name))
		entry["properties"] = props
		results.append(entry)

	for child in node.get_children():
		_find_nodes_by_script_recursive(child, script_filter, prop_filter, results)


# ── get_autoload ─────────────────────────────────────────────────────────────

func _cmd_get_autoload(params: Dictionary) -> void:
	var autoload_name: String = params.get("name", "")
	if autoload_name.is_empty():
		_write_response({"error": "'name' is required"})
		return

	var node := get_node_or_null(NodePath("/root/" + autoload_name))
	if node == null:
		_write_response({"error": "Autoload not found: %s" % autoload_name})
		return

	var prop_filter: Array = params.get("properties", [])
	var props: Dictionary = {}

	if prop_filter.is_empty():
		for prop_info in node.get_property_list():
			var prop_name: String = prop_info["name"]
			var usage: int = prop_info["usage"]
			if not (usage & PROPERTY_USAGE_EDITOR):
				continue
			if prop_name.begins_with("_") or prop_name == "script":
				continue
			props[prop_name] = _serialize_value(node.get(prop_name))
	else:
		for prop_name: String in prop_filter:
			props[prop_name] = _serialize_value(node.get(prop_name))

	var result := {
		"name": autoload_name,
		"path": str(node.get_path()),
		"type": node.get_class(),
		"properties": props,
	}
	var script: Script = node.get_script()
	if script:
		result["script"] = script.resource_path

	_write_response(result)


# ── batch_get_properties ─────────────────────────────────────────────────────

func _cmd_batch_get_properties(params: Dictionary) -> void:
	var nodes: Array = params.get("nodes", [])
	if nodes.is_empty():
		_write_response({"error": "'nodes' array is required"})
		return

	var results: Array = []
	for entry: Dictionary in nodes:
		var node_path: String = entry.get("path", "")
		var prop_filter: Array = entry.get("properties", [])

		if node_path.is_empty():
			results.append({"path": "", "properties": {}, "error": "Empty path"})
			continue

		var node := get_node_or_null(NodePath(node_path))
		if node == null:
			results.append({"path": node_path, "properties": {}, "error": "Node not found"})
			continue

		var props: Dictionary = {}
		if prop_filter.is_empty():
			for prop_info in node.get_property_list():
				var prop_name: String = prop_info["name"]
				var usage: int = prop_info["usage"]
				if not (usage & PROPERTY_USAGE_EDITOR):
					continue
				if prop_name.begins_with("_") or prop_name == "script":
					continue
				props[prop_name] = _serialize_value(node.get(prop_name))
		else:
			for prop_name: String in prop_filter:
				props[prop_name] = _serialize_value(node.get(prop_name))

		results.append({"path": node_path, "properties": props})

	_write_response({"nodes": results, "count": results.size()})


# ── find_ui_elements ─────────────────────────────────────────────────────────

func _cmd_find_ui_elements(params: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var type_filter: String = params.get("type_filter", "")
	var elements: Array = []
	_find_ui_recursive(root, type_filter, elements)
	_write_response({"elements": elements, "count": elements.size()})


func _find_ui_recursive(node: Node, type_filter: String, results: Array) -> void:
	if node is Control and node.visible:
		var ctrl: Control = node
		var entry: Dictionary = {}
		var include := false

		if ctrl is Button:
			var btn: Button = ctrl
			entry["type"] = "Button"
			entry["text"] = btn.text
			entry["disabled"] = btn.disabled
			include = true
		elif ctrl is Label:
			var lbl: Label = ctrl
			entry["type"] = "Label"
			entry["text"] = lbl.text
			include = true
		elif ctrl is LineEdit:
			var le: LineEdit = ctrl
			entry["type"] = "LineEdit"
			entry["text"] = le.text
			entry["placeholder"] = le.placeholder_text
			include = true
		elif ctrl is TextEdit:
			var te: TextEdit = ctrl
			entry["type"] = "TextEdit"
			entry["text"] = te.text.left(200)
			include = true
		elif ctrl is OptionButton:
			var ob: OptionButton = ctrl
			entry["type"] = "OptionButton"
			entry["text"] = ob.text
			entry["selected"] = ob.selected
			include = true
		elif ctrl is CheckBox:
			var cb: CheckBox = ctrl
			entry["type"] = "CheckBox"
			entry["text"] = cb.text
			entry["checked"] = cb.button_pressed
			include = true
		elif ctrl is HSlider or ctrl is VSlider:
			var sl: Range = ctrl
			entry["type"] = "HSlider" if ctrl is HSlider else "VSlider"
			entry["value"] = sl.value
			entry["min"] = sl.min_value
			entry["max"] = sl.max_value
			include = true

		if include:
			if not type_filter.is_empty() and entry.get("type", "") != type_filter:
				pass  # Skip non-matching types
			else:
				var rect := ctrl.get_global_rect()
				entry["name"] = str(ctrl.name)
				entry["path"] = str(ctrl.get_path())
				entry["rect"] = {
					"x": rect.position.x,
					"y": rect.position.y,
					"width": rect.size.x,
					"height": rect.size.y,
				}
				entry["center"] = {
					"x": rect.position.x + rect.size.x / 2.0,
					"y": rect.position.y + rect.size.y / 2.0,
				}
				results.append(entry)

	for child in node.get_children():
		_find_ui_recursive(child, type_filter, results)


# ── click_button_by_text ─────────────────────────────────────────────────────

func _cmd_click_button_by_text(params: Dictionary) -> void:
	var text: String = params.get("text", "")
	var partial: bool = params.get("partial", true)
	if text.is_empty():
		_write_response({"error": "'text' is required"})
		return

	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var btn: Button = _find_button_by_text(root, text, partial)
	if btn == null:
		_write_response({"error": "No visible button found with text: '%s'" % text})
		return

	var rect := btn.get_global_rect()
	var center := rect.get_center()
	var btn_text_value := btn.text

	# Capture button path before clicking — the click may trigger a scene
	# transition that removes the node from the tree.
	var btn_path := str(btn.get_path()) if btn.is_inside_tree() else ""

	# Emit the pressed signal directly — more reliable than Input.parse_input_event
	# which doesn't always reach GUI Controls.
	btn.emit_signal("pressed")

	# After the click, the node may have been freed due to scene transition.
	# Re-check before accessing any node properties.
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		_write_response({
			"clicked": true,
			"button_text": btn_text_value,
			"button_path": btn_path,
			"position": {"x": center.x, "y": center.y},
			"note": "Button was removed from scene tree after click (likely a scene transition)",
		})
		return

	_write_response({
		"clicked": true,
		"button_text": btn.text,
		"button_path": str(btn.get_path()),
		"position": {"x": center.x, "y": center.y},
	})


func _find_button_by_text(node: Node, text: String, partial: bool) -> Button:
	if node is Button and node.visible:
		var btn: Button = node
		var btn_text := btn.text.to_lower().strip_edges()
		var search_text := text.to_lower().strip_edges()
		if partial and btn_text.contains(search_text):
			return btn
		elif not partial and btn_text == search_text:
			return btn

	for child in node.get_children():
		var found := _find_button_by_text(child, text, partial)
		if found != null:
			return found
	return null


# ── wait_for_node ────────────────────────────────────────────────────────────

func _cmd_wait_for_node(params: Dictionary) -> void:
	_pending_command = false  # Async command — don't trigger crash recovery
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_write_response({"error": "'node_path' is required"})
		return

	var timeout_sec: float = params.get("timeout", 5.0)
	var poll_interval: int = maxi(int(params.get("poll_frames", 5)), 1)

	var attempts := int(timeout_sec / (poll_interval / 60.0))
	var frame_counter := 0

	for i in attempts:
		var node := get_node_or_null(NodePath(node_path))
		if node != null:
			var result := {
				"found": true,
				"node_path": str(node.get_path()),
				"type": node.get_class(),
				"name": str(node.name),
			}
			var script: Script = node.get_script()
			if script:
				result["script"] = script.resource_path
			_write_response(result)
			return

		# Wait poll_interval frames
		for _f in poll_interval:
			await get_tree().process_frame

	_write_response({
		"found": false,
		"node_path": node_path,
		"error": "Node not found after %.1fs" % timeout_sec,
	})


# ── find_nearby_nodes ─────────────────────────────────────────────────────────

func _cmd_find_nearby_nodes(params: Dictionary) -> void:
	var radius: float = float(params.get("radius", 20.0))
	var max_results: int = int(params.get("max_results", 10))
	var type_filter: String = params.get("type_filter", "")
	var group_filter: String = params.get("group_filter", "")

	# Resolve origin position
	var origin := Vector3.ZERO
	var position_param: Variant = params.get("position", null)
	if position_param is String:
		# node_path — use its global_position
		var origin_node := get_node_or_null(NodePath(position_param as String))
		if origin_node == null:
			_write_response({"error": "Origin node not found: %s" % position_param})
			return
		if origin_node is Node3D:
			origin = (origin_node as Node3D).global_position
		elif origin_node is Node2D:
			var pos2d: Vector2 = (origin_node as Node2D).global_position
			origin = Vector3(pos2d.x, pos2d.y, 0)
		else:
			_write_response({"error": "Origin node is not Node2D or Node3D: %s" % position_param})
			return
	elif position_param is Dictionary:
		var dict: Dictionary = position_param
		origin = Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
	elif position_param == null:
		_write_response({"error": "'position' is required (node_path string or {x,y,z} object)"})
		return

	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	# Collect all spatial nodes within radius
	var candidates: Array = []
	_find_nearby_recursive(root, origin, radius, type_filter, group_filter, candidates)

	# Sort by distance
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"]
	)

	# Limit results
	if candidates.size() > max_results:
		candidates.resize(max_results)

	_write_response({
		"origin": {"x": origin.x, "y": origin.y, "z": origin.z},
		"radius": radius,
		"nodes": candidates,
		"count": candidates.size(),
	})


func _find_nearby_recursive(node: Node, origin: Vector3, radius: float, type_filter: String, group_filter: String, results: Array) -> void:
	var pos := Vector3.ZERO
	var is_spatial := false

	if node is Node3D:
		pos = (node as Node3D).global_position
		is_spatial = true
	elif node is Node2D:
		var pos2d: Vector2 = (node as Node2D).global_position
		pos = Vector3(pos2d.x, pos2d.y, 0)
		is_spatial = true

	if is_spatial:
		var diff := pos - origin
		var dist := diff.length()
		if dist <= radius:
			# Apply filters
			var passes := true
			if not type_filter.is_empty() and not node.is_class(type_filter):
				passes = false
			if not group_filter.is_empty() and not node.is_in_group(group_filter):
				passes = false

			if passes:
				var entry: Dictionary = {
					"node_path": str(node.get_path()),
					"name": str(node.name),
					"type": node.get_class(),
					"distance": snappedf(dist, 0.01),
					"global_position": {"x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01), "z": snappedf(pos.z, 0.01)},
					"direction": {"x": snappedf(diff.x, 0.01), "y": snappedf(diff.y, 0.01), "z": snappedf(diff.z, 0.01)},
				}
				var script: Script = node.get_script()
				if script:
					entry["script"] = script.resource_path
				results.append(entry)

	for child in node.get_children():
		_find_nearby_recursive(child, origin, radius, type_filter, group_filter, results)


# ── navigate_to ──────────────────────────────────────────────────────────────

func _cmd_navigate_to(params: Dictionary) -> void:
	# Resolve player position
	var player_path: String = params.get("player_path", "/root/Main/Player")
	var player := get_node_or_null(NodePath(player_path))
	if player == null:
		_write_response({"error": "Player not found: %s" % player_path})
		return

	var player_pos := Vector3.ZERO
	if player is Node3D:
		player_pos = (player as Node3D).global_position
	else:
		_write_response({"error": "Player is not Node3D: %s" % player_path})
		return

	# Resolve target position
	var target_param: Variant = params.get("target", null)
	var target_pos := Vector3.ZERO
	if target_param is String:
		var target_node := get_node_or_null(NodePath(target_param as String))
		if target_node == null:
			_write_response({"error": "Target node not found: %s" % target_param})
			return
		if target_node is Node3D:
			target_pos = (target_node as Node3D).global_position
		else:
			_write_response({"error": "Target is not Node3D: %s" % target_param})
			return
	elif target_param is Dictionary:
		var dict: Dictionary = target_param
		target_pos = Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
	else:
		_write_response({"error": "'target' is required (node_path string or {x,y,z} object)"})
		return

	# Calculate world direction (XZ plane for 3D movement)
	var world_dir := target_pos - player_pos
	var distance := world_dir.length()
	var flat_dir := Vector3(world_dir.x, 0, world_dir.z).normalized()

	# Find camera for relative direction
	var camera_path: String = params.get("camera_path", "")
	var camera: Camera3D = null
	if not camera_path.is_empty():
		var cam_node := get_node_or_null(NodePath(camera_path))
		if cam_node is Camera3D:
			camera = cam_node
	else:
		# Auto-detect: find Camera3D in scene
		camera = get_viewport().get_camera_3d()

	var suggested_keys: Array = []
	var camera_yaw_delta: float = 0.0
	var camera_forward := Vector3.ZERO

	if camera != null:
		# Camera forward (XZ plane)
		camera_forward = -camera.global_basis.z
		var cam_flat := Vector3(camera_forward.x, 0, camera_forward.z).normalized()
		var cam_right := Vector3(camera_forward.z, 0, -camera_forward.x).normalized()

		if flat_dir.length() > 0.01:
			# Project target direction onto camera axes
			var forward_dot := flat_dir.dot(cam_flat)
			var right_dot := flat_dir.dot(cam_right)

			# Suggest keys based on dominant direction
			if forward_dot > 0.3:
				suggested_keys.append("KEY_W")
			elif forward_dot < -0.3:
				suggested_keys.append("KEY_S")
			if right_dot > 0.3:
				suggested_keys.append("KEY_D")
			elif right_dot < -0.3:
				suggested_keys.append("KEY_A")

			# Calculate yaw rotation needed to face target directly (W only)
			var angle_to_target := atan2(flat_dir.x, flat_dir.z)
			var cam_yaw := atan2(cam_flat.x, cam_flat.z)
			camera_yaw_delta = angle_to_target - cam_yaw
			# Normalize to [-PI, PI]
			while camera_yaw_delta > PI:
				camera_yaw_delta -= TAU
			while camera_yaw_delta < -PI:
				camera_yaw_delta += TAU

	# Estimate walk duration (rough: assume ~5 units/sec movement speed)
	var move_speed: float = float(params.get("move_speed", 5.0))
	var estimated_duration := distance / move_speed if move_speed > 0 else 0.0

	# Convert yaw delta to approximate mouse relative_x pixels
	# Typical: 400px mouse movement ≈ PI radians
	var mouse_sensitivity_scale: float = 400.0 / PI
	var suggested_mouse_x := -camera_yaw_delta * mouse_sensitivity_scale

	_write_response({
		"distance": snappedf(distance, 0.01),
		"world_direction": {
			"x": snappedf(world_dir.x, 0.01),
			"y": snappedf(world_dir.y, 0.01),
			"z": snappedf(world_dir.z, 0.01),
		},
		"flat_direction": {
			"x": snappedf(flat_dir.x, 0.01),
			"z": snappedf(flat_dir.z, 0.01),
		},
		"suggested_keys": suggested_keys,
		"camera_rotation_delta": {
			"yaw_radians": snappedf(camera_yaw_delta, 0.001),
			"suggested_mouse_relative_x": snappedf(suggested_mouse_x, 1.0),
		},
		"estimated_duration": snappedf(estimated_duration, 0.1),
		"player_position": {"x": snappedf(player_pos.x, 0.01), "y": snappedf(player_pos.y, 0.01), "z": snappedf(player_pos.z, 0.01)},
		"target_position": {"x": snappedf(target_pos.x, 0.01), "y": snappedf(target_pos.y, 0.01), "z": snappedf(target_pos.z, 0.01)},
	})


# ── move_to ───────────────────────────────────────────────────────────────────

func _cmd_move_to(params: Dictionary) -> void:
	# Resolve player node
	var player_path: String = params.get("player_path", "/root/Main/Player")
	var player := get_node_or_null(NodePath(player_path))
	if player == null or not player is Node3D:
		_write_response({"error": "Player not found or not Node3D: %s" % player_path})
		return

	_moveto_player = player as Node3D

	# Resolve target position
	var target_param: Variant = params.get("target", null)
	if target_param is String:
		var target_node := get_node_or_null(NodePath(target_param as String))
		if target_node == null:
			_write_response({"error": "Target node not found: %s" % target_param})
			return
		if target_node is Node3D:
			_moveto_target = (target_node as Node3D).global_position
		else:
			_write_response({"error": "Target is not Node3D: %s" % target_param})
			return
	elif target_param is Dictionary:
		var dict: Dictionary = target_param
		_moveto_target = Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
	else:
		_write_response({"error": "'target' is required (node_path string or {x,y,z} object)"})
		return

	# Resolve camera pivot
	_moveto_camera_pivot = null
	var camera_path: String = params.get("camera_path", "")
	if not camera_path.is_empty():
		var cam_node := get_node_or_null(NodePath(camera_path))
		if cam_node is Node3D:
			_moveto_camera_pivot = cam_node as Node3D
	else:
		# Auto-detect: look for SpringArm3D child of player
		for child in _moveto_player.get_children():
			if child is SpringArm3D:
				_moveto_camera_pivot = child as Node3D
				break
		# Fallback: active Camera3D's parent
		if _moveto_camera_pivot == null:
			var cam := get_viewport().get_camera_3d()
			if cam != null and cam.get_parent() is Node3D and cam.get_parent() != get_tree().root:
				_moveto_camera_pivot = cam.get_parent() as Node3D

	# Read params
	_moveto_arrival_radius = float(params.get("arrival_radius", 1.5))
	_moveto_timeout = float(params.get("timeout", 15.0))
	_moveto_run = bool(params.get("run", false))
	_moveto_look_at = bool(params.get("look_at_target", true))
	_moveto_elapsed = 0.0
	_moveto_keys_held.clear()

	# Check if already at target
	var dist := _moveto_player.global_position.distance_to(_moveto_target)
	if dist <= _moveto_arrival_radius:
		_write_response({
			"success": true,
			"arrived": true,
			"final_distance": snappedf(dist, 0.01),
			"final_position": _serialize_value(_moveto_player.global_position),
			"target_position": _serialize_value(_moveto_target),
			"elapsed_time": 0.0,
		})
		return

	# Start walking — async state, don't trigger crash recovery
	_pending_command = false
	_state = State.MOVING_TO

	# Inject walk key
	_inject_key(KEY_W, true)
	if _moveto_run:
		_inject_key(KEY_SHIFT, true)


func _process_move_to(delta: float) -> void:
	# Check for abort (new command arrived)
	if FileAccess.file_exists(REQUEST_PATH):
		_finish_move_to(false, "Aborted by new command")
		_state = State.IDLE
		_handle_request()
		return

	_moveto_elapsed += delta

	# Timeout check
	if _moveto_elapsed >= _moveto_timeout:
		_finish_move_to(false, "Timeout after %.1fs" % _moveto_timeout)
		return

	# Safety: player freed
	if not is_instance_valid(_moveto_player):
		_finish_move_to(false, "Player node was freed")
		return

	var player_pos := _moveto_player.global_position
	var flat_target := Vector3(_moveto_target.x, player_pos.y, _moveto_target.z)
	var dist := player_pos.distance_to(flat_target)

	# Arrival check (XZ distance only, ignore Y)
	if dist <= _moveto_arrival_radius:
		_finish_move_to(true, "Arrived")
		return

	# Rotate camera pivot toward target
	if _moveto_look_at and _moveto_camera_pivot != null and is_instance_valid(_moveto_camera_pivot):
		var dir := flat_target - player_pos
		if dir.length_squared() > 0.01:
			var target_yaw := atan2(-dir.x, -dir.z)
			var current_yaw: float = _moveto_camera_pivot.rotation.y
			# Lerp toward target yaw (~10 rad/s)
			var yaw_diff := target_yaw - current_yaw
			# Normalize to [-PI, PI]
			while yaw_diff > PI:
				yaw_diff -= TAU
			while yaw_diff < -PI:
				yaw_diff += TAU
			var max_step := 10.0 * delta
			var step := clampf(yaw_diff, -max_step, max_step)
			_moveto_camera_pivot.rotation.y += step


func _finish_move_to(success: bool, message: String) -> void:
	# Release all held keys
	_release_all_keys()
	_state = State.IDLE

	var final_pos := Vector3.ZERO
	var final_dist := 0.0
	if is_instance_valid(_moveto_player):
		final_pos = _moveto_player.global_position
		final_dist = final_pos.distance_to(_moveto_target)

	_write_response({
		"success": success,
		"arrived": success,
		"message": message,
		"final_distance": snappedf(final_dist, 0.01),
		"final_position": _serialize_value(final_pos),
		"target_position": _serialize_value(_moveto_target),
		"elapsed_time": snappedf(_moveto_elapsed, 0.01),
	})


func _inject_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed:
		_moveto_keys_held.append(keycode)
	else:
		_moveto_keys_held.erase(keycode)


func _release_all_keys() -> void:
	for keycode: int in _moveto_keys_held.duplicate():
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = false
		Input.parse_input_event(event)
	_moveto_keys_held.clear()


# ── Recording ────────────────────────────────────────────────────────────────

func _cmd_start_recording(_params: Dictionary) -> void:
	_recording_events.clear()
	_recording_start_msec = Time.get_ticks_msec()
	_state = State.RECORDING
	set_process_input(true)
	_write_response({"recording": true, "message": "Recording started"})


func _cmd_stop_recording(_params: Dictionary) -> void:
	set_process_input(false)
	_state = State.IDLE
	var events := _recording_events.duplicate()
	var duration_ms := Time.get_ticks_msec() - _recording_start_msec
	_write_response({
		"recording": false,
		"events": events,
		"event_count": events.size(),
		"duration_ms": duration_ms,
	})


func _cmd_replay_recording(params: Dictionary) -> void:
	_pending_command = false  # Async command — don't trigger crash recovery
	var events: Array = params.get("events", [])
	if events.is_empty():
		_write_response({"error": "No events to replay"})
		return

	var speed: float = params.get("speed", 1.0)

	var start_msec := Time.get_ticks_msec()
	for event_data: Dictionary in events:
		var delay_ms: int = event_data.get("time_ms", 0)
		var adjusted_delay := int(delay_ms / speed)

		while Time.get_ticks_msec() - start_msec < adjusted_delay:
			await get_tree().process_frame

		var event := _reconstruct_event(event_data)
		if event != null:
			Input.parse_input_event(event)

	_write_response({
		"replayed": true,
		"event_count": events.size(),
		"speed": speed,
	})


func _input(event: InputEvent) -> void:
	if _state != State.RECORDING:
		return

	var time_ms := Time.get_ticks_msec() - _recording_start_msec
	var data: Dictionary = {"time_ms": time_ms}

	if event is InputEventKey:
		var key: InputEventKey = event
		data["type"] = "key"
		data["keycode"] = OS.get_keycode_string(key.keycode) if key.keycode != 0 else ""
		data["physical_keycode"] = OS.get_keycode_string(key.physical_keycode) if key.physical_keycode != 0 else ""
		data["pressed"] = key.pressed
		data["shift"] = key.shift_pressed
		data["ctrl"] = key.ctrl_pressed
		data["alt"] = key.alt_pressed
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		data["type"] = "mouse_button"
		data["button"] = mb.button_index
		data["pressed"] = mb.pressed
		data["position"] = {"x": mb.position.x, "y": mb.position.y}
		data["double_click"] = mb.double_click
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		data["type"] = "mouse_motion"
		data["position"] = {"x": mm.position.x, "y": mm.position.y}
		data["relative"] = {"x": mm.relative.x, "y": mm.relative.y}
	elif event is InputEventAction:
		var act: InputEventAction = event
		data["type"] = "action"
		data["action"] = act.action
		data["pressed"] = act.pressed
		data["strength"] = act.strength
	else:
		return

	_recording_events.append(data)


func _reconstruct_event(data: Dictionary) -> InputEvent:
	var type: String = data.get("type", "")
	match type:
		"key":
			var event := InputEventKey.new()
			var keycode_str: String = data.get("keycode", "")
			if not keycode_str.is_empty():
				event.keycode = OS.find_keycode_from_string(keycode_str)
			event.pressed = data.get("pressed", true)
			event.shift_pressed = data.get("shift", false)
			event.ctrl_pressed = data.get("ctrl", false)
			event.alt_pressed = data.get("alt", false)
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = data.get("button", MOUSE_BUTTON_LEFT)
			event.pressed = data.get("pressed", true)
			event.double_click = data.get("double_click", false)
			var pos: Dictionary = data.get("position", {})
			event.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
			event.global_position = event.position
			return event
		"mouse_motion":
			var event := InputEventMouseMotion.new()
			var pos: Dictionary = data.get("position", {})
			event.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
			event.global_position = event.position
			var rel: Dictionary = data.get("relative", {})
			event.relative = Vector2(rel.get("x", 0.0), rel.get("y", 0.0))
			return event
		"action":
			var event := InputEventAction.new()
			event.action = data.get("action", "")
			event.pressed = data.get("pressed", true)
			event.strength = data.get("strength", 1.0)
			return event
	return null


# ── Helpers ───────────────────────────────────────────────────────────────────

func _write_response(data: Dictionary) -> void:
	_pending_command = false
	# TCP client (preferred)
	if _pending_tcp != null:
		var envelope: Dictionary
		if data.has("error") and data.size() == 1:
			envelope = {"id": _pending_tcp_id, "ok": false, "error": str(data["error"])}
		elif data.has("error") and typeof(data["error"]) == TYPE_STRING and not data.has("result"):
			envelope = {"id": _pending_tcp_id, "ok": false, "error": str(data["error"]), "data": data}
		else:
			envelope = {"id": _pending_tcp_id, "ok": true, "data": data}
		envelope["queue_depth"] = _tcp_queue.size()
		_tcp_send(_pending_tcp, envelope)
		_pending_tcp = null
		_pending_tcp_id = 0
		_dispatch_busy = false
		# Drain next queued TCP request (same frame if sync command)
		_drain_tcp_queue()
		return
	# File IPC fallback
	_dispatch_busy = false
	var json := JSON.stringify(data)
	var file := FileAccess.open(RESPONSE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
	_drain_tcp_queue()


# ── assert_node_state ─────────────────────────────────────────────────────────

func _cmd_assert_node_state(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_write_response({"error": "node_path is required"})
		return

	var property: String = params.get("property", "")
	if property.is_empty():
		_write_response({"error": "property is required"})
		return

	var node := get_node_or_null(NodePath(node_path))
	if node == null:
		_write_response({"error": "Node not found: %s" % node_path})
		return

	var actual: Variant
	if ":" in property:
		actual = node.get_indexed(NodePath(property))
	else:
		actual = node.get(property)
	var expected: Variant = params.get("expected", null)
	var operator: String = params.get("operator", "eq")
	var passed: bool = false

	match operator:
		"eq":
			passed = (str(actual) == str(expected)) or (actual == expected)
		"neq":
			passed = (actual != expected) and (str(actual) != str(expected))
		"gt":
			passed = float(actual) > float(expected)
		"lt":
			passed = float(actual) < float(expected)
		"gte":
			passed = float(actual) >= float(expected)
		"lte":
			passed = float(actual) <= float(expected)
		"contains":
			passed = str(actual).contains(str(expected))
		"type_is":
			passed = typeof(actual) == int(expected) or type_string(typeof(actual)) == str(expected)
		_:
			_write_response({"error": "Unknown operator: %s" % operator})
			return

	_write_response({
		"result": {
			"assertion": "node_state",
			"node_path": node_path,
			"property": property,
			"operator": operator,
			"expected": _serialize_value(expected),
			"actual": _serialize_value(actual),
			"passed": passed,
		}
	})


# ── get_performance_monitors ──────────────────────────────────────────────────

func _cmd_get_performance_monitors(_params: Dictionary) -> void:
	var monitors := {}
	monitors["fps"] = Performance.get_monitor(Performance.TIME_FPS)
	monitors["frame_time_msec"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	monitors["physics_frame_time_msec"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	monitors["navigation_process_msec"] = Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0

	monitors["memory_static"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	monitors["memory_static_max"] = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)

	monitors["object_count"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	monitors["object_resource_count"] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	monitors["object_node_count"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	monitors["object_orphan_node_count"] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	monitors["render_total_objects_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	monitors["render_total_primitives_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	monitors["render_total_draw_calls_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	monitors["render_video_mem_used"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)

	monitors["physics_2d_active_objects"] = Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	monitors["physics_2d_collision_pairs"] = Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
	monitors["physics_2d_island_count"] = Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)

	monitors["physics_3d_active_objects"] = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	monitors["physics_3d_collision_pairs"] = Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
	monitors["physics_3d_island_count"] = Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)

	monitors["navigation_active_maps"] = Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS)
	monitors["navigation_region_count"] = Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT)
	monitors["navigation_agent_count"] = Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT)

	_write_response({"result": {"monitors": monitors, "process": "game"}})


# ── Video / timeline / events (native visual probe) ───────────────────────────

func _session_t() -> float:
	return (Time.get_ticks_msec() - _video_start_msec) / 1000.0 if _video_start_msec > 0 else 0.0


func _append_log(level: String, message: String, extra: Dictionary = {}) -> void:
	var entry := {
		"t": _session_t() if _state == State.VIDEO_RECORDING or _state == State.CAPTURING_TIMELINE else Time.get_ticks_msec() / 1000.0,
		"level": level,
		"message": message,
	}
	for k in extra:
		entry[k] = extra[k]
	_log_ring.append(entry)
	while _log_ring.size() > LOG_RING_MAX:
		_log_ring.pop_front()
	if _state == State.VIDEO_RECORDING:
		_video_events.append(entry)
		_flush_event_line(entry)


func _flush_event_line(entry: Dictionary) -> void:
	if _video_dir.is_empty():
		return
	var path := _video_dir.path_join("events.jsonl")
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(entry))
	f.close()


func _cmd_start_video_record(params: Dictionary) -> void:
	_pending_command = false
	var session_id: String = str(params.get("session_id", "session_%d" % Time.get_ticks_msec()))
	_video_dir = "user://mcp_recordings/%s" % session_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_video_dir))
	_video_frame_idx = 0
	_video_fps = clampf(float(params.get("fps", 10.0)), 1.0, 30.0)
	_video_accum = 0.0
	_video_half = bool(params.get("half_resolution", true))
	_video_max_frames = clampi(int(params.get("max_frames", 900)), 30, 3600)
	_video_save_images = bool(params.get("save_images", true))
	_video_events.clear()
	_video_track_nodes.clear()
	if params.has("track_nodes") and params["track_nodes"] is Array:
		_video_track_nodes = params["track_nodes"]
	_video_start_msec = Time.get_ticks_msec()
	# Clear events file
	var ef := FileAccess.open(_video_dir.path_join("events.jsonl"), FileAccess.WRITE)
	if ef:
		ef.close()
	_append_log("info", "video_record_start", {"session_id": session_id, "fps": _video_fps})
	_state = State.VIDEO_RECORDING
	_write_response({
		"recording": true,
		"session_id": session_id,
		"dir": _video_dir,
		"fps": _video_fps,
		"half_resolution": _video_half,
		"max_frames": _video_max_frames,
		"hint": "stop_video_record then media_frames_to_video / media_extract_keyframes",
	})


func _process_video_record(delta: float) -> void:
	if _video_frame_idx >= _video_max_frames:
		_finalize_video_record(true)
		return
	_video_accum += delta
	var interval := 1.0 / _video_fps
	if _video_accum < interval:
		return
	_video_accum = 0.0
	if not _video_save_images:
		_video_frame_idx += 1
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var image := viewport.get_texture().get_image()
	if image == null:
		return
	if _video_half:
		var ns := image.get_size() / 2
		if ns.x >= 2 and ns.y >= 2:
			image.resize(ns.x, ns.y, Image.INTERPOLATE_BILINEAR)
	var fname := "frame_%05d.png" % _video_frame_idx
	var fpath := _video_dir.path_join(fname)
	image.save_png(fpath)
	# Optional property tracks
	if not _video_track_nodes.is_empty():
		var sample := {"t": _session_t(), "frame": _video_frame_idx, "props": {}}
		for spec in _video_track_nodes:
			if not spec is Dictionary:
				continue
			var np := str(spec.get("node_path", ""))
			var node := get_tree().root.get_node_or_null(np) if not np.is_empty() else null
			if node == null:
				continue
			var props: Array = spec.get("properties", [])
			var bag := {}
			for p in props:
				bag[str(p)] = _serialize_value(node.get(str(p)))
			sample["props"][np] = bag
		_flush_event_line({"t": sample["t"], "type": "sample", "frame": _video_frame_idx, "props": sample["props"]})
	_video_frame_idx += 1


func _finalize_video_record(auto: bool) -> Dictionary:
	var duration := _session_t()
	var meta := {
		"dir": _video_dir,
		"frame_count": _video_frame_idx,
		"fps": _video_fps,
		"duration_sec": duration,
		"events_path": _video_dir.path_join("events.jsonl") if not _video_dir.is_empty() else "",
		"frame_pattern": _video_dir.path_join("frame_%05d.png") if not _video_dir.is_empty() else "",
		"half_resolution": _video_half,
		"auto_stopped": auto,
		"event_count": _video_events.size(),
	}
	# Write meta.json
	if not _video_dir.is_empty():
		var mf := FileAccess.open(_video_dir.path_join("meta.json"), FileAccess.WRITE)
		if mf:
			mf.store_string(JSON.stringify(meta, "\t"))
			mf.close()
	_state = State.IDLE
	_append_log("info", "video_record_stop", meta)
	return meta


func _cmd_stop_video_record(_params: Dictionary) -> void:
	if _state != State.VIDEO_RECORDING and _video_dir.is_empty():
		_write_response({"error": "No video recording in progress"})
		return
	var meta := _finalize_video_record(false)
	_write_response({"recording": false, "meta": meta})


func _cmd_log_run_event(params: Dictionary) -> void:
	var type: String = str(params.get("type", params.get("event_type", "event")))
	var message: String = str(params.get("message", params.get("name", type)))
	var level: String = str(params.get("level", "info"))
	var extra: Dictionary = {}
	if params.has("data") and params["data"] is Dictionary:
		extra = params["data"]
	extra["type"] = type
	_append_log(level, message, extra)
	_write_response({"logged": true, "t": _session_t(), "type": type, "message": message})


func _cmd_get_run_events(params: Dictionary) -> void:
	var max_n: int = clampi(int(params.get("max", 100)), 1, 500)
	var out: Array = []
	# Prefer file if recording dir set
	if not _video_dir.is_empty() and FileAccess.file_exists(_video_dir.path_join("events.jsonl")):
		var f := FileAccess.open(_video_dir.path_join("events.jsonl"), FileAccess.READ)
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
		out = _video_events.duplicate()
	if out.size() > max_n:
		out = out.slice(out.size() - max_n)
	_write_response({"events": out, "count": out.size(), "dir": _video_dir})


func _cmd_get_run_logs(params: Dictionary) -> void:
	var max_n: int = clampi(int(params.get("max", 50)), 1, LOG_RING_MAX)
	var level_filter: String = str(params.get("level", ""))
	var out: Array = []
	for e in _log_ring:
		if not level_filter.is_empty() and str(e.get("level", "")) != level_filter:
			continue
		out.append(e)
	if out.size() > max_n:
		out = out.slice(out.size() - max_n)
	_write_response({
		"logs": out,
		"count": out.size(),
		"playing": true,
		"state": _state_name(),
		"video_recording": _state == State.VIDEO_RECORDING,
	})


func _state_name() -> String:
	match _state:
		State.IDLE: return "idle"
		State.CAPTURING_FRAMES: return "capturing_frames"
		State.MONITORING: return "monitoring"
		State.RECORDING: return "input_recording"
		State.MOVING_TO: return "moving_to"
		State.WATCHING_SIGNALS: return "watching_signals"
		State.VIDEO_RECORDING: return "video_recording"
		State.CAPTURING_TIMELINE: return "capturing_timeline"
		_: return "unknown"


func _cmd_get_run_status(_params: Dictionary) -> void:
	var scene := get_tree().current_scene
	_write_response({
		"ok": true,
		"state": _state_name(),
		"has_scene": scene != null,
		"scene_name": str(scene.name) if scene else "",
		"scene_path": scene.scene_file_path if scene else "",
		"video_recording": _state == State.VIDEO_RECORDING,
		"video_dir": _video_dir,
		"video_frames": _video_frame_idx,
		"video_t": _session_t() if _state == State.VIDEO_RECORDING else 0.0,
		"log_count": _log_ring.size(),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"paused": get_tree().paused,
	})


func _cmd_capture_timeline(params: Dictionary) -> void:
	## Sample node properties over duration; optional frame PNGs.
	_pending_command = false
	var duration: float = clampf(float(params.get("duration_sec", params.get("duration", 2.0))), 0.1, 30.0)
	_timeline_interval_sec = clampf(float(params.get("interval_sec", 0.1)), 0.033, 2.0)
	_timeline_include_images = bool(params.get("include_images", false))
	_timeline_half = bool(params.get("half_resolution", true))
	_timeline_nodes.clear()
	if params.has("nodes") and params["nodes"] is Array:
		_timeline_nodes = params["nodes"]
	elif params.has("node_path"):
		_timeline_nodes = [{
			"node_path": params["node_path"],
			"properties": params.get("properties", []),
		}]
	if _timeline_nodes.is_empty():
		_write_response({"error": "Provide nodes:[{node_path,properties}] or node_path+properties"})
		return
	_timeline_samples.clear()
	_timeline_remaining_sec = duration
	_timeline_accum = 0.0
	_video_start_msec = Time.get_ticks_msec()  # reuse for sample t
	_state = State.CAPTURING_TIMELINE
	_sample_timeline_once()  # immediate first sample


func _process_timeline(delta: float) -> void:
	_timeline_remaining_sec -= delta
	_timeline_accum += delta
	if _timeline_accum >= _timeline_interval_sec:
		_timeline_accum = 0.0
		_sample_timeline_once()
	if _timeline_remaining_sec <= 0.0:
		_finish_timeline()


func _sample_timeline_once() -> void:
	var sample := {"t": (Time.get_ticks_msec() - _video_start_msec) / 1000.0, "nodes": {}}
	for spec in _timeline_nodes:
		if not spec is Dictionary:
			continue
		var np := str(spec.get("node_path", ""))
		var node := get_tree().root.get_node_or_null(np)
		if node == null:
			sample["nodes"][np] = {"error": "not_found"}
			continue
		var bag := {"type": node.get_class()}
		var props: Array = spec.get("properties", [])
		if props.is_empty():
			# sensible defaults
			if "position" in node:
				bag["position"] = _serialize_value(node.get("position"))
			if "visible" in node:
				bag["visible"] = node.get("visible")
		else:
			for p in props:
				bag[str(p)] = _serialize_value(node.get(str(p)))
		sample["nodes"][np] = bag
	if _timeline_include_images:
		var viewport := get_viewport()
		if viewport:
			var image := viewport.get_texture().get_image()
			if image:
				if _timeline_half:
					var ns := image.get_size() / 2
					if ns.x >= 2 and ns.y >= 2:
						image.resize(ns.x, ns.y, Image.INTERPOLATE_BILINEAR)
				sample["image_b64"] = Marshalls.raw_to_base64(image.save_png_to_buffer())
	_timeline_samples.append(sample)


func _finish_timeline() -> void:
	_state = State.IDLE
	var dur := 0.0
	if not _timeline_samples.is_empty():
		dur = float(_timeline_samples[_timeline_samples.size() - 1].get("t", 0.0))
	_write_response({
		"samples": _timeline_samples,
		"count": _timeline_samples.size(),
		"duration_sec": dur,
		"include_images": _timeline_include_images,
	})
	_timeline_samples.clear()


func _cmd_find_nodes(params: Dictionary) -> void:
	var by: String = str(params.get("by", "type")).to_lower()
	var query: String = str(params.get("query", params.get("value", "")))
	var max_n: int = clampi(int(params.get("max", 50)), 1, 200)
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	var found: Array = []
	_find_nodes_walk(root, by, query, found, max_n)
	_write_response({"by": by, "query": query, "nodes": found, "count": found.size()})


func _find_nodes_walk(node: Node, by: String, query: String, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	var match := false
	match by:
		"group":
			match = node.is_in_group(query)
		"type", "class":
			match = node.is_class(query) or node.get_class() == query
		"name":
			match = str(node.name).contains(query) or str(node.name).matchn("*" + query + "*")
		"path":
			match = str(node.get_path()).contains(query)
		"script":
			var sc: Script = node.get_script()
			match = sc != null and sc.resource_path.contains(query)
		_:
			match = str(node.name).contains(query) or node.is_class(query)
	if match:
		out.append({
			"path": str(node.get_path()),
			"name": str(node.name),
			"type": node.get_class(),
			"script": node.get_script().resource_path if node.get_script() else "",
		})
	for c in node.get_children():
		_find_nodes_walk(c, by, query, out, max_n)


func _serialize_value(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_VECTOR2:
			var v: Vector2 = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR2I:
			var v: Vector2i = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR3:
			var v: Vector3 = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_VECTOR3I:
			var v: Vector3i = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_RECT2:
			var r: Rect2 = value
			return {"x": r.position.x, "y": r.position.y, "width": r.size.x, "height": r.size.y}
		TYPE_COLOR:
			var c: Color = value
			return {"r": c.r, "g": c.g, "b": c.b, "a": c.a, "html": "#" + c.to_html()}
		TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			if value is Resource:
				var res: Resource = value
				return {"type": res.get_class(), "path": res.resource_path}
			return str(value)
		TYPE_ARRAY:
			var arr: Array = value
			var result: Array = []
			for item in arr:
				result.append(_serialize_value(item))
			return result
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var result: Dictionary = {}
			for key in dict:
				result[str(key)] = _serialize_value(dict[key])
			return result
		_:
			return value
