@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Quest + dialogue graph systems for narrative / RPG / adventure games.


func get_commands() -> Dictionary:
	return {
		"create_quest_resource": _create_quest_resource,
		"create_quest_log_script": _create_quest_log_script,
		"create_dialogue_graph_resource": _create_dialogue_graph_resource,
		"validate_dialogue_graph": _validate_dialogue_graph,
		"merge_dialogue_lines": _merge_dialogue_lines,
		"create_quest_giver_script": _create_quest_giver_script,
		"create_objective_tracker_script": _create_objective_tracker_script,
		"list_quest_recipes": _list_quest_recipes,
	}


func _list_quest_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"quest_resource": {
			"id": "main_intro",
			"title": "Wake Up",
			"description": "Leave the village",
			"objectives": [
				{"id": "talk_elder", "text": "Talk to the elder", "type": "talk", "target": "elder", "required": 1},
				{"id": "reach_gate", "text": "Reach the gate", "type": "reach", "target": "gate", "required": 1},
			],
			"rewards": {"xp": 50, "items": [{"id": "potion", "count": 1}]},
			"next_quests": ["forest_path"],
		},
		"dialogue_graph": "nodes keyed by id with text/choices/quest_start/quest_complete/set_flag",
		"flow": [
			"create_quest_resource",
			"create_quest_log_script (autoload)",
			"create_dialogue_graph_resource",
			"setup_dialogue_box_ui + create_dialogue_runner or quest_giver",
		],
	})


func _write_json(path: String, data: Dictionary, overwrite: bool) -> Dictionary:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return {"path": path}


func _write_script(path: String, content: String, overwrite: bool) -> Dictionary:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return {"path": path}


func _create_quest_resource(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://quests/example_quest.json")
	var quest_id: String = optional_string(params, "id", "example_quest")
	var title: String = optional_string(params, "title", "Example Quest")
	var description: String = optional_string(params, "description", "Do the thing.")
	var objectives: Array = params.get("objectives", [])
	if not objectives is Array or objectives.is_empty():
		objectives = [
			{"id": "obj1", "text": "Talk to the NPC", "type": "talk", "target": "npc", "required": 1},
			{"id": "obj2", "text": "Collect items", "type": "collect", "target": "herb", "required": 3},
		]
	var data := {
		"id": quest_id,
		"title": title,
		"description": description,
		"auto_start": optional_bool(params, "auto_start", false),
		"objectives": objectives,
		"rewards": params.get("rewards", {"xp": 10, "items": []}),
		"next_quests": params.get("next_quests", []),
		"prerequisites": params.get("prerequisites", []),
		"meta": {"created_by": "godot-mcp", "version": 1},
	}
	if params.has("extra") and params["extra"] is Dictionary:
		for k in params["extra"]:
			data[str(k)] = params["extra"][k]
	var w := _write_json(path, data, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "id": quest_id, "objective_count": objectives.size()})


func _create_quest_log_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/quest_log.gd")
	var content := """extends Node
## MCP QuestLog autoload — track quests/objectives from JSON resources.

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal objective_progress(quest_id: String, objective_id: String, current: int, required: int)

## quest_id -> { data, status: inactive|active|completed, progress: {obj_id: count} }
var quests: Dictionary = {}

func load_quest_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var qid := str(parsed.get("id", path.get_file().get_basename()))
	quests[qid] = {
		"data": parsed,
		"status": "inactive",
		"progress": {},
	}
	for obj in parsed.get("objectives", []):
		if obj is Dictionary:
			quests[qid]["progress"][str(obj.get("id", ""))] = 0
	if parsed.get("auto_start", false):
		start_quest(qid)
	return true

func start_quest(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	if quests[quest_id]["status"] == "completed":
		return false
	quests[quest_id]["status"] = "active"
	quest_started.emit(quest_id)
	return true

func is_active(quest_id: String) -> bool:
	return quests.has(quest_id) and quests[quest_id]["status"] == "active"

func is_completed(quest_id: String) -> bool:
	return quests.has(quest_id) and quests[quest_id]["status"] == "completed"

func report(event_type: String, target: String, amount: int = 1) -> void:
	## Call from gameplay: QuestLog.report("talk", "elder") or report("collect", "herb", 1)
	for qid in quests:
		var q: Dictionary = quests[qid]
		if q["status"] != "active":
			continue
		for obj in q["data"].get("objectives", []):
			if not obj is Dictionary:
				continue
			if str(obj.get("type", "")) != event_type:
				continue
			if str(obj.get("target", "")) != target and not target.is_empty():
				if str(obj.get("target", "")) != target:
					continue
			var oid := str(obj.get("id", ""))
			var req := int(obj.get("required", 1))
			var cur: int = int(q["progress"].get(oid, 0)) + amount
			q["progress"][oid] = mini(cur, req)
			objective_progress.emit(qid, oid, q["progress"][oid], req)
		_try_complete(qid)

func _try_complete(quest_id: String) -> void:
	var q: Dictionary = quests[quest_id]
	for obj in q["data"].get("objectives", []):
		if not obj is Dictionary:
			continue
		var oid := str(obj.get("id", ""))
		var req := int(obj.get("required", 1))
		if int(q["progress"].get(oid, 0)) < req:
			return
	q["status"] = "completed"
	quest_completed.emit(quest_id)
	for nq in q["data"].get("next_quests", []):
		if quests.has(str(nq)):
			start_quest(str(nq))

func get_active_summaries() -> Array:
	var out: Array = []
	for qid in quests:
		var q: Dictionary = quests[qid]
		if q["status"] != "active":
			continue
		var objs: Array = []
		for obj in q["data"].get("objectives", []):
			if obj is Dictionary:
				var oid := str(obj.get("id", ""))
				objs.append({
					"id": oid,
					"text": obj.get("text", ""),
					"current": q["progress"].get(oid, 0),
					"required": obj.get("required", 1),
				})
		out.append({"id": qid, "title": q["data"].get("title", qid), "objectives": objs})
	return out
"""
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", true):
		var aname: String = optional_string(params, "autoload_name", "QuestLog")
		if not ProjectSettings.has_setting("autoload/" + aname):
			ProjectSettings.set_setting("autoload/" + aname, "*" + w["path"])
			ProjectSettings.save()
			al = true
	return success({"path": w["path"], "autoload_added": al})


func _create_dialogue_graph_resource(params: Dictionary) -> Dictionary:
	## Node-keyed dialogue graph (richer than flat lines array).
	var path: String = optional_string(params, "path", "res://dialogue/graph_example.json")
	var start: String = optional_string(params, "start", "start")
	var nodes: Dictionary = {}
	if params.has("nodes") and params["nodes"] is Dictionary:
		nodes = params["nodes"]
	elif params.has("lines") and params["lines"] is Array:
		# Convert lines array → nodes map
		for line in params["lines"]:
			if line is Dictionary and line.has("id"):
				var n: Dictionary = line.duplicate()
				var nid: String = str(n["id"])
				n.erase("id")
				nodes[nid] = n
	if nodes.is_empty():
		nodes = {
			"start": {
				"speaker": "Villager",
				"text": "The forest is dangerous.",
				"choices": [
					{"text": "I'll help", "next": "accept", "quest_start": "forest_path"},
					{"text": "Not now", "next": "decline"},
				],
			},
			"accept": {
				"speaker": "Villager",
				"text": "Bless you. Find the elder first.",
				"set_flag": {"helped_villager": true},
				"next": "",
			},
			"decline": {
				"speaker": "Villager",
				"text": "Come back when ready.",
				"next": "",
			},
		}
	var data := {
		"start": start,
		"nodes": nodes,
		"meta": {"created_by": "godot-mcp", "version": 2, "format": "graph"},
	}
	var w := _write_json(path, data, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "start": start, "node_count": nodes.size(), "format": "graph"})


func _validate_dialogue_graph(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return error_invalid_params("Not a JSON object")
	var issues: Array = []
	var warnings: Array = []
	var start: String = str(parsed.get("start", ""))
	var nodes: Dictionary = {}
	if parsed.has("nodes") and parsed["nodes"] is Dictionary:
		nodes = parsed["nodes"]
	elif parsed.has("lines") and parsed["lines"] is Array:
		for line in parsed["lines"]:
			if line is Dictionary and line.has("id"):
				nodes[str(line["id"])] = line
	else:
		issues.append("Missing nodes{} or lines[]")
	if start.is_empty():
		issues.append("Missing start id")
	elif not nodes.has(start):
		issues.append("start '%s' not in nodes" % start)
	var reachable: Dictionary = {}
	if nodes.has(start):
		_dfs_dialogue(start, nodes, reachable)
	for nid in nodes:
		if not reachable.has(nid):
			warnings.append("Unreachable node: %s" % nid)
		var n: Variant = nodes[nid]
		if not n is Dictionary:
			issues.append("Node %s is not an object" % nid)
			continue
		var next := str(n.get("next", ""))
		if not next.is_empty() and not nodes.has(next):
			issues.append("Node %s next→ missing '%s'" % [nid, next])
		if n.has("choices") and n["choices"] is Array:
			for ch in n["choices"]:
				if ch is Dictionary:
					var cn := str(ch.get("next", ""))
					if not cn.is_empty() and not nodes.has(cn):
						issues.append("Node %s choice next→ missing '%s'" % [nid, cn])
	return success({
		"path": path,
		"ok": issues.is_empty(),
		"issues": issues,
		"warnings": warnings,
		"node_count": nodes.size(),
		"reachable_count": reachable.size(),
	})


func _dfs_dialogue(id: String, nodes: Dictionary, seen: Dictionary) -> void:
	if seen.has(id) or not nodes.has(id):
		return
	seen[id] = true
	var n: Variant = nodes[id]
	if not n is Dictionary:
		return
	var next := str(n.get("next", ""))
	if not next.is_empty():
		_dfs_dialogue(next, nodes, seen)
	if n.has("choices") and n["choices"] is Array:
		for ch in n["choices"]:
			if ch is Dictionary:
				var cn := str(ch.get("next", ""))
				if not cn.is_empty():
					_dfs_dialogue(cn, nodes, seen)


func _merge_dialogue_lines(params: Dictionary) -> Dictionary:
	## Append/merge lines into an existing dialogue JSON.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if not params.has("lines") and not params.has("nodes"):
		return error_invalid_params("Provide lines[] or nodes{}")
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			data = parsed
	if not data.has("nodes"):
		data["nodes"] = {}
	if not data.has("start"):
		data["start"] = optional_string(params, "start", "start")
	var added: Array = []
	if params.has("nodes") and params["nodes"] is Dictionary:
		for k in params["nodes"]:
			data["nodes"][str(k)] = params["nodes"][k]
			added.append(str(k))
	if params.has("lines") and params["lines"] is Array:
		for line in params["lines"]:
			if line is Dictionary and line.has("id"):
				var nid := str(line["id"])
				var n: Dictionary = line.duplicate()
				n.erase("id")
				data["nodes"][nid] = n
				added.append(nid)
	if params.has("start") and str(params["start"]) != "":
		data["start"] = str(params["start"])
	var w := _write_json(path, data, true)
	if w.has("error"):
		return w
	return success({"path": path, "added": added, "node_count": data["nodes"].size()})


func _create_quest_giver_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/quest_giver.gd")
	var content := """extends Area2D
## MCP quest giver — on interact, starts quest + optional dialogue.

@export var quest_id: String = ""
@export var dialogue_path: String = ""
@export var interact_action: String = "interact"

signal dialogue_requested(path: String)
signal quest_offered(quest_id: String)

var _player_near: bool = false

func _ready() -> void:
	body_entered.connect(func(b):
		if b.is_in_group("player"):
			_player_near = true
	)
	body_exited.connect(func(b):
		if b.is_in_group("player"):
			_player_near = false
	)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_near:
		return
	if event.is_action_pressed(interact_action):
		if quest_id != "" and has_node("/root/QuestLog"):
			get_node("/root/QuestLog").start_quest(quest_id)
			quest_offered.emit(quest_id)
		if dialogue_path != "":
			dialogue_requested.emit(dialogue_path)
		get_viewport().set_input_as_handled()
"""
	if optional_bool(params, "is_3d", false):
		content = content.replace("extends Area2D", "extends Area3D")
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "requires": ["QuestLog autoload", "player in group 'player'"]})


func _create_objective_tracker_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/objective_tracker.gd")
	var content := """extends Area2D
## MCP objective trigger — reports to QuestLog when player enters.

@export var event_type: String = "reach"
@export var target: String = "gate"
@export var amount: int = 1
@export var one_shot: bool = true

var _done: bool = false

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if _done:
		return
	if not body.is_in_group("player"):
		return
	if has_node("/root/QuestLog"):
		get_node("/root/QuestLog").report(event_type, target, amount)
	if one_shot:
		_done = true
		monitoring = false
"""
	if optional_bool(params, "is_3d", false):
		content = content.replace("extends Area2D", "extends Area3D")
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"]})
