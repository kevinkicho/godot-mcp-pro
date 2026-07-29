@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Joypad / gamepad InputMap surface - docs tutorials/inputs joypad section.


func get_commands() -> Dictionary:
	return {
		"list_joypads": _list_joypads,
		"create_joypad_input_map_preset": _create_joypad_preset,
		"add_joypad_binding": _add_joypad_binding,
		"set_action_deadzone": _set_action_deadzone,
		"get_action_strength_info": _get_action_strength_info,
		"list_joypad_button_names": _list_joypad_button_names,
	}


func _list_joypads(_params: Dictionary) -> Dictionary:
	var pads: Array = []
	for id in Input.get_connected_joypads():
		pads.append({
			"device": id,
			"name": Input.get_joy_name(id),
			"guid": Input.get_joy_guid(id) if Input.has_method("get_joy_guid") else "",
		})
	return success({
		"joypads": pads,
		"count": pads.size(),
		"hint": "Devices only visible when a pad is connected to the editor process",
	})


func _list_joypad_button_names(_params: Dictionary) -> Dictionary:
	## Godot JOY_BUTTON / JOY_AXIS reference for agents.
	return success({
		"buttons": {
			"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y,
			"BACK": JOY_BUTTON_BACK, "GUIDE": JOY_BUTTON_GUIDE, "START": JOY_BUTTON_START,
			"LEFT_STICK": JOY_BUTTON_LEFT_STICK, "RIGHT_STICK": JOY_BUTTON_RIGHT_STICK,
			"LEFT_SHOULDER": JOY_BUTTON_LEFT_SHOULDER, "RIGHT_SHOULDER": JOY_BUTTON_RIGHT_SHOULDER,
			"DPAD_UP": JOY_BUTTON_DPAD_UP, "DPAD_DOWN": JOY_BUTTON_DPAD_DOWN,
			"DPAD_LEFT": JOY_BUTTON_DPAD_LEFT, "DPAD_RIGHT": JOY_BUTTON_DPAD_RIGHT,
		},
		"axes": {
			"LEFT_X": JOY_AXIS_LEFT_X, "LEFT_Y": JOY_AXIS_LEFT_Y,
			"RIGHT_X": JOY_AXIS_RIGHT_X, "RIGHT_Y": JOY_AXIS_RIGHT_Y,
			"TRIGGER_LEFT": JOY_AXIS_TRIGGER_LEFT, "TRIGGER_RIGHT": JOY_AXIS_TRIGGER_RIGHT,
		},
		"presets": ["xbox_ui", "platformer", "twin_stick", "racing"],
	})


func _set_action_deadzone(params: Dictionary) -> Dictionary:
	var r := require_string(params, "action")
	if r[1] != null:
		return r[1]
	var action: String = r[0]
	var deadzone: float = clampf(float(params.get("deadzone", 0.2)), 0.0, 1.0)
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)
	var events: Array = []
	for e in InputMap.action_get_events(action):
		events.append(e)
	ProjectSettings.set_setting("input/" + action, {"deadzone": deadzone, "events": events})
	ProjectSettings.save()
	return success({"action": action, "deadzone": deadzone})


func _get_action_strength_info(params: Dictionary) -> Dictionary:
	## Document how agents should read strength; optionally sample if playing.
	var r := require_string(params, "action")
	if r[1] != null:
		return r[1]
	var action: String = r[0]
	var info := {
		"action": action,
		"exists": InputMap.has_action(action),
		"deadzone": InputMap.action_get_deadzone(action) if InputMap.has_action(action) else null,
		"api": {
			"editor_or_game": "Input.get_action_strength(action) / get_axis(neg, pos)",
			"note": "Strength is meaningful at runtime; editor values reflect editor focus",
		},
	}
	if InputMap.has_action(action):
		info["strength_now"] = Input.get_action_strength(action)
		info["raw_strength_now"] = Input.get_action_raw_strength(action)
	return success(info)


func _add_joypad_binding(params: Dictionary) -> Dictionary:
	var r := require_string(params, "action")
	if r[1] != null:
		return r[1]
	var action: String = r[0]
	var kind: String = optional_string(params, "kind", "button").to_lower()  # button | axis
	var deadzone: float = float(params.get("deadzone", 0.2))
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	var event: InputEvent = null
	if kind == "axis" or kind == "joypad_motion":
		var jm := InputEventJoypadMotion.new()
		jm.axis = _parse_axis(params.get("axis", params.get("axis_name", JOY_AXIS_LEFT_X)))
		jm.axis_value = float(params.get("axis_value", 1.0))
		event = jm
	else:
		var jb := InputEventJoypadButton.new()
		jb.button_index = _parse_button(params.get("button", params.get("button_index", JOY_BUTTON_A)))
		event = jb
	InputMap.action_add_event(action, event)
	_persist_action(action)
	return success({
		"action": action,
		"kind": kind,
		"event": _ser(event),
		"saved": true,
	})


func _create_joypad_preset(params: Dictionary) -> Dictionary:
	## Apply a full gamepad-friendly InputMap pack (alongside keyboard if merge).
	var preset: String = optional_string(params, "preset", "platformer")
	var merge: bool = optional_bool(params, "merge", true)
	var device_note := "Uses standard Godot joy button indices (Xbox layout naming)"
	var map: Dictionary = {}
	match preset:
		"xbox_ui", "ui":
			map = {
				"ui_accept": [{"type": "button", "button": JOY_BUTTON_A}],
				"ui_cancel": [{"type": "button", "button": JOY_BUTTON_B}],
				"ui_left": [{"type": "button", "button": JOY_BUTTON_DPAD_LEFT}, {"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": -1.0}],
				"ui_right": [{"type": "button", "button": JOY_BUTTON_DPAD_RIGHT}, {"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": 1.0}],
				"ui_up": [{"type": "button", "button": JOY_BUTTON_DPAD_UP}, {"type": "axis", "axis": JOY_AXIS_LEFT_Y, "axis_value": -1.0}],
				"ui_down": [{"type": "button", "button": JOY_BUTTON_DPAD_DOWN}, {"type": "axis", "axis": JOY_AXIS_LEFT_Y, "axis_value": 1.0}],
			}
		"platformer":
			map = {
				"move_left": [{"type": "button", "button": JOY_BUTTON_DPAD_LEFT}, {"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": -1.0}],
				"move_right": [{"type": "button", "button": JOY_BUTTON_DPAD_RIGHT}, {"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": 1.0}],
				"jump": [{"type": "button", "button": JOY_BUTTON_A}],
				"attack": [{"type": "button", "button": JOY_BUTTON_X}],
				"dash": [{"type": "button", "button": JOY_BUTTON_B}],
				"pause": [{"type": "button", "button": JOY_BUTTON_START}],
			}
		"twin_stick":
			map = {
				"move_left": [{"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": -1.0}],
				"move_right": [{"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": 1.0}],
				"move_up": [{"type": "axis", "axis": JOY_AXIS_LEFT_Y, "axis_value": -1.0}],
				"move_down": [{"type": "axis", "axis": JOY_AXIS_LEFT_Y, "axis_value": 1.0}],
				"aim_left": [{"type": "axis", "axis": JOY_AXIS_RIGHT_X, "axis_value": -1.0}],
				"aim_right": [{"type": "axis", "axis": JOY_AXIS_RIGHT_X, "axis_value": 1.0}],
				"aim_up": [{"type": "axis", "axis": JOY_AXIS_RIGHT_Y, "axis_value": -1.0}],
				"aim_down": [{"type": "axis", "axis": JOY_AXIS_RIGHT_Y, "axis_value": 1.0}],
				"fire": [{"type": "button", "button": JOY_BUTTON_RIGHT_SHOULDER}, {"type": "axis", "axis": JOY_AXIS_TRIGGER_RIGHT, "axis_value": 1.0}],
			}
		"racing":
			map = {
				"steer_left": [{"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": -1.0}],
				"steer_right": [{"type": "axis", "axis": JOY_AXIS_LEFT_X, "axis_value": 1.0}],
				"accelerate": [{"type": "axis", "axis": JOY_AXIS_TRIGGER_RIGHT, "axis_value": 1.0}, {"type": "button", "button": JOY_BUTTON_A}],
				"brake": [{"type": "axis", "axis": JOY_AXIS_TRIGGER_LEFT, "axis_value": 1.0}, {"type": "button", "button": JOY_BUTTON_B}],
				"handbrake": [{"type": "button", "button": JOY_BUTTON_X}],
			}
		_:
			return error_invalid_params("Unknown preset. Use: xbox_ui, platformer, twin_stick, racing")

	var applied: Array = []
	for action in map:
		var deadzone := 0.2
		if not InputMap.has_action(action):
			InputMap.add_action(action, deadzone)
		elif not merge:
			InputMap.action_erase_events(action)
		for def in map[action]:
			var ev: InputEvent = null
			if str(def.get("type", "")) == "axis":
				var jm := InputEventJoypadMotion.new()
				jm.axis = int(def.get("axis", 0))
				jm.axis_value = float(def.get("axis_value", 1.0))
				ev = jm
			else:
				var jb := InputEventJoypadButton.new()
				jb.button_index = int(def.get("button", 0))
				ev = jb
			# Avoid duplicate identical events
			var dup := false
			for existing in InputMap.action_get_events(action):
				if _events_equal(existing, ev):
					dup = true
					break
			if not dup:
				InputMap.action_add_event(action, ev)
		_persist_action(action)
		applied.append(action)

	return success({
		"preset": preset,
		"actions": applied,
		"merge": merge,
		"device_note": device_note,
		"hint": "Combine with create_input_map_preset for keyboard+mouse; list_joypads to verify hardware",
	})


func _persist_action(action: String) -> void:
	var events: Array = []
	for e in InputMap.action_get_events(action):
		events.append(e)
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": InputMap.action_get_deadzone(action),
		"events": events,
	})
	ProjectSettings.save()


func _parse_button(v: Variant) -> int:
	if v is int or v is float:
		return int(v)
	var s := str(v).to_upper()
	var table := {
		"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y,
		"START": JOY_BUTTON_START, "BACK": JOY_BUTTON_BACK, "GUIDE": JOY_BUTTON_GUIDE,
		"LB": JOY_BUTTON_LEFT_SHOULDER, "RB": JOY_BUTTON_RIGHT_SHOULDER,
		"LEFT_SHOULDER": JOY_BUTTON_LEFT_SHOULDER, "RIGHT_SHOULDER": JOY_BUTTON_RIGHT_SHOULDER,
		"DPAD_UP": JOY_BUTTON_DPAD_UP, "DPAD_DOWN": JOY_BUTTON_DPAD_DOWN,
		"DPAD_LEFT": JOY_BUTTON_DPAD_LEFT, "DPAD_RIGHT": JOY_BUTTON_DPAD_RIGHT,
	}
	return int(table.get(s, JOY_BUTTON_A))


func _parse_axis(v: Variant) -> int:
	if v is int or v is float:
		return int(v)
	var s := str(v).to_upper()
	var table := {
		"LEFT_X": JOY_AXIS_LEFT_X, "LEFT_Y": JOY_AXIS_LEFT_Y,
		"RIGHT_X": JOY_AXIS_RIGHT_X, "RIGHT_Y": JOY_AXIS_RIGHT_Y,
		"TRIGGER_LEFT": JOY_AXIS_TRIGGER_LEFT, "TRIGGER_RIGHT": JOY_AXIS_TRIGGER_RIGHT,
		"LT": JOY_AXIS_TRIGGER_LEFT, "RT": JOY_AXIS_TRIGGER_RIGHT,
	}
	return int(table.get(s, JOY_AXIS_LEFT_X))


func _ser(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadButton:
		return {"type": "joypad_button", "button_index": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "joypad_motion", "axis": event.axis, "axis_value": event.axis_value}
	return {"type": event.get_class()}


func _events_equal(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and is_equal_approx(a.axis_value, b.axis_value)
	return false
