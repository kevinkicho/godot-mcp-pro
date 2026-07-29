@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Behavior tree runtime for NPCs — beyond simple FSM.


func get_commands() -> Dictionary:
	return {
		"create_behavior_tree_runtime_script": _create_bt_runtime,
		"create_behavior_tree_resource": _create_bt_resource,
		"create_behavior_tree_runner_script": _create_bt_runner,
		"create_blackboard_script": _create_blackboard,
		"setup_behavior_tree_on_node": _setup_bt_on_node,
		"list_behavior_tree_recipes": _list_bt_recipes,
	}


func _list_bt_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"node_types": ["selector", "sequence", "parallel", "inverter", "succeeder", "repeater", "action", "condition"],
		"flow": [
			"create_blackboard_script",
			"create_behavior_tree_runtime_script",
			"create_behavior_tree_resource (JSON tree)",
			"create_behavior_tree_runner_script / setup_behavior_tree_on_node",
		],
		"example_actions": ["wait", "move_to", "play_anim", "attack", "set_bb", "call_method"],
	})




func _create_blackboard(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/bt_blackboard.gd")
	var content := """extends RefCounted
## MCP BT Blackboard — shared key/value memory for behavior trees.
class_name BTBlackboard

signal value_changed(key: String, value: Variant)

var _data: Dictionary = {}

func set_value(key: String, value: Variant) -> void:
	_data[key] = value
	value_changed.emit(key, value)

func get_value(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)

func has_value(key: String) -> bool:
	return _data.has(key)

func erase(key: String) -> void:
	_data.erase(key)

func keys() -> Array:
	return _data.keys()

func as_dict() -> Dictionary:
	return _data.duplicate()
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "class_name": "BTBlackboard"})


func _create_bt_runtime(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/bt_runtime.gd")
	var content := """extends RefCounted
## MCP behavior tree runtime — evaluate JSON tree against actor + blackboard.
## Status: SUCCESS=1, FAILURE=0, RUNNING=2
class_name BTRuntime

const SUCCESS := 1
const FAILURE := 0
const RUNNING := 2

var actor: Node
var bb  # BTBlackboard
var tree: Dictionary = {}
var _wait_left: float = 0.0
var _running_path: String = ""

func setup(p_actor: Node, p_bb, p_tree: Dictionary) -> void:
	actor = p_actor
	bb = p_bb
	tree = p_tree

func tick(delta: float) -> int:
	if tree.is_empty():
		return FAILURE
	if _wait_left > 0.0:
		_wait_left = maxf(_wait_left - delta, 0.0)
		return RUNNING if _wait_left > 0.0 else SUCCESS
	return _eval(tree, delta)

func _eval(node: Dictionary, delta: float) -> int:
	var t := str(node.get("type", "action"))
	match t:
		"selector":
			for c in node.get("children", []):
				if c is Dictionary:
					var s := _eval(c, delta)
					if s != FAILURE:
						return s
			return FAILURE
		"sequence":
			for c in node.get("children", []):
				if c is Dictionary:
					var s2 := _eval(c, delta)
					if s2 != SUCCESS:
						return s2
			return SUCCESS
		"parallel":
			var any_fail := false
			var any_run := false
			for c in node.get("children", []):
				if c is Dictionary:
					var s3 := _eval(c, delta)
					if s3 == FAILURE:
						any_fail = true
					elif s3 == RUNNING:
						any_run = true
			if any_fail:
				return FAILURE
			return RUNNING if any_run else SUCCESS
		"inverter":
			var kids: Array = node.get("children", [])
			if kids.is_empty():
				return FAILURE
			var s4 := _eval(kids[0], delta)
			if s4 == SUCCESS:
				return FAILURE
			if s4 == FAILURE:
				return SUCCESS
			return RUNNING
		"succeeder":
			var kids2: Array = node.get("children", [])
			if not kids2.is_empty():
				_eval(kids2[0], delta)
			return SUCCESS
		"repeater":
			var times := int(node.get("times", 1))
			var kids3: Array = node.get("children", [])
			if kids3.is_empty():
				return FAILURE
			for i in times:
				var s5 := _eval(kids3[0], delta)
				if s5 != SUCCESS:
					return s5
			return SUCCESS
		"condition":
			return SUCCESS if _check_condition(node) else FAILURE
		"action", _:
			return _do_action(node, delta)

func _check_condition(node: Dictionary) -> bool:
	var key := str(node.get("key", ""))
	var op := str(node.get("op", "truthy"))
	var expect = node.get("value", true)
	var actual = bb.get_value(key) if bb else null
	match op:
		"eq", "==":
			return actual == expect
		"neq", "!=":
			return actual != expect
		"gt":
			return float(actual) > float(expect)
		"gte":
			return float(actual) >= float(expect)
		"lt":
			return float(actual) < float(expect)
		"lte":
			return float(actual) <= float(expect)
		"has":
			return bb != null and bb.has_value(key)
		"truthy", _:
			return bool(actual)

func _do_action(node: Dictionary, delta: float) -> int:
	var action := str(node.get("action", node.get("name", "wait")))
	match action:
		"wait":
			_wait_left = float(node.get("seconds", 1.0))
			return RUNNING
		"set_bb":
			if bb:
				bb.set_value(str(node.get("key", "")), node.get("value", null))
			return SUCCESS
		"call_method":
			var method := str(node.get("method", ""))
			if actor and actor.has_method(method):
				var args: Array = node.get("args", [])
				actor.callv(method, args)
				return SUCCESS
			return FAILURE
		"print":
			print("[BT] ", node.get("message", ""))
			return SUCCESS
		"succeed":
			return SUCCESS
		"fail":
			return FAILURE
		"move_to":
			# Expect actor has navigate_to(Vector2/3) or set target on blackboard
			if bb and node.has("bb_target"):
				bb.set_value("move_target", bb.get_value(str(node["bb_target"])))
			if actor and actor.has_method("bt_move_to"):
				var target = node.get("target", bb.get_value("move_target") if bb else null)
				return int(actor.bt_move_to(target, delta))
			return FAILURE
		"attack":
			if actor and actor.has_method("bt_attack"):
				return int(actor.bt_attack(delta))
			return FAILURE
		_:
			if actor and actor.has_method("bt_" + action):
				return int(actor.call("bt_" + action, node, delta))
			push_warning("BT unknown action: " + action)
			return FAILURE
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "class_name": "BTRuntime"})


func _create_bt_resource(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://ai/example_bt.json")
	var tree: Dictionary = {}
	if params.has("tree") and params["tree"] is Dictionary:
		tree = params["tree"]
	else:
		# Classic: if player in range attack else chase else idle
		tree = {
			"type": "selector",
			"children": [
				{
					"type": "sequence",
					"children": [
						{"type": "condition", "key": "player_in_attack_range", "op": "truthy"},
						{"type": "action", "action": "attack"},
					],
				},
				{
					"type": "sequence",
					"children": [
						{"type": "condition", "key": "player_visible", "op": "truthy"},
						{"type": "action", "action": "move_to", "bb_target": "player_pos"},
					],
				},
				{
					"type": "sequence",
					"children": [
						{"type": "action", "action": "wait", "seconds": 0.5},
						{"type": "action", "action": "print", "message": "idle patrol tick"},
					],
				},
			],
		}
	var data := {
		"name": optional_string(params, "name", "ExampleBT"),
		"tree": tree,
		"meta": {"created_by": "godot-mcp", "version": 1},
	}
	var w := write_json_file(path, data, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "name": data["name"]})


func _create_bt_runner(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/bt_runner.gd")
	var content := """extends Node
## MCP BT runner — attach as child of AI actor. Loads JSON tree each tick.

@export var tree_path: String = "res://ai/example_bt.json"
@export var tick_every_physics: bool = true

var _runtime  # BTRuntime
var _bb  # BTBlackboard

func _ready() -> void:
	_bb = load("res://scripts/bt_blackboard.gd").new() if ResourceLoader.exists("res://scripts/bt_blackboard.gd") else null
	if _bb == null and ClassDB.class_exists("BTBlackboard"):
		_bb = ClassDB.instantiate("BTBlackboard")
	# Prefer global class if available
	if _bb == null:
		_bb = _BlackboardFallback.new()
	_runtime = _make_runtime()
	_reload_tree()

func _make_runtime():
	if ResourceLoader.exists("res://scripts/bt_runtime.gd"):
		return load("res://scripts/bt_runtime.gd").new()
	return null

func _reload_tree() -> void:
	if _runtime == null:
		return
	var tree := {}
	if FileAccess.file_exists(tree_path):
		var f := FileAccess.open(tree_path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			tree = parsed.get("tree", parsed)
	_runtime.setup(get_parent(), _bb, tree)

func blackboard():
	return _bb

func _physics_process(delta: float) -> void:
	if tick_every_physics and _runtime:
		_runtime.tick(delta)

func _process(delta: float) -> void:
	if not tick_every_physics and _runtime:
		_runtime.tick(delta)

class _BlackboardFallback:
	var _data := {}
	func set_value(k, v): _data[k] = v
	func get_value(k, d=null): return _data.get(k, d)
	func has_value(k): return _data.has(k)
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"]})


func _setup_bt_on_node(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	# Ensure scripts exist
	if not FileAccess.file_exists("res://scripts/bt_runtime.gd"):
		_create_bt_runtime({"overwrite": false})
	if not FileAccess.file_exists("res://scripts/bt_blackboard.gd"):
		_create_blackboard({"overwrite": false})
	var runner_path: String = optional_string(params, "script_path", "res://scripts/bt_runner.gd")
	if not FileAccess.file_exists(runner_path):
		_create_bt_runner({"path": runner_path, "overwrite": false})
	var tree_path: String = optional_string(params, "tree_path", "res://ai/example_bt.json")
	if not FileAccess.file_exists(tree_path):
		_create_bt_resource({"path": tree_path, "overwrite": false})
	var n := Node.new()
	n.name = optional_string(params, "name", "BehaviorTree")
	add_child_with_undo(parent, n, root, "MCP: BehaviorTree")
	var scr = load(runner_path)
	if scr:
		n.set_script(scr)
		n.set("tree_path", tree_path)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(n)),
		"tree_path": tree_path,
		"script_path": runner_path,
	})
