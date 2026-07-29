@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Touch / mobile input - virtual joystick, touch buttons, gesture helpers.


func get_commands() -> Dictionary:
	return {
		"create_virtual_joystick_script": _create_joystick,
		"setup_virtual_joystick_ui": _setup_joystick_ui,
		"create_touch_button_script": _create_touch_btn,
		"setup_mobile_touch_controls": _setup_mobile_pack,
		"create_swipe_gesture_script": _create_swipe,
		"list_touch_input_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"create_input_map_preset", "create_joypad_input_map_preset", "setup_hud",
		"create_platformer_controller_script", "create_topdown_controller_script",
	])


func _create_joystick(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/virtual_joystick.gd")
	var content := """extends Control
class_name VirtualJoystick
## On-screen stick writing to Input actions or exposing vector.

signal direction_changed(dir: Vector2)

@export var action_left: StringName = &\"ui_left\"
@export var action_right: StringName = &\"ui_right\"
@export var action_up: StringName = &\"ui_up\"
@export var action_down: StringName = &\"ui_down\"
@export var use_actions: bool = true
@export var deadzone: float = 0.15
@export var knob_path: NodePath = ^\"Knob\"

var _touch_index: int = -1
var _center: Vector2
var _dir: Vector2 = Vector2.ZERO
var _knob: Control

func _ready() -> void:
	_knob = get_node_or_null(knob_path) as Control
	_center = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP

func get_direction() -> Vector2:
	return _dir

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _touch_index == -1:
			_touch_index = st.index
			_update(st.position)
		elif not st.pressed and st.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		_update((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_index = 0
				_update(mb.position)
			else:
				_release()
	elif event is InputEventMouseMotion and _touch_index != -1:
		_update((event as InputEventMouseMotion).position)

func _update(local_pos: Vector2) -> void:
	var max_r := minf(size.x, size.y) * 0.5
	var v := local_pos - _center
	if v.length() > max_r:
		v = v.normalized() * max_r
	if _knob:
		_knob.position = _center + v - _knob.size * 0.5
	var n := v / max_r if max_r > 0.0 else Vector2.ZERO
	if n.length() < deadzone:
		n = Vector2.ZERO
	_dir = n
	direction_changed.emit(_dir)
	if use_actions:
		_write_actions(_dir)

func _release() -> void:
	_touch_index = -1
	_dir = Vector2.ZERO
	if _knob:
		_knob.position = _center - _knob.size * 0.5
	direction_changed.emit(_dir)
	if use_actions:
		_write_actions(Vector2.ZERO)

func _write_actions(d: Vector2) -> void:
	Input.action_press(action_right) if d.x > deadzone else Input.action_release(action_right)
	Input.action_press(action_left) if d.x < -deadzone else Input.action_release(action_left)
	Input.action_press(action_down) if d.y > deadzone else Input.action_release(action_down)
	Input.action_press(action_up) if d.y < -deadzone else Input.action_release(action_up)
	# Strength
	if d.x > 0.0:
		Input.action_press(action_right, d.x)
	if d.x < 0.0:
		Input.action_press(action_left, -d.x)
	if d.y > 0.0:
		Input.action_press(action_down, d.y)
	if d.y < 0.0:
		Input.action_press(action_up, -d.y)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "VirtualJoystick"})


func _create_touch_btn(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/touch_action_button.gd")
	var content := """extends TouchScreenButton
## Maps touch button to an Input action while pressed.

@export var action: StringName = &\"ui_accept\"

func _ready() -> void:
	pressed.connect(_on_pressed)
	released.connect(_on_released)

func _on_pressed() -> void:
	Input.action_press(action)

func _on_released() -> void:
	Input.action_release(action)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path})


func _setup_joystick_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "TouchControls")
	layer.layer = optional_int(params, "layer", 50)
	add_child_with_undo(parent, layer, root, "MCP: Touch layer")
	var base := Panel.new()
	base.name = "JoystickBase"
	base.anchor_left = 0.0
	base.anchor_top = 1.0
	base.anchor_right = 0.0
	base.anchor_bottom = 1.0
	base.offset_left = 24
	base.offset_top = -180
	base.offset_right = 164
	base.offset_bottom = -40
	add_child_with_undo(layer, base, root, "MCP: joystick base")
	var knob := Panel.new()
	knob.name = "Knob"
	knob.offset_right = 48
	knob.offset_bottom = 48
	add_child_with_undo(base, knob, root, "MCP: knob")
	var script_path: String = optional_string(params, "script_path", "res://scripts/virtual_joystick.gd")
	if not FileAccess.file_exists(script_path):
		_create_joystick({"path": script_path, "overwrite": false})
	var scr: Script = load(script_path)
	if scr:
		base.set_script(scr)
	mark_current_scene_unsaved()
	return success({
		"layer_path": str(root.get_path_to(layer)),
		"joystick_path": str(root.get_path_to(base)),
	})


func _setup_mobile_pack(params: Dictionary) -> Dictionary:
	var joy := _setup_joystick_ui(params)
	var root := get_edited_root()
	if root == null:
		return joy
	var layer_path := ""
	if joy.has("result"):
		layer_path = str(joy["result"].get("layer_path", ""))
	var layer := find_node_by_path(layer_path) if not layer_path.is_empty() else null
	if layer:
		var btn := Button.new()
		btn.name = "JumpButton"
		btn.text = "A"
		btn.anchor_left = 1.0
		btn.anchor_right = 1.0
		btn.anchor_top = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = -120
		btn.offset_top = -120
		btn.offset_right = -40
		btn.offset_bottom = -40
		add_child_with_undo(layer, btn, root, "MCP: jump touch")
	return success({"joystick": joy, "hint": "Bind JumpButton to action via create_touch_button_script or pressed->Input"})


func _create_swipe(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/swipe_gesture.gd")
	var content := """extends Node
## Detects simple swipe gestures.

signal swiped(direction: Vector2)

@export var min_distance: float = 80.0
var _start: Vector2
var _active: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_start = st.position
			_active = true
		elif _active:
			_active = false
			var d := st.position - _start
			if d.length() >= min_distance:
				swiped.emit(d.normalized())
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path})
