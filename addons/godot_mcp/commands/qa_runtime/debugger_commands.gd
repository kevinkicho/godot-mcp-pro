@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Debugger surface: pause state, continue/step, source breakpoints, stack/errors.
## Godot does not fully expose breakpoint APIs to plugins; we combine:
## 1) Script source markers (`breakpoint` keyword / list lines)
## 2) Debugger toolbar button automation (Continue / Step)
## 3) ScriptEditor open + errors/stack where available


func get_commands() -> Dictionary:
	return {
		"debugger_get_status": _debugger_get_status,
		"debugger_continue": _debugger_continue,
		"debugger_step_over": _debugger_step_over,
		"debugger_step_into": _debugger_step_into,
		"debugger_step_out": _debugger_step_out,
		"list_source_breakpoints": _list_source_breakpoints,
		"set_source_breakpoint": _set_source_breakpoint,
		"remove_source_breakpoint": _remove_source_breakpoint,
		"open_script_at_line": _open_script_at_line,
		"list_debugger_errors": _list_debugger_errors,
		"set_debug_project_settings": _set_debug_project_settings,
	}


func _find_debugger_button_by_icon(icon_names: Array) -> Button:
	var dbg := _find_script_editor_debugger()
	if dbg == null:
		return null
	var icons: Array = []
	for name in icon_names:
		var ic := _get_editor_icon(str(name))
		if ic != null:
			icons.append(ic)
	var fallback: Button = null
	var queue: Array[Node] = [dbg]
	while not queue.is_empty():
		var n := queue.pop_front()
		if n is Button:
			var b := n as Button
			for ic2 in icons:
				if b.icon == ic2:
					return b
			# English tooltip fallbacks
			var tip: String = b.tooltip_text
			for name in icon_names:
				var key := str(name).replace("Debug", "")
				if tip.contains(key) or tip == key:
					fallback = b
		for c in n.get_children():
			queue.append(c)
	return fallback


func _press_debugger_button(icon_names: Array, label: String) -> Dictionary:
	var btn := _find_debugger_button_by_icon(icon_names)
	if btn == null:
		# Also try continue helper for that case
		if label == "Continue":
			try_debugger_continue()
			return success({"action": label, "pressed": is_debugger_paused() == false or true, "via": "try_debugger_continue"})
		return error_not_found("Debugger %s button" % label, "Open the Debugger bottom panel while playing")
	if btn.disabled:
		return success({
			"action": label,
			"pressed": false,
			"disabled": true,
			"message": "Button disabled (game not paused at breakpoint, or not playing)",
			"debugger_paused": is_debugger_paused(),
			"playing": get_editor().is_playing_scene() if get_editor() else false,
		})
	btn.emit_signal("pressed")
	return success({"action": label, "pressed": true, "debugger_paused": is_debugger_paused()})


func _debugger_get_status(_params: Dictionary) -> Dictionary:
	var ei := get_editor()
	var playing := ei.is_playing_scene() if ei else false
	var paused := is_debugger_paused()
	var errors := collect_debugger_errors(20)
	return success({
		"playing": playing,
		"debugger_paused": paused,
		"continue_enabled": paused,
		"error_count": errors.size(),
		"recent_errors": errors,
		"hint": "Use set_source_breakpoint to insert `breakpoint` in GDScript; play_scene; debugger_continue/step_* when paused.",
	})


func _debugger_continue(_params: Dictionary) -> Dictionary:
	return _press_debugger_button(["DebugContinue"], "Continue")


func _debugger_step_over(_params: Dictionary) -> Dictionary:
	return _press_debugger_button(["DebugStepOver", "StepOver", "DebugNext"], "Step Over")


func _debugger_step_into(_params: Dictionary) -> Dictionary:
	return _press_debugger_button(["DebugStepInto", "StepInto", "DebugStep"], "Step Into")


func _debugger_step_out(_params: Dictionary) -> Dictionary:
	return _press_debugger_button(["DebugStepOut", "StepOut"], "Step Out")


func _list_source_breakpoints(params: Dictionary) -> Dictionary:
	## List lines containing standalone `breakpoint` keyword in a script (or project scan).
	var path: String = optional_string(params, "path", "")
	var results: Array = []
	if not path.is_empty():
		if not path.begins_with("res://"):
			path = "res://" + path.trim_prefix("/")
		results = _scan_script_breakpoints(path)
		return success({"path": path, "breakpoints": results, "count": results.size()})
	# Scan scripts under res:// (capped)
	var max_files: int = optional_int(params, "max_files", 200)
	var files: Array = []
	_collect_gd_files("res://", files, max_files)
	var all: Array = []
	for fpath in files:
		var bps := _scan_script_breakpoints(str(fpath))
		for bp in bps:
			bp["path"] = fpath
			all.append(bp)
	return success({"breakpoints": all, "count": all.size(), "files_scanned": files.size()})


func _collect_gd_files(dir_path: String, out: Array, max_files: int) -> void:
	if out.size() >= max_files:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name) if not dir_path.ends_with("/") else dir_path + name
		if dir_path == "res://":
			full = "res://" + name
		else:
			full = dir_path.rstrip("/") + "/" + name
		if dir.current_is_dir():
			if name != ".godot" and name != "addons":
				_collect_gd_files(full, out, max_files)
		elif name.ends_with(".gd"):
			out.append(full)
			if out.size() >= max_files:
				break
		name = dir.get_next()
	dir.list_dir_end()


func _scan_script_breakpoints(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var line_no := 0
	while not f.eof_reached():
		line_no += 1
		var line := f.get_line()
		var stripped := line.strip_edges()
		# Standalone breakpoint keyword (not in comment only if starts with breakpoint)
		if stripped == "breakpoint" or stripped.begins_with("breakpoint ") or stripped.begins_with("breakpoint\t"):
			out.append({"line": line_no, "text": stripped})
		elif stripped.begins_with("breakpoint") and not stripped.begins_with("breakpoint_"):
			out.append({"line": line_no, "text": stripped})
	f.close()
	return out


func _set_source_breakpoint(params: Dictionary) -> Dictionary:
	## Insert `breakpoint` statement at 1-based line (or after function name).
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not path.ends_with(".gd"):
		return error_invalid_params("Only .gd scripts supported for source breakpoints")
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var line: int = optional_int(params, "line", 0)
	var after_func: String = optional_string(params, "after_function", "")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot read %s" % path)
	var text := f.get_as_text()
	f.close()
	var lines: PackedStringArray = text.split("\n")
	var insert_at := -1  # 0-based index of line AFTER which we insert, or replace empty
	if line > 0:
		insert_at = clampi(line - 1, 0, lines.size())
	elif not after_func.is_empty():
		for i in lines.size():
			var s := lines[i].strip_edges()
			if s.begins_with("func " + after_func) or s.begins_with("func " + after_func + "("):
				insert_at = i + 1
				break
		if insert_at < 0:
			return error_not_found("Function '%s'" % after_func)
	else:
		return error_invalid_params("Provide line (1-based) or after_function")
	# Detect indent from next non-empty line or previous
	var indent := "\t"
	if insert_at < lines.size():
		var sample := lines[mini(insert_at, lines.size() - 1)]
		var m := 0
		while m < sample.length() and (sample[m] == "\t" or sample[m] == " "):
			m += 1
		if m > 0:
			indent = sample.substr(0, m)
		elif insert_at > 0:
			sample = lines[insert_at - 1]
			m = 0
			while m < sample.length() and (sample[m] == "\t" or sample[m] == " "):
				m += 1
			if m > 0:
				indent = sample.substr(0, m) + "\t"
			else:
				indent = "\t"
	# Avoid duplicate
	if insert_at < lines.size() and lines[insert_at].strip_edges() == "breakpoint":
		return success({"path": path, "line": insert_at + 1, "already_present": true})
	if insert_at > 0 and insert_at <= lines.size() and lines[insert_at - 1].strip_edges() == "breakpoint":
		return success({"path": path, "line": insert_at, "already_present": true})
	var new_lines: PackedStringArray = []
	for i in lines.size():
		if i == insert_at:
			new_lines.append(indent + "breakpoint")
		new_lines.append(lines[i])
	if insert_at >= lines.size():
		new_lines.append(indent + "breakpoint")
	var out_text := "\n".join(new_lines)
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf == null:
		return error_internal("Cannot write %s" % path)
	wf.store_string(out_text)
	wf.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	# Try open in script editor
	if ResourceLoader.exists(path):
		var scr = load(path)
		if scr is Script:
			EditorInterface.edit_script(scr, insert_at + 1)
	return success({
		"path": path,
		"line": insert_at + 1,
		"inserted": "breakpoint",
		"note": "Source keyword breakpoint - hits when this line executes under the debugger",
	})


func _remove_source_breakpoint(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var line: int = optional_int(params, "line", 0)
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var lines: PackedStringArray = text.split("\n")
	var removed := 0
	var new_lines: PackedStringArray = []
	for i in lines.size():
		var stripped := lines[i].strip_edges()
		var is_bp := stripped == "breakpoint" or (stripped.begins_with("breakpoint") and not stripped.begins_with("breakpoint_"))
		if is_bp and (line <= 0 or i + 1 == line):
			removed += 1
			continue
		new_lines.append(lines[i])
	if removed == 0:
		return success({"path": path, "removed": 0, "message": "No matching breakpoint line"})
	var wf := FileAccess.open(path, FileAccess.WRITE)
	wf.store_string("\n".join(new_lines))
	wf.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "removed": removed})


func _open_script_at_line(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var line: int = optional_int(params, "line", 1)
	if not ResourceLoader.exists(res[0]):
		return error_not_found(res[0])
	var scr = load(res[0])
	if not scr is Script:
		return error_invalid_params("Not a Script resource")
	EditorInterface.edit_script(scr as Script, line)
	return success({"path": res[0], "line": line, "opened": true})


func _list_debugger_errors(params: Dictionary) -> Dictionary:
	var max_n: int = optional_int(params, "max_errors", 30)
	var errors := collect_debugger_errors(max_n)
	return success({
		"errors": errors,
		"count": errors.size(),
		"debugger_paused": is_debugger_paused(),
	})


func _set_debug_project_settings(params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("max_remote_stdout_chars_per_second"):
		ProjectSettings.set_setting(
			"network/limits/debugger/max_chars_per_second",
			int(params["max_remote_stdout_chars_per_second"])
		)
		applied["network/limits/debugger/max_chars_per_second"] = params["max_remote_stdout_chars_per_second"]
	if params.has("print_fps"):
		ProjectSettings.set_setting("debug/settings/stdout/print_fps", bool(params["print_fps"]))
		applied["debug/settings/stdout/print_fps"] = bool(params["print_fps"])
	if params.has("verbose_stdout"):
		ProjectSettings.set_setting("debug/settings/stdout/verbose_stdout", bool(params["verbose_stdout"]))
		applied["debug/settings/stdout/verbose_stdout"] = bool(params["verbose_stdout"])
	if params.has("gdscript_always_track_call_stacks"):
		ProjectSettings.set_setting(
			"debug/settings/gdscript/always_track_call_stacks",
			bool(params["gdscript_always_track_call_stacks"])
		)
		applied["debug/settings/gdscript/always_track_call_stacks"] = bool(params["gdscript_always_track_call_stacks"])
	if params.has("gdscript_always_track_local_variables"):
		ProjectSettings.set_setting(
			"debug/settings/gdscript/always_track_local_variables",
			bool(params["gdscript_always_track_local_variables"])
		)
		applied["debug/settings/gdscript/always_track_local_variables"] = bool(params["gdscript_always_track_local_variables"])
	if applied.is_empty():
		return error_invalid_params("Provide print_fps, verbose_stdout, gdscript_always_track_call_stacks, etc.")
	ProjectSettings.save()
	return success({"applied": applied})
