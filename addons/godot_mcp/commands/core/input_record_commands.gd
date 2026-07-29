@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Input record/replay manifests for agent playtest scripts.


func get_commands() -> Dictionary:
	return {
		"write_input_replay_manifest": _write_input_replay_manifest,
		"run_input_replay_manifest": _run_input_replay_manifest,
		"list_input_record_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["simulate_sequence", "playtest_sequence", "simulate_action"],
		"format": {
			"events": [
				{"type": "action", "action": "ui_right", "pressed": true},
				{"type": "wait", "sec": 0.2},
				{"type": "action", "action": "ui_right", "pressed": false},
			],
		},
	})


func _write_input_replay_manifest(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://test/input_replay.json")
	if not path.begins_with("res://") and not path.begins_with("user://"):
		path = "res://" + path.trim_prefix("/")
	var events: Array = params.get("events", [])
	if events.is_empty():
		events = [
			{"type": "wait", "sec": 0.5},
			{"type": "action", "action": "ui_accept", "pressed": true},
			{"type": "wait", "sec": 0.1},
			{"type": "action", "action": "ui_accept", "pressed": false},
		]
	var data := {
		"version": 1,
		"name": optional_string(params, "name", "replay"),
		"events": events,
	}
	ensure_parent_dir(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write")
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if path.begins_with("res://"):
		EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "event_count": events.size()})


func _run_input_replay_manifest(params: Dictionary) -> Dictionary:
	## Load manifest and play via playtest_sequence steps conversion.
	var path: String = optional_string(params, "path", "")
	if path.is_empty():
		return error_invalid_params("path required")
	if not path.begins_with("res://") and not path.begins_with("user://"):
		path = "res://" + path.trim_prefix("/")
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return error_internal("Invalid JSON")
	f.close()
	var events: Array = []
	if j.data is Dictionary:
		events = j.data.get("events", [])
	var steps: Array = []
	for e in events:
		if not e is Dictionary:
			continue
		var t := str(e.get("type", ""))
		if t == "wait" or t == "delay":
			steps.append({"type": "wait", "sec": float(e.get("sec", e.get("seconds", 0.2)))})
		else:
			# pass through as playtest_sequence step
			var step := e.duplicate()
			if not step.has("type"):
				step["type"] = t if not t.is_empty() else "action"
			steps.append(step)
	var router = get_parent()
	if router == null or not router.has_method("execute"):
		return error_internal("No router")
	return await router.execute("playtest_sequence", {
		"mode": optional_string(params, "mode", "main"),
		"path": optional_string(params, "scene_path", ""),
		"settle_sec": float(params.get("settle_sec", 0.8)),
		"stop_after": optional_bool(params, "stop_after", true),
		"steps": steps,
	})
