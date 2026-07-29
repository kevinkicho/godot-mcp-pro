@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## InputMap export/import JSON — port actions between projects / version control.


func get_commands() -> Dictionary:
	return {
		"export_input_map_json": _export_json,
		"import_input_map_json": _import_json,
		"list_input_map_actions_detail": _list_detail,
		"clear_input_action_events": _clear_events,
		"list_input_map_io_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_input_map_preset", "set_input_action", "get_input_actions", "list_input_action_events"],
	})


func _event_to_dict(ev: InputEvent) -> Dictionary:
	var d := {"class": ev.get_class()}
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		d["keycode"] = k.keycode
		d["physical_keycode"] = k.physical_keycode
		d["key_label"] = k.key_label
		d["unicode"] = k.unicode
		d["shift"] = k.shift_pressed
		d["ctrl"] = k.ctrl_pressed
		d["alt"] = k.alt_pressed
		d["meta"] = k.meta_pressed
	elif ev is InputEventMouseButton:
		var m: InputEventMouseButton = ev as InputEventMouseButton
		d["button_index"] = m.button_index
		d["double_click"] = m.double_click
	elif ev is InputEventJoypadButton:
		var j: InputEventJoypadButton = ev as InputEventJoypadButton
		d["button_index"] = j.button_index
		d["device"] = j.device
	elif ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
		d["axis"] = jm.axis
		d["axis_value"] = jm.axis_value
		d["device"] = jm.device
	elif ev is InputEventAction:
		d["action"] = (ev as InputEventAction).action
		d["pressed"] = (ev as InputEventAction).pressed
	return d


func _dict_to_event(d: Dictionary) -> InputEvent:
	var cls: String = str(d.get("class", "InputEventKey"))
	match cls:
		"InputEventKey":
			var k := InputEventKey.new()
			if d.has("keycode"):
				k.keycode = int(d["keycode"]) as Key
			if d.has("physical_keycode"):
				k.physical_keycode = int(d["physical_keycode"]) as Key
			k.shift_pressed = bool(d.get("shift", false))
			k.ctrl_pressed = bool(d.get("ctrl", false))
			k.alt_pressed = bool(d.get("alt", false))
			k.meta_pressed = bool(d.get("meta", false))
			return k
		"InputEventMouseButton":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button_index", 1)) as MouseButton
			return m
		"InputEventJoypadButton":
			var j := InputEventJoypadButton.new()
			j.button_index = int(d.get("button_index", 0)) as JoyButton
			j.device = int(d.get("device", -1))
			return j
		"InputEventJoypadMotion":
			var jm := InputEventJoypadMotion.new()
			jm.axis = int(d.get("axis", 0)) as JoyAxis
			jm.axis_value = float(d.get("axis_value", 1.0))
			jm.device = int(d.get("device", -1))
			return jm
		_:
			return null


func _export_json(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://input_map.json")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var actions: Dictionary = {}
	for action in InputMap.get_actions():
		var an := str(action)
		if an.begins_with("ui_") and not optional_bool(params, "include_ui", false):
			continue
		var events: Array = []
		for ev in InputMap.action_get_events(action):
			events.append(_event_to_dict(ev))
		actions[an] = {
			"deadzone": InputMap.action_get_deadzone(action),
			"events": events,
		}
	var data := {
		"version": 1,
		"godot": Engine.get_version_info(),
		"actions": actions,
	}
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# Also mirror into ProjectSettings for persistence across restarts
	if optional_bool(params, "sync_project_settings", true):
		_sync_actions_to_project(actions)
	return success({
		"path": path,
		"action_count": actions.size(),
		"actions": actions.keys(),
	})


func _import_json(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://input_map.json")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot read")
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or not parsed.has("actions"):
		return error_internal("Invalid input_map JSON")
	var replace: bool = optional_bool(params, "replace_existing", true)
	var actions: Dictionary = parsed["actions"]
	var imported: Array = []
	for an in actions:
		var entry: Dictionary = actions[an]
		if not InputMap.has_action(an):
			InputMap.add_action(an, float(entry.get("deadzone", 0.5)))
		elif replace:
			InputMap.action_erase_events(an)
			if entry.has("deadzone"):
				InputMap.action_set_deadzone(an, float(entry["deadzone"]))
		if entry.has("events") and entry["events"] is Array:
			for ed in entry["events"]:
				if ed is Dictionary:
					var ev := _dict_to_event(ed)
					if ev:
						InputMap.action_add_event(an, ev)
		imported.append(str(an))
	if optional_bool(params, "save_project", true):
		_sync_actions_to_project(actions)
		ProjectSettings.save()
	return success({"path": path, "imported": imported, "count": imported.size()})


func _sync_actions_to_project(actions: Dictionary) -> void:
	## Best-effort: ProjectSettings input/* keys from live InputMap
	for an in actions:
		var events: Array = []
		if InputMap.has_action(an):
			for ev in InputMap.action_get_events(an):
				events.append(ev)
		var dead := 0.5
		if InputMap.has_action(an):
			dead = InputMap.action_get_deadzone(an)
		ProjectSettings.set_setting("input/" + str(an), {
			"deadzone": dead,
			"events": events,
		})


func _list_detail(params: Dictionary) -> Dictionary:
	var include_ui: bool = optional_bool(params, "include_ui", false)
	var out: Array = []
	for action in InputMap.get_actions():
		var an := str(action)
		if an.begins_with("ui_") and not include_ui:
			continue
		var events: Array = []
		for ev in InputMap.action_get_events(action):
			events.append(_event_to_dict(ev))
		out.append({
			"action": an,
			"deadzone": InputMap.action_get_deadzone(action),
			"events": events,
		})
	return success({"actions": out, "count": out.size()})


func _clear_events(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "action")
	if r0[1] != null:
		return r0[1]
	if not InputMap.has_action(r0[0]):
		return error_not_found("action '%s'" % r0[0])
	InputMap.action_erase_events(r0[0])
	if optional_bool(params, "save_project", true):
		ProjectSettings.set_setting("input/" + r0[0], {
			"deadzone": InputMap.action_get_deadzone(r0[0]),
			"events": [],
		})
		ProjectSettings.save()
	return success({"action": r0[0], "cleared": true})
