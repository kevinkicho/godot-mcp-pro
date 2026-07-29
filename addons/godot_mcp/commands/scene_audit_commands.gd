@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scene audit — signal wiring dump, missing scripts, batch scene load checks.


func get_commands() -> Dictionary:
	return {
		"list_scene_signals": _list_scene_signals,
		"list_missing_scripts": _list_missing_scripts,
		"validate_all_scenes": _validate_all_scenes,
		"audit_scene_tree": _audit_scene_tree,
		"list_scene_audit_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"flow": [
			"audit_scene_tree for open scene health",
			"list_scene_signals before rewiring",
			"validate_all_scenes before export",
			"list_missing_scripts after renames",
		],
		"related": ["validate_level_playable", "validate_scene_dependencies", "analyze_scene_complexity"],
	})


func _list_scene_signals(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start_path: String = optional_string(params, "node_path", ".")
	var start := find_node_by_path(start_path)
	if start == null:
		return error_not_found("Node")
	var max_n: int = clampi(optional_int(params, "max", 200), 1, 2000)
	var only_connected: bool = optional_bool(params, "only_connected", true)
	var out: Array = []
	_walk_signals(start, root, out, max_n, only_connected)
	return success({
		"connections": out,
		"count": out.size(),
		"only_connected": only_connected,
		"truncated": out.size() >= max_n,
	})


func _walk_signals(n: Node, root: Node, out: Array, max_n: int, only_connected: bool) -> void:
	if out.size() >= max_n:
		return
	var sigs: Array = n.get_signal_list()
	for s in sigs:
		if out.size() >= max_n:
			return
		var sname: String = str(s.get("name", ""))
		var conns: Array = n.get_signal_connection_list(sname)
		if only_connected and conns.is_empty():
			continue
		if conns.is_empty() and not only_connected:
			out.append({
				"source": str(root.get_path_to(n)),
				"signal": sname,
				"connections": [],
			})
		for c in conns:
			if out.size() >= max_n:
				return
			var target = c.get("callable", c.get("target", null))
			var target_path := ""
			var method := ""
			if target is Callable:
				var cb: Callable = target
				if cb.get_object() is Node:
					target_path = str(root.get_path_to(cb.get_object() as Node))
				method = cb.get_method()
			elif c.has("target") and c["target"] is Node:
				target_path = str(root.get_path_to(c["target"]))
				method = str(c.get("method", ""))
			out.append({
				"source": str(root.get_path_to(n)),
				"signal": sname,
				"target": target_path,
				"method": method,
				"flags": c.get("flags", 0),
			})
	for ch in n.get_children():
		_walk_signals(ch, root, out, max_n, only_connected)


func _list_missing_scripts(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start_path: String = optional_string(params, "node_path", ".")
	var start := find_node_by_path(start_path)
	if start == null:
		return error_not_found("Node")
	var missing: Array = []
	var with_script: Array = []
	_walk_scripts(start, root, missing, with_script)
	return success({
		"missing_scripts": missing,
		"nodes_with_script": with_script.size(),
		"missing_count": missing.size(),
		"ok": missing.is_empty(),
	})


func _walk_scripts(n: Node, root: Node, missing: Array, with_script: Array) -> void:
	var scr: Script = n.get_script()
	if scr != null:
		var path := scr.resource_path
		var entry := {"node": str(root.get_path_to(n)), "script": path, "class": n.get_class()}
		if path.is_empty() or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			# Built-in / unsaved scripts have empty path
			if path.is_empty():
				entry["note"] = "built-in or unsaved script"
				with_script.append(entry)
			else:
				missing.append(entry)
		else:
			with_script.append(entry)
	for ch in n.get_children():
		_walk_scripts(ch, root, missing, with_script)


func _validate_all_scenes(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	var max_n: int = clampi(optional_int(params, "max", 50), 1, 200)
	var scenes: Array = []
	_collect_scenes(root_path, scenes, max_n)
	var results: Array = []
	var fail := 0
	for sp in scenes:
		var item := {"path": sp, "ok": false}
		# Dependency check
		var missing_deps: Array = []
		for d in ResourceLoader.get_dependencies(str(sp)):
			var p := _dep_path(str(d))
			if not ResourceLoader.exists(p) and not FileAccess.file_exists(p):
				missing_deps.append(p)
		item["missing_deps"] = missing_deps
		# Try load packed scene
		if not missing_deps.is_empty():
			item["error"] = "missing dependencies"
			fail += 1
		else:
			var res = load(str(sp))
			if res == null:
				item["error"] = "load returned null"
				fail += 1
			elif res is PackedScene:
				var inst = (res as PackedScene).instantiate()
				if inst == null:
					item["error"] = "instantiate failed"
					fail += 1
				else:
					item["ok"] = true
					item["root_class"] = inst.get_class()
					item["root_name"] = inst.name
					item["child_count"] = inst.get_child_count()
					inst.free()
			else:
				item["error"] = "not a PackedScene"
				fail += 1
		results.append(item)
	return success({
		"scenes": results,
		"checked": results.size(),
		"failed": fail,
		"all_ok": fail == 0,
	})


func _audit_scene_tree(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var max_depth: int = clampi(optional_int(params, "max_depth", 8), 1, 20)
	var issues: Array = []
	var stats := {
		"nodes": 0,
		"with_script": 0,
		"collision_shapes": 0,
		"cameras": 0,
		"lights": 0,
		"audio_players": 0,
		"animation_players": 0,
		"unique_classes": {},
	}
	_audit_walk(root, root, 0, max_depth, issues, stats)
	var class_list: Array = []
	for k in stats["unique_classes"]:
		class_list.append({"class": k, "count": stats["unique_classes"][k]})
	return success({
		"scene": root.scene_file_path,
		"root": root.name,
		"root_class": root.get_class(),
		"stats": {
			"nodes": stats["nodes"],
			"with_script": stats["with_script"],
			"collision_shapes": stats["collision_shapes"],
			"cameras": stats["cameras"],
			"lights": stats["lights"],
			"audio_players": stats["audio_players"],
			"animation_players": stats["animation_players"],
			"classes": class_list,
		},
		"issues": issues,
		"ok": issues.is_empty() or not _has_error_severity(issues),
		"hint": "list_scene_signals / list_missing_scripts for detail",
	})


func _audit_walk(n: Node, root: Node, depth: int, max_depth: int, issues: Array, stats: Dictionary) -> void:
	stats["nodes"] = int(stats["nodes"]) + 1
	var cls: String = n.get_class()
	var uc: Dictionary = stats["unique_classes"]
	uc[cls] = int(uc.get(cls, 0)) + 1
	stats["unique_classes"] = uc

	if n.get_script() != null:
		stats["with_script"] = int(stats["with_script"]) + 1
		var sp := n.get_script().resource_path
		if not sp.is_empty() and not ResourceLoader.exists(sp) and not FileAccess.file_exists(sp):
			issues.append({
				"severity": "error",
				"node": str(root.get_path_to(n)),
				"message": "Missing script %s" % sp,
			})

	if n is CollisionShape2D or n is CollisionShape3D:
		stats["collision_shapes"] = int(stats["collision_shapes"]) + 1
		var shape = n.get("shape")
		if shape == null:
			issues.append({
				"severity": "warning",
				"node": str(root.get_path_to(n)),
				"message": "CollisionShape has no shape resource",
			})
	if n is Camera2D or n is Camera3D:
		stats["cameras"] = int(stats["cameras"]) + 1
	if n is Light2D or n is Light3D:
		stats["lights"] = int(stats["lights"]) + 1
	if n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D:
		stats["audio_players"] = int(stats["audio_players"]) + 1
	if n is AnimationPlayer:
		stats["animation_players"] = int(stats["animation_players"]) + 1

	if n.name.is_empty():
		issues.append({
			"severity": "warning",
			"node": str(root.get_path_to(n)),
			"message": "Empty node name",
		})

	if depth >= max_depth:
		return
	for ch in n.get_children():
		_audit_walk(ch, root, depth + 1, max_depth, issues, stats)


func _has_error_severity(issues: Array) -> bool:
	for i in issues:
		if i is Dictionary and str(i.get("severity", "")) == "error":
			return true
	return false


func _dep_path(dep: String) -> String:
	if dep.contains("::"):
		var parts := dep.split("::")
		return parts[parts.size() - 1]
	return dep


func _collect_scenes(dir_path: String, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.rstrip("/") + "/" + name if dir_path != "res://" else "res://" + name
		if dir.current_is_dir():
			if name != ".godot" and name != "addons":
				_collect_scenes(full, out, max_n)
		elif name.get_extension().to_lower() in ["tscn", "scn"]:
			out.append(full)
		name = dir.get_next()
		if out.size() >= max_n:
			break
	dir.list_dir_end()
