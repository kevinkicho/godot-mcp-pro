@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Dialogue runtime polish - graph validate, merge, typewriter UI, cinematic timeline cuts.


func get_commands() -> Dictionary:
	return {
		"validate_dialogue_graph_json": _validate_graph,
		"merge_dialogue_graphs": _merge_graphs,
		"create_dialogue_typewriter_ui_script": _typewriter,
		"setup_dialogue_balloon_ui": _setup_balloon,
		"create_cinematic_timeline_script": _timeline_script,
		"create_cinematic_timeline_json": _timeline_json,
		"setup_cinematic_timeline_player": _setup_timeline,
		"list_dialogue_runtime_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"create_dialogue_resource", "create_dialogue_runner_script", "setup_dialogue_box_ui",
		"create_cutscene_player_script", "create_simple_cutscene_json", "setup_cinematic_path_camera",
	], {
		"flow": [
			"create_dialogue_resource / create_cinematic_timeline_json",
			"validate_dialogue_graph_json",
			"setup_dialogue_balloon_ui + create_dialogue_typewriter_ui_script",
			"setup_cinematic_timeline_player for cuts/camera/dialogue mix",
		],
	})


func _load_json(path: String) -> Dictionary:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not FileAccess.file_exists(path):
		return {"error": "missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return {"data": data, "path": path}
	if data is Array:
		return {"data": {"lines": data}, "path": path}
	return {"error": "parse"}


func _validate_graph(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var loaded := _load_json(res[0])
	if loaded.has("error"):
		return error_not_found(res[0], "Need dialogue JSON")
	var data: Dictionary = loaded["data"]
	var lines: Array = data.get("lines", data.get("nodes", data.get("dialogue", [])))
	if lines is Dictionary:
		var arr: Array = []
		for k in lines:
			var item = lines[k]
			if item is Dictionary:
				var d: Dictionary = item.duplicate()
				if not d.has("id"):
					d["id"] = k
				arr.append(d)
		lines = arr
	var ids := {}
	var issues: Array = []
	var starts: Array = []
	for line in lines:
		if not line is Dictionary:
			issues.append({"type": "invalid_line", "line": str(line)})
			continue
		var id := str(line.get("id", ""))
		if id.is_empty():
			issues.append({"type": "missing_id", "speaker": line.get("speaker", "")})
			continue
		if ids.has(id):
			issues.append({"type": "duplicate_id", "id": id})
		ids[id] = true
		if bool(line.get("start", false)) or id == str(data.get("start", "")):
			starts.append(id)
	for line in lines:
		if not line is Dictionary:
			continue
		var id2 := str(line.get("id", ""))
		var next := str(line.get("next", ""))
		if not next.is_empty() and not ids.has(next):
			issues.append({"type": "dangling_next", "from": id2, "next": next})
		if line.has("choices") and line["choices"] is Array:
			for ch in line["choices"]:
				if ch is Dictionary:
					var cn := str(ch.get("next", ""))
					if not cn.is_empty() and not ids.has(cn):
						issues.append({"type": "dangling_choice", "from": id2, "next": cn, "text": ch.get("text", "")})
	if starts.is_empty() and lines.size() > 0 and lines[0] is Dictionary:
		starts.append(str(lines[0].get("id", "")))
	return success({
		"path": res[0],
		"line_count": lines.size() if lines is Array else 0,
		"id_count": ids.size(),
		"starts": starts,
		"issues": issues,
		"ok": issues.is_empty(),
	})


func _merge_graphs(params: Dictionary) -> Dictionary:
	## paths: [json, json] -> out_path merged lines (prefix ids optional)
	if not params.has("paths") or not params["paths"] is Array:
		return error_invalid_params("paths array required")
	var out_path: String = optional_string(params, "out_path", "res://dialogue/merged.json")
	var prefix: bool = optional_bool(params, "prefix_ids", true)
	var merged: Array = []
	var meta := {"title": optional_string(params, "title", "merged"), "sources": []}
	var i := 0
	for p in params["paths"]:
		var loaded := _load_json(str(p))
		if loaded.has("error"):
			continue
		(meta["sources"] as Array).append(loaded["path"])
		var data: Dictionary = loaded["data"]
		var lines: Array = data.get("lines", data.get("nodes", []))
		if lines is Dictionary:
			var arr2: Array = []
			for k in lines:
				var item = lines[k]
				if item is Dictionary:
					var d: Dictionary = item.duplicate()
					d["id"] = k if not d.has("id") else d["id"]
					arr2.append(d)
			lines = arr2
		for line in lines:
			if not line is Dictionary:
				continue
			var L: Dictionary = line.duplicate(true)
			var id := str(L.get("id", "line_%d" % merged.size()))
			if prefix:
				var pre := "g%d_" % i
				L["id"] = pre + id
				if L.has("next") and not str(L["next"]).is_empty():
					L["next"] = pre + str(L["next"])
				if L.has("choices") and L["choices"] is Array:
					var chs: Array = []
					for ch in L["choices"]:
						if ch is Dictionary:
							var c2: Dictionary = ch.duplicate()
							if c2.has("next") and not str(c2["next"]).is_empty():
								c2["next"] = pre + str(c2["next"])
							chs.append(c2)
					L["choices"] = chs
			merged.append(L)
		i += 1
	var payload := {"title": meta["title"], "sources": meta["sources"], "lines": merged, "start": str(merged[0]["id"]) if merged.size() > 0 else ""}
	var w := write_text_res(out_path, JSON.stringify(payload, "\t"), optional_bool(params, "overwrite", true))
	if w.has("error"):
		return w
	return success({"path": out_path, "line_count": merged.size(), "sources": meta["sources"]})


func _typewriter(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/dialogue_typewriter.gd")
	var content := """extends RichTextLabel
class_name DialogueTypewriter
## Typewriter reveal for dialogue balloons.

signal finished
signal character_shown(ch: String)

@export var chars_per_second: float = 40.0
@export var skip_action: StringName = &\"ui_accept\"

var _full: String = \"\"
var _t: float = 0.0
var _playing: bool = false

func play_text(text: String) -> void:
	_full = text
	_t = 0.0
	_playing = true
	bbcode_enabled = true
	text = \"\"

func skip() -> void:
	if not _playing:
		return
	text = _full
	_playing = false
	finished.emit()

func is_playing() -> bool:
	return _playing

func _process(delta: float) -> void:
	if not _playing:
		return
	if Input.is_action_just_pressed(skip_action):
		skip()
		return
	_t += delta
	var n := int(_t * chars_per_second)
	if n >= _full.length():
		text = _full
		_playing = false
		finished.emit()
	else:
		var next_text := _full.substr(0, n)
		if next_text != text:
			var ch := _full.substr(n - 1, 1) if n > 0 else \"\"
			text = next_text
			if not ch.is_empty():
				character_shown.emit(ch)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "DialogueTypewriter"})


func _setup_balloon(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "DialogueBalloon")
	layer.layer = optional_int(params, "layer", 40)
	add_child_with_undo(parent, layer, root, "MCP: Dialogue balloon")
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.72
	panel.anchor_bottom = 0.95
	add_child_with_undo(layer, panel, root, "MCP: panel")
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: vbox")
	var speaker := Label.new()
	speaker.name = "Speaker"
	speaker.text = "NPC"
	add_child_with_undo(vbox, speaker, root, "MCP: speaker")
	var body := RichTextLabel.new()
	body.name = "Body"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(0, 80)
	body.text = "..."
	add_child_with_undo(vbox, body, root, "MCP: body")
	var choices := VBoxContainer.new()
	choices.name = "Choices"
	add_child_with_undo(vbox, choices, root, "MCP: choices")
	var tw_path: String = optional_string(params, "typewriter_script", "res://scripts/dialogue_typewriter.gd")
	if not FileAccess.file_exists(tw_path):
		_typewriter({"path": tw_path, "overwrite": false})
	var scr: Script = load(tw_path)
	if scr:
		body.set_script(scr)
	mark_current_scene_unsaved()
	return success({
		"layer_path": str(root.get_path_to(layer)),
		"speaker_path": str(root.get_path_to(speaker)),
		"body_path": str(root.get_path_to(body)),
		"choices_path": str(root.get_path_to(choices)),
	})


func _timeline_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/cinematic_timeline.gd")
	var content := """extends Node
## Cinematic timeline: ordered tracks of camera/dialogue/wait/signal/call steps.

signal step_started(index: int, step: Dictionary)
signal step_finished(index: int, step: Dictionary)
signal timeline_finished

@export_file(\"*.json\") var timeline_path: String = \"\"
@export var autoplay: bool = false

var _steps: Array = []
var _i: int = -1
var _playing: bool = false
var _busy: bool = false

func _ready() -> void:
	if autoplay and not timeline_path.is_empty():
		load_timeline(timeline_path)
		play()

func load_timeline(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error(\"timeline missing: %s\" % path)
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary and data.has(\"steps\"):
		_steps = data[\"steps\"]
	elif data is Array:
		_steps = data

func play() -> void:
	_playing = true
	_i = -1
	_advance()

func _advance() -> void:
	if not _playing or _busy:
		return
	_i += 1
	if _i >= _steps.size():
		_playing = false
		timeline_finished.emit()
		return
	var step: Dictionary = _steps[_i]
	step_started.emit(_i, step)
	_busy = true
	await _run(step)
	_busy = false
	step_finished.emit(_i, step)
	_advance()

func _run(step: Dictionary) -> void:
	match str(step.get(\"type\", \"wait\")).to_lower():
		\"wait\":
			await get_tree().create_timer(float(step.get(\"seconds\", 1.0))).timeout
		\"dialogue\":
			get_tree().call_group(\"dialogue_ui\", \"show_line\", step.get(\"speaker\", \"\"), step.get(\"text\", \"\"))
			await get_tree().create_timer(float(step.get(\"seconds\", 2.0))).timeout
		\"camera\":
			var np := str(step.get(\"node_path\", \"\"))
			if not np.is_empty() and has_node(np):
				var cam = get_node(np)
				if cam is Camera3D:
					cam.current = true
				elif cam is Camera2D:
					cam.make_current()
			if step.has(\"seconds\"):
				await get_tree().create_timer(float(step[\"seconds\"])).timeout
		\"cut\":
			# hard cut: optional fade signal
			get_tree().call_group(\"cinematic\", \"_on_cut\", step)
			await get_tree().process_frame
		\"signal\":
			get_tree().call_group(\"cinematic\", \"_on_cinematic_event\", str(step.get(\"name\", \"event\")), step)
		\"call\":
			var npp := str(step.get(\"node_path\", \".\"))
			var method := str(step.get(\"method\", \"\"))
			if not method.is_empty() and has_node(npp):
				var n = get_node(npp)
				if n.has_method(method):
					n.callv(method, step.get(\"args\", []))
		\"scene\":
			var sp := str(step.get(\"path\", \"\"))
			if not sp.is_empty():
				get_tree().change_scene_to_file(sp)
		_:
			await get_tree().process_frame
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path})


func _timeline_json(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://cinematics/intro_timeline.json")
	var steps: Array = params.get("steps", [])
	if steps.is_empty():
		steps = [
			{"type": "cut", "name": "black"},
			{"type": "camera", "node_path": "CinematicCamera", "seconds": 0.1},
			{"type": "dialogue", "speaker": "Narrator", "text": "It begins.", "seconds": 2.5},
			{"type": "wait", "seconds": 0.5},
			{"type": "signal", "name": "intro_done"},
		]
	var data := {
		"title": optional_string(params, "title", "Intro"),
		"steps": steps,
	}
	var w := write_text_res(path, JSON.stringify(data, "\t"), optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": path, "step_count": steps.size()})


func _setup_timeline(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var script_path: String = optional_string(params, "script_path", "res://scripts/cinematic_timeline.gd")
	if not FileAccess.file_exists(script_path):
		_timeline_script({"path": script_path, "overwrite": false})
	var n := Node.new()
	n.name = optional_string(params, "name", "CinematicTimeline")
	var scr: Script = load(script_path)
	if scr:
		n.set_script(scr)
	if params.has("timeline_path") and "timeline_path" in n:
		n.set("timeline_path", str(params["timeline_path"]))
	if params.has("autoplay") and "autoplay" in n:
		n.set("autoplay", bool(params["autoplay"]))
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_with_undo(parent, n, root, "MCP: CinematicTimeline")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(n)),
		"script_path": script_path,
		"timeline_path": params.get("timeline_path", ""),
	})
