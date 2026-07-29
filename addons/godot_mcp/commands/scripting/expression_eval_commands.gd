@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Safe-ish Expression evaluation for agents (math/docs classdb_only escape hatch).


func get_commands() -> Dictionary:
	return {
		"evaluate_expression": _evaluate_expression,
		"evaluate_expression_on_node": _evaluate_expression_on_node,
		"list_expression_eval_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["execute_editor_script", "call_node_method", "describe_class"],
		"security": "No OS.execute; Expression only. Still treat user input carefully.",
	})


func _evaluate_expression(params: Dictionary) -> Dictionary:
	var expr_r := require_string(params, "expression")
	if expr_r[1] != null:
		return expr_r[1]
	var expression := Expression.new()
	var inputs: Array = []
	var input_names: PackedStringArray = PackedStringArray()
	if params.has("inputs") and params["inputs"] is Dictionary:
		for k in params["inputs"]:
			input_names.append(str(k))
			inputs.append(params["inputs"][k])
	var err := expression.parse(expr_r[0], input_names)
	if err != OK:
		return error_invalid_params("Parse error: %s" % expression.get_error_text())
	var result = expression.execute(inputs, null, true)
	if expression.has_execute_failed():
		return error_internal("Execute failed: %s" % expression.get_error_text())
	return success({
		"expression": expr_r[0],
		"result": result,
		"result_type": typeof(result),
	})


func _evaluate_expression_on_node(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var expr_r := require_string(params, "expression")
	if expr_r[1] != null:
		return expr_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var expression := Expression.new()
	var err := expression.parse(expr_r[0])
	if err != OK:
		return error_invalid_params("Parse error: %s" % expression.get_error_text())
	var result = expression.execute([], node, true)
	if expression.has_execute_failed():
		return error_internal("Execute failed: %s" % expression.get_error_text())
	return success({
		"node_path": r0[0],
		"expression": expr_r[0],
		"result": result,
	})
