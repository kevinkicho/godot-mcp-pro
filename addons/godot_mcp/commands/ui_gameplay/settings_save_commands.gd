@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Settings menu + save slot UI systems for modern game shells.


func get_commands() -> Dictionary:
	return {
		"create_settings_resource_script": _create_settings_resource_script,
		"create_settings_manager_script": _create_settings_manager_script,
		"setup_settings_menu": _setup_settings_menu,
		"setup_save_slot_menu": _setup_save_slot_menu,
		"create_enhanced_save_manager_script": _create_enhanced_save_manager,
		"create_encrypted_save_manager_script": _create_encrypted_save_manager,
		"list_settings_save_recipes": _list_recipes,
	}


func _list_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"flow_settings": [
			"create_settings_manager_script (autoload)",
			"setup_settings_menu on options scene",
		],
		"flow_save": [
			"create_enhanced_save_manager_script (or create_save_manager_script)",
			"create_encrypted_save_manager_script for FileAccess encrypted stores",
			"setup_save_slot_menu",
		],
	})



func _create_settings_resource_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/game_settings.gd")
	var content := """extends Resource
## MCP GameSettings resource - volume, graphics, accessibility.
class_name GameSettings

@export var master_volume: float = 1.0
@export var music_volume: float = 0.8
@export var sfx_volume: float = 1.0
@export var fullscreen: bool = false
@export var vsync: bool = true
@export var locale: String = "en"
@export var mouse_sensitivity: float = 1.0
@export var show_subtitles: bool = true
@export var extra: Dictionary = {}
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "class_name": "GameSettings"})


func _create_settings_manager_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/settings_manager.gd")
	var content := """extends Node
## MCP SettingsManager autoload - load/save user://settings.cfg and apply audio/window.

signal settings_changed

const PATH := "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var fullscreen: bool = false
var vsync: bool = true
var locale: String = "en"
var mouse_sensitivity: float = 1.0
var show_subtitles: bool = true

func _ready() -> void:
	load_settings()
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	locale = str(cfg.get_value("game", "locale", locale))
	mouse_sensitivity = float(cfg.get_value("game", "mouse_sensitivity", mouse_sensitivity))
	show_subtitles = bool(cfg.get_value("game", "subtitles", show_subtitles))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("game", "locale", locale)
	cfg.set_value("game", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("game", "subtitles", show_subtitles)
	cfg.save(PATH)
	settings_changed.emit()

func apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	var mi := AudioServer.get_bus_index("Music")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, linear_to_db(music_volume))
	var si := AudioServer.get_bus_index("SFX")
	if si >= 0:
		AudioServer.set_bus_volume_db(si, linear_to_db(sfx_volume))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	if locale != "":
		TranslationServer.set_locale(locale)
	settings_changed.emit()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply()
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", true):
		var aname := optional_string(params, "autoload_name", "SettingsManager")
		# force add_autoload path via ensure_autoload
		al = ensure_autoload(aname, w["path"], true)
	return success({"path": w["path"], "autoload_added": al})


func _setup_settings_menu(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found(parent_path)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "SettingsMenu")
	layer.layer = optional_int(params, "layer", 50)
	add_child_with_undo(parent, layer, root, "MCP: Settings menu")

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child_with_undo(layer, center, root, "MCP: settings center")

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(400, 360)
	add_child_with_undo(center, panel, root, "MCP: settings panel")

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: settings vbox")

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_with_undo(vbox, title, root, "MCP: title")

	for item in [
		["MasterLabel", "Master Volume"],
		["MasterSlider", "HSlider"],
		["MusicLabel", "Music Volume"],
		["MusicSlider", "HSlider"],
		["SfxLabel", "SFX Volume"],
		["SfxSlider", "HSlider"],
	]:
		if item[1] == "HSlider":
			var s := HSlider.new()
			s.name = item[0]
			s.min_value = 0
			s.max_value = 1
			s.step = 0.01
			s.value = 1
			s.custom_minimum_size = Vector2(280, 16)
			add_child_with_undo(vbox, s, root, "MCP: " + item[0])
		else:
			var l := Label.new()
			l.name = item[0]
			l.text = item[1]
			add_child_with_undo(vbox, l, root, "MCP: " + item[0])

	var fs := CheckBox.new()
	fs.name = "FullscreenCheck"
	fs.text = "Fullscreen"
	add_child_with_undo(vbox, fs, root, "MCP: fs")

	var vs := CheckBox.new()
	vs.name = "VsyncCheck"
	vs.text = "VSync"
	vs.button_pressed = true
	add_child_with_undo(vbox, vs, root, "MCP: vsync")

	var apply_btn := Button.new()
	apply_btn.name = "ApplyButton"
	apply_btn.text = "Apply & Save"
	add_child_with_undo(vbox, apply_btn, root, "MCP: apply")

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back"
	add_child_with_undo(vbox, back_btn, root, "MCP: back")

	var sp: String = optional_string(params, "script_path", "res://scripts/settings_menu_ui.gd")
	var scr := """extends CanvasLayer
## MCP settings menu UI - binds to SettingsManager autoload.

@onready var master_s: HSlider = $Center/Panel/VBox/MasterSlider
@onready var music_s: HSlider = $Center/Panel/VBox/MusicSlider
@onready var sfx_s: HSlider = $Center/Panel/VBox/SfxSlider
@onready var fs: CheckBox = $Center/Panel/VBox/FullscreenCheck
@onready var vs: CheckBox = $Center/Panel/VBox/VsyncCheck
@onready var apply_btn: Button = $Center/Panel/VBox/ApplyButton
@onready var back_btn: Button = $Center/Panel/VBox/BackButton

func _ready() -> void:
	apply_btn.pressed.connect(_on_apply)
	back_btn.pressed.connect(func(): visible = false)
	_load_from_manager()

func _load_from_manager() -> void:
	if not has_node("/root/SettingsManager"):
		return
	var sm := get_node("/root/SettingsManager")
	master_s.value = sm.master_volume
	music_s.value = sm.music_volume
	sfx_s.value = sm.sfx_volume
	fs.button_pressed = sm.fullscreen
	vs.button_pressed = sm.vsync

func _on_apply() -> void:
	if not has_node("/root/SettingsManager"):
		return
	var sm := get_node("/root/SettingsManager")
	sm.master_volume = master_s.value
	sm.music_volume = music_s.value
	sm.sfx_volume = sfx_s.value
	sm.fullscreen = fs.button_pressed
	sm.vsync = vs.button_pressed
	sm.apply()
	sm.save_settings()
"""
	write_script_file(sp, scr, true)
	var s = load(sp)
	if s:
		layer.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(layer)), "script_path": sp})


func _create_enhanced_save_manager(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/save_manager_enhanced.gd")
	var content := """extends Node
## MCP enhanced SaveManager - multi-slot metadata, autosave, screenshot thumb optional.

signal save_completed(slot: String)
signal load_completed(slot: String, data: Dictionary)

const SAVE_DIR := "user://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")

func _meta_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".meta.json")

func save_game(data: Dictionary, slot: String = "slot0", meta: Dictionary = {}) -> Error:
	var path := _slot_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_CREATE
	var payload := {
		"version": 2,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data,
	}
	f.store_string(JSON.stringify(payload, "\\t"))
	f.close()
	var m := {
		"slot": slot,
		"timestamp": payload["timestamp"],
		"title": meta.get("title", slot),
		"playtime_sec": meta.get("playtime_sec", 0),
		"level": meta.get("level", ""),
		"screenshot_path": meta.get("screenshot_path", ""),
	}
	var mf := FileAccess.open(_meta_path(slot), FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(m, "\\t"))
		mf.close()
	save_completed.emit(slot)
	return OK

func load_game(slot: String = "slot0") -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed.get("data", {})
	load_completed.emit(slot, data)
	return data

func has_save(slot: String = "slot0") -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func delete_save(slot: String) -> void:
	var p := _slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var m := _meta_path(slot)
	if FileAccess.file_exists(m):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(m))

func list_slots() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while not n.is_empty():
		if n.ends_with(".meta.json"):
			var mf := FileAccess.open(SAVE_DIR.path_join(n), FileAccess.READ)
			var meta = JSON.parse_string(mf.get_as_text()) if mf else {}
			mf.close() if mf else null
			if meta is Dictionary:
				out.append(meta)
		elif n.ends_with(".json") and not n.ends_with(".meta.json"):
			var base := n.get_basename()
			if not FileAccess.file_exists(_meta_path(base)):
				out.append({"slot": base, "title": base, "timestamp": 0})
		n = dir.get_next()
	dir.list_dir_end()
	return out

func autosave(data: Dictionary, meta: Dictionary = {}) -> Error:
	meta["title"] = meta.get("title", "Autosave")
	return save_game(data, "autosave", meta)
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", true):
		var aname := optional_string(params, "autoload_name", "SaveManager")
		al = ensure_autoload(aname, w["path"], true)
	return success({"path": w["path"], "autoload_added": al})


func _create_encrypted_save_manager(params: Dictionary) -> Dictionary:
	## FileAccess encrypted user saves (AES via password). Project-neutral scaffold.
	var path: String = optional_string(params, "path", "res://scripts/encrypted_save_manager.gd")
	var content := """extends Node
## MCP EncryptedSaveManager - FileAccess open_encrypted_with_pass on user://saves.
signal save_completed(slot: String)
signal load_completed(slot: String, data: Dictionary)

const SAVE_DIR := "user://saves"
@export var password: String = "change-me-in-project-settings"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if ProjectSettings.has_setting("mcp/save_password"):
		password = str(ProjectSettings.get_setting("mcp/save_password"))

func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".esav")

func save_game(data: Dictionary, slot: String = "slot0") -> Error:
	var p := _slot_path(slot)
	var f := FileAccess.open_encrypted_with_pass(p, FileAccess.WRITE, password)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data))
	f.close()
	save_completed.emit(slot)
	return OK

func load_game(slot: String = "slot0") -> Dictionary:
	var p := _slot_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open_encrypted_with_pass(p, FileAccess.READ, password)
	if f == null:
		push_error("Encrypted load failed: %s" % error_string(FileAccess.get_open_error()))
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	var data: Dictionary = parsed if parsed is Dictionary else {}
	load_completed.emit(slot, data)
	return data

func has_save(slot: String = "slot0") -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func delete_save(slot: String) -> void:
	var p := _slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func list_slots() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while not n.is_empty():
		if n.ends_with(".esav"):
			out.append(n.get_basename())
		n = dir.get_next()
	dir.list_dir_end()
	return out
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", true):
		al = ensure_autoload(optional_string(params, "autoload_name", "SaveManager"), w.get("path", path), true)
	if optional_bool(params, "set_project_password", false):
		var pw: String = optional_string(params, "password", "change-me")
		ProjectSettings.set_setting("mcp/save_password", pw)
		ProjectSettings.save()
	return success({
		"path": w.get("path", path),
		"autoload_added": al,
		"hint": "Set password via mcp/save_password project setting or @export; not cloud-backed",
	})


func _setup_save_slot_menu(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found(parent_path)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "SaveSlotMenu")
	layer.layer = optional_int(params, "layer", 40)
	add_child_with_undo(parent, layer, root, "MCP: Save slots")

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child_with_undo(layer, center, root, "MCP: center")

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(420, 320)
	add_child_with_undo(center, panel, root, "MCP: panel")

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: vbox")

	var title := Label.new()
	title.name = "Title"
	title.text = "Save / Load"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_with_undo(vbox, title, root, "MCP: title")

	var list := ItemList.new()
	list.name = "SlotList"
	list.custom_minimum_size = Vector2(0, 180)
	add_child_with_undo(vbox, list, root, "MCP: list")

	var hbox := HBoxContainer.new()
	hbox.name = "Buttons"
	add_child_with_undo(vbox, hbox, root, "MCP: buttons")

	for bn in ["SaveButton", "LoadButton", "DeleteButton", "CloseButton"]:
		var b := Button.new()
		b.name = bn
		b.text = bn.replace("Button", "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child_with_undo(hbox, b, root, "MCP: " + bn)

	var sp: String = optional_string(params, "script_path", "res://scripts/save_slot_menu.gd")
	var scr := """extends CanvasLayer
## MCP save slot menu - uses SaveManager autoload.

signal save_requested(slot: String)
signal load_requested(slot: String)

@onready var slot_list: ItemList = $Center/Panel/VBox/SlotList
@onready var save_btn: Button = $Center/Panel/VBox/Buttons/SaveButton
@onready var load_btn: Button = $Center/Panel/VBox/Buttons/LoadButton
@onready var delete_btn: Button = $Center/Panel/VBox/Buttons/DeleteButton
@onready var close_btn: Button = $Center/Panel/VBox/Buttons/CloseButton

var _slots: Array = []

func _ready() -> void:
	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	delete_btn.pressed.connect(_on_delete)
	close_btn.pressed.connect(func(): visible = false)
	refresh()

func refresh() -> void:
	slot_list.clear()
	_slots.clear()
	var known: Dictionary = {}
	if has_node("/root/SaveManager") and get_node("/root/SaveManager").has_method("list_slots"):
		for m in get_node("/root/SaveManager").list_slots():
			if m is Dictionary:
				known[str(m.get("slot", ""))] = m
	for i in 3:
		var sid := "slot%d" % i
		if known.has(sid):
			_slots.append(known[sid])
		else:
			_slots.append({"slot": sid, "title": "Empty Slot %d" % (i + 1), "timestamp": 0})
	for m2 in _slots:
		var ts := int(m2.get("timestamp", 0))
		var label := str(m2.get("title", m2.get("slot", "?")))
		if ts > 0:
			label += " - " + Time.get_datetime_string_from_unix_time(ts)
		slot_list.add_item(label)

func _selected_slot() -> String:
	var i := slot_list.get_selected_items()
	if i.is_empty():
		return "slot0"
	return str(_slots[i[0]].get("slot", "slot0"))

func _on_save() -> void:
	var slot := _selected_slot()
	save_requested.emit(slot)
	# Caller should provide data; if GameState exists, try default
	if has_node("/root/SaveManager") and has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		var data := {"score": gs.get("score") if "score" in gs else 0, "flags": gs.get("flags") if "flags" in gs else {}}
		get_node("/root/SaveManager").save_game(data, slot, {"title": "Slot " + slot})
		refresh()

func _on_load() -> void:
	var slot := _selected_slot()
	load_requested.emit(slot)
	if has_node("/root/SaveManager"):
		var data: Dictionary = get_node("/root/SaveManager").load_game(slot)
		if has_node("/root/GameState") and data:
			var gs := get_node("/root/GameState")
			if data.has("score") and "score" in gs:
				gs.score = int(data["score"])
			if data.has("flags") and "flags" in gs:
				gs.flags = data["flags"]

func _on_delete() -> void:
	var slot := _selected_slot()
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").delete_save(slot)
		refresh()
"""
	write_script_file(sp, scr, true)
	var s = load(sp)
	if s:
		layer.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(layer)), "script_path": sp})
