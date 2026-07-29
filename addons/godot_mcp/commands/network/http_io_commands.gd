@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## HTTP + encrypted IO — tutorials/io structural surface for agents.


func get_commands() -> Dictionary:
	return {
		"create_http_client_script": _create_http_client_script,
		"setup_http_request_node": _setup_http_request_node,
		"create_encrypted_save_script": _create_encrypted_save_script,
		"encrypted_file_write": _encrypted_file_write,
		"encrypted_file_read": _encrypted_file_read,
		"list_http_io_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_http_request", "config_file_*", "json_*", "create_save_manager_script"],
		"flow": [
			"create_http_client_script add_autoload=true",
			"setup_http_request_node for one-shot downloads",
			"create_encrypted_save_script for password-derived saves",
		],
	})


func _create_http_client_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/http_client_service.gd")
	var content := """extends Node
## MCP HTTP client service — JSON GET/POST via HTTPRequest child.
signal request_completed(ok: bool, result: Variant, response_code: int)

var _http: HTTPRequest
var _pending: bool = false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "HTTPRequest"
	add_child(_http)
	_http.request_completed.connect(_on_completed)

func get_json(url: String, headers: PackedStringArray = PackedStringArray()) -> Error:
	return _request(url, headers, HTTPClient.METHOD_GET, "")

func post_json(url: String, body: Dictionary, headers: PackedStringArray = PackedStringArray()) -> Error:
	var h := headers
	if h.is_empty():
		h = PackedStringArray(["Content-Type: application/json"])
	return _request(url, h, HTTPClient.METHOD_POST, JSON.stringify(body))

func _request(url: String, headers: PackedStringArray, method: int, body: String) -> Error:
	if _pending:
		return ERR_BUSY
	_pending = true
	var err := _http.request(url, headers, method, body)
	if err != OK:
		_pending = false
	return err

func _on_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_pending = false
	var text := body.get_string_from_utf8()
	var parsed: Variant = text
	var j := JSON.new()
	if j.parse(text) == OK:
		parsed = j.data
	var ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	request_completed.emit(ok, parsed, response_code)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var added := maybe_add_autoload(params, path, "HttpClient")
	return success({"path": path, "autoload_added": added})


func _setup_http_request_node(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var http := HTTPRequest.new()
	http.name = optional_string(params, "name", "HTTPRequest")
	if params.has("timeout") and "timeout" in http:
		http.timeout = float(params["timeout"])
	if params.has("download_file"):
		http.download_file = str(params["download_file"])
	add_child_with_undo(parent, http, root, "MCP: HTTPRequest")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(http)),
		"hint": "connect request_completed; call request(url) from script or execute_editor_script",
	})


func _create_encrypted_save_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/encrypted_save_manager.gd")
	var content := """extends Node
## MCP encrypted save — FileAccess open_encrypted_with_pass (AES).
## password from game settings / user input — never hardcode production secrets.

signal save_completed(slot: String)
signal load_completed(slot: String, data: Dictionary)

const SAVE_DIR := "user://saves_enc"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".bin")

func save_game(data: Dictionary, password: String, slot: String = "slot0") -> Error:
	if password.is_empty():
		return ERR_INVALID_PARAMETER
	var path := _slot_path(slot)
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, password)
	if f == null:
		return FileAccess.get_open_error()
	var payload := {"v": 1, "t": Time.get_unix_time_from_system(), "data": data}
	f.store_string(JSON.stringify(payload))
	f.close()
	save_completed.emit(slot)
	return OK

func load_game(password: String, slot: String = "slot0") -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, password)
	if f == null:
		return {"error": "bad_password_or_file"}
	var text := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(text) != OK:
		return {"error": "parse"}
	var root: Variant = j.data
	if root is Dictionary and root.has("data"):
		load_completed.emit(slot, root["data"])
		return root["data"]
	return root if root is Dictionary else {}
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var added := maybe_add_autoload(params, path, "EncryptedSave")
	return success({"path": path, "autoload_added": added})


func _encrypted_file_write(params: Dictionary) -> Dictionary:
	var path_r := require_string(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var pass_r := require_string(params, "password")
	if pass_r[1] != null:
		return pass_r[1]
	var path: String = path_r[0]
	if not path.begins_with("user://") and not path.begins_with("res://"):
		path = "user://" + path.trim_prefix("/")
	if path.begins_with("res://") and not optional_bool(params, "allow_res", false):
		return error_invalid_params("Refuse encrypted write to res:// unless allow_res=true (prefer user://)")
	var text: String = optional_string(params, "text", "")
	if params.has("data"):
		text = JSON.stringify(params["data"])
	if text.is_empty():
		return error_invalid_params("text or data required")
	ensure_parent_dir(path)
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, pass_r[0])
	if f == null:
		return error_internal("open_encrypted failed: %s" % error_string(FileAccess.get_open_error()))
	f.store_string(text)
	f.close()
	return success({"path": path, "bytes": text.length()})


func _encrypted_file_read(params: Dictionary) -> Dictionary:
	var path_r := require_string(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var pass_r := require_string(params, "password")
	if pass_r[1] != null:
		return pass_r[1]
	var path: String = path_r[0]
	if not path.begins_with("user://") and not path.begins_with("res://"):
		path = "user://" + path.trim_prefix("/")
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, pass_r[0])
	if f == null:
		return error_internal("Decrypt/open failed (wrong password?)")
	var text := f.get_as_text()
	f.close()
	var parsed = null
	var j := JSON.new()
	if j.parse(text) == OK:
		parsed = j.data
	return success({"path": path, "text": text if optional_bool(params, "include_text", true) else "", "json": parsed})
