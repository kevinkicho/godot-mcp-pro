@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Headless-oriented production macros — match high-frequency human IDE actions.
## Prefer these when building a game end-to-end (brief → content → playtest).


func get_commands() -> Dictionary:
	return {
		"scaffold_project_defaults": _scaffold_project_defaults,
		"wire_signal_to_new_method": _wire_signal_to_new_method,
		"playtest_report": _playtest_report,
		"agent_production_status": _agent_production_status,
		"create_input_map_preset": _create_input_map_preset,
	}


func _scaffold_project_defaults(params: Dictionary) -> Dictionary:
	## First-hour human Project Settings + folders + main scene shell.
	var genre: String = optional_string(params, "genre", "generic")  # 2d|3d|ui|generic
	var project_name: String = optional_string(params, "project_name", "")
	var applied: Array = []
	var created: Array = []

	if not project_name.is_empty():
		ProjectSettings.set_setting("application/config/name", project_name)
		applied.append("application/config/name")

	# Window defaults (common game)
	var vw: int = optional_int(params, "viewport_width", 1280)
	var vh: int = optional_int(params, "viewport_height", 720)
	ProjectSettings.set_setting("display/window/size/viewport_width", vw)
	ProjectSettings.set_setting("display/window/size/viewport_height", vh)
	ProjectSettings.set_setting("display/window/stretch/mode", optional_string(params, "stretch_mode", "canvas_items"))
	ProjectSettings.set_setting("display/window/stretch/aspect", optional_string(params, "stretch_aspect", "expand"))
	applied.append_array(["viewport", "stretch"])

	# Folder layout
	var dirs: Array = params.get("folders", [
		"res://scenes", "res://scripts", "res://assets", "res://assets/sprites",
		"res://assets/audio", "res://ui", "res://resources",
	])
	for d in dirs:
		var dp := str(d)
		if not dp.begins_with("res://"):
			dp = "res://" + dp.trim_prefix("/")
		var abs := ProjectSettings.globalize_path(dp)
		if not DirAccess.dir_exists_absolute(abs):
			DirAccess.make_dir_recursive_absolute(abs)
			created.append(dp)

	# Physics layer names (2d)
	if genre in ["2d", "generic", ""]:
		var layer_prefix := "layer_names/2d_physics/layer_"
		var defaults := {1: "player", 2: "enemy", 3: "world", 4: "projectile", 5: "pickup"}
		for k in defaults:
			ProjectSettings.set_setting(layer_prefix + str(k), defaults[k])
		applied.append("2d_physics_layers")

	if genre == "3d":
		var p3 := "layer_names/3d_physics/layer_"
		var d3 := {1: "player", 2: "enemy", 3: "world", 4: "projectile"}
		for k2 in d3:
			ProjectSettings.set_setting(p3 + str(k2), d3[k2])
		applied.append("3d_physics_layers")

	# Input map preset
	var input_preset: String = optional_string(params, "input_preset", "platformer_2d" if genre != "3d" else "fps_basic")
	if optional_bool(params, "setup_input", true):
		var ir := _create_input_map_preset({"preset": input_preset})
		if ir.has("result"):
			applied.append("input_preset:%s" % input_preset)
		elif ir.has("error"):
			applied.append("input_preset_failed")

	# Main scene shell
	var main_path: String = optional_string(params, "main_scene", "res://scenes/main.tscn")
	if not main_path.begins_with("res://"):
		main_path = "res://" + main_path.trim_prefix("/")
	var root_type: String = optional_string(params, "root_type", "")
	if root_type.is_empty():
		match genre:
			"3d":
				root_type = "Node3D"
			"ui":
				root_type = "Control"
			_:
				root_type = "Node2D"
	if not FileAccess.file_exists(main_path) or optional_bool(params, "force_main_scene", false):
		var mk := await _create_main_scene_file(main_path, root_type)
		if mk.get("ok", false):
			created.append(main_path)
	ProjectSettings.set_setting("application/run/main_scene", main_path)
	applied.append("main_scene")

	ProjectSettings.save()
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()

	return success({
		"genre": genre,
		"main_scene": main_path,
		"root_type": root_type,
		"applied": applied,
		"created": created,
		"viewport": {"width": vw, "height": vh},
		"next_steps": [
			"stage_files_into_res / ensure_imported for assets",
			"create_scene / add_node / create_script for gameplay",
			"wire_signal_to_new_method for UI/game events",
			"playtest_report to verify",
		],
		"headless_note": "Requires Godot editor + MCP plugin for full import/playtest; file scaffolding works when plugin is up.",
	})


func _create_main_scene_file(path: String, root_type: String) -> Dictionary:
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return {"ok": false, "error": derr}
	# Minimal tscn
	var type_name := root_type
	if not ClassDB.class_exists(type_name):
		type_name = "Node2D"
	var body := """[gd_scene format=3]

[node name="Main" type="%s"]
""" % type_name
	if type_name == "Control":
		body = """[gd_scene format=3]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
"""
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false}
	f.store_string(body)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return {"ok": true, "path": path}


func _create_input_map_preset(params: Dictionary) -> Dictionary:
	## Common InputMap packs so agents don't reinvent WASD every game.
	## Writes ProjectSettings + live InputMap (matches Project → Input Map dock).
	var preset: String = optional_string(params, "preset", "platformer_2d")
	var actions: Dictionary = {}
	match preset:
		"platformer_2d", "topdown_2d", "2d":
			actions = {
				"move_left": [{"type": "key", "keycode": "A"}, {"type": "key", "keycode": "Left"}],
				"move_right": [{"type": "key", "keycode": "D"}, {"type": "key", "keycode": "Right"}],
				"move_up": [{"type": "key", "keycode": "W"}, {"type": "key", "keycode": "Up"}],
				"move_down": [{"type": "key", "keycode": "S"}, {"type": "key", "keycode": "Down"}],
				"jump": [{"type": "key", "keycode": "Space"}],
				"shoot": [{"type": "key", "keycode": "J"}, {"type": "mouse", "button": 1}],
				"pause": [{"type": "key", "keycode": "Escape"}],
				"interact": [{"type": "key", "keycode": "E"}],
			}
		"fps_basic", "3d":
			actions = {
				"move_left": [{"type": "key", "keycode": "A"}],
				"move_right": [{"type": "key", "keycode": "D"}],
				"move_forward": [{"type": "key", "keycode": "W"}],
				"move_back": [{"type": "key", "keycode": "S"}],
				"jump": [{"type": "key", "keycode": "Space"}],
				"shoot": [{"type": "mouse", "button": 1}],
				"aim": [{"type": "mouse", "button": 2}],
				"pause": [{"type": "key", "keycode": "Escape"}],
			}
		"ui_menu":
			actions = {
				"ui_accept": [{"type": "key", "keycode": "Enter"}, {"type": "key", "keycode": "Space"}],
				"ui_cancel": [{"type": "key", "keycode": "Escape"}],
			}
		_:
			if params.has("actions") and params["actions"] is Dictionary:
				actions = params["actions"]
			else:
				return error_invalid_params("Unknown preset; use platformer_2d|fps_basic|ui_menu or actions{}")

	var created: Array = []
	var deadzone: float = float(params.get("deadzone", 0.5))
	for action_name in actions:
		var action_str := str(action_name)
		var evts: Array = actions[action_name]
		var events: Array = []
		for e in evts:
			if e is Dictionary:
				var ev: InputEvent = _make_input_event(e)
				if ev:
					events.append(ev)
		# Persist to project.godot (Project Settings → Input Map)
		ProjectSettings.set_setting("input/" + action_str, {
			"deadzone": deadzone,
			"events": events,
		})
		# Live InputMap so playtest works without editor restart
		if not InputMap.has_action(action_str):
			InputMap.add_action(action_str, deadzone)
		else:
			InputMap.action_set_deadzone(action_str, deadzone)
			InputMap.action_erase_events(action_str)
		for ev2 in events:
			InputMap.action_add_event(action_str, ev2)
		created.append(action_str)
	var save_err := ProjectSettings.save()
	if save_err != OK:
		return error_internal("Failed to save input map: %s" % error_string(save_err))
	return success({"preset": preset, "actions": created, "count": created.size(), "deadzone": deadzone})


func _make_input_event(spec: Dictionary) -> InputEvent:
	var t: String = str(spec.get("type", "key")).to_lower()
	if t == "key":
		var ev := InputEventKey.new()
		var kc: String = str(spec.get("keycode", spec.get("key", "A")))
		ev.keycode = _keycode_from_string(kc)
		ev.ctrl_pressed = bool(spec.get("ctrl", false))
		ev.shift_pressed = bool(spec.get("shift", false))
		ev.alt_pressed = bool(spec.get("alt", false))
		ev.meta_pressed = bool(spec.get("meta", false))
		return ev
	if t == "mouse" or t == "mouse_button":
		var em := InputEventMouseButton.new()
		em.button_index = int(spec.get("button", spec.get("button_index", 1))) as MouseButton
		return em
	if t == "joypad_button":
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(spec.get("button_index", spec.get("button", 0))) as JoyButton
		return jb
	if t == "joypad_motion":
		var jm := InputEventJoypadMotion.new()
		jm.axis = int(spec.get("axis", 0)) as JoyAxis
		jm.axis_value = float(spec.get("axis_value", 1.0))
		return jm
	return null


func _keycode_from_string(s: String) -> Key:
	## Prefer engine resolver (handles "A", "Space", "Left", "Escape", …).
	if s.is_empty():
		return KEY_NONE
	var from_os: Key = OS.find_keycode_from_string(s) as Key
	if from_os != KEY_NONE:
		return from_os
	# Title-case aliases
	var titled := s.capitalize()
	from_os = OS.find_keycode_from_string(titled) as Key
	if from_os != KEY_NONE:
		return from_os
	var u := s.to_upper()
	match u:
		"LEFT", "ARROWLEFT", "ARROW_LEFT":
			return KEY_LEFT
		"RIGHT", "ARROWRIGHT", "ARROW_RIGHT":
			return KEY_RIGHT
		"UP", "ARROWUP", "ARROW_UP":
			return KEY_UP
		"DOWN", "ARROWDOWN", "ARROW_DOWN":
			return KEY_DOWN
		"SPACE", "SPACEBAR":
			return KEY_SPACE
		"ENTER", "RETURN":
			return KEY_ENTER
		"ESCAPE", "ESC":
			return KEY_ESCAPE
		"SHIFT":
			return KEY_SHIFT
		"CTRL", "CONTROL":
			return KEY_CTRL
		"TAB":
			return KEY_TAB
		_:
			if ClassDB.class_has_integer_constant(&"@GlobalScope", "KEY_" + u):
				return ClassDB.class_get_integer_constant(&"@GlobalScope", "KEY_" + u) as Key
			if u.length() == 1:
				var ch := u.unicode_at(0)
				if ch >= 65 and ch <= 90:
					return ch as Key
				if ch >= 48 and ch <= 57:
					return ch as Key
			return KEY_NONE


func _wire_signal_to_new_method(params: Dictionary) -> Dictionary:
	## Human Signal dock: Connect → create method on target script (or create script).
	var source_r := require_string(params, "source_path")
	if source_r[1] != null:
		return source_r[1]
	var signal_r := require_string(params, "signal_name")
	if signal_r[1] != null:
		return signal_r[1]
	var target_r := require_string(params, "target_path")
	if target_r[1] != null:
		return target_r[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var source := find_node_by_path(source_r[0])
	var target := find_node_by_path(target_r[0])
	if source == null:
		return error_not_found("Source '%s'" % source_r[0])
	if target == null:
		return error_not_found("Target '%s'" % target_r[0])
	if not source.has_signal(signal_r[0]):
		return error_invalid_params("Signal '%s' not on %s" % [signal_r[0], source.get_class()])

	var method_name: String = optional_string(params, "method_name", "")
	if method_name.is_empty():
		method_name = "_on_%s_%s" % [source.name.to_snake_case(), signal_r[0]]
		method_name = method_name.replace("__", "_")

	# Ensure target has a script
	var script: Script = target.get_script()
	var script_path := ""
	var script_created := false
	if script == null or script.resource_path.is_empty():
		script_path = optional_string(params, "script_path", "res://scripts/%s.gd" % target.name.to_snake_case())
		if not script_path.begins_with("res://"):
			script_path = "res://" + script_path.trim_prefix("/")
		if not FileAccess.file_exists(script_path):
			var base_class := target.get_class()
			var tmpl := "extends %s\n\n\nfunc _ready() -> void:\n\tpass\n" % base_class
			var derr := ensure_parent_dir(script_path)
			if not derr.is_empty():
				return derr
			var wf := FileAccess.open(script_path, FileAccess.WRITE)
			if wf == null:
				return error_internal("Cannot create script %s" % script_path)
			wf.store_string(tmpl)
			wf.close()
			script_created = true
			EditorInterface.get_resource_filesystem().update_file(script_path)
		script = load(script_path) as Script
		if script == null:
			return error_internal("Failed to load script %s" % script_path)
		target.set_script(script)
		mark_current_scene_unsaved()
	else:
		script_path = script.resource_path

	# Append method if missing
	var method_added := false
	if not FileAccess.file_exists(script_path):
		return error_not_found(script_path)
	var rf := FileAccess.open(script_path, FileAccess.READ)
	if rf == null:
		return error_internal("Cannot read script %s" % script_path)
	var text := rf.get_as_text()
	rf.close()
	if not text.contains("func %s(" % method_name):
		# Prefer signal arg names from ClassDB when method_args omitted
		var arg_list: String = optional_string(params, "method_args", "")
		if arg_list.is_empty():
			arg_list = _signal_arg_list(source, signal_r[0])
		var stub: String
		if optional_bool(params, "print_debug", true):
			stub = "\n\nfunc %s(%s) -> void:\n\tprint(\"[signal] %s.%s -> %s\")\n" % [
				method_name, arg_list, source.name, signal_r[0], method_name
			]
		else:
			stub = "\n\nfunc %s(%s) -> void:\n\tpass\n" % [method_name, arg_list]
		text = text.rstrip() + stub
		var guard := guard_text_resource_write(script_path, optional_bool(params, "force", true))
		if not guard.is_empty():
			return guard
		var w2 := FileAccess.open(script_path, FileAccess.WRITE)
		if w2 == null:
			return error_internal("Cannot write script")
		w2.store_string(text)
		w2.close()
		method_added = true
		if script:
			script.reload(true)
		EditorInterface.get_resource_filesystem().update_file(script_path)

	# Connect persistent (scene connection — human Signal dock)
	var already := source.is_connected(signal_r[0], Callable(target, method_name))
	if not already:
		var flags: int = Object.CONNECT_PERSIST
		if optional_bool(params, "deferred", false):
			flags |= Object.CONNECT_DEFERRED
		var undo := get_undo_redo()
		undo.create_action("MCP: Wire signal to new method")
		undo.add_do_method(source, "connect", signal_r[0], Callable(target, method_name), flags)
		undo.add_undo_method(source, "disconnect", signal_r[0], Callable(target, method_name))
		undo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"source": str(root.get_path_to(source)),
		"signal": signal_r[0],
		"target": str(root.get_path_to(target)),
		"method": method_name,
		"script_path": script_path,
		"script_created": script_created,
		"method_added": method_added,
		"connected": true,
		"was_already_connected": already,
		"persistent": true,
	})


func _signal_arg_list(source: Object, signal_name: String) -> String:
	## Build "arg0, arg1" style param list from signal signature when available.
	for sig in source.get_signal_list():
		if str(sig.get("name", "")) != signal_name:
			continue
		var args: Array = sig.get("args", [])
		if args.is_empty():
			return ""
		var parts: PackedStringArray = PackedStringArray()
		for i in range(args.size()):
			var a: Dictionary = args[i]
			var n: String = str(a.get("name", ""))
			if n.is_empty():
				n = "arg%d" % i
			parts.append(n)
		return ", ".join(parts)
	return ""


func _playtest_report(params: Dictionary) -> Dictionary:
	## Human "hit Play, look at Output, glance at game" in one agent call.
	var mode: String = optional_string(params, "mode", "main")
	var path: String = optional_string(params, "path", "")
	var settle_sec: float = float(params.get("settle_sec", params.get("wait_sec", 1.5)))
	var stop_after: bool = optional_bool(params, "stop_after", true)
	var take_screenshot: bool = optional_bool(params, "screenshot", true)

	# Start play
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

	# Wait for game to boot
	var start := Time.get_ticks_msec()
	var attempts := int(maxf(settle_sec, 0.5) / 0.1) + 5
	while attempts > 0 and not EditorInterface.is_playing_scene():
		await get_tree().create_timer(0.1).timeout
		attempts -= 1
	await get_tree().create_timer(settle_sec).timeout

	var report := {
		"playing": EditorInterface.is_playing_scene(),
		"mode": mode,
		"path": path,
		"settle_sec": settle_sec,
		"elapsed_ms": Time.get_ticks_msec() - start,
	}

	# Errors from editor/debugger
	var errors: Array = collect_debugger_errors(20)
	report["debugger_errors"] = errors
	report["debugger_paused"] = is_debugger_paused()
	if is_debugger_paused():
		try_debugger_continue()
		report["auto_continued"] = true

	# Runtime tree snapshot (best-effort)
	if EditorInterface.is_playing_scene():
		var tree_res: Dictionary = await send_game_command("get_scene_tree", {"max_depth": optional_int(params, "max_depth", 4)}, 8.0)
		if tree_res.has("result"):
			report["game_scene_tree"] = tree_res["result"]
		elif tree_res.has("error"):
			report["game_scene_tree_error"] = tree_res["error"]
		# Optional property checks: asserts: [{node_path, property, equals}]
		if params.has("asserts") and params["asserts"] is Array:
			var assert_results: Array = []
			for a in params["asserts"]:
				if not a is Dictionary:
					continue
				var np := str(a.get("node_path", a.get("path", "")))
				var prop := str(a.get("property", ""))
				var pr: Dictionary = await send_game_command("get_node_properties", {"node_path": np}, 5.0)
				var entry := {"node_path": np, "property": prop, "ok": false}
				if pr.has("result"):
					var props = pr["result"]
					if props is Dictionary and props.has("properties"):
						props = props["properties"]
					if props is Dictionary and prop != "" and props.has(prop):
						entry["actual"] = props[prop]
						if a.has("equals"):
							entry["ok"] = str(props[prop]) == str(a["equals"])
							entry["expected"] = a["equals"]
						else:
							entry["ok"] = true
					else:
						entry["properties_keys"] = props.keys() if props is Dictionary else []
				else:
					entry["error"] = pr.get("error", pr)
				assert_results.append(entry)
			report["asserts"] = assert_results

	# Screenshot (may be large — include path/meta only if tool returns base64, truncate)
	if take_screenshot and EditorInterface.is_playing_scene():
		# Reuse game inspector screenshot via editor command pattern if available
		var shot: Dictionary = await send_game_command("get_screenshot", {}, 8.0)
		if shot.has("result"):
			var sr = shot["result"]
			if sr is Dictionary:
				report["screenshot"] = {
					"has_image": sr.has("image_base64") or sr.has("path"),
					"path": sr.get("path", ""),
					"width": sr.get("width", 0),
					"height": sr.get("height", 0),
					# Do not dump full base64 into agent context unless requested
					"image_base64": sr.get("image_base64", "") if optional_bool(params, "include_screenshot_data", false) else "",
				}
			else:
				report["screenshot"] = {"raw": true}
		else:
			report["screenshot_error"] = shot.get("error", "unavailable")

	if stop_after and EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
		report["stopped"] = true
	else:
		report["stopped"] = false

	var ok := report.get("playing", false) or report.get("stopped", false)
	if errors.size() > 0:
		ok = false
	if report.has("asserts"):
		for ar in report["asserts"]:
			if ar is Dictionary and not ar.get("ok", false):
				ok = false
	report["ok"] = ok
	report["summary"] = "playtest %s — %d debugger errors" % [
		"PASS" if ok else "FAIL",
		errors.size(),
	]
	return success(report)


func _agent_production_status(_params: Dictionary) -> Dictionary:
	## Single dashboard: connection, scene, import idle, play state, command count.
	var cfg := ConfigFile.new()
	var plugin_version := "unknown"
	if cfg.load("res://addons/godot_mcp/plugin.cfg") == OK:
		plugin_version = str(cfg.get_value("plugin", "version", "unknown"))
	var root := get_edited_root()
	var router = get_parent()
	var command_count := 0
	if router and router.has_method("get_available_methods"):
		command_count = router.get_available_methods().size()
	var fs := EditorInterface.get_resource_filesystem()
	var scanning := fs.is_scanning() if fs else false
	var playing := EditorInterface.is_playing_scene()
	var issues: Array = []
	if command_count == 0:
		issues.append("No commands registered")
	if root == null:
		issues.append("No scene open — open_scene or create_scene")
	if scanning:
		issues.append("Filesystem still scanning/importing — wait_for_import / ensure_imported")
	return success({
		"plugin_version": plugin_version,
		"command_count": command_count,
		"project_name": ProjectSettings.get_setting("application/config/name", ""),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"open_scene": root.scene_file_path if root else "",
		"has_open_scene": root != null,
		"filesystem_scanning": scanning,
		"playing": playing,
		"debugger_paused": is_debugger_paused(),
		"issues": issues,
		"ready_for_content_work": command_count > 0 and not scanning,
		"recommended_loop": [
			"agent_production_status",
			"scaffold_project_defaults (once)",
			"stage_files_into_res / ensure_imported",
			"build scenes/scripts",
			"wire_signal_to_new_method",
			"playtest_report",
			"fix → repeat",
		],
	})
