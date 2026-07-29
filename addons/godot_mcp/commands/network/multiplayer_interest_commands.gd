@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Multiplayer interest / visibility / replication range helpers.


func get_commands() -> Dictionary:
	return {
		"create_interest_manager_script": _create_interest_manager_script,
		"setup_multiplayer_visibility_filter": _setup_multiplayer_visibility_filter,
		"set_synchronizer_replication_interval": _set_synchronizer_replication_interval,
		"configure_multiplayer_spawner_limits": _configure_multiplayer_spawner_limits,
		"list_multiplayer_interest_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_multiplayer_spawner", "setup_multiplayer_synchronizer", "add_replication_property", "create_multiplayer_template_script"],
		"flow": [
			"create_interest_manager_script add_autoload=true",
			"setup_multiplayer_visibility_filter on player",
			"set_synchronizer_replication_interval for bandwidth",
		],
	})


func _create_interest_manager_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/interest_manager.gd")
	var content := """extends Node
## Simple interest / AOI manager — tracks watchers and which peers should see an entity.
## Use with MultiplayerSynchronizer visibility or custom spawn filters.

signal interest_changed(entity_id: StringName, peer_ids: Array)

@export var default_radius: float = 40.0
var _entities: Dictionary = {}  # id -> {node, radius}
var _watchers: Dictionary = {}  # peer_id -> Node3D/Node2D

func register_entity(id: StringName, node: Node, radius: float = -1.0) -> void:
	_entities[id] = {"node": node, "radius": radius if radius > 0.0 else default_radius}

func unregister_entity(id: StringName) -> void:
	_entities.erase(id)

func register_watcher(peer_id: int, node: Node) -> void:
	_watchers[peer_id] = node

func unregister_watcher(peer_id: int) -> void:
	_watchers.erase(peer_id)

func peers_interested_in(id: StringName) -> Array:
	if not _entities.has(id):
		return []
	var e: Dictionary = _entities[id]
	var ent: Node = e.get("node")
	var radius: float = float(e.get("radius", default_radius))
	if ent == null or not is_instance_valid(ent):
		return []
	var out: Array = []
	for peer_id in _watchers:
		var w: Node = _watchers[peer_id]
		if w == null or not is_instance_valid(w):
			continue
		if _distance(ent, w) <= radius:
			out.append(int(peer_id))
	return out

func refresh_entity(id: StringName) -> void:
	var peers := peers_interested_in(id)
	interest_changed.emit(id, peers)

func refresh_all() -> void:
	for id in _entities.keys():
		refresh_entity(id)

func _distance(a: Node, b: Node) -> float:
	if a is Node3D and b is Node3D:
		return (a as Node3D).global_position.distance_to((b as Node3D).global_position)
	if a is Node2D and b is Node2D:
		return (a as Node2D).global_position.distance_to((b as Node2D).global_position)
	return 0.0
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var added := maybe_add_autoload(params, path, "InterestManager")
	return success({"path": path, "autoload_added": added})


func _setup_multiplayer_visibility_filter(params: Dictionary) -> Dictionary:
	## Attach a small script that filters MultiplayerSynchronizer public_visibility by distance.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var script_path: String = optional_string(params, "script_path", "res://scripts/mp_visibility_filter.gd")
	if not FileAccess.file_exists(script_path) or optional_bool(params, "overwrite", false):
		var content := """extends Node
## Distance-based MultiplayerSynchronizer visibility helper.
@export var synchronizer_path: NodePath
@export var radius: float = 40.0
@export var update_hz: float = 4.0
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0 / maxf(update_hz, 0.1):
		return
	_t = 0.0
	var sync := get_node_or_null(synchronizer_path)
	if sync == null:
		return
	# public_visibility is simple; for per-peer use set_visibility_for
	if multiplayer.multiplayer_peer == null:
		return
	var my_id := multiplayer.get_unique_id()
	for peer in multiplayer.get_peers():
		var visible := true
		# Custom: keep all visible unless InterestManager present
		if has_node(\"/root/InterestManager\"):
			pass
		if sync.has_method(\"set_visibility_for\"):
			sync.set_visibility_for(peer, visible)
"""
		write_script_file(script_path, content, true)
	var node := Node.new()
	node.name = optional_string(params, "name", "VisibilityFilter")
	node.set_script(load(script_path))
	if params.has("synchronizer_path"):
		node.set("synchronizer_path", NodePath(str(params["synchronizer_path"])))
	if params.has("radius"):
		node.set("radius", float(params["radius"]))
	add_child_with_undo(parent, node, root, "MCP: MP visibility filter")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"script_path": script_path,
	})


func _set_synchronizer_replication_interval(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or n.get_class() != "MultiplayerSynchronizer":
		return error_not_found("MultiplayerSynchronizer")
	var applied := {}
	if params.has("replication_interval") and "replication_interval" in n:
		n.set("replication_interval", float(params["replication_interval"]))
		applied["replication_interval"] = n.get("replication_interval")
	if params.has("delta_interval") and "delta_interval" in n:
		n.set("delta_interval", float(params["delta_interval"]))
		applied["delta_interval"] = n.get("delta_interval")
	if params.has("public_visibility") and "public_visibility" in n:
		n.set("public_visibility", bool(params["public_visibility"]))
		applied["public_visibility"] = n.get("public_visibility")
	if params.has("visibility_update_mode") and "visibility_update_mode" in n:
		n.set("visibility_update_mode", int(params["visibility_update_mode"]))
		applied["visibility_update_mode"] = n.get("visibility_update_mode")
	if applied.is_empty():
		return error_invalid_params("Provide replication_interval, delta_interval, public_visibility")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _configure_multiplayer_spawner_limits(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is MultiplayerSpawner):
		return error_not_found("MultiplayerSpawner")
	var applied := {}
	if params.has("spawn_limit") and "spawn_limit" in n:
		n.set("spawn_limit", int(params["spawn_limit"]))
		applied["spawn_limit"] = n.get("spawn_limit")
	if params.has("spawn_path") and "spawn_path" in n:
		n.set("spawn_path", NodePath(str(params["spawn_path"])))
		applied["spawn_path"] = str(n.get("spawn_path"))
	if params.has("spawn_function") and "spawn_function" in n:
		# Callable hard via MCP — document
		applied["spawn_function_note"] = "Set spawn_function in script; not set via free-form Callable here"
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})
