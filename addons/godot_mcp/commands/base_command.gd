@tool
extends Node

var editor_plugin: EditorPlugin


## Override in subclasses: return {"method_name": Callable}
func get_commands() -> Dictionary:
	return {}


## Helper: return a success result
func success(data: Dictionary = {}) -> Dictionary:
	return {"result": data}


## Helper: return an error
func error(code: int, message: String, data: Dictionary = {}) -> Dictionary:
	var err := {"code": code, "message": message}
	if not data.is_empty():
		err["data"] = data
	return {"error": err}


## Error codes
func error_not_found(what: String, suggestion: String = "") -> Dictionary:
	var data := {}
	if suggestion:
		data["suggestion"] = suggestion
	return error(-32001, "%s not found" % what, data)


func error_invalid_params(message: String) -> Dictionary:
	return error(-32602, message)


func error_no_scene() -> Dictionary:
	return error(-32000, "No scene is currently open", {"suggestion": "Use open_scene to open a scene first"})


func error_internal(message: String) -> Dictionary:
	return error(-32603, "Internal error: %s" % message)


func error_conflict(message: String, data: Dictionary = {}) -> Dictionary:
	return error(-32009, message, data)


## Get required string param
func require_string(params: Dictionary, key: String) -> Array:
	if not params.has(key) or not params[key] is String or (params[key] as String).is_empty():
		return [null, error_invalid_params("Missing required parameter: %s" % key)]
	return [params[key] as String, null]


## Get optional string param with default
func optional_string(params: Dictionary, key: String, default: String = "") -> String:
	if params.has(key) and params[key] is String:
		return params[key] as String
	return default


## Get optional bool param with default
func optional_bool(params: Dictionary, key: String, default: bool = false) -> bool:
	if params.has(key) and params[key] is bool:
		return params[key] as bool
	return default


## Get optional int param with default
func optional_int(params: Dictionary, key: String, default: int = 0) -> int:
	if params.has(key):
		return int(params[key])
	return default


## Get the game process's user data directory.
## OS.get_user_data_dir() is cached at editor startup and won't reflect
## project name changes made to project.godot while the editor is running.
## The game process reads the name from disk, so we must do the same.
func get_game_user_dir() -> String:
	var cached_dir := OS.get_user_data_dir()
	var cfg := ConfigFile.new()
	var err := cfg.load(ProjectSettings.globalize_path("res://project.godot"))
	if err != OK:
		return cached_dir
	# When use_custom_user_dir=true, editor and game share the same dir
	# (OS.get_user_data_dir() already resolves to the custom path).
	if cfg.get_value("application", "config/use_custom_user_dir", false):
		return cached_dir
	var disk_name = cfg.get_value("application", "config/name", "")
	if typeof(disk_name) != TYPE_STRING or (disk_name as String).is_empty():
		return cached_dir
	# Sanitize exactly like Godot does when computing the default user dir
	# (core/config/project_settings.cpp ProjectSettings::_init).
	var sanitized := (disk_name as String).xml_unescape().validate_filename().replace(".", "_")
	if sanitized.is_empty():
		return cached_dir
	var base_dir := cached_dir.get_base_dir()
	var game_dir := base_dir.path_join(sanitized)
	# Ensure the directory exists (game may not have created it yet)
	if not DirAccess.dir_exists_absolute(game_dir):
		DirAccess.make_dir_recursive_absolute(game_dir)
	return game_dir


## Get EditorInterface
func get_editor() -> EditorInterface:
	return editor_plugin.get_editor_interface()


## Get the edited scene root
func get_edited_root() -> Node:
	return EditorInterface.get_edited_scene_root()


## Get UndoRedo
func get_undo_redo() -> EditorUndoRedoManager:
	return editor_plugin.get_undo_redo()


func normalize_project_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		return path.simplify_path()
	return ProjectSettings.localize_path(path).simplify_path()


## Require a project-relative res:// path for mutating file operations.
## Rejects empty paths, absolute OS paths that don't localize, and ".." traversal.
## Returns [normalized_path, null] on success or [null, error_dict] on failure.
func require_res_path(params: Dictionary, key: String = "path") -> Array:
	var result := require_string(params, key)
	if result[1] != null:
		return result
	return validate_res_path(result[0] as String)


func validate_res_path(path: String) -> Array:
	var normalized := normalize_project_path(path)
	if normalized.is_empty():
		return [null, error_invalid_params("Path is empty after normalization")]
	if normalized.contains(".."):
		return [null, error_invalid_params("Path must not contain '..': %s" % normalized)]
	if not normalized.begins_with("res://"):
		# Allow bare relative paths by prefixing res://
		if not normalized.begins_with("user://") and not normalized.contains("://"):
			normalized = normalize_project_path("res://" + normalized.trim_prefix("/"))
		if not normalized.begins_with("res://"):
			return [null, error_invalid_params(
				"Mutating tools require a res:// project path (got '%s'). Refuse absolute/OS paths." % path
			)]
	if normalized.contains(".."):
		return [null, error_invalid_params("Path must not contain '..': %s" % normalized)]
	return [normalized, null]


func is_scene_resource_path(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext == "tscn" or ext == "scn"


func get_open_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	for scene_path: String in open_scenes:
		var normalized := normalize_project_path(scene_path)
		if not normalized.is_empty() and normalized not in paths:
			paths.append(normalized)

	var root := get_edited_root()
	if root != null and not root.scene_file_path.is_empty():
		var active_path := normalize_project_path(root.scene_file_path)
		if active_path not in paths:
			paths.append(active_path)
	return paths


func is_scene_path_open(path: String) -> bool:
	var normalized := normalize_project_path(path)
	if normalized.is_empty():
		return false
	return normalized in get_open_scene_paths()


func is_active_scene_path(path: String) -> bool:
	var root := get_edited_root()
	if root == null:
		return false
	return normalize_project_path(root.scene_file_path) == normalize_project_path(path)


func guard_offline_scene_save(path: String) -> Dictionary:
	if is_scene_resource_path(path) and is_scene_path_open(path):
		return error_conflict(
			"Refusing to save open scene '%s' outside the Godot editor state" % normalize_project_path(path),
			{
				"path": normalize_project_path(path),
				"open_scenes": get_open_scene_paths(),
				"suggestion": "Use live editor changes plus save_scene, or close the scene before offline edits.",
			}
		)
	return {}


## Helper: create the parent directory of a res:// path if missing.
## Returns {} on success, an error dictionary on failure.
func ensure_parent_dir(path: String) -> Dictionary:
	## Accepts res:// or absolute OS paths; creates parent directory if missing.
	var dir := path.get_base_dir()
	if dir.is_empty():
		return {}
	var abs_dir := ProjectSettings.globalize_path(dir) if dir.begins_with("res://") or dir.begins_with("user://") else dir
	if DirAccess.dir_exists_absolute(abs_dir):
		return {}
	var derr := DirAccess.make_dir_recursive_absolute(abs_dir)
	if derr != OK:
		return error_internal("Cannot create directory '%s': %s" % [dir, error_string(derr)])
	return {}


## Helper: unwrap the (possibly multi-)wrapped {"result": ...} envelope returned
## by the game IPC channel. The game writes its own {"result": ...} envelope and
## the transport wraps it again, so consumers must unwrap defensively.
func unwrap_game_result(result: Dictionary) -> Dictionary:
	var payload: Variant = result
	while payload is Dictionary and payload.has("result") and payload["result"] is Dictionary:
		payload = payload["result"]
	return payload if payload is Dictionary else {}


## Shared IPC helper: send a command to the running game and await its response.
## Prefers TCP runtime probe (127.0.0.1:6510-6514); falls back to file IPC.
func send_game_command(command: String, params: Dictionary = {}, timeout_sec: float = 5.0) -> Dictionary:
	var ei := get_editor()
	var playing := ei != null and ei.is_playing_scene()
	# TCP works for editor Play AND standalone game processes
	var tcp_res := await _send_game_command_tcp(command, params, timeout_sec)
	if tcp_res.get("_tcp_ok", false):
		tcp_res.erase("_tcp_ok")
		tcp_res.erase("_transport")
		return tcp_res
	# File IPC only when editor is playing (same user://)
	if not playing:
		return error(-32000, "No scene is currently playing and runtime TCP unavailable", {
			"suggestion": "run_session_start, or launch game with MCPGameInspector autoload (ports 6510-6514)",
			"tcp_error": tcp_res.get("error", tcp_res),
		})

	var user_dir := get_game_user_dir()
	var request_path := user_dir + "/mcp_game_request"
	var response_path := user_dir + "/mcp_game_response"

	# Clean stale response
	if FileAccess.file_exists(response_path):
		DirAccess.remove_absolute(response_path)

	# Write request
	var request_data := JSON.stringify({"command": command, "params": params})
	var req := FileAccess.open(request_path, FileAccess.WRITE)
	if req == null:
		return error_internal("Could not create game request file")
	req.store_string(request_data)
	req.close()

	# Poll for response
	var attempts := int(timeout_sec / 0.1)
	while attempts > 0:
		await get_tree().create_timer(0.1).timeout
		if FileAccess.file_exists(response_path):
			break
		if not ei.is_playing_scene():
			if FileAccess.file_exists(request_path):
				DirAccess.remove_absolute(request_path)
			return error(-32000, "Game stopped during command execution")
		attempts -= 1

	if not FileAccess.file_exists(response_path):
		# Try to auto-resume the debugger (runtime error may have paused the game)
		if ei.is_playing_scene():
			try_debugger_continue()
			for _retry in 20:
				await get_tree().create_timer(0.1).timeout
				if FileAccess.file_exists(response_path):
					break

	if not FileAccess.file_exists(response_path):
		if FileAccess.file_exists(request_path):
			DirAccess.remove_absolute(request_path)
		return build_timeout_error(timeout_sec)

	# Read response
	var file := FileAccess.open(response_path, FileAccess.READ)
	if file == null:
		return error_internal("Could not read game response file")
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(response_path)

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return error_internal("Invalid response JSON from game")

	if parsed.has("error"):
		return error(-32000, str(parsed["error"]))

	var out := success(parsed)
	if out.has("result") and out["result"] is Dictionary:
		out["result"]["_transport"] = "file"
	return out


func _runtime_ports() -> Array:
	var ports: Array = []
	# Prefer port advertised by game
	var port_file := get_game_user_dir() + "/mcp_runtime_port"
	if FileAccess.file_exists(port_file):
		var f := FileAccess.open(port_file, FileAccess.READ)
		if f:
			var p := int(f.get_as_text().strip_edges())
			f.close()
			if p >= 6510 and p <= 6514:
				ports.append(p)
	# Also try default user path
	var alt := OS.get_user_data_dir() + "/mcp_runtime_port"
	if FileAccess.file_exists(alt):
		var f2 := FileAccess.open(alt, FileAccess.READ)
		if f2:
			var p2 := int(f2.get_as_text().strip_edges())
			f2.close()
			if p2 >= 6510 and p2 <= 6514 and not ports.has(p2):
				ports.append(p2)
	for p3 in range(6510, 6515):
		if not ports.has(p3):
			ports.append(p3)
	return ports


func _runtime_token() -> String:
	var t := OS.get_environment("MCP_RUNTIME_TOKEN")
	if t.is_empty() and ProjectSettings.has_setting("mcp/runtime_token"):
		t = str(ProjectSettings.get_setting("mcp/runtime_token", ""))
	return t


func _send_game_command_tcp(command: String, params: Dictionary, timeout_sec: float) -> Dictionary:
	var ports := _runtime_ports()
	var last_err := "no connection"
	var token := _runtime_token()
	# Retry a few times on queue_full (multi-agent contention)
	var max_attempts := 3
	for attempt in max_attempts:
		for port in ports:
			var peer := StreamPeerTCP.new()
			var err := peer.connect_to_host("127.0.0.1", int(port))
			if err != OK:
				last_err = "connect %d: %s" % [port, error_string(err)]
				continue
			var connect_deadline := Time.get_ticks_msec() + 800
			while Time.get_ticks_msec() < connect_deadline:
				peer.poll()
				var st := peer.get_status()
				if st == StreamPeerTCP.STATUS_CONNECTED:
					break
				if st == StreamPeerTCP.STATUS_ERROR:
					break
				await get_tree().process_frame
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				peer.disconnect_from_host()
				last_err = "port %d not connected" % port
				continue
			var req_id := Time.get_ticks_msec() % 1000000
			var payload := {"id": req_id, "command": command, "params": params}
			if not token.is_empty():
				payload["token"] = token
			var line := JSON.stringify(payload) + "\n"
			peer.put_data(line.to_utf8_buffer())
			var buf := ""
			var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
			while Time.get_ticks_msec() < deadline:
				peer.poll()
				if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
					last_err = "disconnected during wait"
					break
				var n := peer.get_available_bytes()
				if n > 0:
					var got: Array = peer.get_data(n)
					if got.size() < 2 or got[0] != OK:
						await get_tree().process_frame
						continue
					var chunk: PackedByteArray = got[1]
					buf += chunk.get_string_from_utf8()
					var nl := buf.find("\n")
					if nl >= 0:
						var resp_line := buf.substr(0, nl).strip_edges()
						peer.disconnect_from_host()
						var parsed = JSON.parse_string(resp_line)
						if parsed == null or not parsed is Dictionary:
							return error_internal("Invalid TCP JSON from game")
						if parsed.get("ok", false) == false:
							var code := str(parsed.get("code", ""))
							if code == "queue_full" and attempt < max_attempts - 1:
								await get_tree().create_timer(0.05 * (attempt + 1)).timeout
								last_err = "queue_full retry"
								break  # retry outer
							return error(-32000, str(parsed.get("error", "runtime error")), {
								"transport": "tcp",
								"port": port,
								"code": code,
								"queue_depth": parsed.get("queue_depth", 0),
							})
						var data = parsed.get("data", {})
						if data is Dictionary:
							data["_transport"] = "tcp"
							data["_port"] = port
							data["_queue_depth"] = parsed.get("queue_depth", 0)
							var ok_out := success(data)
							ok_out["_tcp_ok"] = true
							return ok_out
						var ok2 := success({"value": data, "_transport": "tcp", "_port": port})
						ok2["_tcp_ok"] = true
						return ok2
				await get_tree().process_frame
			peer.disconnect_from_host()
			if last_err == "queue_full retry":
				continue
			last_err = "timeout on port %d" % port
	return {"_tcp_ok": false, "error": last_err}


func is_shader_resource_path(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext == "gdshader" or ext == "gdshaderinc" or ext == "shader"


func is_text_resource_open_in_script_editor(path: String) -> bool:
	var target := normalize_project_path(path)
	if target.is_empty():
		return false
	if is_shader_resource_path(target) and ResourceLoader.has_cached(target):
		return true
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return false
	for open_resource in script_editor.get_open_scripts():
		if open_resource is Resource:
			var resource_path := normalize_project_path((open_resource as Resource).resource_path)
			if resource_path == target:
				return true
	return false


func guard_text_resource_write(path: String, force: bool) -> Dictionary:
	if not force and is_text_resource_open_in_script_editor(path):
		return error_conflict(
			"Refusing to write open text resource '%s' outside the script editor state" % normalize_project_path(path),
			{
				"path": normalize_project_path(path),
				"suggestion": "Close the file in Godot's script editor or pass force=true to overwrite it deliberately.",
			}
		)
	return {}


func mark_current_scene_unsaved() -> void:
	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()


func add_child_with_undo(parent: Node, child: Node, root: Node, action_name: String) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", child)
	undo_redo.add_do_method(child, "set_owner", root)
	undo_redo.add_do_reference(child)
	undo_redo.add_undo_method(parent, "remove_child", child)
	undo_redo.commit_action()


func set_property_with_undo(target: Object, property: String, new_value: Variant, action_name: String) -> void:
	var old_value: Variant = target.get(property)
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_property(target, property, new_value)
	if new_value is Resource:
		undo_redo.add_do_reference(new_value)
	undo_redo.add_undo_property(target, property, old_value)
	if old_value is Resource:
		undo_redo.add_undo_reference(old_value)
	undo_redo.commit_action()


## ── Game-command timeout diagnostics ──────────────────────────────────────────
## Shared by the file-IPC `_send_game_command` helpers (runtime/test commands).
## The goal is to never tell the agent "the game isn't running / autoload missing"
## when the game IS running and merely paused by a runtime error.

## Locate the editor's ScriptEditorDebugger node (BFS from base control).
func _find_script_editor_debugger() -> Node:
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	var queue: Array[Node] = [base]
	while not queue.is_empty():
		var node := queue.pop_front()
		if node.get_class() == "ScriptEditorDebugger":
			return node
		for child in node.get_children():
			queue.append(child)
	return null


## Look up an editor theme icon by name (locale-independent), or null.
func _get_editor_icon(icon_name: String) -> Texture2D:
	var base := EditorInterface.get_base_control()
	if base != null and base.has_theme_icon(icon_name, "EditorIcons"):
		return base.get_theme_icon(icon_name, "EditorIcons")
	return null


## Find the debugger "Continue" button without relying on UI text.
## The editor is translated, so matching tooltip/label text breaks for
## non-English editors (issue #34: Italian → "Continua"). Match by the editor
## theme icon "DebugContinue" first, falling back to the English text only if
## the icon can't be resolved.
func _find_debugger_continue_button() -> Button:
	var dbg := _find_script_editor_debugger()
	if dbg == null:
		return null
	var continue_icon := _get_editor_icon("DebugContinue")
	var fallback: Button = null
	var inner: Array[Node] = [dbg]
	while not inner.is_empty():
		var n := inner.pop_front()
		if n is Button:
			var b := n as Button
			if continue_icon != null and b.icon == continue_icon:
				return b
			if b.tooltip_text == "Continue":
				fallback = b
		for c in n.get_children():
			inner.append(c)
	return fallback


## True when the running game is halted at a breakpoint or runtime error
## (the debugger's "Continue" button is present and enabled).
func is_debugger_paused() -> bool:
	var btn := _find_debugger_continue_button()
	return btn != null and not btn.disabled


## Read recent runtime errors from the debugger's "Errors" tab tree, so a
## timeout caused by a script error can report the actual cause inline.
func collect_debugger_errors(max_errors: int = 10) -> Array:
	var out: Array = []
	var dbg := _find_script_editor_debugger()
	if dbg == null:
		return out
	for child in dbg.get_children():
		if child is TabContainer:
			var tab_container := child as TabContainer
			for tab_idx in range(tab_container.get_tab_count()):
				var tab_control: Control = tab_container.get_tab_control(tab_idx)
				if tab_control is VBoxContainer and tab_control.name.begins_with("Errors"):
					for vchild in tab_control.get_children():
						if vchild is Tree:
							var tree := vchild as Tree
							var root_item: TreeItem = tree.get_root()
							if root_item:
								var item: TreeItem = root_item.get_first_child()
								while item and out.size() < max_errors:
									var col0: String = item.get_text(0).strip_edges()
									var col1: String = item.get_text(1).strip_edges()
									var msg: String = col0
									if not col1.is_empty():
										msg = (msg + " " + col1) if not msg.is_empty() else col1
									if not msg.is_empty():
										out.append(msg)
									item = item.get_next()
					break
			break
	return out


## Press the debugger "Continue" button to resume a paused game process.
func try_debugger_continue() -> void:
	var btn := _find_debugger_continue_button()
	if btn != null and not btn.disabled:
		btn.emit_signal("pressed")
		push_warning("[MCP] Auto-resumed debugger after runtime error")


## Build an accurate error for a file-IPC game-command timeout.
## Distinguishes "game not running" from "game running but unresponsive
## (likely paused by a runtime error / breakpoint)" so callers aren't misled
## into thinking the MCP connection is dead or the autoload is missing.
func build_timeout_error(timeout_sec: float) -> Dictionary:
	# Re-check play state at the moment we give up.
	if not get_editor().is_playing_scene():
		return error(
			-32000,
			"Game command timed out after %.1fs and the game process is no longer running." % timeout_sec,
			{
				"game_running": false,
				"suggestion": "The scene stopped. Call play_scene to start it again before sending runtime commands.",
			}
		)

	# The game IS running. Figure out *why* it didn't answer.
	var paused := is_debugger_paused()
	var runtime_errors := collect_debugger_errors(10)
	var data := {
		"game_running": true,
		"debugger_paused": paused,
	}
	if not runtime_errors.is_empty():
		data["runtime_errors"] = runtime_errors

	var msg: String
	if paused or not runtime_errors.is_empty():
		msg = ("Game command timed out after %.1fs, but the game IS running. " % timeout_sec) \
			+ "A runtime/script error paused the scene, so it could not respond to the command."
		data["suggestion"] = "This is NOT a connection or autoload problem. Fix the error in 'runtime_errors' " \
			+ "(or call get_editor_errors for the full list), then retry. The debugger was auto-resumed; " \
			+ "if errors persist, call stop_scene then play_scene to restart cleanly."
	else:
		msg = ("Game command timed out after %.1fs. The game is running but did not respond in time." % timeout_sec)
		data["suggestion"] = "The MCP server connection is fine and the game is running. The command may be slow " \
			+ "or the game may be busy/blocked. Retry with a longer timeout, and call get_editor_errors to check " \
			+ "for runtime errors. In rare cases (custom projects) verify the MCPGameInspector autoload is active."
	return error(-32000, msg, data)


## Find node by path in edited scene
func find_node_by_path(node_path: String) -> Node:
	var root := get_edited_root()
	if root == null:
		return null
	if node_path == "." or node_path == root.name:
		return root
	# Try relative from root
	if root.has_node(node_path):
		return root.get_node(node_path)
	# Try with root name prefix stripped
	if node_path.begins_with(root.name + "/"):
		var rel := node_path.substr(root.name.length() + 1)
		if root.has_node(rel):
			return root.get_node(rel)
	return null
