@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Level/scene streaming helpers - load/unload chunk scenes for large worlds.


func get_commands() -> Dictionary:
	return {
		"create_stream_manager_script": _create_stream_manager_script,
		"stream_load_chunk": _stream_load_chunk,
		"stream_unload_chunk": _stream_unload_chunk,
		"stream_list_chunks": _stream_list_chunks,
		"stream_set_chunk_active": _stream_set_chunk_active,
		"list_stream_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"flow": [
			"create_stream_manager_script (autoload optional)",
			"stream_load_chunk scene_path=res://levels/chunk_0_0.tscn",
			"stream_set_chunk_active / unload far chunks",
			"validate_level_playable + playtest",
		],
		"tools": get_commands().keys(),
	})


func _create_stream_manager_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/stream_manager.gd")
	var content := """extends Node
## MCP StreamManager - load/unload packed scene chunks under a holder node.
signal chunk_loaded(id: String, node: Node)
signal chunk_unloaded(id: String)

@export var holder_path: NodePath = ^"Chunks"
var _chunks: Dictionary = {}  # id -> Node

func _holder() -> Node:
	var h := get_node_or_null(holder_path)
	if h == null and get_tree() and get_tree().current_scene:
		h = get_tree().current_scene.get_node_or_null("Chunks")
	return h

func load_chunk(id: String, scene_path: String, parent: Node = null) -> Node:
	if _chunks.has(id) and is_instance_valid(_chunks[id]):
		return _chunks[id]
	if not ResourceLoader.exists(scene_path):
		push_error("Missing chunk: " + scene_path)
		return null
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	inst.name = id
	var p := parent if parent else _holder()
	if p == null:
		p = get_tree().current_scene
	p.add_child(inst)
	_chunks[id] = inst
	chunk_loaded.emit(id, inst)
	return inst

func unload_chunk(id: String) -> void:
	if not _chunks.has(id):
		return
	var n: Node = _chunks[id]
	_chunks.erase(id)
	if is_instance_valid(n):
		n.queue_free()
	chunk_unloaded.emit(id)

func set_active(id: String, active: bool) -> void:
	if not _chunks.has(id):
		return
	var n: Node = _chunks[id]
	if n is Node3D:
		(n as Node3D).visible = active
	n.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func list_chunks() -> Array:
	var out: Array = []
	for k in _chunks:
		out.append({"id": k, "valid": is_instance_valid(_chunks[k])})
	return out
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", false):
		al = ensure_autoload(optional_string(params, "autoload_name", "StreamManager"), w.get("path", path), true)
	return success({"path": w.get("path", path), "autoload_added": al})


func _ensure_chunks_holder(root: Node, parent: Node) -> Node:
	var holder := parent.get_node_or_null("Chunks")
	if holder:
		return holder
	holder = Node3D.new()
	holder.name = "Chunks"
	add_child_with_undo(parent, holder, root, "MCP: Chunks holder")
	return holder


func _stream_load_chunk(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var scene_path: String = optional_string(params, "scene_path", "")
	if scene_path.is_empty():
		return error_invalid_params("scene_path required")
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path.trim_prefix("/")
	if not ResourceLoader.exists(scene_path):
		return error_not_found(scene_path)
	var id: String = optional_string(params, "id", scene_path.get_file().get_basename())
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var holder := _ensure_chunks_holder(root, parent)
	# Replace existing
	var existing := holder.get_node_or_null(id)
	if existing:
		existing.queue_free()
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return error_internal("Not PackedScene")
	var inst := packed.instantiate()
	inst.name = id
	if params.has("position") and inst is Node3D:
		var pos = params["position"]
		if pos is Dictionary:
			(inst as Node3D).position = Vector3(float(pos.get("x", 0)), float(pos.get("y", 0)), float(pos.get("z", 0)))
	add_child_with_undo(holder, inst, root, "MCP: load chunk")
	mark_current_scene_unsaved()
	return success({
		"id": id,
		"node_path": str(root.get_path_to(inst)),
		"scene_path": scene_path,
		"holder": str(root.get_path_to(holder)),
	})


func _stream_unload_chunk(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var id: String = optional_string(params, "id", "")
	var path: String = optional_string(params, "node_path", "")
	var node: Node = null
	if not path.is_empty():
		node = find_node_by_path(path)
	elif not id.is_empty():
		var parent := find_node_by_path(optional_string(params, "parent_path", "."))
		if parent:
			var holder := parent.get_node_or_null("Chunks")
			if holder:
				node = holder.get_node_or_null(id)
	if node == null:
		return error_not_found("chunk")
	var p := str(root.get_path_to(node))
	node.queue_free()
	mark_current_scene_unsaved()
	return success({"unloaded": p, "id": id})


func _stream_list_chunks(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var holder := parent.get_node_or_null("Chunks")
	if holder == null:
		return success({"chunks": [], "count": 0})
	var out: Array = []
	for c in holder.get_children():
		out.append({
			"id": str(c.name),
			"path": str(root.get_path_to(c)),
			"type": c.get_class(),
			"visible": c.visible if c is CanvasItem or c is Node3D else true,
		})
	return success({"chunks": out, "count": out.size(), "holder": str(root.get_path_to(holder))})


func _stream_set_chunk_active(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var active: bool = optional_bool(params, "active", true)
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found(r0[0])
	if node is Node3D:
		(node as Node3D).visible = active
	elif node is CanvasItem:
		(node as CanvasItem).visible = active
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "active": active})
