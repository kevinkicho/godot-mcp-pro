@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Closed-loop playtest → diagnose → agent fix hints (Wave 2).


func get_commands() -> Dictionary:
	return {
		"playtest_fix_loop": _playtest_fix_loop,
		"diagnose_playtest_failure": _diagnose_playtest_failure,
		"assert_scene_playable": _assert_scene_playable,
		"list_playtest_fix_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["playtest_report", "playtest_sequence", "list_debugger_errors", "analyze_project_best_practices"],
		"flow": [
			"assert_scene_playable",
			"playtest_fix_loop max_attempts=3",
			"diagnose_playtest_failure on FAIL",
		],
	})


func _router_exec(method: String, params: Dictionary = {}) -> Dictionary:
	var r = get_parent()
	if r == null or not r.has_method("execute"):
		return {"error": {"message": "No router", "method": method}}
	return await r.execute(method, params)


func _playtest_fix_loop(params: Dictionary) -> Dictionary:
	## Run playtest_report up to max_attempts; collect failures + fix hints for agent.
	var max_attempts: int = clampi(optional_int(params, "max_attempts", 3), 1, 10)
	var mode: String = optional_string(params, "mode", "main")
	var settle: float = float(params.get("settle_sec", 1.2))
	var attempts: Array = []
	var passed := false
	for i in range(max_attempts):
		var report = await _router_exec("playtest_report", {
			"mode": mode,
			"path": optional_string(params, "path", ""),
			"settle_sec": settle,
			"stop_after": true,
			"screenshot": optional_bool(params, "screenshot", true),
			"asserts": params.get("asserts", []),
		})
		var payload = report.get("result", report)
		while payload is Dictionary and payload.has("result") and payload["result"] is Dictionary and payload.has("error") == false:
			# unwrap one level if double-wrapped success
			if payload.get("ok") != null or payload.get("summary") != null:
				break
			if payload.has("result") and not payload.has("ok"):
				payload = payload["result"]
			else:
				break
		var ok := false
		var summary := ""
		var errors: Array = []
		if payload is Dictionary:
			ok = bool(payload.get("ok", false))
			summary = str(payload.get("summary", ""))
			errors = payload.get("debugger_errors", [])
			if payload.has("error"):
				ok = false
		var diag = {}
		if not ok:
			diag = await _diagnose_playtest_failure({
				"debugger_errors": errors,
				"report": payload if payload is Dictionary else {},
			})
			diag = diag.get("result", diag)
		attempts.append({
			"attempt": i + 1,
			"ok": ok,
			"summary": summary,
			"debugger_errors": errors,
			"diagnosis": diag,
		})
		if ok:
			passed = true
			break
		# Brief pause between attempts
		await get_tree().create_timer(0.3).timeout
	return success({
		"passed": passed,
		"attempts": attempts,
		"count": attempts.size(),
		"agent_next": (
			["save_scene", "continue production"] if passed
			else ["read diagnosis.fix_hints", "edit_script / update_property", "playtest_fix_loop again"]
		),
	})


func _diagnose_playtest_failure(params: Dictionary) -> Dictionary:
	var errors: Array = params.get("debugger_errors", [])
	if errors.is_empty() and params.has("report") and params["report"] is Dictionary:
		errors = params["report"].get("debugger_errors", [])
	# Also pull live debugger errors
	var live := collect_debugger_errors(20)
	for e in live:
		if not (e in errors):
			errors.append(e)
	var hints: Array = []
	var files: Array = []
	for e in errors:
		var msg := str(e)
		var h := _hint_for_error(msg)
		hints.append(h)
		if h.has("script_path") and not str(h["script_path"]).is_empty():
			files.append(h["script_path"])
	# Scene-level checks
	var scene_issues: Array = []
	var root := get_edited_root()
	if root == null:
		scene_issues.append("No scene open — open_scene or create_scene")
	var main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main.is_empty():
		scene_issues.append("No main scene — set_main_scene")
	return success({
		"error_count": errors.size(),
		"errors": errors,
		"fix_hints": hints,
		"likely_scripts": files,
		"scene_issues": scene_issues,
		"suggested_tools": [
			"open_script_at_line",
			"edit_script",
			"validate_script",
			"list_property_info",
			"get_editor_errors",
		],
	})


func _hint_for_error(msg: String) -> Dictionary:
	var lower := msg.to_lower()
	var hint := {"message": msg, "category": "unknown", "action": "read error and describe_class related types"}
	# Parse res:// path:line if present
	var re := RegEx.new()
	re.compile("(res://[^\\s:]+):(\\d+)")
	var m := re.search(msg)
	if m:
		hint["script_path"] = m.get_string(1)
		hint["line"] = int(m.get_string(2))
		hint["action"] = "open_script_at_line path=%s line=%s then edit_script" % [m.get_string(1), m.get_string(2)]
	if lower.contains("null instance") or lower.contains("invalid get index"):
		hint["category"] = "null_ref"
		hint["action"] = "Check node paths / @onready; get_scene_tree + get_game_node_properties"
	elif lower.contains("parser error") or lower.contains("compile"):
		hint["category"] = "parse"
		hint["action"] = "validate_script + edit_script"
	elif lower.contains("not found") or lower.contains("cannot find"):
		hint["category"] = "missing_resource"
		hint["action"] = "ensure_imported / check res:// path with get_filesystem_tree"
	elif lower.contains("signal"):
		hint["category"] = "signal"
		hint["action"] = "get_signals + connect_signal / wire_signal_to_new_method"
	elif lower.contains("physics") or lower.contains("collision"):
		hint["category"] = "physics"
		hint["action"] = "get_collision_info / list_physics_shapes_in_scene"
	return hint


func _assert_scene_playable(params: Dictionary) -> Dictionary:
	## Pre-flight before play: main scene, root, scripts, optional collision/camera.
	var issues: Array = []
	var root := get_edited_root()
	var main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main.is_empty():
		issues.append({"severity": "error", "id": "no_main", "fix": "set_main_scene"})
	elif not ResourceLoader.exists(main) and not FileAccess.file_exists(main):
		issues.append({"severity": "error", "id": "main_missing", "message": main, "fix": "create_scene / set_main_scene"})
	if root == null and optional_bool(params, "require_open_scene", false):
		issues.append({"severity": "warning", "id": "no_open_scene", "fix": "open_scene"})
	if root:
		if optional_bool(params, "require_camera", false):
			if _count_class(root, "Camera2D") + _count_class(root, "Camera3D") == 0:
				issues.append({"severity": "warning", "id": "no_camera", "fix": "setup_camera_2d / setup_camera_3d_node"})
		if optional_bool(params, "require_player_group", false):
			var players := root.get_tree().get_nodes_in_group("player") if root.is_inside_tree() else []
			# edited tree may not have get_tree groups same way
			if not _has_group_meta(root, "player"):
				issues.append({"severity": "info", "id": "no_player_group", "fix": "set_node_groups group=player"})
	var errors := 0
	for i in issues:
		if str(i.get("severity")) == "error":
			errors += 1
	return success({
		"ok": errors == 0,
		"issues": issues,
		"main_scene": main,
		"has_open_scene": root != null,
	})


func _count_class(n: Node, cls: String) -> int:
	var c := 1 if n.is_class(cls) else 0
	for ch in n.get_children():
		c += _count_class(ch, cls)
	return c


func _has_group_meta(n: Node, group: String) -> bool:
	if n.is_in_group(group):
		return true
	for ch in n.get_children():
		if _has_group_meta(ch, group):
			return true
	return false
