@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Cloud save templates, settings UX pack, accessibility - ship-loop polish for agents.


func get_commands() -> Dictionary:
	return {
		"create_cloud_save_provider_script": _cloud_provider,
		"create_settings_menu_controller_script": _settings_menu,
		"setup_settings_menu_ui": _setup_settings_ui,
		"create_accessibility_settings_script": _a11y_script,
		"apply_accessibility_project_defaults": _a11y_defaults,
		"create_save_cloud_sync_script": _cloud_sync,
		"list_cloud_settings_accessibility_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"write_save_slot_json", "create_encrypted_save_manager_script", "create_game_state_serializer_script",
		"setup_pause_menu", "create_game_flow_controller_script",
	], {
		"flow": [
			"create_settings_menu_controller_script + setup_settings_menu_ui",
			"create_accessibility_settings_script add_autoload",
			"create_cloud_save_provider_script (stub/provider interface)",
			"create_save_cloud_sync_script to wrap local slots",
		],
	})


func _cloud_provider(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/cloud_save_provider.gd")
	var provider: String = optional_string(params, "provider", "stub")
	var content := """extends Node
class_name CloudSaveProvider
## Provider-neutral cloud save interface. Swap backends without rewriting game code.
## provider modes: stub (local only), http (REST), custom.

signal upload_finished(slot: String, ok: bool)
signal download_finished(slot: String, data: Dictionary, ok: bool)

@export var provider: String = \"%s\"
@export var endpoint: String = \"https://example.com/api/saves\"
@export var api_key: String = \"\"
@export var local_fallback: bool = true

func upload_slot(slot: String, data: Dictionary) -> void:
	match provider:
		\"http\":
			await _http_upload(slot, data)
		_:
			if local_fallback:
				_local_write(slot, data)
			upload_finished.emit(slot, true)

func download_slot(slot: String) -> void:
	match provider:
		\"http\":
			await _http_download(slot)
		_:
			var d := _local_read(slot)
			download_finished.emit(slot, d, not d.is_empty())

func list_remote_slots() -> Array:
	# Stub: mirror local user://saves
	return _local_list()

func _local_dir() -> String:
	return \"user://saves\"

func _local_path(slot: String) -> String:
	return _local_dir().path_join(\"slot_%%s.json\" %% slot)

func _local_write(slot: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_local_dir())
	var f := FileAccess.open(_local_path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({\"data\": data, \"ts\": Time.get_unix_time_from_system()}, \"\\t\"))

func _local_read(slot: String) -> Dictionary:
	var p := _local_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed.get(\"data\", parsed)
	return {}

func _local_list() -> Array:
	var out: Array = []
	var dir := DirAccess.open(_local_dir())
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != \"\":
		if n.begins_with(\"slot_\") and n.ends_with(\".json\"):
			out.append(n.trim_prefix(\"slot_\").trim_suffix(\".json\"))
		n = dir.get_next()
	return out

func _http_upload(slot: String, data: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray([\"Content-Type: application/json\"])
	if not api_key.is_empty():
		headers.append(\"Authorization: Bearer %%s\" %% api_key)
	var body := JSON.stringify({\"slot\": slot, \"data\": data})
	var err := http.request(endpoint.path_join(slot), headers, HTTPClient.METHOD_PUT, body)
	var ok := err == OK
	if ok:
		var result = await http.request_completed
		ok = int(result[1]) >= 200 and int(result[1]) < 300
	http.queue_free()
	if local_fallback and not ok:
		_local_write(slot, data)
	upload_finished.emit(slot, ok)

func _http_download(slot: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray()
	if not api_key.is_empty():
		headers.append(\"Authorization: Bearer %%s\" %% api_key)
	var err := http.request(endpoint.path_join(slot), headers, HTTPClient.METHOD_GET)
	var data := {}
	var ok := err == OK
	if ok:
		var result = await http.request_completed
		ok = int(result[1]) >= 200 and int(result[1]) < 300
		if ok:
			var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			if parsed is Dictionary:
				data = parsed.get(\"data\", parsed)
	http.queue_free()
	if not ok and local_fallback:
		data = _local_read(slot)
		ok = not data.is_empty()
	download_finished.emit(slot, data, ok)
""" % provider
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	if optional_bool(params, "add_autoload", false):
		maybe_add_autoload(params, path, "CloudSave")
	return success({"path": path, "provider": provider, "class_name": "CloudSaveProvider"})


func _cloud_sync(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/save_cloud_sync.gd")
	var content := """extends Node
class_name SaveCloudSync
## Wraps local JSON slots with optional cloud upload/download.

@export var cloud_path: NodePath
@export var auto_upload_on_save: bool = true

func save_local_and_cloud(slot: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(\"user://saves\")
	var f := FileAccess.open(\"user://saves/slot_%s.json\" % slot, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, \"\\t\"))
	if auto_upload_on_save:
		var cloud := get_node_or_null(cloud_path)
		if cloud and cloud.has_method(\"upload_slot\"):
			cloud.upload_slot(slot, data)

func load_prefer_cloud(slot: String) -> Dictionary:
	var cloud := get_node_or_null(cloud_path)
	if cloud and cloud.has_method(\"download_slot\"):
		cloud.download_slot(slot)
		# Caller should await download_finished; sync helper returns local immediately
	var p := \"user://saves/slot_%s.json\" % slot
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			return parsed
	return {}
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "SaveCloudSync"})


func _settings_menu(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/settings_menu_controller.gd")
	var content := """extends CanvasLayer
## Settings menu: audio buses, window mode, accessibility hooks.

signal closed

@export var master_bus: StringName = &\"Master\"
@export var music_bus: StringName = &\"Music\"
@export var sfx_bus: StringName = &\"SFX\"
@export var config_path: String = \"user://settings.cfg\"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load()

func open() -> void:
	visible = true
	get_tree().paused = true

func close_menu() -> void:
	_save()
	visible = false
	get_tree().paused = false
	closed.emit()

func set_bus_volume_linear(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))

func set_fullscreen(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func set_vsync(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

func _save() -> void:
	var cfg := ConfigFile.new()
	for bus in [master_bus, music_bus, sfx_bus]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			cfg.set_value(\"audio\", str(bus), db_to_linear(AudioServer.get_bus_volume_db(idx)))
	cfg.set_value(\"video\", \"fullscreen\", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.save(config_path)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	for bus in [master_bus, music_bus, sfx_bus]:
		if cfg.has_section_key(\"audio\", str(bus)):
			set_bus_volume_linear(bus, float(cfg.get_value(\"audio\", str(bus))))
	if cfg.has_section_key(\"video\", \"fullscreen\"):
		set_fullscreen(bool(cfg.get_value(\"video\", \"fullscreen\")))
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path})


func _setup_settings_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "SettingsMenu")
	layer.layer = optional_int(params, "layer", 60)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_with_undo(parent, layer, root, "MCP: Settings")
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -180
	panel.offset_bottom = 180
	add_child_with_undo(layer, panel, root, "MCP: settings panel")
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: vbox")
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_with_undo(vbox, title, root, "MCP: title")
	for label_text in ["Master", "Music", "SFX"]:
		var row := HBoxContainer.new()
		row.name = label_text + "Row"
		add_child_with_undo(vbox, row, root, "MCP: row")
		var lab := Label.new()
		lab.text = label_text
		lab.custom_minimum_size = Vector2(80, 0)
		add_child_with_undo(row, lab, root, "MCP: lab")
		var slider := HSlider.new()
		slider.name = label_text + "Slider"
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.value = 0.8
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child_with_undo(row, slider, root, "MCP: slider")
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	add_child_with_undo(vbox, close_btn, root, "MCP: close")
	var script_path: String = optional_string(params, "script_path", "res://scripts/settings_menu_controller.gd")
	if not FileAccess.file_exists(script_path):
		_settings_menu({"path": script_path, "overwrite": false})
	var scr: Script = load(script_path)
	if scr:
		layer.set_script(scr)
	mark_current_scene_unsaved()
	return success({"layer_path": str(root.get_path_to(layer)), "panel_path": str(root.get_path_to(panel))})


func _a11y_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/accessibility_settings.gd")
	var content := """extends Node
class_name AccessibilitySettings
## Runtime accessibility toggles agents can wire to settings UI.

signal changed

@export var subtitle_scale: float = 1.0
@export var ui_scale: float = 1.0
@export var reduce_motion: bool = false
@export var screen_shake_enabled: bool = true
@export var colorblind_mode: StringName = &\"none\"  # none, protanopia, deuteranopia, tritanopia
@export var high_contrast: bool = false
@export var config_path: String = \"user://accessibility.cfg\"

func _ready() -> void:
	load_settings()
	apply()

func apply() -> void:
	get_tree().root.content_scale_factor = ui_scale
	if high_contrast:
		# Soft hint: games should listen to changed for theme swaps
		pass
	changed.emit()

func set_ui_scale(v: float) -> void:
	ui_scale = clampf(v, 0.75, 2.0)
	apply()
	save_settings()

func set_reduce_motion(v: bool) -> void:
	reduce_motion = v
	save_settings()
	changed.emit()

func set_screen_shake(v: bool) -> void:
	screen_shake_enabled = v
	save_settings()
	changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(\"a11y\", \"subtitle_scale\", subtitle_scale)
	cfg.set_value(\"a11y\", \"ui_scale\", ui_scale)
	cfg.set_value(\"a11y\", \"reduce_motion\", reduce_motion)
	cfg.set_value(\"a11y\", \"screen_shake_enabled\", screen_shake_enabled)
	cfg.set_value(\"a11y\", \"colorblind_mode\", str(colorblind_mode))
	cfg.set_value(\"a11y\", \"high_contrast\", high_contrast)
	cfg.save(config_path)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	subtitle_scale = float(cfg.get_value(\"a11y\", \"subtitle_scale\", subtitle_scale))
	ui_scale = float(cfg.get_value(\"a11y\", \"ui_scale\", ui_scale))
	reduce_motion = bool(cfg.get_value(\"a11y\", \"reduce_motion\", reduce_motion))
	screen_shake_enabled = bool(cfg.get_value(\"a11y\", \"screen_shake_enabled\", screen_shake_enabled))
	colorblind_mode = StringName(str(cfg.get_value(\"a11y\", \"colorblind_mode\", colorblind_mode)))
	high_contrast = bool(cfg.get_value(\"a11y\", \"high_contrast\", high_contrast))
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	if optional_bool(params, "add_autoload", true):
		maybe_add_autoload(params, path, "Accessibility")
	return success({"path": path, "class_name": "AccessibilitySettings"})


func _a11y_defaults(params: Dictionary) -> Dictionary:
	## Project settings defaults that help accessibility.
	var applied := {}
	if optional_bool(params, "stretch_mode", true):
		ProjectSettings.set_setting("display/window/stretch/mode", optional_string(params, "mode", "canvas_items"))
		applied["stretch/mode"] = ProjectSettings.get_setting("display/window/stretch/mode")
	if optional_bool(params, "stretch_aspect", true):
		ProjectSettings.set_setting("display/window/stretch/aspect", optional_string(params, "aspect", "expand"))
		applied["stretch/aspect"] = ProjectSettings.get_setting("display/window/stretch/aspect")
	if params.has("ui_scale"):
		# content scale factor is runtime; store recommended default in project
		ProjectSettings.set_setting("display/window/stretch/scale", float(params["ui_scale"]))
		applied["stretch/scale"] = float(params["ui_scale"])
	if optional_bool(params, "ensure_accessibility_autoload", true):
		var apath: String = optional_string(params, "script_path", "res://scripts/accessibility_settings.gd")
		if not FileAccess.file_exists(apath):
			_a11y_script({"path": apath, "overwrite": false, "add_autoload": true})
		else:
			ensure_autoload("Accessibility", apath, true)
		applied["autoload"] = "Accessibility"
	ProjectSettings.save()
	return success({"applied": applied})
