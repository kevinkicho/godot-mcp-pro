@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Lightweight utility AI / GOAP-inspired scaffolds (AI behavior gap).


func get_commands() -> Dictionary:
	return {
		"create_utility_ai_script": _create_utility_ai_script,
		"create_goap_planner_script": _create_goap_planner_script,
		"create_blackboard_utility_script": _create_blackboard_utility_script,
		"list_utility_ai_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_behavior_tree_runtime_script", "setup_ai_agent_2d", "create_chase_ai_script"],
		"note": "Recipes for agent-authored AI - not full visual planners",
	})


func _create_utility_ai_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/utility_ai.gd")
	var content := """extends Node
## Simple utility AI - scores actions by consideration curves and picks max.
class_name UtilityAI

signal action_selected(action_id: StringName, score: float)

## actions: { id: StringName, considerations: [{get_value: Callable, weight: float, curve: String}] }
var actions: Array = []

func add_action(id: StringName, considerations: Array = []) -> void:
	actions.append({\"id\": id, \"considerations\": considerations})

func score_action(action: Dictionary, ctx: Dictionary = {}) -> float:
	var cons: Array = action.get(\"considerations\", [])
	if cons.is_empty():
		return 0.0
	var score := 1.0
	for c in cons:
		var w: float = float(c.get(\"weight\", 1.0))
		var raw := 0.5
		if c.has(\"value\"):
			raw = float(c[\"value\"])
		elif c.has(\"key\") and ctx.has(c[\"key\"]):
			raw = float(ctx[c[\"key\"]])
		raw = clampf(raw, 0.0, 1.0)
		var shaped := _shape(raw, str(c.get(\"curve\", \"linear\")))
		score *= pow(shaped, w)
	return score

func _shape(v: float, curve: String) -> float:
	match curve:
		\"inverse\":
			return 1.0 - v
		\"quadratic\":
			return v * v
		\"logistic\":
			return 1.0 / (1.0 + exp(-12.0 * (v - 0.5)))
		_:
			return v

func pick(ctx: Dictionary = {}) -> Dictionary:
	var best_id: StringName = &\"\"
	var best := -1.0
	for a in actions:
		var s := score_action(a, ctx)
		if s > best:
			best = s
			best_id = a.get(\"id\", &\"\")
	if best_id != &\"\":
		action_selected.emit(best_id, best)
	return {\"id\": best_id, \"score\": best}
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "api": ["add_action", "pick", "score_action"]})


func _create_goap_planner_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/goap_planner.gd")
	var content := """extends RefCounted
## Tiny GOAP-style planner: actions have preconditions + effects (Dictionary facts).
## Not optimal A*; BFS up to max_depth for small action sets.

func plan(start: Dictionary, goal: Dictionary, actions: Array, max_depth: int = 6) -> Array:
	# actions: [{id, cost, pre:{}, eff:{}}]
	var queue: Array = [{\"state\": start.duplicate(true), \"path\": []}]
	var seen: Dictionary = {}
	seen[_key(start)] = true
	while not queue.is_empty():
		var node: Dictionary = queue.pop_front()
		var state: Dictionary = node[\"state\"]
		var path: Array = node[\"path\"]
		if _satisfies(state, goal):
			return path
		if path.size() >= max_depth:
			continue
		for a in actions:
			if not _satisfies(state, a.get(\"pre\", {})):
				continue
			var next := state.duplicate(true)
			var eff: Dictionary = a.get(\"eff\", {})
			for k in eff:
				next[k] = eff[k]
			var kstr := _key(next)
			if seen.has(kstr):
				continue
			seen[kstr] = true
			var np := path.duplicate()
			np.append(a.get(\"id\", \"\"))
			queue.append({\"state\": next, \"path\": np})
	return []

func _satisfies(state: Dictionary, need: Dictionary) -> bool:
	for k in need:
		if not state.has(k) or state[k] != need[k]:
			return false
	return true

func _key(state: Dictionary) -> String:
	var keys: Array = state.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k in keys:
		parts.append(\"%s=%s\" % [str(k), str(state[k])])
	return \"|\".join(parts)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "api": ["plan(start, goal, actions)"]})


func _create_blackboard_utility_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/ai_blackboard.gd")
	var content := """extends Node
## Shared AI blackboard / world state dictionary.
signal changed(key: StringName, value: Variant)
var data: Dictionary = {}

func set_value(key: StringName, value: Variant) -> void:
	data[key] = value
	changed.emit(key, value)

func get_value(key: StringName, default: Variant = null) -> Variant:
	return data.get(key, default)

func has_value(key: StringName) -> bool:
	return data.has(key)

func as_dict() -> Dictionary:
	return data.duplicate(true)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var added := maybe_add_autoload(params, path, "AIBlackboard")
	return success({"path": path, "autoload_added": added})
