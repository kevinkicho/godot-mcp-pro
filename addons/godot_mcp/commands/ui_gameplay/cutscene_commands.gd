@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Cutscene / timeline sequencer scripts - agent-friendly linear storytelling.


func get_commands() -> Dictionary:
	return {
		"create_cutscene_player_script": _create_player,
		"create_cutscene_sequence_resource_script": _create_sequence_res,
		"setup_cutscene_player_node": _setup_node,
		"create_simple_cutscene_json": _create_json,
		"list_cutscene_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_dialogue_box_ui", "create_camera_shake_script", "setup_camera_2d",
		"setup_path_follow", "create_tween_helper_script", "set_process_mode",
	], {
		"flow": [
			"create_cutscene_player_script",
			"create_simple_cutscene_json path=res://cutscenes/intro.json",
			"setup_cutscene_player_node sequence_path=...",
			"playtest_report",
		],
	})


func _create_player(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/cutscene_player.gd")
	var content := """extends Node
## MCP CutscenePlayer - plays step lists (JSON or exported Array).
## Steps: {type, ...} where type in wait|dialogue|camera|signal|call|property|scene
signal step_started(index: int, step: Dictionary)
signal step_finished(index: int, step: Dictionary)
signal cutscene_finished
signal dialogue_requested(text: String, speaker: String)

@export_file(\"*.json\") var sequence_path: String = \"\"
@export var autoplay: bool = false
@export var skip_action: StringName = &\"ui_cancel\"

var _steps: Array = []
var _index: int = -1
var _playing: bool = false
var _busy: bool = false

func _ready() -> void:
	if autoplay and not sequence_path.is_empty():
		load_sequence(sequence_path)
		play()

func _unhandled_input(event: InputEvent) -> void:
	if _playing and event.is_action_pressed(skip_action):
		skip()

func load_sequence(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error(\"Cutscene: cannot open %s\" % path)
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary and data.has(\"steps\"):
		_steps = data[\"steps\"]
	elif data is Array:
		_steps = data
	else:
		push_error(\"Cutscene: expected {steps:[...]} or array\")

func set_steps(steps: Array) -> void:
	_steps = steps.duplicate(true)

func play() -> void:
	if _steps.is_empty():
		push_warning(\"Cutscene: no steps\")
		return
	_playing = true
	_index = -1
	_advance()

func skip() -> void:
	if not _playing:
		return
	_busy = false
	_finish()

func is_playing() -> bool:
	return _playing

func _advance() -> void:
	if not _playing or _busy:
		return
	_index += 1
	if _index >= _steps.size():
		_finish()
		return
	var step: Dictionary = _steps[_index]
	step_started.emit(_index, step)
	_busy = true
	await _run_step(step)
	_busy = false
	step_finished.emit(_index, step)
	_advance()

func _run_step(step: Dictionary) -> void:
	var t := str(step.get(\"type\", \"wait\")).to_lower()
	match t:
		\"wait\":
			await get_tree().create_timer(float(step.get(\"seconds\", 1.0))).timeout
		\"dialogue\":
			dialogue_requested.emit(str(step.get(\"text\", \"\")), str(step.get(\"speaker\", \"\")))
			var hold := float(step.get(\"seconds\", 2.0))
			if hold > 0.0:
				await get_tree().create_timer(hold).timeout
		\"camera\":
			var path := str(step.get(\"node_path\", \"\"))
			if not path.is_empty() and has_node(path):
				var cam = get_node(path)
				if cam is Camera2D:
					cam.make_current()
				elif cam is Camera3D:
					cam.current = true
			if step.has(\"seconds\"):
				await get_tree().create_timer(float(step[\"seconds\"])).timeout
		\"signal\":
			var sig := str(step.get(\"name\", \"cutscene_event\"))
			if has_signal(sig):
				emit_signal(sig)
			else:
				# Generic bus via group
				get_tree().call_group(\"cutscene_listeners\", \"_on_cutscene_event\", sig, step)
		\"call\":
			var np := str(step.get(\"node_path\", \".\"))
			var method := str(step.get(\"method\", \"\"))
			if not method.is_empty() and has_node(np):
				var n = get_node(np)
				if n.has_method(method):
					var args: Array = step.get(\"args\", [])
					n.callv(method, args)
		\"property\":
			var np2 := str(step.get(\"node_path\", \"\"))
			var prop := str(step.get(\"property\", \"\"))
			if not np2.is_empty() and not prop.is_empty() and has_node(np2):
				get_node(np2).set(prop, step.get(\"value\"))
		\"scene\":
			var scene_path := str(step.get(\"path\", \"\"))
			if not scene_path.is_empty():
				get_tree().change_scene_to_file(scene_path)
		_:
			push_warning(\"Cutscene: unknown step type %s\" % t)

func _finish() -> void:
	_playing = false
	_busy = false
	cutscene_finished.emit()
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	if optional_bool(params, "add_autoload", false):
		maybe_add_autoload(params, path, "CutscenePlayer")
	return success({"path": path, "type": "CutscenePlayer"})


func _create_sequence_res(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/cutscene_sequence.gd")
	var content := """extends Resource
class_name CutsceneSequence
## Optional Resource wrapper for cutscene steps (edit in inspector).
@export var id: String = \"intro\"
@export var steps: Array[Dictionary] = []
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "CutsceneSequence"})


func _setup_node(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var script_path: String = optional_string(params, "script_path", "res://scripts/cutscene_player.gd")
	if not FileAccess.file_exists(script_path):
		var created := _create_player({"path": script_path, "overwrite": false})
		if created.has("error") and int(created["error"].get("code", 0)) != -32000:
			return created
	var n := Node.new()
	n.name = optional_string(params, "name", "CutscenePlayer")
	var scr: Script = load(script_path)
	if scr:
		n.set_script(scr)
	if params.has("sequence_path") and "sequence_path" in n:
		n.set("sequence_path", str(params["sequence_path"]))
	if params.has("autoplay") and "autoplay" in n:
		n.set("autoplay", bool(params["autoplay"]))
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_with_undo(parent, n, root, "MCP: CutscenePlayer")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(n)),
		"script_path": script_path,
		"sequence_path": params.get("sequence_path", ""),
	})


func _create_json(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://cutscenes/intro.json")
	var title: String = optional_string(params, "title", "Intro")
	var steps: Array = params.get("steps", [])
	if steps.is_empty():
		steps = [
			{"type": "wait", "seconds": 0.5},
			{"type": "dialogue", "speaker": "Narrator", "text": "Welcome.", "seconds": 2.0},
			{"type": "wait", "seconds": 0.3},
			{"type": "signal", "name": "intro_done"},
		]
	var data := {"title": title, "steps": steps}
	var text := JSON.stringify(data, "\t")
	var w := write_text_res(path, text, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": path, "step_count": steps.size(), "title": title})
