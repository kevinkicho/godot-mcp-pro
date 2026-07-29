@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Closed-loop interactive playtest — human "play, press keys, check state" as one agent call.
## steps: wait | action | key | mouse_click | mouse_move | sequence | assert | screenshot | log


func get_commands() -> Dictionary:
	return {
		"playtest_sequence": _playtest_sequence,
		"list_playtest_loop_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"step_types": [
			"wait (sec)",
			"action (action, pressed?, strength?)",
			"key (keycode, pressed?)",
			"mouse_click (x, y, button?)",
			"mouse_move (x, y)",
			"sequence (events[], frame_delay?)",
			"assert (node_path, property, equals?)",
			"screenshot",
			"get_tree (max_depth?)",
			"log (message)",
		],
		"example": {
			"mode": "main",
			"settle_sec": 1.0,
			"steps": [
				{"type": "action", "action": "ui_right", "pressed": true},
				{"type": "wait", "sec": 0.5},
				{"type": "action", "action": "ui_right", "pressed": false},
				{"type": "assert", "node_path": "Player", "property": "position"},
				{"type": "screenshot"},
			],
			"stop_after": true,
		},
		"related": ["playtest_report", "simulate_action", "simulate_sequence", "assert_node_state"],
	})


func _playtest_sequence(params: Dictionary) -> Dictionary:
	## Play scene, run ordered steps (input + wait + assert + screenshot), stop.
	if not params.has("steps") or not params["steps"] is Array:
		return error_invalid_params("steps: Array of step dicts required")
	var steps: Array = params["steps"]
	if steps.is_empty():
		return error_invalid_params("steps is empty")
	if steps.size() > 80:
		return error_invalid_params("Max 80 steps per playtest_sequence")

	var mode: String = optional_string(params, "mode", "main")
	var path: String = optional_string(params, "path", "")
	var settle_sec: float = float(params.get("settle_sec", 1.0))
	var stop_after: bool = optional_bool(params, "stop_after", true)
	var default_hold_sec: float = float(params.get("default_action_hold_sec", 0.15))

	match mode:
		"current":
			EditorInterface.play_current_scene()
		"custom":
			if path.is_empty():
				return error_invalid_params("custom mode needs path")
			if not path.begins_with("res://"):
				path = "res://" + path.trim_prefix("/")
			if not FileAccess.file_exists(path):
				return error_not_found(path)
			EditorInterface.play_custom_scene(path)
		_:
			EditorInterface.play_main_scene()

	var start := Time.get_ticks_msec()
	var attempts := int(maxf(settle_sec, 0.5) / 0.1) + 5
	while attempts > 0 and not EditorInterface.is_playing_scene():
		await get_tree().create_timer(0.1).timeout
		attempts -= 1
	await get_tree().create_timer(settle_sec).timeout

	var report := {
		"mode": mode,
		"path": path,
		"settle_sec": settle_sec,
		"step_results": [],
	}
	var all_ok := true

	# Initial debugger errors
	var early_errors: Array = collect_debugger_errors(10)
	if is_debugger_paused():
		try_debugger_continue()
	report["startup_debugger_errors"] = early_errors
	if early_errors.size() > 0:
		all_ok = false

	for i in range(steps.size()):
		var step = steps[i]
		if not step is Dictionary:
			report["step_results"].append({"index": i, "ok": false, "error": "step must be Dictionary"})
			all_ok = false
			if optional_bool(params, "stop_on_fail", true):
				break
			continue
		if not EditorInterface.is_playing_scene():
			report["step_results"].append({"index": i, "ok": false, "error": "game stopped"})
			all_ok = false
			break

		var stype: String = str(step.get("type", step.get("op", ""))).to_lower()
		var entry := {"index": i, "type": stype, "ok": true}

		match stype:
			"wait", "sleep", "delay":
				var sec: float = float(step.get("sec", step.get("seconds", step.get("wait_sec", 0.5))))
				await get_tree().create_timer(clampf(sec, 0.0, 30.0)).timeout
				entry["waited_sec"] = sec

			"action", "simulate_action":
				var action_name: String = str(step.get("action", ""))
				if action_name.is_empty():
					entry["ok"] = false
					entry["error"] = "action required"
					all_ok = false
				else:
					var pressed: bool = true if not step.has("pressed") else bool(step["pressed"])
					var strength: float = float(step.get("strength", 1.0))
					var werr := _write_input([{
						"type": "action",
						"action": action_name,
						"pressed": pressed,
						"strength": strength,
					}])
					if not werr.is_empty():
						entry["ok"] = false
						entry["error"] = werr
						all_ok = false
					else:
						entry["action"] = action_name
						entry["pressed"] = pressed
						# Optional hold then release
						if pressed and bool(step.get("auto_release", step.get("hold_then_release", false))):
							var hold: float = float(step.get("hold_sec", default_hold_sec))
							await get_tree().create_timer(clampf(hold, 0.05, 10.0)).timeout
							_write_input([{
								"type": "action",
								"action": action_name,
								"pressed": false,
								"strength": 0.0,
							}])
							entry["auto_released"] = true

			"key", "simulate_key":
				var keycode: String = str(step.get("keycode", step.get("key", "")))
				if keycode.is_empty():
					entry["ok"] = false
					entry["error"] = "keycode required"
					all_ok = false
				else:
					var kp: bool = true if not step.has("pressed") else bool(step["pressed"])
					var werr2 := _write_input([{
						"type": "key",
						"keycode": keycode,
						"pressed": kp,
						"shift": bool(step.get("shift", false)),
						"ctrl": bool(step.get("ctrl", false)),
						"alt": bool(step.get("alt", false)),
					}])
					if not werr2.is_empty():
						entry["ok"] = false
						entry["error"] = werr2
						all_ok = false
					else:
						entry["keycode"] = keycode

			"mouse_click":
				var mx: float = float(step.get("x", 0))
				var my: float = float(step.get("y", 0))
				var btn: int = int(step.get("button", 1))
				var press_ev := {
					"type": "mouse_button",
					"button": btn,
					"pressed": true,
					"double_click": bool(step.get("double_click", false)),
					"position": {"x": mx, "y": my},
				}
				var rel_ev := press_ev.duplicate()
				rel_ev["pressed"] = false
				var werr3 := _write_sequence([press_ev, rel_ev], 1)
				if not werr3.is_empty():
					entry["ok"] = false
					entry["error"] = werr3
					all_ok = false
				else:
					entry["x"] = mx
					entry["y"] = my
				await get_tree().create_timer(0.1).timeout

			"mouse_move":
				var werr4 := _write_input([{
					"type": "mouse_motion",
					"position": {"x": float(step.get("x", 0)), "y": float(step.get("y", 0))},
					"relative": {
						"x": float(step.get("relative_x", 0)),
						"y": float(step.get("relative_y", 0)),
					},
					"button_mask": int(step.get("button_mask", 0)),
				}])
				if not werr4.is_empty():
					entry["ok"] = false
					entry["error"] = werr4
					all_ok = false

			"sequence":
				var events: Array = step.get("events", [])
				if events.is_empty():
					entry["ok"] = false
					entry["error"] = "events required"
					all_ok = false
				else:
					var fd: int = int(step.get("frame_delay", 1))
					var werr5 := _write_sequence(events, fd)
					if not werr5.is_empty():
						entry["ok"] = false
						entry["error"] = werr5
						all_ok = false
					else:
						entry["event_count"] = events.size()
					await get_tree().create_timer(0.05 * maxi(events.size(), 1)).timeout

			"assert", "check":
				var np: String = str(step.get("node_path", step.get("path", "")))
				var prop: String = str(step.get("property", ""))
				if np.is_empty():
					entry["ok"] = false
					entry["error"] = "node_path required"
					all_ok = false
				else:
					var pr: Dictionary = await send_game_command("get_node_properties", {"node_path": np}, 5.0)
					entry["node_path"] = np
					entry["property"] = prop
					if pr.has("result"):
						var props = pr["result"]
						if props is Dictionary and props.has("properties"):
							props = props["properties"]
						if props is Dictionary:
							if prop != "" and props.has(prop):
								entry["actual"] = props[prop]
								if step.has("equals"):
									entry["expected"] = step["equals"]
									entry["ok"] = str(props[prop]) == str(step["equals"])
								elif step.has("contains"):
									entry["ok"] = str(props[prop]).contains(str(step["contains"]))
								else:
									entry["ok"] = true
							elif prop == "":
								var keys: Array = props.keys()
								entry["properties_sample"] = keys.slice(0, mini(20, keys.size()))
								entry["ok"] = true
							else:
								entry["ok"] = false
								entry["error"] = "property not found"
								var keys2: Array = props.keys()
								entry["keys_sample"] = keys2.slice(0, mini(15, keys2.size()))
						else:
							entry["ok"] = false
							entry["error"] = "unexpected properties payload"
					else:
						entry["ok"] = false
						entry["error"] = pr.get("error", "get_node_properties failed")
					if not entry.get("ok", false):
						all_ok = false

			"screenshot", "shot":
				var shot: Dictionary = await send_game_command("get_screenshot", {}, 8.0)
				if shot.has("result") and shot["result"] is Dictionary:
					var sr: Dictionary = shot["result"]
					entry["screenshot"] = {
						"has_image": sr.has("image_base64") or sr.has("path"),
						"path": sr.get("path", ""),
						"width": sr.get("width", 0),
						"height": sr.get("height", 0),
					}
					if optional_bool(params, "include_screenshot_data", false) and optional_bool(step, "include_data", false):
						entry["screenshot"]["image_base64"] = sr.get("image_base64", "")
				else:
					entry["ok"] = false
					entry["error"] = shot.get("error", "screenshot failed")
					all_ok = false

			"get_tree", "tree":
				var depth: int = int(step.get("max_depth", 4))
				var tree_res: Dictionary = await send_game_command("get_scene_tree", {"max_depth": depth}, 8.0)
				if tree_res.has("result"):
					entry["game_scene_tree"] = tree_res["result"]
				else:
					entry["ok"] = false
					entry["error"] = tree_res.get("error", "get_scene_tree failed")
					all_ok = false

			"log", "note":
				entry["message"] = str(step.get("message", step.get("text", "")))

			_:
				entry["ok"] = false
				entry["error"] = "unknown step type: %s" % stype
				all_ok = false

		if is_debugger_paused():
			try_debugger_continue()
			entry["debugger_was_paused"] = true
		var step_errors: Array = collect_debugger_errors(5)
		if step_errors.size() > 0:
			entry["debugger_errors"] = step_errors
			# Don't fail entire run solely for residual errors unless step itself failed

		report["step_results"].append(entry)
		if not entry.get("ok", false) and optional_bool(params, "stop_on_fail", true):
			break

	report["debugger_errors"] = collect_debugger_errors(20)
	report["debugger_paused"] = is_debugger_paused()
	if report["debugger_errors"].size() > 0:
		all_ok = false

	if stop_after and EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
		report["stopped"] = true
	else:
		report["stopped"] = false

	report["ok"] = all_ok
	report["elapsed_ms"] = Time.get_ticks_msec() - start
	report["summary"] = "playtest_sequence %s — %d steps" % [
		"PASS" if all_ok else "FAIL",
		report["step_results"].size(),
	]
	return success(report)


func _input_path() -> String:
	return get_game_user_dir().path_join("mcp_input_commands")


func _write_input(events: Array) -> Dictionary:
	var path := _input_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"message": "Failed to write input commands", "code": FileAccess.get_open_error()}
	file.store_string(JSON.stringify(events))
	file.close()
	return {}


func _write_sequence(events: Array, frame_delay: int) -> Dictionary:
	var path := _input_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"message": "Failed to write input sequence", "code": FileAccess.get_open_error()}
	if frame_delay <= 0:
		file.store_string(JSON.stringify(events))
	else:
		file.store_string(JSON.stringify({
			"sequence_events": events,
			"frame_delay": frame_delay,
		}))
	file.close()
	return {}
