@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Multiplayer peer recipes — ENet host/join scripts (tutorials/networking).


func get_commands() -> Dictionary:
	return {
		"create_enet_multiplayer_script": _create_enet_script,
		"create_multiplayer_bootstrap_script": _create_bootstrap,
		"setup_multiplayer_spawner_basic": _setup_spawner_basic,
		"list_multiplayer_peer_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"setup_multiplayer_spawner", "setup_multiplayer_synchronizer",
			"create_multiplayer_game_manager_script", "list_webrtc_recipes",
		],
	})


func _create_enet_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/enet_multiplayer.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## ENet multiplayer host/join helper.

signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_connected(id: int)
signal peer_disconnected(id: int)

@export var port: int = 7777
@export var max_clients: int = 8
@export var address: String = "127.0.0.1"

func host_game(p_port: int = -1, p_max: int = -1) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(p_port if p_port > 0 else port, p_max if p_max > 0 else max_clients)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_bind_signals()
	return OK

func join_game(p_address: String = "", p_port: int = -1) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(
		p_address if not p_address.is_empty() else address,
		p_port if p_port > 0 else port
	)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_bind_signals()
	return OK

func close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func get_unique_id() -> int:
	return multiplayer.get_unique_id()

func is_server() -> bool:
	return multiplayer.is_server()

func _bind_signals() -> void:
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
	if not multiplayer.connection_failed.is_connected(_on_failed):
		multiplayer.connection_failed.connect(_on_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_connected() -> void:
	connected_to_server.emit()

func _on_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	var al := maybe_add_autoload(params, path, "Net")
	return success({"path": path, "autoload_added": al, "api": ["host_game", "join_game", "close"]})


func _create_bootstrap(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/multiplayer_bootstrap.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Bootstrap: host or join from UI buttons / command line.

@export var net_path: NodePath
@export var default_port: int = 7777

@onready var _net: Node = get_node_or_null(net_path)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--host" in args:
		host()
	elif "--join" in args:
		var addr := "127.0.0.1"
		for i in args.size():
			if args[i] == "--join" and i + 1 < args.size():
				addr = args[i + 1]
		join(addr)

func host(port: int = -1) -> void:
	if _net and _net.has_method("host_game"):
		var err: Error = _net.host_game(port if port > 0 else default_port)
		print("Host result: ", err)

func join(address: String = "127.0.0.1", port: int = -1) -> void:
	if _net and _net.has_method("join_game"):
		var err: Error = _net.join_game(address, port if port > 0 else default_port)
		print("Join result: ", err)
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "hint": "Set net_path to ENet helper node; run with --host or --join 127.0.0.1"})


func _setup_spawner_basic(params: Dictionary) -> Dictionary:
	## Thin wrapper ensuring MultiplayerSpawner exists with spawn path.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var spawner := MultiplayerSpawner.new()
	spawner.name = optional_string(params, "name", "MultiplayerSpawner")
	var spawn_path: String = optional_string(params, "spawn_path", ".")
	spawner.spawn_path = NodePath(spawn_path)
	if params.has("spawn_limit"):
		spawner.spawn_limit = int(params["spawn_limit"])
	add_child_with_undo(parent, spawner, root, "MCP: MultiplayerSpawner")
	var scene_path: String = optional_string(params, "spawnable_scene", "")
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		spawner.add_spawnable_scene(scene_path)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(spawner)),
		"spawn_path": spawn_path,
		"spawnable_scene": scene_path,
	})
