@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Remaining runtime systems - logging, achievements, day/night, feature flags, accessibility.


func get_commands() -> Dictionary:
	return {
		"create_game_logger_script": _create_logger,
		"create_achievement_manager_script": _create_achievements,
		"create_day_night_cycle_script": _create_day_night,
		"create_feature_flags_script": _create_flags,
		# create_accessibility_settings_script canonical in cloud_settings_accessibility_commands
		"create_websocket_client_script": _create_ws,
		"list_runtime_systems_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_game_state_serializer_script", "create_settings_manager_script", "pipeline_game_loop_shell"],
	})


func _create_logger(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/game_logger.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Ring-buffer game logger with levels.

signal logged(level: String, message: String)

enum Level { DEBUG, INFO, WARN, ERROR }

@export var min_level: Level = Level.DEBUG
@export var max_entries: int = 500
@export var mirror_to_print: bool = true

var _entries: Array = []

func debug(msg: String) -> void:
	_log(\"DEBUG\", msg, Level.DEBUG)

func info(msg: String) -> void:
	_log(\"INFO\", msg, Level.INFO)

func warn(msg: String) -> void:
	_log(\"WARN\", msg, Level.WARN)

func error(msg: String) -> void:
	_log(\"ERROR\", msg, Level.ERROR)

func _log(level: String, msg: String, lv: Level) -> void:
	if lv < min_level:
		return
	var entry := {\"t\": Time.get_ticks_msec(), \"level\": level, \"msg\": msg}
	_entries.append(entry)
	while _entries.size() > max_entries:
		_entries.pop_front()
	if mirror_to_print:
		print(\"[%s] %s\" % [level, msg])
	logged.emit(level, msg)

func get_entries() -> Array:
	return _entries.duplicate()

func clear() -> void:
	_entries.clear()

func dump_to_user(path: String = \"user://game.log\") -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	for e in _entries:
		f.store_line(\"%s\\t%s\\t%s\" % [e.get(\"t\", 0), e.get(\"level\", \"\"), e.get(\"msg\", \"\")])
	f.close()
	return OK
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "autoload_added": maybe_add_autoload(params, path, "Log")})


func _create_achievements(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/achievement_manager.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Local achievements - unlock + persist to user://

signal unlocked(id: StringName)

@export var save_path: String = \"user://achievements.json\"
var _defs: Dictionary = {} # id -> {title, description, secret}
var _unlocked: Dictionary = {} # id -> timestamp

func _ready() -> void:
	load_progress()

func define(id: StringName, title: String, description: String = \"\", secret: bool = false) -> void:
	_defs[id] = {\"title\": title, \"description\": description, \"secret\": secret}

func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)

func unlock(id: StringName) -> bool:
	if _unlocked.has(id):
		return false
	_unlocked[id] = Time.get_unix_time_from_system()
	unlocked.emit(id)
	save_progress()
	return true

func get_all() -> Array:
	var out: Array = []
	for id in _defs:
		out.append({
			\"id\": str(id),
			\"title\": _defs[id].get(\"title\", \"\"),
			\"description\": _defs[id].get(\"description\", \"\"),
			\"unlocked\": _unlocked.has(id),
			\"secret\": _defs[id].get(\"secret\", false),
		})
	return out

func save_progress() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({\"unlocked\": _unlocked}, \"\\t\"))
		f.close()

func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var p = JSON.parse_string(f.get_as_text())
	f.close()
	if p is Dictionary and p.has(\"unlocked\"):
		_unlocked = p[\"unlocked\"]
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "autoload_added": maybe_add_autoload(params, path, "Achievements")})


func _create_day_night(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/day_night_cycle.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Day/night cycle driving a DirectionalLight3D + optional WorldEnvironment.

signal time_changed(hour: float)

@export var light_path: NodePath
@export var environment_path: NodePath
@export var day_length_seconds: float = 120.0
@export var start_hour: float = 8.0
@export var auto_run: bool = true

var hour: float = 8.0
var _light: DirectionalLight3D
var _env: WorldEnvironment

func _ready() -> void:
	hour = start_hour
	_light = get_node_or_null(light_path) as DirectionalLight3D
	_env = get_node_or_null(environment_path) as WorldEnvironment

func _process(delta: float) -> void:
	if not auto_run:
		return
	hour = fmod(hour + (24.0 / day_length_seconds) * delta, 24.0)
	_apply()
	time_changed.emit(hour)

func set_hour(h: float) -> void:
	hour = fmod(h, 24.0)
	_apply()
	time_changed.emit(hour)

func _apply() -> void:
	# Map hour to sun angle
	var t := hour / 24.0
	var angle := t * TAU - PI * 0.5
	if _light:
		_light.rotation.x = -sin(angle) * PI * 0.45
		_light.rotation.y = cos(angle) * PI * 0.25
		var day_factor := clampf(sin(angle), 0.0, 1.0)
		_light.light_energy = lerpf(0.05, 1.2, day_factor)
		_light.light_color = Color(1, 0.95, 0.85).lerp(Color(0.2, 0.25, 0.45), 1.0 - day_factor)
	if _env and _env.environment:
		var e := _env.environment
		var day_factor2 := clampf(sin(angle), 0.0, 1.0)
		e.ambient_light_energy = lerpf(0.05, 0.4, day_factor2)
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "hint": "Attach; set light_path to DirectionalLight3D"})


func _create_flags(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/feature_flags.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Runtime feature flags (local overrides + defaults).

signal flag_changed(flag: StringName, value: bool)

@export var defaults: Dictionary = {}
var _overrides: Dictionary = {}

func is_enabled(flag: StringName, default: bool = false) -> bool:
	if _overrides.has(flag):
		return bool(_overrides[flag])
	if defaults.has(flag):
		return bool(defaults[flag])
	return default

func set_flag(flag: StringName, value: bool) -> void:
	_overrides[flag] = value
	flag_changed.emit(flag, value)

func clear_override(flag: StringName) -> void:
	_overrides.erase(flag)

func all_flags() -> Dictionary:
	var out := defaults.duplicate()
	for k in _overrides:
		out[k] = _overrides[k]
	return out
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "autoload_added": maybe_add_autoload(params, path, "Flags")})


func _create_a11y(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/accessibility_settings.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Accessibility helpers - font scale, subtitles, reduce motion, colorblind-safe palette hint.

signal changed

@export var font_scale: float = 1.0:
	set(v):
		font_scale = clampf(v, 0.75, 2.0)
		_apply()
@export var subtitles_enabled: bool = true
@export var reduce_motion: bool = false
@export var screen_reader_hints: bool = false

func _apply() -> void:
	# Scale default theme font sizes if present
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		theme = ThemeDB.get_default_theme()
	changed.emit()

func set_font_scale(v: float) -> void:
	font_scale = v

func to_dict() -> Dictionary:
	return {
		\"font_scale\": font_scale,
		\"subtitles_enabled\": subtitles_enabled,
		\"reduce_motion\": reduce_motion,
		\"screen_reader_hints\": screen_reader_hints,
	}

func from_dict(d: Dictionary) -> void:
	font_scale = float(d.get(\"font_scale\", 1.0))
	subtitles_enabled = bool(d.get(\"subtitles_enabled\", true))
	reduce_motion = bool(d.get(\"reduce_motion\", false))
	screen_reader_hints = bool(d.get(\"screen_reader_hints\", false))
	_apply()
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "autoload_added": maybe_add_autoload(params, path, "A11y")})


func _create_ws(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/websocket_client.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## WebSocket client helper (non-multiplayer API peer).

signal connected
signal disconnected
signal message_received(text: String)
signal binary_received(data: PackedByteArray)

@export var url: String = \"ws://127.0.0.1:8080\"
var _peer: WebSocketPeer = WebSocketPeer.new()
var _active: bool = false

func connect_to_url(p_url: String = \"\") -> Error:
	if not p_url.is_empty():
		url = p_url
	var err := _peer.connect_to_url(url)
	_active = err == OK
	return err

func disconnect_from_host() -> void:
	_peer.close()
	_active = false
	disconnected.emit()

func send_text(text: String) -> Error:
	return _peer.send_text(text)

func _process(_delta: float) -> void:
	if not _active:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _peer.get_available_packet_count() > 0:
			var pkt := _peer.get_packet()
			if _peer.was_string_packet():
				message_received.emit(pkt.get_string_from_utf8())
			else:
				binary_received.emit(pkt)
	elif state == WebSocketPeer.STATE_CLOSED:
		_active = false
		disconnected.emit()
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "api": ["connect_to_url", "send_text", "disconnect_from_host"]})
