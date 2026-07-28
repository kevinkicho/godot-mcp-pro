@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Game UI systems: HUD, pause menu, inventory grid, dialogue box, game state.


func get_commands() -> Dictionary:
	return {
		"setup_hud": _setup_hud,
		"setup_pause_menu": _setup_pause_menu,
		"setup_inventory_ui": _setup_inventory_ui,
		"setup_dialogue_box_ui": _setup_dialogue_box_ui,
		"create_game_state_script": _create_game_state_script,
		"create_audio_manager_script": _create_audio_manager_script,
		"set_scene_tree_paused": _set_scene_tree_paused,
		"list_game_ui_templates": _list_game_ui_templates,
	}


func _list_game_ui_templates(_params: Dictionary) -> Dictionary:
	return success({
		"templates": [
			{"id": "hud", "tool": "setup_hud"},
			{"id": "pause", "tool": "setup_pause_menu"},
			{"id": "inventory", "tool": "setup_inventory_ui"},
			{"id": "dialogue", "tool": "setup_dialogue_box_ui"},
			{"id": "game_state", "tool": "create_game_state_script"},
			{"id": "audio_manager", "tool": "create_audio_manager_script"},
		],
	})


func _write_script(path: String, content: String, overwrite: bool) -> Dictionary:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return {"path": path}


func _setup_hud(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "HUD")
	layer.layer = optional_int(params, "layer", 10)
	add_child_with_undo(parent, layer, root, "MCP: HUD layer")

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["theme_override_constants/margin_left", "theme_override_constants/margin_top",
			"theme_override_constants/margin_right", "theme_override_constants/margin_bottom"]:
		margin.set(side, 16)
	add_child_with_undo(layer, margin, root, "MCP: HUD margin")

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(margin, vbox, root, "MCP: HUD vbox")

	var health_label := Label.new()
	health_label.name = "HealthLabel"
	health_label.text = optional_string(params, "health_text", "HP: 100")
	add_child_with_undo(vbox, health_label, root, "MCP: HUD health")

	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.min_value = 0
	bar.max_value = float(params.get("max_health", 100))
	bar.value = bar.max_value
	bar.custom_minimum_size = Vector2(200, 16)
	add_child_with_undo(vbox, bar, root, "MCP: HUD bar")

	var score := Label.new()
	score.name = "ScoreLabel"
	score.text = optional_string(params, "score_text", "Score: 0")
	add_child_with_undo(vbox, score, root, "MCP: HUD score")

	# Bind script for health_changed
	if optional_bool(params, "attach_script", true):
		var sp: String = optional_string(params, "script_path", "res://scripts/hud.gd")
		var scr := """extends CanvasLayer
## MCP HUD — call set_health / set_score from gameplay.

@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var health_bar: ProgressBar = $Margin/VBox/HealthBar
@onready var score_label: Label = $Margin/VBox/ScoreLabel

func set_health(current: float, maximum: float = -1.0) -> void:
	if maximum > 0.0:
		health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP: %d" % int(current)

func set_score(score: int) -> void:
	score_label.text = "Score: %d" % score

func _on_health_changed(current: float, maximum: float) -> void:
	set_health(current, maximum)
"""
		var w := _write_script(sp, scr, optional_bool(params, "overwrite", true))
		if w.has("path"):
			var s = load(w["path"])
			if s:
				layer.set_script(s)

	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(layer)),
		"children": ["HealthLabel", "HealthBar", "ScoreLabel"],
	})


func _setup_pause_menu(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "PauseMenu")
	layer.layer = optional_int(params, "layer", 100)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_with_undo(parent, layer, root, "MCP: Pause menu layer")

	var panel := ColorRect.new()
	panel.name = "Dimmer"
	panel.color = Color(0, 0, 0, 0.55)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_with_undo(layer, panel, root, "MCP: Pause dimmer")

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child_with_undo(panel, center, root, "MCP: Pause center")

	var vbox := VBoxContainer.new()
	vbox.name = "Buttons"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child_with_undo(center, vbox, root, "MCP: Pause buttons")

	var title := Label.new()
	title.name = "Title"
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_with_undo(vbox, title, root, "MCP: Pause title")

	for btn_name in ["ResumeButton", "QuitButton"]:
		var b := Button.new()
		b.name = btn_name
		b.text = "Resume" if btn_name == "ResumeButton" else "Quit to Desktop"
		b.custom_minimum_size = Vector2(200, 36)
		add_child_with_undo(vbox, b, root, "MCP: Pause " + btn_name)

	var sp: String = optional_string(params, "script_path", "res://scripts/pause_menu.gd")
	var scr := """extends CanvasLayer
## MCP pause menu — toggle with pause action or Escape.

@onready var dimmer: ColorRect = $Dimmer
@onready var resume_btn: Button = $Dimmer/Center/Buttons/ResumeButton
@onready var quit_btn: Button = $Dimmer/Center/Buttons/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	dimmer.visible = false
	resume_btn.pressed.connect(unpause)
	quit_btn.pressed.connect(func(): get_tree().quit())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if dimmer.visible:
			unpause()
		else:
			pause()
		get_viewport().set_input_as_handled()

func pause() -> void:
	dimmer.visible = true
	get_tree().paused = true

func unpause() -> void:
	dimmer.visible = false
	get_tree().paused = false
"""
	var w := _write_script(sp, scr, optional_bool(params, "overwrite", true))
	if w.has("path"):
		var s = load(w["path"])
		if s:
			layer.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(layer)), "action": "pause"})


func _setup_inventory_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var cols: int = optional_int(params, "columns", 4)
	var slots: int = optional_int(params, "slots", 16)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "InventoryUI")
	layer.layer = optional_int(params, "layer", 20)
	add_child_with_undo(parent, layer, root, "MCP: Inventory layer")

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(cols * 72 + 24, ceili(float(slots) / cols) * 72 + 48)
	add_child_with_undo(layer, panel, root, "MCP: Inventory panel")

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: Inventory vbox")

	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_with_undo(vbox, title, root, "MCP: Inventory title")

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = cols
	add_child_with_undo(vbox, grid, root, "MCP: Inventory grid")

	for i in range(slots):
		var slot := Panel.new()
		slot.name = "Slot%d" % i
		slot.custom_minimum_size = Vector2(64, 64)
		add_child_with_undo(grid, slot, root, "MCP: Inventory slot")
		var lbl := Label.new()
		lbl.name = "Count"
		lbl.text = ""
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		add_child_with_undo(slot, lbl, root, "MCP: slot label")

	var sp: String = optional_string(params, "script_path", "res://scripts/inventory_ui.gd")
	var scr := """extends CanvasLayer
## MCP inventory UI — toggle with 'inventory' action or I key fallback.

signal item_clicked(slot_index: int)

@onready var panel: PanelContainer = $Panel
@onready var grid: GridContainer = $Panel/VBox/Grid

var items: Array = []  # [{id, name, count, icon_path?}, ...]

func _ready() -> void:
	items.resize(grid.get_child_count())
	for i in range(items.size()):
		items[i] = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_I):
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func set_item(slot: int, id: String, item_name: String, count: int = 1) -> void:
	if slot < 0 or slot >= items.size():
		return
	items[slot] = {"id": id, "name": item_name, "count": count}
	_refresh_slot(slot)

func clear_slot(slot: int) -> void:
	if slot < 0 or slot >= items.size():
		return
	items[slot] = null
	_refresh_slot(slot)

func _refresh_slot(slot: int) -> void:
	var node := grid.get_child(slot)
	var lbl: Label = node.get_node_or_null("Count")
	if items[slot] == null:
		if lbl: lbl.text = ""
		node.tooltip_text = ""
	else:
		if lbl: lbl.text = str(items[slot].get("count", 1))
		node.tooltip_text = str(items[slot].get("name", ""))
"""
	var w := _write_script(sp, scr, optional_bool(params, "overwrite", true))
	if w.has("path"):
		var s = load(w["path"])
		if s:
			layer.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(layer)), "slots": slots, "columns": cols})


func _setup_dialogue_box_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "DialogueBox")
	layer.layer = optional_int(params, "layer", 50)
	add_child_with_undo(parent, layer, root, "MCP: Dialogue layer")

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -180
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_bottom = -24
	add_child_with_undo(layer, panel, root, "MCP: Dialogue panel")

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: Dialogue vbox")

	var speaker := Label.new()
	speaker.name = "Speaker"
	speaker.text = "NPC"
	add_child_with_undo(vbox, speaker, root, "MCP: Speaker")

	var body := RichTextLabel.new()
	body.name = "Body"
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(0, 80)
	body.text = "..."
	add_child_with_undo(vbox, body, root, "MCP: Body")

	var next_btn := Button.new()
	next_btn.name = "NextButton"
	next_btn.text = "Continue"
	add_child_with_undo(vbox, next_btn, root, "MCP: Next")

	var sp: String = optional_string(params, "script_path", "res://scripts/dialogue_box.gd")
	var scr := """extends CanvasLayer
## MCP dialogue box — show_lines([{speaker, text}, ...])

signal dialogue_finished

@onready var panel: PanelContainer = $Panel
@onready var speaker_lbl: Label = $Panel/VBox/Speaker
@onready var body_lbl: RichTextLabel = $Panel/VBox/Body
@onready var next_btn: Button = $Panel/VBox/NextButton

var _lines: Array = []
var _i: int = 0

func _ready() -> void:
	next_btn.pressed.connect(advance)
	panel.visible = false

func show_lines(lines: Array) -> void:
	_lines = lines
	_i = 0
	panel.visible = true
	_show_current()

func advance() -> void:
	_i += 1
	if _i >= _lines.size():
		panel.visible = false
		dialogue_finished.emit()
	else:
		_show_current()

func _show_current() -> void:
	var line = _lines[_i]
	if line is Dictionary:
		speaker_lbl.text = str(line.get("speaker", ""))
		body_lbl.text = str(line.get("text", ""))
	else:
		speaker_lbl.text = ""
		body_lbl.text = str(line)

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		advance()
		get_viewport().set_input_as_handled()
"""
	var w := _write_script(sp, scr, optional_bool(params, "overwrite", true))
	if w.has("path"):
		var s = load(w["path"])
		if s:
			layer.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(layer))})


func _create_game_state_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/game_state.gd")
	var content := """extends Node
## MCP GameState autoload — score, flags, pause helpers.

signal score_changed(score: int)
signal flag_changed(key: String, value: Variant)

var score: int = 0
var flags: Dictionary = {}

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	flag_changed.emit(key, value)

func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)

func pause_game() -> void:
	get_tree().paused = true

func resume_game() -> void:
	get_tree().paused = false

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
"""
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", true):
		var aname: String = optional_string(params, "autoload_name", "GameState")
		var p: String = w.get("path", path)
		if not ProjectSettings.has_setting("autoload/" + aname):
			ProjectSettings.set_setting("autoload/" + aname, "*" + p)
			ProjectSettings.save()
			al = true
	return success({"path": w.get("path", path), "autoload_added": al})


func _create_audio_manager_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/audio_manager.gd")
	var content := """extends Node
## MCP AudioManager autoload — SFX oneshots + music crossfade on Music bus.

@export var sfx_bus: String = "SFX"
@export var music_bus: String = "Music"

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _using_a: bool = true

func _ready() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_music_a.bus = music_bus
	_music_b.bus = music_bus
	add_child(_music_a)
	add_child(_music_b)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = sfx_bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func play_sfx_path(path: String, volume_db: float = 0.0) -> void:
	if ResourceLoader.exists(path):
		play_sfx(load(path) as AudioStream, volume_db)

func play_music(stream: AudioStream, fade_sec: float = 0.8) -> void:
	var incoming := _music_b if _using_a else _music_a
	var outgoing := _music_a if _using_a else _music_b
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween()
	tw.tween_property(incoming, "volume_db", 0.0, fade_sec)
	tw.parallel().tween_property(outgoing, "volume_db", -40.0, fade_sec)
	tw.tween_callback(func():
		outgoing.stop()
		_using_a = not _using_a
	)

func stop_music(fade_sec: float = 0.5) -> void:
	var cur := _music_a if _using_a else _music_b
	var tw := create_tween()
	tw.tween_property(cur, "volume_db", -40.0, fade_sec)
	tw.tween_callback(cur.stop)
"""
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", true):
		var aname: String = optional_string(params, "autoload_name", "AudioManager")
		var p: String = w.get("path", path)
		if not ProjectSettings.has_setting("autoload/" + aname):
			ProjectSettings.set_setting("autoload/" + aname, "*" + p)
			ProjectSettings.save()
			al = true
	# Ensure SFX/Music buses exist
	var buses_added: Array = []
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			buses_added.append(bus_name)
	return success({"path": w.get("path", path), "autoload_added": al, "buses_added": buses_added})


func _set_scene_tree_paused(params: Dictionary) -> Dictionary:
	## Editor-side note: pausing only applies while playing.
	if not EditorInterface.is_playing_scene():
		return error(-32000, "No scene playing — play_scene first", {})
	var paused: bool = optional_bool(params, "paused", true)
	# Runtime pause via game command if available
	var res: Dictionary = await send_game_command("execute_script", {
		"code": "get_tree().paused = %s" % ("true" if paused else "false"),
	}, 5.0)
	return success({"paused": paused, "game": res.get("result", res)})
