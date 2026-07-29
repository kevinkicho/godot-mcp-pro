## TCP JSON-lines runtime probe server (127.0.0.1:6510-6514).
## Extracted from MCPGameInspector for maintainability.
## Emits command_request; caller must call complete() with the response payload.
extends RefCounted

const PORT_FILE := "user://mcp_runtime_port"
const META_FILE := "user://mcp_runtime_meta.json"
const PORT_START := 6510
const PORT_END := 6514
const MAX_CLIENTS := 8
const MAX_QUEUE := 48

signal command_request(peer: StreamPeerTCP, req_id: int, command: String, params: Dictionary)

var _tcp: TCPServer
var port: int = 0
var _clients: Array = []
var _buffers: Dictionary = {}
var _queue: Array = []
var _busy: bool = false
var _pending_peer: StreamPeerTCP = null
var _pending_id: int = 0


func get_port() -> int:
	return port


func is_busy() -> bool:
	return _busy


func queue_depth() -> int:
	return _queue.size()


func client_count() -> int:
	return _clients.size()


func pending_peer() -> StreamPeerTCP:
	return _pending_peer


func start() -> bool:
	_tcp = TCPServer.new()
	for p in range(PORT_START, PORT_END + 1):
		if _tcp.listen(p, "127.0.0.1") == OK:
			port = p
			_write_meta()
			print("[MCP] Runtime TCP 127.0.0.1:%d (queue=%d%s)" % [
				p, MAX_QUEUE, " auth=on" if auth_required() else " auth=off"
			])
			return true
	_tcp = null
	push_warning("[MCP] Runtime TCP ports %d-%d busy — file IPC only" % [PORT_START, PORT_END])
	return false


func stop() -> void:
	_queue.clear()
	_busy = false
	_pending_peer = null
	for c in _clients:
		if c is StreamPeerTCP:
			(c as StreamPeerTCP).disconnect_from_host()
	_clients.clear()
	_buffers.clear()
	if _tcp:
		_tcp.stop()
		_tcp = null
	port = 0


static func expected_token() -> String:
	var t := OS.get_environment("MCP_RUNTIME_TOKEN")
	if t.is_empty() and ProjectSettings.has_setting("mcp/runtime_token"):
		t = str(ProjectSettings.get_setting("mcp/runtime_token", ""))
	return t


static func auth_required() -> bool:
	return not expected_token().is_empty()


static func request_authorized(parsed: Dictionary) -> bool:
	var expected := expected_token()
	if expected.is_empty():
		return true
	var got := str(parsed.get("token", parsed.get("auth", "")))
	if got.is_empty() and parsed.get("params") is Dictionary:
		got = str(parsed["params"].get("token", parsed["params"].get("auth", "")))
	return got == expected


func _write_meta() -> void:
	var meta := {
		"port": port,
		"host": "127.0.0.1",
		"auth_required": auth_required(),
		"max_clients": MAX_CLIENTS,
		"max_queue": MAX_QUEUE,
		"protocol": "json_lines_v1",
	}
	var f := FileAccess.open(META_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))
		f.close()
	var pf := FileAccess.open(PORT_FILE, FileAccess.WRITE)
	if pf:
		pf.store_string(str(port))
		pf.close()


func poll() -> void:
	if _tcp == null:
		return
	while _tcp.is_connection_available():
		if _clients.size() >= MAX_CLIENTS:
			var reject: StreamPeerTCP = _tcp.take_connection()
			if reject:
				send_raw(reject, {"id": 0, "ok": false, "error": "too many clients", "code": "max_clients"})
				reject.disconnect_from_host()
			break
		var peer: StreamPeerTCP = _tcp.take_connection()
		if peer:
			_clients.append(peer)
			_buffers[peer.get_instance_id()] = ""
	var dead: Array = []
	for peer in _clients:
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
		var buf: String = str(_buffers.get(id, "")) + chunk.get_string_from_utf8()
		while true:
			var nl := buf.find("\n")
			if nl < 0:
				break
			var line := buf.substr(0, nl).strip_edges()
			buf = buf.substr(nl + 1)
			if not line.is_empty():
				_on_line(p, line)
		_buffers[id] = buf
	for d in dead:
		_drop_client(d)
	if not _busy:
		_drain()


func _drop_client(p: StreamPeerTCP) -> void:
	var kept: Array = []
	for item in _queue:
		if item is Dictionary and item.get("peer") == p:
			continue
		kept.append(item)
	_queue = kept
	_clients.erase(p)
	_buffers.erase(p.get_instance_id())
	if _pending_peer == p:
		_pending_peer = null


func _on_line(peer: StreamPeerTCP, line: String) -> void:
	var parsed = JSON.parse_string(line)
	if parsed == null or not parsed is Dictionary:
		send_raw(peer, {"id": 0, "ok": false, "error": "Invalid JSON", "code": "bad_json"})
		return
	var req_id: int = int(parsed.get("id", 0))
	if not request_authorized(parsed):
		send_raw(peer, {
			"id": req_id,
			"ok": false,
			"error": "unauthorized — set MCP_RUNTIME_TOKEN or mcp/runtime_token and pass token=",
			"code": "auth_required",
			"auth_required": true,
		})
		return
	var command: String = str(parsed.get("command", ""))
	var params: Dictionary = parsed.get("params", {}) if parsed.get("params") is Dictionary else {}
	if command.is_empty():
		send_raw(peer, {"id": req_id, "ok": false, "error": "command required", "code": "bad_request"})
		return
	if _busy:
		if _queue.size() >= MAX_QUEUE:
			send_raw(peer, {
				"id": req_id,
				"ok": false,
				"error": "runtime queue full (%d)" % MAX_QUEUE,
				"code": "queue_full",
				"queue_depth": _queue.size(),
			})
			return
		_queue.append({"peer": peer, "id": req_id, "command": command, "params": params})
		return
	_begin(peer, req_id, command, params)


func _begin(peer: StreamPeerTCP, req_id: int, command: String, params: Dictionary) -> void:
	_busy = true
	_pending_peer = peer
	_pending_id = req_id
	command_request.emit(peer, req_id, command, params)


func _drain() -> void:
	if _busy:
		return
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		var peer: StreamPeerTCP = item.get("peer")
		if peer == null or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		_begin(peer, int(item.get("id", 0)), str(item.get("command", "")), item.get("params", {}))
		return


func send_raw(peer: StreamPeerTCP, obj: Dictionary) -> void:
	if peer == null:
		return
	peer.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())


## Complete the in-flight request (success or error payload from inspector).
func complete(data: Dictionary) -> void:
	if _pending_peer != null:
		var envelope: Dictionary
		if data.has("error") and data.size() == 1:
			envelope = {"id": _pending_id, "ok": false, "error": str(data["error"])}
		elif data.has("error") and typeof(data["error"]) == TYPE_STRING and not data.has("result"):
			envelope = {"id": _pending_id, "ok": false, "error": str(data["error"]), "data": data}
		else:
			envelope = {"id": _pending_id, "ok": true, "data": data}
		envelope["queue_depth"] = _queue.size()
		send_raw(_pending_peer, envelope)
		_pending_peer = null
		_pending_id = 0
	_busy = false
	_drain()


func info_dict() -> Dictionary:
	return {
		"tcp_port": port,
		"host": "127.0.0.1",
		"auth_required": auth_required(),
		"queue_depth": _queue.size(),
		"clients": _clients.size(),
		"max_clients": MAX_CLIENTS,
		"max_queue": MAX_QUEUE,
		"dispatch_busy": _busy,
		"protocol": "json_lines_v1",
	}
