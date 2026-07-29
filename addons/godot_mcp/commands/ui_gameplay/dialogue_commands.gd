@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Project-neutral dialogue + cutscene helpers (resources + runner script).
## Not a full dialogue plugin - structured data agents can author and play.


func get_commands() -> Dictionary:
	return {
		"create_dialogue_resource": _create_dialogue_resource,
		"create_cutscene_resource": _create_cutscene_resource,
		"create_dialogue_runner_script": _create_dialogue_runner_script,
		# create_cutscene_player_script canonical in cutscene_commands
		"list_dialogue_recipes": _list_dialogue_recipes,
	}


func _list_dialogue_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"dialogue_line": {
			"id": "line_id",
			"speaker": "NPC",
			"text": "Hello",
			"next": "line_2",
			"choices": [{"text": "Yes", "next": "yes_branch"}, {"text": "No", "next": "no_branch"}],
		},
		"cutscene_step_types": ["wait", "dialogue", "animate", "move", "signal", "set_property", "call"],
		"flow": "create_dialogue_resource -> create_dialogue_runner_script -> attach runner -> load resource path",
	})


func _create_dialogue_resource(params: Dictionary) -> Dictionary:
	## Writes a JSON dialogue graph under res:// (easy for agents to edit).
	var path: String = optional_string(params, "path", "res://dialogue/example_dialogue.json")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var start: String = optional_string(params, "start", "start")
	var lines: Array = params.get("lines", [])
	if not lines is Array or lines.is_empty():
		lines = [
			{"id": "start", "speaker": "Guide", "text": "Welcome.", "next": "ask"},
			{
				"id": "ask",
				"speaker": "Guide",
				"text": "Ready to begin?",
				"choices": [
					{"text": "Yes", "next": "yes"},
					{"text": "Not yet", "next": "no"},
				],
			},
			{"id": "yes", "speaker": "Guide", "text": "Great - let's go.", "next": ""},
			{"id": "no", "speaker": "Guide", "text": "Take your time.", "next": ""},
		]
	var data := {
		"start": start,
		"lines": lines,
		"meta": {
			"created_by": "godot-mcp",
			"version": 1,
		},
	}
	var text := JSON.stringify(data, "\t")
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(text)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "start": start, "line_count": lines.size(), "type": "dialogue_json"})


func _create_cutscene_resource(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://cutscenes/example_cutscene.json")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var steps: Array = params.get("steps", [])
	if not steps is Array or steps.is_empty():
		steps = [
			{"type": "wait", "seconds": 0.5},
			{"type": "dialogue", "speaker": "Narrator", "text": "A new adventure begins..."},
			{"type": "wait", "seconds": 1.0},
			{"type": "signal", "name": "cutscene_finished"},
		]
	var data := {
		"name": optional_string(params, "name", "ExampleCutscene"),
		"steps": steps,
		"meta": {"created_by": "godot-mcp", "version": 1},
	}
	var text := JSON.stringify(data, "\t")
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(text)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "step_count": steps.size(), "type": "cutscene_json"})


func _create_dialogue_runner_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/dialogue_runner.gd")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var content := """extends Node
## MCP dialogue runner - loads JSON from create_dialogue_resource.
signal line_shown(speaker: String, text: String)
signal choices_presented(choices: Array)
signal dialogue_finished
signal choice_selected(index: int, next_id: String)

@export_file("*.json") var dialogue_path: String = ""
var _data: Dictionary = {}
var _current_id: String = ""

func load_dialogue(path: String = "") -> Error:
	if not path.is_empty():
		dialogue_path = path
	if dialogue_path.is_empty() or not FileAccess.file_exists(dialogue_path):
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(dialogue_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	_data = parsed
	return OK

func start(at_id: String = "") -> void:
	if _data.is_empty() and load_dialogue() != OK:
		push_error("DialogueRunner: failed to load dialogue")
		return
	_current_id = at_id if not at_id.is_empty() else str(_data.get("start", "start"))
	_show_current()

func _find_line(id: String) -> Dictionary:
	for line in _data.get("lines", []):
		if line is Dictionary and str(line.get("id", "")) == id:
			return line
	return {}

func _show_current() -> void:
	if _current_id.is_empty():
		dialogue_finished.emit()
		return
	var line := _find_line(_current_id)
	if line.is_empty():
		dialogue_finished.emit()
		return
	var speaker := str(line.get("speaker", ""))
	var text := str(line.get("text", ""))
	line_shown.emit(speaker, text)
	var choices: Array = line.get("choices", [])
	if choices is Array and choices.size() > 0:
		choices_presented.emit(choices)
	# auto-advance if no choices and next set - caller may call advance()

func advance() -> void:
	var line := _find_line(_current_id)
	if line.is_empty():
		dialogue_finished.emit()
		return
	var choices: Array = line.get("choices", [])
	if choices is Array and choices.size() > 0:
		return  # wait for select_choice
	_current_id = str(line.get("next", ""))
	if _current_id.is_empty():
		dialogue_finished.emit()
	else:
		_show_current()

func select_choice(index: int) -> void:
	var line := _find_line(_current_id)
	var choices: Array = line.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var ch: Dictionary = choices[index]
	var next_id := str(ch.get("next", ""))
	choice_selected.emit(index, next_id)
	_current_id = next_id
	if _current_id.is_empty():
		dialogue_finished.emit()
	else:
		_show_current()
"""
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "created": true})


func _create_cutscene_player_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/cutscene_player.gd")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var content := """extends Node
## MCP cutscene player - sequential JSON steps from create_cutscene_resource.
signal step_started(index: int, step: Dictionary)
signal cutscene_finished
signal dialogue_line(speaker: String, text: String)

@export_file("*.json") var cutscene_path: String = ""
var _steps: Array = []
var _index: int = 0
var _playing: bool = false

func load_cutscene(path: String = "") -> Error:
	if not path.is_empty():
		cutscene_path = path
	if cutscene_path.is_empty() or not FileAccess.file_exists(cutscene_path):
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(cutscene_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	_steps = parsed.get("steps", [])
	return OK

func play() -> void:
	if _steps.is_empty() and load_cutscene() != OK:
		push_error("CutscenePlayer: failed to load")
		return
	_index = 0
	_playing = true
	_run_next()

func _run_next() -> void:
	if not _playing:
		return
	if _index >= _steps.size():
		_playing = false
		cutscene_finished.emit()
		return
	var step: Dictionary = _steps[_index]
	step_started.emit(_index, step)
	var t := str(step.get("type", "wait"))
	match t:
		"wait":
			var sec := float(step.get("seconds", 1.0))
			await get_tree().create_timer(sec).timeout
		"dialogue":
			dialogue_line.emit(str(step.get("speaker", "")), str(step.get("text", "")))
			await get_tree().create_timer(float(step.get("seconds", 2.0))).timeout
		"signal":
			var sig := str(step.get("name", "cutscene_event"))
			if has_signal(sig):
				emit_signal(sig)
			else:
				# generic notify
				print("[Cutscene] signal ", sig)
		"set_property":
			var np := str(step.get("node_path", "."))
			var node := get_node_or_null(np)
			if node and step.has("property"):
				node.set(str(step["property"]), step.get("value"))
		"call":
			var np2 := str(step.get("node_path", "."))
			var node2 := get_node_or_null(np2)
			var method := str(step.get("method", ""))
			if node2 and node2.has_method(method):
				node2.call(method)
		_:
			await get_tree().process_frame
	_index += 1
	_run_next()

func stop() -> void:
	_playing = false
"""
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "created": true})
