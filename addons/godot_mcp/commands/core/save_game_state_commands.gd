@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Save/load game state from node trees — agents capture/apply world snapshots.


func get_commands() -> Dictionary:
	return {
		"capture_node_state": _capture_node,
		"capture_scene_state": _capture_scene,
		"apply_node_state": _apply_node,
		"create_game_state_serializer_script": _create_serializer,
		"write_save_slot_json": _write_slot,
		"read_save_slot_json": _read_slot,
		"list_save_slots_json": _list_slots,
		"list_save_game_state_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"create_enhanced_save_manager_script", "create_encrypted_save_manager_script",
			"setup_save_slot_menu", "encrypted_file_write",
		],
		"workflow": [
			"create_game_state_serializer_script add_autoload=true",
			"write_save_slot_json slot=1 data={...} OR capture_scene_state → write",
			"read_save_slot_json slot=1 → apply via serializer",
		],
	})


func _serialize_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2:
			return {"_t": "Vector2", "x": v.x, "y": v.y}
		TYPE_VECTOR3:
			return {"_t": "Vector3", "x": v.x, "y": v.y, "z": v.z}
		TYPE_COLOR:
			return {"_t": "Color", "r": v.r, "g": v.g, "b": v.b, "a": v.a}
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _serialize_value(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for item in v:
				a.append(_serialize_value(item))
			return a
		TYPE_OBJECT:
			if v is Resource and not (v as Resource).resource_path.is_empty():
				return {"_t": "ResourcePath", "path": (v as Resource).resource_path}
			return null
		_:
			if typeof(v) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
				return v
			return str(v)


func _deserialize_value(v: Variant) -> Variant:
	if v is Dictionary and v.has("_t"):
		match str(v["_t"]):
			"Vector2":
				return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
			"Vector3":
				return Vector3(float(v.get("x", 0)), float(v.get("y", 0)), float(v.get("z", 0)))
			"Color":
				return Color(float(v.get("r", 1)), float(v.get("g", 1)), float(v.get("b", 1)), float(v.get("a", 1)))
			"ResourcePath":
				var p := str(v.get("path", ""))
				if ResourceLoader.exists(p):
					return load(p)
				return null
	return v


func _capture_node(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var props: Array = params.get("properties", [])
	if props.is_empty():
		# sensible defaults
		if node is Node2D:
			props = ["position", "rotation", "scale", "visible"]
		elif node is Node3D:
			props = ["position", "rotation", "scale", "visible"]
		elif node is Control:
			props = ["position", "size", "visible", "modulate"]
		else:
			props = ["visible"]
	var state := {
		"node_path": r0[0],
		"class": node.get_class(),
		"name": str(node.name),
		"properties": {},
	}
	for p in props:
		var pn := str(p)
		if pn in node:
			state["properties"][pn] = _serialize_value(node.get(pn))
	# Optional groups
	if optional_bool(params, "include_groups", false):
		state["groups"] = node.get_groups()
	return success({"state": state})


func _capture_scene(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var class_filter: String = optional_string(params, "class_name", "")
	var group_filter: String = optional_string(params, "group", "")
	var props: Array = params.get("properties", [])
	var limit: int = optional_int(params, "limit", 100)
	var nodes: Array = []
	_walk_capture(root, root, class_filter, group_filter, props, nodes, limit)
	var payload := {
		"version": 1,
		"scene_file": root.scene_file_path,
		"captured_at": Time.get_unix_time_from_system(),
		"nodes": nodes,
	}
	return success({"state": payload, "count": nodes.size()})


func _walk_capture(scene_root: Node, node: Node, class_filter: String, group_filter: String, props: Array, out: Array, limit: int) -> void:
	if out.size() >= limit:
		return
	var include := true
	if not class_filter.is_empty() and not node.is_class(class_filter) and node.get_class() != class_filter:
		include = false
	if not group_filter.is_empty() and not node.is_in_group(group_filter):
		include = false
	if include and node != scene_root:
		var use_props: Array = props
		if use_props.is_empty():
			if node is Node2D:
				use_props = ["position", "rotation", "visible"]
			elif node is Node3D:
				use_props = ["position", "rotation", "visible"]
			else:
				use_props = []
		if not use_props.is_empty():
			var st := {"node_path": str(scene_root.get_path_to(node)), "class": node.get_class(), "properties": {}}
			for p in use_props:
				if str(p) in node:
					st["properties"][str(p)] = _serialize_value(node.get(str(p)))
			out.append(st)
	for c in node.get_children():
		_walk_capture(scene_root, c, class_filter, group_filter, props, out, limit)


func _apply_node(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not params.has("properties") or not (params["properties"] is Dictionary):
		return error_invalid_params("properties dictionary required")
	var applied := {}
	for k in params["properties"]:
		if str(k) in node:
			var val = _deserialize_value(params["properties"][k])
			node.set(str(k), val)
			applied[str(k)] = true
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied.keys()})


func _create_serializer(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/game_state_serializer.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Runtime save/load helper — JSON slots under user://saves/

signal saved(slot: String)
signal loaded(slot: String)

@export var save_dir: String = \"user://saves\"

func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)

func slot_path(slot: String) -> String:
	return save_dir.path_join(\"slot_%s.json\" % slot)

func save_dict(slot: String, data: Dictionary, meta: Dictionary = {}) -> Error:
	_ensure_dir()
	var payload := {
		\"version\": 1,
		\"timestamp\": Time.get_unix_time_from_system(),
		\"meta\": meta,
		\"data\": data,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(payload, \"\\t\"))
	f.close()
	saved.emit(slot)
	return OK

func load_dict(slot: String) -> Dictionary:
	var p := slot_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		loaded.emit(slot)
		return parsed
	return {}

func list_slots() -> Array:
	_ensure_dir()
	var out: Array = []
	var da := DirAccess.open(save_dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != \"\":
		if not da.current_is_dir() and fn.begins_with(\"slot_\") and fn.ends_with(\".json\"):
			out.append(fn.trim_prefix(\"slot_\").trim_suffix(\".json\"))
		fn = da.get_next()
	da.list_dir_end()
	return out

func delete_slot(slot: String) -> Error:
	var p := slot_path(slot)
	if FileAccess.file_exists(p):
		return DirAccess.remove_absolute(p)
	return OK

func capture_nodes(root: Node, paths: PackedStringArray, properties: PackedStringArray) -> Dictionary:
	var nodes := {}
	for path in paths:
		var n := root.get_node_or_null(NodePath(path))
		if n == null:
			continue
		var props := {}
		for prop in properties:
			if prop in n:
				props[prop] = n.get(prop)
		nodes[path] = {\"class\": n.get_class(), \"properties\": props}
	return {\"nodes\": nodes}

func apply_nodes(root: Node, data: Dictionary) -> void:
	var nodes: Dictionary = data.get(\"nodes\", data)
	for path in nodes:
		var n := root.get_node_or_null(NodePath(str(path)))
		if n == null:
			continue
		var entry: Dictionary = nodes[path]
		var props: Dictionary = entry.get(\"properties\", entry)
		for prop in props:
			if prop in n:
				n.set(prop, props[prop])
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	var al := maybe_add_autoload(params, path, "GameSave")
	return success({"path": path, "autoload_added": al, "api": ["save_dict", "load_dict", "list_slots", "capture_nodes", "apply_nodes"]})


func _slot_dir() -> String:
	return "user://saves"


func _write_slot(params: Dictionary) -> Dictionary:
	var slot: String = optional_string(params, "slot", "1")
	if not params.has("data"):
		return error_invalid_params("data dictionary required (or capture first)")
	var data = params["data"]
	if not data is Dictionary:
		return error_invalid_params("data must be dictionary")
	var meta: Dictionary = params.get("meta", {})
	if not meta is Dictionary:
		meta = {}
	var dir := _slot_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("slot_%s.json" % slot)
	var payload := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"meta": meta,
		"data": data,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return success({"slot": slot, "path": path, "timestamp": payload["timestamp"]})


func _read_slot(params: Dictionary) -> Dictionary:
	var slot: String = optional_string(params, "slot", "1")
	var path := _slot_dir().path_join("slot_%s.json" % slot)
	if not FileAccess.file_exists(path):
		return error_not_found("save slot '%s'" % slot)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot read")
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return error_internal("Invalid save JSON")
	return success({"slot": slot, "path": path, "payload": parsed})


func _list_slots(_params: Dictionary) -> Dictionary:
	var dir := _slot_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var slots: Array = []
	var da := DirAccess.open(dir)
	if da:
		da.list_dir_begin()
		var fn := da.get_next()
		while fn != "":
			if not da.current_is_dir() and fn.begins_with("slot_") and fn.ends_with(".json"):
				var slot_id := fn.trim_prefix("slot_").trim_suffix(".json")
				var path := dir.path_join(fn)
				var entry := {"slot": slot_id, "path": path}
				var f := FileAccess.open(path, FileAccess.READ)
				if f:
					var parsed = JSON.parse_string(f.get_as_text())
					f.close()
					if parsed is Dictionary:
						entry["timestamp"] = parsed.get("timestamp", 0)
						entry["meta"] = parsed.get("meta", {})
				slots.append(entry)
			fn = da.get_next()
		da.list_dir_end()
	return success({"slots": slots, "count": slots.size(), "save_dir": dir})
