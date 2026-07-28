@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Prefer the *game* user dir so input reaches the running play-session
## even when editor-cached user:// differs (project rename, custom user dir).
func _commands_path() -> String:
	return get_game_user_dir().path_join("mcp_input_commands")


func get_commands() -> Dictionary:
	return {
		"simulate_key": _simulate_key,
		"simulate_mouse_click": _simulate_mouse_click,
		"simulate_mouse_move": _simulate_mouse_move,
		"simulate_action": _simulate_action,
		"simulate_sequence": _simulate_sequence,
	}


func _simulate_key(params: Dictionary) -> Dictionary:
	var result := require_string(params, "keycode")
	if result[1] != null:
		return result[1]
	var keycode: String = result[0]

	var pressed: bool = optional_bool(params, "pressed", true)
	var shift: bool = optional_bool(params, "shift", false)
	var ctrl: bool = optional_bool(params, "ctrl", false)
	var alt: bool = optional_bool(params, "alt", false)

	var event := {
		"type": "key",
		"keycode": keycode,
		"pressed": pressed,
		"shift": shift,
		"ctrl": ctrl,
		"alt": alt,
	}
	var werr := _write_commands([event])
	if not werr.is_empty():
		return werr
	return success({"sent": true, "event": event})


func _simulate_mouse_click(params: Dictionary) -> Dictionary:
	var button: int = optional_int(params, "button", 1)  # MOUSE_BUTTON_LEFT
	var pressed: bool = optional_bool(params, "pressed", true)
	var double_click: bool = optional_bool(params, "double_click", false)
	var auto_release: bool = optional_bool(params, "auto_release", true)
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))

	var press_event := {
		"type": "mouse_button",
		"button": button,
		"pressed": pressed,
		"double_click": double_click,
		"position": {"x": x, "y": y},
	}

	# Auto-release: send press + release in sequence so UI buttons actually fire
	if pressed and auto_release:
		var release_event := press_event.duplicate()
		release_event["pressed"] = false
		var sequence_data := {
			"sequence_events": [press_event, release_event],
			"frame_delay": 1,
		}
		var write_err := _write_raw(JSON.stringify(sequence_data))
		if not write_err.is_empty():
			return write_err
		return success({"sent": true, "event": press_event, "auto_release": true})

	var werr2 := _write_commands([press_event])
	if not werr2.is_empty():
		return werr2
	return success({"sent": true, "event": press_event})


func _simulate_mouse_move(params: Dictionary) -> Dictionary:
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var rel_x: float = float(params.get("relative_x", 0))
	var rel_y: float = float(params.get("relative_y", 0))
	var button_mask: int = optional_int(params, "button_mask", 0)
	var unhandled_explicit: bool = params.has("unhandled")
	var unhandled: bool = optional_bool(params, "unhandled", false)

	var event := {
		"type": "mouse_motion",
		"position": {"x": x, "y": y},
		"relative": {"x": rel_x, "y": rel_y},
		"button_mask": button_mask,
	}
	# Auto-enable unhandled for drag motions (camera-pan use case) ONLY when
	# the caller did NOT explicitly pass an "unhandled" key. If they passed
	# one — true or false — honor it. This lets UI drag-and-drop tests opt
	# back into normal GUI dispatch by passing unhandled: false explicitly.
	if unhandled_explicit:
		event["unhandled"] = unhandled
	elif button_mask > 0:
		event["unhandled"] = true
	var werr3 := _write_commands([event])
	if not werr3.is_empty():
		return werr3
	return success({"sent": true, "event": event})


func _simulate_action(params: Dictionary) -> Dictionary:
	var result := require_string(params, "action")
	if result[1] != null:
		return result[1]
	var action_name: String = result[0]

	var pressed: bool = optional_bool(params, "pressed", true)
	var strength: float = float(params.get("strength", 1.0))

	var event := {
		"type": "action",
		"action": action_name,
		"pressed": pressed,
		"strength": strength,
	}
	var werr4 := _write_commands([event])
	if not werr4.is_empty():
		return werr4
	return success({"sent": true, "event": event})


func _simulate_sequence(params: Dictionary) -> Dictionary:
	if not params.has("events") or not params["events"] is Array:
		return error_invalid_params("Missing required parameter: events (Array)")

	var events: Array = params["events"]
	if events.is_empty():
		return error_invalid_params("Events array is empty")

	var frame_delay: int = optional_int(params, "frame_delay", 1)

	for event_data: Dictionary in events:
		if not event_data.has("type") or (event_data["type"] as String).is_empty():
			return error_invalid_params("Invalid event in sequence: %s" % str(event_data))

	if frame_delay <= 0:
		# All events in one frame - write as plain array
		var err := _write_commands(events)
		if not err.is_empty():
			return err
	else:
		# Sequence with frame delay - game side handles timing
		var sequence_data := {
			"sequence_events": events,
			"frame_delay": frame_delay,
		}
		var write_err := _write_raw(JSON.stringify(sequence_data))
		if not write_err.is_empty():
			return write_err

	return success({"sent": true, "event_count": events.size(), "frame_delay": frame_delay})


func _write_commands(events: Array) -> Dictionary:
	return _write_raw(JSON.stringify(events))


func _write_raw(json: String) -> Dictionary:
	var path := _commands_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var msg := "Failed to write commands to %s: %s" % [path, error_string(FileAccess.get_open_error())]
		push_error("[MCP Input] %s" % msg)
		return error_internal(msg)
	file.store_string(json)
	file.close()
	return {}
