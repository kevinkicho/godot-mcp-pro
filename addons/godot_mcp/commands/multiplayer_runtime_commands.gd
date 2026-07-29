@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Multiplayer host/join runtime polish — lobby UI, player spawn stack, WebSocket peer.


func get_commands() -> Dictionary:
	return {
		"create_multiplayer_lobby_ui": _create_multiplayer_lobby_ui,
		"create_multiplayer_game_manager_script": _create_multiplayer_game_manager_script,
		"create_websocket_multiplayer_template": _create_websocket_multiplayer_template,
		"setup_multiplayer_player_scene": _setup_multiplayer_player_scene,
		"setup_multiplayer_spawn_stack": _setup_multiplayer_spawn_stack,
		"list_multiplayer_recipes": _list_multiplayer_recipes,
	}


func _list_multiplayer_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"recipes": [
			{"id": "enet_lobby", "tools": ["create_multiplayer_template_script", "create_multiplayer_lobby_ui", "create_multiplayer_game_manager_script"]},
			{"id": "spawn_stack", "tools": ["setup_multiplayer_spawn_stack", "setup_multiplayer_player_scene"]},
			{"id": "websocket", "tools": ["create_websocket_multiplayer_template"]},
		],
		"flow": [
			"create_multiplayer_game_manager_script (autoload)",
			"create_multiplayer_lobby_ui on main menu scene",
			"setup_multiplayer_player_scene for pawn",
			"setup_multiplayer_spawn_stack on game level",
			"playtest host + join (two instances)",
		],
	})



func _create_multiplayer_game_manager_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/multiplayer_manager.gd")
	var port: int = optional_int(params, "port", 7777)
	var max_clients: int = optional_int(params, "max_clients", 8)
	var game_scene: String = optional_string(params, "game_scene", "res://scenes/main.tscn")
	var content := """extends Node
## MCP MultiplayerManager autoload — ENet host/join + scene change + player roster.

const DEFAULT_PORT := %d
const MAX_CLIENTS := %d
const GAME_SCENE := "%s"

signal lobby_message(text: String)
signal player_list_changed(players: Dictionary)
signal connection_succeeded
signal connection_failed_signal

## peer_id -> {name}
var players: Dictionary = {}
var local_player_name: String = "Player"

func host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		lobby_message.emit("Host failed: %%s" %% error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_wire()
	players[1] = {"name": local_player_name}
	player_list_changed.emit(players)
	lobby_message.emit("Hosting on port %%d" %% port)
	return OK

func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		lobby_message.emit("Join failed: %%s" %% error_string(err))
		connection_failed_signal.emit()
		return err
	multiplayer.multiplayer_peer = peer
	_wire()
	lobby_message.emit("Connecting to %%s:%%d…" %% [address, port])
	return OK

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	player_list_changed.emit(players)
	lobby_message.emit("Disconnected")

func start_game() -> void:
	if not multiplayer.is_server():
		return
	_load_game.rpc(GAME_SCENE)

@rpc("authority", "call_local", "reliable")
func _load_game(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func _wire() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
	if not multiplayer.connection_failed.is_connected(_on_failed):
		multiplayer.connection_failed.connect(_on_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_left):
		multiplayer.server_disconnected.connect(_on_server_left)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		# Request name from client
		_request_name.rpc_id(id)
	lobby_message.emit("Peer connected: %%d" %% id)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_list_changed.emit(players)
	lobby_message.emit("Peer left: %%d" %% id)

func _on_connected() -> void:
	connection_succeeded.emit()
	_register_name.rpc_id(1, local_player_name)
	lobby_message.emit("Connected to server")

func _on_failed() -> void:
	connection_failed_signal.emit()
	lobby_message.emit("Connection failed")
	leave()

func _on_server_left() -> void:
	lobby_message.emit("Server disconnected")
	leave()

@rpc("any_peer", "reliable")
func _register_name(player_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	players[id] = {"name": player_name}
	player_list_changed.emit(players)
	if multiplayer.is_server():
		_sync_players.rpc(players)

@rpc("authority", "reliable")
func _request_name() -> void:
	_register_name.rpc_id(1, local_player_name)

@rpc("authority", "call_local", "reliable")
func _sync_players(list: Dictionary) -> void:
	players = list
	player_list_changed.emit(players)

func get_my_id() -> int:
	return multiplayer.get_unique_id()
""" % [port, max_clients, game_scene]
	# Fix double-escaped percents for GDScript format - I used %% for the template inside % format
	# Actually the outer is % [port...] so %% becomes % in output - good for GDScript format strings
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	var al := false
	if optional_bool(params, "add_autoload", true):
		var aname: String = optional_string(params, "autoload_name", "MultiplayerManager")
		al = ensure_autoload(aname, w["path"], true)
	return success({"path": w["path"], "autoload_added": al, "port": port, "game_scene": game_scene})


func _create_multiplayer_lobby_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "MultiplayerLobby")
	layer.layer = optional_int(params, "layer", 20)
	add_child_with_undo(parent, layer, root, "MCP: MP lobby")

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child_with_undo(layer, center, root, "MCP: lobby center")

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(360, 280)
	add_child_with_undo(center, panel, root, "MCP: lobby panel")

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: lobby vbox")

	var title := Label.new()
	title.name = "Title"
	title.text = "Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_with_undo(vbox, title, root, "MCP: title")

	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.placeholder_text = "Player name"
	name_edit.text = "Player"
	add_child_with_undo(vbox, name_edit, root, "MCP: name")

	var addr := LineEdit.new()
	addr.name = "AddressEdit"
	addr.placeholder_text = "Address"
	addr.text = "127.0.0.1"
	add_child_with_undo(vbox, addr, root, "MCP: addr")

	var port_edit := LineEdit.new()
	port_edit.name = "PortEdit"
	port_edit.placeholder_text = "Port"
	port_edit.text = str(optional_int(params, "port", 7777))
	add_child_with_undo(vbox, port_edit, root, "MCP: port")

	var host_btn := Button.new()
	host_btn.name = "HostButton"
	host_btn.text = "Host"
	add_child_with_undo(vbox, host_btn, root, "MCP: host")

	var join_btn := Button.new()
	join_btn.name = "JoinButton"
	join_btn.text = "Join"
	add_child_with_undo(vbox, join_btn, root, "MCP: join")

	var start_btn := Button.new()
	start_btn.name = "StartButton"
	start_btn.text = "Start Game (host)"
	add_child_with_undo(vbox, start_btn, root, "MCP: start")

	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "Idle"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child_with_undo(vbox, status, root, "MCP: status")

	var players := ItemList.new()
	players.name = "PlayerList"
	players.custom_minimum_size = Vector2(0, 80)
	add_child_with_undo(vbox, players, root, "MCP: players")

	var sp: String = optional_string(params, "script_path", "res://scripts/multiplayer_lobby_ui.gd")
	var scr := """extends CanvasLayer
## MCP multiplayer lobby UI — wires to MultiplayerManager autoload.

@onready var name_edit: LineEdit = $Center/Panel/VBox/NameEdit
@onready var addr_edit: LineEdit = $Center/Panel/VBox/AddressEdit
@onready var port_edit: LineEdit = $Center/Panel/VBox/PortEdit
@onready var host_btn: Button = $Center/Panel/VBox/HostButton
@onready var join_btn: Button = $Center/Panel/VBox/JoinButton
@onready var start_btn: Button = $Center/Panel/VBox/StartButton
@onready var status: Label = $Center/Panel/VBox/StatusLabel
@onready var player_list: ItemList = $Center/Panel/VBox/PlayerList

func _ready() -> void:
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	start_btn.pressed.connect(_on_start)
	if has_node("/root/MultiplayerManager"):
		var mm := get_node("/root/MultiplayerManager")
		mm.lobby_message.connect(func(t): status.text = t)
		mm.player_list_changed.connect(_on_players)
		mm.connection_succeeded.connect(func(): status.text = "Connected")
		mm.connection_failed_signal.connect(func(): status.text = "Failed")

func _on_host() -> void:
	if not has_node("/root/MultiplayerManager"):
		status.text = "Add MultiplayerManager autoload"
		return
	var mm := get_node("/root/MultiplayerManager")
	mm.local_player_name = name_edit.text
	mm.host(int(port_edit.text))

func _on_join() -> void:
	if not has_node("/root/MultiplayerManager"):
		status.text = "Add MultiplayerManager autoload"
		return
	var mm := get_node("/root/MultiplayerManager")
	mm.local_player_name = name_edit.text
	mm.join(addr_edit.text, int(port_edit.text))

func _on_start() -> void:
	if has_node("/root/MultiplayerManager"):
		get_node("/root/MultiplayerManager").start_game()

func _on_players(players: Dictionary) -> void:
	player_list.clear()
	for id in players:
		var n: String = str(players[id].get("name", id))
		player_list.add_item("%s (%s)" % [n, id])
"""
	var w := write_script_file(sp, scr, optional_bool(params, "overwrite", true))
	if w.has("path"):
		var s = load(w["path"])
		if s:
			layer.set_script(s)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(layer)),
		"script_path": sp,
		"hint": "Call create_multiplayer_game_manager_script first (autoload MultiplayerManager)",
	})


func _create_websocket_multiplayer_template(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/multiplayer_websocket.gd")
	var port: int = optional_int(params, "port", 9080)
	var content := """extends Node
## MCP WebSocket multiplayer host/join template.

const DEFAULT_PORT := %d

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connected_to_server
signal connection_failed

func host(port: int = DEFAULT_PORT) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_wire()
	return OK

func join(url: String = "ws://127.0.0.1:%d") -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_wire()
	return OK

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func _wire() -> void:
	if not multiplayer.peer_connected.is_connected(func(id): peer_connected.emit(id)):
		multiplayer.peer_connected.connect(func(id): peer_connected.emit(id))
	if not multiplayer.peer_disconnected.is_connected(func(id): peer_disconnected.emit(id)):
		multiplayer.peer_disconnected.connect(func(id): peer_disconnected.emit(id))
	if not multiplayer.connected_to_server.is_connected(func(): connected_to_server.emit()):
		multiplayer.connected_to_server.connect(func(): connected_to_server.emit())
	if not multiplayer.connection_failed.is_connected(func(): connection_failed.emit()):
		multiplayer.connection_failed.connect(func(): connection_failed.emit())
""" % [port, port]
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w["path"], "port": port, "protocol": "websocket"})


func _setup_multiplayer_player_scene(params: Dictionary) -> Dictionary:
	## Create a simple networked player .tscn with MultiplayerSynchronizer.
	var save_path: String = optional_string(params, "path", "res://scenes/network_player.tscn")
	if not save_path.begins_with("res://"):
		save_path = "res://" + save_path.trim_prefix("/")
	var is_3d: bool = optional_bool(params, "is_3d", false)
	var root_type := "CharacterBody3D" if is_3d else "CharacterBody2D"
	var script_path: String = optional_string(params, "script_path", "res://scripts/network_player.gd")
	var speed: float = float(params.get("speed", 5.0 if is_3d else 200.0))

	var script_content: String
	if is_3d:
		script_content = """extends CharacterBody3D
## MCP networked player 3D — authority-only input.

@export var speed: float = %.2f

func _ready() -> void:
	set_multiplayer_authority(str(name).to_int() if str(name).is_valid_int() else 1)
	var cam := get_node_or_null("Camera3D")
	if cam:
		cam.current = is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
""" % speed
	else:
		script_content = """extends CharacterBody2D
## MCP networked player 2D — authority-only input.

@export var speed: float = %.1f

func _ready() -> void:
	set_multiplayer_authority(str(name).to_int() if str(name).is_valid_int() else 1)
	var cam := get_node_or_null("Camera2D")
	if cam:
		cam.enabled = is_multiplayer_authority()

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
""" % speed

	var sw := write_script_file(script_path, script_content, optional_bool(params, "overwrite", true))
	if sw.has("error"):
		return sw

	# Build scene in memory and pack
	var body: Node
	if is_3d:
		body = CharacterBody3D.new()
		body.name = "NetworkPlayer"
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		col.shape = cap
		col.position = Vector3(0, 0.9, 0)
		body.add_child(col)
		col.owner = body
		var cam := Camera3D.new()
		cam.name = "Camera3D"
		cam.position = Vector3(0, 1.6, 0)
		body.add_child(cam)
		cam.owner = body
	else:
		body = CharacterBody2D.new()
		body.name = "NetworkPlayer"
		var col2 := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12
		col2.shape = circle
		body.add_child(col2)
		col2.owner = body
		var cam2 := Camera2D.new()
		cam2.name = "Camera2D"
		body.add_child(cam2)
		cam2.owner = body

	var sync := MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	if is_3d:
		config.add_property(NodePath(".:rotation"))
	sync.replication_config = config
	body.add_child(sync)
	sync.owner = body

	var scr = load(script_path)
	if scr:
		body.set_script(scr)

	var packed := PackedScene.new()
	if packed.pack(body) != OK:
		body.free()
		return error_internal("pack failed")
	body.free()
	var derr := ensure_parent_dir(save_path)
	if not derr.is_empty():
		return derr
	if FileAccess.file_exists(save_path) and not optional_bool(params, "overwrite", true):
		return error(-32000, "Exists: %s" % save_path, {"suggestion": "overwrite=true"})
	if ResourceSaver.save(packed, save_path) != OK:
		return error_internal("save failed")
	EditorInterface.get_resource_filesystem().update_file(save_path)
	return success({
		"path": save_path,
		"script_path": script_path,
		"is_3d": is_3d,
		"sync_properties": ["position"] + (["rotation"] if is_3d else []),
	})


func _setup_multiplayer_spawn_stack(params: Dictionary) -> Dictionary:
	## MultiplayerSpawner + spawn points under current scene for player pawns.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var player_scene: String = optional_string(params, "player_scene", "res://scenes/network_player.tscn")
	if not player_scene.begins_with("res://"):
		player_scene = "res://" + player_scene.trim_prefix("/")

	var spawner := MultiplayerSpawner.new()
	spawner.name = optional_string(params, "name", "MultiplayerSpawner")
	spawner.spawn_path = NodePath("..")
	if spawner.has_method("add_spawnable_scene"):
		spawner.add_spawnable_scene(player_scene)
	add_child_with_undo(parent, spawner, root, "MCP: MultiplayerSpawner")

	var points := Node.new()
	points.name = "SpawnPoints"
	add_child_with_undo(parent, points, root, "MCP: SpawnPoints")
	var count: int = optional_int(params, "spawn_point_count", 4)
	var spacing: float = float(params.get("spacing", 64.0 if not optional_bool(params, "is_3d", false) else 3.0))
	var is_3d: bool = optional_bool(params, "is_3d", false)
	for i in range(count):
		if is_3d:
			var m := Marker3D.new()
			m.name = "Spawn%d" % i
			m.position = Vector3(i * spacing, 0, 0)
			add_child_with_undo(points, m, root, "MCP: spawn point")
		else:
			var m2 := Marker2D.new()
			m2.name = "Spawn%d" % i
			m2.position = Vector2(i * spacing, 0)
			add_child_with_undo(points, m2, root, "MCP: spawn point")

	var sp: String = optional_string(params, "script_path", "res://scripts/multiplayer_spawner_host.gd")
	var scr := """extends Node
## MCP host spawn helper — spawn one player pawn per peer at SpawnPoints.

@export var player_scene: PackedScene
@export var spawn_points_path: NodePath = ^"../SpawnPoints"

func _ready() -> void:
	if player_scene == null and ResourceLoader.exists("%s"):
		player_scene = load("%s")
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_spawn_for)
		# Spawn existing peers including server
		for id in multiplayer.get_peers():
			_spawn_for(id)
		_spawn_for(multiplayer.get_unique_id())

func _spawn_for(peer_id: int) -> void:
	if not multiplayer.is_server() or player_scene == null:
		return
	var p: Node = player_scene.instantiate()
	p.name = str(peer_id)
	var points := get_node_or_null(spawn_points_path)
	if points and points.get_child_count() > 0:
		var idx := peer_id %% points.get_child_count()
		var spawner_pt: Node = points.get_child(idx)
		if p is Node2D and spawner_pt is Node2D:
			(p as Node2D).global_position = (spawner_pt as Node2D).global_position
		elif p is Node3D and spawner_pt is Node3D:
			(p as Node3D).global_position = (spawner_pt as Node3D).global_position
	get_parent().add_child(p, true)
	p.set_multiplayer_authority(peer_id)
""" % [player_scene, player_scene]
	var w := write_script_file(sp, scr, optional_bool(params, "overwrite", true))
	if w.has("path"):
		var host_node := Node.new()
		host_node.name = "SpawnHost"
		add_child_with_undo(parent, host_node, root, "MCP: SpawnHost")
		var s = load(w["path"])
		if s:
			host_node.set_script(s)
			if ResourceLoader.exists(player_scene):
				host_node.set("player_scene", load(player_scene))
			host_node.set("spawn_points_path", host_node.get_path_to(points))

	mark_current_scene_unsaved()
	return success({
		"spawner_path": str(root.get_path_to(spawner)),
		"spawn_points_path": str(root.get_path_to(points)),
		"player_scene": player_scene,
		"spawn_point_count": count,
		"hint": "Ensure player_scene exists (setup_multiplayer_player_scene). Host via MultiplayerManager then load this level.",
	})
