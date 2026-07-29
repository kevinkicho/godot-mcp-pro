## Editor-side TCP client for MCPGameInspector runtime probe.
extends RefCounted

const PORT_START := 6510
const PORT_END := 6514


static func token() -> String:
	var t := OS.get_environment("MCP_RUNTIME_TOKEN")
	if t.is_empty() and ProjectSettings.has_setting("mcp/runtime_token"):
		t = str(ProjectSettings.get_setting("mcp/runtime_token", ""))
	return t


static func discover_ports(user_dir: String = "") -> Array:
	var ports: Array = []
	var candidates: Array = []
	if not user_dir.is_empty():
		candidates.append(user_dir.path_join("mcp_runtime_port"))
		candidates.append(user_dir.path_join("mcp_runtime_meta.json"))
	candidates.append(OS.get_user_data_dir().path_join("mcp_runtime_port"))
	candidates.append(OS.get_user_data_dir().path_join("mcp_runtime_meta.json"))
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var raw := f.get_as_text().strip_edges()
		f.close()
		if raw.begins_with("{"):
			var j = JSON.parse_string(raw)
			if j is Dictionary and int(j.get("port", 0)) >= PORT_START:
				var pj := int(j["port"])
				if pj <= PORT_END and not ports.has(pj):
					ports.append(pj)
		else:
			var p := int(raw)
			if p >= PORT_START and p <= PORT_END and not ports.has(p):
				ports.append(p)
	for p2 in range(PORT_START, PORT_END + 1):
		if not ports.has(p2):
			ports.append(p2)
	return ports


## Async: must be called with await from a Node tree context.
## Returns {ok:true, data:Dictionary, port} or {ok:false, error:String, code?:String}
static func call_command(tree: SceneTree, command: String, params: Dictionary, timeout_sec: float = 5.0, user_dir: String = "") -> Dictionary:
	var ports := discover_ports(user_dir)
	var tok := token()
	var last_err := "no connection"
	var max_attempts := 3
	for attempt in max_attempts:
		for port in ports:
			var peer := StreamPeerTCP.new()
			if peer.connect_to_host("127.0.0.1", int(port)) != OK:
				last_err = "connect failed %d" % port
				continue
			var connect_deadline := Time.get_ticks_msec() + 800
			while Time.get_ticks_msec() < connect_deadline:
				peer.poll()
				var st := peer.get_status()
				if st == StreamPeerTCP.STATUS_CONNECTED:
					break
				if st == StreamPeerTCP.STATUS_ERROR:
					break
				await tree.process_frame
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				peer.disconnect_from_host()
				last_err = "port %d not connected" % port
				continue
			var req_id := Time.get_ticks_msec() % 1000000
			var payload := {"id": req_id, "command": command, "params": params}
			if not tok.is_empty():
				payload["token"] = tok
			peer.put_data((JSON.stringify(payload) + "\n").to_utf8_buffer())
			var buf := ""
			var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
			while Time.get_ticks_msec() < deadline:
				peer.poll()
				if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
					last_err = "disconnected"
					break
				var n := peer.get_available_bytes()
				if n > 0:
					var got: Array = peer.get_data(n)
					if got.size() < 2 or got[0] != OK:
						await tree.process_frame
						continue
					buf += (got[1] as PackedByteArray).get_string_from_utf8()
					var nl := buf.find("\n")
					if nl >= 0:
						var resp_line := buf.substr(0, nl).strip_edges()
						peer.disconnect_from_host()
						var parsed = JSON.parse_string(resp_line)
						if parsed == null or not parsed is Dictionary:
							return {"ok": false, "error": "Invalid TCP JSON"}
						if parsed.get("ok", false) == false:
							var code := str(parsed.get("code", ""))
							if code == "queue_full" and attempt < max_attempts - 1:
								await tree.create_timer(0.05 * (attempt + 1)).timeout
								last_err = "queue_full"
								break
							return {
								"ok": false,
								"error": str(parsed.get("error", "runtime error")),
								"code": code,
								"port": port,
								"queue_depth": parsed.get("queue_depth", 0),
							}
						var data = parsed.get("data", {})
						if data is Dictionary:
							data["_transport"] = "tcp"
							data["_port"] = port
							data["_queue_depth"] = parsed.get("queue_depth", 0)
							return {"ok": true, "data": data, "port": port}
						return {"ok": true, "data": {"value": data, "_transport": "tcp", "_port": port}, "port": port}
				await tree.process_frame
			peer.disconnect_from_host()
			if last_err == "queue_full":
				break
			last_err = "timeout on port %d" % port
	return {"ok": false, "error": last_err}
