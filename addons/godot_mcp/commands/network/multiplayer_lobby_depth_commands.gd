@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Multiplayer lobby / ready-up / player roster - closes host->play production gap.


func get_commands() -> Dictionary:
	return {
		"create_multiplayer_lobby_script": _create_lobby_script,
		"create_player_spawn_service_script": _create_spawn_service,
		"setup_spawn_points": _setup_spawn_points,
		"list_spawn_points": _list_spawn_points,
		"create_network_clock_script": _create_clock,
		"list_multiplayer_lobby_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"pipeline_multiplayer_enet", "create_enet_multiplayer_script",
			"setup_multiplayer_spawner_basic", "add_replication_properties_bulk",
			"create_multiplayer_lobby_ui",
		],
		"workflow": [
			"pipeline_multiplayer_enet",
			"create_multiplayer_lobby_script add_autoload=true",
			"setup_spawn_points parent_path=Level count=4",
			"create_player_spawn_service_script",
		],
	})


func _create_lobby_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/multiplayer_lobby.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Multiplayer lobby: roster, ready flags, start when all ready (server authoritative).

signal player_joined(peer_id: int, info: Dictionary)
signal player_left(peer_id: int)
signal player_ready_changed(peer_id: int, is_ready: bool)
signal all_ready
signal match_starting
signal lobby_reset

@export var min_players: int = 1
@export var max_players: int = 8
@export var auto_start_when_ready: bool = true

## peer_id -> {name, ready, team, extra}
var players: Dictionary = {}
var match_started: bool = false

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_bind()

func bind_multiplayer() -> void:
	_bind()

func _bind() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# Local player
	if multiplayer.has_multiplayer_peer():
		_register_player(multiplayer.get_unique_id(), {"name": "Player_%d" % multiplayer.get_unique_id()})

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_register_player.rpc(id, {"name": "Player_%d" % id})
		# Sync existing roster to new peer
		for pid in players:
			_register_player.rpc_id(id, pid, players[pid])

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
		player_left.emit(id)
		_broadcast_leave.rpc(id)

@rpc("authority", "call_local", "reliable")
func _register_player(peer_id: int, info: Dictionary) -> void:
	if players.has(peer_id):
		players[peer_id].merge(info, true)
	else:
		var entry := {"name": str(info.get("name", "Player")), "ready": false, "team": 0}
		entry.merge(info, true)
		players[peer_id] = entry
	player_joined.emit(peer_id, players[peer_id])

@rpc("any_peer", "call_local", "reliable")
func set_ready(is_ready: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	if not players.has(id):
		return
	players[id]["ready"] = is_ready
	player_ready_changed.emit(id, is_ready)
	if multiplayer.is_server():
		_sync_ready.rpc(id, is_ready)
		_check_all_ready()

@rpc("authority", "call_local", "reliable")
func _sync_ready(peer_id: int, is_ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id]["ready"] = is_ready
		player_ready_changed.emit(peer_id, is_ready)

@rpc("authority", "call_local", "reliable")
func _broadcast_leave(peer_id: int) -> void:
	if players.has(peer_id):
		players.erase(peer_id)
	player_left.emit(peer_id)

func _check_all_ready() -> void:
	if match_started:
		return
	if players.size() < min_players:
		return
	for pid in players:
		if not bool(players[pid].get("ready", false)):
			return
	all_ready.emit()
	if auto_start_when_ready:
		start_match()

@rpc("authority", "call_local", "reliable")
func start_match() -> void:
	if not multiplayer.is_server() and multiplayer.get_unique_id() != 1:
		# only server should call; clients receive via rpc
		pass
	match_started = true
	match_starting.emit()

func get_player_ids() -> Array:
	return players.keys()

func is_all_ready() -> bool:
	if players.is_empty():
		return false
	for pid in players:
		if not bool(players[pid].get("ready", false)):
			return false
	return players.size() >= min_players

func reset_lobby() -> void:
	match_started = false
	for pid in players:
		players[pid]["ready"] = false
	lobby_reset.emit()
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	var al := maybe_add_autoload(params, path, "Lobby")
	return success({
		"path": path,
		"autoload_added": al,
		"api": ["set_ready", "start_match", "get_player_ids", "is_all_ready", "bind_multiplayer"],
	})


func _create_spawn_service(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/player_spawn_service.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Picks spawn points (group spawn_point) for multiplayer players.

signal player_spawned(peer_id: int, node: Node)

@export var player_scene: PackedScene
@export var spawn_group: StringName = &\"spawn_point\"
@export var spawn_parent_path: NodePath = NodePath(\"..\")
@export var cycle_spawns: bool = true

var _next_index: int = 0
var _spawned: Dictionary = {} # peer_id -> Node

func get_spawn_points() -> Array[Node]:
	var out: Array[Node] = []
	for n in get_tree().get_nodes_in_group(spawn_group):
		out.append(n)
	return out

func pick_spawn_transform(peer_id: int = 0) -> Transform3D:
	var points := get_spawn_points()
	if points.is_empty():
		return Transform3D.IDENTITY
	var idx := _next_index % points.size()
	if cycle_spawns:
		_next_index += 1
	else:
		idx = absi(peer_id) % points.size()
	var p: Node = points[idx]
	if p is Node3D:
		return (p as Node3D).global_transform
	if p is Node2D:
		var t := Transform3D.IDENTITY
		t.origin = Vector3((p as Node2D).global_position.x, (p as Node2D).global_position.y, 0)
		return t
	return Transform3D.IDENTITY

func pick_spawn_position_2d(peer_id: int = 0) -> Vector2:
	var points := get_spawn_points()
	if points.is_empty():
		return Vector2.ZERO
	var idx := (_next_index if cycle_spawns else absi(peer_id)) % points.size()
	if cycle_spawns:
		_next_index += 1
	var p: Node = points[idx]
	if p is Node2D:
		return (p as Node2D).global_position
	if p is Node3D:
		var o: Vector3 = (p as Node3D).global_position
		return Vector2(o.x, o.z)
	return Vector2.ZERO

@rpc(\"authority\", \"call_local\", \"reliable\")
func spawn_player(peer_id: int) -> void:
	if player_scene == null:
		push_error(\"player_scene not set\")
		return
	if _spawned.has(peer_id) and is_instance_valid(_spawned[peer_id]):
		return
	var inst: Node = player_scene.instantiate()
	inst.name = \"Player_%d\" % peer_id
	var parent := get_node_or_null(spawn_parent_path)
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(inst, true)
	if inst is Node3D:
		(inst as Node3D).global_transform = pick_spawn_transform(peer_id)
	elif inst is Node2D:
		(inst as Node2D).global_position = pick_spawn_position_2d(peer_id)
	if inst.has_method(\"set_multiplayer_authority\"):
		inst.set_multiplayer_authority(peer_id)
	_spawned[peer_id] = inst
	player_spawned.emit(peer_id, inst)

func despawn_player(peer_id: int) -> void:
	if _spawned.has(peer_id) and is_instance_valid(_spawned[peer_id]):
		_spawned[peer_id].queue_free()
	_spawned.erase(peer_id)
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({
		"path": path,
		"api": ["spawn_player", "despawn_player", "pick_spawn_transform", "get_spawn_points"],
		"hint": "Set player_scene; mark Marker2D/3D with group spawn_point via setup_spawn_points",
	})


func _setup_spawn_points(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var count: int = optional_int(params, "count", 4)
	var dim: String = optional_string(params, "dimension", "auto").to_lower()
	if dim == "auto":
		dim = "3d" if parent is Node3D else "2d"
	var spacing: float = float(params.get("spacing", 4.0))
	var group: String = optional_string(params, "group", "spawn_point")
	var created: Array = []
	for i in count:
		var marker: Node
		if dim in ["3d", "3"]:
			marker = Marker3D.new()
			(marker as Marker3D).position = Vector3(float(i) * spacing, 0, 0)
		else:
			marker = Marker2D.new()
			(marker as Marker2D).position = Vector2(float(i) * spacing * 32.0, 0)
		marker.name = "SpawnPoint_%d" % (i + 1)
		marker.add_to_group(group, true)
		add_child_with_undo(parent, marker, root, "MCP: Spawn point")
		created.append(str(root.get_path_to(marker)))
	mark_current_scene_unsaved()
	return success({
		"spawn_points": created,
		"count": created.size(),
		"group": group,
		"dimension": dim,
	})


func _list_spawn_points(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var group: String = optional_string(params, "group", "spawn_point")
	var points: Array = []
	_collect_group(root, root, group, points)
	return success({"group": group, "points": points, "count": points.size()})


func _collect_group(scene_root: Node, node: Node, group: String, out: Array) -> void:
	if node.is_in_group(group):
		var entry := {
			"node_path": str(scene_root.get_path_to(node)),
			"name": node.name,
			"class": node.get_class(),
		}
		if node is Node2D:
			entry["position"] = {"x": (node as Node2D).global_position.x, "y": (node as Node2D).global_position.y}
		elif node is Node3D:
			var p: Vector3 = (node as Node3D).global_position
			entry["position"] = {"x": p.x, "y": p.y, "z": p.z}
		out.append(entry)
	for c in node.get_children():
		_collect_group(scene_root, c, group, out)


func _create_clock(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/network_clock.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Simple server time sync estimate for multiplayer games.

signal time_synced(server_time_msec: int, rtt_msec: int)

var _rtt_msec: int = 0
var _server_time_offset_msec: int = 0

func get_rtt_msec() -> int:
	return _rtt_msec

func get_estimated_server_time_msec() -> int:
	return Time.get_ticks_msec() + _server_time_offset_msec

func ping_server() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		return
	_ping.rpc_id(1, Time.get_ticks_msec())

@rpc(\"any_peer\", \"reliable\")
func _ping(client_send_msec: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_pong.rpc_id(sender, client_send_msec, Time.get_ticks_msec())

@rpc(\"authority\", \"reliable\")
func _pong(client_send_msec: int, server_msec: int) -> void:
	var now := Time.get_ticks_msec()
	_rtt_msec = now - client_send_msec
	var one_way := _rtt_msec / 2
	_server_time_offset_msec = (server_msec + one_way) - now
	time_synced.emit(get_estimated_server_time_msec(), _rtt_msec)
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	var al := maybe_add_autoload(params, path, "NetClock")
	return success({"path": path, "autoload_added": al, "api": ["ping_server", "get_rtt_msec", "get_estimated_server_time_msec"]})
