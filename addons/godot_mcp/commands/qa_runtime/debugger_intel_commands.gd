@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Debugger intelligence - parse errors -> file/line -> fix plan (Wave 5).


func get_commands() -> Dictionary:
	return {
		"analyze_debugger_errors": _analyze_debugger_errors,
		"get_fix_plan_from_errors": _get_fix_plan_from_errors,
		"open_error_source": _open_error_source,
		"list_debugger_intel_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["list_debugger_errors", "debugger_get_status", "open_script_at_line", "playtest_fix_loop"],
	})


func _analyze_debugger_errors(params: Dictionary) -> Dictionary:
	var max_n: int = clampi(optional_int(params, "max", 30), 1, 100)
	var errors: Array = collect_debugger_errors(max_n)
	if params.has("errors") and params["errors"] is Array:
		for e in params["errors"]:
			errors.append(e)
	var analyzed: Array = []
	var re := RegEx.new()
	re.compile("(res://[^\\s:\\]\\)]+):(\\d+)")
	for e in errors:
		var msg := str(e)
		var entry := {
			"raw": msg,
			"category": _categorize(msg),
			"script_path": "",
			"line": 0,
		}
		var m := re.search(msg)
		if m:
			entry["script_path"] = m.get_string(1)
			entry["line"] = int(m.get_string(2))
		entry["suggested_action"] = _action_for(entry)
		analyzed.append(entry)
	return success({
		"count": analyzed.size(),
		"errors": analyzed,
		"debugger_paused": is_debugger_paused(),
		"playing": EditorInterface.is_playing_scene(),
	})


func _categorize(msg: String) -> String:
	var l := msg.to_lower()
	if l.contains("parser error") or l.contains("compile"):
		return "parse"
	if l.contains("null instance") or l.contains("invalid get index") or l.contains("invalid call"):
		return "null_ref"
	if l.contains("failed to load") or l.contains("no such file") or l.contains("cannot open"):
		return "missing_resource"
	if l.contains("signal"):
		return "signal"
	if l.contains("stack overflow") or l.contains("cyclic"):
		return "cycle"
	if l.contains("assertion failed"):
		return "assert"
	return "runtime"


func _action_for(entry: Dictionary) -> String:
	var cat: String = str(entry.get("category", ""))
	var path: String = str(entry.get("script_path", ""))
	var line: int = int(entry.get("line", 0))
	match cat:
		"parse":
			return "validate_script path=%s; edit_script around line %d" % [path, line]
		"null_ref":
			return "get_scene_tree; check @onready paths; open_script_at_line %s:%d" % [path, line]
		"missing_resource":
			return "ensure_imported / get_filesystem_tree; fix res:// path"
		"signal":
			return "get_signals + connect_signal / wire_signal_to_new_method"
		_:
			if not path.is_empty():
				return "open_script_at_line path=%s line=%d" % [path, line]
			return "list_debugger_errors + playtest_report"


func _get_fix_plan_from_errors(params: Dictionary) -> Dictionary:
	var analysis := _analyze_debugger_errors(params)
	var ar = analysis.get("result", analysis)
	var steps: Array = []
	var seen := {}
	if ar is Dictionary:
		for e in ar.get("errors", []):
			if not e is Dictionary:
				continue
			var key := str(e.get("script_path", "")) + ":" + str(e.get("line", 0)) + e.get("category", "")
			if seen.has(key):
				continue
			seen[key] = true
			var step := {
				"category": e.get("category"),
				"action": e.get("suggested_action"),
				"tools": [],
			}
			match str(e.get("category")):
				"parse":
					step["tools"] = ["validate_script", "edit_script", "open_script_at_line"]
				"null_ref":
					step["tools"] = ["get_scene_tree", "inspect_node", "open_script_at_line"]
				"missing_resource":
					step["tools"] = ["ensure_imported", "scan_filesystem", "get_import_info"]
				_:
					step["tools"] = ["open_script_at_line", "edit_script", "playtest_report"]
			if e.get("script_path"):
				step["script_path"] = e.get("script_path")
				step["line"] = e.get("line")
			steps.append(step)
	steps.append({
		"category": "verify",
		"action": "playtest_fix_loop or playtest_report",
		"tools": ["playtest_fix_loop", "playtest_report"],
	})
	return success({
		"plan": steps,
		"step_count": steps.size(),
		"error_analysis": ar,
	})


func _open_error_source(params: Dictionary) -> Dictionary:
	## Open first parseable error location, or provided path/line.
	var path: String = optional_string(params, "path", "")
	var line: int = optional_int(params, "line", 1)
	if path.is_empty():
		var analysis := _analyze_debugger_errors({"max": 10})
		var ar = analysis.get("result", analysis)
		if ar is Dictionary:
			for e in ar.get("errors", []):
				if e is Dictionary and str(e.get("script_path", "")).begins_with("res://"):
					path = str(e["script_path"])
					line = int(e.get("line", 1))
					break
	if path.is_empty():
		return error_not_found("No script path in errors - pass path=")
	var router = get_parent()
	if router and router.has_method("execute"):
		return await router.execute("open_script_at_line", {"path": path, "line": line})
	EditorInterface.edit_script(load(path) as Script, line - 1)
	return success({"path": path, "line": line, "opened": true})
