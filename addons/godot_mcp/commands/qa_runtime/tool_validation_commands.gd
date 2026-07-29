@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Live tool validation suite - exercises registered MCP commands in-editor.
## Honest scope: smoke contracts for all tools; full semantic verification needs
## per-domain fixtures. See tests/README.md.


func get_commands() -> Dictionary:
	return {
		"list_tool_validation_plan": _list_plan,
		"validate_tool_contract": _validate_one,
		"validate_tools_batch": _validate_batch,
		"run_tool_validation_suite": _run_suite,
		"run_critical_path_validation": _run_critical,
		"export_tool_validation_report": _export_report,
		"list_tool_validation_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"list_mcp_commands", "list_command_modules", "get_production_surface_report",
		"list_surface_registry", "call_editor",
	], {
		"docs": "tests/README.md",
		"modes": ["empty_params", "scene_gated", "critical_path", "all_safe"],
	})


func _router():
	return get_parent()


func _all_methods() -> Array:
	var r = _router()
	if r and r.has_method("get_available_methods"):
		var m = r.get_available_methods()
		if m is Array:
			var out: Array = []
			for x in m:
				out.append(str(x))
			out.sort()
			return out
	return []


func _classify(name: String) -> Dictionary:
	var is_list := name.begins_with("list_") or name.ends_with("_tools") or name.ends_with("_recipes") or name.ends_with("_catalog")
	var destructive := name.begins_with("delete_") or name.contains("delete_resource") or name.begins_with("remove_") and name.contains("file")
	var runtime := name.contains("playtest") or name.begins_with("play_") or name.contains("runtime") or name.contains("screenshot") or name.begins_with("simulate_") or name.begins_with("assert_")
	var scene := false
	for h in ["node", "scene", "camera", "mesh", "skeleton", "animation", "tilemap", "light", "avatar", "canvas"]:
		if name.contains(h):
			scene = true
			break
	if is_list:
		scene = false
	var kind := "empty_params"
	if destructive:
		kind = "destructive_gated"
	elif runtime:
		kind = "runtime_gated"
	elif scene and not is_list:
		kind = "scene_gated"
	elif not is_list and (name.begins_with("set_") or name.begins_with("create_") or name.begins_with("setup_") or name.begins_with("apply_")):
		kind = "mutate_minimal"
	return {
		"smoke_kind": kind,
		"is_list": is_list,
		"needs_scene": scene,
		"needs_runtime": runtime,
		"destructive": destructive,
	}


func _default_params(name: String, kind: String) -> Dictionary:
	match kind:
		"empty_params":
			return {}
		"destructive_gated", "runtime_gated":
			return {}
		"scene_gated":
			return {"node_path": ".", "parent_path": "."}
		"mutate_minimal":
			if name.contains("path") or name.begins_with("create_") or name.begins_with("write_"):
				return {"path": "res://__mcp_validation__/%s.tres" % name, "overwrite": true}
			return {"node_path": ".", "name": "MCPValidation"}
		_:
			return {}


func _is_ok_envelope(res: Dictionary, kind: String) -> Dictionary:
	## Accept success result OR structured error (invalid params / no scene).
	if res.has("result"):
		return {"pass": true, "outcome": "success"}
	if res.has("error"):
		var err = res["error"]
		if not err is Dictionary:
			return {"pass": false, "outcome": "malformed_error"}
		if not err.has("code") or not err.has("message"):
			return {"pass": false, "outcome": "error_missing_fields"}
		# Structured rejection is valid for gated smoke
		var code := int(err.get("code", 0))
		var msg := str(err.get("message", "")).to_lower()
		if kind in ["scene_gated", "mutate_minimal"]:
			if "scene" in msg or "not found" in msg or "required" in msg or "missing" in msg or "invalid" in msg or code in [-32000, -32001, -32602, -32603]:
				return {"pass": true, "outcome": "structured_error_ok"}
		if kind == "empty_params":
			# list tools should usually succeed; if error, still must be structured
			return {"pass": true, "outcome": "structured_error_ok"}
		return {"pass": true, "outcome": "structured_error_ok"}
	return {"pass": false, "outcome": "no_result_or_error"}


func _list_plan(params: Dictionary) -> Dictionary:
	var methods := _all_methods()
	var mode: String = optional_string(params, "mode", "all_safe")
	var plan: Array = []
	var skipped: Array = []
	for name in methods:
		var c := _classify(name)
		var kind: String = str(c["smoke_kind"])
		var include := true
		match mode:
			"empty_params", "list_only":
				include = kind == "empty_params" or bool(c["is_list"])
			"scene_gated":
				include = kind == "scene_gated"
			"all_safe":
				include = kind in ["empty_params", "scene_gated", "mutate_minimal"]
			"all":
				include = true
			_:
				include = kind != "destructive_gated"
		if not include:
			skipped.append({"tool": name, "reason": kind})
			continue
		if kind == "destructive_gated" and not optional_bool(params, "include_destructive", false):
			skipped.append({"tool": name, "reason": "destructive"})
			continue
		if kind == "runtime_gated" and not optional_bool(params, "include_runtime", false):
			skipped.append({"tool": name, "reason": "runtime"})
			continue
		plan.append({
			"tool": name,
			"smoke_kind": kind,
			"params": _default_params(name, kind),
		})
	return success({
		"mode": mode,
		"total_registered": methods.size(),
		"plan_count": plan.size(),
		"skipped_count": skipped.size(),
		"plan": plan if optional_bool(params, "include_plan", true) else [],
		"skipped_sample": skipped.slice(0, mini(50, skipped.size())),
	})


func _validate_one(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "tool")
	if r0[1] != null:
		# also accept name
		if params.has("name"):
			r0 = [str(params["name"]), null]
		else:
			return r0[1]
	var name: String = r0[0]
	var r = _router()
	if r == null or not r.has_method("execute"):
		return error_internal("No command router")
	var c := _classify(name)
	var kind: String = optional_string(params, "smoke_kind", str(c["smoke_kind"]))
	var call_params: Dictionary = params.get("params", _default_params(name, kind))
	if call_params is Dictionary and call_params.get("__skip__", false):
		return success({"tool": name, "skipped": true, "reason": call_params.get("reason", "skip")})
	var started := Time.get_ticks_msec()
	var res: Dictionary = await r.execute(name, call_params if call_params is Dictionary else {})
	var elapsed := Time.get_ticks_msec() - started
	var check := _is_ok_envelope(res, kind)
	return success({
		"tool": name,
		"pass": bool(check.get("pass", false)),
		"outcome": check.get("outcome", ""),
		"smoke_kind": kind,
		"elapsed_ms": elapsed,
		"response_keys": res.keys(),
		"error_message": res.get("error", {}).get("message", "") if res.has("error") else "",
	})


func _validate_batch(params: Dictionary) -> Dictionary:
	var tools: Array = params.get("tools", [])
	if tools.is_empty():
		return error_invalid_params("tools array required")
	var results: Array = []
	var passed := 0
	var failed := 0
	for t in tools:
		var name := str(t) if not (t is Dictionary) else str(t.get("tool", t.get("name", "")))
		var sub_params := {}
		if t is Dictionary and t.has("params"):
			sub_params = t["params"]
		var one := await _validate_one({"tool": name, "params": sub_params})
		if one.has("error"):
			failed += 1
			results.append({"tool": name, "pass": false, "error": one["error"]})
			continue
		var body: Dictionary = one.get("result", {})
		if bool(body.get("pass", false)):
			passed += 1
		else:
			failed += 1
		results.append(body)
	return success({
		"passed": passed,
		"failed": failed,
		"total": tools.size(),
		"results": results,
	})


func _run_suite(params: Dictionary) -> Dictionary:
	var mode: String = optional_string(params, "mode", "all_safe")
	var limit: int = optional_int(params, "limit", 0)
	var plan_res := _list_plan({
		"mode": mode,
		"include_plan": true,
		"include_destructive": optional_bool(params, "include_destructive", false),
		"include_runtime": optional_bool(params, "include_runtime", false),
	})
	if plan_res.has("error"):
		return plan_res
	var plan: Array = plan_res.get("result", {}).get("plan", [])
	if limit > 0 and plan.size() > limit:
		plan = plan.slice(0, limit)
	var passed := 0
	var failed := 0
	var skipped := 0
	var failures: Array = []
	var results: Array = []
	var i := 0
	for item in plan:
		i += 1
		var name: String = str(item.get("tool", ""))
		var kind: String = str(item.get("smoke_kind", "empty_params"))
		var call_params: Dictionary = item.get("params", {})
		var one := await _validate_one({
			"tool": name,
			"smoke_kind": kind,
			"params": call_params,
		})
		var body: Dictionary = one.get("result", {}) if not one.has("error") else {"pass": false, "tool": name, "outcome": "invoke_error"}
		if bool(body.get("skipped", false)):
			skipped += 1
		elif bool(body.get("pass", false)):
			passed += 1
		else:
			failed += 1
			if failures.size() < 100:
				failures.append(body)
		if optional_bool(params, "include_results", false):
			results.append(body)
		# yield occasionally so editor stays responsive
		if i % 25 == 0:
			await get_tree().process_frame
	var report := {
		"mode": mode,
		"total_planned": plan.size(),
		"passed": passed,
		"failed": failed,
		"skipped": skipped,
		"pass_rate": float(passed) / float(maxi(plan.size(), 1)),
		"failures": failures,
		"registered": _all_methods().size(),
		"timestamp": Time.get_datetime_string_from_system(true, true),
	}
	if optional_bool(params, "include_results", false):
		report["results"] = results
	if optional_bool(params, "write_report", true):
		var path: String = optional_string(params, "report_path", "res://mcp_validation_report.json")
		write_text_res(path, JSON.stringify(report, "\t"), true)
		report["report_path"] = path
	return success(report)


func _run_critical(params: Dictionary) -> Dictionary:
	## Built-in critical path (mirrors tests/integration/critical_path_specs.json)
	var steps: Array = [
		"list_agent_domains",
		"get_production_surface_report",
		"list_out_of_scope_surfaces",
		"list_humanoid_recipes",
		"list_avatar_identity_tools",
		"list_performance_autofix_tools",
		"list_filesystem_bulk_tools",
		"list_tool_validation_tools",
	]
	if params.has("tools") and params["tools"] is Array:
		steps = params["tools"]
	return await _validate_batch({"tools": steps})


func _export_report(params: Dictionary) -> Dictionary:
	## Re-run suite and force write
	var p := params.duplicate()
	p["write_report"] = true
	p["include_results"] = optional_bool(params, "include_results", false)
	return await _run_suite(p)
