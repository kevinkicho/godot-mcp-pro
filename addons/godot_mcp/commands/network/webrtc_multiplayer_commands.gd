@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## WebRTC multiplayer, lightweight signaling/matchmaking stubs, input-buffer netcode helpers.
## Full WebRTC needs an external signaling server; we scaffold client + local mock.


func get_commands() -> Dictionary:
	return {
		"create_webrtc_multiplayer_template": _create_webrtc_template,
		"create_signaling_server_script": _create_signaling_server_script,
		"create_matchmaking_client_script": _create_matchmaking_client_script,
		"create_input_buffer_netcode_script": _create_input_buffer_netcode_script,
		"create_lag_compensation_helper_script": _create_lag_compensation_helper_script,
		"create_webrtc_ice_config_script": _create_webrtc_ice_config,
		"list_webrtc_recipes": _list_webrtc_recipes,
	}


func _list_webrtc_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"recipes": [
			{"id": "webrtc_p2p", "tools": ["create_webrtc_multiplayer_template", "create_signaling_server_script"]},
			{"id": "matchmaking", "tools": ["create_matchmaking_client_script", "create_signaling_server_script"]},
			{"id": "ice_turn", "tools": ["create_webrtc_ice_config_script"]},
			{"id": "netcode", "tools": ["create_input_buffer_netcode_script", "create_lag_compensation_helper_script"]},
		],
		"honesty": [
			"WebRTC in Godot requires WebRTCMultiplayerPeer + a signaling channel (WebSocket/HTTP).",
			"Full GGPO-style rollback is not provided; input buffer is a practical mid-tier netcode base.",
			"Matchmaking here is a project-neutral lobby room protocol, not a commercial relay.",
			"TURN credentials are supplied by your infra — MCP scaffolds ICE config only.",
		],
		"flow": [
			"create_webrtc_ice_config_script (STUN/TURN urls)",
			"create_signaling_server_script (or host external)",
			"create_webrtc_multiplayer_template on both peers",
			"exchange offer/answer via signaling",
			"multiplayer.multiplayer_peer = webrtc peer",
		],
	})



func _create_webrtc_template(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/webrtc_multiplayer.gd")
	var content := """extends Node
## MCP WebRTC multiplayer peer helper.
## Requires Godot WebRTC (enabled in export / editor build with webrtc).
## Signaling: call apply_remote_description / add_ice_candidate from your signaler.

signal peer_ready
signal connection_failed
signal ice_candidate_local(mid: String, index: int, sdp: String)
signal local_description(type: String, sdp: String)

var _rtc: WebRTCMultiplayerPeer
var _connections: Dictionary = {}  # peer_id -> WebRTCPeerConnection

func setup_as_server(max_channels: int = 1) -> Error:
	_rtc = WebRTCMultiplayerPeer.new()
	var err := _rtc.create_server(max_channels)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = _rtc
	peer_ready.emit()
	return OK

func setup_as_client(self_id: int = 1, max_channels: int = 1) -> Error:
	_rtc = WebRTCMultiplayerPeer.new()
	var err := _rtc.create_client(self_id, max_channels)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = _rtc
	peer_ready.emit()
	return OK

func add_peer(peer_id: int) -> WebRTCPeerConnection:
	## Create a WebRTCPeerConnection for remote peer and wire ICE.
	if _rtc == null:
		push_error("Call setup_as_server/client first")
		return null
	var conn := WebRTCPeerConnection.new()
	conn.session_description_created.connect(func(type: String, sdp: String):
		local_description.emit(type, sdp)
	)
	conn.ice_candidate_created.connect(func(mid: String, index: int, sdp: String):
		ice_candidate_local.emit(mid, index, sdp)
	)
	var err := conn.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
	if err != OK:
		push_error("WebRTC initialize failed: %s" % error_string(err))
		return null
	_rtc.add_peer(conn, peer_id)
	_connections[peer_id] = conn
	return conn

func create_offer(peer_id: int) -> void:
	var conn: WebRTCPeerConnection = _connections.get(peer_id)
	if conn:
		conn.create_offer()

func apply_remote_description(peer_id: int, type: String, sdp: String) -> Error:
	var conn: WebRTCPeerConnection = _connections.get(peer_id)
	if conn == null:
		return ERR_DOES_NOT_EXIST
	return conn.set_remote_description(type, sdp)

func add_ice_candidate(peer_id: int, mid: String, index: int, sdp: String) -> Error:
	var conn: WebRTCPeerConnection = _connections.get(peer_id)
	if conn == null:
		return ERR_DOES_NOT_EXIST
	return conn.add_ice_candidate(mid, index, sdp)

func poll() -> void:
	if _rtc:
		_rtc.poll()
	for id in _connections:
		var c: WebRTCPeerConnection = _connections[id]
		if c:
			c.poll()

func _process(_delta: float) -> void:
	poll()

func leave() -> void:
	_connections.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_rtc = null
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({
		"path": w["path"],
		"hint": "Pair with create_signaling_server_script. Export needs WebRTC enabled.",
		"stun": "stun:stun.l.google.com:19302",
	})


func _create_signaling_server_script(params: Dictionary) -> Dictionary:
	## Lightweight WebSocket signaling (Godot as host) for WebRTC offer/answer/ICE relay.
	var path: String = optional_string(params, "path", "res://scripts/webrtc_signaling_server.gd")
	var port: int = optional_int(params, "port", 9081)
	var content := """extends Node
## MCP WebSocket signaling server — relays JSON messages between peers in a room.
## Protocol (JSON lines/text frames):
##   {"type":"join","room":"lobby","id":1}
##   {"type":"signal","room":"lobby","to":2,"payload":{...}}
##   {"type":"leave","room":"lobby"}

const PORT := %d
signal client_joined(peer_id: int, room: String)
signal message_relayed(from_id: int, to_id: int)

var _server: WebSocketMultiplayerPeer  # used only as raw server peer for simplicity
var _tcp: TCPServer
var _peers: Dictionary = {}  # id -> WebSocketPeer
var _rooms: Dictionary = {}  # room -> Array[int]
var _next_id: int = 2

func start(port: int = PORT) -> Error:
	_tcp = TCPServer.new()
	var err := _tcp.listen(port)
	if err != OK:
		return err
	print("[signal] listening on ", port)
	return OK

func _process(_delta: float) -> void:
	if _tcp and _tcp.is_connection_available():
		var stream := _tcp.take_connection()
		var ws := WebSocketPeer.new()
		ws.accept_stream(stream)
		var id := _next_id
		_next_id += 1
		_peers[id] = ws
	var dead: Array = []
	for id in _peers:
		var ws: WebSocketPeer = _peers[id]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var pkt := ws.get_packet().get_string_from_utf8()
				_handle(id, pkt)
		elif st == WebSocketPeer.STATE_CLOSED:
			dead.append(id)
	for id2 in dead:
		_remove_peer(id2)

func _handle(from_id: int, text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var t := str(data.get("type", ""))
	var room := str(data.get("room", "default"))
	match t:
		"join":
			if not _rooms.has(room):
				_rooms[room] = []
			if not _rooms[room].has(from_id):
				_rooms[room].append(from_id)
			client_joined.emit(from_id, room)
			_send(from_id, {"type": "joined", "id": from_id, "room": room, "peers": _rooms[room]})
			_broadcast(room, {"type": "peer_joined", "id": from_id}, from_id)
		"signal":
			var to_id := int(data.get("to", 0))
			var payload = data.get("payload", {})
			_send(to_id, {"type": "signal", "from": from_id, "payload": payload})
			message_relayed.emit(from_id, to_id)
		"leave":
			_leave_room(from_id, room)

func _leave_room(id: int, room: String) -> void:
	if _rooms.has(room):
		_rooms[room].erase(id)
		_broadcast(room, {"type": "peer_left", "id": id}, id)

func _remove_peer(id: int) -> void:
	for room in _rooms.keys():
		if _rooms[room].has(id):
			_leave_room(id, room)
	_peers.erase(id)

func _send(id: int, obj: Dictionary) -> void:
	if not _peers.has(id):
		return
	var ws: WebSocketPeer = _peers[id]
	ws.send_text(JSON.stringify(obj))

func _broadcast(room: String, obj: Dictionary, except: int = -1) -> void:
	if not _rooms.has(room):
		return
	for id in _rooms[room]:
		if id != except:
			_send(id, obj)

func stop() -> void:
	for id in _peers.keys():
		var ws: WebSocketPeer = _peers[id]
		ws.close()
	_peers.clear()
	if _tcp:
		_tcp.stop()
""" % port
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "port": port, "protocol": "websocket_json_signaling"})


func _create_matchmaking_client_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/matchmaking_client.gd")
	var content := """extends Node
## MCP matchmaking client — connects to signaling server, joins room, relays WebRTC signals.

signal room_joined(self_id: int, peers: Array)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal signal_received(from_id: int, payload: Dictionary)
signal connected
signal disconnected

@export var server_url: String = "ws://127.0.0.1:9081"
@export var room: String = "lobby"

var _ws: WebSocketPeer
var self_id: int = 0

func connect_to_server(url: String = "") -> Error:
	if url != "":
		server_url = url
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(server_url)
	if err != OK:
		return err
	return OK

func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if self_id == 0 and not _joined:
			_send({"type": "join", "room": room})
			_joined = true
			connected.emit()
		while _ws.get_available_packet_count() > 0:
			var text := _ws.get_packet().get_string_from_utf8()
			_handle(text)
	elif st == WebSocketPeer.STATE_CLOSED and _joined:
		_joined = false
		disconnected.emit()

var _joined: bool = false

func join_room(room_name: String = "") -> void:
	if room_name != "":
		room = room_name
	_send({"type": "join", "room": room})

func send_signal_to(peer_id: int, payload: Dictionary) -> void:
	_send({"type": "signal", "room": room, "to": peer_id, "payload": payload})

func leave() -> void:
	_send({"type": "leave", "room": room})
	if _ws:
		_ws.close()
	_ws = null
	_joined = false

func _send(obj: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(obj))

func _handle(text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	match str(data.get("type", "")):
		"joined":
			self_id = int(data.get("id", 0))
			room_joined.emit(self_id, data.get("peers", []))
		"peer_joined":
			peer_joined.emit(int(data.get("id", 0)))
		"peer_left":
			peer_left.emit(int(data.get("id", 0)))
		"signal":
			signal_received.emit(int(data.get("from", 0)), data.get("payload", {}))
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"]})


func _create_input_buffer_netcode_script(params: Dictionary) -> Dictionary:
	## Delay-based / input-buffer netcode (not full rollback).
	var path: String = optional_string(params, "path", "res://scripts/input_buffer_netcode.gd")
	var delay: int = optional_int(params, "input_delay_frames", 2)
	var content := """extends Node
## MCP input-buffer netcode — fixed input delay for peer-to-peer lockstep-ish feel.
## Not full rollback/GGPO. Good base for fighters/platform fighters prototypes.

signal frame_ready(frame: int, inputs: Dictionary)

@export var input_delay_frames: int = %d
@export var max_rollback_window: int = 8  # reserved for future

## frame -> { peer_id: input_dict }
var _buffer: Dictionary = {}
var _local_peer_id: int = 1
var _current_frame: int = 0

func setup(local_id: int, delay: int = -1) -> void:
	_local_peer_id = local_id
	if delay >= 0:
		input_delay_frames = delay
	_current_frame = 0
	_buffer.clear()

func submit_local_input(input: Dictionary) -> void:
	## Schedule local input at frame + delay; RPC to peers.
	var target := _current_frame + input_delay_frames
	_store(target, _local_peer_id, input)
	if multiplayer.has_multiplayer_peer():
		_rpc_input.rpc(target, input)

@rpc("any_peer", "reliable")
func _rpc_input(frame: int, input: Dictionary) -> void:
	var from := multiplayer.get_remote_sender_id()
	if from == 0:
		from = multiplayer.get_unique_id()
	_store(frame, from, input)

func _store(frame: int, peer_id: int, input: Dictionary) -> void:
	if not _buffer.has(frame):
		_buffer[frame] = {}
	_buffer[frame][peer_id] = input

func tick(expected_peers: Array) -> bool:
	## Advance one frame if all peer inputs for current frame are present.
	if not _buffer.has(_current_frame):
		return false
	var frame_inputs: Dictionary = _buffer[_current_frame]
	for pid in expected_peers:
		if not frame_inputs.has(pid):
			return false
	frame_ready.emit(_current_frame, frame_inputs)
	_buffer.erase(_current_frame)
	_current_frame += 1
	return true

func get_current_frame() -> int:
	return _current_frame
""" % delay
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({
		"path": w["path"],
		"input_delay_frames": delay,
		"note": "This is delay-based netcode, not full rollback simulation.",
	})


func _create_lag_compensation_helper_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/lag_compensation.gd")
	var content := """extends RefCounted
## MCP lag compensation helpers — rewind positions by RTT for hit validation (server-side).
## class_name LagCompensation

class_name LagCompensation

## history: peer_id -> Array[{t: float, pos: Vector3/Vector2}]
static func record(history: Dictionary, peer_id: int, pos: Variant, t: float, max_samples: int = 64) -> void:
	if not history.has(peer_id):
		history[peer_id] = []
	var arr: Array = history[peer_id]
	arr.append({"t": t, "pos": pos})
	while arr.size() > max_samples:
		arr.pop_front()

static func sample_at(history: Dictionary, peer_id: int, t: float) -> Variant:
	if not history.has(peer_id):
		return null
	var arr: Array = history[peer_id]
	if arr.is_empty():
		return null
	# Find bracketing samples
	var prev = arr[0]
	for s in arr:
		if s["t"] >= t:
			# lerp
			var dt: float = s["t"] - prev["t"]
			if dt <= 0.0001:
				return s["pos"]
			var a: float = clampf((t - prev["t"]) / dt, 0.0, 1.0)
			return _lerp_pos(prev["pos"], s["pos"], a)
		prev = s
	return arr[arr.size() - 1]["pos"]

static func _lerp_pos(a: Variant, b: Variant, t: float) -> Variant:
	if a is Vector3 and b is Vector3:
		return (a as Vector3).lerp(b as Vector3, t)
	if a is Vector2 and b is Vector2:
		return (a as Vector2).lerp(b as Vector2, t)
	return b

static func rtt_rewind_time(now: float, rtt_sec: float) -> float:
	return now - rtt_sec * 0.5
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "class_name": "LagCompensation"})


func _create_webrtc_ice_config(params: Dictionary) -> Dictionary:
	## Project-neutral ICE/STUN/TURN config helper used by WebRTC peers.
	var path: String = optional_string(params, "path", "res://scripts/webrtc_ice_config.gd")
	var stun: Array = params.get("stun_servers", ["stun:stun.l.google.com:19302"])
	var turn_url: String = optional_string(params, "turn_url", "")
	var turn_user: String = optional_string(params, "turn_username", "")
	var turn_pass: String = optional_string(params, "turn_password", "")
	var content := """extends RefCounted
class_name WebRTCIceConfig
## MCP ICE configuration — STUN always; TURN optional (set project settings or args).

static func default_stun() -> PackedStringArray:
	return PackedStringArray(["stun:stun.l.google.com:19302"])

static func build_ice_servers(
	stun_servers: PackedStringArray = default_stun(),
	turn_url: String = "",
	turn_username: String = "",
	turn_password: String = ""
) -> Array:
	var servers: Array = []
	for s in stun_servers:
		servers.append({"urls": [s]})
	if not turn_url.is_empty():
		servers.append({
			"urls": [turn_url],
			"username": turn_username,
			"credential": turn_password,
		})
	return servers

static func apply_to_peer(peer: WebRTCMultiplayerPeer, ice_servers: Array = []) -> void:
	if ice_servers.is_empty():
		ice_servers = build_ice_servers()
	if peer.has_method("set_ice_servers"):
		peer.call("set_ice_servers", ice_servers)
	peer.set_meta("mcp_ice_servers", ice_servers)

static func from_project_settings() -> Array:
	var stun = ProjectSettings.get_setting("mcp/webrtc_stun", default_stun())
	var turn := str(ProjectSettings.get_setting("mcp/webrtc_turn_url", ""))
	var user := str(ProjectSettings.get_setting("mcp/webrtc_turn_user", ""))
	var pass := str(ProjectSettings.get_setting("mcp/webrtc_turn_pass", ""))
	var arr := PackedStringArray()
	if stun is PackedStringArray:
		arr = stun
	elif stun is Array:
		for s in stun:
			arr.append(str(s))
	else:
		arr = default_stun()
	return build_ice_servers(arr, turn, user, pass)
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	if optional_bool(params, "write_project_settings", false):
		if stun is Array:
			var psa := PackedStringArray()
			for s in stun:
				psa.append(str(s))
			ProjectSettings.set_setting("mcp/webrtc_stun", psa)
		if not turn_url.is_empty():
			ProjectSettings.set_setting("mcp/webrtc_turn_url", turn_url)
			ProjectSettings.set_setting("mcp/webrtc_turn_user", turn_user)
			ProjectSettings.set_setting("mcp/webrtc_turn_pass", turn_pass)
		ProjectSettings.save()
	return success({
		"path": w.get("path", path),
		"stun": stun,
		"turn_configured": not turn_url.is_empty(),
		"hint": "Pass TURN url/user/pass from your relay; commercial matchmaking not included",
	})
