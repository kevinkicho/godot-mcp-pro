@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Apply Expression results onto node properties (pairs with evaluate_expression).


func get_commands() -> Dictionary:
	return {
		"set_property_from_expression": _set_from_expr,
		"batch_set_from_expressions": _batch_set,
		"list_expression_batch_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"evaluate_expression", "evaluate_expression_on_node",
		"update_property", "batch_update_property", "call_node_method",
	], {
		"hint": "Uses Godot Expression. evaluate_expression for dry-run; set_property_from_expression to write.",
	})


func _build_expression(expr_str: String, input_names: PackedStringArray) -> Dictionary:
	var expr := Expression.new()
	var err := expr.parse(expr_str, input_names)
	if err != OK:
		return {"error": error_invalid_params("Expression parse error: %s" % expr.get_error_text())}
	return {"expr": expr}


func _eval_on_node(node: Object, expr_str: String, inputs: Dictionary) -> Dictionary:
	if not inputs is Dictionary:
		inputs = {}
	var names: PackedStringArray = PackedStringArray()
	var values: Array = []
	# Prefer explicit inputs; always offer self/node aliases if missing
	var merged: Dictionary = inputs.duplicate()
	if not merged.has("self"):
		merged["self"] = node
	if not merged.has("node"):
		merged["node"] = node
	for k in merged:
		names.append(str(k))
		values.append(merged[k])
	var built := _build_expression(expr_str, names)
	if built.has("error"):
		return built
	var expr: Expression = built["expr"]
	var result: Variant = expr.execute(values, node, true)
	if expr.has_execute_failed():
		return {"error": error_invalid_params("Execute failed: %s" % expr.get_error_text())}
	return {"result": result}


func _set_from_expr(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var r1 := require_string(params, "property")
	if r1[1] != null:
		return r1[1]
	var r2 := require_string(params, "expression")
	if r2[1] != null:
		return r2[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var prop: String = r1[0]
	if not prop in node:
		return error_not_found("Property '%s'" % prop)
	var eval_res := _eval_on_node(node, r2[0], params.get("inputs", {}))
	if eval_res.has("error"):
		return eval_res["error"]
	var value: Variant = eval_res["result"]
	var old: Variant = node.get(prop)
	var undo := get_undo_redo()
	undo.create_action("MCP: set from expression")
	undo.add_do_property(node, prop, value)
	undo.add_undo_property(node, prop, old)
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"property": prop,
		"expression": r2[0],
		"old_value": old,
		"new_value": node.get(prop),
	})


func _batch_set(params: Dictionary) -> Dictionary:
	## items: [{node_path, property, expression, inputs?}]
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("items array required")
	var results: Array = []
	for item in params["items"]:
		if not item is Dictionary:
			continue
		var sub := _set_from_expr(item)
		if sub.has("error"):
			results.append({"ok": false, "error": sub["error"], "item": item})
		else:
			results.append({"ok": true, "result": sub.get("result", {})})
	return success({"results": results, "count": results.size()})
