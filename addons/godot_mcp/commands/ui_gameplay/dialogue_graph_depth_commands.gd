@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Dialogue graph resource CRUD depth (Wave 4 narrative).


func get_commands() -> Dictionary:
	return {
		"dialogue_graph_load": _dialogue_graph_load,
		"dialogue_graph_add_line": _dialogue_graph_add_line,
		"dialogue_graph_set_line": _dialogue_graph_set_line,
		"dialogue_graph_remove_line": _dialogue_graph_remove_line,
		"dialogue_graph_add_choice": _dialogue_graph_add_choice,
		"dialogue_graph_validate": _dialogue_graph_validate,
		"dialogue_graph_list_lines": _dialogue_graph_list_lines,
		"list_dialogue_graph_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_dialogue_resource", "create_dialogue_runner_script", "add_dialogue_graph_node", "export_dialogue_graph_mermaid"],
	})


func _load_graph(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(text) != OK:
		return {}
	if j.data is Dictionary:
		return j.data
	return {}


func _save_graph(path: String, data: Dictionary) -> Error:
	ensure_parent_dir(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_CREATE
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return OK


func _lines_array(data: Dictionary) -> Array:
	var lines = data.get("lines", [])
	return lines if lines is Array else []


func _find_line(lines: Array, id: String) -> int:
	for i in range(lines.size()):
		if lines[i] is Dictionary and str(lines[i].get("id", "")) == id:
			return i
	return -1


func _dialogue_graph_load(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var data := _load_graph(path_r[0])
	if data.is_empty():
		return error_not_found(path_r[0])
	return success({"path": path_r[0], "graph": data, "line_count": _lines_array(data).size()})


func _dialogue_graph_list_lines(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var data := _load_graph(path_r[0])
	var lines := _lines_array(data)
	var out: Array = []
	for l in lines:
		if l is Dictionary:
			out.append({
				"id": l.get("id", ""),
				"speaker": l.get("speaker", ""),
				"text": str(l.get("text", "")).substr(0, 80),
				"next": l.get("next", ""),
				"choices": (l.get("choices", []) as Array).size() if l.get("choices") is Array else 0,
			})
	return success({"path": path_r[0], "start": data.get("start", ""), "lines": out, "count": out.size()})


func _dialogue_graph_add_line(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var data := _load_graph(path_r[0])
	if data.is_empty():
		data = {"start": "start", "lines": [], "meta": {"version": 1}}
	var lines := _lines_array(data)
	var id: String = optional_string(params, "id", "line_%d" % lines.size())
	if _find_line(lines, id) >= 0:
		return error_invalid_params("Line id already exists: %s" % id)
	var line := {
		"id": id,
		"speaker": optional_string(params, "speaker", ""),
		"text": optional_string(params, "text", ""),
		"next": optional_string(params, "next", ""),
	}
	if params.has("choices") and params["choices"] is Array:
		line["choices"] = params["choices"]
	lines.append(line)
	data["lines"] = lines
	if optional_bool(params, "as_start", false):
		data["start"] = id
	var err := _save_graph(path_r[0], data)
	if err != OK:
		return error_internal(error_string(err))
	return success({"path": path_r[0], "line": line, "count": lines.size()})


func _dialogue_graph_set_line(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var id_r := require_string(params, "id")
	if id_r[1] != null:
		return id_r[1]
	var data := _load_graph(path_r[0])
	var lines := _lines_array(data)
	var idx := _find_line(lines, id_r[0])
	if idx < 0:
		return error_not_found("line %s" % id_r[0])
	var line: Dictionary = lines[idx]
	for k in ["speaker", "text", "next"]:
		if params.has(k):
			line[k] = params[k]
	if params.has("choices"):
		line["choices"] = params["choices"]
	lines[idx] = line
	data["lines"] = lines
	_save_graph(path_r[0], data)
	return success({"path": path_r[0], "line": line})


func _dialogue_graph_remove_line(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var id_r := require_string(params, "id")
	if id_r[1] != null:
		return id_r[1]
	var data := _load_graph(path_r[0])
	var lines := _lines_array(data)
	var idx := _find_line(lines, id_r[0])
	if idx < 0:
		return error_not_found("line")
	lines.remove_at(idx)
	data["lines"] = lines
	_save_graph(path_r[0], data)
	return success({"removed": id_r[0], "count": lines.size()})


func _dialogue_graph_add_choice(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var id_r := require_string(params, "id")
	if id_r[1] != null:
		return id_r[1]
	var text_r := require_string(params, "text")
	if text_r[1] != null:
		return text_r[1]
	var next: String = optional_string(params, "next", "")
	var data := _load_graph(path_r[0])
	var lines := _lines_array(data)
	var idx := _find_line(lines, id_r[0])
	if idx < 0:
		return error_not_found("line")
	var line: Dictionary = lines[idx]
	var choices: Array = line.get("choices", [])
	if not choices is Array:
		choices = []
	choices.append({"text": text_r[0], "next": next})
	line["choices"] = choices
	lines[idx] = line
	data["lines"] = lines
	_save_graph(path_r[0], data)
	return success({"id": id_r[0], "choices": choices})


func _dialogue_graph_validate(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var data := _load_graph(path_r[0])
	if data.is_empty():
		return error_not_found(path_r[0])
	var lines := _lines_array(data)
	var ids := {}
	var issues: Array = []
	for l in lines:
		if not l is Dictionary:
			continue
		var id := str(l.get("id", ""))
		if id.is_empty():
			issues.append({"severity": "error", "message": "Line missing id"})
			continue
		if ids.has(id):
			issues.append({"severity": "error", "message": "Duplicate id %s" % id})
		ids[id] = true
	var start := str(data.get("start", ""))
	if not start.is_empty() and not ids.has(start):
		issues.append({"severity": "error", "message": "start '%s' not in lines" % start})
	for l in lines:
		if not l is Dictionary:
			continue
		var next := str(l.get("next", ""))
		if not next.is_empty() and not ids.has(next):
			issues.append({"severity": "warning", "message": "Dangling next %s from %s" % [next, l.get("id")]})
		if l.get("choices") is Array:
			for ch in l["choices"]:
				if ch is Dictionary:
					var cn := str(ch.get("next", ""))
					if not cn.is_empty() and not ids.has(cn):
						issues.append({"severity": "warning", "message": "Dangling choice next %s" % cn})
	var err_n := 0
	for i in issues:
		if str(i.get("severity")) == "error":
			err_n += 1
	return success({"ok": err_n == 0, "issues": issues, "line_count": lines.size(), "start": start})
